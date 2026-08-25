"""地区过滤与快照折算测试。"""
from decimal import Decimal
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models import AdministrativeRegion, Merchant, ProductRecord
from app.services.price_region import apply_region_filter, record_price_in_user_currency


@pytest.fixture()
def db():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    S = sessionmaker(bind=engine)
    s = S()
    yield s
    s.close()


def _region(db, id_, code, name, level, path):
    r = AdministrativeRegion(id=id_, code=code, name=name, level=level, iso_country=code, path=path)
    db.add(r)
    return r


def _merchant(db, id_, region_id):
    m = Merchant(id=id_, name=f"m{id_}", region_id=region_id)
    db.add(m)
    return m


def _record(db, id_, merchant_id):
    r = ProductRecord(id=id_, user_id=1, product_id=1, merchant_id=merchant_id, product_name="x", price=1, original_quantity=1, original_unit_id=1, standard_quantity=1, standard_unit_id=1, is_active=True)
    db.add(r)
    return r


def test_record_price_factor():
    class R:
        price = Decimal("10")
        exchange_rate = Decimal("7.8")
    assert record_price_in_user_currency(R()) == Decimal("78")


def test_record_price_factor_none_is_one():
    class R:
        price = Decimal("10")
        exchange_rate = None
    assert record_price_in_user_currency(R()) == Decimal("10")


def test_apply_region_filter_includes_unassigned_merchants(db):
    # 中国(46) -> 河南(level1) -> 三门峡(level2, 1100) -> 湖滨区(level3, 1951)
    _region(db, 46, "CN", "中国", 0, "CN")
    _region(db, 100, "410000", "河南省", 1, "CN/410000", )
    _region(db, 1100, "411200", "三门峡市", 2, "CN/410000/411200")
    _region(db, 1951, "411202", "湖滨区", 3, "CN/410000/411200/411202")
    # 商家：在湖滨区(1951)、在别处(外国城市 999)、未分配(NULL)
    _merchant(db, 1, 1951)
    _merchant(db, 2, 999)
    _merchant(db, 3, None)
    # 记录
    _record(db, 11, 1)
    _record(db, 12, 2)
    _record(db, 13, 3)
    db.commit()

    from app.models.product import ProductRecord as PR
    q = db.query(PR)
    # 过滤到「三门峡市」子树：应包含 湖滨区商家 + 未分配地区商家，排除别处商家
    rows = apply_region_filter(q, db, 1100).all()
    got = sorted(r.merchant_id for r in rows)
    assert got == [1, 3]
