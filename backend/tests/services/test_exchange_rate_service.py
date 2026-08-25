"""汇率服务测试（使用内存快照，不发真实网络）。"""
from datetime import date
from decimal import Decimal
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from app.core.database import Base
from app.models import ExchangeRateSnapshot
from app.services.exchange_rate_service import (
    store_snapshot,
    convert,
    get_rate_on_date,
)

@pytest.fixture()
def db():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    S = sessionmaker(bind=engine)
    s = S()
    yield s
    s.close()

def _seed(db):
    store_snapshot(db, date(2026, 8, 1), "EUR", {"EUR": 1.0, "USD": 1.08, "CNY": 7.8}, source="test")
    db.commit()

def test_convert_same_currency(db):
    assert convert(db, Decimal("10"), "CNY", "CNY", date(2026, 8, 1)) == Decimal("10")

def test_convert_cross_currency(db):
    _seed(db)
    got = convert(db, Decimal("10"), "CNY", "EUR", date(2026, 8, 1))
    assert round(float(got), 6) == round(10 / 7.8, 6)

def test_get_rate_on_date_forward_fills(db):
    _seed(db)
    assert get_rate_on_date(db, "USD", date(2026, 8, 5)) == Decimal("1.08")

def test_missing_currency_returns_none(db):
    _seed(db)
    assert get_rate_on_date(db, "JPY", date(2026, 8, 1)) is None
