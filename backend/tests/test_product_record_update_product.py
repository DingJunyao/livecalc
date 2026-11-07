"""编辑价格记录时允许换绑商品。

回归背景：ProductRecordUpdate 此前没有 product_id 字段，编辑价格记录
无法把记录换到另一个商品（web 编辑对话框里商品可选但保存被丢弃，
移动端商品干脆只读）。换绑后要求：
- 商品必须存在（活跃），显式置空拒绝（商品是记录必填归属）；
- 记录上的冗余快照 product_name 同步为新商品名；
- 标准量换算按新商品上下文重算（自定义单位换算按商品挂靠）。
"""
from datetime import datetime, timezone

from conftest import TestingSessionLocal, engine, FakeUser
from app.core.database import Base


def _unit(db, name, abbr, unit_type, si_factor=None):
    from app.models.unit import Unit
    u = db.query(Unit).filter(Unit.abbreviation == abbr).first()
    if u:
        return u
    u = Unit(name=name, abbreviation=abbr, unit_type=unit_type, si_factor=si_factor)
    db.add(u)
    db.commit()
    db.refresh(u)
    return u


def _build(db):
    """商品 A（记录挂靠）+ 商品 B（换绑目标）+ 一条 1 斤记录。"""
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.merchant import Merchant
    from app.models.product import ProductRecord

    jin = _unit(db, "斤", "斤", "mass", si_factor=0.5)
    gram = _unit(db, "克", "g", "mass", si_factor=0.001)

    ing = Ingredient(name="换绑测试原料")
    db.add(ing)
    db.commit()
    db.refresh(ing)

    pa = Product(name="换绑测试商品A", ingredient_id=ing.id, price_weight=50, is_active=True)
    pb = Product(name="换绑测试商品B", ingredient_id=ing.id, price_weight=50, is_active=True)
    db.add_all([pa, pb])
    db.commit()
    db.refresh(pa)
    db.refresh(pb)

    m = Merchant(user_id=FakeUser.id, name="换绑测试商家", is_open=True)
    db.add(m)
    db.commit()
    db.refresh(m)

    now = datetime.now(timezone.utc).replace(tzinfo=None)
    rec = ProductRecord(
        user_id=FakeUser.id, product_id=pa.id, product_name=pa.name,
        merchant_id=m.id, price=10, currency="CNY",
        original_quantity=1, original_unit_id=jin.id,
        standard_quantity=500, standard_unit_id=gram.id,
        record_type="price", recorded_at=now, is_active=True,
    )
    db.add(rec)
    db.commit()
    db.refresh(rec)
    return rec.id, pa.id, pb.id


def _cleanup(db, record_id, product_ids):
    from app.models.merchant import Merchant
    from app.models.nutrition import Ingredient
    from app.models.product import ProductRecord
    from app.models.product_entity import Product

    if record_id:
        db.query(ProductRecord).filter(ProductRecord.id == record_id).delete(synchronize_session=False)
    if product_ids:
        db.query(Product).filter(Product.id.in_(product_ids)).delete(synchronize_session=False)
    db.query(Ingredient).filter(Ingredient.name == "换绑测试原料").delete(synchronize_session=False)
    db.query(Merchant).filter(Merchant.name == "换绑测试商家").delete(synchronize_session=False)
    db.commit()


def _put(client, record_id, payload):
    return client.put(f"/api/v1/products/{record_id}", json=payload)


def test_update_record_change_product(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    record_id = pa_id = pb_id = None
    try:
        record_id, pa_id, pb_id = _build(db)
    finally:
        db.close()

    client = TestClient(app)
    try:
        r = _put(client, record_id, {"product_id": pb_id})
        assert r.status_code == 200, r.text
        data = r.json()
        # 记录换绑到商品 B，商品名快照同步
        assert data["product_id"] == pb_id
        assert data["product_name"] == "换绑测试商品B"
        # 未传数量/单位时沿用 1 斤，标准量按新商品上下文重算仍为 500 g
        assert float(data["standard_quantity"]) == 500

        # 换绑 + 改数量：标准量按新值重算
        r = _put(client, record_id, {"product_id": pa_id, "original_quantity": 2, "original_unit": "斤"})
        assert r.status_code == 200, r.text
        data = r.json()
        assert data["product_id"] == pa_id
        assert data["product_name"] == "换绑测试商品A"
        assert float(data["standard_quantity"]) == 1000
    finally:
        db = TestingSessionLocal()
        try:
            _cleanup(db, record_id, [pa_id, pb_id])
        finally:
            db.close()


def test_update_record_product_required(as_admin):
    """product_id 显式置空拒绝（商品是记录的必填归属）。"""
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    record_id = pa_id = pb_id = None
    try:
        record_id, pa_id, pb_id = _build(db)
    finally:
        db.close()

    client = TestClient(app)
    try:
        r = _put(client, record_id, {"product_id": None})
        assert r.status_code == 400
    finally:
        db = TestingSessionLocal()
        try:
            _cleanup(db, record_id, [pa_id, pb_id])
        finally:
            db.close()


def test_update_record_unknown_product(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    record_id = pa_id = pb_id = None
    try:
        record_id, pa_id, pb_id = _build(db)
    finally:
        db.close()

    client = TestClient(app)
    try:
        r = _put(client, record_id, {"product_id": 99999999})
        assert r.status_code == 404
    finally:
        db = TestingSessionLocal()
        try:
            _cleanup(db, record_id, [pa_id, pb_id])
        finally:
            db.close()
