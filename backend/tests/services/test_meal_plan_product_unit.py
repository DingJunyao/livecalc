import asyncio
import uuid
from datetime import datetime, timezone

import pytest
from conftest import FakeUser


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
