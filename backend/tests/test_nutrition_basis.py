"""营养基准（「每 X 单位」）落库 / 读取 / 缩放口径测试。

背景：营养数据长期只有「每 100 g」一种基准（reference_amount/reference_unit）。
现在编辑器可以改成别的量/单位（mL、斤，或该实体自定义单位如「1 袋 = 250 g」），
要求：
- 原料：基准写进 NutritionData.reference_amount/reference_unit（提议执行器负责）；
- 商品：基准写进 Product.custom_nutrition_data 的 reference_amount/reference_unit，
  GET 营养时按「商品自定义 > 关联原料 > 100 g」回传；
- 计算：基准先折算成克当量再算缩放，存量 100 g 数据结果逐位不变。
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


def _ingredient(db_session, name="营养基准食材"):
    from app.models.nutrition import Ingredient
    ing = Ingredient(name=name, is_active=True)
    db_session.add(ing)
    db_session.commit()
    db_session.refresh(ing)
    return ing.id


def _nutrition_row(db_session, ingredient_id):
    from app.models.nutrition_data import NutritionData
    db_session.expire_all()
    return db_session.query(NutritionData).filter(
        NutritionData.ingredient_id == ingredient_id
    ).first()


# ---------------------------------------------------------------- 原料

def test_ingredient_edit_persists_basis(db_session, as_admin):
    ing_id = _ingredient(db_session)
    resp = client.post(
        f"/api/v1/nutrition/ingredients/{ing_id}/nutrition",
        json={
            "base_quantity": 250,
            "base_unit": "mL",
            "nutrients": [{"name": "能量", "value": 300, "unit": "kJ"}],
            "source": "custom",
        },
    )
    assert resp.status_code == 200, resp.text

    row = _nutrition_row(db_session, ing_id)
    assert row is not None
    assert float(row.reference_amount) == 250.0
    assert row.reference_unit == "mL"

    detail = client.get(f"/api/v1/nutrition/ingredients/{ing_id}/nutrition")
    assert detail.status_code == 200, detail.text
    assert float(detail.json()["reference_amount"]) == 250.0
    assert detail.json()["reference_unit"] == "mL"


def test_ingredient_edit_without_basis_keeps_100g(db_session, as_admin):
    """不传 base_* 时维持 100 g —— 旧客户端/旧数据行为不变。"""
    ing_id = _ingredient(db_session, "营养基准食材_默认")
    resp = client.post(
        f"/api/v1/nutrition/ingredients/{ing_id}/nutrition",
        json={
            "nutrients": [{"name": "蛋白质", "value": 3, "unit": "g"}],
            "source": "custom",
        },
    )
    assert resp.status_code == 200, resp.text
    row = _nutrition_row(db_session, ing_id)
    assert float(row.reference_amount) == 100.0
    assert row.reference_unit == "g"


def test_ingredient_edit_rejects_bad_basis(db_session, as_admin):
    ing_id = _ingredient(db_session, "营养基准食材_校验")
    bad_amount = client.post(
        f"/api/v1/nutrition/ingredients/{ing_id}/nutrition",
        json={
            "base_quantity": 0,
            "base_unit": "g",
            "nutrients": [{"name": "钠", "value": 100, "unit": "mg"}],
        },
    )
    assert bad_amount.status_code == 422

    blank_unit = client.post(
        f"/api/v1/nutrition/ingredients/{ing_id}/nutrition",
        json={
            "base_quantity": 100,
            "base_unit": "   ",
            "nutrients": [{"name": "钠", "value": 100, "unit": "mg"}],
        },
    )
    assert blank_unit.status_code == 422


def test_ingredient_executor_revert_restores_basis(db_session):
    """覆盖营养后回滚：基准也要一起还原，否则旧值配新基准。"""
    from app.models.nutrition_data import NutritionData
    from app.services.proposals.executors.nutrition import NutritionExecutor

    ing_id = _ingredient(db_session, "营养基准食材_回滚")
    db_session.add(NutritionData(
        ingredient_id=ing_id,
        nutrients={"core_nutrients": {"能量": {"value": 100, "unit": "kcal"}}},
        source="custom",
        reference_amount=250.0,
        reference_unit="mL",
        is_verified=True,
    ))
    db_session.commit()

    class _Proposal:
        entity_id = ing_id
        payload = {
            "nutrients": {"core_nutrients": {"能量": {"value": 200, "unit": "kcal"}}},
            "base_quantity": 500,
            "base_unit": "mL",
        }

    executor = NutritionExecutor()
    proposal = _Proposal()
    result = executor.apply(db_session, proposal)
    proposal.snapshot = result.snapshot
    proposal.revert_payload = result.revert_payload
    db_session.commit()

    row = _nutrition_row(db_session, ing_id)
    assert float(row.reference_amount) == 500.0
    assert row.reference_unit == "mL"
    assert result.snapshot["reference_amount"] == 250.0

    executor.revert(db_session, proposal)
    db_session.commit()
    row = _nutrition_row(db_session, ing_id)
    assert float(row.reference_amount) == 250.0
    assert row.reference_unit == "mL"
    assert row.nutrients["core_nutrients"]["能量"]["value"] == 100


# ---------------------------------------------------------------- 商品

def _product(db_session, ingredient_id, name="营养基准商品"):
    from app.models.product_entity import Product
    p = Product(name=name, ingredient_id=ingredient_id, is_active=True)
    db_session.add(p)
    db_session.commit()
    db_session.refresh(p)
    return p.id


def test_product_edit_stores_basis_in_custom_data(db_session, as_admin):
    ing_id = _ingredient(db_session, "营养基准商品_原料")
    product_id = _product(db_session, ing_id)

    resp = client.post(
        f"/api/v1/nutrition/products/{product_id}/nutrition",
        json={
            "base_quantity": 1,
            "base_unit": "袋",
            "nutrients": [{"name": "能量", "value": 1300, "unit": "kJ"}],
            "source": "custom",
        },
    )
    assert resp.status_code == 200, resp.text

    detail = client.get(f"/api/v1/nutrition/products/{product_id}/nutrition")
    assert detail.status_code == 200, detail.text
    body = detail.json()
    assert float(body["reference_amount"]) == 1.0
    assert body["reference_unit"] == "袋"
    assert body["custom_nutrition_data"]["reference_amount"] == 1

    # 合并逻辑不能把基准当成营养素：all_nutrients 里只有用户填的那一项
    assert "reference_amount" not in body["nutrition"]["all_nutrients"]
    assert "reference_unit" not in body["nutrition"]["all_nutrients"]


def test_product_get_inherits_ingredient_basis(db_session, as_admin):
    """商品没有自定义基准时，回显关联原料的基准（而不是硬编码 100 g）。"""
    from app.models.nutrition_data import NutritionData
    ing_id = _ingredient(db_session, "营养基准商品_继承")
    product_id = _product(db_session, ing_id, "营养基准商品_继承商品")
    db_session.add(NutritionData(
        ingredient_id=ing_id,
        nutrients={"core_nutrients": {"钠": {"value": 40, "unit": "mg"}}},
        source="custom",
        reference_amount=330.0,
        reference_unit="mL",
        is_verified=True,
    ))
    db_session.commit()

    body = client.get(
        f"/api/v1/nutrition/products/{product_id}/nutrition"
    ).json()
    assert float(body["reference_amount"]) == 330.0
    assert body["reference_unit"] == "mL"


# ---------------------------------------------------------------- 缩放口径

def _nutrition_data(db_session, ingredient_id, reference_amount, reference_unit,
                    value=100.0):
    from app.models.nutrition_data import NutritionData
    db_session.add(NutritionData(
        ingredient_id=ingredient_id,
        nutrients={
            "core_nutrients": {"能量": {"value": value, "unit": "kcal", "key": "energy"}},
            "all_nutrients": {"energy": {"value": value, "unit": "kcal"}},
        },
        source="custom",
        reference_amount=reference_amount,
        reference_unit=reference_unit,
        is_verified=True,
    ))
    db_session.commit()


def _scaled_energy(db_session, ingredient_id, quantity, unit):
    from app.services.nutrition_calculator import NutritionCalculator
    result = NutritionCalculator(db_session).calculate_ingredient_nutrition(
        ingredient_id, quantity, unit
    )
    # 缩放结果按显示名（中文）落键
    return result["nutrition"]["all_nutrients"]["能量"]["value"]


def test_scale_legacy_100g_unchanged(db_session):
    """存量（每 100 g）结果不变：100 g 请求 → 1×，250 g 请求 → 2.5×。"""
    ing_id = _ingredient(db_session, "营养基准食材_存量")
    _nutrition_data(db_session, ing_id, 100.0, "g", value=200.0)
    assert _scaled_energy(db_session, ing_id, 100, "g") == 200.0
    assert _scaled_energy(db_session, ing_id, 250, "g") == 500.0


def test_scale_by_volume_basis(db_session):
    """每 250 mL 标注：请求 100 mL（默认按水 1:1 折克）→ 0.4×。"""
    ing_id = _ingredient(db_session, "营养基准食材_体积")
    _nutrition_data(db_session, ing_id, 250.0, "mL", value=100.0)
    assert _scaled_energy(db_session, ing_id, 100, "mL") == 40.0


def _ensure_gram_unit(db_session):
    """内存测试库不会跑启动初始化，'g' 需按需补上（实体覆盖默认按克折算要用到它）。"""
    from app.models.unit import Unit
    if db_session.query(Unit).filter(Unit.abbreviation == "g").first() is None:
        db_session.add(Unit(name="克", abbreviation="g", unit_type="mass", si_factor=0.001))
        db_session.commit()


def test_scale_by_custom_unit_basis(db_session):
    """每 1 袋（= 250 g）标注：请求 250 g → 1×（旧口径会算成 250×）。"""
    from app.models.entity_unit_override import EntityUnitOverride
    _ensure_gram_unit(db_session)
    ing_id = _ingredient(db_session, "营养基准食材_自定义单位")
    _nutrition_data(db_session, ing_id, 1.0, "袋", value=600.0)
    db_session.add(EntityUnitOverride(
        entity_type="ingredient",
        entity_id=ing_id,
        unit_name="袋",
        weight_per_unit=250,
        is_active=True,
    ))
    db_session.commit()

    assert _scaled_energy(db_session, ing_id, 250, "g") == 600.0
    assert _scaled_energy(db_session, ing_id, 125, "g") == 300.0


def test_scale_falls_back_when_unit_unresolvable(db_session):
    """基准单位解析不出来时按「amount 即克数」的旧口径，不产生离谱缩放。"""
    ing_id = _ingredient(db_session, "营养基准食材_悬空单位")
    _nutrition_data(db_session, ing_id, 100.0, "已删除的单位", value=50.0)
    assert _scaled_energy(db_session, ing_id, 100, "g") == 50.0
