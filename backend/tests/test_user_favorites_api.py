"""收藏（原料/商品/菜谱）的模型与 API 回归测试。

口径：收藏是个人私有数据（登录直写、不走审批）；纯链接表
（(user_id, entity_type, entity_id) 唯一，取消收藏=物理删）；列表端点
favorites_first / favorites_only 参数化且默认关闭。
"""
import uuid

import pytest
from sqlalchemy.exc import IntegrityError

from conftest import FakeUser, TestingSessionLocal, engine
from app.core.database import Base

_PRIMARY = ("ingredient", "product", "recipe")


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
    """建 2 原料 / 2 商品 / 2 菜谱（名字带唯一后缀），返回 6 个 id。

    「other」三件套用于验证 favorites_only 确实排除了非收藏项：每类只有 1 条
    数据时，「忽略参数」与「正确过滤」的结果相同，测试会假通过。
    """
    from app.models.nutrition import Ingredient
    from app.models.product_entity import Product
    from app.models.recipe import Recipe

    suffix = uuid.uuid4().hex[:10]
    ing = Ingredient(name=f"收藏测试原料_{suffix}", is_active=True)
    ing_other = Ingredient(name=f"收藏测试原料B_{suffix}", is_active=True)
    db.add_all([ing, ing_other])
    db.commit()
    prod = Product(name=f"收藏测试商品_{suffix}", ingredient_id=ing.id, is_active=True)
    prod_other = Product(
        name=f"收藏测试商品B_{suffix}", ingredient_id=ing_other.id, is_active=True
    )
    rec = Recipe(
        name=f"收藏测试菜谱_{suffix}", category="主食", user_id=FakeUser.id, is_active=True
    )
    rec_other = Recipe(
        name=f"收藏测试菜谱B_{suffix}", category="主食", user_id=FakeUser.id, is_active=True
    )
    db.add_all([prod, prod_other, rec, rec_other])
    db.commit()
    return {
        "ingredient": ing.id,
        "product": prod.id,
        "recipe": rec.id,
        "ingredient_other": ing_other.id,
        "product_other": prod_other.id,
        "recipe_other": rec_other.id,
    }


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
        db.query(Product).filter(
            Product.id.in_([ids["product"], ids["product_other"]])
        ).delete(synchronize_session=False)
        db.query(Recipe).filter(
            Recipe.id.in_([ids["recipe"], ids["recipe_other"]])
        ).delete(synchronize_session=False)
        db.query(Ingredient).filter(
            Ingredient.id.in_([ids["ingredient"], ids["ingredient_other"]])
        ).delete(synchronize_session=False)
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
        primary = {k: ids[k] for k in _PRIMARY}
        for entity_type, entity_id in primary.items():
            resp = client.post(f"/api/v1/favorites/{entity_type}/{entity_id}")
            assert resp.status_code == 200 and resp.json() == {"ok": True}, resp.text
            # 幂等：重复收藏仍 ok 且只有一行
            resp = client.post(f"/api/v1/favorites/{entity_type}/{entity_id}")
            assert resp.status_code == 200, resp.text
        assert client.post(f"/api/v1/merchants/{merchant_id}/favorite").status_code == 200

        resp = client.get("/api/v1/favorites")
        assert resp.status_code == 200, resp.text
        payload = resp.json()
        for entity_type, entity_id in primary.items():
            listed = [it["id"] for it in payload[f"{entity_type}s"]]
            assert entity_id in listed, (entity_type, payload)
        listed_merchants = [it["id"] for it in payload["merchants"]]
        assert merchant_id in listed_merchants, payload["merchants"]
        hit = [it for it in payload["merchants"] if it["id"] == merchant_id][0]
        assert hit.get("effective_currency"), hit

        resp = client.get("/api/v1/favorites/recipe")
        assert resp.status_code == 200, resp.text
        assert ids["recipe"] in [it["id"] for it in resp.json()]

        for entity_type, entity_id in primary.items():
            resp = client.delete(f"/api/v1/favorites/{entity_type}/{entity_id}")
            assert resp.status_code == 200 and resp.json() == {"ok": True}, resp.text
        resp = client.get("/api/v1/favorites")
        for entity_type, entity_id in primary.items():
            assert entity_id not in [it["id"] for it in resp.json()[f"{entity_type}s"]]
    finally:
        from app.models.merchant import Merchant
        from app.models.user_merchant_favorite import UserMerchantFavorite

        db = TestingSessionLocal()
        try:
            db.query(UserMerchantFavorite).filter(
                UserMerchantFavorite.merchant_id == merchant_id
            ).delete(synchronize_session=False)
            db.query(Merchant).filter(Merchant.id == merchant_id).delete(
                synchronize_session=False
            )
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


def _list_ids(client, path, params=None):
    resp = client.get(path, params=params or {"limit": 1000})
    assert resp.status_code == 200, resp.text
    return [it["id"] for it in resp.json()["items"]]


def test_favorites_only_and_first_products(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        ids = _seed_favorite_entities(db)
    finally:
        db.close()

    client = TestClient(app)
    try:
        base = _list_ids(client, "/api/v1/products/entity")
        assert ids["product"] in base and ids["product_other"] in base

        assert client.post(f"/api/v1/favorites/product/{ids['product']}").status_code == 200

        # favorites_only：只有该商品（非收藏的同名批次商品被排除），total 与条数一致
        resp = client.get(
            "/api/v1/products/entity", params={"favorites_only": "true", "limit": 1000}
        )
        payload = resp.json()
        assert [it["id"] for it in payload["items"]] == [ids["product"]]
        assert payload["total"] == 1

        # favorites_first：收藏项在最前，非收藏项相对顺序与 base 一致（去掉收藏项后的序列）
        pinned = _list_ids(client, "/api/v1/products/entity", {"favorites_first": "true"})
        assert pinned[0] == ids["product"]
        assert [i for i in pinned if i != ids["product"]] == [
            i for i in base if i != ids["product"]
        ]

        # 默认（不传参）：顺序与 base 完全一致（行为不变）
        assert _list_ids(client, "/api/v1/products/entity") == base

        # favorites_only 与既有特殊条件叠加：仍然只返回收藏项且 total 一致
        resp = client.get(
            "/api/v1/products/entity",
            params={"favorites_only": "true", "no_recent_price": "true", "limit": 1000},
        )
        payload = resp.json()
        assert payload["total"] == len(payload["items"])
        assert [it["id"] for it in payload["items"]] == [ids["product"]]

        client.delete(f"/api/v1/favorites/product/{ids['product']}")
    finally:
        _cleanup_favorite_entities(ids)


def test_favorites_only_and_first_ingredients_and_recipes(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        ids = _seed_favorite_entities(db)
    finally:
        db.close()

    client = TestClient(app)
    try:
        base = _list_ids(client, "/api/v1/ingredients")
        assert ids["ingredient"] in base and ids["ingredient_other"] in base
        client.post(f"/api/v1/favorites/ingredient/{ids['ingredient']}")
        resp = client.get(
            "/api/v1/ingredients", params={"favorites_only": "true", "limit": 1000}
        )
        payload = resp.json()
        assert [it["id"] for it in payload["items"]] == [ids["ingredient"]]
        assert payload["total"] == 1
        pinned = _list_ids(
            client, "/api/v1/ingredients", {"favorites_first": "true", "sort_by": "name"}
        )
        assert pinned[0] == ids["ingredient"]

        base_r = _list_ids(client, "/api/v1/recipes")
        assert ids["recipe"] in base_r and ids["recipe_other"] in base_r
        client.post(f"/api/v1/favorites/recipe/{ids['recipe']}")
        resp = client.get("/api/v1/recipes", params={"favorites_only": "true", "limit": 1000})
        payload = resp.json()
        assert [it["id"] for it in payload["items"]] == [ids["recipe"]]
        assert payload["total"] == 1
        pinned = _list_ids(client, "/api/v1/recipes", {"favorites_first": "true"})
        assert pinned[0] == ids["recipe"]

        client.delete(f"/api/v1/favorites/ingredient/{ids['ingredient']}")
        client.delete(f"/api/v1/favorites/recipe/{ids['recipe']}")
    finally:
        _cleanup_favorite_entities(ids)
