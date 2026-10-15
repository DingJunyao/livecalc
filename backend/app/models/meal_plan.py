"""试算方案（meal_plans + meal_plan_items）。

一份方案 = 一顿（kind='meal'）或一日（kind='day'）的搭配；条目三选一
（recipe / ingredient / product）。软删（AuditMixin）。推荐页「设为今日一餐」
会把 daily_recommendations.source 置为 'plan' 并回链 plan_id。
"""
from sqlalchemy import Column, Integer, String, Numeric, ForeignKey, CheckConstraint
from sqlalchemy.orm import relationship
from app.core.base_model import AuditMixin
from app.core.database import Base


class MealPlan(Base, AuditMixin):
    __tablename__ = "meal_plans"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)
    name = Column(String(120), nullable=False)
    kind = Column(String(10), nullable=False, default="meal")  # meal | day
    note = Column(String(200), nullable=True)

    items = relationship(
        "MealPlanItem",
        back_populates="plan",
        cascade="all, delete-orphan",
        order_by="MealPlanItem.sort_order",
    )


class MealPlanItem(Base, AuditMixin):
    __tablename__ = "meal_plan_items"
    __table_args__ = (
        CheckConstraint(
            "(item_type = 'recipe' AND recipe_id IS NOT NULL AND ingredient_id IS NULL AND product_id IS NULL) "
            "OR (item_type = 'ingredient' AND ingredient_id IS NOT NULL AND recipe_id IS NULL AND product_id IS NULL) "
            "OR (item_type = 'product' AND product_id IS NOT NULL AND recipe_id IS NULL AND ingredient_id IS NULL)",
            name="ck_meal_plan_item_type",
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    plan_id = Column(Integer, ForeignKey("meal_plans.id"), nullable=False, index=True)
    # 一日方案的分组；一顿方案统一 other
    group = Column(String(20), nullable=False, default="other")  # breakfast|lunch|dinner|other
    item_type = Column(String(20), nullable=False)  # recipe | ingredient | product
    recipe_id = Column(Integer, ForeignKey("recipes.id"), nullable=True)
    ingredient_id = Column(Integer, ForeignKey("ingredients.id"), nullable=True)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=True)
    # recipe 项：份量；ingredient/product 项：数量 + 单位
    servings = Column(Numeric(6, 2), nullable=True)
    quantity = Column(Numeric(12, 4), nullable=True)
    unit_id = Column(Integer, ForeignKey("units.id"), nullable=True)
    sort_order = Column(Integer, nullable=False, default=0)
    note = Column(String(200), nullable=True)

    plan = relationship("MealPlan", back_populates="items")
    recipe = relationship("Recipe")
    ingredient = relationship("Ingredient")
    product = relationship("Product")
    unit = relationship("Unit")
