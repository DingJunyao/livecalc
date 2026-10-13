"""
独立的迷你图数据 API

提供批量查询各类实体的近N天价格/成本趋势数据，
与主列表 API 分离，避免列表加载超时。
"""
import asyncio
from concurrent.futures import ThreadPoolExecutor
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Dict, Optional
from collections import defaultdict
from datetime import date, datetime, timedelta

from app.core.database import get_db
from app.core.security import get_current_user
from app.api.deps import get_timezone
from app.services.calc_scope import resolve_region_param
from app.services.price_region import apply_region_filter, record_price_in_user_currency
from app.utils.date_range_utils import utc_datetime_to_local_date
from app.models.product import ProductRecord
from app.models.product_entity import Product
from app.models.nutrition import Ingredient
from app.models.recipe import Recipe
from app.core.exceptions import LocalizedHTTPException

router = APIRouter(tags=["sparklines"])


def _unit_price_per_jin(db, row) -> float:
    """记录 → ¥/斤 单价（按记录时用户币种快照折算 + 500g 归一化）。

    体积标准的历史遗留记录经实体密度折克（record_standard_grams）。
    """
    from app.services.price_aggregator import record_standard_grams
    grams = record_standard_grams(db, row.standard_quantity, row.standard_unit_id, row.product_id)
    return float(record_price_in_user_currency(row)) * 500.0 / grams


def _forward_fill_daily(day_values: Dict[str, float], tz: str) -> List[float]:
    """按本地日历日从首个有值日填充到今天，无记录日沿用前一日的值。

    迷你图 X 轴语义是时间：每天占一格，点间距才能反映真实天数间隔。
    价格在两次记录之间视为不变（与成本计算的前向填充口径一致），
    久未更新时表现为长平尾。调用方传入的值已完成聚合与舍入。
    """
    if not day_values:
        return []
    d0 = date.fromisoformat(min(day_values.keys()))
    d1 = utc_datetime_to_local_date(datetime.utcnow(), tz)
    out: List[float] = []
    last: Optional[float] = None
    cur = d0
    while cur <= d1:
        v = day_values.get(cur.isoformat())
        if v is not None:
            last = v
        if last is not None:
            out.append(last)
        cur += timedelta(days=1)
    return out


def _fetch_recent_records(db: Session, product_ids: List[int], days: int, region_id: Optional[int]):
    """一次拉取一组商品近 N 天的价格记录（region 过滤），按 recorded_at 升序。

    与旧版「逐商品分别查询 ORDER BY recorded_at」同源同序：同一商品内记录
    的相对顺序一致，保证逐日聚合的浮点累加顺序不变。
    必须带上 standard_unit_id：_unit_price_per_jin → record_standard_grams 需要它
    （体积语义折克），漏选会在取用时抛 AttributeError。
    """
    if not product_ids:
        return []
    cutoff = datetime.utcnow() - timedelta(days=days)
    q = db.query(
        ProductRecord.product_id,
        ProductRecord.price,
        ProductRecord.exchange_rate,
        ProductRecord.standard_quantity,
        ProductRecord.standard_unit_id,
        ProductRecord.recorded_at,
    ).filter(
        ProductRecord.product_id.in_(product_ids),
        ProductRecord.recorded_at >= cutoff,
        ProductRecord.price.isnot(None),
        ProductRecord.is_active == True,  # noqa: E712
    ).order_by(ProductRecord.recorded_at)
    return apply_region_filter(q, db, region_id).all()


def _fetch_carry_forward_seeds(
    db: Session,
    product_ids: List[int],
    days: int,
    tz: str,
    region_id: Optional[int],
):
    """每个商品在窗口起点之前的「最近有记录日」的全部记录（as-of 携带起点）。

    综合价语义是「某商品的最近一次价格一直有效」，所以窗口前最后一次记录价必须
    参与窗口内每一天的加权；否则久未记录的商品会在图上整段消失，综合价退化成
    单品价。以「日」为单位取（与 _collect_recent_records 同口径），保证同日多条
    记录仍取当天均价。
    """
    if not product_ids:
        return []
    from app.services.ingredient_price_service import _collect_recent_records

    cutoff = datetime.utcnow() - timedelta(days=days)
    seeds = []
    for pid in product_ids:
        seeds.extend(_collect_recent_records(db, pid, cutoff, tz=tz, region_id=region_id))
    return seeds


def _weight_map(db: Session, product_ids: List[int], user_id: Optional[int]) -> dict:
    """商品权重表：全局 price_weight ← 用户覆盖（优先）。一次批量查询。"""
    if not product_ids:
        return {}
    pw: dict = {pid: w for pid, w in db.query(Product.id, Product.price_weight)
                .filter(Product.id.in_(product_ids)).all()}
    if user_id is not None:
        from app.models.user_product_weight_override import UserProductWeightOverride
        ov = {r.product_id: r.weight for r in db.query(UserProductWeightOverride).filter(
            UserProductWeightOverride.user_id == user_id,
            UserProductWeightOverride.product_id.in_(product_ids),
            UserProductWeightOverride.is_active == True,  # noqa: E712
        ).all()}
        pw = {k: ov.get(k, v) for k, v in pw.items()}
    return pw


def _daily_avg_for_product_ids(
    db: Session,
    product_ids: List[int],
    days: int = 90,
    ingredient_id: Optional[int] = None,
    user_id: Optional[int] = None,
    tz: str = "UTC",
    region_id: Optional[int] = None,
) -> List[float]:
    """计算一组商品在近N天内的每日平均价格（单实体版，批量端点已改用批量路径）。

    - 传 ingredient_id：商品内日均 → 商品间按 price_weight 加权（原料 sparkline 用，
      修正「记录多的商品被放大」的偏置）。
    - 不传：退化为记录级日均（旧行为，商品 sparkline 用）。
    归一化到 ¥/斤（1斤=500g），按 standard_quantity 确保跨单位可比。
    返回按日历日前向填充后的序列（每天一格，无记录日沿用前值）。
    """
    if not product_ids:
        return []

    records = _fetch_recent_records(db, product_ids, days, region_id)
    pw = _weight_map(db, product_ids, user_id if ingredient_id is not None else None)

    # 按日 + 按商品：{date: {product_id: [unit_price,...]}}
    by_day_product: dict = defaultdict(dict)
    for row in records:
        unit_price = _unit_price_per_jin(db, row)
        dkey = utc_datetime_to_local_date(row.recorded_at, tz).isoformat()
        by_day_product[dkey].setdefault(row.product_id, []).append(unit_price)

    daily: dict = {}
    for dkey in sorted(by_day_product.keys()):
        prods = by_day_product[dkey]
        if ingredient_id is not None:
            # 商品级加权：每商品先均价，再按权重加权
            num = den = 0.0
            for pid, ups in prods.items():
                w = pw.get(pid, 50)
                if w <= 0 or not ups:
                    continue
                num += (sum(ups) / len(ups)) * w
                den += w
            avg = num / den if den > 0 else None
        else:
            all_up = [up for ups in prods.values() for up in ups]
            avg = sum(all_up) / len(all_up) if all_up else None
        if avg is not None:
            daily[dkey] = round(avg, 2)
    return _forward_fill_daily(daily, tz)


def _products_sparklines_batched(
    db: Session,
    product_ids: List[int],
    days: int,
    tz: str,
    region_id: Optional[int],
) -> Dict[str, Optional[List[float]]]:
    """商品 sparkline 批量版：一次记录查询，内存按 (商品, 日) 分组做记录级日均。

    聚合口径与 _daily_avg_for_product_ids([pid])（ingredient_id=None，记录级日均）
    完全一致，只是消除了逐商品 N+1 查询。返回前向填充到今天的日历日序列。
    """
    rows = _fetch_recent_records(db, product_ids, days, region_id)
    # {pid: {date: [unit_price,...]}}；记录按 recorded_at 升序流入，append 顺序与单查版一致
    by_pid_day: dict = defaultdict(lambda: defaultdict(list))
    for row in rows:
        by_pid_day[row.product_id][utc_datetime_to_local_date(row.recorded_at, tz).isoformat()].append(
            _unit_price_per_jin(db, row)
        )
    result: Dict[str, Optional[List[float]]] = {}
    for pid in product_ids:
        day_map = by_pid_day.get(pid)
        if not day_map:
            result[str(pid)] = None
            continue
        daily: dict = {}
        for dkey in sorted(day_map.keys()):
            ups = day_map[dkey]
            daily[dkey] = round(sum(ups) / len(ups), 2)
        result[str(pid)] = _forward_fill_daily(daily, tz) or None
    return result


def _ingredients_sparklines_batched(
    db: Session,
    ingredient_ids: List[int],
    days: int,
    user_id: Optional[int],
    tz: str,
    region_id: Optional[int],
) -> Dict[str, Optional[List[float]]]:
    """原料 sparkline 批量版：一次记录/权重查询，内存按商品组装「as-of 加权」序列。

    口径与原料详情页趋势图、综合最新价、菜谱成本一致：
      - 每个商品的价格 = 该商品「最近有记录日」的均价（同日多条取均价）
      - 该价格一直有效到下一次记录；窗口起点之前的最近一次记录作为起点携带，
        否则久未记录的商品会在图上整段消失，综合价退化成单品价
      - 每日综合价 = 各商品当日有效价按权重（用户覆盖 > price_weight > 50）加权
    参与上限：商品最近一次价格超过 INGREDIENT_PRICE_STALE_DAYS 天不再参与当日综合价
    （与综合最新价的 excluded[reason="stale"] 同一规则，保证卡片与图表对得上）。
    返回按本地日历日、从窗口起点到今天的一格一天序列。
    """
    from app.services.ingredient_price_service import INGREDIENT_PRICE_STALE_DAYS

    products = db.query(Product.id, Product.ingredient_id).filter(
        Product.ingredient_id.in_(ingredient_ids),
        Product.is_active == True,  # noqa: E712
    ).all()
    ing_to_prods: dict = defaultdict(list)
    all_pids: List[int] = []
    for prod_id, ing_id in products:
        ing_to_prods[ing_id].append(prod_id)
        all_pids.append(prod_id)

    rows = _fetch_recent_records(db, all_pids, days, region_id)
    seeds = _fetch_carry_forward_seeds(db, all_pids, days, tz, region_id)
    pw = _weight_map(db, all_pids, user_id)

    # {pid: {本地日: [unit_price,...]}}（含窗口前的携带起点）
    steps: dict = defaultdict(lambda: defaultdict(list))
    for row in rows + seeds:
        steps[row.product_id][utc_datetime_to_local_date(row.recorded_at, tz)].append(
            _unit_price_per_jin(db, row)
        )

    today = utc_datetime_to_local_date(datetime.utcnow(), tz)
    window_start = today - timedelta(days=days)

    result: Dict[str, Optional[List[float]]] = {}
    for ing_id in ingredient_ids:
        # 每商品一个日升序阶梯 + 游标（逐日推进只前进不回退）
        per_pid_steps: dict = {}
        first_day = None
        for pid in ing_to_prods.get(ing_id) or []:
            by_day = steps.get(pid)
            if not by_day:
                continue
            ordered = sorted((d, sum(v) / len(v)) for d, v in by_day.items())
            per_pid_steps[pid] = [ordered, 0, None, ordered[-1][0] + timedelta(days=INGREDIENT_PRICE_STALE_DAYS)]
            first_day = ordered[0][0] if first_day is None else min(first_day, ordered[0][0])
        if first_day is None:
            result[str(ing_id)] = None
            continue

        series: List[float] = []
        cur = max(first_day, window_start)
        while cur <= today:
            num = den = 0.0
            for pid, state in per_pid_steps.items():
                ordered, idx, value, expires_on = state
                while idx < len(ordered) and ordered[idx][0] <= cur:
                    value = ordered[idx][1]
                    idx += 1
                state[1], state[2] = idx, value
                w = pw.get(pid, 50)
                if value is None or w <= 0:
                    continue
                if cur > expires_on:
                    continue
                num += value * w
                den += w
            if den > 0:
                series.append(round(num / den, 2))
            cur += timedelta(days=1)
        result[str(ing_id)] = series or None
    return result


@router.get("/sparklines/recipes")
async def get_recipes_sparklines(
    ids: str = Query(..., description="菜谱ID列表，逗号分隔"),
    days: int = Query(90, ge=7, le=365, description="查询天数"),
    region_id: Optional[int] = Query(None, description="按商家地区子树过滤（默认不过滤）"),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
    tz: str = Depends(get_timezone),
) -> Dict[str, Optional[List[float]]]:
    """批量获取菜谱迷你图数据（多线程并发）"""
    region_id = resolve_region_param(db, current_user, region_id)
    try:
        id_list = [int(x.strip()) for x in ids.split(",") if x.strip()]
        if not id_list:
            return {}

        from app.core.database import SessionLocal
        from app.services.recipe_service import calculate_recipe_cost_range_trend

        def _compute_one(rid: int) -> tuple:
            """在独立 DB session 中计算单个菜谱的成本趋势"""
            session = SessionLocal()
            try:
                trend = calculate_recipe_cost_range_trend(rid, current_user.id, session, days=days, tz=tz, region_id=region_id)
                if trend:
                    # 趋势本身逐天计算但无价日缺失；按日历日前向填充，
                    # 保证迷你图每天一格、点间距反映真实天数间隔
                    day_values = {
                        t["date"]: t["avg_cost"]
                        for t in trend
                        if t.get("date") and t.get("avg_cost") is not None
                    }
                    data = _forward_fill_daily(day_values, tz)
                    return (str(rid), data if data else None)
                return (str(rid), None)
            except Exception:
                return (str(rid), None)
            finally:
                session.close()

        loop = asyncio.get_event_loop()
        with ThreadPoolExecutor(max_workers=min(len(id_list), 8)) as pool:
            futures = [loop.run_in_executor(pool, _compute_one, rid) for rid in id_list]
            results = await asyncio.gather(*futures)

        return {k: v for k, v in results}

    except Exception as e:
        raise LocalizedHTTPException(status_code=500, message='获取菜谱迷你图失败: {error}', error=str(e))


@router.get("/sparklines/ingredients")
async def get_ingredients_sparklines(
    ids: str = Query(..., description="原料ID列表，逗号分隔"),
    days: int = Query(90, ge=7, le=365, description="查询天数"),
    region_id: Optional[int] = Query(None, description="按商家地区子树过滤（默认不过滤）"),
    db: Session = Depends(get_db),
    _current_user=Depends(get_current_user),
    tz: str = Depends(get_timezone),
) -> Dict[str, Optional[List[float]]]:
    """批量获取原料迷你图数据（跨所有关联商品聚合）"""
    region_id = resolve_region_param(db, _current_user, region_id)
    try:
        id_list = [int(x.strip()) for x in ids.split(",") if x.strip()]
        if not id_list:
            return {}

        return _ingredients_sparklines_batched(
            db, id_list, days=days, user_id=_current_user.id, tz=tz, region_id=region_id
        )
    except Exception as e:
        raise LocalizedHTTPException(status_code=500, message='获取原料迷你图失败: {error}', error=str(e))


@router.get("/sparklines/products")
async def get_products_sparklines(
    ids: str = Query(..., description="商品ID列表，逗号分隔"),
    days: int = Query(90, ge=7, le=365, description="查询天数"),
    region_id: Optional[int] = Query(None, description="按商家地区子树过滤（默认不过滤）"),
    db: Session = Depends(get_db),
    _current_user=Depends(get_current_user),
    tz: str = Depends(get_timezone),
) -> Dict[str, Optional[List[float]]]:
    """批量获取商品迷你图数据"""
    region_id = resolve_region_param(db, _current_user, region_id)
    try:
        id_list = [int(x.strip()) for x in ids.split(",") if x.strip()]
        if not id_list:
            return {}

        return _products_sparklines_batched(db, id_list, days=days, tz=tz, region_id=region_id)
    except Exception as e:
        raise LocalizedHTTPException(status_code=500, message='获取商品迷你图失败: {error}', error=str(e))
