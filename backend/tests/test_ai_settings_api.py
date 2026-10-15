"""用户级 AI 设置端点测试。"""
from conftest import FakeUser, NonAdminFakeUser, TestingSessionLocal, engine
from app.core.database import Base


def test_get_and_update_own_settings(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    client = TestClient(app)
    resp = client.get("/api/v1/profile/ai-settings")
    assert resp.status_code == 200, resp.text
    payload = resp.json()
    assert payload["method"] is None and payload["has_api_key"] is False
    assert "default_method" in payload["policy"]

    resp = client.put("/api/v1/profile/ai-settings", json={
        "method": "user_ai", "provider": "openai",
        "base_url": "https://example.com/v1", "model": "gpt-x",
        "api_key": "sk-abcdef123456",
    })
    assert resp.status_code == 200, resp.text
    payload = resp.json()
    assert payload["method"] == "user_ai" and payload["has_api_key"] is True
    assert "abcdef123456" not in (payload["api_key_masked"] or "")

    # 落库为密文
    from app.models.user_ai_settings import UserAiSettings
    db = TestingSessionLocal()
    try:
        row = db.query(UserAiSettings).filter(
            UserAiSettings.user_id == FakeUser.id).one()
        assert row.api_key_enc and row.api_key_enc != "sk-abcdef123456"
        assert row.daily_ai_limit_override is None
    finally:
        db.close()

    # 清除密钥
    resp = client.delete("/api/v1/profile/ai-settings/api-key")
    assert resp.status_code == 200, resp.text
    resp = client.get("/api/v1/profile/ai-settings")
    assert resp.json()["has_api_key"] is False


def test_non_admin_cannot_update_others(as_non_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    client = TestClient(app)
    resp = client.put("/api/v1/profile/ai-settings", params={"user_id": FakeUser.id},
                      json={"method": "rule"})
    assert resp.status_code == 403, resp.text


def test_admin_can_update_other_user(as_admin):
    from starlette.testclient import TestClient
    from app.main import app
    from app.models.user import User

    Base.metadata.create_all(bind=engine)
    # 目标用户需真实存在（fake 用户不落库）
    db = TestingSessionLocal()
    try:
        if db.query(User).filter(User.id == 2).first() is None:
            db.add(User(id=2, username="u2", email="u2@x.c",
                        password_hash="x", is_admin=False, is_active=True))
            db.commit()
    finally:
        db.close()

    client = TestClient(app)
    resp = client.put("/api/v1/profile/ai-settings", params={"user_id": 2},
                      json={"method": "rule", "daily_limit_override": 5})
    assert resp.status_code == 200, resp.text
    assert resp.json()["daily_limit_override"] == 5
