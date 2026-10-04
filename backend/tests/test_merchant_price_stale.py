"""各商家最新价的陈旧判定测试。

覆盖商品 / 原料两个 latest-price-by-merchant 端点：
  - 超过 30 天的陈旧记录排到最后、is_stale=True
  - 陈旧记录哪怕价格最低也不参与最低价比较
  - 全部陈旧时不标注最低价
"""
from datetime import datetime, timedelta, timezone

from conftest import TestingSessionLocal, engine, FakeUser
from app.core.database import Base


def _get_or_create_jin(db):
    from app.models.unit import Unit
    u = db.query(Unit).filter(Unit.abbreviation == "斤").first()
    if u:
        return u
    u = Unit(name="斤", abbreviation="斤", unit_type="mass")
    db.add(u)
    db.commit()
    db.refresh(u)
    return u


def _build(db, days_ago_by_merchant, shared_product=False):
    """原料 + 每商家 1 条记录。original 单位 = 斤 = 折算目标，免单位转换。

    days_ago_by_merchant: [(merchant_name, price, days_ago)]
    shared_product=True 时所有记录挂在同一商品上（商品端点场景：各商家对同一商品报价），
    否则每商家各 1 商品（原料端点场景）。
    返回 (ing_id, product_ids, merchant_ids)
    """
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.merchant import Merchant
    from app.models.product import ProductRecord

    ing = Ingredient(name="陈旧判定测试原料")
    db.add(ing)
    db.commit()
    db.refresh(ing)

    jin = _get_or_create_jin(db)
    shared_p = None
    if shared_product:
        shared_p = Product(name="陈旧判定P-共享", ingredient_id=ing.id, price_weight=50, is_active=True)
        db.add(shared_p)
        db.commit()
        db.refresh(shared_p)

    product_ids, merchant_ids = [], []
    for m_name, price, days_ago in days_ago_by_merchant:
        if shared_p is not None:
            p = shared_p
        else:
            p = Product(name=f"陈旧判定P-{m_name}", ingredient_id=ing.id, price_weight=50, is_active=True)
            db.add(p)
            db.commit()
            db.refresh(p)
        m = Merchant(user_id=FakeUser.id, name=m_name, is_open=True)
        db.add(m)
        db.commit()
        db.refresh(m)
        db.add(ProductRecord(
            user_id=FakeUser.id, product_id=p.id, product_name=p.name,
            merchant_id=m.id, price=price, currency="CNY",
            original_quantity=1, original_unit_id=jin.id,
            standard_quantity=1, standard_unit_id=jin.id,
            record_type="price",
            recorded_at=datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=days_ago),
        ))
        db.commit()
        if p.id not in product_ids:
            product_ids.append(p.id)
        merchant_ids.append(m.id)
    return ing.id, product_ids, merchant_ids


def _cleanup(db, ing_id, product_ids, merchant_ids):
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.merchant import Merchant
    from app.models.product import ProductRecord

    if product_ids:
        db.query(ProductRecord).filter(ProductRecord.product_id.in_(product_ids)).delete(synchronize_session=False)
    db.query(Product).filter(Product.ingredient_id == ing_id).delete(synchronize_session=False)
    db.query(Ingredient).filter(Ingredient.id == ing_id).delete(synchronize_session=False)
    if merchant_ids:
        db.query(Merchant).filter(Merchant.id.in_(merchant_ids)).delete(synchronize_session=False)
    db.commit()


def _run(client, url):
    r = client.get(url)
    assert r.status_code == 200
    return r.json()["prices"]


def test_product_stale_sorted_last_and_excluded_from_lowest(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    ids = None
    try:
        # 陈旧商家价更低（3 < 8），但 31 天前的记录不参与最低价比较
        ids = _build(db, [("新鲜商家", 8, 2), ("陈旧商家", 3, 31)], shared_product=True)
    finally:
        db.close()

    client = TestClient(app)
    try:
        prices = _run(client, f"/api/v1/products/entity/{ids[1][0]}/latest-price-by-merchant")
        assert len(prices) == 2
        assert prices[0]["merchant_name"] == "新鲜商家"
        assert prices[0]["is_stale"] is False
        assert prices[0]["is_lowest"] is True
        assert prices[1]["merchant_name"] == "陈旧商家"
        assert prices[1]["is_stale"] is True
        assert prices[1]["is_lowest"] is False
        assert prices[1]["recorded_at"] is not None
    finally:
        db = TestingSessionLocal()
        try:
            _cleanup(db, *ids)
        finally:
            db.close()


def test_product_all_stale_no_lowest(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    ids = None
    try:
        ids = _build(db, [("旧商家A", 5, 40), ("旧商家B", 6, 60)], shared_product=True)
    finally:
        db.close()

    client = TestClient(app)
    try:
        prices = _run(client, f"/api/v1/products/entity/{ids[1][0]}/latest-price-by-merchant")
        assert len(prices) == 2
        # 全部陈旧：按价升序，但都不标最低价
        assert prices[0]["merchant_name"] == "旧商家A"
        assert all(p["is_stale"] is True for p in prices)
        assert all(p["is_lowest"] is False for p in prices)
    finally:
        db = TestingSessionLocal()
        try:
            _cleanup(db, *ids)
        finally:
            db.close()


def test_ingredient_stale_sorted_last_and_excluded_from_lowest(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    ids = None
    try:
        ids = _build(db, [("新鲜商家", 8, 2), ("陈旧商家", 3, 31)], shared_product=True)
    finally:
        db.close()

    client = TestClient(app)
    try:
        prices = _run(client, f"/api/v1/nutrition/ingredients/{ids[0]}/latest-price-by-merchant")
        assert len(prices) == 2
        assert prices[0]["merchant_name"] == "新鲜商家"
        assert prices[0]["is_stale"] is False
        assert prices[0]["is_lowest"] is True
        assert prices[1]["merchant_name"] == "陈旧商家"
        assert prices[1]["is_stale"] is True
        assert prices[1]["is_lowest"] is False
    finally:
        db = TestingSessionLocal()
        try:
            _cleanup(db, *ids)
        finally:
            db.close()


def test_ingredient_fresh_unchanged(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    ids = None
    try:
        # 全部新鲜：行为与旧版一致（最低价标在第一条）
        ids = _build(db, [("甲商家", 9, 1), ("乙商家", 7, 10)])
    finally:
        db.close()

    client = TestClient(app)
    try:
        prices = _run(client, f"/api/v1/nutrition/ingredients/{ids[0]}/latest-price-by-merchant")
        assert len(prices) == 2
        assert prices[0]["merchant_name"] == "乙商家"
        assert prices[0]["is_lowest"] is True
        assert prices[0]["is_stale"] is False
        assert prices[1]["is_lowest"] is False
    finally:
        db = TestingSessionLocal()
        try:
            _cleanup(db, *ids)
        finally:
            db.close()
