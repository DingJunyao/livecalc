"""公开配置 / 法律文档 / 合规信息管理端 测试（隔离内存库）。"""
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.core.security import get_current_admin_user, get_current_user
from app.main import app

client = TestClient(app)


@pytest.fixture()
def env():
    engine = create_engine(
        "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine, autoflush=False, autocommit=False)

    def override_db():
        db = Session()
        try:
            yield db
        finally:
            db.close()

    admin = SimpleNamespace(id=1, is_admin=True, username="admin")
    app.dependency_overrides[get_db] = override_db
    app.dependency_overrides[get_current_user] = lambda: admin
    app.dependency_overrides[get_current_admin_user] = lambda: admin
    try:
        yield Session
    finally:
        for dep in (get_db, get_current_user, get_current_admin_user):
            app.dependency_overrides.pop(dep, None)
        engine.dispose()


def test_app_config_public(env):
    """未登录也能读到启动配置，且不含密钥字段。"""
    resp = client.get("/api/v1/app/config")
    assert resp.status_code == 200
    body = resp.json()
    assert "registration_require_invite_code" in body
    assert body["ai"]["providers"] is not None
    assert body["map"]["providers"]
    assert body["legal"]["privacy_url"] == "/legal/privacy"
    assert "api_key" not in resp.text and "secret" not in resp.text


def test_legal_document_defaults(env):
    zh = client.get("/api/v1/legal/privacy", params={"locale": "zh"}).json()
    assert zh["doc"] == "privacy"
    assert "隐私政策" in zh["content"]

    en = client.get("/api/v1/legal/terms", params={"locale": "en"}).json()
    assert "Terms of Service" in en["content"]

    # 不支持的语言回退英文
    ar = client.get("/api/v1/legal/privacy", params={"locale": "ar"}).json()
    assert ar["locale"] == "en"

    missing = client.get("/api/v1/legal/unknown")
    assert missing.status_code == 404


def test_legal_html_page(env):
    resp = client.get("/legal/privacy")
    assert resp.status_code == 200
    assert "<h1>" in resp.text
    assert "隐私政策" in resp.text
    assert client.get("/legal/unknown").status_code == 404


def test_admin_update_compliance_and_reflect(env):
    put = client.put(
        "/api/v1/admin/compliance",
        json={
            "ai": {"providers": {"openai": {
                "display_name": "OpenAI 兼容 API",
                "model_name": "某备案模型",
                "filing_no": "网信算备123456",
                "note": "",
            }}},
            "map": {"providers": {"amap": {
                "display_name": "高德地图",
                "approval_no": "GS(2024)0001号",
                "note": "",
            }}},
            "legal": {"contact_email": "dingjunyao0703@163.com"},
        },
    )
    assert put.status_code == 200
    body = put.json()
    assert body["ai"]["providers"]["openai"]["filing_no"] == "网信算备123456"
    assert body["map"]["providers"]["amap"]["approval_no"] == "GS(2024)0001号"
    assert body["legal"]["contact_email"] == "dingjunyao0703@163.com"

    # 公开配置应带出填写后的信息
    cfg = client.get("/api/v1/app/config").json()
    assert cfg["map"]["providers"][0]["approval_no"] == "GS(2024)0001号"
    # 页脚联系邮箱生效
    page = client.get("/legal/privacy").text
    assert "dingjunyao0703@163.com" in page


def test_legal_content_edit_overrides_default(env):
    put = client.put(
        "/api/v1/admin/compliance",
        json={"legal": {"privacy": {"zh": "# 自定义隐私政策\n\n由管理员编辑。"}}},
    )
    assert put.status_code == 200
    doc = client.get("/api/v1/legal/privacy", params={"locale": "zh"}).json()
    assert "由管理员编辑" in doc["content"]
    # 英文未编辑，仍是默认文案
    en = client.get("/api/v1/legal/privacy", params={"locale": "en"}).json()
    assert "Privacy Policy" in en["content"]
