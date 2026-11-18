"""跨地区物价对比端点的回归测试。

数据布局（每个测试自建、finally 清理；共享内存库多测试共存）：
  国家 TCN → 省份 TP → 城市A / 城市B / 城市C（无商家）
  商家 mA 在城市A、商家 mB 在城市B；同一商品两条记录：
  mA 便宜（10 元/500g，较早）、mB 贵（100 元/500g，较晚）。
  with_free_merchant=True 时额外建一个无地区商家（其记录按既有规则
  「未分配地区商家在任何地区都计入」，会进入所有地区的汇总，所以默认关闭）。

验证：
  - /comparison/regions 候选；无地区商家不产生候选
  - /comparison/summary 物价指数（单价比率中位数）与篮子趋势
  - /comparison/entity-prices 矩阵（原料/商品 × 地区，含无数据地区与超期放开）
  - region_ids 校验（≤6）
"""
import asyncio
import uuid
from datetime import datetime, timedelta, timezone

import pytest
from conftest import FakeUser
from starlette.requests import Request

# mA 记录：10 元 / 500 g；mB 记录：100 元 / 500 g
PRICE_A = 10.0
PRICE_B = 100.0
STD_QTY = 500
# 每标准单位（g）单价：卡片价口径 = price / standard_quantity
UNIT_PRICE_A = PRICE_A / STD_QTY
UNIT_PRICE_B = PRICE_B / STD_QTY


def _fake_request() -> Request:
    return Request({
        "type": "http", "method": "GET", "path": "/",
        "headers": [], "query_string": b"",
    })


def _build_fixture(db_session, with_free_merchant: bool = False):
    """建 地区链 + 两地商家 + 原料/商品两条异地记录。"""
    from app.models.administrative_region import AdministrativeRegion
    from app.models.merchant import Merchant
    from app.models.nutrition import Ingredient
    from app.models.product import ProductRecord
    from app.models.product_entity import Product
    from app.models.unit import Unit

    suffix = uuid.uuid4().hex[:8]
    country = AdministrativeRegion(
        code=f"TCN-{suffix}", name=f"测试国家-{suffix}", level=0,
        iso_country="TC", path=f"TCN{suffix}", is_active=True,
    )
    db_session.add(country)
    db_session.flush()
    province = AdministrativeRegion(
        code=f"TP-{suffix}", name=f"测试省-{suffix}", level=1,
        parent_id=country.id, path=f"{country.path}/TP{suffix}", is_active=True,
    )
    db_session.add(province)
    db_session.flush()
    cities = {}
    for key in ("A", "B", "C"):
        city = AdministrativeRegion(
            code=f"TC{key}-{suffix}", name=f"测试城市{key}-{suffix}", level=2,
            parent_id=province.id, path=f"{province.path}/TC{key}{suffix}",
            is_active=True,
        )
        db_session.add(city)
        cities[key] = city
    db_session.flush()

    merchant_a = Merchant(name=f"商家A-{suffix}", region_id=cities["A"].id)
    merchant_b = Merchant(name=f"商家B-{suffix}", region_id=cities["B"].id)
    merchants = [merchant_a, merchant_b]
    if with_free_merchant:
        merchants.append(Merchant(name=f"游离商家-{suffix}", region_id=None))
    db_session.add_all(merchants)
    db_session.flush()

    gram = Unit(
        name=f"克-{suffix}", abbreviation="g", unit_type="mass",
        si_factor=0.001, is_active=True,
    )
    ingredient = Ingredient(
        name=f"测试原料-{suffix}", ai_inferred=False, is_imported=False,
        is_merged=False, is_active=True,
    )
    db_session.add_all([gram, ingredient])
    db_session.flush()
    product = Product(
        name=f"测试商品-{suffix}", ingredient_id=ingredient.id,
        price_weight=50, is_active=True,
    )
    db_session.add(product)
    db_session.flush()

    now = datetime.now(timezone.utc)
    record_a = ProductRecord(
        user_id=FakeUser.id, product_id=product.id, product_name=product.name,
        merchant_id=merchant_a.id, price=PRICE_A,
        original_quantity=STD_QTY, original_unit_id=gram.id,
        standard_quantity=STD_QTY, standard_unit_id=gram.id,
        recorded_at=now - timedelta(days=2), is_active=True,
    )
    record_b = ProductRecord(
        user_id=FakeUser.id, product_id=product.id, product_name=product.name,
        merchant_id=merchant_b.id, price=PRICE_B,
        original_quantity=STD_QTY, original_unit_id=gram.id,
        standard_quantity=STD_QTY, standard_unit_id=gram.id,
        recorded_at=now - timedelta(days=1), is_active=True,
    )
    records = [record_a, record_b]
    if with_free_merchant:
        records.append(ProductRecord(
            user_id=FakeUser.id, product_id=product.id, product_name=product.name,
            merchant_id=merchants[2].id, price=PRICE_A,
            original_quantity=STD_QTY, original_unit_id=gram.id,
            standard_quantity=STD_QTY, standard_unit_id=gram.id,
            recorded_at=now - timedelta(days=2), is_active=True,
        ))
    db_session.add_all(records)
    db_session.commit()

    return {
        "suffix": suffix,
        "country": country, "province": province, "cities": cities,
        "merchant_a": merchant_a, "merchant_b": merchant_b,
        "gram": gram, "ingredient": ingredient, "product": product,
        "record_a": record_a, "record_b": record_b,
    }


def _cleanup_fixture(db_session, fx):
    from app.models.administrative_region import AdministrativeRegion
    from app.models.merchant import Merchant
    from app.models.nutrition import Ingredient
    from app.models.product import ProductRecord
    from app.models.product_entity import Product
    from app.models.unit import Unit

    db_session.query(ProductRecord).filter(
        ProductRecord.product_id == fx["product"].id
    ).delete(synchronize_session=False)
    db_session.query(Product).filter(Product.id == fx["product"].id).delete(
        synchronize_session=False
    )
    db_session.query(Ingredient).filter(Ingredient.id == fx["ingredient"].id).delete(
        synchronize_session=False
    )
    db_session.query(Merchant).filter(Merchant.name.like(
        f"%-{fx['suffix']}"
    )).delete(synchronize_session=False)
    db_session.query(Unit).filter(Unit.id == fx["gram"].id).delete(
        synchronize_session=False
    )
    city_ids = [c.id for c in fx["cities"].values()] + [fx["province"].id, fx["country"].id]
    db_session.query(AdministrativeRegion).filter(
        AdministrativeRegion.id.in_(city_ids)
    ).delete(synchronize_session=False)
    db_session.commit()


def test_comparison_regions_lists_cities_with_records(db_session):
    """地区候选：有记录的两地；游离商家不产生候选（其记录也不计入候选计数）。"""
    from app.api.comparison import list_priced_regions

    fx = _build_fixture(db_session, with_free_merchant=True)
    try:
        res = asyncio.run(list_priced_regions(
            request=_fake_request(), db=db_session, _current_user=FakeUser(),
        ))
        ids = [r.region_id for r in res.regions]
        assert fx["cities"]["A"].id in ids
        assert fx["cities"]["B"].id in ids
        assert fx["cities"]["C"].id not in ids
        by_id = {r.region_id: r for r in res.regions}
        # 候选计数按地区子树 INNER JOIN，游离商家的记录不落到任何候选上
        assert by_id[fx["cities"]["A"].id].record_count == 1
        assert by_id[fx["cities"]["A"].id].merchant_count == 1
        assert by_id[fx["cities"]["B"].id].record_count == 1
        assert all(r.display_name for r in res.regions)
    finally:
        _cleanup_fixture(db_session, fx)


def test_comparison_summary_price_index_and_trend(db_session):
    """概览：基准地区指数=100；另一地区指数=单价比率中位数×100；空地区趋势为空。"""
    from app.api.comparison import comparison_summary

    fx = _build_fixture(db_session)
    rids = f"{fx['cities']['A'].id},{fx['cities']['B'].id},{fx['cities']['C'].id}"
    try:
        res = asyncio.run(comparison_summary(
            request=_fake_request(), region_ids=rids, days=7,
            db=db_session, current_user=FakeUser(), tz="UTC",
        ))
        by_id = {r.region_id: r for r in res.regions}
        assert res.base_region_id == fx["cities"]["A"].id
        assert res.basket_size == 1  # 基准地区近一年有记录的商品
        # 基准地区：比率全为 1 → 指数 100
        assert by_id[fx["cities"]["A"].id].price_index == pytest.approx(100.0)
        # 城市B：只有该商品有数据，比率 = 100/10 → 指数 1000
        assert by_id[fx["cities"]["B"].id].price_index == pytest.approx(1000.0)
        # 城市C：子树无商家 → 无记录、无指数、无趋势
        assert by_id[fx["cities"]["C"].id].record_count == 0
        assert by_id[fx["cities"]["C"].id].price_index is None
        assert by_id[fx["cities"]["C"].id].trend == []
        # 趋势为 ¥/斤 口径：10 元/500g → 每斤 10；从记录日前向填充到今天
        trend_a = by_id[fx["cities"]["A"].id].trend
        assert len(trend_a) >= 3  # 2 天前 → 今天
        assert trend_a[-1] == pytest.approx(10.0)
        assert by_id[fx["cities"]["B"].id].trend[-1] == pytest.approx(100.0)
    finally:
        _cleanup_fixture(db_session, fx)


def test_comparison_entity_prices_ingredient_matrix(db_session):
    """原料×地区矩阵：卡片价=每标准单位综合价口径；无数据地区整格为 null。"""
    from app.api.comparison import comparison_entity_prices

    fx = _build_fixture(db_session)
    rids = f"{fx['cities']['A'].id},{fx['cities']['C'].id}"
    try:
        res = asyncio.run(comparison_entity_prices(
            _fake_request(),
            entity_type="ingredient",
            entity_ids=str(fx["ingredient"].id),
            region_ids=rids, days=7,
            db=db_session, current_user=FakeUser(), tz="UTC",
        ))
        assert len(res.entities) == 1
        row = res.entities[0]
        assert row.entity_id == fx["ingredient"].id
        assert row.name.startswith("测试原料")
        cell_a = row.regions[str(fx["cities"]["A"].id)]
        assert cell_a is not None
        assert cell_a.price == pytest.approx(UNIT_PRICE_A)
        assert cell_a.unit == "g"
        assert cell_a.days_since_record == 2
        assert cell_a.is_stale is False
        assert cell_a.participant_count == 1
        assert cell_a.trend and cell_a.trend[-1] == pytest.approx(10.0)
        # 城市C 子树无商家 → 整格 null
        assert row.regions[str(fx["cities"]["C"].id)] is None
    finally:
        _cleanup_fixture(db_session, fx)


def test_comparison_entity_prices_product_and_stale(db_session):
    """商品实体矩阵 + 30 天超期放开（唯一记录超期时仍显示价格并标 stale）。"""
    from app.api.comparison import comparison_entity_prices
    from app.models.product import ProductRecord

    fx = _build_fixture(db_session)
    try:
        # 把城市A 的记录改成 40 天前（超期）
        fx["record_a"].recorded_at = datetime.now(timezone.utc) - timedelta(days=40)
        db_session.commit()

        res = asyncio.run(comparison_entity_prices(
            _fake_request(),
            entity_type="product",
            entity_ids=str(fx["product"].id),
            region_ids=f"{fx['cities']['A'].id},{fx['cities']['B'].id}",
            days=7,
            db=db_session, current_user=FakeUser(), tz="UTC",
        ))
        row = res.entities[0]
        cell_a = row.regions[str(fx["cities"]["A"].id)]
        # 唯一记录超期 → 放开显示旧价（宁可显示旧价格，也不能没有价格）
        assert cell_a is not None
        assert cell_a.price == pytest.approx(UNIT_PRICE_A)
        assert cell_a.is_stale is True
        assert cell_a.days_since_record == 40
        # 城市B 的记录新鲜（1 天前）
        cell_b = row.regions[str(fx["cities"]["B"].id)]
        assert cell_b is not None
        assert cell_b.is_stale is False
        assert cell_b.days_since_record == 1
        assert cell_b.price == pytest.approx(UNIT_PRICE_B)
    finally:
        _cleanup_fixture(db_session, fx)


def test_comparison_entity_prices_weighted_across_products(db_session):
    """原料下两个商品（同地各一）：卡片价按权重加权，参与商品数正确。"""
    from app.api.comparison import comparison_entity_prices
    from app.models.product import ProductRecord
    from app.models.product_entity import Product

    fx = _build_fixture(db_session)
    try:
        product2 = Product(
            name=f"测试商品2-{fx['suffix']}", ingredient_id=fx["ingredient"].id,
            price_weight=50, is_active=True,
        )
        db_session.add(product2)
        db_session.flush()
        record2 = ProductRecord(
            user_id=FakeUser.id, product_id=product2.id, product_name=product2.name,
            merchant_id=fx["merchant_b"].id, price=PRICE_B,
            original_quantity=STD_QTY, original_unit_id=fx["gram"].id,
            standard_quantity=STD_QTY, standard_unit_id=fx["gram"].id,
            recorded_at=datetime.now(timezone.utc) - timedelta(days=1),
            is_active=True,
        )
        db_session.add(record2)
        db_session.commit()

        res = asyncio.run(comparison_entity_prices(
            _fake_request(),
            entity_type="ingredient",
            entity_ids=str(fx["ingredient"].id),
            region_ids=str(fx["cities"]["B"].id),
            days=7,
            db=db_session, current_user=FakeUser(), tz="UTC",
        ))
        cell = res.entities[0].regions[str(fx["cities"]["B"].id)]
        # 城市B 两个商品各一条（各 100 元/500g），等权 → 均值
        assert cell is not None
        assert cell.price == pytest.approx(UNIT_PRICE_B)
        assert cell.participant_count == 2
    finally:
        _cleanup_fixture(db_session, fx)


def test_comparison_region_ids_validation():
    """region_ids 校验：空、非数字、超过 6 个都报 400；去重保序。"""
    from app.api.comparison import _parse_region_ids
    from app.core.exceptions import LocalizedHTTPException

    with pytest.raises(LocalizedHTTPException):
        _parse_region_ids("")
    with pytest.raises(LocalizedHTTPException):
        _parse_region_ids("abc")
    with pytest.raises(LocalizedHTTPException):
        _parse_region_ids("1,2,3,4,5,6,7")
    assert _parse_region_ids("3,1,1,2") == [3, 1, 2]  # 去重保序
