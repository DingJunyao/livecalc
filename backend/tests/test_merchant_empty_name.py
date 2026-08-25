"""商家创建 name 可选（只填国家/地区也能保存）回归测试。"""
from fastapi.testclient import TestClient
from app.main import app
from app.models.merchant import Merchant

client = TestClient(app)


def _cleanup(db_session, merchant_id):
    db_session.query(Merchant).filter(Merchant.id == merchant_id).delete()
    db_session.commit()


def test_create_merchant_empty_name_allowed(as_admin, db_session):
    """name 传空串也能创建（归一化为空串存储）。"""
    r = client.post(
        "/api/v1/merchants",
        json={"name": "", "region_id": 1, "is_open": True},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["name"] == ""
    assert body["region_id"] == 1
    assert body["effective_currency"] == "CNY"  # 无地区/币种时回落全局默认
    assert body["is_open"] is True
    _cleanup(db_session, body["id"])


def test_create_merchant_without_name_key(as_admin, db_session):
    """请求体完全没有 name 字段也能创建。"""
    r = client.post(
        "/api/v1/merchants",
        json={"region_id": 1},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["name"] == ""
    assert body["region_id"] == 1
    _cleanup(db_session, body["id"])


def test_create_merchant_with_name_still_works(as_admin, db_session):
    """有名称时保持原行为。"""
    r = client.post(
        "/api/v1/merchants",
        json={"name": "盒马鲜生", "is_open": True},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["name"] == "盒马鲜生"
    _cleanup(db_session, body["id"])
