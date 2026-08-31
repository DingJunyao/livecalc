import uuid

from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def _unique_username(prefix: str = "i18n_user") -> str:
    return f"{prefix}_{uuid.uuid4().hex[:12]}"


def test_auth_error_translates_by_accept_language():
    response = client.post(
        "/api/v1/auth/register",
        headers={"Accept-Language": "en-US"},
        json={},
    )
    assert response.status_code == 422
    assert response.json()["detail"] == "Request validation failed"
    assert response.json()["errors"][0]["message"] == "This field is required"


def test_dynamic_backend_error_translates():
    response = client.get(
        "/api/v1/regions/999999",
        headers={"Accept-Language": "ar"},
    )
    assert response.status_code == 404
    assert response.json()["detail"] == "المنطقة الإدارية غير موجودة"


def test_duplicate_username_translates_in_english_and_arabic():
    username = _unique_username()
    payload = {
        "username": username,
        "password_hash": "test_password_hash",
    }

    first = client.post(
        "/api/v1/auth/register",
        headers={"Accept-Language": "en-US"},
        json={**payload, "email": f"{username}_first@example.com"},
    )
    assert first.status_code == 200

    english = client.post(
        "/api/v1/auth/register",
        headers={"Accept-Language": "en-US"},
        json={**payload, "email": f"{username}_en@example.com"},
    )
    assert english.status_code == 400
    assert english.json()["detail"] == "Username already exists"

    arabic = client.post(
        "/api/v1/auth/register",
        headers={"Accept-Language": "ar"},
        json={**payload, "email": f"{username}_ar@example.com"},
    )
    assert arabic.status_code == 400
    assert arabic.json()["detail"] == "اسم المستخدم موجود بالفعل"
