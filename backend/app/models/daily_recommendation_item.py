"""每日推荐条目（一道菜）。

父表 daily_recommendations 每餐一行，本表每道菜一行（多道菜套餐，设计 §4.6）。
role 用于组合语义：staple（主食）/ main / side / soup / drink。
"""
from sqlalchemy import Column, Integer, String, Text, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base


class DailyRecommendationItem(Base):
    __tablename__ = "daily_recommendation_items"

    id = Column(Integer, primary_key=True, index=True)
    recommendation_id = Column(
        Integer, ForeignKey("daily_recommendations.id"), nullable=False, index=True
    )
    recipe_id = Column(Integer, ForeignKey("recipes.id"), nullable=False, index=True)
    sort_order = Column(Integer, nullable=False, default=0)
    role = Column(String(20), nullable=False, default="main")
    reason = Column(Text, nullable=True)

    recommendation = relationship("DailyRecommendation", back_populates="items")
    recipe = relationship("Recipe")
