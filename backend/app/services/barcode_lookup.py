"""Barcode provider configuration and lookup resolution."""

import json
import copy
import ipaddress
import re
import socket
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Literal
from urllib.parse import quote, urlparse

import httpx
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.models.barcode_lookup_cache import BarcodeLookupCache
from app.models.nutrition import Ingredient
from app.models.product_barcode import ProductBarcode
from app.models.product_entity import Product
from app.models.system_config import SystemConfig


class ServiceConfig(BaseModel):
    id: str = Field(min_length=1, max_length=50)
    type: Literal["openfoodfacts", "mxnzp", "yunji", "custom"]
    enabled: bool = False
    timeout_seconds: float = Field(5, ge=0.1, le=30)
    name: str | None = Field(None, max_length=100)
    doc_url: str | None = Field(None, max_length=500)
    app_id: str | None = Field(None, max_length=200)
    app_secret: str | None = Field(None, max_length=200)
    app_code: str | None = Field(None, max_length=200)
    url_template: str | None = Field(None, max_length=1000)
    headers: dict[str, str] = Field(default_factory=dict)
    mappings: dict[str, str] = Field(default_factory=dict)


class BarcodeConfig(BaseModel):
    cache_ttl_minutes: int = Field(10080, ge=1, le=527040)
    services: list[ServiceConfig] = Field(default_factory=list)


@dataclass
class LookupOutcome:
    found: bool
    source: str | None
    product: dict
    errors: list[str]


BUILTIN_CONFIGS = [
    {
        "id": "openfoodfacts",
        "type": "openfoodfacts",
        "enabled": False,
        "name": "Open Food Facts",
        "doc_url": "https://world.openfoodfacts.org/",
    },
    {
        "id": "mxnzp",
        "type": "mxnzp",
        "enabled": False,
        "name": "mxnzp",
        "doc_url": "https://www.mxnzp.com/doc/detail?id=6",
    },
    {
        "id": "yunji",
        "type": "yunji",
        "enabled": False,
        "name": "云际（云 API 市场）",
        "doc_url": "https://market.aliyun.com/detail/cmapi031448",
    },
]


def default_config() -> dict:
    return {"cache_ttl_minutes": 10080, "services": BUILTIN_CONFIGS}


def load_or_default_config(raw: dict | None) -> BarcodeConfig:
    if not raw:
        return BarcodeConfig(**default_config())
    return BarcodeConfig(**raw)


def load_config(db: Session) -> BarcodeConfig:
    row = db.query(SystemConfig).filter(
        SystemConfig.key == "barcode_service_config"
    ).first()
    raw = json.loads(row.value) if row else None
    return load_or_default_config(raw)


def _mask_service(service: ServiceConfig) -> dict:
    data = service.model_dump(mode="json")
    for field in ("app_id", "app_secret", "app_code"):
        value = getattr(service, field)
        data[field] = "***" if value else None
        data[f"has_{field}"] = bool(value)
    data["headers"] = {name: "***" for name in service.headers}
    return data


def mask_config(config: BarcodeConfig) -> dict:
    return {
        "cache_ttl_minutes": config.cache_ttl_minutes,
        "services": [_mask_service(service) for service in config.services],
    }


def merge_saved_secrets(saved: BarcodeConfig, incoming: dict) -> BarcodeConfig:
    data = copy.deepcopy(incoming)
    saved_services = {service.id: service for service in saved.services}
    for service in data.get("services", []):
        previous = saved_services.get(service.get("id"))
        if not previous:
            continue
        for field in ("app_id", "app_secret", "app_code"):
            if service.get(field) in (None, "***"):
                service[field] = getattr(previous, field)
        service["headers"] = {
            name: previous.headers.get(name, value) if value == "***" else value
            for name, value in (service.get("headers") or {}).items()
        }
    return BarcodeConfig(**data)


def validate_public_http_url(url_template: str) -> None:
    if url_template.count("{barcode}") != 1:
        raise ValueError("URL template must contain exactly one {barcode}")
    if url_template.count("{") != 1 or url_template.count("}") != 1:
        raise ValueError("URL template only supports the {barcode} placeholder")

    parsed = urlparse(url_template)
    if parsed.scheme not in ("http", "https") or not parsed.hostname:
        raise ValueError("Custom barcode URL must be an absolute HTTP(S) URL")
    if not parsed.hostname:
        raise ValueError("Custom barcode URL has no host")

    try:
        records = socket.getaddrinfo(parsed.hostname, parsed.port or 443)
    except OSError as exc:
        raise ValueError(f"Cannot resolve custom barcode URL host: {exc}") from exc

    for record in records:
        address = record[4][0]
        try:
            if not ipaddress.ip_address(address).is_global:
                raise ValueError(f"Custom barcode URL host is not public: {address}")
        except ValueError as exc:
            if "not public" in str(exc):
                raise
            raise ValueError(f"Invalid custom barcode URL host: {address}") from exc


def _validate_header(name: str, value: str) -> None:
    try:
        encoded_name = name.encode("ascii")
    except UnicodeEncodeError as exc:
        raise ValueError(f"Header name must be ASCII: {name}") from exc
    if not encoded_name or any(ch in encoded_name for ch in b" :"):
        raise ValueError(f"Invalid header name: {name}")
    if "\r" in value or "\n" in value:
        raise ValueError(f"Header value must not contain newlines: {name}")


def validate_config(config: BarcodeConfig) -> None:
    ids: set[str] = set()
    for service in config.services:
        if service.id in ids:
            raise ValueError(f"Duplicate barcode service id: {service.id}")
        ids.add(service.id)
        if not service.enabled:
            continue

        if service.type == "mxnzp" and not (service.app_id and service.app_secret):
            raise ValueError(f"mxnzp service {service.id} requires app_id and app_secret")
        if service.type == "yunji" and not service.app_code:
            raise ValueError(f"yunji service {service.id} requires app_code")
        if service.type == "custom":
            if not service.url_template:
                raise ValueError(f"custom service {service.id} requires url_template")
            if not service.mappings.get("name"):
                raise ValueError(f"custom service {service.id} requires name mapping")
            validate_public_http_url(service.url_template)
            for mapping in service.mappings.values():
                jsonpath({"x": 1}, mapping)

        for name, value in service.headers.items():
            _validate_header(name, value)


def build_url(url_template: str, barcode: str) -> str:
    return url_template.replace(
        "{barcode}", quote(barcode, safe="")
    )


_IDENTIFIER = re.compile(r"[^.\[\]\(\)\*,:]+")


def jsonpath(data: Any, path: str) -> Any:
    if not isinstance(path, str) or not path.startswith("$"):
        raise ValueError("JSONPath must start with $")

    current = data
    index = 1
    while index < len(path):
        if path[index] == ".":
            index += 1
            match = _IDENTIFIER.match(path, index)
            if not match:
                raise ValueError(f"Invalid JSONPath segment at {index}: {path}")
            key = match.group(0)
            if key in ("*", "..") or any(ch in key for ch in "()*,:[]"):
                raise ValueError(f"Unsupported JSONPath segment: {key}")
            if not isinstance(current, dict):
                return None
            current = current.get(key)
            index = match.end()
            continue

        if path[index] == "[":
            end = path.find("]", index + 1)
            if end < 0:
                raise ValueError(f"Unclosed JSONPath bracket: {path}")
            token = path[index + 1 : end]
            index = end + 1
            if token.startswith(("'", '"')):
                if len(token) < 2 or token[-1] != token[0]:
                    raise ValueError(f"Invalid quoted JSONPath token: {token}")
                key = token[1:-1]
                if not key:
                    raise ValueError("Empty JSONPath key")
                if not isinstance(current, dict):
                    return None
                current = current.get(key)
            elif token.isdigit():
                position = int(token)
                if not isinstance(current, list) or position >= len(current):
                    return None
                current = current[position]
            else:
                raise ValueError(f"Unsupported JSONPath token: {token}")
            continue

        raise ValueError(f"Unsupported JSONPath at {index}: {path}")

    return current


def _clean_product(barcode: str, values: dict[str, Any]) -> dict | None:
    product = {
        "barcode": barcode,
        "name": values.get("name"),
        "brand": values.get("brand"),
        "spec": values.get("spec"),
        "manufacturer": values.get("manufacturer"),
        "image_url": values.get("image_url"),
    }
    for key, value in list(product.items()):
        if isinstance(value, str):
            product[key] = value.strip() or None
    if not product["name"]:
        return None
    return product


def _parse_openfoodfacts(payload: dict, barcode: str) -> dict | None:
    if payload.get("status") != 1:
        return None
    product = payload.get("product") or {}
    return _clean_product(barcode, {
        "name": product.get("product_name"),
        "brand": product.get("brands"),
        "spec": product.get("quantity"),
        "manufacturer": None,
        "image_url": product.get("image_url"),
    })


def _parse_mxnzp(payload: dict, barcode: str) -> dict | None:
    if payload.get("code") != 1:
        return None
    data = payload.get("data") or {}
    return _clean_product(barcode, {
        "name": data.get("goodsName"),
        "brand": data.get("brand"),
        "spec": data.get("standard"),
        "manufacturer": data.get("supplier"),
        "image_url": data.get("image"),
    })


def _parse_yunji(payload: dict, barcode: str) -> dict | None:
    if str(payload.get("status")) != "200":
        return None
    data = payload
    images = data.get("Image") or []
    image_url = images[0].get("Imageurl") if images else None
    return _clean_product(barcode, {
        "name": data.get("ItemName"),
        "brand": data.get("BrandName"),
        "spec": data.get("ItemSpecification"),
        "manufacturer": data.get("FirmName"),
        "image_url": image_url,
    })


def _parse_custom(service: ServiceConfig, payload: dict, barcode: str) -> dict | None:
    values = {
        field: jsonpath(payload, service.mappings.get(field, "$.missing"))
        for field in ("name", "brand", "spec", "manufacturer", "image_url")
    }
    return _clean_product(barcode, values)


def lookup_with_provider(
    service: ServiceConfig, barcode: str, client: httpx.Client
) -> dict | None:
    if service.type == "openfoodfacts":
        response = client.get(
            f"https://world.openfoodfacts.org/api/v2/product/{quote(barcode, safe='')}.json"
        )
        response.raise_for_status()
        return _parse_openfoodfacts(response.json(), barcode)

    if service.type == "mxnzp":
        response = client.get(
            "https://www.mxnzp.com/api/barcode/goods/details",
            params={
                "barcode": barcode,
                "app_id": service.app_id,
                "app_secret": service.app_secret,
            },
        )
        response.raise_for_status()
        return _parse_mxnzp(response.json(), barcode)

    if service.type == "yunji":
        response = client.get(
            "https://barcode100.market.alicloudapi.com/getBarcode",
            params={"Code": barcode},
            headers={"Authorization": f"APPCODE {service.app_code}"},
        )
        response.raise_for_status()
        return _parse_yunji(response.json(), barcode)

    response = client.get(
        build_url(service.url_template, barcode), headers=service.headers
    )
    response.raise_for_status()
    return _parse_custom(service, response.json(), barcode)


def _local_product(db: Session, barcode: str) -> Product | None:
    primary = (
        db.query(Product)
        .join(Ingredient, Product.ingredient_id == Ingredient.id)
        .filter(
            Product.barcode == barcode,
            Product.is_active.is_(True),
            Ingredient.is_active.is_(True),
        )
        .first()
    )
    if primary:
        return primary

    return (
        db.query(Product)
        .join(ProductBarcode, ProductBarcode.product_id == Product.id)
        .join(Ingredient, Product.ingredient_id == Ingredient.id)
        .filter(
            ProductBarcode.barcode == barcode,
            ProductBarcode.is_active.is_(True),
            Product.is_active.is_(True),
            Ingredient.is_active.is_(True),
        )
        .first()
    )


def _local_payload(product: Product, barcode: str) -> dict:
    payload = _clean_product(barcode, {
        "name": product.name,
        "brand": product.brand,
        "spec": None,
        "manufacturer": None,
        "image_url": product.image_url,
    })
    return {"id": product.id, **payload}


def _as_utc(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


def _cached_payload(db: Session, barcode: str, now: datetime) -> dict | None:
    row = db.get(BarcodeLookupCache, barcode)
    if not row:
        return None
    if _as_utc(row.expires_at) <= now:
        return None
    return json.loads(row.payload)


def provider_source(service: ServiceConfig) -> str:
    if service.type == "custom":
        return f"custom:{service.id}"
    return service.type


def _provider_label(service: ServiceConfig) -> str:
    return service.name or service.id


def resolve_barcode(
    db: Session,
    barcode: str,
    config: BarcodeConfig | None = None,
    client: httpx.Client | None = None,
) -> LookupOutcome:
    barcode = barcode.strip()
    if not barcode or len(barcode) > 50:
        return LookupOutcome(False, None, {}, ["Invalid barcode"])

    config = config or load_config(db)
    product = _local_product(db, barcode)
    if product:
        return LookupOutcome(True, "local", _local_payload(product, barcode), [])

    now = datetime.now(timezone.utc)
    cached = _cached_payload(db, barcode, now)
    if cached is not None:
        row = db.get(BarcodeLookupCache, barcode)
        return LookupOutcome(True, row.source, cached, [])

    errors: list[str] = []
    services = [service for service in config.services if service.enabled]
    own_client = client is None and bool(services)
    if own_client:
        client = httpx.Client(timeout=max(service.timeout_seconds for service in services))

    try:
        for service in services:
            label = _provider_label(service)
            try:
                provider_product = lookup_with_provider(service, barcode, client)
            except (httpx.HTTPError, ValueError, TypeError):
                errors.append(f"{label}: lookup failed")
                continue
            if provider_product is None:
                errors.append(f"{label}: product not found")
                continue

            source = provider_source(service)
            fetched_at = datetime.now(timezone.utc)
            row = db.get(BarcodeLookupCache, barcode)
            if row:
                row.payload = json.dumps(provider_product, ensure_ascii=False)
                row.source = source
                row.fetched_at = fetched_at
                row.expires_at = fetched_at + timedelta(
                    minutes=config.cache_ttl_minutes
                )
            else:
                db.add(BarcodeLookupCache(
                    barcode=barcode,
                    payload=json.dumps(provider_product, ensure_ascii=False),
                    source=source,
                    fetched_at=fetched_at,
                    expires_at=fetched_at + timedelta(
                        minutes=config.cache_ttl_minutes
                    ),
                ))
            db.commit()
            return LookupOutcome(True, source, provider_product, [])
    finally:
        if own_client:
            client.close()

    return LookupOutcome(False, None, {}, errors)
