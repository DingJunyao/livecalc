# backend/tests/test_usda_admin_api.py
"""USDA 管理 API 测试。

数据库与鉴权 override 由 `tests/conftest.py` 统一提供（共享内存 SQLite +
FakeUser is_admin=True），通过 `clean_usda_tables` fixture 按测试安装/恢复，
避免与 `test_usda_api.py` 在模块级互相覆盖 dependency_overrides。
"""
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.models.usda import UsdaFood, UsdaFoodNutrient, TranslationConfig

from conftest import TestingSessionLocal

client = TestClient(app)


@pytest.fixture()
def db_with_data(clean_usda_tables):
    db = TestingSessionLocal()
    db.add_all([
        UsdaFood(fdc_id=1, data_type="foundation", description="A", translate_status="done"),
        UsdaFood(fdc_id=2, data_type="foundation", description="B", translate_status="pending"),
    ])
    db.add(UsdaFoodNutrient(fdc_id=1, name="Energy", name_zh="能量", amount=1, unit_name="kcal"))
    db.add(UsdaFoodNutrient(fdc_id=1, name="Weird Nutrient", name_zh=None, amount=1, unit_name="g"))
    db.commit()
    yield db
    db.query(UsdaFoodNutrient).delete()
    db.query(UsdaFood).delete()
    db.commit()
    db.close()


def test_statistics(db_with_data):
    r = client.get("/api/v1/admin/usda/statistics")
    assert r.status_code == 200
    d = r.json()
    assert d["total"] >= 2
    assert d["unmapped_nutrients"] >= 1


def test_unmapped_nutrients(db_with_data):
    r = client.get("/api/v1/admin/usda/unmapped-nutrients")
    assert r.status_code == 200
    d = r.json()
    assert "Weird Nutrient" in d["names"]


@pytest.fixture()
def clean_translation_config(clean_usda_tables):
    db = TestingSessionLocal()
    db.query(TranslationConfig).delete()
    db.commit()
    yield db
    db.query(TranslationConfig).delete()
    db.commit()
    db.close()


def test_translation_config_get_default(clean_translation_config):
    r = client.get("/api/v1/admin/translation-config")
    assert r.status_code == 200
    d = r.json()
    assert "ai" in d and "machine" in d
    assert "openai" in d["ai"]["providers"]
    assert "baidu" in d["machine"]["providers"]


def test_translation_config_put(clean_translation_config):
    new_cfg = {"ai": {"providers": {"openai": {"enabled": True, "base_url": "http://x/v1", "api_key": "k", "model": "m"}}}, "machine": {"providers": {}}}
    r = client.put("/api/v1/admin/translation-config", json={"config": new_cfg})
    assert r.status_code == 200
    # 再 GET 确认持久化
    r2 = client.get("/api/v1/admin/translation-config")
    assert r2.json()["ai"]["providers"]["openai"]["enabled"] is True


def test_translation_config_get_includes_meal_plan_and_policy(clean_translation_config):
    """GET 必须回 meal_plan / ai_policy 区块（前端模板直接访问，缺了整页白屏）。"""
    d = client.get("/api/v1/admin/translation-config").json()
    assert d["meal_plan"]["provider"] == "claude_code"
    assert d["ai_policy"]["allow_user_choice"] is True
    assert d["ai_policy"]["daily_ai_limit"] == 20


def test_translation_config_policy_round_trip(clean_translation_config):
    """策略与餐食推荐区块要能存进去、读回来，且服务层读到的是存库值。"""
    cfg = client.get("/api/v1/admin/translation-config").json()
    cfg["ai_policy"]["allow_user_choice"] = False
    cfg["ai_policy"]["daily_ai_limit"] = 5
    cfg["meal_plan"]["provider"] = "openai"
    assert client.put("/api/v1/admin/translation-config", json={"config": cfg}).status_code == 200

    d = client.get("/api/v1/admin/translation-config").json()
    assert d["ai_policy"]["allow_user_choice"] is False
    assert d["ai_policy"]["daily_ai_limit"] == 5
    assert d["meal_plan"]["provider"] == "openai"

    # 此前 to_dict() 只回 ai/machine，服务层永远只能读到默认值
    from app.services.ai_policy import get_meal_plan_cfg, get_policy

    db = TestingSessionLocal()
    try:
        assert get_policy(db)["daily_ai_limit"] == 5
        assert get_meal_plan_cfg(db)["provider"] == "openai"
    finally:
        db.close()


def test_translation_config_put_partial_keeps_other_blocks(clean_translation_config):
    """旧客户端（只提交 ai/machine）PUT 时不得抹掉其余区块，缺省字段要补齐。"""
    cfg = client.get("/api/v1/admin/translation-config").json()
    cfg["ai_policy"]["show_ai_badge"] = False
    client.put("/api/v1/admin/translation-config", json={"config": cfg})

    r = client.put(
        "/api/v1/admin/translation-config",
        json={"config": {"ai": {"providers": {"openai": {"enabled": True}}}}},
    )
    assert r.status_code == 200
    d = client.get("/api/v1/admin/translation-config").json()
    assert d["ai_policy"]["show_ai_badge"] is False
    assert d["meal_plan"]["provider"] == "claude_code"
    assert d["ai"]["providers"]["openai"]["enabled"] is True
    # 残缺结构里没写的默认字段由合并补齐
    assert d["ai"]["providers"]["openai"]["model"] == "gpt-4o-mini"
    assert "baidu" in d["machine"]["providers"]


def test_translate_unknown_provider_400(clean_translation_config):
    # 不存在的 provider 名 → 400
    r = client.post("/api/v1/admin/usda/translate", json={"provider": "nonexistent_provider"})
    assert r.status_code == 400


def test_translation_config_test_unknown_provider_400(clean_translation_config):
    r = client.post("/api/v1/admin/translation-config/test", json={"provider": "nonexistent_provider"})
    assert r.status_code == 400
