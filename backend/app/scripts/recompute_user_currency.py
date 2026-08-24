"""用户换默认币种后，按记录日期用快照表重算所有 exchange_rate / user_currency。"""
from datetime import date
from decimal import Decimal

from sqlalchemy.orm import Session

from app.models.product import ProductRecord
from app.services.exchange_rate_service import get_rate_on_date


def compute_exchange_factor(db: Session, from_currency: str, to_currency: str, on_date: date) -> Decimal:
    if from_currency == to_currency:
        return Decimal("1")
    base = "EUR"
    f = get_rate_on_date(db, from_currency, on_date)
    t = get_rate_on_date(db, to_currency, on_date)
    if f is None or t is None:
        raise ValueError(f"缺少 {on_date} 的 {from_currency}/{to_currency} 汇率快照")
    return (Decimal("1") / f) * t


def recompute_all(db: Session, new_user_currency: str) -> int:
    count = 0
    records = db.query(ProductRecord).filter(ProductRecord.is_active == True).all()  # noqa: E712
    for r in records:
        if not r.currency or r.currency == new_user_currency:
            r.exchange_rate = Decimal("1")
            r.user_currency = new_user_currency
        else:
            d = r.recorded_at.date() if r.recorded_at else date.today()
            r.exchange_rate = compute_exchange_factor(db, r.currency, new_user_currency, d)
            r.user_currency = new_user_currency
        count += 1
    db.commit()
    return count
