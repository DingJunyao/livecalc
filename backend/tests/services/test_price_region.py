"""地区过滤与快照折算测试。"""
from decimal import Decimal
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models import AdministrativeRegion, Merchant, ProductRecord
from app.services.calc_scope import resolve_region_param
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


def test_session_region_override_beats_user_default(db):
    """会话级地区覆盖（X-Region）优先于用户默认计算范围。"""
    from app.services.session_context import get_session_region, reset_session_region, set_session_region
    _region(db, 100, "CN", "中国", 0, "CN")
    _region(db, 200, "440000", "广东省", 1, "CN/440000")
    _region(db, 300, "440300", "深圳市", 2, "CN/440000/440300")
    _merchant(db, 1, 300)
    db.commit()

    class User:
        region_id = None
        default_calc_scope = "country"

    try:
        # 无覆盖：用户无地区 -> 不设过滤（None）
        assert resolve_region_param(db, User(), None) is None
        # 会话覆盖到深圳
        set_session_region(300)
        assert resolve_region_param(db, User(), None) == 300
        # 显式 region_id 仍优先
        assert resolve_region_param(db, User(), 100) == 100
    finally:
        reset_session_region()


def test_session_currency_factor_in_record_price(db):
    """会话币种覆盖时 record_price_in_user_currency 折算到会话币种。"""
    from app.services.session_context import reset_session_currency, set_session_currency
    class R:
        price = Decimal("10")
        exchange_rate = Decimal("7.2")  # USD -> CNY
    try:
        assert record_price_in_user_currency(R()) == Decimal("72")
        set_session_currency("JPY", 20.0)  # CNY -> JPY
        assert record_price_in_user_currency(R()) == Decimal("1440")
    finally:
        reset_session_currency()


# ---- 多地区组合（自定义计算范围）----

def _build_two_cities(db):
    """中国(46) -> 河南(100) -> 三门峡(1100) -> 湖滨区(1951)；广东(200) -> 深圳(300)。"""
    _region(db, 46, "CN", "中国", 0, "CN")
    _region(db, 100, "410000", "河南省", 1, "CN/410000")
    _region(db, 1100, "411200", "三门峡市", 2, "CN/410000/411200")
    _region(db, 1951, "411202", "湖滨区", 3, "CN/410000/411200/411202")
    _region(db, 200, "440000", "广东省", 1, "CN/440000")
    _region(db, 300, "440300", "深圳市", 2, "CN/440000/440300")


def test_region_subtree_ids_multi_union_dedup(db):
    """多地区组合 = 各子树并集去重：市 + 其下辖县不重复；空元组 → 空列表。"""
    _build_two_cities(db)
    _merchant(db, 1, 1951)
    db.commit()

    from app.services.price_region import region_subtree_ids
    merged = region_subtree_ids(db, (1100, 1951))
    assert sorted(merged) == sorted(set(merged))  # 无重复
    assert 1951 in merged and 1100 in merged
    # 与逐个展开的并集一致
    assert sorted(merged) == sorted(set(region_subtree_ids(db, 1100)) | set(region_subtree_ids(db, 1951)))
    assert region_subtree_ids(db, ()) == []


def test_apply_region_filter_multi_region_union(db):
    """组合过滤：两城市子树并集内的商家计入 + 未分配地区商家计入，别处排除。"""
    _build_two_cities(db)
    _merchant(db, 1, 1951)   # 三门峡湖滨区
    _merchant(db, 2, 300)    # 深圳
    _merchant(db, 3, 999)    # 别处（无子树覆盖）
    _merchant(db, 4, None)   # 未分配地区
    _record(db, 11, 1)
    _record(db, 12, 2)
    _record(db, 13, 3)
    _record(db, 14, 4)
    db.commit()

    from app.models.product import ProductRecord as PR
    q = db.query(PR)
    rows = apply_region_filter(q, db, (1100, 300)).all()
    assert sorted(r.merchant_id for r in rows) == [1, 2, 4]

    # 单 id 与等价单元素元组结果一致（X-Region 兼容性）
    single = apply_region_filter(db.query(PR), db, (1100,)).all()
    assert sorted(r.merchant_id for r in single) == [1, 4]


def test_apply_region_filter_empty_tuple_filters_all(db):
    """空元组 = 无有效地区 → 全部过滤（与单 id 空子树同语义）。"""
    _build_two_cities(db)
    _merchant(db, 1, 1951)
    _record(db, 11, 1)
    db.commit()

    from app.models.product import ProductRecord as PR
    assert apply_region_filter(db.query(PR), db, ()).all() == []


def test_session_region_override_accepts_tuple(db):
    """会话地区覆盖（X-Region 多 id）支持元组并透传。"""
    from app.services.session_context import reset_session_region, set_session_region
    _build_two_cities(db)
    db.commit()

    class User:
        region_id = None
        default_calc_scope = None

    try:
        set_session_region((1100, 300))
        assert resolve_region_param(db, User(), None) == (1100, 300)
    finally:
        reset_session_region()