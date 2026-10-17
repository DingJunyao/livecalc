import asyncio
import uuid

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
