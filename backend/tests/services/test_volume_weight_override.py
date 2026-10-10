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


# ---------- 存量修复：/nutrition 单品接口与 ¥/斤 归一 ----------

def test_nutrition_single_item_count_volume_override(db, units):
    """单品营养：1瓶牛奶（体积覆盖 500mL、密度1.03）→ base_quantity=515g（原按 1g 算）"""
    from app.services.nutrition_calculator import NutritionCalculator
    ing = make_milk(db, units, density=1030)
    base = NutritionCalculator(db)._convert_to_base(1.0, "瓶", ing.id)
    assert base == pytest.approx(515.0)


def test_nutrition_single_item_count_without_data_returns_zero(db, units):
    """计数单位无覆盖无 piece_weight → 0（与菜谱营养口径一致，不按 100g 臆估）"""
    from app.services.nutrition_calculator import NutritionCalculator
    ing = Ingredient(name="蒜")
    db.add(ing)
    db.commit()
    base = NutritionCalculator(db)._convert_to_base(2.0, "瓶", ing.id)
    assert base == 0.0


def test_nutrition_single_item_volume_with_density(db, units):
    """单品营养：200mL 牛奶（密度1.03）→ 206g（原 1:1 按 200g）"""
    from app.services.nutrition_calculator import NutritionCalculator
    ing = make_milk(db, units, density=1030)
    base = NutritionCalculator(db)._convert_to_base(200.0, "mL", ing.id)
    assert base == pytest.approx(206.0)


def test_nutrition_single_item_mass_regression(db, units):
    """单品营养回归：100g / 1kg 与旧转换表一致"""
    from app.services.nutrition_calculator import NutritionCalculator
    ing = Ingredient(name="米")
    db.add(ing)
    db.commit()
    calc = NutritionCalculator(db)
    assert calc._convert_to_base(100.0, "g", ing.id) == pytest.approx(100.0)
    assert calc._convert_to_base(1.0, "kg", ing.id) == pytest.approx(1000.0)


def test_record_standard_grams_mass_and_volume(db, units):
    """record_standard_grams：质量标准直取；体积标准（历史遗留）经密度折克"""
    from app.services.price_aggregator import record_standard_grams
    ing = make_milk(db, units, density=1030)
    product = Product(name="某牌牛奶", ingredient_id=ing.id)
    db.add(product)
    db.commit()
    # 质量标准：直取
    assert record_standard_grams(db, 250, units["g"].id, product.id) == pytest.approx(250.0)
    # 体积标准（ml）：250 × 1.03 = 257.5
    assert record_standard_grams(db, 250, units["mL"].id, product.id) == pytest.approx(257.5)
    # 体积标准、无密度记录 → 水兜底 1:1
    ing2 = Ingredient(name="清水")
    db.add(ing2)
    db.commit()
    product2 = Product(name="瓶装水", ingredient_id=ing2.id)
    db.add(product2)
    db.commit()
    assert record_standard_grams(db, 250, units["mL"].id, product2.id) == pytest.approx(250.0)


def test_recompute_summary_volume_record_uses_density(db, units):
    """recompute_summary：体积标准记录折克后归一 ¥/斤（原把 ml 当克）"""
    from app.models.product import ProductRecord
    from app.models.price_summary import ProductMerchantPriceSummary
    from app.services.price_aggregator import recompute_summary
    ing = make_milk(db, units, density=1030)
    product = Product(name="某牌牛奶1L", ingredient_id=ing.id)
    db.add(product)
    db.commit()
    db.add(ProductRecord(
        product_id=product.id, price=10.0, user_id=1, product_name=product.name,
        original_quantity=1, original_unit_id=units["L"].id,
        standard_quantity=1000, standard_unit_id=units["mL"].id,
    ))
    db.commit()
    recompute_summary(db, product_id=product.id, merchant_id=None)
    s = db.query(ProductMerchantPriceSummary).filter_by(product_id=product.id).one()
    # 1000 ml × 1.03 = 1030 g → 10 / 1030 × 500 ≈ 4.854 元/斤（原按 1000g → 5.0）
    assert float(s.avg_price_30d) == pytest.approx(10 / 1030 * 500, abs=0.01)
