"""价格记录写入币种快照测试。"""
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.security import get_current_user

client = TestClient(app)


class FUser:
    id = 1
    is_admin = False


def _fake_user():
    return FUser()


@pytest.fixture(autouse=True)
def _override_user():
    previous = app.dependency_overrides.get(get_current_user)
    app.dependency_overrides[get_current_user] = _fake_user
    yield
    if previous is None:
        app.dependency_overrides.pop(get_current_user, None)
    else:
        app.dependency_overrides[get_current_user] = previous


def test_merchant_required():
    r = client.post("/api/v1/products/", json={"price": 10, "original_quantity": 1, "original_unit": "个"})
    assert r.status_code == 422