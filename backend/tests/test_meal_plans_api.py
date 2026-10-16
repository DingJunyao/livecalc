"""试算方案（阶段 3）端到端测试：CRUD / evaluate / cost-trend / set-plan。"""
import datetime
import uuid

from conftest import FakeUser, TestingSessionLocal, engine
from app.core.database import Base
from app.models.user import User


def _seed_recipe(db, count=1):
    from app.models.recipe import Recipe

    ids = []
    for i in range(count):
        r = Recipe(name=f"试算菜谱_{uuid.uuid4().hex[:8]}_{i}", category="主食",
                   user_id=FakeUser.id, is_active=True, servings=1)
        db.add(r)
        db.flush()
        ids.append(r.id)
    db.commit()
    return ids[0]


def _cleanup_recipe(recipe_id):
    from app.models.recipe import Recipe
    from app.models.meal_plan import MealPlan, MealPlanItem
    from app.models.daily_recommendation import DailyRecommendation

    db = TestingSessionLocal()
    try:
        db.query(DailyRecommendation).delete(synchronize_session=False)
        db.query(MealPlanItem).delete(synchronize_session=False)
        db.query(MealPlan).delete(synchronize_session=False)
        db.query(Recipe).filter(Recipe.id == recipe_id).delete(synchronize_session=False)
        db.commit()
    finally:
        db.close()


def test_plan_crud_and_evaluate(as_admin):
    from starlette.testclient import TestClient
    from app.main import app

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        recipe_id = _seed_recipe(db)
    finally:
        db.close()

    client = TestClient(app)
    try:
        # 创建
        resp = client.post("/api/v1/meal-plans", json={
            "name": "一人食晚餐", "kind": "meal",
            "items": [
                {"group": "dinner", "item_type": "recipe",
                 "recipe_id": recipe_id, "servings": 2, "sort_order": 0},
            ],
        })
        assert resp.status_code == 200, resp.text
        plan = resp.json()
        assert plan["kind"] == "meal"
        assert len(plan["items"]) == 1
        assert plan["items"][0]["name"].startswith("试算菜谱")
        plan_id = plan["id"]

        # 列表
        resp = client.get("/api/v1/meal-plans")
        assert any(p["id"] == plan_id for p in resp.json()["items"])

        # 草稿 evaluate（不落库）
        resp = client.post("/api/v1/meal-plans/evaluate", json={
            "kind": "meal", "meal_type": "dinner",
            "items": [
                {"group": "dinner", "item_type": "recipe",
                 "recipe_id": recipe_id, "servings": 2},
            ],
        })
        assert resp.status_code == 200, resp.text
        payload = resp.json()
        assert payload["items"][0]["item_type"] == "recipe"
        assert "totals" in payload and "targets" in payload and "deltas" in payload
        # meal 目标 = 每日目标 × 0.35（dinner）
        assert abs(payload["targets"]["calories"] - 2000 * 0.35) < 1

        # 三选一校验：坏条目 400
        resp = client.post("/api/v1/meal-plans", json={
            "name": "坏方案", "kind": "meal",
            "items": [{"group": "other", "item_type": "recipe"}],
        })
        assert resp.status_code == 400, resp.text

        # cost-trend（无价格记录 → 逐日 0 值但结构正确）
        resp = client.get(f"/api/v1/meal-plans/{plan_id}/cost-trend", params={"days": 7})
        assert resp.status_code == 200, resp.text
        trend = resp.json()
        assert len(trend) == 7
        assert {"date", "total_cost", "currency"} <= set(trend[0].keys())

        # 软删
        resp = client.delete(f"/api/v1/meal-plans/{plan_id}")
        assert resp.status_code == 200
        resp = client.get(f"/api/v1/meal-plans/{plan_id}")
        assert resp.status_code == 404
    finally:
        _cleanup_recipe(recipe_id)


def _use_memory_db_for_background(monkeypatch=None):
    """后台线程指向内存库；并强制走规则组合（避免默认 system_ai 拉起真实 CLI）。"""
    from app.services import ai_policy as ap

    if monkeypatch is not None:
        monkeypatch.setattr(
            ap, "resolve_ai_credentials",
            lambda db_, user_, scope="meal_plan": {"method": "rule"})
    else:
        ap.resolve_ai_credentials = lambda db_, user_, scope="meal_plan": {"method": "rule"}
    import app.core.database as core_db
    core_db.SessionLocal = TestingSessionLocal
    db = TestingSessionLocal()
    try:
        if db.query(User).filter(User.id == FakeUser.id).first() is None:
            db.add(User(id=FakeUser.id, username="admin", email="a@b.c",
                        password_hash="x", is_admin=True, is_active=True))
            db.commit()
    finally:
        db.close()


def test_set_plan_and_refresh_flips_source(as_admin, monkeypatch):
    """方案设为今日一餐 → source=plan + plan 渲染；换整餐翻回规则。"""
    import asyncio
    import json as _json
    from starlette.testclient import TestClient
    from app.main import app
    from app.services import meal_recommender as mr

    Base.metadata.create_all(bind=engine)
    from app.services.meal_composer import LLMMealComposer

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
        return _json.dumps({"dishes": dishes, "note": "AI"}, ensure_ascii=False)

    mr._build_llm_composer = lambda creds: LLMMealComposer(fake_complete)
    _use_memory_db_for_background(monkeypatch)

    db = TestingSessionLocal()
    try:
        recipe_id = _seed_recipe(db)
        _seed_recipe(db, count=3)  # 三餐都要主食可配
        user = db.query(User).filter(User.id == FakeUser.id).first()
        # 先生成今日推荐（规则路径，快）
        from app.services import ai_policy as ap

        original_resolve = ap.resolve_ai_credentials
        ap.resolve_ai_credentials = lambda db_, user_, scope="meal_plan": {"method": "rule"}
        try:
            result = asyncio.run(mr.generate_recommendations(db, user, "UTC"))
        finally:
            ap.resolve_ai_credentials = original_resolve
        assert result["status"] == "ready"
    finally:
        db.close()

    client = TestClient(app)
    try:
        # 创建方案并设为今日一餐
        resp = client.post("/api/v1/meal-plans", json={
            "name": "方案晚餐", "kind": "meal",
            "items": [{"group": "dinner", "item_type": "recipe",
                       "recipe_id": recipe_id, "servings": 1}],
        })
        plan_id = resp.json()["id"]

        resp = client.post("/api/v1/meals/recommendations/set-plan", json={
            "plan_id": plan_id, "meal_type": "dinner"})
        assert resp.status_code == 200, resp.text
        dinner = {r["meal_type"]: r for r in resp.json()["recommendations"]}["dinner"]
        assert dinner["source"] == "plan"
        assert dinner["plan"]["id"] == plan_id
        assert dinner["plan"]["name"] == "方案晚餐"
        assert any(it["item_type"] == "recipe" for it in dinner["plan"]["items"])

        # 换整餐 → 翻回规则来源（服务层直调，避免后台线程会话竞态）
        import asyncio
        db = TestingSessionLocal()
        try:
            user = db.query(User).filter(User.id == FakeUser.id).first()
            result, error = asyncio.run(mr.refresh_meal_recommendation(
                db, user, "dinner", "UTC"))
            assert error is None, error
        finally:
            db.close()
        payload = client.get("/api/v1/meals/recommendations").json()
        dinner = {r["meal_type"]: r for r in payload["recommendations"]}["dinner"]
        assert dinner["source"] in ("rule", "system_ai", "user_ai")
        assert dinner["plan"] is None
    finally:
        _cleanup_recipe(recipe_id)


def _ensure_fake_user(db):
    from app.models.user import User

    if db.query(User).filter(User.id == FakeUser.id).first() is None:
        db.add(User(id=FakeUser.id, username="probe_admin", email="probe@example.com",
                    password_hash="x", is_admin=True, is_active=True))
        db.commit()


def test_evaluate_awaits_async_recipe_engines(as_admin, monkeypatch):
    """回归：菜谱成本/营养引擎是 async def，试算必须 await。

    未 await 时拿到的是 coroutine → `cost.get(...)` 抛 AttributeError → 被
    `except Exception` 静默吞掉 → item.cost / nutrition 全 None →「合计 vs 目标」恒为 0。
    这里用假引擎把「必须 await」钉死：一旦退回同步调用，合计就会变成 0。
    """
    from starlette.testclient import TestClient
    from app.main import app
    from app.services import meal_plan_service as mps

    async def fake_cost(recipe_id, user_id, db=None, **kwargs):
        return {"total_cost": 25.0, "currency": "CNY", "cost_per_serving": 12.5}

    async def fake_nutrition(recipe_id, db=None, **kwargs):
        return {"per_serving": {"calories": 300.0, "protein": 10.0,
                                "carbs": 40.0, "fat": 5.0}}

    monkeypatch.setattr(mps, "calculate_recipe_cost", fake_cost)
    monkeypatch.setattr(mps, "calculate_recipe_nutrition", fake_nutrition)

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        recipe_id = _seed_recipe(db)
    finally:
        db.close()

    client = TestClient(app)
    try:
        resp = client.post("/api/v1/meal-plans/evaluate", json={
            "kind": "meal", "meal_type": "dinner",
            "items": [{"group": "dinner", "item_type": "recipe",
                       "recipe_id": recipe_id, "servings": 2}],
        })
        assert resp.status_code == 200, resp.text
        payload = resp.json()
        assert payload["items"][0]["cost"] == 12.5
        assert payload["items"][0]["nutrition"]["calories"] == 300.0
        # 合计必须跟着走（未 await 时会退化成 0）
        assert payload["totals"]["cost"] == 12.5
        assert payload["totals"]["calories"] == 300.0
        assert payload["totals"]["protein_g"] == 10.0
    finally:
        _cleanup_recipe(recipe_id)


def test_recipe_cost_per_serving_accepts_float_servings_override(as_admin):
    """回归：servings_override 传 float（试算页传 float(servings)）时，
    Decimal 总价 / float 会抛 TypeError（recipe_service.calculate_recipe_cost 末尾的 cost_per_serving）。"""
    import asyncio
    from app.services.recipe_service import calculate_recipe_cost

    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        _ensure_fake_user(db)
        recipe_id = _seed_recipe(db)
        result = asyncio.run(calculate_recipe_cost(
            recipe_id, FakeUser.id, db, servings_override=2.0,
        ))
    finally:
        db.close()
    try:
        assert result is not None
        assert float(result["cost_per_serving"]) == 0.0
        assert float(result["total_cost"]) == 0.0
    finally:
        _cleanup_recipe(recipe_id)
