"""价格计算用的地区过滤与币种折算 helper。"""
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Optional

from sqlalchemy import or_
from sqlalchemy.orm import Session, Query, aliased

from app.models.administrative_region import AdministrativeRegion
from app.models.merchant import Merchant
from app.models.product import ProductRecord

# 与 app.services.lookup_cache.clear 共用的子树缓存 key（写 AdministrativeRegion 时一并失效）
_REGION_SUBTREE_CACHE_KEY = "_livecalc_region_subtree_cache"

# 各商家最新价的「陈旧」阈值：超过 30 天的记录不参与最低价比较，展示时排到最后并置灰
MERCHANT_PRICE_STALE_DAYS = 30


def is_stale_recorded_at(recorded_at: Optional[datetime]) -> bool:
    """商家最新价是否陈旧（距现在超过 MERCHANT_PRICE_STALE_DAYS 天）。

    naive datetime 视为 UTC（与 app.utils.datetime_utils.serialize_datetime 口径一致）；
    recorded_at 缺失时视为不陈旧（不改变既有展示行为）。
    """
    if recorded_at is None:
        return False
    aware = recorded_at if recorded_at.tzinfo else recorded_at.replace(tzinfo=timezone.utc)
    return datetime.now(timezone.utc) - aware > timedelta(days=MERCHANT_PRICE_STALE_DAYS)


def region_subtree_ids(db: Session, region_id: int) -> list[int]:
    """地区子树 id 列表（含自身）。请求级缓存：成本/趋势计算会对同一 region_id
    调用上万次 apply_region_filter，子树为准静态数据，挂在 db.info 上随请求失效。"""
    cache = db.info.get(_REGION_SUBTREE_CACHE_KEY)
    if cache is None:
        cache = {}
        db.info[_REGION_SUBTREE_CACHE_KEY] = cache
    if region_id in cache:
        return cache[region_id]

    region = db.query(AdministrativeRegion).filter(
        AdministrativeRegion.id == region_id,
        AdministrativeRegion.is_active == True,  # noqa: E712
    ).first()
    if region is None:
        ids: list[int] = []
    elif region.path:
        rows = db.query(AdministrativeRegion.id).filter(
            AdministrativeRegion.path.like(f"{region.path}%"),
            AdministrativeRegion.is_active == True,  # noqa: E712
        ).all()
        ids = [region.id] + [r[0] for r in rows if r[0] != region.id]
    else:
        ids = [region.id]

    cache[region_id] = ids
    return ids


def apply_region_filter(query: Query, db: Session, region_id: Optional[int]) -> Query:
    if region_id is None:
        return query
    ids = region_subtree_ids(db, region_id)
    if not ids:
        return query.filter(False)
    # Use an alias so the filter stays unambiguous even when the caller
    # already joined Merchant on ProductRecord.merchant_id (e.g. merchant-costs
    # or latest-price-by-merchant queries).
    merchant_alias = aliased(Merchant)
    # 未分配地区的商家视为「任何地区均计入」（用户明确要求：没有选择地区的商家在任何地区和范围下都计入）。
    return query.join(
        merchant_alias, ProductRecord.merchant_id == merchant_alias.id
    ).filter(or_(
        merchant_alias.region_id.in_(ids),
        merchant_alias.region_id.is_(None),
    ))


def record_price_in_user_currency(record) -> Decimal:
    p = Decimal(str(record.price))
    er = getattr(record, "exchange_rate", None)
    factor = Decimal(str(er)) if er is not None else Decimal("1")
    sr = _session_rate_factor()
    if sr is not None and sr != 1.0:
        factor = factor * sr
    return p * factor


def display_exchange_rate(record) -> Decimal:
    """序列化给前端的 exchange_rate：会话币种覆盖时折算到会话币种（原币种 -> 会话币种）。"""
    er = getattr(record, "exchange_rate", None)
    factor = Decimal(str(er)) if er is not None else Decimal("1")
    sr = _session_rate_factor()
    if sr is not None and sr != 1.0:
        factor = factor * sr
    return factor


def _session_rate_factor() -> Optional[Decimal]:
    """会话覆盖时返回 用户币种 -> 会话币种 的当日汇率，否则 None。"""
    from app.services.session_context import get_session_rate
    sr = get_session_rate()
    if sr is None or sr == 1.0:
        return None
    return Decimal(str(sr))
