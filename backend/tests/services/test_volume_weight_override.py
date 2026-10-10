"""自定义单位"每单位量"支持体积语义（如 1瓶=500mL）的换算测试。

覆盖：
- UnitConversionService.convert 实体覆盖分支：体积 weight_unit 经实体密度折算
- _get_piece_weight_kg 的体积分支（count 兜底路径）
- recipe_service.calculate_recipe_nutrition 的 count 体积覆盖折算
- 质量语义覆盖的回归
"""
import asyncio
from decimal import Decimal

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base
from app.models.unit import Unit
from app.models.entity_unit_override import EntityUnitOverride
from app.models.entity_density import EntityDensity
from app.models.nutrition import Ingredient
from app.models.product_entity import Product
from app.models.recipe import Recipe, RecipeIngredient
from app.models.nutrition_data import NutritionData
from app.services.unit_conversion_service import (
    UnitConversionService,
    _get_piece_weight_kg,
)


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    try:
        yield session
    finally:
        session.close()
        engine.dispose()


@pytest.fixture
def units(db):
    """最小单位集：kg/g（质量）、L/mL（体积）、瓶（count）"""
    def add(abbr, name, utype, factor, is_base=False, system="metric"):
        u = Unit(
            name=name, abbreviation=abbr, unit_type=utype,
            si_factor=Decimal(str(factor)), is_si_base=is_base,
            unit_system=system,
        )
        db.add(u)
        return u

    kg = add("kg", "千克", "mass", 1, is_base=True)
    g = add("g", "克", "mass", 0.001)
    liter = add("L", "升", "volume", 1, is_base=True)
    ml = add("mL", "毫升", "volume", 0.001)
    bottle = add("瓶", "瓶", "count", 1, system="count")
    db.commit()
    return {"kg": kg, "g": g, "L": liter, "mL": ml, "瓶": bottle}


def make_override(db, entity_type, entity_id, weight_unit, weight_per_unit, unit_name="瓶"):
    ov = EntityUnitOverride(
        entity_type=entity_type, entity_id=entity_id, unit_name=unit_name,
        conversion_factor=Decimal("1"),
        weight_per_unit=Decimal(str(weight_per_unit)),
        weight_unit_id=weight_unit.id, is_active=True, source="manual",
    )
    db.add(ov)
    db.commit()
    return ov


def make_milk(db, units, density=None):
    """牛奶原料：可选密度 + 瓶=500mL 覆盖"""
    ing = Ingredient(name="牛奶")
    db.add(ing)
    db.commit()
    if density is not None:
        db.add(EntityDensity(
            entity_type="ingredient", entity_id=ing.id,
            density=Decimal(str(density)), is_active=True,
        ))
        db.commit()
    make_override(db, "ingredient", ing.id, units["mL"], 500)
    return ing


def test_volume_override_with_density_converts_to_grams(db, units):
    """1瓶=500mL、密度 1.03 g/mL → 515 g"""
    ing = make_milk(db, units, density=1030)
    result = UnitConversionService(db).convert(
        Decimal("1"), "瓶", "g", entity_type="ingredient", entity_id=ing.id
    )
    assert result is not None
    value, method = result
    assert method == "entity_override"
    assert float(value) == pytest.approx(515.0)


def test_volume_override_water_fallback(db, units):
    """无密度记录 → 水密度兜底：1瓶=500mL → 500 g"""
    ing = make_milk(db, units, density=None)
    result = UnitConversionService(db).convert(
        Decimal("1"), "瓶", "g", entity_type="ingredient", entity_id=ing.id
    )
    assert result is not None
    value, method = result
    assert method == "entity_override"
    assert float(value) == pytest.approx(500.0)


def test_volume_override_product_falls_back_to_ingredient_density(db, units):
    """商品覆盖为体积、密度挂在关联原料上：换算走 product→ingredient 密度回退链"""
    ing = Ingredient(name="纯牛奶")
    db.add(ing)
    db.commit()
    db.add(EntityDensity(
        entity_type="ingredient", entity_id=ing.id,
        density=Decimal("1030"), is_active=True,
    ))
    product = Product(name="某牌纯牛奶250ml", ingredient_id=ing.id)
    db.add(product)
    db.commit()
    make_override(db, "product", product.id, units["mL"], 250)

    result = UnitConversionService(db).convert(
        Decimal("1"), "瓶", "g", entity_type="product", entity_id=product.id
    )
    assert result is not None
    value, method = result
    assert method == "entity_override"
    assert float(value) == pytest.approx(257.5)


def test_piece_weight_kg_volume_branch(db, units):
    """count 兜底路径（_get_piece_weight_kg）：体积 weight_unit 经密度折 kg"""
    ing = make_milk(db, units, density=1030)
    service = UnitConversionService(db)
    wp_kg = _get_piece_weight_kg(service, "ingredient", ing.id, "瓶", Decimal("0.1"))
    assert float(wp_kg) == pytest.approx(0.515)


def test_mass_override_regression(db, units):
    """回归：质量语义覆盖（1瓶=500g）行为不变"""
    ing = Ingredient(name="面粉")
    db.add(ing)
    db.commit()
    make_override(db, "ingredient", ing.id, units["g"], 500)
    result = UnitConversionService(db).convert(
        Decimal("2"), "瓶", "kg", entity_type="ingredient", entity_id=ing.id
    )
    assert result is not None
    value, method = result
    assert method == "entity_override"
    assert float(value) == pytest.approx(1.0)


def test_recipe_nutrition_count_volume_override(db, units):
    """菜谱营养：1瓶牛奶（500mL、密度1.03）→ 515g → 54kcal/100g × 5.15 = 278.1 kcal"""
    ing = make_milk(db, units, density=1030)
    db.add(NutritionData(
        ingredient_id=ing.id, source="custom",
        reference_amount=100.0, reference_unit="g",
        nutrients={
            "core_nutrients": {
                "能量": {"value": 54.0, "unit": "kcal", "key": "energy"},
            },
            "all_nutrients": {},
        },
    ))
    recipe = Recipe(name="牛奶测试", servings=1, ingredients=[
        RecipeIngredient(ingredient_id=ing.id, quantity="1", unit_id=units["瓶"].id),
    ])
    db.add(recipe)
    db.commit()

    from app.services.recipe_service import calculate_recipe_nutrition
    result = asyncio.run(calculate_recipe_nutrition(recipe.id, db))
    assert result["total_calories"] == pytest.approx(278.1, abs=0.05)
