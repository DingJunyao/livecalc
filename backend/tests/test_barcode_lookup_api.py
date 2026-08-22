import json
from datetime import datetime, timezone
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.models.barcode_lookup_cache import BarcodeLookupCache
from app.models.nutrition import Ingredient
from app.models.product_entity import Product
from app.models.system_config import SystemConfig


client = TestClient(app)


@pytest.fixture(autouse=True)
def clean_barcode_api_rows(db_session):
    def clean():
        db_session.query(SystemConfig).filter(
            SystemConfig.key == "barcode_service_config"
        ).delete()
        db_session.query(BarcodeLookupCache).filter(
            BarcodeLookupCache.barcode.like("99010000000%")
        ).delete()
        ingredient_ids = db_session.query(Ingredient.id).filter(
            Ingredient.name.like("barcode api %")
        )
        db_session.query(Product).filter(
            Product.ingredient_id.in_(ingredient_ids)
        ).delete(synchronize_session=False)
        db_session.query(Ingredient).filter(
            Ingredient.name.like("barcode api %")
        ).delete(synchronize_session=False)
        db_session.commit()

    clean()
    yield
    clean()


def _local_product(db):
    ingredient = Ingredient(name="barcode api Milk", is_active=True)
    db.add(ingredient)
    db.flush()
    product = Product(
        name="Milk",
        brand="Brand",
        barcode="9901000000001",
        image_url="https://example.test/milk.jpg",
        ingredient_id=ingredient.id,
        is_active=True,
    )
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


def test_barcode_endpoint_requires_auth():
    response = client.get("/api/v1/products/entity/barcode/9901000000001")

    assert response.status_code in (401, 403)


def test_local_barcode_lookup(as_admin, db_session):
    product = _local_product(db_session)

    response = client.get("/api/v1/products/entity/barcode/9901000000001")

    assert response.status_code == 200
    assert response.json() == {
        "found": True,
        "source": "local",
        "product": {
            "id": product.id,
            "barcode": "9901000000001",
            "name": "Milk",
            "brand": "Brand",
            "spec": None,
            "manufacturer": None,
            "image_url": "https://example.test/milk.jpg",
        },
        "errors": [],
    }


def test_miss_returns_404_body(as_admin):
    response = client.get("/api/v1/products/entity/barcode/9901000000002")

    assert response.status_code == 404
    body = response.json()
    assert body["found"] is False
    assert body["source"] is None
    assert body["product"] == {}
    assert isinstance(body["errors"], list)


def test_admin_config_masks_and_retains_saved_secrets(as_admin, db_session):
    saved = {
        "cache_ttl_minutes": 30,
        "services": [{
            "id": "mxnzp",
            "type": "mxnzp",
            "enabled": True,
            "app_id": "saved-id",
            "app_secret": "saved-secret",
        }],
    }
    db_session.merge(SystemConfig(
        key="barcode_service_config",
        value=json.dumps(saved),
    ))
    db_session.add(BarcodeLookupCache(
        barcode="9901000000003",
        payload=json.dumps({"barcode": "9901000000003", "name": "Milk"}),
        source="mxnzp",
        expires_at=datetime(2999, 1, 1, tzinfo=timezone.utc),
    ))
    db_session.commit()
    incoming = {
        "cache_ttl_minutes": 40,
        "services": [{
            "id": "mxnzp",
            "type": "mxnzp",
            "enabled": True,
            "app_id": "new-id",
            "app_secret": "***",
        }],
    }

    put_response = client.put("/api/v1/admin/barcode-services", json=incoming)
    get_response = client.get("/api/v1/admin/barcode-services")

    assert put_response.status_code == 200
    assert get_response.status_code == 200
    row = db_session.get(SystemConfig, "barcode_service_config")
    persisted = json.loads(row.value)
    assert persisted["cache_ttl_minutes"] == 40
    assert persisted["services"][0]["app_secret"] == "saved-secret"
    assert db_session.query(BarcodeLookupCache).count() == 0
    masked = get_response.json()["services"][0]
    assert masked["app_secret"] == "***"
    assert masked["has_app_secret"] is True


def test_admin_config_rejects_private_custom_url(as_admin, db_session):
    response = client.put("/api/v1/admin/barcode-services", json={
        "services": [{
            "id": "private",
            "type": "custom",
            "enabled": True,
            "url_template": "http://127.0.0.1/{barcode}",
            "mappings": {"name": "$.name"},
        }],
    })

    assert response.status_code == 400
    assert db_session.query(SystemConfig).filter(
        SystemConfig.key == "barcode_service_config"
    ).count() == 0


def test_admin_config_masks_and_retains_custom_headers(as_admin, db_session):
    db_session.merge(SystemConfig(
        key="barcode_service_config",
        value=json.dumps({
            "services": [{
                "id": "custom",
                "type": "custom",
                "enabled": False,
                "url_template": "https://api.example.test/{barcode}",
                "headers": {"Authorization": "Bearer saved-token"},
                "mappings": {"name": "$.name"},
            }],
        }),
    ))
    db_session.commit()
    masked = client.get("/api/v1/admin/barcode-services").json()

    response = client.put("/api/v1/admin/barcode-services", json=masked)

    assert response.status_code == 200
    assert masked["services"][0]["headers"] == {"Authorization": "***"}
    persisted = json.loads(
        db_session.get(SystemConfig, "barcode_service_config").value
    )
    assert persisted["services"][0]["headers"] == {
        "Authorization": "Bearer saved-token"
    }


def test_admin_service_test_uses_saved_masked_credentials(
    as_admin, db_session, monkeypatch
):
    db_session.merge(SystemConfig(
        key="barcode_service_config",
        value=json.dumps({
            "services": [{
                "id": "mxnzp",
                "type": "mxnzp",
                "enabled": True,
                "app_id": "saved-id",
                "app_secret": "saved-secret",
            }],
        }),
    ))
    db_session.commit()

    with patch(
        "app.api.barcode_config.lookup_with_provider", return_value=None
    ) as provider:
        response = client.post("/api/v1/admin/barcode-services/test", json={
            "barcode": "9901000000005",
            "service": {
                "id": "mxnzp",
                "type": "mxnzp",
                "enabled": True,
                "app_id": "***",
                "app_secret": "***",
            },
        })

    assert response.status_code == 200
    service = provider.call_args[0][0]
    assert service.app_id == "saved-id"
    assert service.app_secret == "saved-secret"


def test_admin_service_test_calls_one_provider_without_persisting(
    as_admin, db_session, monkeypatch
):
    payload = {
        "barcode": "9901000000004",
        "service": {
            "id": "mxnzp",
            "type": "mxnzp",
            "enabled": True,
            "app_id": "app-id",
            "app_secret": "secret",
        },
    }
    provider_product = {
        "barcode": payload["barcode"],
        "name": "Milk",
        "brand": None,
        "spec": None,
        "manufacturer": None,
        "image_url": None,
    }

    with patch(
        "app.api.barcode_config.lookup_with_provider",
        return_value=provider_product,
    ) as provider:
        response = client.post("/api/v1/admin/barcode-services/test", json=payload)

    assert response.status_code == 200
    assert response.json() == {
        "found": True,
        "source": "mxnzp",
        "product": provider_product,
        "errors": [],
    }
    provider.assert_called_once()
    assert db_session.query(SystemConfig).filter(
        SystemConfig.key == "barcode_service_config"
    ).count() == 0
    assert db_session.query(BarcodeLookupCache).count() == 0
