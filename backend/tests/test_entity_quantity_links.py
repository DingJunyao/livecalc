"""商品/原料数量关联：折克、因子、API 与成本链。"""
from datetime import datetime, timezone
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.models.entity_quantity_link import EntityQuantityLink
from app.models.entity_unit_override import EntityUnitOverride
from app.models.nutrition import Ingredient
from app.models.product import ProductRecord
from app.models.product_entity import Product
from app.models.unit import Unit
from app.services.proposals.bootstrap import register_all

client = TestClient(app)


@pytest.fixture(autouse=True)
def _setup():
    register_all()
    previous = dict(app.dependency_overrides)
    yield
    app.dependency_overrides.clear()
    app.dependency_overrides.update(previous)


def _unit(db, name, abbr, unit_type, si):
    unit = db.query(Unit).filter(Unit.abbreviation == abbr).first()
    if unit is None:
        unit = Unit(
            name=name, abbreviation=abbr, unit_type=unit_type,
            si_factor=Decimal(str(si)), unit_system="metric",
        )
        db.add(unit)
        db.commit()
        db.refresh(unit)
    return unit


def _ingredient(db, name):
    ing = Ingredient(name=name, is_active=True)
    db.add(ing)
    db.commit()
    db.refresh(ing)
    return ing


def _product(db, ingredient, name):
    p = Product(name=name, ingredient_id=ingredient.id, price_weight=50, is_active=True)
    db.add(p)
    db.commit()
    db.refresh(p)
    return p


def _override(db, product, unit_name, grams, g_unit):
    db.add(EntityUnitOverride(
        entity_type="product", entity_id=product.id, unit_name=unit_name,
        weight_per_unit=grams, weight_unit_id=g_unit.id,
        conversion_factor=1, is_active=True,
    ))
    db.commit()


def _record(db, product, price, quantity, unit, g_unit):
    db.add(ProductRecord(
        user_id=1, product_id=product.id, product_name=product.name,
        price=Decimal(str(price)), currency="CNY", user_currency="CNY",
        original_quantity=Decimal(str(quantity)), original_unit_id=unit.id,
        standard_quantity=Decimal(str(quantity)) * Decimal(str(unit.si_factor)) * 1000,
        standard_unit_id=g_unit.id,
        exchange_rate=Decimal("1"),
        recorded_at=datetime.now(timezone.utc).replace(tzinfo=None),
        is_active=True,
    ))
    db.commit()


def _link(db, from_type, from_id, from_qty, from_unit, to_type, to_id, to_qty, to_unit):
    row = EntityQuantityLink(
        from_type=from_type, from_id=from_id,
        from_quantity=Decimal(str(from_qty)), from_unit=from_unit,
        to_type=to_type, to_id=to_id,
        to_quantity=Decimal(str(to_qty)), to_unit=to_unit,
        is_active=True,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def test_resolve_unit_grams_and_link_factor(db_session):
    g = _unit(db_session, "克", "g", "mass", 0.001)
    kg = _unit(db_session, "千克", "kg", "mass", 1)
    ing = _ingredient(db_session, "测试方便面")
    five = _product(db_session, ing, "测试五连包")
    single = _product(db_session, ing, "测试单包")
    box = _product(db_session, ing, "测试整箱")
    _override(db_session, single, "包", 85, g)
    _link(db_session, "product", five.id, 1, "提", "product", single.id, 5, "包")
    _link(db_session, "product", box.id, 1, "箱", "product", five.id, 4, "提")

    from app.services.entity_link_service import (
        link_price_factor,
        resolve_unit_grams,
    )

    assert resolve_unit_grams(db_session, "product", five.id, "提") == Decimal("425")
    assert resolve_unit_grams(db_session, "product", single.id, "包") == Decimal("85")
    from app.services.unit_conversion_service import UnitConversionService
    converted = UnitConversionService(db_session).convert(
        Decimal("1"), "提", "g", entity_type="product", entity_id=five.id,
    )
    assert converted is not None
    assert converted[0] == Decimal("425")
    assert resolve_unit_grams(db_session, "product", box.id, "箱") == Decimal("1700")
    factor = link_price_factor(
        Decimal("425"), Decimal("1"), Decimal("85"), Decimal("5"),
    )
    assert factor == Decimal("1")


def test_ingredient_link_factor_and_cost(db_session):
    g = _unit(db_session, "克", "g", "mass", 0.001)
    kg = _unit(db_session, "千克", "kg", "mass", 1)
    fresh = _ingredient(db_session, "测试鲜香菇")
    dried = _ingredient(db_session, "测试干香菇")
    dried_product = _product(db_session, dried, "测试干香菇商品")
    _record(db_session, dried_product, 60, 1, kg, g)
    _link(db_session, "ingredient", fresh.id, 3, "kg", "ingredient", dried.id, 1, "kg")

    from app.services.entity_link_service import resolve_unit_grams
    from app.services import recipe_service

    assert resolve_unit_grams(db_session, "ingredient", fresh.id, "kg") == Decimal("1000")
    from app.services.entity_link_service import get_links_for_entity
    assert len(get_links_for_entity(db_session, "ingredient", fresh.id)) == 1
    direct = recipe_service._entity_direct_cost_range_ppg(
        db_session, "ingredient", dried.id, user_id=1,
        as_of_date=datetime.now(timezone.utc),
    )
    assert direct is not None, "dried direct price should exist"
    linked = recipe_service._linked_cost_range_ppg(
        db_session, "ingredient", fresh.id, user_id=1,
        as_of_date=datetime.now(timezone.utc),
    )
    assert linked is not None
    mn, mx, av, chain = linked
    assert abs(float(av) - 0.02) < 1e-9
    assert "测试干香菇" in chain


def test_api_crud(db_session, as_admin):
    ing = _ingredient(db_session, "测试关联原料")
    a = _product(db_session, ing, "测试关联商品A")
    b = _product(db_session, ing, "测试关联商品B")

    resp = client.post(
        f"/api/v1/entities/product/{a.id}/quantity-links",
        json={
            "to_type": "product", "to_id": b.id,
            "from_quantity": 1, "from_unit": "提",
            "to_quantity": 5, "to_unit": "包",
        },
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["current"]["quantity"] == 1
    assert body["other"]["quantity"] == 5
    link_id = body["id"]

    listed = client.get(f"/api/v1/entities/product/{a.id}/quantity-links")
    assert listed.status_code == 200
    assert len(listed.json()["items"]) == 1

    updated = client.put(
        f"/api/v1/entities/product/{a.id}/quantity-links/{link_id}",
        json={"to_quantity": 6},
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["other"]["quantity"] == 6

    deleted = client.delete(
        f"/api/v1/entities/product/{a.id}/quantity-links/{link_id}",
    )
    assert deleted.status_code == 200, deleted.text
    assert deleted.json()["pending"] is False


def test_api_pending(db_session, as_non_admin):
    ing = _ingredient(db_session, "测试待审关联原料")
    a = _product(db_session, ing, "测试待审商品A")
    b = _product(db_session, ing, "测试待审商品B")

    pending = client.post(
        f"/api/v1/entities/product/{b.id}/quantity-links",
        json={
            "to_type": "product", "to_id": a.id,
            "from_quantity": 5, "from_unit": "包",
            "to_quantity": 1, "to_unit": "提",
        },
    )
    assert pending.status_code == 201, pending.text
    assert pending.json()["pending"] is True
