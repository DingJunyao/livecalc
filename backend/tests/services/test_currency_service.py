"""币种与地区推导服务测试。"""
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from app.core.database import Base
from app.models import Currency, RegionUnitSetting, AdministrativeRegion, Merchant, User
from app.services.currency_service import (
    get_region_default_currency,
    get_merchant_default_currency,
    get_user_default_currency,
    currency_symbol,
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
    db.add(Currency(code="CNY", name="人民币", symbol="¥"))
    db.add(Currency(code="USD", name="美元", symbol="$"))
    db.add(RegionUnitSetting(region_code="CN", region_name="中国", default_currency="CNY"))
    cn = AdministrativeRegion(id=100, code="CN", name="中国", level=0, iso_country="CN", path="CN")
    gd = AdministrativeRegion(id=200, code="440000", name="广东省", level=1, iso_country="CN", path="CN/440000", parent_id=100)
    sz = AdministrativeRegion(id=300, code="440300", name="深圳市", level=2, iso_country="CN", path="CN/440000/440300", parent_id=200)
    db.add_all([cn, gd, sz])
    db.commit()


def test_currency_symbol_falls_back_to_code(db):
    _seed(db)
    assert currency_symbol(db, "USD") == "$"
    assert currency_symbol(db, "XXX") == "XXX"


def test_region_default_currency_walks_to_country(db):
    _seed(db)
    sz = db.query(AdministrativeRegion).filter_by(id=300).one()
    assert get_region_default_currency(db, sz) == "CNY"


def test_merchant_default_currency_override_and_derive(db):
    _seed(db)
    m1 = Merchant(name="A", region_id=300, default_currency=None)
    m2 = Merchant(name="B", region_id=300, default_currency="USD")
    db.add_all([m1, m2])
    db.commit()
    assert get_merchant_default_currency(db, m1) == "CNY"
    assert get_merchant_default_currency(db, m2) == "USD"


def test_user_default_currency_override_and_derive(db):
    _seed(db)
    u1 = User(username="a", email="a@b.c", password_hash="x", region_id=300, default_currency=None)
    u2 = User(username="b", email="b@b.c", password_hash="x", region_id=None, default_currency="USD")
    db.add_all([u1, u2])
    db.commit()
    assert get_user_default_currency(db, u1) == "CNY"
    assert get_user_default_currency(db, u2) == "USD"


def test_region_change_clears_legacy_inherited_currency_but_keeps_manual_override(db):
    """迁移地区时，旧地区的默认币种不应继续遮蔽新地区币种。"""
    from app.api.auth import _clear_inherited_currency_after_region_change

    _seed(db)
    db.add(RegionUnitSetting(region_code="ID", region_name="印度尼西亚", default_currency="IDR"))
    indonesia = AdministrativeRegion(id=400, code="ID", name="印度尼西亚", level=0, iso_country="ID", path="ID")
    inherited = User(username="follow_region", email="follow_region@x.c", password_hash="x", region_id=100, default_currency="CNY")
    manual = User(username="manual_currency", email="manual_currency@x.c", password_hash="x", region_id=100, default_currency="USD")
    db.add_all([indonesia, inherited, manual])
    db.commit()

    _clear_inherited_currency_after_region_change(db, inherited, 100, 400)
    _clear_inherited_currency_after_region_change(db, manual, 100, 400)

    assert inherited.default_currency is None
    inherited.region_id = 400
    assert get_user_default_currency(db, inherited) == "IDR"
    assert manual.default_currency == "USD"


def test_recompute_user_records_rebases_snapshots(db):
    """用户币种 CNY -> JPY：价格记录 exchange_rate/user_currency 按记录日期重算。"""
    from datetime import datetime, date
    from decimal import Decimal

    from app.config import settings
    from app.models.exchange_rate_snapshot import ExchangeRateSnapshot
    from app.models.product import ProductRecord
    from app.services.currency_service import recompute_user_records
    from app.services.exchange_rate_service import store_snapshot

    db.add(Currency(code="CNY", name="人民币", symbol="¥"))
    db.add(Currency(code="JPY", name="日元", symbol="¥"))
    db.add(RegionUnitSetting(region_code="JP", region_name="日本", default_currency="JPY"))
    db.add(AdministrativeRegion(id=50, code="JP", name="日本", level=0, iso_country="JP", path="JP"))
    store_snapshot(db, date.today(), settings.exchange_rate_base_currency, {"CNY": "7.8", "JPY": "160.0"})
    u = User(username="recompute_u", email="recompute@x.c", password_hash="x", region_id=50)
    db.add(u)
    db.commit()

    r = ProductRecord(
        user_id=u.id, product_id=1, product_name="p", price=100,
        original_quantity=1, original_unit_id=1,
        standard_quantity=1, standard_unit_id=1,
        currency="CNY", user_currency="CNY", exchange_rate=Decimal("1"),
        recorded_at=datetime.now(),
    )
    db.add(r)
    db.commit()

    res = recompute_user_records(db, u.id, "JPY")
    assert res["updated"] == 1 and res["skipped"] == 0
    db.refresh(r)
    assert r.user_currency == "JPY"
    assert r.exchange_rate is not None and r.exchange_rate != Decimal("1")

    # 幂等：币种未变时再跑同样结果
    res2 = recompute_user_records(db, u.id, "JPY")
    assert res2["updated"] == 1


def test_recompute_uses_nearest_snapshot_for_old_records(db):
    """记录日期早于最早汇率快照时，用最近可用快照重算（不跳过）。"""
    from datetime import date, datetime, timedelta
    from decimal import Decimal

    from app.config import settings
    from app.models.product import ProductRecord
    from app.services.currency_service import recompute_user_records
    from app.services.exchange_rate_service import store_snapshot

    db.add(Currency(code="CNY", name="人民币", symbol="¥"))
    db.add(Currency(code="JPY", name="日元", symbol="¥"))
    store_snapshot(db, date.today(), settings.exchange_rate_base_currency, {"CNY": "7.8", "JPY": "160.0"})
    u = User(username="old_u", email="old@x.c", password_hash="x", region_id=50)
    db.add(u)
    db.commit()

    r = ProductRecord(
        user_id=u.id, product_id=1, product_name="old", price=100,
        original_quantity=1, original_unit_id=1,
        standard_quantity=1, standard_unit_id=1,
        currency="CNY", user_currency="CNY", exchange_rate=Decimal("1"),
        recorded_at=datetime.now() - timedelta(days=30),  # 早于快照日期
    )
    db.add(r)
    db.commit()

    res = recompute_user_records(db, u.id, "JPY")
    assert res["updated"] == 1 and res["skipped"] == 0
    db.refresh(r)
    assert r.user_currency == "JPY"
