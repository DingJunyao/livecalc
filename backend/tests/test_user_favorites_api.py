"""收藏（原料/商品/菜谱）的模型与 API 回归测试。

口径：收藏是个人私有数据（登录直写、不走审批）；纯链接表
（(user_id, entity_type, entity_id) 唯一，取消收藏=物理删）；列表端点
favorites_first / favorites_only 参数化且默认关闭。
"""
import pytest
from sqlalchemy.exc import IntegrityError

from conftest import FakeUser, TestingSessionLocal, engine
from app.core.database import Base


def test_user_favorite_unique_constraint():
    Base.metadata.create_all(bind=engine)
    from app.models.user_favorite import UserFavorite

    db = TestingSessionLocal()
    try:
        db.add(UserFavorite(user_id=FakeUser.id, entity_type="recipe", entity_id=999001))
        db.commit()
        db.add(UserFavorite(user_id=FakeUser.id, entity_type="recipe", entity_id=999001))
        with pytest.raises(IntegrityError):
            db.commit()
        db.rollback()
    finally:
        db.query(UserFavorite).filter(UserFavorite.entity_id == 999001).delete()
        db.commit()
        db.close()


def _seed_favorite_entities(db):
    """建 1 原料 / 1 商品 / 1 菜谱（名字带唯一后缀），返回 id 与清理信息。"""
    import uuid

    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.recipe import Recipe

    suffix = uuid.uuid4().hex[:10]
    ing = Ingredient(name=f"收藏测试原料_{suffix}", is_active=True)
    db.add(ing)
    db.commit()
    prod = Product(name=f"收藏测试商品_{suffix}", ingredient_id=ing.id, is_active=True)
    rec = Recipe(name=f"收藏测试菜谱_{suffix}", category="主食", user_id=FakeUser.id, is_active=True)
    db.add_all([prod, rec])
    db.commit()
    return {"ingredient": ing.id, "product": prod.id, "recipe": rec.id}


def _cleanup_favorite_entities(ids):
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.recipe import Recipe
    from app.models.user_favorite import UserFavorite

    db = TestingSessionLocal()
    try:
        db.query(UserFavorite).filter(
            UserFavorite.entity_id.in_(list(ids.values()))
        ).delete(synchronize_session=False)
        db.query(Product).filter(Product.id == ids["product"]).delete(synchronize_session=False)
        db.query(Recipe).filter(Recipe.id == ids["recipe"]).delete(synchronize_session=False)
        db.query(Ingredient).filter(Ingredient.id == ids["ingredient"]).delete(synchronize_session=False)
        db.commit()
    finally:
        db.close()


def test_favorite_round_trip_all_types(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        ids = _seed_favorite_entities(db)
        # 再建一个商家（聚合里走既有商家收藏表，验证非空时的序列化）
        import uuid

        from app.models.merchant import Merchant

        suffix = uuid.uuid4().hex[:10]
        merchant = Merchant(name=f"收藏测试商家_{suffix}", user_id=FakeUser.id, is_open=True)
        db.add(merchant)
        db.commit()
        merchant_id = merchant.id
    finally:
        db.close()

    client = TestClient(app)
    try:
        for entity_type, entity_id in ids.items():
            resp = client.post(f"/api/v1/favorites/{entity_type}/{entity_id}")
            assert resp.status_code == 200 and resp.json() == {"ok": True}, resp.text
            # 幂等：重复收藏仍 ok 且只有一行
            resp = client.post(f"/api/v1/favorites/{entity_type}/{entity_id}")
            assert resp.status_code == 200, resp.text
        assert client.post(f"/api/v1/merchants/{merchant_id}/favorite").status_code == 200

        resp = client.get("/api/v1/favorites")
        assert resp.status_code == 200, resp.text
        payload = resp.json()
        for entity_type, entity_id in ids.items():
            listed = [it["id"] for it in payload[f"{entity_type}s"]]
            assert entity_id in listed, (entity_type, payload)
        listed_merchants = [it["id"] for it in payload["merchants"]]
        assert merchant_id in listed_merchants, payload["merchants"]
        hit = [it for it in payload["merchants"] if it["id"] == merchant_id][0]
        assert hit.get("effective_currency"), hit

        resp = client.get("/api/v1/favorites/recipe")
        assert resp.status_code == 200, resp.text
        assert ids["recipe"] in [it["id"] for it in resp.json()]

        for entity_type, entity_id in ids.items():
            resp = client.delete(f"/api/v1/favorites/{entity_type}/{entity_id}")
            assert resp.status_code == 200 and resp.json() == {"ok": True}, resp.text
        resp = client.get("/api/v1/favorites")
        for entity_type, entity_id in ids.items():
            assert entity_id not in [it["id"] for it in resp.json()[f"{entity_type}s"]]
    finally:
        from app.models.merchant import Merchant
        from app.models.user_merchant_favorite import UserMerchantFavorite

        db = TestingSessionLocal()
        try:
            db.query(UserMerchantFavorite).filter(
                UserMerchantFavorite.merchant_id == merchant_id
            ).delete(synchronize_session=False)
            db.query(Merchant).filter(Merchant.id == merchant_id).delete(synchronize_session=False)
            db.commit()
        finally:
            db.close()
        _cleanup_favorite_entities(ids)


def test_favorite_unknown_entity_404(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    client = TestClient(app)
    resp = client.post("/api/v1/favorites/recipe/999000123")
    assert resp.status_code == 404, resp.text
    resp = client.post("/api/v1/favorites/not_a_type/1")
    assert resp.status_code == 400, resp.text


def test_favorite_soft_deleted_entity_404_and_hidden(as_admin):
    """软删实体：加收藏 404；收藏过的实体被软删后不再出现在列表。"""
    from starlette.testclient import TestClient
    from app.main import app
    from app.models.recipe import Recipe

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        ids = _seed_favorite_entities(db)
    finally:
        db.close()

    client = TestClient(app)
    try:
        assert client.post(f"/api/v1/favorites/recipe/{ids['recipe']}").status_code == 200
        # 软删该菜谱
        db = TestingSessionLocal()
        try:
            db.query(Recipe).filter(Recipe.id == ids["recipe"]).update({"is_active": False})
            db.commit()
        finally:
            db.close()
        # 已软删 → 再加收藏 404
        resp = client.post(f"/api/v1/favorites/recipe/{ids['recipe']}")
        assert resp.status_code == 404, resp.text
        # 列表不显示
        resp = client.get("/api/v1/favorites/recipe")
        assert ids["recipe"] not in [it["id"] for it in resp.json()]
    finally:
        db = TestingSessionLocal()
        try:
            db.query(Recipe).filter(Recipe.id == ids["recipe"]).update({"is_active": True})
            db.commit()
        finally:
            db.close()
        _cleanup_favorite_entities(ids)
