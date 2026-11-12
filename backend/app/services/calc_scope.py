"""默认计算范围推导。

优先级：users.default_calc_scope_id（自定义多地区组合，user_calc_scopes 表，
返回 region_ids 的 tuple）> 既有 user.region_id + default_calc_scope 层级档位
（返回单个祖先节点 id）。自定义范围不要求 users.region_id 已设置；范围被删
或 region_ids 为空时回退既有路径。None = 不过滤（全部地区）。
"""
from typing import Optional, Tuple, Union

from sqlalchemy.orm import Session

ScopeResult = Optional[Union[int, Tuple[int, ...]]]

_SCOPE_LEVEL = {"country": 0, "province": 1, "city": 2, "county": 3}


def resolve_default_calc_region_id(db: Session, user) -> ScopeResult:
    from app.models.administrative_region import AdministrativeRegion

    # 自定义多地区组合优先（组合里显式列出地区，不依赖 users.region_id）
    scope_id = getattr(user, "default_calc_scope_id", None)
    if scope_id is not None:
        from app.models.user_calc_scope import UserCalcScope
        scope_row = db.query(UserCalcScope).filter(UserCalcScope.id == scope_id).first()
        if scope_row is not None and scope_row.region_ids:
            # 去重保序 + tuple（可哈希，recipe_service 用 region_id 作缓存键）
            ids = tuple(dict.fromkeys(int(r) for r in scope_row.region_ids))
            if ids:
                return ids
        # 范围被删 / region_ids 为空 → 回退既有层级档位推导

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


def resolve_region_param(db: Session, user, region_id) -> ScopeResult:
    """region_id 显式给出则用它；否则按用户默认计算范围推导。

    返回 None（全部地区）/ 单个地区 id / 多地区 id 元组，下游统一透传给
    apply_region_filter / region_subtree_ids（两者均支持多值并集）。
    """
    if region_id is not None:
        return region_id
    from app.services.session_context import get_session_region, has_session_region_override
    # 会话“全部地区”也必须短路默认范围；它的值正是 None。
    if has_session_region_override():
        return get_session_region()
    return resolve_default_calc_region_id(db, user)
