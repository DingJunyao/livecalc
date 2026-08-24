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
