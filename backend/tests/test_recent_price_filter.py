"""商品 / 原料列表「近一个月未维护过价格」特殊条件。

口径：30 天（与 INGREDIENT_PRICE_STALE_DAYS 一致），按用户本地日的 00:00 换算成
UTC 起点后比较 ``recorded_at >= cutoff``：
  - 商品：自身近 30 天没有**有效**价格记录（含从未维护过）→ 命中；
  - 原料：其所有活跃商品近 30 天都没有有效记录（没有任何商品的原料同样命中）。
"""
from datetime import datetime, timedelta, timezone

from conftest import FakeUser, TestingSessionLocal, engine
from app.core.database import Base


def _jin_unit(db):
    from app.models.unit import Unit

    unit = db.query(Unit).filter(Unit.abbreviation == "斤").first()
    if unit:
        return unit
    unit = Unit(name="斤", abbreviation="斤", unit_type="mass")
    db.add(unit)
    db.commit()
    db.refresh(unit)
    return unit


def _seed(db):
    """建 4 个原料 / 5 个商品，返回 (ids dict, 需清理的 id 集合)。"""
    from app.models.nutrition import Ingredient
    from app.models.product import ProductRecord
    from app.models.product_entity import Product

    suffix = str(datetime.now(timezone.utc).timestamp()).replace(".", "")
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    unit = _jin_unit(db)

    ing_fresh = Ingredient(name=f"近月价_新鲜原料_{suffix}", is_active=True)
    ing_old = Ingredient(name=f"近月价_陈旧原料_{suffix}", is_active=True)
    ing_none = Ingredient(name=f"近月价_无商品原料_{suffix}", is_active=True)
    db.add_all([ing_fresh, ing_old, ing_none])
    db.commit()

    # ing_fresh 下有两个商品：一个有今天的记录，一个从没记过
    p_today = Product(name=f"近月价_今天_{suffix}", ingredient_id=ing_fresh.id, is_active=True)
    p_never = Product(name=f"近月价_从未_{suffix}", ingredient_id=ing_fresh.id, is_active=True)
    # ing_old 下：31 天前（算「超期」）+ 近月唯一记录已软删
    p_29 = Product(name=f"近月价_29天前_{suffix}", ingredient_id=ing_fresh.id, is_active=True)
    p_31 = Product(name=f"近月价_31天前_{suffix}", ingredient_id=ing_old.id, is_active=True)
    p_deleted = Product(name=f"近月价_仅软删记录_{suffix}", ingredient_id=ing_old.id, is_active=True)
    db.add_all([p_today, p_never, p_29, p_31, p_deleted])
    db.commit()

    rows = [
        (p_today, 0, True),
        (p_29, 29, True),
        (p_31, 31, True),
        (p_deleted, 1, False),  # 近月内唯一记录被软删 → 视为未维护
    ]
    for product, days_ago, is_active in rows:
        db.add(ProductRecord(
            user_id=FakeUser.id, product_id=product.id, product_name=product.name,
            price=10, currency="CNY",
            original_quantity=1, original_unit_id=unit.id,
            standard_quantity=1, standard_unit_id=unit.id,
            record_type="price", is_active=is_active,
            recorded_at=now - timedelta(days=days_ago),
        ))
    db.commit()

    ids = {
        "ing_fresh": ing_fresh.id, "ing_old": ing_old.id, "ing_none": ing_none.id,
        "p_today": p_today.id, "p_never": p_never.id, "p_29": p_29.id,
        "p_31": p_31.id, "p_deleted": p_deleted.id,
    }
    return ids, suffix


def _cleanup(ids):
    from app.models.nutrition import Ingredient
    from app.models.product import ProductRecord
    from app.models.product_entity import Product

    db = TestingSessionLocal()
    try:
        product_ids = [ids[k] for k in ids if k.startswith("p_")]
        db.query(ProductRecord).filter(ProductRecord.product_id.in_(product_ids)).delete(
            synchronize_session=False
        )
        db.query(Product).filter(Product.id.in_(product_ids)).delete(synchronize_session=False)
        ing_ids = [ids[k] for k in ids if k.startswith("ing_")]
        db.query(Ingredient).filter(Ingredient.id.in_(ing_ids)).delete(synchronize_session=False)
        db.commit()
    finally:
        db.close()


def _list_product_ids(client):
    resp = client.get("/api/v1/products/entity", params={"no_recent_price": "true", "limit": 1000})
    assert resp.status_code == 200, resp.text
    return {item["id"] for item in resp.json()["items"]}


def _list_ingredient_ids(client):
    resp = client.get("/api/v1/ingredients", params={"no_recent_price": "true", "limit": 1000})
    assert resp.status_code == 200, resp.text
    return {item["id"] for item in resp.json()["items"]}


def test_product_no_recent_price_filter(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        ids, _ = _seed(db)
    finally:
        db.close()

    client = TestClient(app)
    try:
        matched = _list_product_ids(client)
        # 今天有记录 / 29 天前有记录 → 近月内维护过，不该命中
        assert ids["p_today"] not in matched
        assert ids["p_29"] not in matched
        # 从未维护 / 31 天前 / 近月唯一记录已软删 → 命中
        assert ids["p_never"] in matched
        assert ids["p_31"] in matched
        assert ids["p_deleted"] in matched
    finally:
        _cleanup(ids)


def test_ingredient_no_recent_price_filter(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        ids, _ = _seed(db)
    finally:
        db.close()

    client = TestClient(app)
    try:
        matched = _list_ingredient_ids(client)
        # 有一个商品今天/29 天前记过 → 近月内维护过，不该命中
        assert ids["ing_fresh"] not in matched
        # 所有商品都在 31 天前（或只有软删记录）→ 命中
        assert ids["ing_old"] in matched
        # 没有商品 → 「所有商品均未维护」成立 → 命中
        assert ids["ing_none"] in matched
    finally:
        _cleanup(ids)


def test_filter_absent_by_default(as_admin):
    """不传 no_recent_price 时不得过滤（默认行为不变）。"""
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        ids, _ = _seed(db)
    finally:
        db.close()

    client = TestClient(app)
    try:
        resp = client.get("/api/v1/products/entity", params={"limit": 1000})
        assert resp.status_code == 200, resp.text
        all_ids = {item["id"] for item in resp.json()["items"]}
        assert {ids["p_today"], ids["p_29"], ids["p_31"]} <= all_ids

        resp = client.get("/api/v1/ingredients", params={"limit": 1000})
        assert resp.status_code == 200, resp.text
        all_ing = {item["id"] for item in resp.json()["items"]}
        assert {ids["ing_fresh"], ids["ing_old"]} <= all_ing
    finally:
        _cleanup(ids)
