"""重算历史快照的核心换算函数测试。"""
from datetime import date
from decimal import Decimal
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from app.core.database import Base
from app.models import ExchangeRateSnapshot
from app.services.exchange_rate_service import store_snapshot
from app.scripts import recompute_user_currency

@pytest.fixture()
def db():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    S = sessionmaker(bind=engine)
    s = S()
    yield s
    s.close()

def test_recompute_factor(db):
    store_snapshot(db, date(2026, 8, 1), "EUR", {"EUR": 1.0, "USD": 1.08, "CNY": 7.8}, source="test")
    db.commit()
    got = recompute_user_currency.compute_exchange_factor(db, "USD", "CNY", date(2026, 8, 1))
    assert round(float(got), 6) == round(7.8 / 1.08, 6)
