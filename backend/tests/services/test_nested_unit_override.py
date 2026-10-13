"""自定义单位嵌套链（1箱 = 12 盒，1盒 = 220 mL）的解析与换算测试。

覆盖：
- resolve_override_amount：factor × weight_per_unit × weight_unit，逐层递归
- convert：嵌套链到体积/质量（经实体密度）
- _get_piece_weight_kg：嵌套链的 count 兜底路径
- 循环引用 / 悬空引用 → 不臆估（返回 None 或退化为全局单位路径）
"""
from decimal import Decimal

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base
from app.models.unit import Unit
from app.models.entity_unit_override import EntityUnitOverride
from app.models.entity_density import EntityDensity
from app.models.nutrition import Ingredient
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
    """最小单位集：kg/g（质量）、L/mL（体积）。"""
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
    box = add("盒", "盒", "count", 1, system="count")
    carton = add("箱", "箱", "count", 1, system="count")
    db.commit()
    return {"kg": kg, "g": g, "L": liter, "mL": ml, "盒": box, "箱": carton}


def _ingredient(db, name="牛奶", density=None):
    ing = Ingredient(name=name, is_active=True)
    db.add(ing)
    db.commit()
    db.refresh(ing)
    if density is not None:
        db.add(EntityDensity(
            entity_type="ingredient", entity_id=ing.id,
            density=Decimal(str(density)), is_active=True,
        ))
        db.commit()
    return ing


def _override(db, entity_type, entity_id, unit_name, *, weight=None,
              weight_unit_id=None, weight_unit_override_id=None, factor=None):
    ov = EntityUnitOverride(
        entity_type=entity_type, entity_id=entity_id, unit_name=unit_name,
        conversion_factor=None if factor is None else Decimal(str(factor)),
        weight_per_unit=None if weight is None else Decimal(str(weight)),
        weight_unit_id=weight_unit_id,
        weight_unit_override_id=weight_unit_override_id,
        is_active=True, source="manual",
    )
    db.add(ov)
    db.commit()
    db.refresh(ov)
    return ov


def test_nested_chain_box_to_volume(db, units):
    """1盒=220mL，1箱=12盒 → 1箱 = 2640 mL（换算系数不填默认 1）。"""
    ing = _ingredient(db)
    box = _override(db, "ingredient", ing.id, "盒", weight=220, weight_unit_id=units["mL"].id)
    _override(db, "ingredient", ing.id, "箱", weight=12, weight_unit_override_id=box.id)

    result = UnitConversionService(db).convert(
        Decimal("1"), "箱", "mL", entity_type="ingredient", entity_id=ing.id
    )
    assert result is not None
    value, method = result
    assert method == "entity_override"
    assert float(value) == pytest.approx(2640.0)


def test_nested_chain_with_conversion_factor_and_no_weight(db, units):
    """「换算系数 12 + 单位 盒（不填单个重量）」同样表示 1箱 = 12 盒。"""
    ing = _ingredient(db)
    box = _override(db, "ingredient", ing.id, "盒", weight=220, weight_unit_id=units["mL"].id)
    _override(db, "ingredient", ing.id, "箱", factor=12, weight_unit_override_id=box.id)

    result = UnitConversionService(db).convert(
        Decimal("2"), "箱", "mL", entity_type="ingredient", entity_id=ing.id
    )
    assert result is not None
    assert float(result[0]) == pytest.approx(5280.0)


def test_nested_chain_to_grams_via_density(db, units):
    """嵌套链末端是体积时，折克要经实体密度（1.03 g/mL）。"""
    ing = _ingredient(db, density=1030)
    box = _override(db, "ingredient", ing.id, "盒", weight=220, weight_unit_id=units["mL"].id)
    _override(db, "ingredient", ing.id, "箱", weight=12, weight_unit_override_id=box.id)

    result = UnitConversionService(db).convert(
        Decimal("1"), "箱", "g", entity_type="ingredient", entity_id=ing.id
    )
    assert result is not None
    assert float(result[0]) == pytest.approx(2640.0 * 1.03)


def test_nested_chain_piece_weight_kg(db, units):
    """count 兜底路径同样走嵌套链：1箱 = 2.64 kg（无密度按水 1000）。"""
    ing = _ingredient(db)
    box = _override(db, "ingredient", ing.id, "盒", weight=220, weight_unit_id=units["mL"].id)
    _override(db, "ingredient", ing.id, "箱", weight=12, weight_unit_override_id=box.id)

    service = UnitConversionService(db)
    kg = _get_piece_weight_kg(service, "ingredient", ing.id, "箱", Decimal("0.1"))
    assert float(kg) == pytest.approx(2.64)


def test_cycle_returns_none_without_estimate(db, units):
    """循环引用不得臆估：两条都只有引用、没有真实重量 → 无法换算。"""
    ing = _ingredient(db)
    a = _override(db, "ingredient", ing.id, "甲")
    b = _override(db, "ingredient", ing.id, "乙", weight_unit_override_id=a.id)
    a.weight_unit_override_id = b.id
    db.commit()

    result = UnitConversionService(db).convert(
        Decimal("1"), "甲", "mL", entity_type="ingredient", entity_id=ing.id
    )
    assert result is None


def test_dangling_reference_falls_back_to_global_unit(db, units):
    """引用悬空但本行另有 weight_per_unit 时，退化为全局单位路径（不整体作废）。"""
    ing = _ingredient(db)
    _override(
        db, "ingredient", ing.id, "箱",
        weight=600, weight_unit_id=units["g"].id, weight_unit_override_id=999999,
    )

    result = UnitConversionService(db).convert(
        Decimal("1"), "箱", "g", entity_type="ingredient", entity_id=ing.id
    )
    assert result is not None
    assert float(result[0]) == pytest.approx(600.0)


def test_nested_cross_entity_reference_ignored(db, units):
    """引用必须同实体：跨实体的引用 id 解析不到 → 退化为本行的全局单位路径。"""
    ing_a = _ingredient(db, "牛奶A")
    ing_b = _ingredient(db, "牛奶B")
    box_b = _override(db, "ingredient", ing_b.id, "盒", weight=220, weight_unit_id=units["mL"].id)
    _override(
        db, "ingredient", ing_a.id, "箱",
        weight=300, weight_unit_id=units["g"].id, weight_unit_override_id=box_b.id,
    )

    result = UnitConversionService(db).convert(
        Decimal("1"), "箱", "g", entity_type="ingredient", entity_id=ing_a.id
    )
    assert result is not None
    assert float(result[0]) == pytest.approx(300.0)


def test_recipe_nutrition_nested_chain(db, units):
    """菜谱营养：1箱 = 12 盒 = 2640 mL、密度 1.03 → 2719.2 g，
    54 kcal/100g × 27.192 = 1468.4 kcal（rewrite 后的 recipe_service 分支）。"""
    import asyncio
    from app.models.recipe import Recipe, RecipeIngredient
    from app.models.nutrition_data import NutritionData

    ing = _ingredient(db, "牛奶", density=1030)
    box = _override(db, "ingredient", ing.id, "盒", weight=220, weight_unit_id=units["mL"].id)
    _override(db, "ingredient", ing.id, "箱", weight=12, weight_unit_override_id=box.id)
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
    recipe = Recipe(name="牛奶箱测试", servings=1, ingredients=[
        RecipeIngredient(ingredient_id=ing.id, quantity="1", unit_id=units["箱"].id),
    ])
    db.add(recipe)
    db.commit()

    from app.services.recipe_service import calculate_recipe_nutrition
    result = asyncio.run(calculate_recipe_nutrition(recipe.id, db))
    assert result["total_calories"] == pytest.approx(54.0 * 27.192, abs=0.1)
