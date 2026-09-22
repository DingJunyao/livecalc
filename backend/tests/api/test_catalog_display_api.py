import pytest
from fastapi.testclient import TestClient

from app.core.database import SessionLocal
from app.main import app
from app.models.administrative_region import AdministrativeRegion
from app.models.currency import Currency


client = TestClient(app)


def _seed_catalog_data(db):
    """Seed the in-memory test database with one country and one currency."""
    db.query(Currency).delete()
    db.query(AdministrativeRegion).delete()
    db.commit()

    db.add(
        Currency(
            code="USD",
            name="美元",
            symbol="$",
            decimals=2,
            is_active=True,
        )
    )
    country = AdministrativeRegion(
        code="CN",
        name="中国",
        name_en="China",
        level=0,
        iso_country="CN",
        path="CN",
        is_active=True,
    )
    db.add(country)
    db.commit()


def _register_and_login(username: str) -> str:
    client.post(
        "/api/v1/auth/register",
        json={
            "username": username,
            "email": f"{username}@test.com",
            "password_hash": "pw_hash",
        },
    )
    response = client.post(
        "/api/v1/auth/login",
        json={"username": username, "password_hash": "pw_hash"},
    )
    assert response.status_code == 200, response.text
    return response.json()["access_token"]


def _ensure_default_usd_currency():
    db = SessionLocal()
    try:
        row = db.query(Currency).filter(Currency.code == "USD").first()
        if row is None:
            db.add(
                Currency(
                    code="USD",
                    name="美元",
                    symbol="$",
                    decimals=2,
                    is_active=True,
                )
            )
        else:
            row.name = "美元"
            row.symbol = "$"
            row.decimals = 2
            row.is_active = True
        db.commit()
    finally:
        db.close()


@pytest.mark.parametrize("accept_language", ["en-US", "ar"])
def test_currencies_add_display_name_without_changing_name(accept_language, as_admin, db_session):
    _seed_catalog_data(db_session)
    response = client.get(
        "/api/v1/currencies",
        headers={"Accept-Language": accept_language},
    )
    assert response.status_code == 200, response.text
    rows = response.json()
    assert rows
    assert all(row["display_name"] for row in rows)
    assert all(row["name"] == "美元" for row in rows)


@pytest.mark.parametrize("accept_language", ["en-US", "ar"])
def test_regions_add_display_name_without_changing_name(accept_language, as_admin, db_session):
    _seed_catalog_data(db_session)
    response = client.get(
        "/api/v1/regions",
        headers={"Accept-Language": accept_language},
    )
    assert response.status_code == 200, response.text
    rows = response.json()
    assert rows
    assert all(row["display_name"] for row in rows)
    assert all(row["name"] == "中国" for row in rows)


def test_stored_locale_takes_precedence_over_accept_language():
    _ensure_default_usd_currency()
    token = _register_and_login("catalog_locale_precedence")

    response = client.patch(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {token}"},
        json={"locale": "ar"},
    )
    assert response.status_code == 200, response.text
    assert response.json()["locale"] == "ar"

    response = client.get(
        "/api/v1/currencies",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept-Language": "en-US",
        },
    )
    assert response.status_code == 200, response.text
    usd = next(row for row in response.json() if row["code"] == "USD")
    assert usd["name"] == "美元"
    assert usd["display_name"] == "دولار أمريكي"
