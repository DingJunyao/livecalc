"""每日汇率快照与换算服务。"""
from datetime import date, datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy.orm import Session
from app.config import settings
from app.models.exchange_rate_snapshot import ExchangeRateSnapshot
from app.services.exchange_rate_providers import get_provider


def store_snapshot(db: Session, rate_date: date, base_currency: str, rates: dict, source: str = "") -> ExchangeRateSnapshot:
    snap = db.query(ExchangeRateSnapshot).filter(
        ExchangeRateSnapshot.rate_date == rate_date,
        ExchangeRateSnapshot.base_currency == base_currency,
    ).first()
    if snap is None:
        snap = ExchangeRateSnapshot(rate_date=rate_date, base_currency=base_currency, rates=dict(rates), source=source)
        db.add(snap)
    else:
        snap.rates = dict(rates)
        snap.source = source or snap.source
    return snap


def get_snapshot(db: Session, on_date: date, base_currency: str) -> Optional[ExchangeRateSnapshot]:
    return (
        db.query(ExchangeRateSnapshot)
        .filter(
            ExchangeRateSnapshot.rate_date <= on_date,
            ExchangeRateSnapshot.base_currency == base_currency,
        )
        .order_by(ExchangeRateSnapshot.rate_date.desc())
        .first()
    )


def get_rate_on_date(db: Session, currency: str, on_date: date) -> Optional[Decimal]:
    snap = get_snapshot(db, on_date, settings.exchange_rate_base_currency)
    if snap is None or currency not in snap.rates:
        return None
    return Decimal(str(snap.rates[currency]))


def convert(db: Session, amount: Decimal, from_currency: str, to_currency: str, on_date: date) -> Optional[Decimal]:
    if from_currency == to_currency:
        return amount
    base = settings.exchange_rate_base_currency
    f = get_rate_on_date(db, from_currency, on_date)
    t = get_rate_on_date(db, to_currency, on_date)
    if f is None or t is None or f == 0:
        return None
    return (amount / f) * t


def fetch_and_store_daily(db: Session, on_date: Optional[date] = None) -> dict:
    provider = get_provider(settings.exchange_rate_provider)
    data = provider.fetch(settings.exchange_rate_base_url, settings.exchange_rate_base_currency)
    d = datetime.strptime(data["date"], "%Y-%m-%d").date() if on_date is None else on_date
    snap = store_snapshot(db, d, data["base"], data["rates"], source=provider.name)
    db.commit()
    return {"date": snap.rate_date.isoformat(), "base": snap.base_currency, "count": len(snap.rates)}
