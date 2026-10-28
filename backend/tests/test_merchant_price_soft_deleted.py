"""价格记录软删除后不得再出现在「各商家价格」/最近价中。

回归背景（真实数据）：商品 1136 有一条已软删的「千禧三分店」记录
（is_active=0），价格记录列表已不可见，但 /latest-price-by-merchant
仍把它当作该商家的最新价返回，造成「各商家价格有、价格记录没有」。
覆盖商品 / 原料两个 latest-price-by-merchant 端点 + 商品最近价端点，
并与价格记录列表口径对齐。
"""
from datetime import datetime, timezone

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


def _get_or_create_gram(db):
    """standard_quantity 的口径是克：500 g = 1 斤。"""
    from app.models.unit import Unit
    u = db.query(Unit).filter(Unit.abbreviation == "g").first()
    if u:
        return u
    u = Unit(name="克", abbreviation="g", unit_type="mass")
    db.add(u)
    db.commit()
    db.refresh(u)
    return u


def _build(db):
    """同一原料/商品下：有效商家 1 条 + 已软删商家 1 条（价格更低）。"""
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.merchant import Merchant
    from app.models.product import ProductRecord

    ing = Ingredient(name="软删除回归原料")
    db.add(ing)
    db.commit()
    db.refresh(ing)

    jin = _get_or_create_jin(db)
    gram = _get_or_create_gram(db)
    p = Product(name="软删除回归商品", ingredient_id=ing.id, price_weight=50, is_active=True)
    db.add(p)
    db.commit()
    db.refresh(p)

    now = datetime.now(timezone.utc).replace(tzinfo=None)

    def _merchant(name):
        m = Merchant(user_id=FakeUser.id, name=name, is_open=True)
        db.add(m)
        db.commit()
        db.refresh(m)
        return m

    m_ok = _merchant("软删除回归-有效商家")
    m_del = _merchant("软删除回归-已删商家")

    db.add(ProductRecord(
        user_id=FakeUser.id, product_id=p.id, product_name=p.name,
        merchant_id=m_ok.id, price=10, currency="CNY",
        original_quantity=1, original_unit_id=jin.id,
        standard_quantity=500, standard_unit_id=gram.id,
        record_type="price", recorded_at=now, is_active=True,
    ))
    db.add(ProductRecord(
        user_id=FakeUser.id, product_id=p.id, product_name=p.name,
        merchant_id=m_del.id, price=2, currency="CNY",
        original_quantity=1, original_unit_id=jin.id,
        standard_quantity=500, standard_unit_id=gram.id,
        record_type="price", recorded_at=now, is_active=False,
    ))
    db.commit()
    return ing.id, p.id, [m_ok.id, m_del.id]


def _cleanup(db, ing_id, product_id, merchant_ids):
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.merchant import Merchant
    from app.models.product import ProductRecord

    if product_id:
        db.query(ProductRecord).filter(ProductRecord.product_id == product_id).delete(synchronize_session=False)
        db.query(Product).filter(Product.id == product_id).delete(synchronize_session=False)
    if ing_id:
        db.query(Ingredient).filter(Ingredient.id == ing_id).delete(synchronize_session=False)
    if merchant_ids:
        db.query(Merchant).filter(Merchant.id.in_(merchant_ids)).delete(synchronize_session=False)
    db.commit()


def test_soft_deleted_record_excluded_from_prices(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    ing_id = product_id = None
    merchant_ids = []
    try:
        ing_id, product_id, merchant_ids = _build(db)
    finally:
        db.close()

    client = TestClient(app)
    try:
        # 商品各商家价格：只剩有效商家（已软删商家的 2 元不得出现/参与最低价）
        r = client.get(f"/api/v1/products/entity/{product_id}/latest-price-by-merchant")
        assert r.status_code == 200
        prices = r.json()["prices"]
        assert [x["merchant_name"] for x in prices] == ["软删除回归-有效商家"]
        assert prices[0]["price"] == 10
        assert prices[0]["is_lowest"] is True

        # 原料各商家价格：同样只剩有效商家
        r = client.get(f"/api/v1/nutrition/ingredients/{ing_id}/latest-price-by-merchant")
        assert r.status_code == 200
        prices = r.json()["prices"]
        assert [x["merchant_name"] for x in prices] == ["软删除回归-有效商家"]

        # 价格记录列表：只有 1 条，与「各商家价格」口径一致
        r = client.get("/api/v1/products/", params={"product_id": product_id})
        assert r.status_code == 200
        assert r.json()["total"] == 1

        # 商品最近价：只按有效记录计算（10，而不是 (10+2)/2=6）
        r = client.get(f"/api/v1/products/entity/{product_id}/latest-price")
        assert r.status_code == 200
        assert r.json()["average_price"] == 10
    finally:
        db = TestingSessionLocal()
        try:
            _cleanup(db, ing_id, product_id, merchant_ids)
        finally:
            db.close()
