from unittest.mock import Mock

import pytest

from app.services.barcode_lookup import (
    BarcodeConfig,
    ServiceConfig,
    build_url,
    jsonpath,
    load_or_default_config,
    lookup_with_provider,
    mask_config,
    validate_config,
    validate_public_http_url,
)


class _Response:
    def __init__(self, payload):
        self.payload = payload

    def raise_for_status(self):
        return None

    def json(self):
        return self.payload


def test_open_foodfacts_maps_product():
    service = ServiceConfig(id="off", type="openfoodfacts", enabled=True)
    client = Mock()
    client.get.return_value = _Response({
        "status": 1,
        "product": {
            "product_name": "Milk",
            "brands": "Brand",
            "quantity": "500 ml",
            "image_url": "https://example.test/milk.jpg",
        },
    })

    result = lookup_with_provider(service, "123", client)

    assert result == {
        "barcode": "123",
        "name": "Milk",
        "brand": "Brand",
        "spec": "500 ml",
        "manufacturer": None,
        "image_url": "https://example.test/milk.jpg",
    }
    client.get.assert_called_once_with(
        "https://world.openfoodfacts.org/api/v2/product/123.json"
    )


def test_mxnzp_maps_data_and_sends_credentials():
    service = ServiceConfig(
        id="mxnzp",
        type="mxnzp",
        enabled=True,
        app_id="app-id",
        app_secret="secret",
    )
    client = Mock()
    client.get.return_value = _Response({
        "code": 200,
        "data": {
            "goodsName": "Milk",
            "brandName": "Brand",
            "spec": "500ml",
            "manu": "Factory",
        },
    })

    result = lookup_with_provider(service, "690", client)

    assert result["name"] == "Milk"
    assert result["manufacturer"] == "Factory"
    client.get.assert_called_once_with(
        "https://www.mxnzp.com/api/barcode/goods/details",
        params={"barcode": "690", "app_id": "app-id", "app_secret": "secret"},
    )


def test_yunji_maps_data_and_app_code_header():
    service = ServiceConfig(
        id="yunji", type="yunji", enabled=True, app_code="app-code"
    )
    client = Mock()
    client.get.return_value = _Response({
        "status": 200,
        "data": {
            "ItemName": "Milk",
            "BrandName": "Brand",
            "ItemSpecification": "500ml",
            "FirmName": "Factory",
            "Image": [{"Imageurl": "https://example.test/m.jpg"}],
        },
    })

    result = lookup_with_provider(service, "690", client)

    assert result == {
        "barcode": "690",
        "name": "Milk",
        "brand": "Brand",
        "spec": "500ml",
        "manufacturer": "Factory",
        "image_url": "https://example.test/m.jpg",
    }
    client.get.assert_called_once_with(
        "https://barcode100.market.alicloudapi.com/getBarcode",
        params={"Code": "690"},
        headers={"Authorization": "APPCODE app-code"},
    )


def test_custom_jsonpath_url_and_headers():
    service = ServiceConfig(
        id="mine",
        type="custom",
        enabled=True,
        url_template="https://api.test/g/{barcode}?lang=zh",
        headers={"Authorization": "Bearer token"},
        mappings={
            "name": "$.data.items[0].name",
            "brand": "$['data']['items'][0]['brand']",
            "spec": "$.data.spec",
            "manufacturer": "$.data.manufacturer",
            "image_url": "$.data.image",
        },
    )
    client = Mock()
    client.get.return_value = _Response({
        "data": {
            "spec": "500ml",
            "manufacturer": "Factory",
            "image": "https://example.test/m.jpg",
            "items": [{"name": "Milk", "brand": "Brand"}],
        }
    })

    result = lookup_with_provider(service, "69 0", client)

    assert result["name"] == "Milk"
    client.get.assert_called_once_with(
        "https://api.test/g/69%200?lang=zh",
        headers={"Authorization": "Bearer token"},
    )


def test_jsonpath_only_supports_safe_lookup():
    data = {"items": [{"name": "Milk"}]}
    assert jsonpath(data, "$.items[0].name") == "Milk"
    assert jsonpath(data, "$['items'][0]['name']") == "Milk"
    with pytest.raises(ValueError):
        jsonpath(data, "$.items[*].name")
    with pytest.raises(ValueError):
        jsonpath(data, "$..name")


def test_build_url_encodes_barcode_once():
    assert build_url("https://api.test/{barcode}", "69 0") == "https://api.test/69%200"


def test_reject_private_custom_url(monkeypatch):
    with pytest.raises(ValueError):
        validate_public_http_url("http://127.0.0.1/api?barcode={barcode}")
    with pytest.raises(ValueError):
        validate_public_http_url("http://10.0.0.1/api?barcode={barcode}")

    monkeypatch.setattr(
        "socket.getaddrinfo",
        lambda *args, **kwargs: [(2, 0, 0, "", ("192.168.1.1", 0))],
    )
    with pytest.raises(ValueError):
        validate_public_http_url("https://internal.example.test/{barcode}")


def test_config_defaults_masking_and_validation():
    raw = {
        "services": [
            {
                "id": "mxnzp",
                "type": "mxnzp",
                "enabled": True,
                "app_id": "app-id",
                "app_secret": "secret",
            }
        ]
    }
    config = load_or_default_config(raw)
    masked = mask_config(config)

    assert config.cache_ttl_minutes == 10080
    assert masked["services"][0]["app_secret"] == "***"
    assert masked["services"][0]["has_app_secret"] is True
    validate_config(config)


def test_config_rejects_duplicate_ids_and_invalid_custom_service(monkeypatch):
    duplicate = BarcodeConfig(services=[
        ServiceConfig(id="same", type="openfoodfacts", enabled=True),
        ServiceConfig(id="same", type="openfoodfacts", enabled=True),
    ])
    with pytest.raises(ValueError):
        validate_config(duplicate)

    monkeypatch.setattr(
        "socket.getaddrinfo",
        lambda *args, **kwargs: [(2, 0, 0, "", ("93.184.216.34", 0))],
    )
    invalid = BarcodeConfig(services=[
        ServiceConfig(
            id="custom",
            type="custom",
            enabled=True,
            url_template="https://api.test/{barcode}",
            mappings={"name": "$.name"},
            headers={"X-Key": "value"},
        )
    ])
    validate_config(invalid)
    invalid.services[0].headers = {"Bad Header": "value"}
    with pytest.raises(ValueError):
        validate_config(invalid)
