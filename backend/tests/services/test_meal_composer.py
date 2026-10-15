"""组合层（meal_composer）纯函数测试：校验器与规则组合器。

夹具为短名单 dict（与 meal_recommender._build_shortlist 输出同形），不依赖 DB。
"""
from app.services.meal_composer import (
    RuleMealComposer,
    build_compose_prompt,
    validate_composition,
)


def _dish(id, name="菜", category="主食", score=0.5, favorite=False, time=10):
    return {
        "id": id, "name": name, "category": category, "score": score,
        "cost_estimate": 3.0, "currency": "CNY",
        "nutrition_per_serving": {"calories": 300, "protein_g": 8, "carbs_g": 55, "fat_g": 4},
        "total_time_minutes": time, "is_favorite": favorite,
        "has_favorite_ingredient": False, "top_ingredients": ["鸡蛋", "米饭"],
    }


def _shortlist():
    return [
        _dish(1, "米饭", "主食", score=0.8),
        _dish(2, "面条", "主食", score=0.6),
        _dish(3, "红烧肉", "荤菜", score=0.7),
        _dish(4, "炒青菜", "素菜", score=0.4),
        _dish(5, "番茄汤", "汤与粥", score=0.55),
        _dish(6, "蒸蛋", "早餐", score=0.5),
    ]


def test_validate_accepts_valid_staple_plus_main():
    raw = {"dishes": [
        {"recipe_id": 1, "role": "staple", "reason": "主食"},
        {"recipe_id": 3, "role": "main", "reason": "荤菜"},
    ], "note": "有荤有素"}
    errors = validate_composition(raw, _shortlist(), "lunch", exclude_ids=set())
    assert errors == [], errors


def test_validate_rejects_missing_staple_and_out_of_range_and_dup():
    base = _shortlist()
    # 无 staple
    errs = validate_composition({"dishes": [{"recipe_id": 3, "role": "main"}]},
                                base, "lunch", set())
    assert any("staple" in e for e in errs), errs
    # id 越界
    errs = validate_composition({"dishes": [{"recipe_id": 999, "role": "staple"}]},
                                base, "lunch", set())
    assert any("999" in e or "不在" in e for e in errs), errs
    # 重复
    errs = validate_composition({"dishes": [
        {"recipe_id": 1, "role": "staple"}, {"recipe_id": 1, "role": "main"}]},
        base, "lunch", set())
    assert any("重复" in e for e in errs), errs
    # 道数越界（>4）
    dishes = [{"recipe_id": i, "role": "side"} for i in (1, 2, 3, 4, 5, 6)]
    errs = validate_composition({"dishes": dishes}, base, "lunch", set())
    assert any("道" in e for e in errs), errs
    # 排除集命中
    errs = validate_composition({"dishes": [{"recipe_id": 1, "role": "staple"}]},
                                base, "lunch", exclude_ids={1})
    assert any("排除" in e for e in errs), errs
    # 坏 JSON
    errs = validate_composition("not-json", base, "lunch", set())
    assert len(errs) == 1 and "JSON" in errs[0]


def test_validate_lunch_staple_category_crosscheck():
    base = _shortlist()
    # 午餐 staple 但选了非「主食」分类 → 机械校验拦截
    errs = validate_composition({"dishes": [{"recipe_id": 3, "role": "staple"}]},
                                base, "lunch", set())
    assert any("主食" in e for e in errs), errs
    # 早餐不要求 staple 的分类必须是「主食」（早餐类可作 staple）
    errs = validate_composition({"dishes": [{"recipe_id": 6, "role": "staple"}]},
                                base, "breakfast", set())
    assert errs == [], errs
    # 反向：「主食」分类的菜标成非 staple → 拦截
    errs = validate_composition({"dishes": [
        {"recipe_id": 6, "role": "staple"},
        {"recipe_id": 1, "role": "side"}]},
        base, "breakfast", set())
    assert any("staple" in e for e in errs), errs


def test_validate_single_dish_mode():
    base = _shortlist()
    # 单道换：只允许 1 道，且 role 必须匹配被换道
    errs = validate_composition(
        {"dishes": [{"recipe_id": 2, "role": "staple"}]}, base, "lunch", set(),
        single_role="staple")
    assert errs == [], errs
    errs = validate_composition(
        {"dishes": [{"recipe_id": 2, "role": "staple"}, {"recipe_id": 3, "role": "main"}]},
        base, "lunch", set(), single_role="staple")
    assert any("1 道" in e for e in errs), errs
    errs = validate_composition(
        {"dishes": [{"recipe_id": 3, "role": "main"}]}, base, "lunch", set(),
        single_role="staple")
    assert any("staple" in e for e in errs), errs


def test_rule_composer_lunch_structure():
    result = RuleMealComposer.compose(_shortlist(), "lunch", exclude_ids=set())
    roles = {d.role for d in result.dishes}
    assert "staple" in roles
    assert result.source == "rule"
    ids = [d.recipe_id for d in result.dishes]
    assert len(ids) == len(set(ids))
    # 主食应取最高分主食（1 米饭 0.8 > 2 面条 0.6）
    assert 1 in ids
    # 主菜应取非主食最高分（3 红烧肉 0.7）
    assert 3 in ids
    # 汤分数 0.55 >= 0.5 → 应包含
    assert 5 in ids


def test_rule_composer_breakfast_uses_breakfast_category():
    result = RuleMealComposer.compose(_shortlist(), "breakfast", exclude_ids=set())
    ids = [d.recipe_id for d in result.dishes]
    assert 6 in ids  # 早餐类
    assert "staple" in {d.role for d in result.dishes}


def test_rule_composer_respects_exclude_and_low_soup_gate():
    result = RuleMealComposer.compose(_shortlist(), "lunch", exclude_ids={1, 3, 5})
    ids = [d.recipe_id for d in result.dishes]
    assert 1 not in ids and 3 not in ids and 5 not in ids
    assert any(d.role == "staple" for d in result.dishes)


def test_rule_composer_single_mode_staple_only():
    result = RuleMealComposer.compose(
        _shortlist(), "lunch", exclude_ids={1}, single_role="staple")
    assert len(result.dishes) == 1
    assert result.dishes[0].recipe_id == 2
    assert result.dishes[0].role == "staple"


def test_prompt_contains_shortlist_and_preference():
    system, user = build_compose_prompt(
        _shortlist(), "lunch", targets={"calories": 800, "protein": 24, "carbs": 120, "fat": 26},
        budget=30.0, excluded_names=["宫保鸡丁"], recent_names=["麻婆豆腐"],
        preference="想吃辣", lang="zh", single_role=None)
    assert "米饭" in user and "想吃辣" in user and "宫保鸡丁" in user
    assert "staple" in system and "JSON" in system
