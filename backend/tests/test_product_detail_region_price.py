"""商品详情「最新价格」的地区口径回归测试。

背景：GET /products/entity/{product_id} 此前不做地区过滤，导致详情页「最新价格」
卡片把用户所选计算范围之外的商家记录算进来（例：空心菜 277，湖滨区范围内的最新价
是 3.78 元/斤，卡片却显示南京商家的 16.67 元/斤），与同一页面的价格记录列表、
价格趋势图口径不一致。

覆盖：
  - 带 X-Region（会话地区覆盖）时，最新价格只取该地区子树内商家的记录
  - 不带 X-Region 且用户未设置地区时，保持原有「不过滤」行为
"""
from datetime import datetime

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


def _region(db, id_, name, level, path, parent_id=None):
    from app.models.administrative_region import AdministrativeRegion
    r = db.query(AdministrativeRegion).filter(AdministrativeRegion.id == id_).first()
    if r:
        return r, False
    r = AdministrativeRegion(
        id=id_, code=f"T{id_}", name=name, level=level,
        iso_country="CN", path=path, parent_id=parent_id, is_active=True,
    )
    db.add(r)
    db.commit()
    return r, True


def _build(db):
    """构造：三门峡市(湖滨区) 商家 3.0 元的旧记录 + 南京(浦口区) 商家 10.0 元的新记录。"""
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.merchant import Merchant
    from app.models.product import ProductRecord

    jin = _get_or_create_jin(db)

    created_regions = []
    for rid, name, level, path, parent in [
        (900001, "测试国", 0, "TCN", None),
        (900041, "测试省A", 1, "TCN/900041", 900001),
        (900042, "测试市A", 2, "TCN/900041/900042", 900041),
        (900043, "测试县A", 3, "TCN/900041/900042/900043", 900042),
        (900131, "测试省B", 1, "TCN/900131", 900001),
        (900132, "测试市B", 2, "TCN/900131/900132", 900131),
        (900133, "测试县B", 3, "TCN/900131/900132/900133", 900132),
    ]:
        _, created = _region(db, rid, name, level, path, parent)
        if created:
            created_regions.append(rid)

    ing = Ingredient(name="地区口径测试原料")
    db.add(ing)
    db.commit()
    db.refresh(ing)

    p = Product(name="地区口径测试商品", ingredient_id=ing.id, price_weight=50, is_active=True)
    db.add(p)
    db.commit()
    db.refresh(p)

    m_in = Merchant(user_id=FakeUser.id, name="测试市A商家", is_open=True, region_id=900043)
    m_out = Merchant(user_id=FakeUser.id, name="测试市B商家", is_open=True, region_id=900133)
    db.add_all([m_in, m_out])
    db.commit()
    db.refresh(m_in)
    db.refresh(m_out)

    def rec(merchant, price, when):
        db.add(ProductRecord(
            user_id=FakeUser.id, product_id=p.id, product_name=p.name,
            merchant_id=merchant.id, price=price, currency="CNY", user_currency="CNY",
            original_quantity=1, original_unit_id=jin.id,
            standard_quantity=500, standard_unit_id=jin.id,
            record_type="price", recorded_at=when,
        ))

    # 范围内：较早的 3.0 元；范围外：更晚的 10.0 元
    rec(m_in, 3.0, datetime(2026, 6, 17, 3, 20))
    rec(m_out, 10.0, datetime(2026, 7, 29, 11, 42))
    db.commit()

    return {
        "product_id": p.id,
        "ingredient_id": ing.id,
        "merchant_ids": [m_in.id, m_out.id],
        "created_regions": created_regions,
    }


def _cleanup(db, ids):
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.merchant import Merchant
    from app.models.product import ProductRecord
    from app.models.administrative_region import AdministrativeRegion

    db.query(ProductRecord).filter(ProductRecord.product_id == ids["product_id"]).delete(synchronize_session=False)
    db.query(Product).filter(Product.id == ids["product_id"]).delete(synchronize_session=False)
    db.query(Ingredient).filter(Ingredient.id == ids["ingredient_id"]).delete(synchronize_session=False)
    db.query(Merchant).filter(Merchant.id.in_(ids["merchant_ids"])).delete(synchronize_session=False)
    if ids["created_regions"]:
        # 先删子节点（level 更大）再删父节点，避免外键约束
        for region in db.query(AdministrativeRegion).filter(
            AdministrativeRegion.id.in_(ids["created_regions"])
        ).order_by(AdministrativeRegion.level.desc()).all():
            db.delete(region)
    db.commit()


def test_latest_price_respects_session_region(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    ids = None
    try:
        ids = _build(db)
        client = TestClient(app)
        url = f"/api/v1/products/entity/{ids['product_id']}"

        # 会话地区覆盖到「测试市A」(900042，含下级 900043)：只统计范围内商家的 3.0 元
        r = client.get(url, headers={"X-Region": "900042"})
        assert r.status_code == 200, r.text
        body = r.json()
        assert body["latest_price"] == 3.0
        assert (body["latest_price_date"] or "").startswith("2026-06-17")

        # 覆盖到县级 900043 结果相同
        r = client.get(url, headers={"X-Region": "900043"})
        assert r.status_code == 200, r.text
        assert r.json()["latest_price"] == 3.0

        # 无覆盖且用户未设置地区：保持不过滤（原行为），取更晚的 10.0 元
        r = client.get(url)
        assert r.status_code == 200, r.text
        assert r.json()["latest_price"] == 10.0
    finally:
        if ids:
            _cleanup(db, ids)
        db.close()
