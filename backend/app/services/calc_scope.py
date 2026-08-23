"""默认计算范围推导：由 user.region_id + default_calc_scope 取祖先节点。"""
from typing import Optional

from sqlalchemy.orm import Session

_SCOPE_LEVEL = {"country": 0, "province": 1, "city": 2, "county": 3}


def resolve_default_calc_region_id(db: Session, user) -> Optional[int]:
    from app.models.administrative_region import AdministrativeRegion

    if getattr(user, "region_id", None) is None:
        return None
    target = _SCOPE_LEVEL.get(getattr(user, "default_calc_scope", None), 0)
    node = db.query(AdministrativeRegion).filter(AdministrativeRegion.id == user.region_id).first()
    if node is None:
        return None
    while node.level > target and node.parent_id is not None:
        parent = db.query(AdministrativeRegion).filter(AdministrativeRegion.id == node.parent_id).first()
        if parent is None:
            break
        node = parent
    return node.id
