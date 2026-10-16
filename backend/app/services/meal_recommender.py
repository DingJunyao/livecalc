"""
每日饮食推荐服务（多道菜套餐，设计 §4）

流程：候选池（分类口径 + 黑名单 + 近 7 天去重，池不足逐级放宽）→ 确定性打分
（营养/成本 + 收藏加权）→ 分类 top-K 短名单 → 组合层（LLM 优先、规则降级，
见 meal_composer.py）→ 落库（父表 + items 子表）→ 响应。

响应向后兼容：recommendations[].recipe 取 staple（无则首道）菜，新增 dishes 数组。
刷新：整餐重搭 + 单道换（recipe_id），refresh_count 支撑每餐每天 5 次上限
（修复旧「行数-1」口径从未生效的 bug）。
"""
import asyncio
import datetime
import logging
import random
import threading
from typing import Dict, List, Optional, Set, Tuple
from app.utils.date_range_utils import utc_datetime_to_local_date, _zone

from sqlalchemy.orm import Session, joinedload

from app.models.user import User
from app.models.recipe import Recipe
from app.models.daily_recommendation import DailyRecommendation
from app.models.daily_recommendation_item import DailyRecommendationItem
from app.services.recipe_service import calculate_recipe_cost, calculate_recipe_nutrition
from app.services import ai_policy
from app.services.meal_plan_service import evaluate_plan
from app.services.meal_composer import (
    LLMMealComposer,
    RuleMealComposer,
)

logger = logging.getLogger("meal_recommender")

# 后台生成追踪：记录哪些用户正在生成推荐
_generating_users: Set[int] = set()
_generation_lock = threading.Lock()

# 后台刷新追踪：记录哪些用户正在刷新某一餐
_refreshing_meals: Dict[int, Set[str]] = {}
_refresh_lock = threading.Lock()

# 三餐营养占比
MEAL_RATIOS = {
    "breakfast": 0.25,
    "lunch": 0.40,
    "dinner": 0.35,
}

# 每餐每天最大刷新次数
MAX_REFRESH_PER_MEAL = 5

# 候选池分类口径（设计 §4.1）：甜品/饮料/调料/半成品不再进正餐池
MEAL_POOL_CATEGORIES: Dict[str, Tuple[str, ...]] = {
    "breakfast": ("早餐", "主食", "汤与粥"),
    "lunch": ("主食", "荤菜", "素菜", "水产", "汤与粥"),
    "dinner": ("主食", "荤菜", "素菜", "水产", "汤与粥"),
}

# 短名单每分类 top-K（设计 §4.2）
_SHORTLIST_TOP_K: Dict[str, Dict[str, int]] = {
    "breakfast": {"早餐": 8, "主食": 6, "汤与粥": 4},
    "lunch": {"主食": 8, "荤菜": 6, "素菜": 6, "水产": 4, "汤与粥": 4},
    "dinner": {"主食": 8, "荤菜": 6, "素菜": 6, "水产": 4, "汤与粥": 4},
}

# 历史去重窗口放宽链（设计 §4.1）
_DEDUP_WINDOW_CHAIN = (7, 3, 0)


def _get_meal_targets(user: User, meal_type: str) -> Dict[str, float]:
    """根据用户目标和三餐占比计算某餐的期望值。"""
    ratio = MEAL_RATIOS[meal_type]
    return {
        "calories": (user.daily_calorie_target or 2000) * ratio,
        "protein": (user.daily_protein_target or 60) * ratio,
        "carbs": (user.daily_carb_target or 300) * ratio,
        "fat": (user.daily_fat_target or 65) * ratio,
    }


def _calc_nutrition_score(nutrition: Optional[Dict], targets: Dict[str, float]) -> float:
    """
    计算营养得分 [0, 1]。

    对热量/蛋白质/碳水/脂肪四项，每项计算：
      偏差 = 1 - |实际值 - 期望值| / max(期望值, 1)
    返回四项偏差的平均值。
    """
    if not nutrition:
        return 0.0

    per_serving = nutrition.get("per_serving", {})
    if not per_serving:
        return 0.0

    actual = {
        "calories": float(per_serving.get("calories", 0) or 0),
        "protein": float(per_serving.get("protein", 0) or 0),
        "carbs": float(per_serving.get("carbs", 0) or 0),
        "fat": float(per_serving.get("fat", 0) or 0),
    }

    deviations = []
    for key in ["calories", "protein", "carbs", "fat"]:
        target = targets[key]
        actual_val = actual[key]
        max_val = max(target, 1.0)
        dev = 1.0 - min(abs(actual_val - target) / max_val, 1.0)
        deviations.append(max(dev, 0.0))

    return sum(deviations) / len(deviations)


def _calc_cost_score(cost_data: Optional[Dict], user: User, meal_type: str) -> float:
    """
    计算成本得分 [0, 1]。

    cost_score = 1 - min(recipe_cost / meal_budget, 1)
    daily_budget 为 None 时返回 0.5（中性分）。
    """
    if user.daily_budget is None or user.daily_budget <= 0:
        return 0.5

    meal_budget = user.daily_budget * MEAL_RATIOS[meal_type]
    if meal_budget <= 0:
        return 0.0

    cost_per_serving = float((cost_data or {}).get("cost_per_serving", 0) or 0)
    if cost_per_serving <= 0:
        return 1.0

    return 1.0 - min(cost_per_serving / meal_budget, 1.0)


def _get_favorite_recipe_ids(db: Session, user_id: int) -> Set[int]:
    """收藏的菜谱 id（偏好信号：短名单加权 + AI 提示标注）。"""
    from app.models.user_favorite import UserFavorite

    rows = db.query(UserFavorite.entity_id).filter(
        UserFavorite.user_id == user_id,
        UserFavorite.entity_type == "recipe",
    ).all()
    return {r[0] for r in rows}


def _recently_recommended(
    db: Session, user_id: int, today: datetime.date, days: int
) -> Tuple[Set[int], List[str]]:
    """近 N 天推荐过的菜谱（跨餐次）。返回 (ids, 名字清单供提示词)。"""
    if days <= 0:
        return set(), []
    start = today - datetime.timedelta(days=days - 1)
    rows = (
        db.query(DailyRecommendationItem.recipe_id, Recipe.name)
        .join(DailyRecommendation,
              DailyRecommendationItem.recommendation_id == DailyRecommendation.id)
        .join(Recipe, DailyRecommendationItem.recipe_id == Recipe.id)
        .filter(
            DailyRecommendation.user_id == user_id,
            DailyRecommendation.date >= start,
            DailyRecommendation.date <= today,
        )
        .all()
    )
    ids = {r[0] for r in rows}
    names = [r[1] for r in rows if r[1]]
    return ids, names


def _get_candidate_pool(
    db: Session,
    meal_type: str,
    exclude_recipe_ids: Optional[Set[int]] = None,
    user_id: Optional[int] = None,
    recent_ids: Optional[Set[int]] = None,
) -> List[Recipe]:
    """
    获取某餐类的候选菜谱池。

    规则：
    - 分类口径见 MEAL_POOL_CATEGORIES
    - is_active == True
    - 排除 exclude_recipe_ids（本餐/他餐已选）
    - 排除 recent_ids（近 7 天已推荐，放宽链由调用方控制）
    - 排除用户黑名单中原料对应的菜谱（手动 + 分组订阅）
    """
    query = db.query(Recipe).filter(
        Recipe.is_active == True,
        Recipe.category.in_(MEAL_POOL_CATEGORIES.get(meal_type, ())),
    )

    if exclude_recipe_ids:
        query = query.filter(~Recipe.id.in_(exclude_recipe_ids))
    if recent_ids:
        query = query.filter(~Recipe.id.in_(recent_ids))

    if user_id is not None:
        from app.api.blacklist import _get_effective_blacklist_ids
        from app.models.recipe import RecipeIngredient

        blacklisted_ids = _get_effective_blacklist_ids(db, user_id)

        if blacklisted_ids:
            excluded_recipes = db.query(RecipeIngredient.recipe_id).filter(
                RecipeIngredient.ingredient_id.in_(blacklisted_ids),
            ).distinct().all()
            excluded_set = {r[0] for r in excluded_recipes}
            if excluded_set:
                query = query.filter(~Recipe.id.in_(excluded_set))

    return query.all()


async def _score_recipe(
    db: Session,
    user: User,
    recipe: Recipe,
    meal_type: str,
    targets: Dict[str, float],
    favorite_ids: Optional[Set[int]] = None,
) -> Tuple[float, Optional[Dict], Optional[Dict]]:
    """对单个菜谱打分，返回 (score, nutrition_data, cost_data)。收藏 +0.1（封顶 1.0）。"""
    nutrition = None
    cost = None

    try:
        nutrition = await calculate_recipe_nutrition(recipe.id, db=db)
    except Exception:
        logger.debug(f"菜谱 {recipe.id} ({recipe.name}) 营养计算失败", exc_info=True)

    try:
        cost = await calculate_recipe_cost(recipe.id, user.id, db=db)
    except Exception:
        logger.debug(f"菜谱 {recipe.id} ({recipe.name}) 成本计算失败", exc_info=True)

    if nutrition is None and cost is None:
        return (0.0, None, None)

    n_score = _calc_nutrition_score(nutrition, targets) if nutrition else 0.0
    c_score = _calc_cost_score(cost, user, meal_type) if cost else 0.5
    score = min(1.0, n_score * 0.5 + c_score * 0.5)
    if favorite_ids and recipe.id in favorite_ids:
        score = min(1.0, score + 0.1)

    return (score, nutrition, cost)


async def _build_shortlist(
    db: Session,
    user: User,
    meal_type: str,
    exclude_ids: Set[int],
    favorite_ids: Set[int],
    recent_ids: Set[int],
) -> List[dict]:
    """打分候选池并按分类取 top-K 短名单（确定性层，设计 §4.2）。"""
    candidates = _get_candidate_pool(
        db, meal_type, exclude_recipe_ids=exclude_ids, user_id=user.id,
        recent_ids=recent_ids,
    )
    # 释放候选池查询的读事务（SQLite 写锁纪律，见历史注释）
    db.rollback()
    if not candidates:
        return []

    targets = _get_meal_targets(user, meal_type)
    scored: List[Tuple[Recipe, float, Optional[Dict], Optional[Dict]]] = []
    for recipe in candidates:
        score, nutrition, cost = await _score_recipe(
            db, user, recipe, meal_type, targets, favorite_ids,
        )
        scored.append((recipe, score, nutrition, cost))
        # 每个候选打分后释放读事务（避免长读事务阻塞并发写）
        db.rollback()

    by_cat: Dict[str, List[Tuple[Recipe, float]]] = {}
    for recipe, score, _n, _c in scored:
        by_cat.setdefault(recipe.category or "", []).append((recipe, score))

    shortlist: List[dict] = []
    for cat, top_k in _SHORTLIST_TOP_K.get(meal_type, {}).items():
        ranked = sorted(by_cat.get(cat, []), key=lambda p: p[1], reverse=True)[:top_k]
        for recipe, score in ranked:
            match = next((s for s in scored if s[0].id == recipe.id), None)
            nutrition = match[2] if match else None
            cost = match[3] if match else None
            shortlist.append(_build_shortlist_entry(recipe, score, nutrition, cost, favorite_ids))

    # 保底：分类键不齐（如库中无水产）导致短名单为空时，取全局最高分兜底
    if not shortlist and scored:
        recipe, score, nutrition, cost = max(scored, key=lambda p: p[1])
        shortlist.append(_build_shortlist_entry(recipe, score, nutrition, cost, favorite_ids))
    return shortlist


def _build_shortlist_entry(
    recipe: Recipe, score: float, nutrition: Optional[Dict],
    cost: Optional[Dict], favorite_ids: Set[int],
) -> dict:
    per_serving = (nutrition or {}).get("per_serving") or {}
    return {
        "id": recipe.id,
        "name": recipe.name,
        "category": recipe.category,
        "score": round(score, 4),
        "cost_estimate": round(float((cost or {}).get("cost_per_serving", 0) or 0), 2),
        "currency": (cost or {}).get("currency"),
        "nutrition_per_serving": {
            "calories": round(float(per_serving.get("calories", 0) or 0), 1),
            "protein_g": round(float(per_serving.get("protein", 0) or 0), 1),
            "carbs_g": round(float(per_serving.get("carbs", 0) or 0), 1),
            "fat_g": round(float(per_serving.get("fat", 0) or 0), 1),
        },
        "total_time_minutes": recipe.total_time_minutes,
        "is_favorite": recipe.id in favorite_ids,
        "has_favorite_ingredient": False,  # 由 _attach_shortlist_extras 填充
        "top_ingredients": [],  # 由 _attach_shortlist_extras 填充
    }


def _attach_shortlist_extras(db: Session, shortlist: List[dict], user_id: int) -> None:
    """填充 top_ingredients 与 has_favorite_ingredient（两次批查询）。"""
    ids = [d["id"] for d in shortlist]
    if not ids:
        return
    from app.models.recipe import RecipeIngredient
    from app.models.nutrition import Ingredient
    from app.models.user_favorite import UserFavorite

    rows = (
        db.query(RecipeIngredient.recipe_id, Ingredient.name)
        .join(Ingredient, RecipeIngredient.ingredient_id == Ingredient.id)
        .filter(RecipeIngredient.recipe_id.in_(ids))
        .all()
    )
    by_recipe: Dict[int, List[str]] = {}
    recipe_ingredients: Dict[int, List[int]] = {}
    for rid, name in rows:
        if name:
            by_recipe.setdefault(rid, []).append(name)

    fav_ing_rows = (
        db.query(UserFavorite.entity_id).filter(
            UserFavorite.user_id == user_id,
            UserFavorite.entity_type == "ingredient",
        ).all()
    )
    favorite_ingredient_ids = {r[0] for r in fav_ing_rows}
    if favorite_ingredient_ids:
        ri_rows = (
            db.query(RecipeIngredient.recipe_id, RecipeIngredient.ingredient_id)
            .filter(RecipeIngredient.recipe_id.in_(ids))
            .all()
        )
        for rid, iid in ri_rows:
            recipe_ingredients.setdefault(rid, []).append(iid)

    for d in shortlist:
        d["top_ingredients"] = by_recipe.get(d["id"], [])[:5]
        d["has_favorite_ingredient"] = any(
            iid in favorite_ingredient_ids
            for iid in recipe_ingredients.get(d["id"], [])
        )


def _build_recipe_brief(
    recipe: Recipe, nutrition: Optional[Dict], cost: Optional[Dict]
) -> Dict:
    """构建菜谱简要信息 dict。"""
    from app.services.storage import get_storage

    images_list = recipe.images or []
    brief = {
        "id": recipe.id,
        "name": recipe.name,
        "category": recipe.category,
        "images": images_list,
        "image_urls": [get_storage().url_for(img[len('/static/images/'):] if img.startswith('/static/images/') else img) for img in images_list] if images_list else None,
        "servings": recipe.servings or 1,
    }

    if cost:
        brief["cost_estimate"] = round(float(cost.get("cost_per_serving", 0) or 0), 2)
        brief["currency"] = cost.get("currency")
    else:
        brief["cost_estimate"] = None
        brief["currency"] = None

    if nutrition:
        per_serving = nutrition.get("per_serving", {})
        brief["nutrition_per_serving"] = {
            "calories": round(float(per_serving.get("calories", 0) or 0), 1),
            "protein_g": round(float(per_serving.get("protein", 0) or 0), 1),
            "carbs_g": round(float(per_serving.get("carbs", 0) or 0), 1),
            "fat_g": round(float(per_serving.get("fat", 0) or 0), 1),
        }
    else:
        brief["nutrition_per_serving"] = None

    return brief


def _count_today_refreshes(
    db: Session, user_id: int, today: datetime.date
) -> Dict[str, int]:
    """查询今天各餐已刷新次数（读 refresh_count 列；首次生成不算刷新）。"""
    rows = (
        db.query(DailyRecommendation.meal_type, DailyRecommendation.refresh_count)
        .filter(
            DailyRecommendation.user_id == user_id,
            DailyRecommendation.date == today,
        )
        .all()
    )
    counts = {"breakfast": 0, "lunch": 0, "dinner": 0}
    for meal_type, cnt in rows:
        counts[meal_type] = int(cnt or 0)
    return counts


def _get_current_meal(hour: int) -> Optional[str]:
    """根据当前小时判断对应餐类。"""
    if 5 <= hour < 10:
        return "breakfast"
    elif 10 <= hour < 14:
        return "lunch"
    elif 14 <= hour < 22:
        return "dinner"
    return None


# ============ 组合（短名单 → LLM/规则 → ComposedMeal） ============

def _build_llm_composer(creds: dict) -> Optional[LLMMealComposer]:
    """按策略凭据构造 LLM composer；provider 不在 AI 白名单时返回 None（走规则）。"""
    provider = creds.get("provider")
    if provider not in ("openai", "anthropic", "claude_code", "codex"):
        return None
    from app.services.translate.registry import get_translator

    timeout = int(creds.get("timeout") or 120)
    translator = get_translator(provider, creds.get("section") or {}, timeout)

    async def complete(system: str, user: str) -> str:
        results = await asyncio.wait_for(
            translator.translate_batch([user], system_prompt=system),
            timeout=timeout + 5,
        )
        return results[0] if results else ""

    return LLMMealComposer(complete)


async def _compose_for_meal(
    db: Session,
    user: User,
    meal_type: str,
    exclude_ids: Set[int],
    today: datetime.date,
    preference: Optional[str],
    lang: str,
    single_role: Optional[str] = None,
    favorite_ids: Optional[Set[int]] = None,
) -> Tuple[Optional[Dict], bool]:
    """组合一餐。返回 ({"shortlist":…, "composed":…}, limit_reached)。

    含策略集成：system_ai 每日上限 → 直接规则（limit_reached=True 供文案）；
    LLM 调用记用量事件（ok/fallback/error）。
    """
    if favorite_ids is None:
        favorite_ids = _get_favorite_recipe_ids(db, user.id)

    # 去重放宽链：7 → 3 → 0，取首个非空短名单
    shortlist: List[dict] = []
    recent_names: List[str] = []
    recent_ids: Set[int] = set()
    for window in _DEDUP_WINDOW_CHAIN:
        recent_ids, recent_names = _recently_recommended(db, user.id, today, window)
        shortlist = await _build_shortlist(
            db, user, meal_type, exclude_ids, favorite_ids, recent_ids - exclude_ids,
        )
        db.rollback()
        if shortlist:
            break
    if not shortlist:
        return None, False

    _attach_shortlist_extras(db, shortlist, user.id)
    db.rollback()

    targets = _get_meal_targets(user, meal_type)
    budget = (
        float(user.daily_budget) * MEAL_RATIOS[meal_type]
        if user.daily_budget else None
    )
    excluded_names = [
        r[0] for r in db.query(Recipe.name).filter(Recipe.id.in_(exclude_ids)).all()
    ] if exclude_ids else []
    db.rollback()

    llm = None
    method = "rule"
    provider = None
    creds = ai_policy.resolve_ai_credentials(db, user)
    if creds["method"] in ("system_ai", "user_ai"):
        if creds["method"] == "system_ai" and ai_policy.system_ai_limit_reached(db, user):
            method = "rule"
        else:
            llm = _build_llm_composer(creds)
            if llm is None:
                method = "rule"
            else:
                method, provider = creds["method"], creds["provider"]

    composed = None
    if llm is not None:
        try:
            composed = await llm.compose(
                shortlist, meal_type, exclude_ids=exclude_ids,
                targets=targets, budget=budget,
                excluded_names=excluded_names, recent_names=recent_names,
                preference=preference, lang=lang, single_role=single_role,
            )
        except Exception:
            logger.warning(f"{meal_type} LLM 组合异常，降级规则", exc_info=True)
            composed = None
        if composed is not None and composed.dishes:
            composed.source = method
            ai_policy.record_usage(db, user.id, "meal_plan", method, provider, "ok")
        else:
            ai_policy.record_usage(db, user.id, "meal_plan", method, provider, "fallback")
            composed = None
    if composed is None or not composed.dishes:
        # 规则降级：source 保持 rule；limit_reached 或 LLM 不可用时给出文案
        composed = RuleMealComposer.compose(
            shortlist, meal_type, exclude_ids=exclude_ids, single_role=single_role,
        )
        if llm is not None or method == "rule":
            composed.note = composed.note or "按营养与成本目标规则组合"

    return {"shortlist": shortlist, "composed": composed}, False


def _persist_meal(
    db: Session, user_id: int, today: datetime.date, meal_type: str,
    composed, preference: Optional[str],
) -> DailyRecommendation:
    """写父行 + items（调用方负责 commit）。"""
    import os
    if os.environ.get("MEAL_DEBUG"):
        print(f"[persist] {meal_type} source={composed.source} dishes={[d.recipe_id for d in composed.dishes]}", flush=True)
    record = DailyRecommendation(
        user_id=user_id,
        date=today,
        meal_type=meal_type,
        source=composed.source,
        reason=composed.note,
        preference=preference,
        refresh_count=0,
    )
    db.add(record)
    db.flush()
    for order, dish in enumerate(composed.dishes):
        db.add(DailyRecommendationItem(
            recommendation_id=record.id,
            recipe_id=dish.recipe_id,
            sort_order=order,
            role=dish.role,
            reason=dish.reason,
        ))
    return record


def _meal_record_recipe_ids(record: DailyRecommendation) -> Set[int]:
    return {item.recipe_id for item in record.items}


async def _build_response_from_records(
    db: Session, records: List[DailyRecommendation], user: User,
    refreshing_meals: Optional[List[str]] = None,
    tz: str = "UTC",
) -> Dict:
    """从 daily_recommendations（含 items）构建完整响应。"""
    now = datetime.datetime.now(_zone(tz))
    current_meal = _get_current_meal(now.hour)
    today = utc_datetime_to_local_date(datetime.datetime.now(datetime.timezone.utc), tz)

    refresh_counts = _count_today_refreshes(db, user.id, today)

    # 黑名单兜底：任一道菜命中黑名单 → 该餐整餐后台重搭
    from app.api.blacklist import _get_effective_blacklist_ids
    from app.models.recipe import RecipeIngredient

    blacklisted_ids = _get_effective_blacklist_ids(db, user.id)
    blocked_recipe_ids: set[int] = set()
    if blacklisted_ids:
        record_recipe_ids = {
            item.recipe_id for r in records for item in r.items
        }
        if record_recipe_ids:
            blocked_recipe_ids = set(
                r[0] for r in db.query(RecipeIngredient.recipe_id).filter(
                    RecipeIngredient.recipe_id.in_(record_recipe_ids),
                    RecipeIngredient.ingredient_id.in_(blacklisted_ids),
                ).distinct().all()
            )
    if blocked_recipe_ids:
        blocked_meal_types = {
            r.meal_type for r in records
            if any(item.recipe_id in blocked_recipe_ids for item in r.items)
        }
        for mt in blocked_meal_types:
            trigger_background_refresh(user.id, mt)
        refreshing_meals = list(set((refreshing_meals or []) + list(blocked_meal_types)))

    rec_map = {r.meal_type: r for r in records}
    recommendations = []
    totals = {
        "cost": 0.0,
        "currency": None,
        "calories": 0.0,
        "protein_g": 0.0,
        "carbs_g": 0.0,
        "fat_g": 0.0,
    }

    for meal_type in ["breakfast", "lunch", "dinner"]:
        record = rec_map.get(meal_type)
        base_item = {
            "meal_type": meal_type,
            "recipe": None,
            "dishes": [],
            "source": record.source if record else None,
            "reason": record.reason if record else None,
            "preference": record.preference if record else None,
            "plan": None,
            "is_current_meal": (meal_type == current_meal),
        }

        # 方案来源餐（source='plan'）：渲染方案视图（方案名 + 条目明细）
        if record is not None and record.source == "plan" and record.plan_id:
            from app.services.meal_plan_service import evaluate_plan

            plan = record.plan
            if plan is not None and plan.is_active:
                # 一日方案按该餐的分组只取对应条目（否则三餐都会塞进整个方案）
                evaluation = await evaluate_plan(db, user, plan, tz=tz, group=meal_type)
                base_item["plan"] = {
                    "id": plan.id,
                    "name": plan.name,
                    "kind": plan.kind,
                    "note": plan.note,
                    "items": [
                        {
                            "item_type": it["item_type"],
                            "name": it.get("name"),
                            "group": it.get("group"),
                            "servings": it.get("servings"),
                            "quantity": it.get("quantity"),
                            "unit": it.get("unit"),
                            "cost": it.get("cost"),
                        }
                        for it in evaluation["items"]
                    ],
                    "totals": evaluation["totals"],
                }
                totals["cost"] = round(totals["cost"] + evaluation["totals"]["cost"], 2)
                if evaluation["totals"].get("currency"):
                    totals["currency"] = evaluation["totals"]["currency"] or totals["currency"]
                for key in ("calories", "protein_g", "carbs_g", "fat_g"):
                    totals[key] = round(
                        totals[key] + float(evaluation["totals"].get(key, 0) or 0), 2)
                recommendations.append(base_item)
                continue

        visible_items = [
            item for item in (record.items if record else [])
            if item.recipe_id not in blocked_recipe_ids
        ]
        if record and visible_items and len(visible_items) == len(record.items):
            dishes = []
            for item in record.items:
                recipe = item.recipe
                if recipe is None:
                    continue
                try:
                    nutrition = await calculate_recipe_nutrition(recipe.id, db=db)
                except Exception:
                    logger.debug(f"响应构建：菜谱 {recipe.id} 营养计算失败", exc_info=True)
                    nutrition = None
                try:
                    cost = await calculate_recipe_cost(recipe.id, user.id, db=db)
                except Exception:
                    logger.debug(f"响应构建：菜谱 {recipe.id} 成本计算失败", exc_info=True)
                    cost = None
                brief = _build_recipe_brief(recipe, nutrition, cost)
                dishes.append({**brief, "role": item.role, "reason": item.reason})

                if cost:
                    totals["currency"] = cost.get("currency") or totals["currency"]
                    totals["cost"] = round(
                        totals["cost"] + float(cost.get("cost_per_serving", 0) or 0), 2
                    )
                if nutrition:
                    ps = nutrition.get("per_serving", {})
                    totals["calories"] = round(
                        totals["calories"] + float(ps.get("calories", 0) or 0), 1)
                    totals["protein_g"] = round(
                        totals["protein_g"] + float(ps.get("protein", 0) or 0), 1)
                    totals["carbs_g"] = round(
                        totals["carbs_g"] + float(ps.get("carbs", 0) or 0), 1)
                    totals["fat_g"] = round(
                        totals["fat_g"] + float(ps.get("fat", 0) or 0), 1)

            staple = next((d for d in dishes if d.get("role") == "staple"), None)
            base_item["dishes"] = dishes
            base_item["recipe"] = staple or (dishes[0] if dishes else None)
        elif record and record.items:
            # 全部被黑名单屏蔽：整餐置空（已在上方触发重搭）
            pass

        recommendations.append(base_item)

    totals["refresh_counts"] = refresh_counts

    return {
        "status": "ready",
        "date": today.isoformat(),
        "recommendations": recommendations,
        "totals": totals,
        "refreshing_meals": refreshing_meals or [],
    }


def _load_today_records(db: Session, user_id: int, today: datetime.date) -> List[DailyRecommendation]:
    return (
        db.query(DailyRecommendation)
        .options(
            joinedload(DailyRecommendation.items).joinedload(DailyRecommendationItem.recipe)
        )
        .filter(
            DailyRecommendation.user_id == user_id,
            DailyRecommendation.date == today,
        )
        .all()
    )


async def generate_recommendations(
    db: Session, user: User, tz: str = "UTC",
    preference: Optional[str] = None, lang: str = "zh",
) -> Dict:
    """
    为指定用户生成今日三餐推荐（多道菜套餐）。

    逻辑：
    1. 检查今天是否已有推荐，有则做黑名单复核后直接返回
    2. 对每餐：池（分类口径 + 去重放宽）→ 短名单 → 组合（LLM 优先/规则降级）
    3. 写入 daily_recommendations + items
    4. 返回结果
    """
    today = utc_datetime_to_local_date(datetime.datetime.now(datetime.timezone.utc), tz)

    existing = _load_today_records(db, user.id, today)

    if existing:
        # 黑名单复核：命中餐删除并重新生成
        from app.api.blacklist import _get_effective_blacklist_ids
        from app.models.recipe import RecipeIngredient

        blacklisted_ids = _get_effective_blacklist_ids(db, user.id)
        if blacklisted_ids:
            existing_recipe_ids = {
                item.recipe_id for r in existing for item in r.items
            }
            bl_recipe_ids: Set[int] = set()
            if existing_recipe_ids:
                bl_recipe_ids = set(
                    r[0] for r in db.query(RecipeIngredient.recipe_id).filter(
                        RecipeIngredient.recipe_id.in_(existing_recipe_ids),
                        RecipeIngredient.ingredient_id.in_(blacklisted_ids),
                    ).distinct().all()
                )
            if bl_recipe_ids:
                bl_meal_types = {
                    r.meal_type for r in existing
                    if any(item.recipe_id in bl_recipe_ids for item in r.items)
                }
                db.query(DailyRecommendation).filter(
                    DailyRecommendation.user_id == user.id,
                    DailyRecommendation.date == today,
                    DailyRecommendation.meal_type.in_(bl_meal_types),
                ).delete(synchronize_session=False)
                # items 随 cascade 删除（session 内对象）；同步清掉孤儿
                from app.models.daily_recommendation_item import DailyRecommendationItem as _DRI

                db.query(_DRI).filter(
                    _DRI.recommendation_id.notin_(
                        db.query(DailyRecommendation.id).filter(
                            DailyRecommendation.user_id == user.id,
                            DailyRecommendation.date == today,
                        )
                    )
                ).delete(synchronize_session=False)
                db.commit()
                existing = [
                    r for r in existing
                    if r.meal_type not in bl_meal_types
                ]

                # 为被删除的餐重新组合（先算后写）
                picked_ids: Set[int] = _meal_record_recipe_ids_union(existing)
                for mt in ["breakfast", "lunch", "dinner"]:
                    if mt not in bl_meal_types:
                        continue
                    result, _limit = await _compose_for_meal(
                        db, user, mt, picked_ids, today, preference, lang,
                    )
                    if result:
                        _persist_meal(db, user.id, today, mt, result["composed"], preference)
                        picked_ids |= {d.recipe_id for d in result["composed"].dishes}
                db.commit()
                existing = _load_today_records(db, user.id, today)

        if existing:
            return await _build_response_from_records(db, existing, user, tz=tz)

    meal_types = ["breakfast", "lunch", "dinner"]
    picked_ids: Set[int] = set()  # 跨餐去重
    import os
    if os.environ.get("MEAL_DEBUG"):
        print(f"[generate] composing for user={user.id} today={today}", flush=True)

    # 先完成所有餐的组合（读 + 计算，不持写锁），再批量写入 + commit
    favorites = _get_favorite_recipe_ids(db, user.id)
    composed_meals = {}
    for meal_type in meal_types:
        result, _limit = await _compose_for_meal(
            db, user, meal_type, picked_ids, today, preference, lang,
            favorite_ids=favorites,
        )
        if result and result["composed"].dishes:
            composed_meals[meal_type] = result["composed"]
            picked_ids |= {d.recipe_id for d in result["composed"].dishes}
        db.rollback()

    for meal_type, composed in composed_meals.items():
        _persist_meal(db, user.id, today, meal_type, composed, preference)
    db.commit()

    all_records = _load_today_records(db, user.id, today)
    return await _build_response_from_records(db, all_records, user, tz=tz)


def _meal_record_recipe_ids_union(records: List[DailyRecommendation]) -> Set[int]:
    ids: Set[int] = set()
    for r in records:
        ids |= _meal_record_recipe_ids(r)
    return ids


async def refresh_meal_recommendation(
    db: Session, user: User, meal_type: str, tz: str = "UTC",
    recipe_id: Optional[int] = None,
    preference: Optional[str] = None,
    lang: str = "zh",
) -> Tuple[Optional[Dict], Optional[str]]:
    """
    刷新某一餐的推荐：整餐重搭（recipe_id=None）或单道换（recipe_id 给定）。

    返回 (response_dict, error_message)。
    """
    today = utc_datetime_to_local_date(datetime.datetime.now(datetime.timezone.utc), tz)

    current_rec = (
        db.query(DailyRecommendation)
        .options(
            joinedload(DailyRecommendation.items).joinedload(DailyRecommendationItem.recipe)
        )
        .filter(
            DailyRecommendation.user_id == user.id,
            DailyRecommendation.date == today,
            DailyRecommendation.meal_type == meal_type,
        )
        .first()
    )
    if current_rec is None:
        return (None, "该餐暂无推荐，请先生成今日推荐")
    # 方案来源餐（source='plan'）可能没有 items —— 同样允许刷新（重建后翻回 AI/规则）

    # 修复后的上限：refresh_count 列真实计数
    if int(current_rec.refresh_count or 0) >= MAX_REFRESH_PER_MEAL:
        return (
            None,
            f"今天{meal_type}推荐已经刷新 {MAX_REFRESH_PER_MEAL} 次了，明天再来吧～",
        )

    # 其他餐已选菜谱（跨餐去重）
    exclude_ids: Set[int] = set()
    all_today = _load_today_records(db, user.id, today)
    for rec in all_today:
        if rec.meal_type != meal_type:
            exclude_ids |= _meal_record_recipe_ids(rec)

    if recipe_id is not None:
        # 单道换：保持其它菜不动，只重选该道
        target_item = next(
            (item for item in current_rec.items if item.recipe_id == recipe_id), None)
        if target_item is None:
            return (None, "该菜不在当前推荐中")
        single_role = target_item.role
        removed_sort = target_item.sort_order
        exclude_ids |= {
            item.recipe_id for item in current_rec.items if item.recipe_id != recipe_id
        }
        result, _limit = await _compose_for_meal(
            db, user, meal_type, exclude_ids, today, preference, lang,
            single_role=single_role,
        )
        if not result or not result["composed"].dishes:
            return (None, "该餐类暂无其他可用菜谱")
        composed = result["composed"]
        new_dish = composed.dishes[0]

        db.query(DailyRecommendationItem).filter(
            DailyRecommendationItem.id == target_item.id
        ).delete(synchronize_session=False)
        db.add(DailyRecommendationItem(
            recommendation_id=current_rec.id,
            recipe_id=new_dish.recipe_id,
            sort_order=removed_sort,
            role=new_dish.role,
            reason=new_dish.reason,
        ))
        current_rec.source = composed.source
        if composed.note:
            current_rec.reason = composed.note
    else:
        # 整餐重搭
        exclude_ids |= _meal_record_recipe_ids(current_rec)
        result, _limit = await _compose_for_meal(
            db, user, meal_type, exclude_ids, today, preference, lang,
        )
        if not result or not result["composed"].dishes:
            return (None, "该餐类暂无其他可用菜谱")
        composed = result["composed"]
        from app.models.daily_recommendation_item import DailyRecommendationItem as _DRI

        db.query(_DRI).filter(
            _DRI.recommendation_id == current_rec.id
        ).delete(synchronize_session=False)
        for order, dish in enumerate(composed.dishes):
            db.add(DailyRecommendationItem(
                recommendation_id=current_rec.id,
                recipe_id=dish.recipe_id,
                sort_order=order,
                role=dish.role,
                reason=dish.reason,
            ))
        current_rec.source = composed.source
        current_rec.reason = composed.note

    if preference is not None:
        current_rec.preference = preference
    current_rec.refresh_count = int(current_rec.refresh_count or 0) + 1
    # 换一餐后回归 AI/规则来源（清除方案来源标记）
    current_rec.source = composed.source
    current_rec.plan_id = None
    db.commit()

    all_records = _load_today_records(db, user.id, today)
    return (await _build_response_from_records(db, all_records, user, tz=tz), None)


# ============ 后台生成与状态检查 ============

def is_generating(user_id: int) -> bool:
    """检查指定用户是否正在后台生成推荐。"""
    with _generation_lock:
        return user_id in _generating_users


def check_today_status(db: Session, user_id: int, tz: str = "UTC") -> Dict:
    """快速检查今日推荐状态，不触发耗时计算。

    返回 {"status": ..., "existing_records": [...], "refreshing_meals": [...]}，
    status 为 "ready"（已有）+ records、"not_generated"（无）、"generating"（生成中）。
    refreshing_meals 为当前正在后台刷新的餐类列表（仅在 ready 时有意义）。
    """
    today = utc_datetime_to_local_date(datetime.datetime.now(datetime.timezone.utc), tz)

    existing = _load_today_records(db, user_id, today)

    with _refresh_lock:
        refreshing = list(_refreshing_meals.get(user_id, set()))

    if existing:
        return {"status": "ready", "existing_records": existing, "refreshing_meals": refreshing}
    if is_generating(user_id):
        return {"status": "generating", "existing_records": [], "refreshing_meals": refreshing}
    return {"status": "not_generated", "existing_records": [], "refreshing_meals": refreshing}


def _generate_in_background(user_id: int, tz: str = "UTC",
                            preference: Optional[str] = None, lang: str = "zh"):
    """在独立线程中运行推荐生成，不阻塞 HTTP 响应。"""
    from app.core.database import SessionLocal

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if user is None:
            logger.warning(f"后台生成：用户 {user_id} 不存在")
            return
        # 在新线程中跑独立的 event loop
        asyncio.run(generate_recommendations(db, user, tz, preference=preference, lang=lang))
        logger.info(f"后台生成：用户 {user_id} 推荐已就绪")
    except Exception:
        logger.exception(f"后台生成：用户 {user_id} 推荐失败")
    finally:
        db.close()
        with _generation_lock:
            _generating_users.discard(user_id)


def trigger_background_generation(user_id: int, tz: str = "UTC",
                                  preference: Optional[str] = None,
                                  lang: str = "zh") -> bool:
    """触发后台生成。如果已在生成中返回 False，否则启动线程并返回 True。"""
    with _generation_lock:
        if user_id in _generating_users:
            return False
        _generating_users.add(user_id)

    thread = threading.Thread(
        target=_generate_in_background,
        args=(user_id, tz, preference, lang),
        daemon=True,
        name=f"meal-gen-{user_id}",
    )
    thread.start()
    return True


# ============ 后台刷新 ============

def is_refreshing(user_id: int, meal_type: str) -> bool:
    """检查指定用户的某餐是否正在后台刷新。"""
    with _refresh_lock:
        return meal_type in _refreshing_meals.get(user_id, set())


def _refresh_in_background(user_id: int, meal_type: str, tz: str = "UTC",
                           target_recipe_id: Optional[int] = None,
                           preference: Optional[str] = None, lang: str = "zh"):
    """在独立线程中运行单餐刷新。"""
    from app.core.database import SessionLocal

    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if user is None:
            logger.warning(f"后台刷新：用户 {user_id} 不存在")
            return
        result, error = asyncio.run(refresh_meal_recommendation(
            db, user, meal_type, tz,
            recipe_id=target_recipe_id, preference=preference, lang=lang,
        ))
        if error:
            logger.warning(f"后台刷新：用户 {user_id} {meal_type} 刷新失败: {error}")
        else:
            logger.info(f"后台刷新：用户 {user_id} {meal_type} 已更新")
    except Exception:
        logger.exception(f"后台刷新：用户 {user_id} {meal_type} 异常")
    finally:
        db.close()
        with _refresh_lock:
            meals = _refreshing_meals.get(user_id, set())
            meals.discard(meal_type)
            if not meals:
                _refreshing_meals.pop(user_id, None)


def trigger_background_refresh(
    user_id: int, meal_type: str, tz: str = "UTC",
    target_recipe_id: Optional[int] = None,
    preference: Optional[str] = None,
    lang: str = "zh",
) -> Tuple[bool, Optional[str]]:
    """触发后台刷新某餐。返回 (started, error_message)。

    - 已在刷新中 → (False, "该餐正在刷新中")
    - 启动成功 → (True, None)
    """
    with _refresh_lock:
        meals = _refreshing_meals.setdefault(user_id, set())
        if meal_type in meals:
            return (False, "该餐正在刷新中，请稍候～")
        meals.add(meal_type)

    thread = threading.Thread(
        target=_refresh_in_background,
        args=(user_id, meal_type, tz, target_recipe_id, preference, lang),
        daemon=True,
        name=f"meal-refresh-{user_id}-{meal_type}",
    )
    thread.start()
    return (True, None)
