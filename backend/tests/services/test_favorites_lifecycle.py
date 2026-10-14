"""收藏的生命周期联动：合并搬迁/回滚 + 导出导入往返。"""
import uuid

import pytest

from conftest import FakeUser, TestingSessionLocal, engine
from app.core.database import Base
from app.services.proposals.bootstrap import register_all


@pytest.fixture(autouse=True)
def _register_proposal_executors():
    """TestClient 不触发 main.py lifespan，需显式注册提案执行器。"""
    register_all()
    yield


def _seed_two_ingredients(db):
    from app.models.nutrition import Ingredient

    suffix = uuid.uuid4().hex[:10]
    src = Ingredient(name=f"收藏合并源_{suffix}", is_active=True)
    tgt = Ingredient(name=f"收藏合并目标_{suffix}", is_active=True)
    db.add_all([src, tgt])
    db.commit()
    return src.id, tgt.id


def _favorite(db, entity_type, entity_id, user_id=FakeUser.id):
    from app.models.user_favorite import UserFavorite

    db.add(UserFavorite(user_id=user_id, entity_type=entity_type, entity_id=entity_id))
    db.commit()


def _cleanup(ingredient_ids):
    from app.models.nutrition import Ingredient
    from app.models.user_favorite import UserFavorite

    db = TestingSessionLocal()
    try:
        db.query(UserFavorite).filter(
            UserFavorite.entity_id.in_(list(ingredient_ids))
        ).delete(synchronize_session=False)
        db.query(Ingredient).filter(Ingredient.id.in_(list(ingredient_ids))).delete(
            synchronize_session=False
        )
        db.commit()
    finally:
        db.close()


def test_ingredient_merge_removes_source_favorites(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        src_id, tgt_id = _seed_two_ingredients(db)
        _favorite(db, "ingredient", src_id)
        _favorite(db, "ingredient", tgt_id)
    finally:
        db.close()

    client = TestClient(app)
    try:
        # 管理员直写（apply_as_admin → IngredientExecutor._apply_merge）
        resp = client.post("/api/v1/ingredients/merge", json={
            "source_ingredient_ids": [src_id], "target_ingredient_id": tgt_id,
        })
        assert resp.status_code == 200, resp.text
        db = TestingSessionLocal()
        try:
            from app.models.user_favorite import UserFavorite
            rows = db.query(UserFavorite).filter(
                UserFavorite.entity_type == "ingredient",
                UserFavorite.entity_id.in_([src_id, tgt_id]),
            ).all()
            # 源收藏被删；目标收藏保留
            assert [r.entity_id for r in rows] == [tgt_id]
        finally:
            db.close()
    finally:
        _cleanup([src_id, tgt_id])
