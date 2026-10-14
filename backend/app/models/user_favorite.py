"""用户收藏（原料 / 商品 / 菜谱）。

商家收藏沿用独立表 user_merchant_favorites（见该模型）；本表覆盖其余三类实体，
按 entity_type 多态解释 entity_id。纯链接表：取消收藏 = 物理删除
（对齐 user_merchant_favorites 的模式）。
entity_id 不加跨表外键（多态 + 软删 + 导出导入重排行 id），存在性由 API 层校验。
"""
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.sql import func
from app.core.database import Base


class UserFavorite(Base):
    __tablename__ = "user_favorites"
    __table_args__ = (
        UniqueConstraint("user_id", "entity_type", "entity_id", name="uq_user_favorites"),
    )

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    entity_type = Column(String(20), nullable=False)  # 'ingredient' | 'product' | 'recipe'
    entity_id = Column(Integer, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
