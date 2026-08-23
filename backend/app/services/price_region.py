"""价格计算用的地区过滤与币种折算 helper。"""
from decimal import Decimal
from typing import Optional

from sqlalchemy.orm import Session, Query

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
    return query.join(Merchant, ProductRecord.merchant_id == Merchant.id).filter(
        Merchant.region_id.in_(ids)
    )


def record_price_in_user_currency(record) -> Decimal:
    p = Decimal(str(record.price))
    er = getattr(record, "exchange_rate", None)
    factor = Decimal(str(er)) if er is not None else Decimal("1")
    return p * factor
