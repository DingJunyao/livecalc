from dataclasses import asdict
import json

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_admin_user
from app.models.barcode_lookup_cache import BarcodeLookupCache
from app.models.system_config import SystemConfig
from app.models.user import User
from app.services.barcode_lookup import (
    BarcodeConfig,
    LookupOutcome,
    ServiceConfig,
    load_config,
    lookup_with_provider,
    mask_config,
    merge_saved_secrets,
    provider_source,
    validate_config,
)


router = APIRouter(prefix="/admin/barcode-services", tags=["barcode_services"])


class BarcodeServiceTestRequest(BaseModel):
    barcode: str = Field(min_length=1, max_length=50)
    service: ServiceConfig


@router.get("")
def get_barcode_config(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user),
):
    return mask_config(load_config(db))


@router.put("")
def put_barcode_config(
    payload: BarcodeConfig,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user),
):
    config = merge_saved_secrets(load_config(db), payload.model_dump())
    try:
        validate_config(config)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    serialized = json.dumps(config.model_dump(mode="json"), ensure_ascii=False)
    row = db.get(SystemConfig, "barcode_service_config")
    if row:
        row.value = serialized
    else:
        db.add(SystemConfig(
            key="barcode_service_config",
            value=serialized,
        ))
    db.query(BarcodeLookupCache).delete(synchronize_session=False)
    db.commit()
    return {"ok": True}


@router.post("/test")
def test_barcode_service(
    payload: BarcodeServiceTestRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_admin_user),
):
    service = payload.service
    try:
        validate_config(BarcodeConfig(services=[service]))
        with httpx.Client(timeout=service.timeout_seconds) as client:
            product = lookup_with_provider(service, payload.barcode, client)
    except (httpx.HTTPError, ValueError, TypeError) as exc:
        return asdict(LookupOutcome(False, None, {}, [str(exc)]))

    source = provider_source(service)
    if product is None:
        return asdict(LookupOutcome(False, None, {}, ["Product not found"]))
    return asdict(LookupOutcome(True, source, product, []))
