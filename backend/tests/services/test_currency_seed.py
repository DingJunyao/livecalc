"""币种字典启动自动填充服务测试。"""
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models import Currency
from app.services.currency_seed import CURRENCIES, ensure_currencies


def _db():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine)()


def test_ensure_currencies_populates_all_when_empty():
    db = _db()
    try:
        result = ensure_currencies(db)
        assert result["created"] == len(CURRENCIES)
        assert result["skipped"] == 0
        assert db.query(Currency).count() == len(CURRENCIES)
    finally:
        db.close()


def test_ensure_currencies_idempotent():
    db = _db()
    try:
        ensure_currencies(db)
        first = {c.code for c in db.query(Currency).all()}
        result = ensure_currencies(db)
        assert result["created"] == 0
        assert result["skipped"] == len(CURRENCIES)
        assert {c.code for c in db.query(Currency).all()} == first
    finally:
        db.close()


def test_ensure_currencies_does_not_overwrite_existing():
    db = _db()
    try:
        db.add(Currency(code="CNY", name="自定义名称", symbol="元", decimals=0, is_active=False))
        db.commit()
        result = ensure_currencies(db)
        assert result["created"] == len(CURRENCIES) - 1
        row = db.query(Currency).filter(Currency.code == "CNY").one()
        assert row.name == "自定义名称"
        assert row.symbol == "元"
        assert row.decimals == 0
        assert row.is_active is False
        assert db.query(Currency).filter(Currency.code == "USD").one() is not None
    finally:
        db.close()


def test_currency_dictionary_covers_seed_and_provider_set():
    # 原有 seed 15 种 + Frankfurter/ECB 主流币种都应覆盖
    codes = [
        "CNY", "USD", "EUR", "GBP", "JPY", "HKD", "KRW", "SGD",
        "AUD", "CAD", "TWD", "THB", "MYR", "VND", "RUB",
        "AED", "BGN", "BRL", "CHF", "CZK", "DKK", "HUF", "IDR",
        "ILS", "INR", "ISK", "MXN", "NOK", "NZD", "PHP", "PLN",
        "RON", "SEK", "TRY", "ZAR",
    ]
    assert set(codes) == set(CURRENCIES)
    for code, meta in CURRENCIES.items():
        assert len(code) == 3 and code.isupper()
        assert meta["name"]
        assert isinstance(meta["symbol"], str)
        assert meta["decimals"] >= 0
