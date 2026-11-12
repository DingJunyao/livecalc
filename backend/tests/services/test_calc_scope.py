"""默认计算范围推导测试。"""
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from app.core.database import Base
from app.models import AdministrativeRegion, User
from app.services.calc_scope import resolve_default_calc_region_id, resolve_region_param
from app.services.session_context import reset_session_region, set_session_region

@pytest.fixture()
def db():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    S = sessionmaker(bind=engine)
    s = S()
    yield s
    s.close()

def test_resolve_scope_walks_to_province(db):
    cn = AdministrativeRegion(id=100, code="CN", name="中国", level=0, iso_country="CN", path="CN")
    gd = AdministrativeRegion(id=200, code="440000", name="广东省", level=1, iso_country="CN", path="CN/440000", parent_id=100)
    sz = AdministrativeRegion(id=300, code="440300", name="深圳市", level=2, iso_country="CN", path="CN/440000/440300", parent_id=200)
    db.add_all([cn, gd, sz])
    db.commit()
    u = User(id=1, username="u", email="u@b.c", password_hash="x", region_id=300, default_calc_scope="province")
    assert resolve_default_calc_region_id(db, u) == 200


def test_explicit_session_all_regions_overrides_user_default_scope(db):
    """会话中选择“全部地区”不能回退为用户保存的地区范围。"""
    cn = AdministrativeRegion(id=100, code="CN", name="中国", level=0, iso_country="CN", path="CN")
    gd = AdministrativeRegion(id=200, code="440000", name="广东省", level=1, iso_country="CN", path="CN/440000", parent_id=100)
    sz = AdministrativeRegion(id=300, code="440300", name="深圳市", level=2, iso_country="CN", path="CN/440000/440300", parent_id=200)
    db.add_all([cn, gd, sz])
    db.commit()
    user = User(id=1, username="u", email="u@b.c", password_hash="x", region_id=300, default_calc_scope="province")

    set_session_region(None)
    try:
        assert resolve_region_param(db, user, None) is None
    finally:
        reset_session_region()


# ---- 自定义计算范围（多地区组合）----

def _make_regions(db):
    db.add_all([
        AdministrativeRegion(id=100, code="CN", name="中国", level=0, iso_country="CN", path="CN"),
        AdministrativeRegion(id=200, code="410000", name="河南省", level=1, iso_country="CN", path="CN/410000", parent_id=100),
        AdministrativeRegion(id=300, code="411200", name="三门峡市", level=2, iso_country="CN", path="CN/410000/411200", parent_id=200),
        AdministrativeRegion(id=400, code="440300", name="深圳市", level=2, iso_country="CN", path="CN/440000/440300", parent_id=200),
    ])
    db.commit()


def test_custom_scope_default_beats_legacy_scope(db):
    """default_calc_scope_id 设置时优先于既有 region_id + default_calc_scope。"""
    from app.models import UserCalcScope
    _make_regions(db)
    scope = UserCalcScope(user_id=1, name="老家周边", region_ids=[300, 400])
    db.add(scope)
    db.commit()
    u = User(id=1, username="u", email="u@b.c", password_hash="x",
             region_id=300, default_calc_scope="province", default_calc_scope_id=scope.id)
    ids = resolve_default_calc_region_id(db, u)
    assert ids == (300, 400)
    assert isinstance(ids, tuple)  # 可哈希：recipe_service 用 region_id 作缓存键


def test_custom_scope_works_without_user_region(db):
    """自定义组合显式列出地区，不要求 users.region_id 已设置。"""
    from app.models import UserCalcScope
    _make_regions(db)
    scope = UserCalcScope(user_id=1, name="组合", region_ids=[300])
    db.add(scope)
    db.commit()
    u = User(id=1, username="u", email="u@b.c", password_hash="x",
             region_id=None, default_calc_scope=None, default_calc_scope_id=scope.id)
    assert resolve_default_calc_region_id(db, u) == (300,)


def test_custom_scope_missing_rows_falls_back_to_legacy(db):
    """范围被删（查不到行）时回退既有 region_id + default_calc_scope 推导。"""
    _make_regions(db)
    u = User(id=1, username="u", email="u@b.c", password_hash="x",
             region_id=300, default_calc_scope="province", default_calc_scope_id=999)
    assert resolve_default_calc_region_id(db, u) == 200


def test_custom_scope_empty_region_ids_falls_back_to_legacy(db):
    """范围存在但 region_ids 为空 → 回退既有推导。"""
    from app.models import UserCalcScope
    _make_regions(db)
    scope = UserCalcScope(user_id=1, name="空组合", region_ids=[])
    db.add(scope)
    db.commit()
    u = User(id=1, username="u", email="u@b.c", password_hash="x",
             region_id=300, default_calc_scope="province", default_calc_scope_id=scope.id)
    assert resolve_default_calc_region_id(db, u) == 200


def test_custom_scope_dedupes_preserving_order(db):
    """region_ids 去重保序（dict.fromkeys），类型为 tuple。"""
    from app.models import UserCalcScope
    _make_regions(db)
    scope = UserCalcScope(user_id=1, name="重复", region_ids=[400, 300, 400, 300])
    db.add(scope)
    db.commit()
    u = User(id=1, username="u", email="u@b.c", password_hash="x", default_calc_scope_id=scope.id)
    assert resolve_default_calc_region_id(db, u) == (400, 300)
