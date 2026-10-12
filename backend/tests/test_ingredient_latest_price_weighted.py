"""原料综合最新价：每商品「最近有记录日」→ 商品间按权重加权。

覆盖 GET /api/v1/nutrition/ingredients/{id}/latest-price：
  - 各商品的最近有记录日各自独立（同日多条记录取当日均价）
  - 最近有记录日超过 24 小时的商品仍参与加权（旧口径下会被整段排除）
  - price_weight=0 的商品被排除并出现在 excluded
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


def _build(db, p2_weight: int = 50):
    """原料 + 3 商品（等权重时综合价 = (1.20 + 4.00 + 0.80) / 3 = 2.00）。

    P1：2 天前，同日两条 1.10 / 1.30 → 当日均价 1.20
    P2：60 天前，4.00
    P3：今天（1 小时前），0.80
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
        (p1, 1.10, now - timedelta(days=2, hours=2)),
        (p1, 1.30, now - timedelta(days=2, hours=1)),
        (p2, 4.00, now - timedelta(days=60)),
        (p3, 0.80, now - timedelta(hours=1)),
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


def test_latest_price_includes_products_with_stale_records(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    ing_id = pids = None
    try:
        ing_id, pids = _build(db)
    finally:
        db.close()

    client = TestClient(app)
    try:
        r = client.get(f"/api/v1/nutrition/ingredients/{ing_id}/latest-price")
        assert r.status_code == 200
        data = r.json()
        # 三个商品都参与：60 天前的记录不再被 24 小时窗口排掉
        assert data["average_price"] == 2.0
        assert data["mode"] == "weighted"
        assert len(data["participants"]) == 3
        assert {p["name"] for p in data["participants"]} == {"综合价P1", "综合价P2", "综合价P3"}
        # 商品内同日多条取均价
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
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    ing_id = pids = None
    try:
        ing_id, pids = _build(db, p2_weight=0)
    finally:
        db.close()

    client = TestClient(app)
    try:
        r = client.get(f"/api/v1/nutrition/ingredients/{ing_id}/latest-price")
        assert r.status_code == 200
        data = r.json()
        # 权重 0 排除 P2（4.00）→ (1.20 + 0.80) / 2 = 1.00
        assert data["average_price"] == 1.0
        assert {p["name"] for p in data["participants"]} == {"综合价P1", "综合价P3"}
        assert any(
            e["name"] == "综合价P2" and e["reason"] == "weight_zero"
            for e in data["excluded"]
        )
    finally:
        db = TestingSessionLocal()
        try:
            if ing_id and pids:
                _cleanup(db, ing_id, pids)
        finally:
            db.close()
