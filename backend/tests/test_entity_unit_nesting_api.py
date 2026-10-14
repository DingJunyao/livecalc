"""实体单位覆盖新增 weight_unit_override_id（嵌套自定义单位）的端点校验测试。

规则：
- weight_unit_override_id 必须指向**同一实体**的另一个活跃自定义单位
- weight_unit_id 与 weight_unit_override_id 互斥
- 不能自引用、不能成环
"""
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.services.proposals.bootstrap import register_all

client = TestClient(app)


@pytest.fixture(autouse=True)
def _setup():
    """TestClient 不触发 main.py lifespan，需显式注册执行器。"""
    register_all()
    previous = dict(app.dependency_overrides)
    yield
    app.dependency_overrides.clear()
    app.dependency_overrides.update(previous)


def _ingredient(db_session, name="嵌套单位测试原料"):
    from app.models.nutrition import Ingredient
    ing = Ingredient(name=name, is_active=True)
    db_session.add(ing)
    db_session.commit()
    db_session.refresh(ing)
    return ing.id


def _unit(db_session, abbr="mL"):
    from app.models.unit import Unit
    from decimal import Decimal
    u = db_session.query(Unit).filter(Unit.abbreviation == abbr).first()
    if u is None:
        u = Unit(name=abbr, abbreviation=abbr, unit_type="volume",
                 si_factor=Decimal("0.001"), unit_system="metric")
        db_session.add(u)
        db_session.commit()
        db_session.refresh(u)
    return u.id


def test_admin_create_nested_override(db_session, as_admin):
    """先建「盒」，再建引用它的「箱」→ 201 且回显引用 id。"""
    ing_id = _ingredient(db_session)
    ml_id = _unit(db_session, "mL")

    box = client.post(
        f"/api/v1/entities/ingredient/{ing_id}/units",
        json={"unit_name": "盒", "weight_per_unit": 220, "weight_unit_id": ml_id},
    )
    assert box.status_code == 201, box.text
    box_id = box.json()["id"]

    carton = client.post(
        f"/api/v1/entities/ingredient/{ing_id}/units",
        json={"unit_name": "箱", "weight_per_unit": 12, "weight_unit_override_id": box_id},
    )
    assert carton.status_code == 201, carton.text
    body = carton.json()
    assert body["weight_unit_override_id"] == box_id
    assert body["weight_unit_id"] is None

    listed = client.get(f"/api/v1/entities/ingredient/{ing_id}/units").json()
    carton_row = next(u for u in listed if u["unit_name"] == "箱")
    assert carton_row["weight_unit_override_id"] == box_id


def _product(db_session, ingredient_id, name="继承测试商品"):
    from app.models.product_entity import Product
    p = Product(name=name, ingredient_id=ingredient_id, is_active=True)
    db_session.add(p)
    db_session.commit()
    db_session.refresh(p)
    return p.id


def test_product_can_reference_its_ingredient_unit(db_session, as_admin):
    """继承：商品的自定义单位可以引用其关联原料的自定义单位。"""
    ing_id = _ingredient(db_session, "继承测试原料")
    ml_id = _unit(db_session, "mL")
    box = client.post(
        f"/api/v1/entities/ingredient/{ing_id}/units",
        json={"unit_name": "盒", "weight_per_unit": 220, "weight_unit_id": ml_id},
    ).json()
    product_id = _product(db_session, ing_id)

    resp = client.post(
        f"/api/v1/entities/product/{product_id}/units",
        json={"unit_name": "箱", "weight_per_unit": 12, "weight_unit_override_id": box["id"]},
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["weight_unit_override_id"] == box["id"]


def test_product_reject_other_ingredient_unit(db_session, as_admin):
    """继承只限自己所属的原料：引用别的原料的覆盖仍应 400。"""
    mine = _ingredient(db_session, "我的原料X")
    other = _ingredient(db_session, "别人的原料Y")
    other_box = client.post(
        f"/api/v1/entities/ingredient/{other}/units",
        json={"unit_name": "盒", "weight_per_unit": 220},
    ).json()
    product_id = _product(db_session, mine, "我的商品X")

    resp = client.post(
        f"/api/v1/entities/product/{product_id}/units",
        json={"unit_name": "箱", "weight_per_unit": 12, "weight_unit_override_id": other_box["id"]},
    )
    assert resp.status_code == 400
    assert "关联原料" in resp.text


def test_reject_both_weight_units(db_session, as_admin):
    ing_id = _ingredient(db_session)
    ml_id = _unit(db_session, "mL")
    box = client.post(
        f"/api/v1/entities/ingredient/{ing_id}/units",
        json={"unit_name": "盒", "weight_per_unit": 220, "weight_unit_id": ml_id},
    ).json()

    resp = client.post(
        f"/api/v1/entities/ingredient/{ing_id}/units",
        json={
            "unit_name": "箱",
            "weight_per_unit": 12,
            "weight_unit_id": ml_id,
            "weight_unit_override_id": box["id"],
        },
    )
    assert resp.status_code == 400
    assert "只能设置其一" in resp.text


def test_reject_self_reference(db_session, as_admin):
    ing_id = _ingredient(db_session)
    box = client.post(
        f"/api/v1/entities/ingredient/{ing_id}/units",
        json={"unit_name": "盒", "weight_per_unit": 220},
    ).json()

    resp = client.put(
        f"/api/v1/entities/ingredient/{ing_id}/units/{box['id']}",
        json={"weight_unit_override_id": box["id"]},
    )
    assert resp.status_code == 400
    assert "自身" in resp.text


def test_reject_cross_entity_reference(db_session, as_admin):
    ing_a = _ingredient(db_session, "实体A")
    ing_b = _ingredient(db_session, "实体B")
    box_b = client.post(
        f"/api/v1/entities/ingredient/{ing_b}/units",
        json={"unit_name": "盒", "weight_per_unit": 220},
    ).json()

    resp = client.post(
        f"/api/v1/entities/ingredient/{ing_a}/units",
        json={"unit_name": "箱", "weight_per_unit": 12, "weight_unit_override_id": box_b["id"]},
    )
    assert resp.status_code == 400
    assert "同一实体" in resp.text


def test_reject_cycle(db_session, as_admin):
    ing_id = _ingredient(db_session)
    a = client.post(
        f"/api/v1/entities/ingredient/{ing_id}/units",
        json={"unit_name": "甲", "weight_per_unit": 2},
    ).json()
    b = client.post(
        f"/api/v1/entities/ingredient/{ing_id}/units",
        json={"unit_name": "乙", "weight_per_unit": 3, "weight_unit_override_id": a["id"]},
    ).json()

    resp = client.put(
        f"/api/v1/entities/ingredient/{ing_id}/units/{a['id']}",
        json={"weight_unit_override_id": b["id"]},
    )
    assert resp.status_code == 400
    assert "循环引用" in resp.text


def test_reject_dangling_reference(db_session, as_admin):
    ing_id = _ingredient(db_session)
    resp = client.post(
        f"/api/v1/entities/ingredient/{ing_id}/units",
        json={"unit_name": "箱", "weight_per_unit": 12, "weight_unit_override_id": 987654},
    )
    assert resp.status_code == 400
    assert "不存在" in resp.text
