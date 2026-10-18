import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.services.recipe_service import calculate_recipe_cost
from app.models.user import User
from app.models.recipe import Recipe, RecipeIngredient
from app.models.product_entity import Product
from app.models.product import ProductRecord
from app.models.nutrition import Ingredient
from app.models.nutrition_data import NutritionData
from app.models.unit import Unit
from datetime import datetime
from decimal import Decimal

client = TestClient(app)


def test_create_recipe():
    """测试创建菜谱"""
    response = client.post(
        "/api/v1/auth/login",
        json={"username": "testuser", "password_hash": "test_password_hash"}
    )
    token = response.json()["access_token"]

    response = client.post(
        "/api/v1/recipes/",
        json={
            "name": "番茄炒蛋",
            "source": "custom",
            "cooking_steps": [
                {"step": 1, "content": "番茄切块，鸡蛋打散"}
            ],
            "ingredients": [
                {"ingredient_name": "鸡蛋", "quantity": "2", "unit": "个"}
            ],
            "servings": 2
        },
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "番茄炒蛋"


def test_get_recipes():
    """测试获取菜谱列表"""
    response = client.get("/api/v1/recipes/")
    assert response.status_code in [200, 401]


def test_get_recipe_cost():
    """测试获取菜谱成本"""
    response = client.post(
        "/api/v1/auth/login",
        json={"username": "testuser", "password_hash": "test_password_hash"}
    )
    token = response.json()["access_token"]

    response = client.get(
        "/api/v1/recipes/1/cost",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code in [200, 404]


@pytest.mark.asyncio
async def test_cross_user_recipe_cost_uses_public_price(db_session):
    """新用户（无价格记录）算菜谱成本，应跨用户使用公开价格（非 0）。

    构造：用户 A 录了某商品价格，用户 B（无任何价格记录）算含该商品的菜谱成本。
    修复前：价格查询按 user_id 过滤 → B 拿不到价 → 成本 0。
    修复后：价格公开，B 用 A 的价算出成本 > 0。
    """
    db = db_session

    # 单位：克（mass，SI 基准）
    gram = Unit(
        name="test_gram_cross",
        abbreviation="tgc",
        unit_type="mass",
        si_factor=1.0,
        is_si_base=True,
        is_standard=True,
    )
    db.add(gram)
    db.flush()

    # 两个用户
    user_a = User(username="cross_user_a", email="cross_a@test.local", password_hash="x")
    user_b = User(username="cross_user_b", email="cross_b@test.local", password_hash="x")
    db.add_all([user_a, user_b])
    db.flush()

    # 食材 + 商品
    ingredient = Ingredient(name="跨用户测试食材", default_unit_id=gram.id)
    db.add(ingredient)
    db.flush()
    product = Product(name="跨用户测试商品", ingredient_id=ingredient.id)
    db.add(product)
    db.flush()

    # 仅用户 A 录价格：10 元 / 100 克 = 0.1 元/克，今天记录
    record = ProductRecord(
        user_id=user_a.id,
        product_id=product.id,
        product_name=product.name,
        price=Decimal("10.00"),
        original_quantity=100,
        original_unit_id=gram.id,
        standard_quantity=100,
        standard_unit_id=gram.id,
        record_type="price",
        recorded_at=datetime.now(),
    )
    db.add(record)

    # 菜谱（属于 B 也可，可见性由 API 层处理，此处直接给 id）
    recipe = Recipe(name="跨用户成本测试菜谱", servings=1, user_id=user_b.id)
    db.add(recipe)
    db.flush()
    ri = RecipeIngredient(
        recipe_id=recipe.id,
        ingredient_id=ingredient.id,
        quantity="100",
        unit_id=gram.id,
    )
    db.add(ri)
    db.commit()

    # 以用户 B 身份算成本（B 无任何价格记录）
    result = await calculate_recipe_cost(recipe.id, user_b.id, db)

    assert result is not None, "calculate_recipe_cost 不应返回 None"
    total = result["total_cost"]
    assert isinstance(total, (Decimal, float, int)), f"total_cost 类型异常: {type(total)}"
    assert float(total) > 0, f"跨用户成本应为正（公开价格），实际: {total}"

    # 清理本次测试数据，避免污染共享内存库的其他测试
    db.query(RecipeIngredient).filter_by(id=ri.id).delete()
    db.query(Recipe).filter_by(id=recipe.id).delete()
    db.query(ProductRecord).filter_by(id=record.id).delete()
    db.query(Product).filter_by(id=product.id).delete()
    db.query(Ingredient).filter_by(id=ingredient.id).delete()
    db.query(User).filter(User.id.in_([user_a.id, user_b.id])).delete()
    db.query(Unit).filter_by(id=gram.id).delete()
    db.commit()


@pytest.mark.asyncio
async def test_recipe_nutrition_falls_back_to_range_max(db_session):
    """quantity=None 的条目：营养计算按 quantity_range 最大值参与，不再按 0。

    「电饭煲蒸米饭」类导入菜谱的源数据只有范围（大米 100-200g）或模糊量
    （水「适量」），quantity 落库为 NULL。修复前 calculate_recipe_nutrition
    把 None 当 "0"，整谱营养被静默清零；修复后与成本同口径
    （_get_effective_quantity）：范围取最大值，模糊量 适量=100g。
    """
    from app.services.recipe_service import calculate_recipe_nutrition

    db = db_session

    gram = Unit(
        name="test_gram_range",
        abbreviation="g",
        unit_type="mass",
        si_factor=1.0,
        is_si_base=True,
        is_standard=True,
    )
    db.add(gram)
    db.flush()

    user = User(username="range_qty_user", email="range_qty@test.local", password_hash="x")
    db.add(user)
    db.flush()

    ingredient = Ingredient(name="范围数量测试食材")
    db.add(ingredient)
    db.flush()

    nutrition = NutritionData(
        ingredient_id=ingredient.id,
        source="test",
        nutrients={
            "core_nutrients": {
                "能量": {"value": 365, "unit": "kcal", "key": "energy"},
                "蛋白质": {"value": 7.13, "unit": "g", "key": "protein"},
            },
            "all_nutrients": {},
        },
        reference_amount=100,
        reference_unit="g",
    )
    db.add(nutrition)
    db.flush()

    recipe = Recipe(name="范围数量测试菜谱", servings=1, user_id=user.id)
    db.add(recipe)
    db.flush()

    # ① 无 quantity、有范围 100-200g → 按最大值 200g 参与
    ri_range = RecipeIngredient(
        recipe_id=recipe.id,
        ingredient_id=ingredient.id,
        quantity=None,
        quantity_range={"min": 100.0, "max": 200.0},
        unit_id=gram.id,
    )
    # ② 无 quantity、无范围、原文「适量」→ 按模糊量映射 100g 参与
    ri_vague = RecipeIngredient(
        recipe_id=recipe.id,
        ingredient_id=ingredient.id,
        quantity=None,
        original_quantity="适量",
        unit_id=gram.id,
    )
    # ③ 对照：有确定数量 50g → 50g
    ri_fixed = RecipeIngredient(
        recipe_id=recipe.id,
        ingredient_id=ingredient.id,
        quantity="50",
        unit_id=gram.id,
    )
    db.add_all([ri_range, ri_vague, ri_fixed])
    db.commit()

    result = await calculate_recipe_nutrition(recipe.id, db=db)

    assert result is not None, "calculate_recipe_nutrition 不应返回 None"

    # 修复前三项全按 0 计，total_calories = 0；修复后 = 365×(2+1+0.5) = 1277.5
    assert float(result["total_calories"]) == pytest.approx(1277.5), (
        f"能量应按 范围最大值200g + 适量100g + 50g 计算，实际: {result['total_calories']}"
    )
    assert float(result["total_protein"]) == pytest.approx(7.13 * 3.5)

    detail_by_ri = {
        d["recipe_ingredient_id"]: d for d in result.get("ingredient_details", [])
    }
    assert detail_by_ri[ri_range.id]["quantity"] == pytest.approx(200.0), (
        "范围条目应取最大值 200g"
    )
    assert detail_by_ri[ri_vague.id]["quantity"] == pytest.approx(100.0), (
        "「适量」条目应按模糊量映射 100g"
    )
    assert detail_by_ri[ri_fixed.id]["quantity"] == pytest.approx(50.0)

    # 清理本次测试数据
    db.query(RecipeIngredient).filter(RecipeIngredient.id.in_(
        [ri_range.id, ri_vague.id, ri_fixed.id])).delete(synchronize_session=False)
    db.query(NutritionData).filter_by(id=nutrition.id).delete()
    db.query(Recipe).filter_by(id=recipe.id).delete()
    db.query(Ingredient).filter_by(id=ingredient.id).delete()
    db.query(User).filter_by(id=user.id).delete()
    db.query(Unit).filter_by(id=gram.id).delete()
    db.commit()

