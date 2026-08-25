"""地图逆地理编码：经纬度 → 行政区划。"""
from typing import Optional

import httpx
from sqlalchemy.orm import Session

from app.models.administrative_region import AdministrativeRegion
from app.models.map_config import MapConfiguration


def match_adcode_to_region_id(db: Session, adcode: str) -> Optional[int]:
    if not adcode:
        return None
    region = db.query(AdministrativeRegion).filter(
        AdministrativeRegion.code == adcode,
        AdministrativeRegion.is_active == True,  # noqa: E712
    ).first()
    return region.id if region else None


def _amap_regeo(config: dict, lng: float, lat: float) -> Optional[str]:
    key = config.get("amap") or config.get("amap_key")
    if not key:
        return None
    url = "https://restapi.amap.com/v3/geocode/regeo"
    r = httpx.get(url, params={"key": key, "location": f"{lng},{lat}", "extensions": "base"}, timeout=10.0)
    r.raise_for_status()
    data = r.json()
    if data.get("status") != "1":
        return None
    return data.get("regeocode", {}).get("addressComponent", {}).get("adcode")


def reverse_geocode(db: Session, lng: float, lat: float) -> Optional[int]:
    cfg = db.query(MapConfiguration).first()
    if cfg is None or not cfg.map_enabled:
        return None
    geocoding = cfg.geocoding or {}
    adcode = None
    if geocoding.get("provider") == "amap":
        adcode = _amap_regeo(geocoding, lng, lat)
    if adcode:
        return match_adcode_to_region_id(db, adcode)
    return None
