"""收藏（原料/商品/菜谱）的模型与 API 回归测试。

口径：收藏是个人私有数据（登录直写、不走审批）；纯链接表
（(user_id, entity_type, entity_id) 唯一，取消收藏=物理删）；列表端点
favorites_first / favorites_only 参数化且默认关闭。
"""
import pytest
from sqlalchemy.exc import IntegrityError

from conftest import FakeUser, TestingSessionLocal, engine
from app.core.database import Base


def test_user_favorite_unique_constraint():
    Base.metadata.create_all(bind=engine)
    from app.models.user_favorite import UserFavorite

    db = TestingSessionLocal()
    try:
        db.add(UserFavorite(user_id=FakeUser.id, entity_type="recipe", entity_id=999001))
        db.commit()
        db.add(UserFavorite(user_id=FakeUser.id, entity_type="recipe", entity_id=999001))
        with pytest.raises(IntegrityError):
            db.commit()
        db.rollback()
    finally:
        db.query(UserFavorite).filter(UserFavorite.entity_id == 999001).delete()
        db.commit()
        db.close()
