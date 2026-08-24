"""汇率 API 测试。"""
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_currencies_list_endpoint_requires_auth():
    r = client.get("/api/v1/currencies")
    assert r.status_code in (401, 403)


def test_manual_exchange_rate_success(as_admin):
    """manual exchange rate: admin + in-memory DB -> 200 (no Decimal 500)."""
    r = client.post(
        "/api/v1/admin/exchange-rates/manual",
        json={
            "rate_date": "2026-08-24",
            "base_currency": "EUR",
            "rates": {"USD": 1.1, "CNY": 7.8},
        },
    )
    assert r.status_code == 200
    body = r.json()
    assert body["base"] == "EUR"
    assert body["count"] == 2
