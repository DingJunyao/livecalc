"""汇率与币种 API 测试。"""
from fastapi.testclient import TestClient
from app.main import app
from app.models.currency import Currency

client = TestClient(app)


def _delete_currencies(db_session, *codes):
    """清理测试创建的币种，避免污染共享内存库。"""
    db_session.query(Currency).filter(Currency.code.in_(codes)).delete()
    db_session.commit()


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


# ---------- 币种管理 CRUD ----------

def test_admin_currencies_requires_admin(as_non_admin):
    """非管理员访问币种管理端点应 403。"""
    r = client.get("/api/v1/admin/currencies")
    assert r.status_code == 403
    r = client.post("/api/v1/admin/currencies", json={"code": "XYZ", "name": "测试币"})
    assert r.status_code == 403
    r = client.put("/api/v1/admin/currencies/XYZ", json={"name": "测试币"})
    assert r.status_code == 403
    r = client.delete("/api/v1/admin/currencies/XYZ")
    assert r.status_code == 403


def test_create_and_upsert_currency(as_admin, db_session):
    """POST /admin/currencies 创建，重复 code 时 upsert 更新。"""
    try:
        r = client.post(
            "/api/v1/admin/currencies",
            json={"code": "XYZ", "name": "测试币", "symbol": "X", "decimals": 2},
        )
        assert r.status_code == 200
        body = r.json()
        assert body["code"] == "XYZ"
        assert body["name"] == "测试币"
        assert body["symbol"] == "X"
        assert body["decimals"] == 2
        assert body["is_active"] is True

        # upsert：存在则更新
        r = client.post(
            "/api/v1/admin/currencies",
            json={"code": "XYZ", "name": "测试币2", "symbol": None, "decimals": 0, "is_active": False},
        )
        assert r.status_code == 200
        body = r.json()
        assert body["name"] == "测试币2"
        assert body["symbol"] is None
        assert body["decimals"] == 0
        assert body["is_active"] is False
    finally:
        _delete_currencies(db_session, "XYZ")


def test_create_currency_code_validation(as_admin):
    """code 必须为 3 位大写字母。"""
    for bad in ["cn1", "CN", "CNY1", "cny"]:
        r = client.post("/api/v1/admin/currencies", json={"code": bad, "name": "x"})
        assert r.status_code == 422, bad


def test_update_currency_partial(as_admin, db_session):
    """PUT 部分更新：只改传字段，其余保持不变。"""
    try:
        client.post("/api/v1/admin/currencies", json={"code": "XYZ", "name": "测试币", "decimals": 2})
        r = client.put("/api/v1/admin/currencies/XYZ", json={"is_active": False, "decimals": 0})
        assert r.status_code == 200
        body = r.json()
        assert body["is_active"] is False
        assert body["decimals"] == 0
        assert body["name"] == "测试币"
    finally:
        _delete_currencies(db_session, "XYZ")


def test_update_currency_not_found(as_admin):
    r = client.put("/api/v1/admin/currencies/ZZZ", json={"name": "x"})
    assert r.status_code == 404


def test_delete_currency_soft_delete(as_admin, db_session):
    """DELETE 软删：公共列表不再返回，管理列表仍可见且 is_active=False。"""
    try:
        client.post("/api/v1/admin/currencies", json={"code": "XYZ", "name": "测试币"})
        r = client.delete("/api/v1/admin/currencies/XYZ")
        assert r.status_code == 200
        assert r.json()["is_active"] is False

        r = client.get("/api/v1/currencies")
        assert all(c["code"] != "XYZ" for c in r.json())

        r = client.get("/api/v1/admin/currencies")
        row = next(c for c in r.json() if c["code"] == "XYZ")
        assert row["is_active"] is False
    finally:
        _delete_currencies(db_session, "XYZ")


def test_delete_currency_not_found(as_admin):
    r = client.delete("/api/v1/admin/currencies/ZZZ")
    assert r.status_code == 404
