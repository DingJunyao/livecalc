"""原料 sparkline：as-of 加权（每商品最近一次价格向前携带）。

覆盖 GET /api/v1/sparklines/ingredients：
  - 窗口内没有新记录的商品，其窗口前的最近一次价格继续参与每日加权
    （旧口径下该商品整段消失，综合价退化成单品价）
  - 序列按本地日历日一格一天，覆盖窗口起点到今天
  - 最近一次价格超过 30 天的商品不再参与（与综合最新价 excluded[stale] 同规则）
并回归 GET /api/v1/sparklines/products（_fetch_recent_records 曾漏选
standard_unit_id，取价时抛 AttributeError → 500）。
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


def _build(db):
    """原料 + 2 商品：P1 40 天前 10.00，P2 5 天前 20.00（等权重）。"""
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.product import ProductRecord

    ing = Ingredient(name="sparkline as-of 测试原料")
    db.add(ing)
    db.commit()
    db.refresh(ing)

    p1 = Product(name="asofP1", ingredient_id=ing.id, price_weight=50, is_active=True)
    p2 = Product(name="asofP2", ingredient_id=ing.id, price_weight=50, is_active=True)
    db.add_all([p1, p2])
    db.commit()
    db.refresh(p1)
    db.refresh(p2)

    gram = _get_or_create_unit(db, "克", "mass", 0.001)
    now = datetime.utcnow()
    for prod, price, days_ago in ((p1, 10.0, 40), (p2, 20.0, 5)):
        db.add(ProductRecord(
            user_id=FakeUser.id, product_id=prod.id, product_name=prod.name,
            price=price, currency="CNY",
            original_quantity=500, original_unit_id=gram.id,
            standard_quantity=500, standard_unit_id=gram.id,
            record_type="price", recorded_at=now - timedelta(days=days_ago),
            is_active=True,
        ))
    db.commit()
    return ing.id, p1.id, p2.id


def _cleanup(db, ing_id, pids):
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.product import ProductRecord

    db.query(ProductRecord).filter(ProductRecord.product_id.in_(pids)).delete(
        synchronize_session=False
    )
    db.query(Product).filter(Product.ingredient_id == ing_id).delete(synchronize_session=False)
    db.query(Ingredient).filter(Ingredient.id == ing_id).delete(synchronize_session=False)
    db.commit()


def test_ingredient_sparkline_carries_stale_product_forward(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    ing_id = pids = None
    try:
        ing_id, p1, p2 = _build(db)
        pids = [p1, p2]
    finally:
        db.close()

    client = TestClient(app)
    try:
        r = client.get(
            "/api/v1/sparklines/ingredients",
            params={"ids": str(ing_id), "days": 30},
        )
        assert r.status_code == 200
        series = r.json()[str(ing_id)]
        assert series is not None
        # P1 记录于 40 天前：窗口起点（今天 -30）时「年龄」10 天，仍参与
        assert series[0] == 10.0
        # P1 参与到「记录后 30 天」（今天 -10）；之后到 P2 出现前无参与者、不产出点
        assert len(series) == 27
        assert series[20] == 10.0
        assert series[21] == 20.0
        assert series[-1] == 20.0
        assert 15.0 not in series
    finally:
        db = TestingSessionLocal()
        try:
            _cleanup(db, ing_id, pids)
        finally:
            db.close()


def test_products_sparkline_returns_series(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    ing_id = pids = None
    try:
        ing_id, p1, p2 = _build(db)
        pids = [p1, p2]
    finally:
        db.close()

    client = TestClient(app)
    try:
        r = client.get(
            "/api/v1/sparklines/products",
            params={"ids": f"{p1},{p2}", "days": 90},
        )
        assert r.status_code == 200
        body = r.json()
        assert body[str(p1)]
        assert body[str(p2)]
        assert body[str(p1)][-1] == 10.0
    finally:
        db = TestingSessionLocal()
        try:
            _cleanup(db, ing_id, pids)
        finally:
            db.close()
