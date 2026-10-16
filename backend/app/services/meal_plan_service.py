"""试算方案服务（设计 §5.2）。

- evaluate：一顿/一日的成本与营养合计 + 与目标对比（草稿不落库也能算）。
- cost_trend：方案成本按历史价格 as-of 逐日折算（复用菜谱 as-of 引擎与
  原料加权价，逐日聚合）。

口径：
- recipe 项：calculate_recipe_cost(servings_override=servings) 的 cost_per_serving；
  营养 = calculate_recipe_nutrition 的 per_serving（与推荐 totals 同口径）。
- ingredient 项：原料加权价（get_weighted_ingredient_price）× 数量（按目标单位换算）；
  营养按 nutrition_data（reference_amount 基准）× 折算克数 / 100。
- product 项：商品最新有效记录的单价 × 数量换算；无营养。
"""
import datetime
import logging
from decimal import Decimal
from typing import Dict, List, Optional

from sqlalchemy.orm import Session

from app.models.nutrition import Ingredient
from app.models.meal_plan import MealPlan, MealPlanItem
from app.models.nutrition_data import NutritionData
from app.models.product import ProductRecord
from app.models.product_entity import Product
from app.models.user import User
from app.services.ingredient_price_service import get_weighted_ingredient_price
from app.services.nutrition_reference import (
    KEY_BY_NAME,
    NAME_BY_KEY,
    NRV_BY_KEY,
    UNIT_BY_KEY,
    energy_to_kcal,
    nrv_pct,
)
from app.services.recipe_service import (
    calculate_recipe_cost,
    calculate_recipe_nutrition,
)
from app.services.unit_conversion_service import UnitConversionService

logger = logging.getLogger("meal_plan_service")

_EMPTY_NUTRITION = {"calories": 0.0, "protein_g": 0.0, "carbs_g": 0.0, "fat_g": 0.0}


def _round2(v: float) -> float:
    return round(v + 0.0, 2)


def _nutrient_values_from_all_nutrients(all_nutrients: Dict, factor: float = 1.0) -> Dict[str, float]:
    """把 all_nutrients（英文 key）整体折算 factor 倍；能量统一成 kcal。"""
    values: Dict[str, float] = {}
    for key, raw in (all_nutrients or {}).items():
        if isinstance(raw, dict):
            value = raw.get("value")
            unit = raw.get("unit")
        elif isinstance(raw, (int, float)):
            value, unit = raw, None
        else:
            continue
        if value is None:
            continue
        try:
            number = float(value) * factor
        except (TypeError, ValueError):
            continue
        if key == "energy":
            number = energy_to_kcal(number, unit)
        values[key] = number
    return values


def _recipe_nutrient_values(nutrition: Dict) -> Dict[str, float]:
    """菜谱 per-serving 的全部营养素（英文 key）；能量用已换算 kJ→kcal 的 per_serving.calories。"""
    per_serving = (nutrition or {}).get("per_serving") or {}
    all_nutrients = ((nutrition or {}).get("per_serving_nutrition") or {}).get("all_nutrients") or {}
    values = _nutrient_values_from_all_nutrients(all_nutrients)
    values["energy"] = float(per_serving.get("calories") or 0)
    values.setdefault("protein", float(per_serving.get("protein") or 0))
    values.setdefault("fat", float(per_serving.get("fat") or 0))
    values.setdefault("carbohydrate", float(per_serving.get("carbs") or 0))
    return {k: v for k, v in values.items() if v}


def _build_plan_nutrition(items_info: List[Dict]) -> Dict:
    """把各条目的 nutrient_values 汇成前端「营养成分 / 营养来源」所需的结构。

    形状与 `calculate_recipe_nutrition` 的返回对齐（`per_serving_nutrition` +
    `ingredient_details[].nutrition_contribution`），这样前端可以直接复用菜谱详情的组件。
    """
    totals: Dict[str, float] = {}
    details: List[Dict] = []
    for info in items_info:
        values = info.get("nutrient_values") or {}
        if not values:
            continue
        for key, value in values.items():
            totals[key] = totals.get(key, 0.0) + float(value)
        details.append({
            "ingredient_id": info.get("item_id"),
            "ingredient_name": info.get("name") or "",
            "item_type": info.get("item_type"),
            "nutrition_contribution": {
                key: {"value": _round2(float(value)), "unit": UNIT_BY_KEY.get(key, "")}
                for key, value in values.items()
            },
        })
    if not totals:
        return {}
    core: Dict[str, Dict] = {}
    all_nutrients: Dict[str, Dict] = {}
    for key, value in totals.items():
        unit = UNIT_BY_KEY.get(key, "")
        pct = nrv_pct(key, value)
        all_nutrients[key] = {"value": _round2(value), "unit": unit, "nrp_pct": pct}
        name = NAME_BY_KEY.get(key)
        if name:
            core[name] = {
                "value": _round2(value),
                "unit": unit,
                "key": key,
                "nrp_pct": pct,
                "standard": f"NRV标准值：{NRV_BY_KEY[key]}{unit}" if key in NRV_BY_KEY else "无标准",
            }
    return {
        "per_serving_nutrition": {"core_nutrients": core, "all_nutrients": all_nutrients},
        "ingredient_details": details,
    }


async def _item_cost_nutrition(
    db: Session, user: User, item: MealPlanItem, tz: str,
) -> Dict:
    """单个条目的 {name, cost, currency, nutrition}。计算失败不抛出，返回 None 值。"""
    out: Dict = {
        "item_id": item.id,
        "item_type": item.item_type,
        "group": item.group,
        "servings": float(item.servings) if item.servings is not None else None,
        "quantity": float(item.quantity) if item.quantity is not None else None,
        "unit": None,
        "cost": None,
        "currency": None,
        "nutrition": None,
        "nutrient_values": {},
    }

    if item.item_type == "recipe":
        recipe = item.recipe
        if recipe is None:
            return out
        out["name"] = recipe.name
        servings_override = float(item.servings) if item.servings is not None else None
        try:
            cost = await calculate_recipe_cost(
                recipe.id, user.id, db,
                tz=tz, servings_override=servings_override,
            )
            if cost and cost.get("cost_per_serving") is not None:
                out["cost"] = _round2(float(cost["cost_per_serving"]))
                out["currency"] = cost.get("currency")
        except Exception:
            logger.debug(f"试算：菜谱 {recipe.id} 成本计算失败", exc_info=True)
        try:
            nutrition = await calculate_recipe_nutrition(recipe.id, db=db)
            if nutrition:
                ps = nutrition.get("per_serving") or {}
                out["nutrition"] = {
                    "calories": _round2(float(ps.get("calories", 0) or 0)),
                    "protein_g": _round2(float(ps.get("protein", 0) or 0)),
                    "carbs_g": _round2(float(ps.get("carbs", 0) or 0)),
                    "fat_g": _round2(float(ps.get("fat", 0) or 0)),
                }
                out["nutrient_values"] = _recipe_nutrient_values(nutrition)
        except Exception:
            logger.debug(f"试算：菜谱 {recipe.id} 营养计算失败", exc_info=True)
        return out

    if item.item_type == "ingredient":
        ingredient: Ingredient = item.ingredient
        if ingredient is None:
            return out
        out["name"] = ingredient.name
        quantity = float(item.quantity or 0)
        unit_abbr = item.unit.abbreviation if item.unit else "g"
        out["unit"] = unit_abbr
        now = datetime.datetime.now(datetime.timezone.utc)
        try:
            weighted = get_weighted_ingredient_price(
                db, ingredient.id, as_of_date=now,
                user_id=user.id, target_unit_abbr=unit_abbr, tz=tz,
            )
            unit_price = weighted.get("unit_price")
            price_unit = weighted.get("unit") or unit_abbr
            if unit_price is not None:
                qty_in_price_unit = quantity
                if price_unit != unit_abbr:
                    converter = UnitConversionService(db)
                    converted = converter.convert(
                        Decimal(str(quantity)), unit_abbr, price_unit,
                        entity_type="ingredient", entity_id=ingredient.id,
                    )
                    qty_in_price_unit = float(converted[0]) if converted else None
                if qty_in_price_unit is not None:
                    out["cost"] = _round2(float(unit_price) * qty_in_price_unit)
                    out["currency"] = weighted.get("currency")
        except Exception:
            logger.debug(f"试算：原料 {ingredient.id} 加权价失败", exc_info=True)
        # 营养：nutrition_data.nutrients（all_nutrients 标准 key，reference 基准）
        # 折算 = 数量换算成克 / 基准量换算成克
        try:
            mapping = (
                db.query(NutritionData)
                .filter(NutritionData.ingredient_id == ingredient.id)
                .first()
            )
            if mapping is not None and mapping.nutrients:
                all_nutrients = (mapping.nutrients or {}).get("all_nutrients") or {}

                def _nutrient(key: str) -> float:
                    data = all_nutrients.get(key)
                    if isinstance(data, dict):
                        return float(data.get("value", 0) or 0)
                    if isinstance(data, (int, float)):
                        return float(data)
                    return 0.0

                converter = UnitConversionService(db)

                def _to_grams(value: float, abbr: str) -> Optional[float]:
                    converted = converter.convert(
                        Decimal(str(value)), abbr, "g",
                        entity_type="ingredient", entity_id=ingredient.id,
                    )
                    if converted:
                        return float(converted[0])
                    if ingredient.density:
                        converted_ml = converter.convert(
                            Decimal(str(value)), abbr, "mL",
                            entity_type="ingredient", entity_id=ingredient.id,
                        )
                        if converted_ml:
                            return float(converted_ml[0]) * float(ingredient.density)
                    return None

                ref_amount = float(mapping.reference_amount or 100.0) or 100.0
                ref_unit = mapping.reference_unit or "g"
                qty_grams = _to_grams(quantity, unit_abbr)
                ref_grams = _to_grams(ref_amount, ref_unit)
                if qty_grams is not None and ref_grams:
                    factor = qty_grams / ref_grams
                    out["nutrition"] = {
                        "calories": _round2(_nutrient("energy") * factor),
                        "protein_g": _round2(_nutrient("protein") * factor),
                        "carbs_g": _round2(_nutrient("carbohydrate") * factor),
                        "fat_g": _round2(_nutrient("fat") * factor),
                    }
                    out["nutrient_values"] = _nutrient_values_from_all_nutrients(
                        all_nutrients, factor)
        except Exception:
            logger.debug(f"试算：原料 {ingredient.id} 营养折算失败", exc_info=True)
        return out

    if item.item_type == "product":
        product: Product = item.product
        if product is None:
            return out
        out["name"] = product.name
        quantity = float(item.quantity or 0)
        unit_abbr = item.unit.abbreviation if item.unit else None
        out["unit"] = unit_abbr
        try:
            record = (
                db.query(ProductRecord)
                .filter(
                    ProductRecord.product_id == product.id,
                    ProductRecord.is_active == True,  # noqa: E712
                )
                .order_by(ProductRecord.recorded_at.desc())
                .first()
            )
            if record is not None and record.price is not None:
                # 单价 = 价格 / 标准数量；数量按记录的标准单位换算
                std_qty = float(record.standard_quantity or 1) or 1.0
                unit_price = float(record.price) / std_qty
                qty_in_std = quantity
                if unit_abbr and record.standard_unit is not None:
                    std_abbr = record.standard_unit.abbreviation
                    if unit_abbr != std_abbr:
                        converter = UnitConversionService(db)
                        converted = converter.convert(
                            Decimal(str(quantity)), unit_abbr, std_abbr,
                            entity_type="product", entity_id=product.id,
                        )
                        qty_in_std = float(converted[0]) if converted else quantity
                out["cost"] = _round2(unit_price * qty_in_std)
                out["currency"] = record.currency
        except Exception:
            logger.debug(f"试算：商品 {product.id} 最新价失败", exc_info=True)
        # 营养：商品自建营养优先，其次沿关联原料（NutritionMixin 合并），基准是「每 X 单位」
        try:
            from app.services.nutrition_calculator import NutritionCalculator

            data = NutritionCalculator(db).calculate_product_nutrition(
                product.id, quantity or None, unit_abbr,
            )
            nutrients = (data or {}).get("nutrition") or {}
            all_nutrients = nutrients.get("all_nutrients") or {}
            if all_nutrients:
                ref_amount = float((data or {}).get("reference_amount") or 100.0) or 100.0
                ref_unit = (data or {}).get("reference_unit") or "g"
                qty_unit = unit_abbr or ref_unit
                qty_in_ref = quantity
                if qty_unit != ref_unit:
                    converter = UnitConversionService(db)
                    converted = converter.convert(
                        Decimal(str(quantity)), qty_unit, ref_unit,
                        entity_type="product", entity_id=product.id,
                    )
                    # 折算不出来时按「数量即基准单位」处理，不臆估
                    qty_in_ref = float(converted[0]) if converted else quantity
                factor = (qty_in_ref / ref_amount) if ref_amount else 0.0
                values: Dict[str, float] = {}
                for name, value in all_nutrients.items():
                    if not isinstance(value, dict) or value.get("value") is None:
                        continue
                    key = KEY_BY_NAME.get(name) or name
                    try:
                        number = float(value["value"]) * factor
                    except (TypeError, ValueError):
                        continue
                    if key == "energy":
                        number = energy_to_kcal(number, value.get("unit"))
                    if number:
                        values[key] = number
                if values:
                    out["nutrient_values"] = values
                    out["nutrition"] = {
                        "calories": _round2(values.get("energy", 0.0)),
                        "protein_g": _round2(values.get("protein", 0.0)),
                        "carbs_g": _round2(values.get("carbohydrate", 0.0)),
                        "fat_g": _round2(values.get("fat", 0.0)),
                    }
        except Exception:
            logger.debug(f"试算：商品 {product.id} 营养折算失败", exc_info=True)
        return out

    return out


async def evaluate_items(
    db: Session, user: User, items: List[Dict],
    kind: str = "meal", meal_type: str = "lunch", tz: str = "UTC",
) -> Dict:
    """评估一组未落库的条目（草稿）。items 为 schema dict。"""
    stub_items: List[MealPlanItem] = []
    for order, it in enumerate(items):
        stub_items.append(MealPlanItem(
            id=-(order + 1),  # 负 id 占位（不落库）
            sort_order=order,
            group=it.get("group") or "other",
            item_type=it.get("item_type") or "recipe",
            recipe_id=it.get("recipe_id"),
            ingredient_id=it.get("ingredient_id"),
            product_id=it.get("product_id"),
            servings=it.get("servings"),
            quantity=it.get("quantity"),
            unit_id=it.get("unit_id"),
            note=it.get("note"),
        ))
    # 为关系加载填充实体（stub 未入 session，relationship 不可用 → 手动查）
    from app.models.recipe import Recipe
    from app.models.product_entity import Product as ProductModel
    from app.models.unit import Unit

    for stub in stub_items:
        if stub.item_type == "recipe" and stub.recipe_id:
            stub.recipe = db.query(Recipe).get(stub.recipe_id)
        elif stub.item_type == "ingredient" and stub.ingredient_id:
            stub.ingredient = db.query(Ingredient).get(stub.ingredient_id)
        elif stub.item_type == "product" and stub.product_id:
            stub.product = db.query(ProductModel).get(stub.product_id)
        if stub.unit_id:
            stub.unit = db.query(Unit).get(stub.unit_id)

    return await _evaluate_stub_items(db, user, stub_items, kind, meal_type, tz)


async def evaluate_plan(
    db: Session, user: User, plan: MealPlan, tz: str = "UTC",
    meal_type: str = "lunch",
    group: Optional[str] = None,
) -> Dict:
    """评估已落库方案（plan.items 已在 session）。

    group：一日方案的条目分组（早/午/晚/其它）。传入时只评估该分组的条目，
    且目标比例按「这一餐」算 —— 「一日方案设为今日」靠它把三餐拆开。
    """
    items = list(plan.items)
    kind = plan.kind
    target_meal = meal_type
    if group and plan.kind == "day":
        items = [it for it in items if it.group == group]
        kind = "meal"
        target_meal = group if group in ("breakfast", "lunch", "dinner") else "lunch"
    return await _evaluate_stub_items(db, user, items, kind, target_meal, tz)


async def _evaluate_stub_items(
    db: Session, user: User, items: List[MealPlanItem],
    kind: str, meal_type: str, tz: str,
) -> Dict:
    from app.services.meal_recommender import MEAL_RATIOS

    eval_items = []
    totals = {"cost": 0.0, "currency": None,
              "calories": 0.0, "protein_g": 0.0, "carbs_g": 0.0, "fat_g": 0.0}
    for item in items:
        info = await _item_cost_nutrition(db, user, item, tz)
        eval_items.append(info)
        if info.get("cost") is not None:
            totals["cost"] = _round2(totals["cost"] + info["cost"])
            totals["currency"] = info.get("currency") or totals["currency"]
        n = info.get("nutrition")
        if n:
            for key in ("calories", "protein_g", "carbs_g", "fat_g"):
                totals[key] = _round2(totals[key] + float(n.get(key, 0) or 0))

    ratio = 1.0 if kind == "day" else MEAL_RATIOS.get(meal_type, MEAL_RATIOS["lunch"])
    targets = {
        "calories": _round2((user.daily_calorie_target or 2000) * ratio),
        "protein_g": _round2((user.daily_protein_target or 60) * ratio),
        "carbs_g": _round2((user.daily_carb_target or 300) * ratio),
        "fat_g": _round2((user.daily_fat_target or 65) * ratio),
    }
    if kind == "day" or user.daily_budget:
        budget = (user.daily_budget or 0) * (1.0 if kind == "day" else ratio)
        if budget:
            targets["cost"] = _round2(budget)

    deltas = {k: _round2(totals[k] - targets[k]) for k in targets if k in totals}

    nutrition_block = _build_plan_nutrition(eval_items)
    # 逐条目的原文（nutrient_values）不再回传，避免响应体过大
    for info in eval_items:
        info.pop("nutrient_values", None)

    return {
        "items": eval_items,
        "totals": totals,
        "targets": targets,
        "deltas": deltas,
        "nutrition": nutrition_block,
    }


def plan_cost_trend(
    db: Session, user: User, plan: MealPlan,
    days: int = 90, offset_days: int = 0, tz: str = "UTC",
) -> List[Dict]:
    """方案成本 as-of 逐日走势：菜谱项走 calculate_recipe_cost_range_trend 的
    avg 档（逐日、前向填充），原料/商品项按天取加权价 / 最新有效记录。"""
    from datetime import timedelta

    from app.services.recipe_service import calculate_recipe_cost_range_trend

    end = datetime.datetime.now(datetime.timezone.utc) - timedelta(days=offset_days)
    start = end - timedelta(days=days - 1)

    daily: Dict[str, Dict[str, Optional[float]]] = {
        (start + timedelta(days=i)).date().isoformat(): {
            "cost": 0.0, "min": 0.0, "max": 0.0, "currency": None,
        }
        for i in range(days)
    }

    recipe_items = [it for it in plan.items if it.item_type == "recipe"]
    loose_items = [it for it in plan.items if it.item_type != "recipe"]

    for item in recipe_items:
        servings = float(item.servings) if item.servings is not None else 1.0
        try:
            trend = calculate_recipe_cost_range_trend(
                item.recipe_id, user.id, db, days=days, offset_days=offset_days, tz=tz,
            )
            for point in trend:
                day = point.get("date")
                if day not in daily:
                    continue
                avg = point.get("avg_cost", point.get("avg"))
                if avg is not None:
                    daily[day]["cost"] = _round2(
                        daily[day]["cost"] + float(avg) * servings)
                mn = point.get("min_cost")
                mx = point.get("max_cost")
                if mn is not None:
                    daily[day]["min"] = _round2(daily[day]["min"] + float(mn) * servings)
                if mx is not None:
                    daily[day]["max"] = _round2(daily[day]["max"] + float(mx) * servings)
                if daily[day]["currency"] is None and point.get("currency"):
                    daily[day]["currency"] = point["currency"]
        except Exception:
            logger.debug(f"趋势：菜谱 {item.recipe_id} 失败", exc_info=True)

    now = datetime.datetime.now(datetime.timezone.utc)
    for item in loose_items:
        quantity = float(item.quantity or 0)
        unit_abbr = item.unit.abbreviation if item.unit else "g"
        if item.item_type == "ingredient":
            for i in range(days):
                day = (start + timedelta(days=i)).date().isoformat()
                as_of = datetime.datetime.fromisoformat(day + "T12:00:00+00:00")
                try:
                    weighted = get_weighted_ingredient_price(
                        db, item.ingredient_id, as_of_date=as_of,
                        user_id=user.id, target_unit_abbr=unit_abbr, tz=tz,
                    )
                    unit_price = weighted.get("unit_price")
                    if unit_price is not None:
                        daily[day]["cost"] = _round2(
                            daily[day]["cost"] + float(unit_price) * quantity)
                        daily[day]["min"] = _round2(
                            daily[day]["min"] + float(unit_price) * quantity)
                        daily[day]["max"] = _round2(
                            daily[day]["max"] + float(unit_price) * quantity)
                        if daily[day]["currency"] is None and weighted.get("currency"):
                            daily[day]["currency"] = weighted["currency"]
                except Exception:
                    continue
        elif item.item_type == "product":
            try:
                record = (
                    db.query(ProductRecord)
                    .filter(
                        ProductRecord.product_id == item.product_id,
                        ProductRecord.is_active == True,  # noqa: E712
                    )
                    .order_by(ProductRecord.recorded_at.desc())
                    .first()
                )
            except Exception:
                record = None
            if record is None or record.price is None:
                continue
            std_qty = float(record.standard_quantity or 1) or 1.0
            unit_price = float(record.price) / std_qty
            qty = quantity
            if item.unit is not None and record.standard_unit is not None \
                    and item.unit.abbreviation != record.standard_unit.abbreviation:
                try:
                    converter = UnitConversionService(db)
                    converted = converter.convert(
                        Decimal(str(quantity)), item.unit.abbreviation,
                        record.standard_unit.abbreviation,
                        entity_type="product", entity_id=item.product_id,
                    )
                    qty = float(converted[0]) if converted else quantity
                except Exception:
                    pass
            # 最新价语义：前向填充到整个窗口
            for day in daily:
                daily[day]["cost"] = _round2(daily[day]["cost"] + unit_price * qty)
                daily[day]["min"] = _round2(daily[day]["min"] + unit_price * qty)
                daily[day]["max"] = _round2(daily[day]["max"] + unit_price * qty)
                if daily[day]["currency"] is None and record.currency:
                    daily[day]["currency"] = record.currency

    return [
        {
            "date": day,
            "total_cost": info["cost"],
            "min_cost": info["min"],
            "max_cost": info["max"],
            "avg_cost": info["cost"],
            "currency": info["currency"],
        }
        for day, info in sorted(daily.items())
    ]
