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
from typing import Dict, List, Optional, Tuple

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import desc, func
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
from app.services.currency_service import get_user_default_currency
from app.services.catalog_display import region_display_name
from app.services.ingredient_price_service import (
    INGREDIENT_PRICE_STALE_DAYS,
    _product_unit_price,
)
from app.services.price_region import apply_region_filter
from app.models.administrative_region import AdministrativeRegion
from app.models.merchant import Merchant
from app.models.product import ProductRecord
from app.models.product_entity import Product
from app.models.nutrition import Ingredient
from app.schemas.comparison import (
    ComparisonSummaryResponse,
    EntityPriceRow,
    EntityPricesResponse,
    EntityRegionPrice,
    RegionCandidate,
    RegionCandidatesResponse,
    RegionMeta,
    RegionSummaryItem,
)
from app.utils.date_range_utils import utc_datetime_to_local_date

router = APIRouter(tags=["跨地区对比"])

MAX_COMPARISON_REGIONS = 6
MAX_COMPARISON_ENTITIES = 50
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
        self.prices: Dict[int, float] = {}        # pid → 最近有记录日每标准单位均价（用户币种）
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
        unit_price = _product_unit_price(latest_rows)
        if unit_price is not None:
            data.prices[pid] = float(unit_price)
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
    """单实体的卡片价：mode="recent" 综合价口径。

    每商品取「最近有记录日」的每标准单位均价 → 30 天参与上限（全部超期放开）
    → 按权重（用户覆盖 > price_weight > 50）加权。
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
    # 单位取最近有记录的参与商品的标准单位（与综合价的 std_abbr 口径一致）
    latest_pid = max(pool, key=lambda p: data.latest[p])
    unit = data.units.get(latest_pid)
    days_since = min((today - data.latest[p]).days for p in pids_with)
    return price, unit, not fresh, days_since, len(pool)


@router.get("/comparison/regions", response_model=RegionCandidatesResponse)
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


@router.get("/comparison/summary", response_model=ComparisonSummaryResponse)
async def comparison_summary(
    request: Request,
    region_ids: str = Query(..., description="对比地区 ID，逗号分隔（≤6，第一个为基准地区）"),
    days: int = Query(30, ge=7, le=90, description="篮子趋势天数"),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
    tz: str = Depends(get_timezone),
):
    """各地区概览：记录数/商品数 + 物价指数 + 共同商品篮子日均价趋势。

    篮子 = 基准地区（region_ids 第一个）近一年有记录的商品；物价指数 =
    各地区对篮子商品的「单价比率（地区价 / 基准价）」中位数 × 100。
    """
    try:
        rids = _parse_region_ids(region_ids)
        regions_by_id = _load_regions(db, rids)
        locale = request_locale(request)
        currency = get_user_default_currency(db, current_user)
        today = utc_datetime_to_local_date(datetime.utcnow(), tz)

        # 篮子：基准地区近一年有记录的商品
        cutoff = datetime.utcnow() - timedelta(days=BASKET_WINDOW_DAYS)
        basket_q = db.query(ProductRecord.product_id.distinct()).filter(
            ProductRecord.is_active == True,  # noqa: E712
            ProductRecord.price.isnot(None),
            ProductRecord.recorded_at >= cutoff,
        )
        basket_rows = apply_region_filter(basket_q, db, rids[0]).all()
        basket_pids = [r[0] for r in basket_rows]

        pw = _weight_map(db, basket_pids, current_user.id)
        base_data = _region_price_data(db, rids[0], basket_pids, tz)

        items: List[RegionSummaryItem] = []
        for rid in rids:
            data = base_data if rid == rids[0] else _region_price_data(db, rid, basket_pids, tz)
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
            record_count, entity_count = apply_region_filter(count_q, db, rid).one()
            trend = _basket_daily_series(data.steps, pw, days, tz)
            region = regions_by_id.get(rid)
            items.append(RegionSummaryItem(
                region_id=rid,
                name=region.name if region else str(rid),
                display_name=region_display_name(region, locale) if region else str(rid),
                record_count=record_count,
                entity_count=entity_count,
                price_index=price_index,
                trend=trend,
            ))
        return ComparisonSummaryResponse(
            currency=currency,
            base_region_id=rids[0],
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


@router.get("/comparison/entity-prices", response_model=EntityPricesResponse)
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
    """实体×地区价格矩阵：每格 = 卡片价（每标准单位，综合价口径）+ 趋势（¥/斤）。

    卡片价经 30 天参与上限聚合；该地区近一年无任何记录时整格为 null。
    """
    try:
        rids = _parse_region_ids(region_ids)
        ids = _parse_entity_ids(entity_ids)
        currency = get_user_default_currency(db, current_user)
        today = utc_datetime_to_local_date(datetime.utcnow(), tz)
        regions_by_id = _load_regions(db, rids)
        locale = request_locale(request)
        region_metas = [
            RegionMeta(
                region_id=rid,
                name=regions_by_id[rid].name,
                display_name=region_display_name(regions_by_id[rid], locale),
                level=regions_by_id[rid].level,
            )
            for rid in rids
            if rid in regions_by_id
        ]

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
                regions={str(rid): None for rid in rids},
            )
            for eid in ids
        }

        for rid in rids:
            if entity_type == "ingredient":
                trends = _ingredients_sparklines_batched(
                    db, ids, days=days, user_id=current_user.id, tz=tz, region_id=rid
                )
            else:
                trends = _products_sparklines_batched(db, ids, days=days, tz=tz, region_id=rid)
            data = _region_price_data(db, rid, all_pids, tz)
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
                rows[eid].regions[str(rid)] = cell
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
