from fastapi.testclient import TestClient

from app.main import app
from app.models.ingredient_category import IngredientCategory
from app.models.nutrition import Ingredient
from app.models.product_entity import Product


client = TestClient(app)


def _cleanup(db, ingredient_ids, category_id=None):
    for ingredient_id in ingredient_ids:
        db.query(Product).filter(Product.ingredient_id == ingredient_id).delete()
        db.query(Ingredient).filter(Ingredient.id == ingredient_id).delete()
    if category_id is not None:
        db.query(IngredientCategory).filter(IngredientCategory.id == category_id).delete()
    db.commit()


def test_create_ingredient_persists_category_and_aliases(as_admin, db_session):
    """新增商品页「新增对应原料」需要一次请求写入名称/分类/别名。"""
    db = db_session
    category = IngredientCategory(name="调料类-tests", display_name="调料类-tests")
    db.add(category)
    db.commit()
    db.refresh(category)

    created_ids = []
    try:
        response = client.post(
            "/api/v1/ingredients",
            json={
                "name": "  松茸鲜  ",
                "aliases": ["松茸粉", "松茸调味料"],
                "category_id": category.id,
            },
        )
        assert response.status_code == 200, response.text
        data = response.json()
        created_ids.append(data["id"])
        assert data["name"] == "松茸鲜"
        assert data["reused"] is False
        assert data["category_id"] == category.id

        ingredient = db.query(Ingredient).filter(Ingredient.id == data["id"]).first()
        assert ingredient.aliases == ["松茸粉", "松茸调味料"]
        assert ingredient.category_id == category.id

        # 默认仍会自动创建同名商品（既有行为，供原料页新增原料后直接记价）
        auto_product = db.query(Product).filter(
            Product.ingredient_id == ingredient.id,
            Product.name == "松茸鲜",
        ).first()
        assert auto_product is not None
    finally:
        _cleanup(db, created_ids, category.id)


def test_create_ingredient_can_skip_auto_product(as_admin, db_session):
    """商品表单自己创建商品，原料接口传 create_same_name_product=false 不再生成重复商品。"""
    db = db_session
    created_ids = []
    try:
        response = client.post(
            "/api/v1/ingredients",
            json={"name": "松茸鲜-skip-tests", "create_same_name_product": False},
        )
        assert response.status_code == 200, response.text
        data = response.json()
        created_ids.append(data["id"])
        assert db.query(Product).filter(
            Product.ingredient_id == data["id"],
        ).count() == 0
    finally:
        _cleanup(db, created_ids)


def test_create_ingredient_reuses_existing_only_when_requested(as_admin, db_session):
    """同名原料：默认仍报 400（兼容旧客户端）；reuse_existing=true 时复用。"""
    db = db_session
    existing = Ingredient(name="松茸鲜-reuse-tests", aliases=["旧别名"])
    db.add(existing)
    db.commit()
    db.refresh(existing)

    try:
        duplicate = client.post(
            "/api/v1/ingredients",
            json={"name": existing.name},
        )
        assert duplicate.status_code == 400

        reused = client.post(
            "/api/v1/ingredients",
            json={
                "name": existing.name,
                "aliases": ["新别名应被忽略"],
                "category_id": 999999,
                "reuse_existing": True,
            },
        )
        assert reused.status_code == 200, reused.text
        data = reused.json()
        assert data["id"] == existing.id
        assert data["reused"] is True
        assert data["aliases"] == ["旧别名"]
    finally:
        _cleanup(db, [existing.id])


def test_create_ingredient_rejects_unknown_category(as_admin):
    response = client.post(
        "/api/v1/ingredients",
        json={"name": "未知分类原料-tests", "category_id": 999999},
    )
    assert response.status_code == 400
