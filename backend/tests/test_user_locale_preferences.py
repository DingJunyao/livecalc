from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def _register_and_login(username: str) -> str:
    client.post("/api/v1/auth/register", json={
        "username": username,
        "email": f"{username}@test.com",
        "password_hash": "pw_hash",
    })
    response = client.post("/api/v1/auth/login", json={
        "username": username,
        "password_hash": "pw_hash",
    })
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


def test_me_returns_null_locale_preferences_for_existing_user():
    token = _register_and_login("locale_null")
    response = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200, response.text
    assert response.json()["locale"] is None
    assert response.json()["format_locale"] is None


def test_patch_me_saves_and_clears_locale_preferences():
    token = _register_and_login("locale_set")
    response = client.patch(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"locale": "ar", "format_locale": "de-DE"},
    )
    assert response.status_code == 200, response.text
    assert response.json()["locale"] == "ar"
    assert response.json()["format_locale"] == "de-DE"

    response = client.patch(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"locale": None, "format_locale": None},
    )
    assert response.status_code == 200, response.text
    assert response.json()["locale"] is None
    assert response.json()["format_locale"] is None


def test_patch_me_rejects_invalid_locales():
    token = _register_and_login("locale_invalid")
    response = client.patch(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"locale": "fr-FR"},
    )
    assert response.status_code == 422, response.text

    response = client.patch(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"format_locale": "ar"},
    )
    assert response.status_code == 422, response.text
