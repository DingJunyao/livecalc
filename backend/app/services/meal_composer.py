"""餐食组合层（设计 §4.3）：可插拔 MealComposer + 校验器 + 规则/LLM 实现。

短名单（确定性层）由 meal_recommender 构建；本模块只消费其 dict 形态，
保证纯函数可单测（DB 无关）。

组合入口 compose_meal：按 ai_policy 解析结果选择 LLM 或规则；LLM 输出经
validate_composition 校验，失败回灌重试 1 次，仍失败/超时/未配置 → 规则降级。
"""
import asyncio
import json
import logging
from dataclasses import dataclass, field
from typing import Awaitable, Callable, Dict, List, Optional, Set

logger = logging.getLogger("meal_composer")

ROLES = ("staple", "main", "side", "soup", "drink")

MEAL_PLANNER_SYSTEM_PROMPT = """你是中餐营养搭配助手。给定候选菜谱短名单（JSON）与约束，组合一餐（1-4 道菜）。
硬性要求：
1. 至少一道 role="staple"（主食）；
2. 只能从短名单中选，不得编造 recipe_id；
3. 每道菜给 role（staple|main|side|soup|drink）与不超过 30 字的推荐理由；
4. 避开「排除菜谱」与「近 7 天已推荐」中的菜；优先满足用户偏好、营养目标与预算；
5. {single_line}
只输出一个 JSON 对象，不要 markdown 代码块、不要解释：
{{"dishes": [{{"recipe_id": 123, "role": "staple", "reason": "…"}}], "note": "整餐一句话理由"}}"""


@dataclass
class ComposedDish:
    recipe_id: int
    role: str
    reason: Optional[str] = None


@dataclass
class ComposedMeal:
    dishes: List[ComposedDish] = field(default_factory=list)
    note: Optional[str] = None
    source: str = "rule"  # rule | system_ai | user_ai


# ============ 校验器（纯函数） ============

def validate_composition(
    raw,
    shortlist: List[dict],
    meal_type: str,
    exclude_ids: Optional[Set[int]] = None,
    single_role: Optional[str] = None,
) -> List[str]:
    """校验组合结果，返回错误清单（空 = 通过）。raw 可为 str（JSON 文本）或 dict。"""
    errors: List[str] = []
    if isinstance(raw, str):
        try:
            raw = json.loads(raw)
        except (json.JSONDecodeError, TypeError):
            return ["输出不是合法 JSON"]

    if not isinstance(raw, dict) or not isinstance(raw.get("dishes"), list):
        return ["缺少 dishes 数组"]

    dishes = raw["dishes"]
    by_id = {d["id"]: d for d in shortlist}

    if single_role is not None:
        if len(dishes) != 1:
            errors.append("单道换模式下必须恰好 1 道")
    elif not (1 <= len(dishes) <= 4):
        errors.append(f"道数必须在 1-4 道，实际 {len(dishes)} 道")

    seen: Set[int] = set()
    has_staple = False
    staple_category_ok = True
    for d in dishes:
        if not isinstance(d, dict):
            errors.append("dishes 元素必须是对象")
            continue
        rid = d.get("recipe_id")
        role = d.get("role")
        if rid not in by_id:
            errors.append(f"recipe_id {rid} 不在短名单中")
            continue
        if rid in seen:
            errors.append(f"recipe_id {rid} 重复")
            continue
        seen.add(rid)
        if role not in ROLES:
            errors.append(f"recipe_id {rid} 的 role 非法：{role}")
            continue
        if role == "staple":
            has_staple = True
            # 午/晚餐机械交叉校验：staple 的分类必须是「主食」
            if meal_type in ("lunch", "dinner") and by_id[rid].get("category") != "主食":
                staple_category_ok = False
        elif by_id[rid].get("category") == "主食":
            errors.append(f"recipe_id {rid}（主食分类）必须标 role=staple")

    if single_role is not None:
        for d in dishes:
            if isinstance(d, dict) and d.get("role") != single_role:
                errors.append(f"单道换的 role 必须是 {single_role}")
    elif not has_staple:
        errors.append("至少一道 role=staple（主食）")

    if meal_type in ("lunch", "dinner") and not staple_category_ok:
        errors.append("午餐/晚餐的 staple 必须是「主食」分类的菜")

    if exclude_ids:
        for rid in seen:
            if rid in exclude_ids:
                errors.append(f"recipe_id {rid} 在排除清单中")

    return errors


def _parse_dishes(raw) -> Optional[ComposedMeal]:
    """从（已通过校验的）dict 构建 ComposedMeal。"""
    dishes = [
        ComposedDish(
            recipe_id=int(d["recipe_id"]),
            role=d.get("role") or "main",
            reason=(d.get("reason") or None) if isinstance(d.get("reason"), str) else None,
        )
        for d in raw.get("dishes", [])
        if isinstance(d, dict) and isinstance(d.get("recipe_id"), int)
    ]
    note = raw.get("note")
    return ComposedMeal(dishes=dishes, note=note if isinstance(note, str) else None)


# ============ 规则组合器 ============

def _top_by_category(shortlist: List[dict], categories, exclude_ids: Set[int]) -> Optional[dict]:
    pool = [
        d for d in shortlist
        if d.get("category") in categories and d["id"] not in exclude_ids
    ]
    if not pool:
        return None
    return max(pool, key=lambda d: d.get("score", 0.0))


class RuleMealComposer:
    """确定性降级：主食 + 主菜（+汤/粥），早餐用早餐类。"""

    @staticmethod
    def compose(
        shortlist: List[dict],
        meal_type: str,
        exclude_ids: Optional[Set[int]] = None,
        single_role: Optional[str] = None,
    ) -> ComposedMeal:
        exclude = set(exclude_ids or set())
        if single_role is not None:
            pool = [d for d in shortlist if d["id"] not in exclude]
            if single_role == "staple":
                if meal_type in ("lunch", "dinner"):
                    pool = [d for d in pool if d.get("category") == "主食"] or pool
                else:
                    pool = (
                        [d for d in pool if d.get("category") in ("主食", "早餐", "汤与粥")]
                        or pool
                    )
            if not pool:
                pool = [d for d in shortlist if d["id"] not in exclude]
            pick = max(pool, key=lambda d: d.get("score", 0.0)) if pool else None
            dishes = [ComposedDish(pick["id"], single_role, "按当前目标挑选")] if pick else []
            return ComposedMeal(dishes=dishes, note="按营养与成本目标挑选", source="rule")

        dishes: List[ComposedDish] = []
        used: Set[int] = set(exclude)

        def take(candidate: Optional[dict], role: str, threshold: Optional[float] = None):
            if candidate is None:
                return
            if threshold is not None and candidate.get("score", 0.0) < threshold:
                return
            if candidate["id"] in used:
                return
            used.add(candidate["id"])
            dishes.append(ComposedDish(candidate["id"], role, "按营养与成本目标挑选"))

        if meal_type == "breakfast":
            take(_top_by_category(shortlist, ("主食",), used), "staple")
            take(_top_by_category(shortlist, ("早餐",), used), "main")
            take(_top_by_category(shortlist, ("汤与粥",), used), "soup", threshold=0.5)
        else:
            take(_top_by_category(shortlist, ("主食",), used), "staple")
            take(_top_by_category(shortlist, ("荤菜", "素菜", "水产"), used), "main")
            take(_top_by_category(shortlist, ("汤与粥",), used), "soup", threshold=0.5)

        return ComposedMeal(dishes=dishes, note="按营养与成本目标挑选", source="rule")


# ============ LLM 组合器 ============

def build_compose_prompt(
    shortlist: List[dict],
    meal_type: str,
    targets: Dict[str, float],
    budget: Optional[float],
    excluded_names: List[str],
    recent_names: List[str],
    preference: Optional[str],
    lang: str = "zh",
    single_role: Optional[str] = None,
) -> tuple[str, str]:
    """构建 (system, user) 提示词对。

    返回元组而非拼接串：system 提示自身含空行，不能用空行分隔还原。
    """
    lang_name = {"zh": "中文", "en": "English", "ar": "العربية"}.get(lang, "中文")
    meal_name = {"breakfast": "早餐", "lunch": "午餐", "dinner": "晚餐"}.get(meal_type, meal_type)
    single_line = (
        f"6. 本次是「单道替换」：只输出恰好 1 道菜，且 role 必须是 {single_role}。"
        if single_role else
        "6. 午餐/晚餐的 staple 必须是分类为「主食」的菜；分类为「主食」的菜必须标 staple。"
    )
    system = MEAL_PLANNER_SYSTEM_PROMPT.format(single_line=single_line)
    payload = {
        "meal_type": meal_name,
        "targets_per_meal": {k: round(v, 1) for k, v in targets.items()},
        "budget_per_meal": budget,
        "user_preference": preference or "",
        "excluded_recipes": excluded_names,
        "recent_7d_recipes": recent_names,
        "output_language": lang_name,
        "candidates": [
            {
                "recipe_id": d["id"], "name": d["name"], "category": d["category"],
                "cost": d.get("cost_estimate"),
                "calories": (d.get("nutrition_per_serving") or {}).get("calories"),
                "protein_g": (d.get("nutrition_per_serving") or {}).get("protein_g"),
                "carbs_g": (d.get("nutrition_per_serving") or {}).get("carbs_g"),
                "fat_g": (d.get("nutrition_per_serving") or {}).get("fat_g"),
                "minutes": d.get("total_time_minutes"),
                "is_favorite": bool(d.get("is_favorite")),
                "has_favorite_ingredient": bool(d.get("has_favorite_ingredient")),
                "top_ingredients": d.get("top_ingredients") or [],
            }
            for d in shortlist
        ],
    }
    user = json.dumps(payload, ensure_ascii=False)
    return system, user


class LLMMealComposer:
    """经 Translator 通道调用大模型组合套餐。

    `complete` 为 (system_prompt, user_prompt) -> 模型文本 的异步可调用；
    生产环境由 meal_recommender 按 provider 构造，测试注入假实现。
    compose 返回 None 表示两次尝试都未通过校验（调用方降级规则）。
    """

    def __init__(self, complete: Callable[[str, str], Awaitable[str]]):
        self._complete = complete

    async def compose(
        self,
        shortlist: List[dict],
        meal_type: str,
        exclude_ids: Optional[Set[int]] = None,
        targets: Optional[Dict[str, float]] = None,
        budget: Optional[float] = None,
        excluded_names: Optional[List[str]] = None,
        recent_names: Optional[List[str]] = None,
        preference: Optional[str] = None,
        lang: str = "zh",
        single_role: Optional[str] = None,
    ) -> Optional[ComposedMeal]:
        prompt = build_compose_prompt(
            shortlist, meal_type, targets or {}, budget,
            excluded_names or [], recent_names or [], preference, lang, single_role,
        )
        system, user = prompt
        feedback = ""
        for attempt in range(2):
            try:
                text = await self._complete(system, user + feedback)
            except Exception as e:
                logger.warning(f"LLM 组合调用失败（第 {attempt + 1} 次）: {e}")
                return None
            errors = validate_composition(
                text, shortlist, meal_type, exclude_ids, single_role)
            if not errors:
                return _parse_dishes(json.loads(text))
            # 回灌错误清单重试
            feedback = (
                f"\n\n上一次输出未通过校验，错误：{'；'.join(errors)}。"
                f"请修正后重新只输出 JSON。"
            )
        logger.warning(f"LLM 组合两次未通过校验：{errors}")
        return None


# ============ 顶层入口 ============

async def compose_meal(
    shortlist: List[dict],
    meal_type: str,
    exclude_ids: Optional[Set[int]] = None,
    *,
    targets: Optional[Dict[str, float]] = None,
    budget: Optional[float] = None,
    excluded_names: Optional[List[str]] = None,
    recent_names: Optional[List[str]] = None,
    preference: Optional[str] = None,
    lang: str = "zh",
    single_role: Optional[str] = None,
    llm: Optional[LLMMealComposer] = None,
) -> ComposedMeal:
    """按可用性选择组合器：LLM 优先（失败自动降级），规则兜底。"""
    if llm is not None and shortlist:
        composed = await llm.compose(
            shortlist, meal_type, exclude_ids=exclude_ids,
            targets=targets, budget=budget,
            excluded_names=excluded_names, recent_names=recent_names,
            preference=preference, lang=lang, single_role=single_role,
        )
        if composed is not None and composed.dishes:
            return composed
    return RuleMealComposer.compose(
        shortlist, meal_type, exclude_ids=exclude_ids, single_role=single_role,
    )
