import asyncio
import uuid
from datetime import datetime, timezone

import pytest
from types import SimpleNamespace
from conftest import FakeUser
from app.services import recipe_service


def _ensure_kg_unit(db_session):
    """内存测试库默认没有 kg 单位；计数单位折算（_get_piece_weight_kg）需要它。

    返回 (kg 单位, 是否本次新建)；已存在时调用方不要删除，避免影响其他用例。
    """
    from app.models.unit import Unit

    kg = db_session.query(Unit).filter(Unit.abbreviation == "kg").first()
    if kg is not None:
        return kg, False
    kg = Unit(
        name="千克", abbreviation="kg", unit_type="mass",
        si_factor=1.0, is_active=True,
    )
    db_session.add(kg)
    db_session.flush()
    return kg, True


def test_product_without_unit_uses_latest_price_record_standard_unit(db_session):
    """商品条目未选单位时，应继承最新价格记录的标准单位，而不是返回空。"""
    from app.models.nutrition import Ingredient
    from app.models.product import ProductRecord
    from app.models.product_entity import Product
    from app.models.unit import Unit
    from app.services.meal_plan_service import evaluate_items

    suffix = uuid.uuid4().hex[:8]
    unit = Unit(
        name=f"克-{suffix}",
        abbreviation=f"g-{suffix}",
        unit_type="mass",
        is_active=True,
    )
    ingredient = Ingredient(
        name=f"测试原料-{suffix}",
        ai_inferred=False,
        is_imported=False,
        is_merged=False,
        is_active=True,
    )
    db_session.add_all([unit, ingredient])
    db_session.flush()

    product = Product(
        name=f"测试商品-{suffix}",
        ingredient_id=ingredient.id,
        price_weight=50,
        is_active=True,
    )
    db_session.add(product)
    db_session.flush()
    record = ProductRecord(
        user_id=FakeUser.id,
        product_id=product.id,
        product_name=product.name,
        price=10,
        original_quantity=1,
        original_unit_id=unit.id,
        standard_quantity=500,
        standard_unit_id=unit.id,
        is_active=True,
    )
    db_session.add(record)
    db_session.commit()

    try:
        payload = asyncio.run(
            evaluate_items(
                db_session,
                FakeUser(),
                [{
                    "group": "dinner",
                    "item_type": "product",
                    "product_id": product.id,
                    "quantity": 120,
                    "unit_id": None,
                }],
            )
        )
    finally:
        expected_unit_abbreviation = unit.abbreviation
        db_session.query(ProductRecord).filter(
            ProductRecord.product_id == product.id
        ).delete(synchronize_session=False)
        db_session.query(Product).filter(Product.id == product.id).delete(
            synchronize_session=False
        )
        db_session.query(Ingredient).filter(
            Ingredient.id == ingredient.id
        ).delete(synchronize_session=False)
        db_session.query(Unit).filter(Unit.id == unit.id).delete(
            synchronize_session=False
        )
        db_session.commit()

    assert payload["items"][0]["unit"] == expected_unit_abbreviation
    assert payload["items"][0]["cost"] == 2.4


def test_weighted_ingredient_price_converts_standard_unit_to_target(db_session):
    """原料按“根”试算时，应把克价换算成根价，避免小额成本被四舍五入成 0。"""
    from app.models.entity_unit_override import EntityUnitOverride
    from app.models.nutrition import Ingredient
    from app.models.product import ProductRecord
    from app.models.product_entity import Product
    from app.models.unit import Unit
    from app.services.ingredient_price_service import get_weighted_ingredient_price

    suffix = uuid.uuid4().hex[:8]
    gram = Unit(
        name=f"克-{suffix}", abbreviation=f"g-{suffix}", unit_type="mass",
        si_factor=0.001,
        is_active=True,
    )
    root = Unit(
        name=f"根-{suffix}", abbreviation=f"根-{suffix}", unit_type="count",
        is_active=True,
    )
    ingredient = Ingredient(
        name=f"测试胡萝卜-{suffix}", ai_inferred=False, is_imported=False,
        is_merged=False, is_active=True,
    )
    db_session.add_all([gram, root, ingredient])
    db_session.flush()
    product = Product(
        name=f"测试胡萝卜商品-{suffix}", ingredient_id=ingredient.id,
        price_weight=50, is_active=True,
    )
    db_session.add(product)
    db_session.flush()
    db_session.add(ProductRecord(
        user_id=FakeUser.id,
        product_id=product.id,
        product_name=product.name,
        price=1.18,
        original_quantity=1,
        original_unit_id=gram.id,
        standard_quantity=500,
        standard_unit_id=gram.id,
        is_active=True,
    ))
    db_session.add(EntityUnitOverride(
        entity_type="ingredient",
        entity_id=ingredient.id,
        unit_name=root.name,
        weight_per_unit=120,
        weight_unit_id=gram.id,
        is_default=True,
        source="manual",
        is_active=True,
    ))
    db_session.commit()

    try:
        result = get_weighted_ingredient_price(
            db_session,
            ingredient.id,
            as_of_date=datetime.now(timezone.utc),
            user_id=FakeUser.id,
            target_unit_abbr=root.abbreviation,
            tz="Asia/Shanghai",
        )
    finally:
        expected_unit_abbreviation = root.abbreviation
        print("weighted-debug", result.get("unit"), result.get("unit_price"))
        print("participant-debug", result.get("participant_records"))
        db_session.query(ProductRecord).filter(
            ProductRecord.product_id == product.id
        ).delete(synchronize_session=False)
        db_session.query(Product).filter(Product.id == product.id).delete(
            synchronize_session=False
        )
        db_session.query(Ingredient).filter(
            Ingredient.id == ingredient.id
        ).delete(synchronize_session=False)
        db_session.query(Unit).filter(Unit.id.in_([gram.id, root.id])).delete(
            synchronize_session=False
        )
        db_session.commit()

    assert result["unit"] == expected_unit_abbreviation
    assert result["unit_price"] == pytest.approx(1.18 / 500 * 120)


def test_ingredient_nutrition_from_product_backfill_with_count_unit(db_session):
    """原料无自有营养数据、按「根」试算：营养应经关联商品加权平均回填 + 单件重量折算。

    复现线上问题：火腿肠（原料）没有 nutrition_data，营养挂在关联商品的自定义
    营养上；旧实现直接读 nutrition_data 首行 + 手工换算克数 → 整项营养为 null，
    脂肪不计入方案合计。现口径与原料营养详情页一致（NutritionCalculator）。
    """
    from app.models.entity_unit_override import EntityUnitOverride
    from app.models.nutrition import Ingredient
    from app.models.product import ProductRecord
    from app.models.product_entity import Product
    from app.models.unit import Unit
    from app.services.meal_plan_service import evaluate_items

    kg, kg_created = _ensure_kg_unit(db_session)
    suffix = uuid.uuid4().hex[:8]
    gram = Unit(
        name=f"克-{suffix}", abbreviation=f"g-{suffix}", unit_type="mass",
        si_factor=0.001,
        is_active=True,
    )
    root = Unit(
        name=f"根-{suffix}", abbreviation=f"根-{suffix}", unit_type="count",
        is_active=True,
    )
    ingredient = Ingredient(
        name=f"测试火腿肠-{suffix}", ai_inferred=False, is_imported=False,
        is_merged=False, is_active=True,
    )
    db_session.add_all([gram, root, ingredient])
    db_session.flush()
    product = Product(
        name=f"测试火腿肠商品-{suffix}", ingredient_id=ingredient.id,
        price_weight=50, is_active=True,
        custom_nutrition_data={
            "reference_amount": 100,
            "reference_unit": "g",
            "all_nutrients": {
                "energy": {"value": 200, "unit": "kcal", "key": "energy"},
                "protein": {"value": 15, "unit": "g", "key": "protein"},
                "fat": {"value": 10, "unit": "g", "key": "fat"},
                "carbohydrate": {"value": 5, "unit": "g", "key": "carbohydrate"},
            },
        },
    )
    db_session.add(product)
    db_session.flush()
    db_session.add(ProductRecord(
        user_id=FakeUser.id,
        product_id=product.id,
        product_name=product.name,
        price=3.0,
        original_quantity=1,
        original_unit_id=gram.id,
        standard_quantity=120,
        standard_unit_id=gram.id,
        is_active=True,
    ))
    db_session.add(EntityUnitOverride(
        entity_type="ingredient",
        entity_id=ingredient.id,
        unit_name=root.name,
        weight_per_unit=120,
        weight_unit_id=gram.id,
        is_default=True,
        source="manual",
        is_active=True,
    ))
    db_session.commit()

    ingredient_name = ingredient.name  # finally 删行后 ORM 实例会过期，先留名
    try:
        payload = asyncio.run(
            evaluate_items(
                db_session,
                FakeUser(),
                [{
                    "group": "dinner",
                    "item_type": "ingredient",
                    "ingredient_id": ingredient.id,
                    "quantity": 2,
                    "unit_id": root.id,
                }],
            )
        )
    finally:
        db_session.query(ProductRecord).filter(
            ProductRecord.product_id == product.id
        ).delete(synchronize_session=False)
        db_session.query(EntityUnitOverride).filter(
            EntityUnitOverride.entity_type == "ingredient",
            EntityUnitOverride.entity_id == ingredient.id,
        ).delete(synchronize_session=False)
        db_session.query(Product).filter(Product.id == product.id).delete(
            synchronize_session=False
        )
        if kg_created:
            db_session.query(Unit).filter(Unit.id == kg.id).delete(
                synchronize_session=False
            )
        db_session.query(Ingredient).filter(
            Ingredient.id == ingredient.id
        ).delete(synchronize_session=False)
        db_session.query(Unit).filter(Unit.id.in_([gram.id, root.id])).delete(
            synchronize_session=False
        )
        db_session.commit()

    info = payload["items"][0]
    # 2 根 = 240 g，每 100 g 脂肪 10 g → 24 g；旧实现这里 nutrition 是 None
    assert info["nutrition"] is not None
    assert info["nutrition"]["fat_g"] == pytest.approx(24.0)
    assert info["nutrition"]["calories"] == pytest.approx(480.0)
    assert info["nutrition"]["protein_g"] == pytest.approx(36.0)
    assert info["nutrition"]["carbs_g"] == pytest.approx(12.0)
    assert payload["totals"]["fat_g"] == pytest.approx(24.0)
    # 营养来源明细里要有这一项（脂肪的贡献方包含火腿肠）
    details = (payload.get("nutrition") or {}).get("ingredient_details") or []
    assert any(
        d.get("ingredient_name") == ingredient_name
        and (d.get("nutrition_contribution") or {}).get("fat", {}).get("value") == 24.0
        for d in details
    )


def test_ingredient_nutrition_uses_own_row_with_count_unit(db_session):
    """原料有自有营养行、按「根」试算：基准 100 g + 单件重量 120 g 折算不变。"""
    from app.models.entity_unit_override import EntityUnitOverride
    from app.models.nutrition import Ingredient
    from app.models.nutrition_data import NutritionData
    from app.models.unit import Unit
    from app.services.meal_plan_service import evaluate_items

    kg, kg_created = _ensure_kg_unit(db_session)
    suffix = uuid.uuid4().hex[:8]
    gram = Unit(
        name=f"克-{suffix}", abbreviation=f"g-{suffix}", unit_type="mass",
        si_factor=0.001,
        is_active=True,
    )
    root = Unit(
        name=f"根-{suffix}", abbreviation=f"根-{suffix}", unit_type="count",
        is_active=True,
    )
    ingredient = Ingredient(
        name=f"测试午餐肉-{suffix}", ai_inferred=False, is_imported=False,
        is_merged=False, is_active=True,
    )
    db_session.add_all([gram, root, ingredient])
    db_session.flush()
    db_session.add(NutritionData(
        ingredient_id=ingredient.id,
        nutrients={
            "all_nutrients": {
                "energy": {"value": 300, "unit": "kcal", "key": "energy"},
                "protein": {"value": 10, "unit": "g", "key": "protein"},
                "fat": {"value": 25, "unit": "g", "key": "fat"},
                "carbohydrate": {"value": 6, "unit": "g", "key": "carbohydrate"},
            },
        },
        source="custom",
        reference_amount=100.0,
        reference_unit="g",
        is_verified=True,
    ))
    db_session.add(EntityUnitOverride(
        entity_type="ingredient",
        entity_id=ingredient.id,
        unit_name=root.name,
        weight_per_unit=80,
        weight_unit_id=gram.id,
        is_default=True,
        source="manual",
        is_active=True,
    ))
    db_session.commit()

    try:
        payload = asyncio.run(
            evaluate_items(
                db_session,
                FakeUser(),
                [{
                    "group": "dinner",
                    "item_type": "ingredient",
                    "ingredient_id": ingredient.id,
                    "quantity": 1,
                    "unit_id": root.id,
                }],
            )
        )
    finally:
        db_session.query(NutritionData).filter(
            NutritionData.ingredient_id == ingredient.id
        ).delete(synchronize_session=False)
        db_session.query(EntityUnitOverride).filter(
            EntityUnitOverride.entity_type == "ingredient",
            EntityUnitOverride.entity_id == ingredient.id,
        ).delete(synchronize_session=False)
        db_session.query(Ingredient).filter(
            Ingredient.id == ingredient.id
        ).delete(synchronize_session=False)
        if kg_created:
            db_session.query(Unit).filter(Unit.id == kg.id).delete(
                synchronize_session=False
            )
        db_session.query(Unit).filter(Unit.id.in_([gram.id, root.id])).delete(
            synchronize_session=False
        )
        db_session.commit()

    info = payload["items"][0]
    # 1 根 = 80 g，每 100 g 脂肪 25 g → 20 g
    assert info["nutrition"] is not None
    assert info["nutrition"]["fat_g"] == pytest.approx(20.0)
    assert info["nutrition"]["calories"] == pytest.approx(240.0)
    assert payload["totals"]["fat_g"] == pytest.approx(20.0)


def test_plan_cost_trend_scales_recipe_range_by_servings(monkeypatch):
    from app.services import meal_plan_service as meal_plan_service
    from app.services import recipe_service

    # plan_cost_trend 的逐日 key 是按 UTC「今天」倒推的；日期写死会让测试随时间失效
    today = datetime.now(timezone.utc).date().isoformat()
    point = {
        "date": today,
        "avg_cost": 3.0,
        "min_cost": 1.0,
        "max_cost": 4.0,
        "currency": "CNY",
    }
    monkeypatch.setattr(
        recipe_service,
        "calculate_recipe_cost_range_trend",
        lambda *args, **kwargs: [point],
    )
    plan = SimpleNamespace(items=[SimpleNamespace(
        recipe_id=1, servings=2, item_type="recipe",
    )])
    user = SimpleNamespace(id=FakeUser.id)

    result = meal_plan_service.plan_cost_trend(
        None, user, plan, days=1, tz="Asia/Shanghai"
    )

    assert len(result) == 1
    assert result[0]["avg_cost"] == pytest.approx(6.0)
    assert result[0]["min_cost"] == pytest.approx(2.0)
    assert result[0]["max_cost"] == pytest.approx(8.0)
    assert result[0]["total_cost"] == pytest.approx(6.0)


def test_plan_cost_trend_keeps_recipe_average_with_loose_items(monkeypatch):
    from app.services import meal_plan_service as meal_plan_service

    today = datetime.now(timezone.utc).date().isoformat()
    recipe_point = {
        "date": today,
        "avg_cost": 3.0,
        "min_cost": 1.0,
        "max_cost": 4.0,
        "currency": "CNY",
    }
    monkeypatch.setattr(
        recipe_service,
        "calculate_recipe_cost_range_trend",
        lambda *args, **kwargs: [recipe_point],
    )
    monkeypatch.setattr(
        meal_plan_service,
        "get_weighted_ingredient_price",
        lambda *args, **kwargs: {"unit_price": 0.1, "currency": "CNY"},
    )
    plan = SimpleNamespace(items=[
        SimpleNamespace(recipe_id=1, servings=1, item_type="recipe"),
        SimpleNamespace(
            ingredient_id=1, quantity=1, unit=None, item_type="ingredient",
        ),
    ])
    user = SimpleNamespace(id=FakeUser.id)

    result = meal_plan_service.plan_cost_trend(
        None, user, plan, days=1, tz="Asia/Shanghai"
    )

    assert result[0]["avg_cost"] == pytest.approx(3.1)
    assert result[0]["min_cost"] == pytest.approx(1.1)
    assert result[0]["max_cost"] == pytest.approx(4.1)
    assert result[0]["total_cost"] == pytest.approx(3.1)


def test_plan_cost_trend_marks_recipe_record_days(monkeypatch):
    """菜谱项当天有价格记录 → 方案走势的 has_record 透传 True（供图表只在此画点）。"""
    from app.services import meal_plan_service as meal_plan_service

    today = datetime.now(timezone.utc).date().isoformat()
    point = {
        "date": today,
        "avg_cost": 3.0,
        "min_cost": 1.0,
        "max_cost": 4.0,
        "currency": "CNY",
        "has_record": True,
    }
    monkeypatch.setattr(
        recipe_service,
        "calculate_recipe_cost_range_trend",
        lambda *args, **kwargs: [point],
    )
    plan = SimpleNamespace(items=[
        SimpleNamespace(recipe_id=1, servings=1, item_type="recipe"),
    ])
    user = SimpleNamespace(id=FakeUser.id)

    result = meal_plan_service.plan_cost_trend(
        None, user, plan, days=1, tz="Asia/Shanghai"
    )

    assert result[0]["has_record"] is True

    # 菜谱项当天无新记录（as-of 携带日）→ has_record 为 False
    point_no_record = dict(point, has_record=False)
    monkeypatch.setattr(
        recipe_service,
        "calculate_recipe_cost_range_trend",
        lambda *args, **kwargs: [point_no_record],
    )
    result2 = meal_plan_service.plan_cost_trend(
        None, user, plan, days=1, tz="Asia/Shanghai"
    )
    assert result2[0]["has_record"] is False
