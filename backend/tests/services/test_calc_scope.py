"""默认计算范围推导测试。"""
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from app.core.database import Base
from app.models import AdministrativeRegion, User
from app.services.calc_scope import resolve_default_calc_region_id

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
