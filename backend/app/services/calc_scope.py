"""默认计算范围推导：由 user.region_id + default_calc_scope 取祖先节点。"""
from typing import Optional

from sqlalchemy.orm import Session

_SCOPE_LEVEL = {"country": 0, "province": 1, "city": 2, "county": 3}


def resolve_default_calc_region_id(db: Session, user) -> Optional[int]:
    from app.models.administrative_region import AdministrativeRegion

    if getattr(user, "region_id", None) is None:
        return None
    scope = getattr(user, "default_calc_scope", None)
    if scope == "":
        # 显式选择「全部地区」→ 不设地区过滤。
        return None
    # None（未设置）→ 按设计默认 country（全量，保持既有行为）
    target = _SCOPE_LEVEL.get(scope, 0)
    node = db.query(AdministrativeRegion).filter(AdministrativeRegion.id == user.region_id).first()
    if node is None:
        return None
    while node.level > target and node.parent_id is not None:
        parent = db.query(AdministrativeRegion).filter(AdministrativeRegion.id == node.parent_id).first()
        if parent is None:
            break
        node = parent
    return node.id


def resolve_region_param(db: Session, user, region_id: Optional[int]) -> Optional[int]:
    """region_id 显式给出则用它；否则按用户默认计算范围推导。"""
    if region_id is not None:
        return region_id
    from app.services.session_context import get_session_region, has_session_region_override
    # 会话“全部地区”也必须短路默认范围；它的值正是 None。
    if has_session_region_override():
        return get_session_region()
    return resolve_default_calc_region_id(db, user)
