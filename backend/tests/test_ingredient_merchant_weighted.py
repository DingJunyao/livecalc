"""原料级各商家价格：同商家多商品按权重加权测试（Task 2）。

覆盖 GET /api/v1/nutrition/ingredients/{id}/latest-price-by-merchant：
  - 同一商家下多个商品时，代表价按商品权重加权
  - 权重为 0 的商品被排除
"""
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


def _build(db, p1_w, p2_w, p1_price, p2_price):
    """原料 + 2 商品（同 1 商家各 1 条记录）。original 单位 = 斤 = ing_target，免单位转换。"""
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.merchant import Merchant
    from app.models.product import ProductRecord

    ing = Ingredient(name="商家加权测试原料")
    db.add(ing)
    db.commit()
    db.refresh(ing)

    p1 = Product(name="商加P1", ingredient_id=ing.id, price_weight=p1_w, is_active=True)
    p2 = Product(name="商加P2", ingredient_id=ing.id, price_weight=p2_w, is_active=True)
    db.add_all([p1, p2])
    db.commit()
    db.refresh(p1)
    db.refresh(p2)

    m = Merchant(user_id=FakeUser.id, name="商加商家", is_open=True)
    db.add(m)
    db.commit()
    db.refresh(m)

    jin = _get_or_create_jin(db)
    for prod, price in [(p1, p1_price), (p2, p2_price)]:
        db.add(ProductRecord(
            user_id=FakeUser.id, product_id=prod.id, product_name=prod.name,
            merchant_id=m.id, price=price, currency="CNY",
            original_quantity=1, original_unit_id=jin.id,
            standard_quantity=1, standard_unit_id=jin.id,
            record_type="price",
        ))
    db.commit()
    return ing.id, m.id


def _cleanup(db, ing_id, m_id):
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.merchant import Merchant
    from app.models.product import ProductRecord

    pids = [p.id for p in db.query(Product).filter(Product.ingredient_id == ing_id).all()]
    if pids:
        db.query(ProductRecord).filter(ProductRecord.product_id.in_(pids)).delete(synchronize_session=False)
    db.query(Product).filter(Product.ingredient_id == ing_id).delete(synchronize_session=False)
    db.query(Ingredient).filter(Ingredient.id == ing_id).delete(synchronize_session=False)
    db.query(Merchant).filter(Merchant.id == m_id).delete(synchronize_session=False)
    db.commit()


def test_same_merchant_multi_product_weighted(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    ing_id = m_id = None
    try:
        ing_id, m_id = _build(db, p1_w=30, p2_w=70, p1_price=10, p2_price=20)
    finally:
        db.close()

    client = TestClient(app)
    try:
        r = client.get(f"/api/v1/nutrition/ingredients/{ing_id}/latest-price-by-merchant")
        assert r.status_code == 200
        prices = r.json()["prices"]
        assert len(prices) == 1
        # 加权 = (10*30 + 20*70) / 100 = 17.0
        assert abs(prices[0]["price"] - 17.0) < 0.01
    finally:
        db = TestingSessionLocal()
        try:
            if ing_id and m_id:
                _cleanup(db, ing_id, m_id)
        finally:
            db.close()


def test_weight_zero_product_excluded_from_merchant(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    ing_id = m_id = None
    try:
        # P1 权重 0（排除），P2 权重 50 → 代表价 = P2 单价 = 20
        ing_id, m_id = _build(db, p1_w=0, p2_w=50, p1_price=10, p2_price=20)
    finally:
        db.close()

    client = TestClient(app)
    try:
        r = client.get(f"/api/v1/nutrition/ingredients/{ing_id}/latest-price-by-merchant")
        assert r.status_code == 200
        prices = r.json()["prices"]
        assert len(prices) == 1
        assert abs(prices[0]["price"] - 20.0) < 0.01
    finally:
        db = TestingSessionLocal()
        try:
            if ing_id and m_id:
                _cleanup(db, ing_id, m_id)
        finally:
            db.close()


def _build_fx(db, merchants_spec):
    """原料 + 1 商品，多商家各 1 条记录，币种/汇率由 merchants_spec 指定。

    merchants_spec: [(merchant_name, price, currency, exchange_rate), ...]
    original 单位 = 斤 = ing_target，免单位转换。
    """
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.merchant import Merchant
    from app.models.product import ProductRecord

    ing = Ingredient(name="外币商家测试原料")
    db.add(ing)
    db.commit()
    db.refresh(ing)

    p = Product(name="外币P1", ingredient_id=ing.id, price_weight=50, is_active=True)
    db.add(p)
    db.commit()
    db.refresh(p)

    merchants = []
    jin = _get_or_create_jin(db)
    for name, price, currency, rate in merchants_spec:
        m = Merchant(user_id=FakeUser.id, name=name, is_open=True)
        db.add(m)
        db.commit()
        db.refresh(m)
        merchants.append(m.id)
        db.add(ProductRecord(
            user_id=FakeUser.id, product_id=p.id, product_name=p.name,
            merchant_id=m.id, price=price, currency=currency,
            exchange_rate=rate,
            original_quantity=1, original_unit_id=jin.id,
            standard_quantity=1, standard_unit_id=jin.id,
            record_type="price",
        ))
    db.commit()
    return ing.id, merchants


def _cleanup_fx(db, ing_id, merchant_ids):
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.merchant import Merchant
    from app.models.product import ProductRecord

    pids = [p.id for p in db.query(Product).filter(Product.ingredient_id == ing_id).all()]
    if pids:
        db.query(ProductRecord).filter(ProductRecord.product_id.in_(pids)).delete(synchronize_session=False)
    db.query(Product).filter(Product.ingredient_id == ing_id).delete(synchronize_session=False)
    db.query(Ingredient).filter(Ingredient.id == ing_id).delete(synchronize_session=False)
    if merchant_ids:
        db.query(Merchant).filter(Merchant.id.in_(merchant_ids)).delete(synchronize_session=False)
    db.commit()


def test_foreign_currency_merchant_price_converted(as_admin):
    """外币商家价按 exchange_rate 折算到用户币种（蒜 25750 IDR 案例）。

    响应行 price 为折算后金额、currency 为用户币种；排序/最低价按折算后比较，
    原币面额大的 IDR 不得因原值大而排到最后或错过最低价。
    """
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    ing_id = merchant_ids = None
    try:
        # CNY 10 元/斤 vs IDR 25750（≈11.33 CNY）/斤
        ing_id, merchant_ids = _build_fx(db, [
            ("外币商家CNY", 10.0, "CNY", 1.0),
            ("外币商家IDR", 25750.0, "IDR", 0.00044),
        ])
    finally:
        db.close()

    client = TestClient(app)
    try:
        r = client.get(f"/api/v1/nutrition/ingredients/{ing_id}/latest-price-by-merchant")
        assert r.status_code == 200
        prices = r.json()["prices"]
        assert len(prices) == 2
        by_name = {p["merchant_name"]: p for p in prices}
        cny_row = by_name["外币商家CNY"]
        idr_row = by_name["外币商家IDR"]
        # IDR 行：25750 × 0.00044 = 11.33，currency=用户币种 CNY（缺失会导致前端按原值标 CNY）
        assert abs(idr_row["price"] - 11.33) < 0.01
        assert idr_row["currency"] == "CNY"
        assert cny_row["price"] == 10.0
        assert cny_row["currency"] == "CNY"
        # 排序按折算后升序，最低价标在 CNY 行
        assert [p["merchant_name"] for p in prices] == ["外币商家CNY", "外币商家IDR"]
        assert cny_row["is_lowest"] is True
        assert idr_row["is_lowest"] is False
    finally:
        db = TestingSessionLocal()
        try:
            if ing_id and merchant_ids:
                _cleanup_fx(db, ing_id, merchant_ids)
        finally:
            db.close()


def test_mixed_currency_weighted_average_converted_first(as_admin):
    """同商家多商品混币种：先各自折算到用户币种再按权重加权。

    P1 CNY 10（权重 30）+ P2 IDR 25750×0.00044≈11.33（权重 70）
    → (10×30 + 11.33×70) / 100 ≈ 10.93，而不是把 25750 当原值加权。
    """
    from starlette.testclient import TestClient
    from app.main import app
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.merchant import Merchant
    from app.models.product import ProductRecord

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    ing_id = m_id = None
    try:
        ing = Ingredient(name="混币种加权原料")
        db.add(ing)
        db.commit()
        db.refresh(ing)
        ing_id = ing.id
        p1 = Product(name="混币P1", ingredient_id=ing.id, price_weight=30, is_active=True)
        p2 = Product(name="混币P2", ingredient_id=ing.id, price_weight=70, is_active=True)
        db.add_all([p1, p2])
        db.commit()
        db.refresh(p1)
        db.refresh(p2)
        m = Merchant(user_id=FakeUser.id, name="混币商家", is_open=True)
        db.add(m)
        db.commit()
        db.refresh(m)
        m_id = m.id
        jin = _get_or_create_jin(db)
        db.add(ProductRecord(
            user_id=FakeUser.id, product_id=p1.id, product_name=p1.name,
            merchant_id=m.id, price=10.0, currency="CNY", exchange_rate=1.0,
            original_quantity=1, original_unit_id=jin.id,
            standard_quantity=1, standard_unit_id=jin.id,
            record_type="price",
        ))
        db.add(ProductRecord(
            user_id=FakeUser.id, product_id=p2.id, product_name=p2.name,
            merchant_id=m.id, price=25750.0, currency="IDR", exchange_rate=0.00044,
            original_quantity=1, original_unit_id=jin.id,
            standard_quantity=1, standard_unit_id=jin.id,
            record_type="price",
        ))
        db.commit()
    finally:
        db.close()

    client = TestClient(app)
    try:
        r = client.get(f"/api/v1/nutrition/ingredients/{ing_id}/latest-price-by-merchant")
        assert r.status_code == 200
        prices = r.json()["prices"]
        assert len(prices) == 1
        # 加权 = (10*30 + 11.33*70) / 100 = 10.931 → 10.93
        assert abs(prices[0]["price"] - 10.93) < 0.01
        assert prices[0]["currency"] == "CNY"
    finally:
        db = TestingSessionLocal()
        try:
            if ing_id and m_id:
                _cleanup_fx(db, ing_id, [m_id])
        finally:
            db.close()
