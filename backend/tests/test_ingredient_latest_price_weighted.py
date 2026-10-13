"""原料综合最新价：每商品「最近有记录日」→ 商品间按权重加权。

覆盖 GET /api/v1/nutrition/ingredients/{id}/latest-price：
  - 各商品的最近有记录日各自独立（同日多条记录取当日均价）
  - 最近一次价格超过 30 天（INGREDIENT_PRICE_STALE_DAYS）的商品被排除（reason=stale）
  - price_weight=0 的商品被排除（reason=weight_zero）
"""
from datetime import datetime, timedelta

from conftest import TestingSessionLocal, engine, FakeUser
from app.core.database import Base


def _get_or_create_unit(db, name: str, unit_type: str = "mass", si_factor: float = 1.0):
    from app.models.unit import Unit
    u = db.query(Unit).filter(Unit.name == name).first()
    if u:
        return u
    u = Unit(name=name, abbreviation=name, unit_type=unit_type, si_factor=si_factor)
    db.add(u)
    db.commit()
    db.refresh(u)
    return u


def _build(db, p2_days_ago: int, p2_weight: int = 50, p1_days_ago: float = 2, p3_days_ago: float = 0):
    """原料 + 3 商品：

    P1：p1_days_ago 天前，同日两条 1.10 / 1.30 → 当日均价 1.20
    P2：p2_days_ago 天前，4.00（权重 p2_weight）
    P3：p3_days_ago 天前，0.80
    """
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.product import ProductRecord

    ing = Ingredient(name="综合价加权测试原料")
    db.add(ing)
    db.commit()
    db.refresh(ing)

    p1 = Product(name="综合价P1", ingredient_id=ing.id, price_weight=50, is_active=True)
    p2 = Product(name="综合价P2", ingredient_id=ing.id, price_weight=p2_weight, is_active=True)
    p3 = Product(name="综合价P3", ingredient_id=ing.id, price_weight=50, is_active=True)
    db.add_all([p1, p2, p3])
    db.commit()
    for p in (p1, p2, p3):
        db.refresh(p)

    jin = _get_or_create_unit(db, "斤", "mass", 0.5)
    now = datetime.utcnow()
    plan = [
        (p1, 1.10, now - timedelta(days=p1_days_ago, hours=2)),
        (p1, 1.30, now - timedelta(days=p1_days_ago, hours=1)),
        (p2, 4.00, now - timedelta(days=p2_days_ago)),
        (p3, 0.80, now - timedelta(days=p3_days_ago, hours=1)),
    ]
    for prod, price, recorded_at in plan:
        db.add(ProductRecord(
            user_id=FakeUser.id, product_id=prod.id, product_name=prod.name,
            price=price, currency="CNY",
            original_quantity=1, original_unit_id=jin.id,
            standard_quantity=1, standard_unit_id=jin.id,
            record_type="price", recorded_at=recorded_at, is_active=True,
        ))
    db.commit()
    return ing.id, [p1.id, p2.id, p3.id]


def _cleanup(db, ing_id, pids):
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.product import ProductRecord

    if pids:
        db.query(ProductRecord).filter(ProductRecord.product_id.in_(pids)).delete(
            synchronize_session=False
        )
    db.query(Product).filter(Product.ingredient_id == ing_id).delete(synchronize_session=False)
    db.query(Ingredient).filter(Ingredient.id == ing_id).delete(synchronize_session=False)
    db.commit()


def _get_latest_price(ing_id: int):
    from starlette.testclient import TestClient
    from app.main import app

    client = TestClient(app)
    r = client.get(f"/api/v1/nutrition/ingredients/{ing_id}/latest-price")
    assert r.status_code == 200
    return r.json()


def test_latest_price_excludes_stale_product(as_admin):
    """60 天前的价格不再参与综合价（否则会长期主导，且与图表对不上）。"""
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    ing_id = pids = None
    try:
        ing_id, pids = _build(db, p2_days_ago=60)
    finally:
        db.close()

    try:
        data = _get_latest_price(ing_id)
        # (1.20 + 0.80) / 2 = 1.00
        assert data["average_price"] == 1.0
        assert data["mode"] == "weighted"
        assert {p["name"] for p in data["participants"]} == {"综合价P1", "综合价P3"}
        stale = next(e for e in data["excluded"] if e["name"] == "综合价P2")
        assert stale["reason"] == "stale"
        assert data["stale_relaxed"] is False
    finally:
        db = TestingSessionLocal()
        try:
            if ing_id and pids:
                _cleanup(db, ing_id, pids)
        finally:
            db.close()


def test_latest_price_includes_recent_product(as_admin):
    """29 天前（< 30 天上限）的记录仍参与加权。"""
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    ing_id = pids = None
    try:
        ing_id, pids = _build(db, p2_days_ago=29)
    finally:
        db.close()

    try:
        data = _get_latest_price(ing_id)
        # (1.20 + 4.00 + 0.80) / 3 = 2.00
        assert data["average_price"] == 2.0
        assert len(data["participants"]) == 3
        p1 = next(p for p in data["participants"] if p["name"] == "综合价P1")
        assert p1["unit_price"] == 1.2
        assert p1["record_count"] == 2
        assert data["latest_date"] is not None
    finally:
        db = TestingSessionLocal()
        try:
            if ing_id and pids:
                _cleanup(db, ing_id, pids)
        finally:
            db.close()


def test_latest_price_excludes_zero_weight_product(as_admin):
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    ing_id = pids = None
    try:
        ing_id, pids = _build(db, p2_days_ago=2, p2_weight=0)
    finally:
        db.close()

    try:
        data = _get_latest_price(ing_id)
        # 权重 0 排除 P2（4.00）→ (1.20 + 0.80) / 2 = 1.00
        assert data["average_price"] == 1.0
        assert {p["name"] for p in data["participants"]} == {"综合价P1", "综合价P3"}
        assert any(
            e["name"] == "综合价P2" and e["reason"] == "weight_zero"
            for e in data["excluded"]
        )
        assert data["stale_relaxed"] is False
    finally:
        db = TestingSessionLocal()
        try:
            if ing_id and pids:
                _cleanup(db, ing_id, pids)
        finally:
            db.close()


def test_latest_price_relaxes_when_all_products_stale(as_admin):
    """全部商品都超过 30 天 → 放开上限（宁可显示旧价格，也不能没有价格）。"""
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    ing_id = pids = None
    try:
        ing_id, pids = _build(db, p2_days_ago=90, p1_days_ago=60, p3_days_ago=70)
    finally:
        db.close()

    try:
        data = _get_latest_price(ing_id)
        # 放开后三个商品都参与：(1.20 + 4.00 + 0.80) / 3 = 2.00
        assert data["average_price"] == 2.0
        assert data["stale_relaxed"] is True
        assert {p["name"] for p in data["participants"]} == {"综合价P1", "综合价P2", "综合价P3"}
        assert data["excluded"] == []
        assert data["latest_date"] is not None
    finally:
        db = TestingSessionLocal()
        try:
            if ing_id and pids:
                _cleanup(db, ing_id, pids)
        finally:
            db.close()
