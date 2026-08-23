"""汇率 API 测试。"""
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_currencies_list_endpoint_requires_auth():
    r = client.get("/api/v1/currencies")
    assert r.status_code in (401, 403)
