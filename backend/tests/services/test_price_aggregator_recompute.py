"""价格聚合重算：实体单位覆盖变更后，价格记录 standard_quantity 跟随最新覆盖。

背景：扫码新增商品 → 先记价格（计数单位默认 100g/个）→ 后补自定义单位（如袋=1000g）。
price_aggregator.recompute_product_standard_quantities 按当前覆盖（商品>原料>兜底）重算
既有记录，并刷新去标识汇总；EntityUnitOverrideExecutor.apply/revert 会自动触发。

本测试使用独立内存库（不与 conftest 共享 engine），避免跨文件测试数据互相污染。
"""
import time
from decimal import Decimal

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models.unit import Unit
from app.models.nutrition import Ingredient
from app.models.product_entity import Product
from app.models.product import ProductRecord
from app.models.entity_unit_override import EntityUnitOverride
from app.models.price_summary import ProductMerchantPriceSummary
from app.services.price_aggregator import (
    recompute_ingredient_standard_quantities,
    recompute_product_standard_quantities,
)
from app.services.proposals.executors.entity_unit_override import EntityUnitOverrideExecutor

_engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
Base.metadata.create_all(_engine)
_Session = sessionmaker(bind=_engine, autoflush=False, autocommit=False)


def _get_or_make_unit(db, *, name, abbr, unit_type, si_factor, unit_system):
    existing = db.query(Unit).filter(Unit.abbreviation == abbr).first()
    if existing is not None:
        return existing
    u = Unit(name=name, abbreviation=abbr, unit_type=unit_type, si_factor=si_factor,
             unit_system=unit_system, is_active=True)
    db.add(u)
    db.flush()
    return u


def _make_units(db):
    g = _get_or_make_unit(db, name="克", abbr="g", unit_type="mass",
                          si_factor=Decimal("0.001"), unit_system="metric")
    kg = _get_or_make_unit(db, name="千克", abbr="kg", unit_type="mass",
                           si_factor=Decimal("1"), unit_system="metric")
    jin = _get_or_make_unit(db, name="斤", abbr="斤", unit_type="mass",
                            si_factor=Decimal("0.5"), unit_system="market")
    dai = _get_or_make_unit(db, name="袋", abbr="袋", unit_type="count",
                            si_factor=Decimal("1"), unit_system="count")
    return g, kg, jin, dai


def _make_ingredient_product_record(db, *, product_name, price, unit_id, std_qty, std_unit_id):
    """创建唯一命名（含时间戳）的原料/商品/记录。"""
    suffix = f"{time.time_ns()}"
    ing = Ingredient(name=f"挂面{suffix}", category_id=1, is_active=True)
    db.add(ing)
    db.flush()
    prod = Product(name=f"{product_name}{suffix}", ingredient_id=ing.id, is_active=True)
    db.add(prod)
    db.flush()
    rec = ProductRecord(
        user_id=1, product_id=prod.id, product_name=prod.name,
        price=price, currency="CNY",
        original_quantity=Decimal("1"), original_unit_id=unit_id,
        standard_quantity=std_qty, standard_unit_id=std_unit_id,
        record_type="purchase", exchange_rate=Decimal("1"),
        is_active=True,
    )
    db.add(rec)
    db.flush()
    return ing, prod, rec


def test_recompute_product_standard_quantity_uses_product_override():
    db = _Session()
    try:
        g, _kg, _jin, dai = _make_units(db)
        _ing, prod, rec = _make_ingredient_product_record(
            db, product_name="金沙河精制鸡蛋挂面 1kg",
            price=Decimal("4.5"), unit_id=dai.id,
            std_qty=Decimal("100"), std_unit_id=g.id,
        )
        # 用户后补自定义单位：袋=1000g
        ov = EntityUnitOverride(
            entity_type="product", entity_id=prod.id, unit_name="袋",
            conversion_factor=Decimal("1"), weight_per_unit=Decimal("1000"),
            weight_unit_id=g.id, is_default=True, source="manual", is_active=True,
        )
        db.add(ov)
        db.flush()

        changed = recompute_product_standard_quantities(db, product_id=prod.id)
        db.commit()

        assert changed == 1
        db.refresh(rec)
        assert float(rec.standard_quantity) == 1000.0
        assert rec.standard_unit_id == g.id

        # 汇总同步：4.5 元 / 1000g → ¥2.25/斤
        summary = db.query(ProductMerchantPriceSummary).filter_by(
            product_id=prod.id, merchant_id=None
        ).first()
        assert summary is not None
        assert float(summary.recent_price) == 2.25
    finally:
        db.close()


def test_recompute_ingredient_recomputes_all_products():
    db = _Session()
    try:
        g, _kg, _jin, dai = _make_units(db)
        ing, prod1, rec1 = _make_ingredient_product_record(
            db, product_name="挂面A", price=Decimal("4.5"),
            unit_id=dai.id, std_qty=Decimal("100"), std_unit_id=g.id,
        )
        prod2 = Product(name=f"挂面B{time.time_ns()}", ingredient_id=ing.id, is_active=True)
        db.add(prod2)
        db.flush()
        rec2 = ProductRecord(
            user_id=1, product_id=prod2.id, product_name=prod2.name,
            price=Decimal("9"), currency="CNY",
            original_quantity=Decimal("1"), original_unit_id=dai.id,
            standard_quantity=Decimal("100"), standard_unit_id=g.id,
            record_type="purchase", exchange_rate=Decimal("1"), is_active=True,
        )
        db.add(rec2)
        # 原料级覆盖：袋=1000g（商品无覆盖时回退到原料覆盖）
        ov = EntityUnitOverride(
            entity_type="ingredient", entity_id=ing.id, unit_name="袋",
            conversion_factor=Decimal("1"), weight_per_unit=Decimal("1000"),
            weight_unit_id=g.id, is_default=True, source="manual", is_active=True,
        )
        db.add(ov)
        db.flush()

        changed = recompute_ingredient_standard_quantities(db, ingredient_id=ing.id)
        db.commit()

        assert changed == 2
        db.refresh(rec1)
        db.refresh(rec2)
        assert float(rec1.standard_quantity) == 1000.0
        assert float(rec2.standard_quantity) == 1000.0
    finally:
        db.close()


def test_executor_apply_recompute_records():
    """EntityUnitOverrideExecutor.apply 创建覆盖后自动重算既有记录。"""
    db = _Session()
    try:
        g, _kg, _jin, dai = _make_units(db)
        _ing, prod, rec = _make_ingredient_product_record(
            db, product_name="挂面", price=Decimal("4.5"),
            unit_id=dai.id, std_qty=Decimal("100"), std_unit_id=g.id,
        )

        class _Proposal:
            entity_type = "entity_unit_override"
            entity_id = None
            action = "create"
            payload = {
                "entity_type": "product",
                "entity_id": prod.id,
                "unit_name": "袋",
                "conversion_factor": "1",
                "weight_per_unit": "1000",
                "weight_unit_id": g.id,
                "is_default": True,
                "source": "manual",
                "is_active": True,
            }

        executor = EntityUnitOverrideExecutor()
        executor.validate(db, _Proposal())
        executor.apply(db, _Proposal())
        db.commit()

        db.refresh(rec)
        assert float(rec.standard_quantity) == 1000.0
        assert rec.standard_unit_id == g.id
    finally:
        db.close()


def test_recompute_falls_back_to_default_when_override_deleted():
    db = _Session()
    try:
        g, _kg, _jin, dai = _make_units(db)
        _ing, prod, rec = _make_ingredient_product_record(
            db, product_name="挂面", price=Decimal("4.5"),
            unit_id=dai.id, std_qty=Decimal("1000"), std_unit_id=g.id,
        )
        ov = EntityUnitOverride(
            entity_type="product", entity_id=prod.id, unit_name="袋",
            conversion_factor=Decimal("1"), weight_per_unit=Decimal("1000"),
            weight_unit_id=g.id, is_default=True, source="manual", is_active=False,  # 已软删
        )
        db.add(ov)
        db.flush()

        # 覆盖被软删后重算 → 回退默认 100g/个
        changed = recompute_product_standard_quantities(db, product_id=prod.id)
        db.commit()

        assert changed == 1
        db.refresh(rec)
        assert float(rec.standard_quantity) == 100.0
    finally:
        db.close()
