"""
每日饮食推荐模型

存储每位用户每天每餐的推荐记录（父表）。
一道推荐可含多道菜（子表 daily_recommendation_items，设计 §4.6）；
reason/preference/source 记录组合层的输出与输入，refresh_count 支撑
「每餐每天 5 次」刷新上限（修复旧 COUNT-1 口径从未生效的 bug）。
"""
from sqlalchemy import Column, Integer, String, Date, DateTime, Text, ForeignKey, UniqueConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base


class DailyRecommendation(Base):
    __tablename__ = "daily_recommendations"
    __table_args__ = (
        UniqueConstraint("user_id", "date", "meal_type", name="uq_user_date_meal"),
    )

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    date = Column(Date, nullable=False)
    meal_type = Column(String(20), nullable=False)  # breakfast / lunch / dinner
    reason = Column(Text, nullable=True)  # 整餐一句话理由（AI 或模板）
    preference = Column(String(200), nullable=True)  # 生成时的一句话偏好快照
    source = Column(String(20), nullable=False, default="rule")  # rule|system_ai|user_ai|plan
    refresh_count = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # 关系
    user = relationship("User", back_populates="daily_recommendations")
    items = relationship(
        "DailyRecommendationItem",
        back_populates="recommendation",
        cascade="all, delete-orphan",
        order_by="DailyRecommendationItem.sort_order",
    )
