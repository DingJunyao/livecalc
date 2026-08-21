from datetime import datetime, timedelta, timezone
import json
from unittest.mock import Mock

import pytest

from app.models.barcode_lookup_cache import BarcodeLookupCache
from app.models.nutrition import Ingredient
from app.models.product_barcode import ProductBarcode
from app.models.product_entity import Product
from app.models.system_config import SystemConfig
from app.services.barcode_lookup import (
    BarcodeConfig,
    ServiceConfig,
    load_config,
    resolve_barcode,
)


class _Response:
    def __init__(self, payload):
        self.payload = payload

    def raise_for_status(self):
        return None

    def json(self):
        return self.payload


@pytest.fixture(autouse=True)
def clean_barcode_resolver_rows(db_session):
    def clean():
        db_session.query(SystemConfig).filter(
            SystemConfig.key == "barcode_service_config"
        ).delete()
        db_session.query(BarcodeLookupCache).filter(
            BarcodeLookupCache.barcode.like("99000000000%")
        ).delete()
        alt_product_ids = [
            row[0] for row in db_session.query(ProductBarcode.product_id).filter(
                ProductBarcode.barcode.like("99000000000%")
            )
        ]
        products = db_session.query(Product).filter(
            (Product.barcode.like("99000000000%"))
            | (Product.ingredient_id.in_(
                db_session.query(Ingredient.id).filter(
                    Ingredient.name.like("barcode resolver %")
                )
            ))
        )
        products_with_alt = db_session.query(Product).filter(
            Product.id.in_(alt_product_ids)
        )
        products_with_alt.delete(synchronize_session=False)
        products.delete(synchronize_session=False)
        db_session.query(Ingredient).filter(
            Ingredient.name.like("barcode resolver %")
        ).delete(synchronize_session=False)
        db_session.commit()

    clean()
    yield
    clean()


def _product(db, barcode=None, name="Primary Milk"):
    ingredient = Ingredient(name=f"barcode resolver {name}", is_active=True)
    db.add(ingredient)
    db.flush()
    product = Product(
        name=name,
        brand="Brand",
        barcode=barcode,
        image_url="https://example.test/milk.jpg",
        ingredient_id=ingredient.id,
        is_active=True,
    )
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


def test_primary_product_barcode_wins(db_session):
    product = _product(db_session, barcode="9900000000001")
    client = Mock()

    result = resolve_barcode(
        db_session,
        "9900000000001",
        config=BarcodeConfig(),
        client=client,
    )

    assert result.found is True
    assert result.source == "local"
    assert result.product == {
        "id": product.id,
        "barcode": "9900000000001",
        "name": "Primary Milk",
        "brand": "Brand",
        "spec": None,
        "manufacturer": None,
        "image_url": "https://example.test/milk.jpg",
    }
    assert result.errors == []
    client.get.assert_not_called()


def test_load_config_reads_system_config(db_session):
    db_session.merge(SystemConfig(
        key="barcode_service_config",
        value=json.dumps({"cache_ttl_minutes": 20, "services": []}),
    ))
    db_session.commit()

    config = load_config(db_session)

    assert config.cache_ttl_minutes == 20
    assert config.services == []


def test_active_alternate_barcode_matches_product(db_session):
    product = _product(db_session, name="Alt Milk")
    db_session.add(ProductBarcode(
        product_id=product.id,
        barcode="9900000000002",
        is_active=True,
    ))
    db_session.commit()

    result = resolve_barcode(
        db_session,
        "9900000000002",
        config=BarcodeConfig(),
        client=Mock(),
    )

    assert result.found is True
    assert result.source == "local"
    assert result.product["id"] == product.id


def test_unexpired_cache_short_circuits_providers(db_session):
    payload = {
        "barcode": "9900000000003",
        "name": "Cached Milk",
        "brand": None,
        "spec": None,
        "manufacturer": None,
        "image_url": None,
    }
    db_session.add(BarcodeLookupCache(
        barcode=payload["barcode"],
        payload=json.dumps(payload),
        source="openfoodfacts",
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=5),
    ))
    db_session.commit()
    client = Mock()

    result = resolve_barcode(
        db_session,
        payload["barcode"],
        config=BarcodeConfig(),
        client=client,
    )

    assert result.found is True
    assert result.source == "openfoodfacts"
    assert result.product == payload
    client.get.assert_not_called()


def test_expired_cache_is_replaced_by_provider_hit(db_session):
    barcode = "9900000000004"
    db_session.add(BarcodeLookupCache(
        barcode=barcode,
        payload=json.dumps({"barcode": barcode, "name": "Old Milk"}),
        source="openfoodfacts",
        expires_at=datetime.now(timezone.utc) - timedelta(minutes=1),
    ))
    db_session.commit()
    client = Mock()
    client.get.return_value = _Response({
        "status": 1,
        "product": {"product_name": "Fresh Milk", "brands": "Brand"},
    })
    config = BarcodeConfig(cache_ttl_minutes=10, services=[
        ServiceConfig(id="openfoodfacts", type="openfoodfacts", enabled=True)
    ])

    result = resolve_barcode(db_session, barcode, config=config, client=client)

    assert result.found is True
    assert result.source == "openfoodfacts"
    assert result.product["name"] == "Fresh Milk"
    cached = db_session.get(BarcodeLookupCache, barcode)
    assert cached.source == "openfoodfacts"
    assert json.loads(cached.payload)["name"] == "Fresh Milk"
    cached_expiry = cached.expires_at
    if cached_expiry.tzinfo is None:
        cached_expiry = cached_expiry.replace(tzinfo=timezone.utc)
    assert cached_expiry > datetime.now(timezone.utc) + timedelta(minutes=9)
    client.get.assert_called_once()


def test_provider_miss_returns_errors_and_does_not_cache(db_session):
    barcode = "9900000000005"
    config = BarcodeConfig(services=[
        ServiceConfig(id="openfoodfacts", type="openfoodfacts", enabled=True),
        ServiceConfig(
            id="mxnzp",
            type="mxnzp",
            enabled=True,
            app_id="app-id",
            app_secret="secret",
        ),
    ])
    client = Mock()
    client.get.side_effect = [
        _Response({"status": 0}),
        _Response({"code": 404}),
    ]

    result = resolve_barcode(db_session, barcode, config=config, client=client)

    assert result.found is False
    assert result.source is None
    assert result.product == {}
    assert len(result.errors) == 2
    assert db_session.query(BarcodeLookupCache).filter(
        BarcodeLookupCache.barcode == barcode
    ).count() == 0
    assert client.get.call_count == 2
