"""价格计算用的地区过滤与币种折算 helper。"""
from decimal import Decimal
from typing import Optional

from sqlalchemy import or_
from sqlalchemy.orm import Session, Query, aliased

from app.models.administrative_region import AdministrativeRegion
from app.models.merchant import Merchant
from app.models.product import ProductRecord


def region_subtree_ids(db: Session, region_id: int) -> list[int]:
    region = db.query(AdministrativeRegion).filter(
        AdministrativeRegion.id == region_id,
        AdministrativeRegion.is_active == True,  # noqa: E712
    ).first()
    if region is None:
        return []
    if region.path:
        rows = db.query(AdministrativeRegion.id).filter(
            AdministrativeRegion.path.like(f"{region.path}%"),
            AdministrativeRegion.is_active == True,  # noqa: E712
        ).all()
        return [region.id] + [r[0] for r in rows if r[0] != region.id]
    return [region.id]


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
    return p * factor
