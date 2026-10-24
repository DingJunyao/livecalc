"""原料营养缺项 → 关联商品自定义营养加权平均回填。

规则（用户需求）：
- 原料没有某个营养素的记录时，从各商品的营养信息里**加权平均**带出
  （商品也没有就不加了）；
- 「某营养素记录为 0」与「没有该营养素记录」必须区分：显式 0 参与平均，
  也允许保存（新增时 0 也要记进去）；
- 权重用商品价格权重（price_weight，默认 50）。
"""
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.proposals.bootstrap import register_all

client = TestClient(app)


@pytest.fixture(autouse=True)
def _setup():
    """TestClient 不触发 lifespan，需显式注册执行器。"""
    register_all()
    previous = dict(app.dependency_overrides)
    yield
    app.dependency_overrides.clear()
    app.dependency_overrides.update(previous)


def _ingredient(db_session, name="浓汤宝原料") -> int:
    from app.models.nutrition import Ingredient
    ing = Ingredient(name=name, is_active=True)
    db_session.add(ing)
    db_session.commit()
    db_session.refresh(ing)
    return ing.id


def _product(db_session, ingredient_id, name, price_weight=50, nutrition=None) -> int:
    from app.models.product_entity import Product
    product = Product(
        name=name,
        ingredient_id=ingredient_id,
        is_active=True,
        price_weight=price_weight,
        custom_nutrition_data=nutrition,
    )
    db_session.add(product)
    db_session.commit()
    db_session.refresh(product)
    return product.id


def _own_nutrition(db_session, ingredient_id, nutrients: dict):
    """给原料写一条自身营养行（直接落库，绕过提议流程）。"""
    from app.models.nutrition_data import NutritionData
    row = NutritionData(
        ingredient_id=ingredient_id,
        source="custom",
        nutrients=nutrients,
        reference_amount=100.0,
        reference_unit="g",
    )
    db_session.add(row)
    db_session.commit()
    db_session.refresh(row)
    return row.id


def _all_nutrients(resp_json) -> dict:
    return resp_json["nutrition"]["all_nutrients"]


# ---------------------------------------------------------------- 缺项回填

def test_missing_nutrient_weighted_average_from_products(db_session, as_admin):
    """原料只有能量：糖从两个商品按价格权重加权平均（(10×50+6×150)/200=7）。"""
    ing_id = _ingredient(db_session)
    _own_nutrition(db_session, ing_id, {
        "all_nutrients": {
            "energy": {"value": 100, "unit": "kcal", "key": "energy"},
        },
        "core_nutrients": {
            "能量": {"value": 100, "unit": "kcal", "key": "energy"},
        },
    })
    _product(db_session, ing_id, "浓汤宝A", price_weight=50, nutrition={
        "all_nutrients": {
            "sugar": {"value": 10, "unit": "g", "key": "sugar"},
        },
    })
    _product(db_session, ing_id, "浓汤宝B", price_weight=150, nutrition={
        "all_nutrients": {
            "sugar": {"value": 6, "unit": "g", "key": "sugar"},
        },
    })

    resp = client.get(f"/api/v1/nutrition/ingredients/{ing_id}/nutrition")
    assert resp.status_code == 200, resp.text
    nutrients = _all_nutrients(resp.json())

    # 自身营养不受影响
    assert nutrients["能量"]["value"] == 100
    # 缺项回填：加权平均 + 来源标记
    assert nutrients["糖"]["value"] == 7.0
    assert nutrients["糖"]["unit"] == "g"
    assert nutrients["糖"]["from_products"] is True
    assert nutrients["糖"]["products_used"] == 2
    # 非核心营养素不进 core_nutrients
    assert "糖" not in resp.json()["nutrition"]["core_nutrients"]


def test_explicit_zero_participates_and_missing_does_not(db_session, as_admin):
    """商品 A 糖=0（有记录）、商品 B 糖=8 → 平均 4；钠只有 B 有 → 12。"""
    ing_id = _ingredient(db_session)
    _own_nutrition(db_session, ing_id, {
        "all_nutrients": {
            "energy": {"value": 50, "unit": "kcal", "key": "energy"},
        },
    })
    _product(db_session, ing_id, "零糖商品", price_weight=50, nutrition={
        "all_nutrients": {
            "sugar": {"value": 0, "unit": "g", "key": "sugar"},
        },
    })
    _product(db_session, ing_id, "普通商品", price_weight=50, nutrition={
        "all_nutrients": {
            "sugar": {"value": 8, "unit": "g", "key": "sugar"},
            "sodium": {"value": 12, "unit": "mg", "key": "sodium"},
        },
    })

    resp = client.get(f"/api/v1/nutrition/ingredients/{ing_id}/nutrition")
    nutrients = _all_nutrients(resp.json())
    # 0 是有效记录，参与平均：(0×50 + 8×50)/100 = 4，而不是只有 B 的 8
    assert nutrients["糖"]["value"] == 4
    # 只有 B 记录了钠 → 用 B 的值
    assert nutrients["钠"]["value"] == 12
    # 核心营养素（钠）同时补进 core_nutrients
    assert resp.json()["nutrition"]["core_nutrients"]["钠"]["value"] == 12


def test_own_value_wins_over_products(db_session, as_admin):
    """原料自己记了糖（哪怕 0）：商品值不覆盖。"""
    ing_id = _ingredient(db_session)
    _own_nutrition(db_session, ing_id, {
        "all_nutrients": {
            "sugar": {"value": 0, "unit": "g", "key": "sugar"},
        },
    })
    _product(db_session, ing_id, "有糖商品", nutrition={
        "all_nutrients": {
            "sugar": {"value": 9, "unit": "g", "key": "sugar"},
        },
    })

    resp = client.get(f"/api/v1/nutrition/ingredients/{ing_id}/nutrition")
    nutrients = _all_nutrients(resp.json())
    assert nutrients["糖"]["value"] == 0
    assert "from_products" not in nutrients["糖"]


def test_no_own_row_uses_products_table(db_session, as_admin):
    """原料完全没有营养行：整表从商品带出；商品也没有则维持 404。"""
    ing_id = _ingredient(db_session)
    _product(db_session, ing_id, "带营养商品", nutrition={
        "all_nutrients": {
            "energy": {"value": 200, "unit": "kcal", "key": "energy"},
            "protein": {"value": 5, "unit": "g", "key": "protein"},
        },
    })

    resp = client.get(f"/api/v1/nutrition/ingredients/{ing_id}/nutrition")
    assert resp.status_code == 200
    nutrients = _all_nutrients(resp.json())
    assert nutrients["能量"]["value"] == 200
    assert nutrients["能量"]["from_products"] is True

    # 商品也没有营养 → 仍然 404
    empty_id = _ingredient(db_session, name="无营养原料")
    resp2 = client.get(f"/api/v1/nutrition/ingredients/{empty_id}/nutrition")
    assert resp2.status_code == 404


def test_alias_keys_and_unit_normalization(db_session, as_admin):
    """别名键互通（sugar/total_sugars）+ 单位归一（kJ→kcal、mg→g、IU 不参与）。"""
    ing_id = _ingredient(db_session)
    # 原料用 USDA 键 total_sugars：编辑器键 sugar 的商品值不重复出现
    _own_nutrition(db_session, ing_id, {
        "all_nutrients": {
            "total_sugars": {"value": 2, "unit": "g", "key": "total_sugars"},
        },
    })
    _product(db_session, ing_id, "kJ商品", nutrition={
        "all_nutrients": {
            "energy": {"value": 418.4, "unit": "kJ", "key": "energy"},
            "sodium": {"value": 500, "unit": "mg", "key": "sodium"},
            "calcium": {"value": 3, "unit": "IU", "key": "calcium"},
        },
    })
    _product(db_session, ing_id, "kcal商品", nutrition={
        "all_nutrients": {
            "energy": {"value": 200, "unit": "kcal", "key": "energy"},
            "sodium": {"value": 1, "unit": "g", "key": "sodium"},
        },
    })

    resp = client.get(f"/api/v1/nutrition/ingredients/{ing_id}/nutrition")
    nutrients = _all_nutrients(resp.json())

    # 原料已有 total_sugars（sugar 的别名）→ 不回填糖
    assert "糖" not in nutrients
    # 能量回填：(418.4 kJ→100 kcal + 200 kcal)/2 = 150 kcal
    assert nutrients["能量"]["value"] == pytest.approx(150.0)
    assert nutrients["能量"]["unit"] == "kcal"
    assert nutrients["能量"]["from_products"] is True
    # 钠（默认基准单位 mg）：(500mg + 1g→1000mg)/2 = 750mg
    assert nutrients["钠"]["value"] == pytest.approx(750.0)
    assert nutrients["钠"]["unit"] == "mg"
    # IU 换算不了 → 钙不回填
    assert "钙" not in nutrients


def test_chinese_keys_and_per_block_reference(db_session, as_admin):
    """移动端保存的商品营养键是中文显示名（key=中文标签），基准可以是
    「每 10.7 g」这类非 100 g 量：键要归一、值要按基准折到每 100 g。"""
    ing_id = _ingredient(db_session)
    _product(db_session, ing_id, "中文键商品", price_weight=100, nutrition={
        "reference_amount": 10.7,
        "reference_unit": "g",
        "all_nutrients": {
            "能量": {"value": 74.0, "unit": "kJ", "key": "能量"},
            "蛋白质": {"value": 0.6, "unit": "g", "key": "蛋白质"},
            "钠": {"value": 887.0, "unit": "mg", "key": "钠"},
        },
    })
    _product(db_session, ing_id, "第二商品", price_weight=100, nutrition={
        "reference_amount": 21.4,
        "reference_unit": "g",
        "all_nutrients": {
            "能量": {"value": 148.0, "unit": "kJ", "key": "能量"},
            "蛋白质": {"value": 1.2, "unit": "g", "key": "蛋白质"},
            "钠": {"value": 1774.0, "unit": "mg", "key": "钠"},
        },
    })

    resp = client.get(f"/api/v1/nutrition/ingredients/{ing_id}/nutrition")
    assert resp.status_code == 200, resp.text
    nutrients = _all_nutrients(resp.json())

    # 两个商品每 100 g 完全一致：能量 148/21.4×100 = 691.589 g→kcal；
    # 74 kJ/10.7g = 691.589 kJ/100g = 165.29 kcal；蛋白质 5.607 g；钠 8289.7 mg
    assert nutrients["能量"]["value"] == pytest.approx(165.29, abs=0.02)
    assert nutrients["能量"]["unit"] == "kcal"
    assert nutrients["蛋白质"]["value"] == pytest.approx(5.607, abs=0.01)
    assert nutrients["蛋白质"]["unit"] == "g"
    assert nutrients["钠"]["value"] == pytest.approx(8289.72, abs=0.5)
    assert nutrients["钠"]["unit"] == "mg"
    for name in ("能量", "蛋白质", "钠"):
        assert nutrients[name]["from_products"] is True
    # 核心营养素同时进 core_nutrients
    assert resp.json()["nutrition"]["core_nutrients"]["能量"]["unit"] == "kcal"


# ---------------------------------------------------------------- 0 值保存

def test_save_explicit_zero_is_recorded(db_session, as_admin):
    """新增时营养素填 0 也要记进去（0 ≠ 没有记录）。"""
    ing_id = _ingredient(db_session)
    resp = client.post(
        f"/api/v1/nutrition/ingredients/{ing_id}/nutrition",
        json={
            "nutrients": [
                {"name": "能量", "value": 100, "unit": "kcal", "key": "energy"},
                {"name": "糖", "value": 0, "unit": "g", "key": "sugar"},
                {"name": "钠", "value": 0, "unit": "mg", "key": "sodium"},
            ],
            "source": "custom",
        },
    )
    assert resp.status_code == 200, resp.text

    resp2 = client.get(f"/api/v1/nutrition/ingredients/{ing_id}/nutrition")
    nutrients = _all_nutrients(resp2.json())
    assert nutrients["糖"]["value"] == 0
    assert nutrients["钠"]["value"] == 0
