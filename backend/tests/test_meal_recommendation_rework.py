"""多道菜推荐重写（设计 §4）的端到端测试。

内存库 + 假 LLM（注入 complete callable）：
- 生成：每餐多道菜、≥1 staple、source/reason/preference 落库、响应兼容别名
- 规则降级：LLM 两次校验失败 → source=rule、fallback 事件
- 每日上限：system_ai 超限 → 直接规则
- 刷新：整餐重搭与单道换、refresh_count 真实计数（5 次上限）
- 去重放宽链：池不足时 7→3→0
"""
import datetime
import uuid

import pytest

from conftest import FakeUser, TestingSessionLocal, engine
from app.core.database import Base
from app.main import app
from app.api.deps import get_timezone
from app.models.user import User


@pytest.fixture(autouse=True)
def _ensure_timezone_override():
    """模块级时区覆盖会被其他测试文件 clear()（如 test_shared_data），
    每条用例前重装，保证组合执行顺序下行为一致。"""
    app.dependency_overrides[get_timezone] = lambda: "UTC"
    yield
    app.dependency_overrides[get_timezone] = lambda: "UTC"


def _seed_pool(db, per_category=2):
    """每分类建若干启用菜谱，返回 {(category): [recipe_ids]}。"""
    from app.models.recipe import Recipe

    suffix = uuid.uuid4().hex[:8]
    out = {}
    plan = [
        ("主食", 3), ("荤菜", 3), ("素菜", 2), ("水产", 1), ("汤与粥", 1),
        ("早餐", 2), ("甜品", 1), ("饮料", 1), ("调料", 1),
    ]
    for category, n in plan:
        ids = []
        for i in range(n):
            r = Recipe(
                name=f"{category}{i}_{suffix}", category=category,
                user_id=FakeUser.id, is_active=True, servings=1,
            )
            db.add(r)
            db.flush()
            ids.append(r.id)
        out[category] = ids
    db.commit()
    return out


def _cleanup_pool(pool):
    from app.models.recipe import Recipe
    from app.models.daily_recommendation import DailyRecommendation
    from app.models.daily_recommendation_item import DailyRecommendationItem

    ids = [rid for ids in pool.values() for rid in ids]
    db = TestingSessionLocal()
    try:
        db.query(DailyRecommendationItem).delete(synchronize_session=False)
        db.query(DailyRecommendation).delete(synchronize_session=False)
        db.query(Recipe).filter(Recipe.id.in_(ids)).delete(synchronize_session=False)
        db.commit()
    finally:
        db.close()


def _force_rule(monkeypatch):
    """测试强制走规则组合（否则默认 system_ai 会拉起真实 claude CLI 等 120s 超时）。"""
    from app.services import ai_policy as ap

    monkeypatch.setattr(ap, "resolve_ai_credentials",
                        lambda db, user, scope="meal_plan": {"method": "rule"})


def _use_memory_db_for_background(monkeypatch):
    """后台线程自建 SessionLocal；指向测试内存库，避免写到真实开发库。"""
    import app.core.database as core_db

    monkeypatch.setattr(core_db, "SessionLocal", TestingSessionLocal)
    db = TestingSessionLocal()
    try:
        from app.models.user import User
        from app.models.ai_usage_event import AiUsageEvent
        from app.models.user_ai_settings import UserAiSettings
        from app.models.daily_recommendation import DailyRecommendation
        from app.models.daily_recommendation_item import DailyRecommendationItem

        # 用量事件/用户 AI 设置跨测试共享内存库：清空本用户的，保证
        # 计数断言与凭据解析路径（fake LLM）不受其他用例残留影响
        db.query(AiUsageEvent).filter(AiUsageEvent.user_id == FakeUser.id).delete()
        db.query(UserAiSettings).filter(UserAiSettings.user_id == FakeUser.id).delete()
        # 批量 delete 不触发 ORM 级联：孤儿 item 必须显式清，
        # 否则 SQLite rowid 复用会让孤儿挂到新记录上（同餐重复菜假象）
        db.query(DailyRecommendationItem).delete()
        db.query(DailyRecommendation).filter(DailyRecommendation.user_id == FakeUser.id).delete()
        db.commit()
        if db.query(User).filter(User.id == FakeUser.id).first() is None:
            db.add(User(id=FakeUser.id, username="admin", email="a@b.c",
                        password_hash="x", is_admin=True, is_active=True))
            db.commit()
    finally:
        db.close()


def _ensure_user_row(db):
    from app.models.user import User

    if db.query(User).filter(User.id == FakeUser.id).first() is None:
        db.add(User(id=FakeUser.id, username="admin", email="a@b.c",
                    password_hash="x", is_admin=True, is_active=True))
        db.commit()


@pytest.fixture()
def _pool():
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        _ensure_user_row(db)
        pool = _seed_pool(db)
    finally:
        db.close()
    yield pool
    _cleanup_pool(pool)


def _fake_llm_by_category(monkeypatch):
    """注入假 LLM：按提示词候选生成「主食 staple + 一道主菜」的合法组合。"""
    import json as _json
    from app.services.meal_composer import LLMMealComposer
    from app.services import meal_recommender as mr

    async def fake_complete(system, user):
        candidates_start = user.index('"candidates"')
        candidates = _json.loads("{" + user[candidates_start:])
        by_cat = {}
        for c in candidates["candidates"]:
            by_cat.setdefault(c["category"], []).append(c)
        dishes = []
        if by_cat.get("主食"):
            dishes.append({"recipe_id": by_cat["主食"][0]["recipe_id"],
                           "role": "staple", "reason": "主食"})
        main_cat = next((c for c in ("水产", "荤菜", "素菜")
                         if by_cat.get(c) and by_cat[c][0]["recipe_id"] != dishes[0]["recipe_id"]), None)
        if main_cat:
            dishes.append({"recipe_id": by_cat[main_cat][0]["recipe_id"],
                           "role": "main", "reason": "主菜"})
        elif by_cat.get("早餐"):
            dishes.append({"recipe_id": by_cat["早餐"][0]["recipe_id"],
                           "role": "main", "reason": "早餐菜"})
        return _json.dumps({"dishes": dishes, "note": "假 LLM 组合"}, ensure_ascii=False)

    monkeypatch.setattr(mr, "_build_llm_composer",
                        lambda creds: LLMMealComposer(fake_complete))


def test_generate_multi_dish_with_fake_llm(as_admin, monkeypatch, _pool):
    """假 LLM 合法组合 → 落库 source=system_ai，响应含 dishes 与兼容 recipe。"""
    import asyncio
    from app.services import meal_recommender as mr

    _fake_llm_by_category(monkeypatch)
    _use_memory_db_for_background(monkeypatch)

    db = TestingSessionLocal()
    try:
        user = db.query(User).filter(User.id == FakeUser.id).first()
        result = asyncio.run(mr.generate_recommendations(
            db, user, "UTC", preference="想吃清淡"))
        assert result["status"] == "ready"
        by_meal = {r["meal_type"]: r for r in result["recommendations"]}
        for meal_type in ("breakfast", "lunch", "dinner"):
            rec = by_meal[meal_type]
            assert rec["dishes"], meal_type
            assert any(d["role"] == "staple" for d in rec["dishes"]), rec
            ids = [d["id"] for d in rec["dishes"]]
            assert len(ids) == len(set(ids))
            assert rec["source"] == "system_ai"
            assert rec["reason"] == "假 LLM 组合"
            staple = next(d for d in rec["dishes"] if d["role"] == "staple")
            # 兼容别名：recipe = staple 菜
            assert rec["recipe"]["id"] == staple["id"]
        assert by_meal["lunch"]["preference"] == "想吃清淡"
        assert result["totals"]["refresh_counts"] == {
            "breakfast": 0, "lunch": 0, "dinner": 0}

        from app.models.ai_usage_event import AiUsageEvent
        assert db.query(AiUsageEvent).filter(
            AiUsageEvent.user_id == FakeUser.id,
            AiUsageEvent.status == "ok").count() == 3
    finally:
        db.close()


def test_generate_falls_back_to_rule_on_bad_llm(as_admin, monkeypatch, _pool):
    """LLM 两次输出都非法 → 规则降级、source=rule、fallback 事件。"""
    import asyncio
    from app.services import meal_recommender as mr
    from app.services.meal_composer import LLMMealComposer

    async def bad_complete(system, user):
        return "这不是 JSON"

    monkeypatch.setattr(
        mr, "_build_llm_composer", lambda creds: LLMMealComposer(bad_complete))
    _use_memory_db_for_background(monkeypatch)

    db = TestingSessionLocal()
    try:
        user = db.query(User).filter(User.id == FakeUser.id).first()
        result = asyncio.run(mr.generate_recommendations(db, user, "UTC"))
        assert result["status"] == "ready"
        for rec in result["recommendations"]:
            assert rec["source"] == "rule"
            assert any(d["role"] == "staple" for d in rec["dishes"])
            # 规则组合不含甜品/饮料/调料
            assert all(d["category"] not in ("甜品", "饮料", "调料") for d in rec["dishes"])

        from app.models.ai_usage_event import AiUsageEvent
        assert db.query(AiUsageEvent).filter(
            AiUsageEvent.status == "fallback").count() == 3
    finally:
        db.close()


def test_refresh_count_limit_and_single_dish_swap(as_admin, monkeypatch, _pool):
    """refresh_count 真实计数：5 次后拒绝；单道换保持其它菜不变、staple 仍在。"""
    import asyncio
    from app.services import meal_recommender as mr

    _force_rule(monkeypatch)
    db = TestingSessionLocal()
    try:
        user = db.query(User).filter(User.id == FakeUser.id).first()
        first = asyncio.run(mr.generate_recommendations(db, user, "UTC"))
        assert first["status"] == "ready"
        lunch = {r["meal_type"]: r for r in first["recommendations"]}["lunch"]
        swap_target = next(d["id"] for d in lunch["dishes"] if d["role"] != "staple")
        staple_id = next(d["id"] for d in lunch["dishes"] if d["role"] == "staple")
        dish_count = len(lunch["dishes"])

        # 单道换：被换菜不在新组合、staple 不变、道数不变
        result, error = asyncio.run(mr.refresh_meal_recommendation(
            db, user, "lunch", "UTC", recipe_id=swap_target))
        assert error is None, error
        lunch2 = {r["meal_type"]: r for r in result["recommendations"]}["lunch"]
        new_ids = [d["id"] for d in lunch2["dishes"]]
        assert swap_target not in new_ids
        assert staple_id in new_ids
        assert len(new_ids) == dish_count
        assert lunch2["source"] == "rule"

        # refresh_count 真实计数：再整餐重搭 4 次后达到上限，第 6 次拒绝
        for i in range(4):
            result, error = asyncio.run(mr.refresh_meal_recommendation(
                db, user, "lunch", "UTC"))
            assert error is None, (i, error)
        result, error = asyncio.run(mr.refresh_meal_recommendation(
            db, user, "lunch", "UTC"))
        assert result is None and error is not None
        assert "5" in error and "刷新" in error

        # 其他餐不受影响：dinner 仍可刷新
        result, error = asyncio.run(mr.refresh_meal_recommendation(
            db, user, "dinner", "UTC"))
        assert error is None, error
    finally:
        db.close()


def test_dedup_widening_allows_reuse_when_pool_small(as_admin, monkeypatch, _pool):
    """7 天去重把池耗尽时放宽到 3/0 天，仍能出餐。"""
    import asyncio
    from app.services import meal_recommender as mr

    _force_rule(monkeypatch)
    db = TestingSessionLocal()
    try:
        user = db.query(User).filter(User.id == FakeUser.id).first()
        first = asyncio.run(mr.generate_recommendations(db, user, "UTC"))
        assert first["status"] == "ready"
        # 同日刷新不受「近 7 天已推荐」影响（放宽链兜底），整餐重搭仍可出餐
        result, error = asyncio.run(mr.refresh_meal_recommendation(db, user, "dinner", "UTC"))
        assert error is None, error
        assert result["status"] == "ready"
        dinner = {r["meal_type"]: r for r in result["recommendations"]}["dinner"]
        assert dinner["dishes"]
        assert any(d["role"] == "staple" for d in dinner["dishes"])
    finally:
        db.close()
