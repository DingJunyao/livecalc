"""试算页（meal_plans）数据层测试。

设计 §5.1：meal_plans（kind=meal|day，软删）+ meal_plan_items
（recipe|ingredient|product 三选一 CheckConstraint）；daily_recommendations
加 plan_id（source='plan' 的方案来源餐）。
"""
import pytest
from sqlalchemy.exc import IntegrityError

from conftest import FakeUser, TestingSessionLocal, engine
from app.core.database import Base


def _make_plan(db, **overrides):
    from app.models.meal_plan import MealPlan, MealPlanItem

    plan = MealPlan(
        user_id=FakeUser.id,
        name=overrides.get("name", "一人食试算"),
        kind=overrides.get("kind", "meal"),
        note=overrides.get("note"),
        created_by=FakeUser.id,
        updated_by=FakeUser.id,
    )
    db.add(plan)
    db.flush()
    items = overrides.get("items") or [
        dict(item_type="recipe", recipe_id=101, servings=2, group="dinner"),
    ]
    for order, it in enumerate(items):
        db.add(MealPlanItem(plan_id=plan.id, sort_order=order, **it))
    db.commit()
    db.refresh(plan)
    return plan


def test_meal_plan_crud_and_check_constraint():
    Base.metadata.create_all(bind=engine)
    from app.models.meal_plan import MealPlan, MealPlanItem

    db = TestingSessionLocal()
    try:
        plan = _make_plan(db)
        assert plan.is_active is True
        assert len(plan.items) == 1
        assert plan.items[0].item_type == "recipe"

        # 三选一：同时给 recipe_id 与 ingredient_id → CheckConstraint 拒绝
        bad = MealPlanItem(
            plan_id=plan.id, item_type="recipe",
            recipe_id=1, ingredient_id=2,
        )
        db.add(bad)
        with pytest.raises(IntegrityError):
            db.commit()
        db.rollback()

        # 软删
        plan.is_active = False
        db.commit()
    finally:
        db.close()


def test_daily_recommendation_plan_id():
    Base.metadata.create_all(bind=engine)
    from app.models.meal_plan import MealPlan
    from app.models.daily_recommendation import DailyRecommendation

    db = TestingSessionLocal()
    try:
        plan = _make_plan(db)
        rec = DailyRecommendation(
            user_id=FakeUser.id,
            date=__import__("datetime").date.today(),
            meal_type="dinner",
            source="plan",
            plan_id=plan.id,
        )
        db.add(rec)
        db.commit()
        loaded = db.query(DailyRecommendation).filter(
            DailyRecommendation.id == rec.id).one()
        assert loaded.plan_id == plan.id
        assert loaded.plan.id == plan.id
    finally:
        db.close()
