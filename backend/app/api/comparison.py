"""跨地区物价对比 API。

对 N 个地区各跑一遍既有的批量加权价管道（sparklines 同口径：每商品
「最近有记录日」均价前向携带、30 天参与上限、全部超期时放开），产出：

  - GET /comparison/regions        有价格数据的地区候选
  - GET /comparison/summary        各地区概览（记录/商品规模 + 物价指数 + 篮子趋势）
  - GET /comparison/entity-prices  实体×地区价格矩阵（卡片价 + 趋势）

口径说明：
  - 每个传入的 region_id 单独作为一棵地区子树过滤（与「按商家」对比的
    每商家一列同构）；会话 X-Region 是「并集范围」语义，不在这里复用。
  - 卡片价 = mode="recent" 综合价口径（每标准单位、用户币种），使地区卡
    与详情页综合价可直接对照。
  - 趋势 = ¥/斤 归一（与列表迷你图一致），跨商品可比。
  - 取数窗口 365 天：卡片价/篮子只看近一年有记录的商品（趋势携带起点
    必然落在窗口内）。
"""
from collections import defaultdict
from datetime import datetime, timedelta
from statistics import median
from typing import Any, Dict, List, Optional, Tuple

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import desc, func, or_
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.exceptions import LocalizedHTTPException
from app.core.i18n import request_locale
from app.core.security import get_current_user
from app.api.deps import get_timezone
from app.api.sparklines import (
    _ingredients_sparklines_batched,
    _products_sparklines_batched,
    _unit_price_per_jin,
    _weight_map,
)
from app.services.ingredient_price_service import INGREDIENT_PRICE_STALE_DAYS
from app.services.currency_service import get_user_default_currency
from app.services.catalog_display import region_display_name
from app.services.meal_plan_service import evaluate_items, evaluate_plan, plan_cost_trend
from app.services.recipe_service import (
    calculate_recipe_cost_as_of,
    calculate_recipe_cost_range_trend,
)
from app.services.price_region import (
    apply_region_filter,
    is_stale_recorded_at,
    record_price_in_user_currency,
    region_subtree_ids,
)
from app.models.administrative_region import AdministrativeRegion
from app.models.merchant import Merchant
from app.models.product import ProductRecord
from app.models.product_entity import Product
from app.models.nutrition import Ingredient
from app.models.recipe import Recipe
from app.schemas.comparison import (
    ComparisonSummaryResponse,
    EntityPriceRow,
    EntityPricesResponse,
    EntityRegionPrice,
    PlanEvaluateRegionsBody,
    PlanEvaluateRegionsResponse,
    PlanRegionTotals,
    RecipeBreakdownItem,
    RecipeCostRow,
    RecipeCostsResponse,
    RecipeRegionCost,
    RegionCandidate,
    RegionCandidatesResponse,
    RegionMeta,
    RegionSummaryItem,
)
from app.utils.date_range_utils import utc_datetime_to_local_date

router = APIRouter(tags=["跨地区对比"])

MAX_COMPARISON_REGIONS = 6
MAX_COMPARISON_ENTITIES = 50
MAX_COMPARISON_RECIPES = 10
MAX_COMPARISON_PLANS = 10
# 卡片价/篮子的取数窗口：近一年有记录才参与（趋势携带起点必然落在窗口内）
BASKET_WINDOW_DAYS = 365


def _parse_region_ids(raw: str) -> List[int]:
    """逗号分隔地区 ID：去重保序、1..6 个（第一个为基准地区）。"""
    values: List[int] = []
    for part in raw.split(","):
        text = part.strip()
        if not text:
            continue
        try:
            value = int(text)
        except ValueError as exc:
            raise LocalizedHTTPException(status_code=400, message="地区 ID 列表格式无效: {error}", error=str(exc))
        if value <= 0:
            raise LocalizedHTTPException(status_code=400, message="地区 ID 列表格式无效: {error}", error="地区 ID 必须为正整数")
        if value not in values:
            values.append(value)
    if not values:
        raise LocalizedHTTPException(status_code=400, message="地区 ID 列表格式无效: {error}", error="至少需要一个地区")
    if len(values) > MAX_COMPARISON_REGIONS:
        raise LocalizedHTTPException(
            status_code=400,
            message="地区 ID 列表格式无效: {error}",
            error=f"一次最多对比 {MAX_COMPARISON_REGIONS} 个地区",
        )
    return values


def _resolve_compare_items(db: Session, user, raw: str, locale: str = "zh-CN") -> List[Dict[str, Any]]:
    """解析对比项列表（保序去重，≤6）。每项可作为独立对比列。

    项格式：
      - ``<int>``        行政区划地区 id（spec = 该 id，子树过滤）
      - ``s<int>``       用户自定义计算范围 id（spec = 范围内地区 id 的
                         **tuple 并集**——region_subtree_ids/apply_region_filter
                         原生支持，一个范围作为一棵合并子树参与对比）

    返回 [{spec, resp_id, name, display_name, level}]：
      - 地区项 resp_id = 地区 id；范围项 resp_id = -(scope.id)（负数区分，
        前端矩阵/趋势/摘要的 key 结构不变，仅数字不同）
      - display_name：地区经 region_display_name 本地化；范围取 scope.name
    """
    from app.models.user_calc_scope import UserCalcScope

    seen_keys: List[str] = []
    items_raw: List[str] = []
    region_ids_needed: List[int] = []
    scope_ids: List[int] = []
    for part in raw.split(","):
        text = part.strip()
        if not text:
            continue
        if text.startswith("s") and text[1:].isdigit():
            sid = int(text[1:])
            if sid <= 0:
                raise LocalizedHTTPException(status_code=400, message="地区 ID 列表格式无效: {error}", error="范围 ID 必须为正整数")
            key = f"s{sid}"
            if key not in seen_keys:
                seen_keys.append(key)
                items_raw.append(key)
                scope_ids.append(sid)
        else:
            try:
                value = int(text)
            except ValueError as exc:
                raise LocalizedHTTPException(status_code=400, message="地区 ID 列表格式无效: {error}", error=str(exc))
            if value <= 0:
                raise LocalizedHTTPException(status_code=400, message="地区 ID 列表格式无效: {error}", error="地区 ID 必须为正整数")
            key = str(value)
            if key not in seen_keys:
                seen_keys.append(key)
                items_raw.append(key)
                region_ids_needed.append(value)
    if not items_raw:
        raise LocalizedHTTPException(status_code=400, message="地区 ID 列表格式无效: {error}", error="至少需要一个地区")
    if len(items_raw) > MAX_COMPARISON_REGIONS:
        raise LocalizedHTTPException(
            status_code=400,
            message="地区 ID 列表格式无效: {error}",
            error=f"一次最多对比 {MAX_COMPARISON_REGIONS} 个地区",
        )

    # 批量取名称：地区 + 范围（scope 归属校验：只能用自己建的）
    regions_by_id = _load_regions(db, region_ids_needed)
    scope_by_id: Dict[int, Any] = {}
    if scope_ids:
        for row in db.query(UserCalcScope).filter(
            UserCalcScope.id.in_(scope_ids),
            UserCalcScope.user_id == user.id,
        ).all():
            scope_by_id[row.id] = row

    out: List[Dict[str, Any]] = []
    for key in items_raw:
        if key.startswith("s"):
            sid = int(key[1:])
            scope = scope_by_id.get(sid)
            if scope is None:
                raise LocalizedHTTPException(status_code=404, message="自定义计算范围不存在: {error}", error=f"s{sid}")
            region_list = tuple(dict.fromkeys(int(r) for r in (scope.region_ids or [])))
            if not region_list:
                raise LocalizedHTTPException(status_code=400, message="地区 ID 列表格式无效: {error}", error=f"范围「{scope.name}」不含任何地区")
            out.append({
                "spec": region_list,          # tuple 并集（子树合并为一棵）
                "resp_id": -sid,              # 负数区分范围项
                "name": scope.name,
                "display_name": scope.name,
                "level": 0,
            })
        else:
            rid = int(key)
            region = regions_by_id.get(rid)
            out.append({
                "spec": rid,
                "resp_id": rid,
                "name": region.name if region else str(rid),
                "display_name": region_display_name(region, locale) if region else str(rid),
                "level": region.level if region else 0,
            })
    return out


def _items_region_metas(items: List[Dict[str, Any]]) -> List[RegionMeta]:
    """对比项 → RegionMeta（响应列头/名称映射；scope 项负数 resp_id + 范围名）。"""
    return [
        RegionMeta(
            region_id=item["resp_id"],
            name=item["name"],
            display_name=item["display_name"],
            level=item["level"],
        )
        for item in items
    ]


def _parse_entity_ids(raw: str, limit: int = MAX_COMPARISON_ENTITIES) -> List[int]:
    """逗号分隔实体 ID：去重保序、最多 limit 个。"""
    values: List[int] = []
    for part in raw.split(","):
        text = part.strip()
        if not text:
            continue
        try:
            value = int(text)
        except ValueError as exc:
            raise LocalizedHTTPException(status_code=400, message="实体 ID 列表格式无效: {error}", error=str(exc))
        if value <= 0:
            raise LocalizedHTTPException(status_code=400, message="实体 ID 列表格式无效: {error}", error="实体 ID 必须为正整数")
        if value not in values:
            values.append(value)
    if not values:
        raise LocalizedHTTPException(status_code=400, message="实体 ID 列表格式无效: {error}", error="至少需要一个实体")
    if len(values) > limit:
        raise LocalizedHTTPException(
            status_code=400,
            message="实体 ID 列表格式无效: {error}",
            error=f"一次最多支持 {limit} 个实体",
        )
    return values


def _load_regions(db: Session, rids: List[int]) -> Dict[int, AdministrativeRegion]:
    rows = db.query(AdministrativeRegion).filter(
        AdministrativeRegion.id.in_(rids),
        AdministrativeRegion.is_active == True,  # noqa: E712
    ).all()
    return {r.id: r for r in rows}


class _RegionPriceData:
    """单地区一次取数的结果：卡片价、趋势阶梯、陈旧标记共用同一批记录。"""

    def __init__(self):
        # pid → 最近有记录日均价（**¥/斤 归一**，用户/会话币种）。跨地区比价
        # 必须用统一口径：同一原料在不同地区的参与商品包装/标准单位不同
        #（按根 vs 按克），每标准单位价（price/standard_quantity）不可比。
        self.prices: Dict[int, float] = {}
        self.steps: Dict[int, dict] = {}          # pid → {本地日: [每斤单价,...]}（趋势口径）
        self.latest: Dict[int, object] = {}       # pid → 最近有记录的本地日
        self.units: Dict[int, Optional[str]] = {} # pid → 最近记录的标准单位缩写


def _region_price_data(db: Session, region_id: int, product_ids: List[int], tz: str) -> _RegionPriceData:
    """一次拉取地区子树内这些商品近一年的记录，组装卡片价/趋势/陈旧三份数据。

    region_id 过滤经 apply_region_filter（未分配地区的商家在所有地区都计入）。
    """
    from app.services.lookup_cache import unit_by_id

    data = _RegionPriceData()
    if not product_ids:
        return data
    cutoff = datetime.utcnow() - timedelta(days=BASKET_WINDOW_DAYS)
    q = db.query(
        ProductRecord.product_id,
        ProductRecord.price,
        ProductRecord.exchange_rate,
        ProductRecord.standard_quantity,
        ProductRecord.standard_unit_id,
        ProductRecord.recorded_at,
    ).filter(
        ProductRecord.product_id.in_(product_ids),
        ProductRecord.is_active == True,  # noqa: E712
        ProductRecord.price.isnot(None),
        ProductRecord.recorded_at >= cutoff,
    ).order_by(ProductRecord.recorded_at)
    rows = apply_region_filter(q, db, region_id).all()

    # {pid: {本地日: [row,...]}}（同日多条记录取均价，与「最近有记录日」口径一致）
    by_pid_day: Dict[int, dict] = defaultdict(lambda: defaultdict(list))
    for row in rows:
        day = utc_datetime_to_local_date(row.recorded_at, tz)
        by_pid_day[row.product_id][day].append(row)

    for pid, by_day in by_pid_day.items():
        latest_day = max(by_day)
        latest_rows = by_day[latest_day]
        # 卡片价与趋势同一 ¥/斤 口径（跨地区可比；同商品内多记录取均价）
        jin_prices = [_unit_price_per_jin(db, r) for r in latest_rows]
        data.prices[pid] = sum(jin_prices) / len(jin_prices)
        data.latest[pid] = latest_day
        data.steps[pid] = {
            d: [_unit_price_per_jin(db, r) for r in day_rows]
            for d, day_rows in by_day.items()
        }
        unit_row = unit_by_id(db, latest_rows[-1].standard_unit_id)
        data.units[pid] = unit_row.abbreviation if unit_row else None
    return data


def _entity_card_price(
    data: _RegionPriceData,
    pids: List[int],
    pw: Dict[int, int],
    today,
) -> Tuple[Optional[float], Optional[str], bool, Optional[int], int]:
    """单实体的卡片价：mode="recent" 综合价口径，**¥/斤 归一**。

    每商品取「最近有记录日」的每斤均价 → 30 天参与上限（全部超期放开）
    → 按权重（用户覆盖 > price_weight > 50）加权。¥/斤 保证跨地区/跨包装可比
    （同一原料在不同地区的参与商品标准单位可能不同）。
    返回 (price, unit, is_stale, days_since_record, participant_count)。
    """
    pids_with = [p for p in pids if p in data.prices]
    if not pids_with:
        return None, None, False, None, 0
    fresh = [p for p in pids_with
             if (today - data.latest[p]).days <= INGREDIENT_PRICE_STALE_DAYS]
    pool = fresh or pids_with  # 全部超期时放开（宁可显示旧价格，也不能没有价格）
    num = den = 0.0
    for pid in pool:
        w = pw.get(pid, 50)
        if w <= 0:
            continue
        num += data.prices[pid] * w
        den += w
    price = round(num / den, 2) if den > 0 else None
    # 单位固定「斤」（¥/斤 口径；各参与商品的标准单位可能不同，不再透传）
    unit = "斤"
    days_since = min((today - data.latest[p]).days for p in pids_with)
    return price, unit, not fresh, days_since, len(pool)


@router.get("/regions", response_model=RegionCandidatesResponse)
async def list_priced_regions(
    request: Request,
    db: Session = Depends(get_db),
    _current_user=Depends(get_current_user),
):
    """有价格记录的地区候选（按记录数降序）。

    供对比页的地区选择器使用；无商家归属的记录不产生地区候选。
    """
    try:
        rows = (
            db.query(
                AdministrativeRegion,
                func.count(ProductRecord.id).label("record_count"),
                func.count(func.distinct(ProductRecord.merchant_id)).label("merchant_count"),
            )
            .join(Merchant, Merchant.region_id == AdministrativeRegion.id)
            .join(ProductRecord, ProductRecord.merchant_id == Merchant.id)
            .filter(
                ProductRecord.is_active == True,  # noqa: E712
                ProductRecord.price.isnot(None),
                AdministrativeRegion.is_active == True,  # noqa: E712
            )
            .group_by(AdministrativeRegion.id)
            .order_by(desc(func.count(ProductRecord.id)))
            .all()
        )
        locale = request_locale(request)
        regions = [
            RegionCandidate(
                region_id=region.id,
                code=region.code,
                name=region.name,
                name_en=region.name_en,
                display_name=region_display_name(region, locale),
                level=region.level,
                path=region.path,
                record_count=record_count,
                merchant_count=merchant_count,
            )
            for region, record_count, merchant_count in rows
        ]
        return RegionCandidatesResponse(regions=regions)
    except LocalizedHTTPException:
        raise
    except Exception as e:
        raise LocalizedHTTPException(status_code=500, message="获取对比地区失败: {error}", error=str(e))


@router.get("/summary", response_model=ComparisonSummaryResponse)
async def comparison_summary(
    request: Request,
    region_ids: str = Query(..., description="对比项列表，逗号分隔（≤6，第一个为基准项；支持地区 id 与 s<范围id>）"),
    days: int = Query(30, ge=7, le=90, description="篮子趋势天数"),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
    tz: str = Depends(get_timezone),
):
    """各地区概览：记录数/商品数 + 物价指数 + 共同商品篮子日均价趋势。

    篮子 = 基准项（region_ids 第一个）近一年有记录的商品；物价指数 =
    各项对篮子商品的「单价比率（项价 / 基准价）」中位数 × 100。
    项可为地区或自定义计算范围（s<id>，范围内子树并集）。
    """
    try:
        locale = request_locale(request)
        compare_items = _resolve_compare_items(db, current_user, region_ids, locale)
        currency = get_user_default_currency(db, current_user)
        today = utc_datetime_to_local_date(datetime.utcnow(), tz)
        base_spec = compare_items[0]["spec"]
        base_resp_id = compare_items[0]["resp_id"]

        # 篮子：基准项近一年有记录的商品
        cutoff = datetime.utcnow() - timedelta(days=BASKET_WINDOW_DAYS)
        basket_q = db.query(ProductRecord.product_id.distinct()).filter(
            ProductRecord.is_active == True,  # noqa: E712
            ProductRecord.price.isnot(None),
            ProductRecord.recorded_at >= cutoff,
        )
        basket_rows = apply_region_filter(basket_q, db, base_spec).all()
        basket_pids = [r[0] for r in basket_rows]

        pw = _weight_map(db, basket_pids, current_user.id)
        base_data = _region_price_data(db, base_spec, basket_pids, tz)

        items: List[RegionSummaryItem] = []
        for idx, item in enumerate(compare_items):
            spec = item["spec"]
            data = base_data if idx == 0 else _region_price_data(db, spec, basket_pids, tz)
            ratios = [
                data.prices[pid] / base_data.prices[pid]
                for pid in basket_pids
                if pid in data.prices and pid in base_data.prices and base_data.prices[pid] > 0
            ]
            price_index = round(median(ratios) * 100, 1) if ratios else None
            count_q = db.query(
                func.count(ProductRecord.id),
                func.count(func.distinct(ProductRecord.product_id)),
            ).filter(
                ProductRecord.is_active == True,  # noqa: E712
                ProductRecord.price.isnot(None),
            )
            record_count, entity_count = apply_region_filter(count_q, db, spec).one()
            trend = _basket_daily_series(data.steps, pw, days, tz)
            items.append(RegionSummaryItem(
                region_id=item["resp_id"],
                name=item["name"],
                display_name=item["display_name"],
                record_count=record_count,
                entity_count=entity_count,
                price_index=price_index,
                trend=trend,
            ))
        return ComparisonSummaryResponse(
            currency=currency,
            base_region_id=base_resp_id,
            basket_size=len(basket_pids),
            regions=items,
        )
    except LocalizedHTTPException:
        raise
    except Exception as e:
        raise LocalizedHTTPException(status_code=500, message="获取对比概览失败: {error}", error=str(e))


def _basket_daily_series(by_pid_day: Dict[int, dict], pw: Dict[int, int], days: int, tz: str) -> List[float]:
    """篮子日均价：每商品「最近有记录日」均价前向携带 + 30 天参与上限
    （全部超期放开），按权重加权（与原料迷你图同一走查算法，篮子跨原料）。"""
    today = utc_datetime_to_local_date(datetime.utcnow(), tz)
    window_start = today - timedelta(days=days)

    per_pid_steps: dict = {}
    for pid, by_day in by_pid_day.items():
        ordered = sorted((d, sum(v) / len(v)) for d, v in by_day.items())
        if not ordered:
            continue
        per_pid_steps[pid] = [ordered, 0, None, ordered[-1][0] + timedelta(days=INGREDIENT_PRICE_STALE_DAYS)]
    if not per_pid_steps:
        return []

    series: List[float] = []
    cur = max(min(state[0][0][0] for state in per_pid_steps.values()), window_start)
    while cur <= today:
        num = den = 0.0          # 30 天内（新鲜）
        num_all = den_all = 0.0  # 全部（当日全部超期时的放开兜底）
        for pid, state in per_pid_steps.items():
            ordered, idx, value, expires_on = state
            while idx < len(ordered) and ordered[idx][0] <= cur:
                value = ordered[idx][1]
                idx += 1
            state[1], state[2] = idx, value
            w = pw.get(pid, 50)
            if value is None or w <= 0:
                continue
            num_all += value * w
            den_all += w
            if cur > expires_on:
                continue
            num += value * w
            den += w
        if den <= 0:
            num, den = num_all, den_all
        if den > 0:
            series.append(round(num / den, 2))
        cur += timedelta(days=1)
    return series


@router.get("/entity-prices", response_model=EntityPricesResponse)
async def comparison_entity_prices(
    request: Request,
    entity_type: str = Query(..., pattern="^(ingredient|product)$", description="实体类型"),
    entity_ids: str = Query(..., description="实体 ID 列表，逗号分隔（≤50）"),
    region_ids: str = Query(..., description="对比地区 ID，逗号分隔（≤6）"),
    days: int = Query(30, ge=7, le=90, description="趋势天数"),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
    tz: str = Depends(get_timezone),
):
    """实体×对比项价格矩阵：每格 = 卡片价（¥/斤，综合价口径）+ 趋势（¥/斤）。

    卡片价经 30 天参与上限聚合；该地区近一年无任何记录时整格为 null。
    项可为地区或自定义计算范围（s<id>）。
    """
    try:
        locale = request_locale(request)
        compare_items = _resolve_compare_items(db, current_user, region_ids, locale)
        ids = _parse_entity_ids(entity_ids)
        currency = get_user_default_currency(db, current_user)
        today = utc_datetime_to_local_date(datetime.utcnow(), tz)
        region_metas = _items_region_metas(compare_items)

        name_by_id: Dict[int, str] = {}
        entity_pids: Dict[int, List[int]] = {}
        if entity_type == "ingredient":
            for ing_id, ing_name in db.query(Ingredient.id, Ingredient.name).filter(
                Ingredient.id.in_(ids)
            ).all():
                name_by_id[ing_id] = ing_name
            prod_rows = db.query(Product.id, Product.ingredient_id).filter(
                Product.ingredient_id.in_(ids),
                Product.is_active == True,  # noqa: E712
            ).all()
            for prod_id, ing_id in prod_rows:
                entity_pids.setdefault(ing_id, []).append(prod_id)
            all_pids = [p for plist in entity_pids.values() for p in plist]
        else:
            for prod_id, prod_name in db.query(Product.id, Product.name).filter(
                Product.id.in_(ids)
            ).all():
                name_by_id[prod_id] = prod_name
                entity_pids[prod_id] = [prod_id]
            all_pids = ids

        pw = _weight_map(db, all_pids, current_user.id)

        rows: Dict[int, EntityPriceRow] = {
            eid: EntityPriceRow(
                entity_id=eid,
                name=name_by_id.get(eid, str(eid)),
                unit=None,
                regions={str(item["resp_id"]): None for item in compare_items},
            )
            for eid in ids
        }

        for item in compare_items:
            rid_spec = item["spec"]
            rid_key = str(item["resp_id"])
            if entity_type == "ingredient":
                trends = _ingredients_sparklines_batched(
                    db, ids, days=days, user_id=current_user.id, tz=tz, region_id=rid_spec
                )
            else:
                trends = _products_sparklines_batched(db, ids, days=days, tz=tz, region_id=rid_spec)
            data = _region_price_data(db, rid_spec, all_pids, tz)
            for eid in ids:
                price, unit, is_stale, days_since, participants = _entity_card_price(
                    data, entity_pids.get(eid) or [], pw, today
                )
                if price is None:
                    continue
                cell = EntityRegionPrice(
                    price=price,
                    is_stale=is_stale,
                    days_since_record=days_since,
                    participant_count=participants,
                    unit=unit,
                    trend=trends.get(str(eid)) or [],
                )
                rows[eid].regions[rid_key] = cell
                if rows[eid].unit is None and unit:
                    rows[eid].unit = unit

        return EntityPricesResponse(
            currency=currency,
            regions=region_metas,
            entities=[rows[eid] for eid in ids],
        )
    except LocalizedHTTPException:
        raise
    except Exception as e:
        raise LocalizedHTTPException(status_code=500, message="获取对比矩阵失败: {error}", error=str(e))


# ==================== 二期：菜谱 / 试算成本对比 ====================


def _parse_plan_ids(raw: str) -> List[int]:
    return _parse_entity_ids(raw, limit=MAX_COMPARISON_PLANS)


def _load_owned_plans(db: Session, user, ids: List[int]) -> Dict[int, "MealPlan"]:
    from sqlalchemy.orm import joinedload

    from app.models.meal_plan import MealPlan

    rows = db.query(MealPlan).options(joinedload(MealPlan.items)).filter(
        MealPlan.id.in_(ids),
        MealPlan.user_id == user.id,
    ).all()
    return {p.id: p for p in rows}


@router.get("/recipe-costs", response_model=RecipeCostsResponse)
async def comparison_recipe_costs(
    request: Request,
    recipe_ids: str = Query(..., description="菜谱 ID 列表，逗号分隔（≤10）"),
    region_ids: str = Query(..., description="对比地区 ID，逗号分隔（≤6）"),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
    tz: str = Depends(get_timezone),
):
    """菜谱×地区成本矩阵：每格 = 总成本/每份成本 + 明细（与菜谱成本同一降级链）。

    明细里 cost=None 的行即该地区缺价的食材（missing_ingredients 汇总），
    供菜谱分析页「按地区」模式的覆盖提示与比价矩阵复用。
    """
    try:
        locale = request_locale(request)
        compare_items = _resolve_compare_items(db, current_user, region_ids, locale)
        rids_recipes = _parse_entity_ids(recipe_ids, limit=MAX_COMPARISON_RECIPES)
        currency = get_user_default_currency(db, current_user)
        name_by_id = {
            rid: name
            for rid, name in db.query(Recipe.id, Recipe.name).filter(
                Recipe.id.in_(rids_recipes)
            ).all()
        }
        now = datetime.utcnow()
        rows: Dict[int, RecipeCostRow] = {
            rid_: RecipeCostRow(
                recipe_id=rid_,
                name=name_by_id.get(rid_, str(rid_)),
                regions={str(item["resp_id"]): None for item in compare_items},
            )
            for rid_ in rids_recipes
        }
        for item in compare_items:
            rid_spec = item["spec"]
            rid_key = str(item["resp_id"])
            for recipe_id in rids_recipes:
                try:
                    cost = calculate_recipe_cost_as_of(
                        recipe_id, current_user.id, now, db, tz=tz, region_id=rid_spec,
                    )
                except Exception:
                    cost = None
                if not cost or cost.get("total_cost") is None:
                    continue
                breakdown_raw = cost.get("cost_breakdown") or []
                breakdown = [
                    RecipeBreakdownItem(
                        ingredient_name=b.get("ingredient_name"),
                        ingredient_id=b.get("ingredient_id"),
                        quantity=b.get("quantity"),
                        cost=b.get("cost"),
                        fallback_chain=b.get("fallback_chain"),
                        aggregation_chain=b.get("aggregation_chain"),
                        price_recorded_at=str(b["price_recorded_at"]) if b.get("price_recorded_at") is not None else None,
                    )
                    for b in breakdown_raw
                ]
                rows[recipe_id].regions[rid_key] = RecipeRegionCost(
                    total_cost=cost.get("total_cost"),
                    cost_per_serving=cost.get("cost_per_serving"),
                    currency=cost.get("currency"),
                    missing_ingredients=[
                        b.ingredient_name for b in breakdown
                        if b.cost is None and b.ingredient_name
                    ],
                    breakdown=breakdown,
                )
        region_metas = _items_region_metas(compare_items)
        return RecipeCostsResponse(
            currency=currency,
            regions=region_metas,
            recipes=[rows[r] for r in rids_recipes],
        )
    except LocalizedHTTPException:
        raise
    except Exception as e:
        raise LocalizedHTTPException(status_code=500, message="获取菜谱成本对比失败: {error}", error=str(e))


@router.get("/recipe-cost-trend")
async def comparison_recipe_cost_trend(
    request: Request,
    recipe_id: int = Query(..., description="菜谱 ID（单选，多地区趋势）"),
    region_ids: str = Query(..., description="对比项列表，逗号分隔（≤6，支持 s<范围id>）"),
    days: int = Query(30, ge=7, le=90, description="趋势天数"),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
    tz: str = Depends(get_timezone),
):
    """单菜谱的多地区成本趋势（每地区一条序列，键为 region_id 字符串）。"""
    try:
        compare_items = _resolve_compare_items(db, current_user, region_ids, request_locale(request))
        out: Dict[str, List[Dict]] = {}
        for item in compare_items:
            try:
                trend = calculate_recipe_cost_range_trend(
                    recipe_id, current_user.id, db, days=days, tz=tz, region_id=item["spec"],
                )
            except Exception:
                trend = []
            out[str(item["resp_id"])] = trend or []
        return {"regions": out}
    except LocalizedHTTPException:
        raise
    except Exception as e:
        raise LocalizedHTTPException(status_code=500, message="获取菜谱趋势对比失败: {error}", error=str(e))


@router.post("/plan-evaluate-regions", response_model=PlanEvaluateRegionsResponse)
async def comparison_plan_evaluate_regions(
    request: Request,
    body: PlanEvaluateRegionsBody,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
    tz: str = Depends(get_timezone),
):
    """同一组试算条目（草稿/未保存均可）在 N 个对比项分别求值。

    试算详情页「合计卡口径切换」的数据源：每项返回 evaluate 的 totals
    （cost / calories / protein_g / carbs_g / fat_g）。显式逐项传范围，
    不走会话 X-Region。body.region_ids 中负数 = 自定义计算范围（-(scope.id)）。
    """
    try:
        compare_items = _resolve_compare_items(
            db, current_user,
            ",".join(
                (f"s{-r}" if r < 0 else str(r)) for r in body.region_ids
            ),
            request_locale(request),
        )
        item_dicts = [item.model_dump() for item in body.items]
        regions = []
        for item in compare_items:
            result = await evaluate_items(
                db, current_user, item_dicts,
                kind=body.kind, meal_type=body.meal_type, tz=tz,
                region_id=item["spec"],
            )
            regions.append(PlanRegionTotals(region_id=item["resp_id"], totals=result.get("totals") or {}))
        return PlanEvaluateRegionsResponse(regions=regions)
    except LocalizedHTTPException:
        raise
    except Exception as e:
        raise LocalizedHTTPException(status_code=500, message="试算分地区求值失败: {error}", error=str(e))


@router.get("/plan-costs")
async def comparison_plan_costs(
    request: Request,
    plan_ids: str = Query(..., description="试算方案 ID 列表，逗号分隔（≤10）"),
    region_ids: str = Query(..., description="对比项列表，逗号分隔（≤6，支持 s<范围id>）"),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
    tz: str = Depends(get_timezone),
):
    """已保存方案×对比项合计对照：每格 = evaluate 的 totals（成本+四项营养）。"""
    try:
        compare_items = _resolve_compare_items(db, current_user, region_ids, request_locale(request))
        ids = _parse_plan_ids(plan_ids)
        plans = _load_owned_plans(db, current_user, ids)
        out = []
        for pid in ids:
            plan = plans.get(pid)
            row: Dict[str, Any] = {
                "plan_id": pid,
                "name": plan.name if plan else str(pid),
                "regions": {str(item["resp_id"]): None for item in compare_items},
            }
            if plan is not None:
                for item in compare_items:
                    try:
                        result = await evaluate_plan(
                            db, current_user, plan, tz=tz, region_id=item["spec"],
                        )
                        row["regions"][str(item["resp_id"])] = result.get("totals") or {}
                    except Exception:
                        row["regions"][str(item["resp_id"])] = None
            out.append(row)
        return {"plans": out, "regions": [item["resp_id"] for item in compare_items]}
    except LocalizedHTTPException:
        raise
    except Exception as e:
        raise LocalizedHTTPException(status_code=500, message="获取试算对比失败: {error}", error=str(e))


@router.get("/plan-cost-trend")
async def comparison_plan_cost_trend(
    request: Request,
    plan_id: int = Query(..., description="试算方案 ID（单选，多地区趋势）"),
    region_ids: str = Query(..., description="对比项列表，逗号分隔（≤6，支持 s<范围id>）"),
    days: int = Query(30, ge=7, le=90, description="趋势天数"),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
    tz: str = Depends(get_timezone),
):
    """单方案的多对比项成本趋势（每项一条序列，复用 plan_cost_trend 显式 region）。"""
    try:
        compare_items = _resolve_compare_items(db, current_user, region_ids, request_locale(request))
        plans = _load_owned_plans(db, current_user, [plan_id])
        plan = plans.get(plan_id)
        if plan is None:
            raise LocalizedHTTPException(status_code=404, message="方案不存在")
        out: Dict[str, List[Dict]] = {}
        for item in compare_items:
            try:
                trend = plan_cost_trend(db, current_user, plan, days=days, tz=tz, region_id=item["spec"])
            except Exception:
                trend = []
            out[str(item["resp_id"])] = trend or []
        return {"regions": out}
    except LocalizedHTTPException:
        raise
    except Exception as e:
        raise LocalizedHTTPException(status_code=500, message="获取试算趋势对比失败: {error}", error=str(e))


# ==================== 三期：商家物价热力图 ====================


@router.get("/heatmap")
async def comparison_heatmap(
    request: Request,
    mode: str = Query("item", pattern="^(item|overall)$", description="item=单品商家价 | overall=商家整体物价指数"),
    entity_type: str = Query("ingredient", pattern="^(ingredient|product)$", description="单品模式的实体类型"),
    entity_id: int = Query(None, description="单品模式的实体 ID"),
    region_ids: str = Query(..., description="限定地区（逗号分隔 ≤6；商家必须落在子树内）"),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
    tz: str = Depends(get_timezone),
):
    """商家物价热力图数据（圆点分档着色用）。

    - mode=item：选一个原料/商品，返回各商家的该品代表价（每 (商家,商品) 取最新
      一条有效记录 → 折算到用户币种 → ¥/斤 归一 → 同商家按权重加权）。
    - mode=overall：不选实体，篮子 = 基准地区（region_ids 第一个）近一年有记录的
      商品（上限 50）；每商家对篮子的加权均价 → price_index = 商家价 / 所选地区
      全部商家价的中位数 ×100（中位数=100，分档自解释）。

    返回 buckets 分位（p25/p50/p75/p90）供前端图例与着色分档；
    坐标缺失（latitude/longitude 为空）的商家不返回（地图上无法渲染）。
    """
    try:
        compare_items = _resolve_compare_items(db, current_user, region_ids, request_locale(request))
        currency = get_user_default_currency(db, current_user)
        uid = current_user.id
        now = datetime.utcnow()

        # 商家全集（各对比项子树并集内、营业中、有坐标），一次查齐
        region_conds = []
        for item in compare_items:
            ids = region_subtree_ids(db, item["spec"])
            if ids:
                region_conds.append(Merchant.region_id.in_(ids))
        merchants = db.query(Merchant).filter(
            Merchant.is_open == True,  # noqa: E712
            Merchant.latitude.isnot(None),
            Merchant.longitude.isnot(None),
            or_(*region_conds) if region_conds else False,
        ).all()
        merchant_by_id = {m.id: m for m in merchants}
        if not merchants:
            return {
                "mode": mode, "currency": currency, "unit": "斤",
                "items": [], "buckets": {},
            }
        mid_set = set(merchant_by_id.keys())

        # 单品模式 → 商品集合；overall → 篮子商品集合
        if mode == "item":
            if entity_id is None:
                raise LocalizedHTTPException(
                    status_code=400, message="热力图参数无效: {error}", error="单品模式必须传 entity_id")
            if entity_type == "ingredient":
                product_ids = [p.id for p in db.query(Product.id).filter(
                    Product.ingredient_id == entity_id,
                    Product.is_active == True,  # noqa: E712
                ).all()]
            else:
                product_ids = [entity_id]
        else:
            cutoff = now - timedelta(days=BASKET_WINDOW_DAYS)
            basket_q = db.query(ProductRecord.product_id.distinct()).filter(
                ProductRecord.is_active == True,  # noqa: E712
                ProductRecord.price.isnot(None),
                ProductRecord.recorded_at >= cutoff,
            )
            basket_rows = apply_region_filter(basket_q, db, compare_items[0]["spec"]).all()
            product_ids = [r[0] for r in basket_rows][:50]  # 上限 50 防查询过重

        if not product_ids:
            return {
                "mode": mode, "currency": currency, "unit": "斤",
                "items": [], "buckets": {},
            }

        # 每 (商家, 商品) 取子树内最新一条有效记录（join Merchant 界定子树）
        records = (
            db.query(ProductRecord)
            .filter(
                ProductRecord.product_id.in_(product_ids),
                ProductRecord.merchant_id.in_(mid_set),
                ProductRecord.is_active == True,  # noqa: E712
                ProductRecord.price.isnot(None),
            )
            .order_by(ProductRecord.recorded_at.desc())
            .all()
        )
        mp_latest: Dict[Tuple[int, int], object] = {}
        sample_counts: Dict[int, set] = defaultdict(set)
        for record in records:
            key = (record.merchant_id, record.product_id)
            if key not in mp_latest:
                mp_latest[key] = record
            sample_counts[record.merchant_id].add(record.product_id)

        # 每商家：商品内均价 → 权重加权（与 latest-price-by-merchant 同口径，
        # 归一单位统一 ¥/斤，跨商品可比）
        from app.services.price_aggregator import record_standard_grams
        from app.services.ingredient_price_service import _resolve_weight

        pw = _weight_map(db, product_ids, uid)
        merchant_prices: Dict[int, float] = {}
        for mid in mid_set:
            weighted = []
            for pid in product_ids:
                record = mp_latest.get((mid, pid))
                if record is None:
                    continue
                grams = record_standard_grams(
                    db, record.standard_quantity, record.standard_unit_id, pid)
                if grams <= 0:
                    continue
                unit_price = float(record_price_in_user_currency(record)) * 500.0 / grams
                w = pw.get(pid, 50)
                if w <= 0:
                    continue
                weighted.append((unit_price, w))
            if not weighted:
                continue
            num = sum(up * w for up, w in weighted)
            den = sum(w for _, w in weighted)
            merchant_prices[mid] = round(num / den, 2)

        # 分位（非陈旧价；全陈旧时用全部）
        prices_all = [
            p for mid, p in merchant_prices.items()
            if not is_stale_recorded_at(mp_latest[
                next(k for k in mp_latest if k[0] == mid)
            ].recorded_at)
        ]
        if not prices_all:
            prices_all = list(merchant_prices.values())
        buckets: Dict[str, Optional[float]] = {}
        if prices_all:
            s = sorted(prices_all)

            def _pct(q: float) -> float:
                idx = min(len(s) - 1, max(0, round((len(s) - 1) * q)))
                return s[idx]
            buckets = {"p25": _pct(0.25), "p50": _pct(0.50),
                       "p75": _pct(0.75), "p90": _pct(0.90)}
        median_price = buckets.get("p50")

        items = []
        for mid, m in merchant_by_id.items():
            price = merchant_prices.get(mid)
            if price is None:
                continue
            # 陈旧判定：该商家任一参与商品为最新记录即可代表，取最新那条
            latest_at = None
            for pid in product_ids:
                record = mp_latest.get((mid, pid))
                if record is not None and (
                    latest_at is None or record.recorded_at > latest_at
                ):
                    latest_at = record.recorded_at
            item: Dict[str, Any] = {
                "merchant_id": mid,
                "name": m.name,
                "latitude": float(m.latitude),
                "longitude": float(m.longitude),
                "is_open": bool(m.is_open),
                "region_id": m.region_id,
                "price": price,
                "is_stale": is_stale_recorded_at(latest_at),
                "sample_count": len(sample_counts.get(mid) or set()),
            }
            if mode == "overall":
                item["price_index"] = (
                    round(price / median_price * 100, 1)
                    if median_price and median_price > 0 else None
                )
            items.append(item)

        return {
            "mode": mode,
            "currency": currency,
            "unit": "斤",
            "entity_type": entity_type if mode == "item" else None,
            "entity_id": entity_id if mode == "item" else None,
            "basket_size": len(product_ids) if mode == "overall" else None,
            "buckets": buckets,
            "items": items,
        }
    except LocalizedHTTPException:
        raise
    except Exception as e:
        raise LocalizedHTTPException(status_code=500, message="获取热力图数据失败: {error}", error=str(e))
