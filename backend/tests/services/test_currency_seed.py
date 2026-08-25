"""币种字典启动自动填充服务测试。"""
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models import AdministrativeRegion, Currency, RegionUnitSetting
from app.services.currency_seed import (
    CURRENCIES,
    REGION_CURRENCIES,
    ensure_currencies,
    ensure_region_currencies,
)

# 精选币种 + 地区映射用到的全部 ISO 4217 代码
EXPECTED_TOTAL = len(set(CURRENCIES) | set(REGION_CURRENCIES.values()))


def _db():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    return sessionmaker(bind=engine)()


def test_ensure_currencies_populates_all_when_empty():
    db = _db()
    try:
        result = ensure_currencies(db)
        assert result["created"] == EXPECTED_TOTAL
        assert result["skipped"] == 0
        assert db.query(Currency).count() == EXPECTED_TOTAL
    finally:
        db.close()


def test_ensure_currencies_idempotent():
    db = _db()
    try:
        ensure_currencies(db)
        first = {c.code for c in db.query(Currency).all()}
        result = ensure_currencies(db)
        assert result["created"] == 0
        assert result["skipped"] == EXPECTED_TOTAL
        assert {c.code for c in db.query(Currency).all()} == first
    finally:
        db.close()


def test_ensure_currencies_does_not_overwrite_existing():
    db = _db()
    try:
        db.add(Currency(code="CNY", name="自定义名称", symbol="元", decimals=0, is_active=False))
        db.commit()
        result = ensure_currencies(db)
        assert result["created"] == EXPECTED_TOTAL - 1
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


def test_ensure_region_currencies_fills_and_is_idempotent():
    db = _db()
    try:
        db.add_all([
            AdministrativeRegion(id=1, code="CN", name="中国", level=0, iso_country="CN", path="CN"),
            AdministrativeRegion(id=2, code="US", name="美国", level=0, iso_country="US", path="US"),
            AdministrativeRegion(id=3, code="JP", name="日本", level=0, iso_country="JP", path="JP"),
        ])
        db.commit()

        result = ensure_region_currencies(db)
        assert result["filled"] == 3
        assert db.query(RegionUnitSetting).filter(RegionUnitSetting.region_code == "US").one().default_currency == "USD"
        assert db.query(RegionUnitSetting).filter(RegionUnitSetting.region_code == "CN").one().default_currency == "CNY"

        # 幂等：第二次不重复补齐
        assert ensure_region_currencies(db)["filled"] == 0

        # 不覆盖已设值（模拟管理员手工改过）
        us = db.query(RegionUnitSetting).filter(RegionUnitSetting.region_code == "US").one()
        us.default_currency = "EUR"
        db.commit()
        assert ensure_region_currencies(db)["filled"] == 0
        assert db.query(RegionUnitSetting).filter(RegionUnitSetting.region_code == "US").one().default_currency == "EUR"
    finally:
        db.close()


def test_region_currency_map_covers_supported_currencies():
    # 每种支持币种至少有一个映射国
    codes = set(REGION_CURRENCIES.values())
    assert set(CURRENCIES) - codes == set()
    assert REGION_CURRENCIES["CN"] == "CNY"
    assert REGION_CURRENCIES["US"] == "USD"
    assert REGION_CURRENCIES["DE"] == "EUR"


def test_region_currency_map_covers_all_countries():
    # 覆盖 countries.json 全部 249 个国家/地区
    import json
    import os
    data_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))),
        "frontend", "src", "data", "regions", "countries.json",
    )
    with open(data_path, encoding="utf-8") as f:
        countries = json.load(f)
    codes = {c["alpha-2"] for c in countries}
    assert codes <= set(REGION_CURRENCIES)
    # 每种映射币种都能被 ensure_currencies 补齐
    needed = set(CURRENCIES) | set(REGION_CURRENCIES.values())
    db = _db()
    try:
        result = ensure_currencies(db)
        assert result["created"] == len(needed)
    finally:
        db.close()

