"""每日推荐「父表 + 子表（多道菜）」与 AI 策略表的数据层测试。

口径（设计 §4.6）：
- daily_recommendations 每餐一行（唯一约束不变），新增 reason/preference/source/refresh_count，
  删除 recipe_id（由子表取代）；refresh_count 修复「5 次/餐/天」上限从未生效的 bug。
- daily_recommendation_items 每道菜一行（sort_order 定序，reason 每道一句）。
"""
from conftest import FakeUser, TestingSessionLocal, engine
from app.core.database import Base


def test_daily_recommendation_has_items_not_recipe_id():
    Base.metadata.create_all(bind=engine)
    from app.models.recipe import Recipe
    from app.models.daily_recommendation import DailyRecommendation
    from app.models.daily_recommendation_item import DailyRecommendationItem

    assert not hasattr(DailyRecommendation, "recipe_id"), "父表 recipe_id 应已由子表取代"

    db = TestingSessionLocal()
    try:
        recipe = Recipe(name=f"推荐子表菜谱_{id(engine)%100000}", category="主食",
                        user_id=FakeUser.id, is_active=True)
        db.add(recipe)
        db.commit()
        rec = DailyRecommendation(
            user_id=FakeUser.id,
            date=__import__("datetime").date.today(),
            meal_type="lunch",
            source="system_ai",
            reason="荤素搭配",
            preference="想吃面",
        )
        db.add(rec)
        db.flush()
        db.add(DailyRecommendationItem(
            recommendation_id=rec.id, recipe_id=recipe.id,
            sort_order=0, role="staple", reason="主食",
        ))
        db.commit()

        loaded = db.query(DailyRecommendation).filter(
            DailyRecommendation.id == rec.id
        ).one()
        assert loaded.refresh_count == 0
        assert len(loaded.items) == 1
        assert loaded.items[0].recipe_id == recipe.id
        assert loaded.items[0].role == "staple"
    finally:
        db.close()


def test_user_ai_settings_and_usage_events():
    Base.metadata.create_all(bind=engine)
    from app.models.user_ai_settings import UserAiSettings
    from app.models.ai_usage_event import AiUsageEvent

    db = TestingSessionLocal()
    try:
        db.add(UserAiSettings(
            user_id=FakeUser.id, method="user_ai", provider="openai",
            base_url="https://example.com/v1", api_key_enc="enc-secret",
            model="gpt-x", daily_ai_limit_override=3,
        ))
        db.add(AiUsageEvent(
            user_id=FakeUser.id, scope="meal_plan", method="system_ai",
            provider="claude_code", status="ok",
        ))
        db.commit()
        row = db.query(UserAiSettings).filter(
            UserAiSettings.user_id == FakeUser.id).one()
        assert row.method == "user_ai" and row.daily_ai_limit_override == 3
        assert db.query(AiUsageEvent).filter(
            AiUsageEvent.user_id == FakeUser.id).count() == 1
    finally:
        db.close()
