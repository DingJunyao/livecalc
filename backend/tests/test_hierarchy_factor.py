"""层级关系换算系数：替代/回退按「1 kg 干 = 3 kg 鲜」折算，未设置时 1:1 兼容。"""
from datetime import datetime, timezone
from decimal import Decimal

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.models.ingredient_hierarchy import IngredientHierarchy
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


def _relation(db, parent, child, relation_type="substitutable", factor=None):
    row = IngredientHierarchy(
        parent_id=parent.id, child_id=child.id,
        relation_type=relation_type, strength=50,
        **(factor or {}),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def test_hierarchy_price_factor_and_sentence(db_session):
    from app.services.entity_link_service import (
        hierarchy_factor_sentence,
        hierarchy_factor_parts,
        hierarchy_price_factor,
    )

    _unit(db_session, "克", "g", "mass", 0.001)
    kg = _unit(db_session, "千克", "kg", "mass", 1)
    fresh = _ingredient(db_session, "系数鲜香菇")
    dried = _ingredient(db_session, "系数干香菇")
    rel = _relation(db_session, dried, fresh, factor={
        "factor_parent_quantity": Decimal("1"),
        "factor_parent_unit": "kg",
        "factor_child_quantity": Decimal("3"),
        "factor_child_unit": "kg",
    })

    parts = hierarchy_factor_parts(rel)
    assert parts is not None
    assert parts[0] == Decimal("1") and parts[2] == Decimal("3")

    factor = hierarchy_price_factor(db_session, rel)
    # 1 kg 干 = 3 kg 鲜 → ppg_鲜 = ppg_干 × 1/3
    assert factor is not None
    assert abs(float(factor) - 1 / 3) < 1e-9

    sentence = hierarchy_factor_sentence(db_session, rel)
    assert sentence is not None
    assert "1 kg" in sentence and "3 kg" in sentence
    assert "系数干香菇" in sentence and "系数鲜香菇" in sentence


def test_fallback_cost_applies_factor(db_session):
    from app.services import recipe_service

    g = _unit(db_session, "克", "g", "mass", 0.001)
    kg = _unit(db_session, "千克", "kg", "mass", 1)
    fresh = _ingredient(db_session, "回退鲜香菇")
    dried = _ingredient(db_session, "回退干香菇")
    dried_product = _product(db_session, dried, "回退干香菇商品")
    # 干 60 元/kg → ppg_干 = 0.06 元/g；鲜 = 0.06 × 1/3 = 0.02 元/g
    _record(db_session, dried_product, 60, 1, kg, g)
    _relation(db_session, dried, fresh, factor={
        "factor_parent_quantity": Decimal("1"),
        "factor_parent_unit": "kg",
        "factor_child_quantity": Decimal("3"),
        "factor_child_unit": "kg",
    })

    rng = recipe_service._fallback_cost_range_ppg(
        db_session, fresh, user_id=1,
        as_of_date=datetime.now(timezone.utc),
    )
    assert rng is not None
    mn, mx, av, chain = rng
    assert abs(float(av) - 0.02) < 1e-9
    assert abs(float(mn) - 0.02) < 1e-9
    assert abs(float(mx) - 0.02) < 1e-9
    assert "回退鲜香菇 → 回退干香菇" in chain
    assert "1 kg" in chain and "3 kg" in chain


def test_fallback_without_factor_stays_one_to_one(db_session):
    """未设系数：行为与历史完全一致（1:1 每克价）。"""
    from app.services import recipe_service

    g = _unit(db_session, "克", "g", "mass", 0.001)
    kg = _unit(db_session, "千克", "kg", "mass", 1)
    fresh = _ingredient(db_session, "无异鲜香菇")
    dried = _ingredient(db_session, "无异干香菇")
    dried_product = _product(db_session, dried, "无异干香菇商品")
    _record(db_session, dried_product, 60, 1, kg, g)
    _relation(db_session, dried, fresh)

    rng = recipe_service._fallback_cost_range_ppg(
        db_session, fresh, user_id=1,
        as_of_date=datetime.now(timezone.utc),
    )
    assert rng is not None
    mn, mx, av, chain = rng
    assert abs(float(av) - 0.06) < 1e-9
    assert "（" not in chain  # 无系数不加等式


def test_api_create_and_partial_factor(db_session, as_admin):
    a = _ingredient(db_session, "系数接口A")
    b = _ingredient(db_session, "系数接口B")

    # 部分填写 → 400
    partial = client.post(
        "/api/v1/ingredients/hierarchy",
        json={
            "parent_id": a.id, "child_id": b.id,
            "relation_type": "substitutable",
            "factor_parent_quantity": 1, "factor_parent_unit": "kg",
        },
    )
    assert partial.status_code == 400, partial.text

    # 完整填写 → 创建成功并回显
    ok = client.post(
        "/api/v1/ingredients/hierarchy",
        json={
            "parent_id": a.id, "child_id": b.id,
            "relation_type": "substitutable",
            "factor_parent_quantity": 1, "factor_parent_unit": "kg",
            "factor_child_quantity": 3, "factor_child_unit": "kg",
        },
    )
    assert ok.status_code in (200, 201), ok.text
    body = ok.json()
    assert body["factor_parent_quantity"] == 1
    assert body["factor_child_quantity"] == 3

    # GET 回读
    listed = client.get(f"/api/v1/ingredients/{a.id}/hierarchy")
    assert listed.status_code == 200
    rows = listed.json()["child_relations"] + listed.json()["parent_relations"]
    target = [r for r in rows if r["id"] == body["id"]]
    assert target and target[0]["factor_child_unit"] == "kg"

    # 更新为 1:1（全空）→ 清除系数
    cleared = client.put(
        f"/api/v1/ingredients/hierarchy/{body['id']}",
        json={"strength": 60},
    )
    assert cleared.status_code == 200, cleared.text
    assert cleared.json()["strength"] == 60
    assert cleared.json()["factor_parent_quantity"] is None
