"""POST /auth/me/delete（账号注销）测试。

用独立内存库 + 依赖覆盖，避免碰开发库（AGENTS：开发过程不自行修改数据库）。
"""
import pytest
from types import SimpleNamespace

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.core.security import get_current_user, get_password_hash
from app.main import app
from app.models.meal_plan import MealPlan, MealPlanItem
from app.models.merchant import Merchant
from app.models.recipe import Recipe
from app.models.user import User
from app.models.user_favorite import UserFavorite
from app.models.user_merchant_favorite import UserMerchantFavorite

client = TestClient(app)

CLIENT_PASSWORD = "sha256_of_password"  # 模拟前端 SHA256 后的值


@pytest.fixture()
def env():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine, autoflush=False, autocommit=False)

    def override_db():
        db = Session()
        try:
            yield db
        finally:
            db.close()

    current = {"id": None}
    app.dependency_overrides[get_db] = override_db
    app.dependency_overrides[get_current_user] = lambda: SimpleNamespace(id=current["id"])
    try:
        yield Session, current
    finally:
        app.dependency_overrides.pop(get_db, None)
        app.dependency_overrides.pop(get_current_user, None)
        engine.dispose()


def _mk_user(db, name: str, *, is_admin: bool = False) -> User:
    user = User(
        username=name,
        email=f"{name}@test.com",
        password_hash=get_password_hash(CLIENT_PASSWORD),
        is_admin=is_admin,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def _delete(uid: int, password: str = CLIENT_PASSWORD):
    return client.post(
        "/api/v1/auth/me/delete",
        json={"password_hash": password},
    )


def _use(current: dict, uid: int) -> None:
    current["id"] = uid


def test_delete_removes_all_own_data(env):
    Session, current = env
    db = Session()
    user = _mk_user(db, "gone")
    merchant = Merchant(name="小卖部", user_id=user.id)
    db.add(merchant)
    db.commit()

    recipe = Recipe(name="番茄炒蛋", user_id=user.id, is_public=False, images=[])
    db.add(recipe)
    db.commit()

    plan = MealPlan(user_id=user.id, name="一天", kind="day")
    db.add(plan)
    db.commit()
    db.add(MealPlanItem(plan_id=plan.id, group="other", item_type="recipe",
                        recipe_id=recipe.id, sort_order=0))
    db.add(UserFavorite(user_id=user.id, entity_type="recipe", entity_id=recipe.id))
    db.add(UserMerchantFavorite(user_id=user.id, merchant_id=merchant.id))
    db.commit()

    uid = user.id
    db.close()

    _use(current, uid)
    assert _delete(uid, "wrong_password").status_code == 400
    assert _delete(uid).status_code == 204

    db = Session()
    assert db.query(User).filter(User.id == uid).count() == 0
    assert db.query(Merchant).count() == 0
    assert db.query(Recipe).filter(Recipe.user_id == uid).count() == 0
    assert db.query(Recipe).count() == 0
    assert db.query(MealPlan).count() == 0
    assert db.query(MealPlanItem).count() == 0
    assert db.query(UserFavorite).count() == 0
    assert db.query(UserMerchantFavorite).count() == 0
    db.close()


def test_delete_keeps_and_anonymizes_content_used_by_others(env):
    Session, current = env
    db = Session()
    owner = _mk_user(db, "owner")
    other = _mk_user(db, "other")

    recipe = Recipe(name="公共菜谱", user_id=owner.id, is_public=True, images=[])
    merchant = Merchant(name="公共商家", user_id=owner.id)
    db.add_all([recipe, merchant])
    db.commit()

    other_plan = MealPlan(user_id=other.id, name="别人的方案", kind="meal")
    db.add(other_plan)
    db.commit()
    db.add(MealPlanItem(plan_id=other_plan.id, group="other", item_type="recipe",
                        recipe_id=recipe.id, sort_order=0))
    db.add(UserMerchantFavorite(user_id=other.id, merchant_id=merchant.id))
    db.commit()

    owner_id, other_id = owner.id, other.id
    recipe_id, merchant_id = recipe.id, merchant.id
    db.close()

    _use(current, owner_id)
    assert _delete(owner_id).status_code == 204

    db = Session()
    # 注销者被删
    assert db.query(User).filter(User.id == owner_id).count() == 0
    # 他人数据保留
    assert db.query(User).filter(User.id == other_id).count() == 1
    # 公共内容保留但匿名化（user_id -> NULL）
    kept_recipe = db.query(Recipe).filter(Recipe.id == recipe_id).first()
    kept_merchant = db.query(Merchant).filter(Merchant.id == merchant_id).first()
    assert kept_recipe is not None and kept_recipe.user_id is None
    assert kept_merchant is not None and kept_merchant.user_id is None
    # 他人的引用完好
    assert db.query(MealPlanItem).filter(MealPlanItem.recipe_id == recipe_id).count() == 1
    assert db.query(UserMerchantFavorite).filter(
        UserMerchantFavorite.user_id == other_id,
        UserMerchantFavorite.merchant_id == merchant_id,
    ).count() == 1
    db.close()


def test_last_admin_cannot_self_delete(env):
    Session, current = env
    db = Session()
    admin = _mk_user(db, "solo_admin", is_admin=True)
    admin_id = admin.id
    db.close()

    _use(current, admin_id)
    resp = _delete(admin_id)
    assert resp.status_code == 400
    assert "管理员" in resp.json()["detail"]

    db = Session()
    assert db.query(User).filter(User.id == admin_id).count() == 1
    db.close()
