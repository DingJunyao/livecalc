"""
每日饮食推荐 API
"""
import asyncio
import datetime
import logging
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from pydantic import BaseModel, Field

from app.core.database import get_db
from app.core.security import get_current_user
from app.api.deps import get_timezone
from app.utils.date_range_utils import utc_datetime_to_local_date
from app.models.user import User
from app.schemas.meal import (
    GenerateMealRequest,
    MealRecommendationsResponse,
    RefreshMealRequest,
)
from app.services.meal_recommender import (
    _build_response_from_records,
    check_today_status,
    is_refreshing,
    trigger_background_generation,
    trigger_background_refresh,
)
from app.core.exceptions import LocalizedHTTPException

logger = logging.getLogger("meals")
router = APIRouter()


def _build_response_from_records_sync(*args, **kwargs):
    """Run the response builder in a fresh event loop on a worker thread."""
    return asyncio.run(_build_response_from_records(*args, **kwargs))


def _accept_lang(request: Request) -> str:
    """从 Accept-Language 推导 AI 文案语言（zh/en/ar）。"""
    header = (request.headers.get("accept-language") or "").lower()
    if header.startswith("en"):
        return "en"
    if header.startswith("ar"):
        return "ar"
    return "zh"


@router.get("/recommendations", response_model=MealRecommendationsResponse)
def get_daily_recommendations(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tz: str = Depends(get_timezone),
):
    """
    获取今日三餐推荐（轻量，不触发计算）。

    - 已有缓存 → 直接返回 status="ready"
    - 未生成 → 返回 status="not_generated"，前端应调用 POST /generate 触发后台计算
    - 生成中 → 返回 status="generating"，前端继续轮询
    """
    try:
        status_info = check_today_status(db, current_user.id, tz)

        if status_info["status"] == "ready":
            return _build_response_from_records_sync(
                db, status_info["existing_records"], current_user,
                refreshing_meals=status_info.get("refreshing_meals", []),
                tz=tz,
            )

        # not_generated 或 generating
        return MealRecommendationsResponse(
            status=status_info["status"],
            date=utc_datetime_to_local_date(datetime.datetime.now(datetime.timezone.utc), tz).isoformat(),
            recommendations=[],
            totals=None,
            refreshing_meals=status_info.get("refreshing_meals", []),
        )
    except Exception as e:
        logger.error(f"获取每日推荐失败: {e}", exc_info=True)
        raise LocalizedHTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, message='获取每日推荐失败')


@router.post("/recommendations/generate", response_model=MealRecommendationsResponse)
def trigger_recommendation_generation(
    request: Request,
    body: GenerateMealRequest | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tz: str = Depends(get_timezone),
):
    """
    触发后台生成今日推荐。

    - 已有缓存 → 直接返回（不重复生成）
    - 已在生成中 → 返回 status="generating"
    - 未生成 → 启动后台线程生成，返回 status="generating"
    - body.preference：一句话偏好（可选）
    """
    try:
        status_info = check_today_status(db, current_user.id, tz)

        if status_info["status"] == "ready":
            return _build_response_from_records_sync(
                db, status_info["existing_records"], current_user,
                refreshing_meals=status_info.get("refreshing_meals", []),
                tz=tz,
            )

        preference = (body.preference or None) if body else None
        started = trigger_background_generation(
            current_user.id, tz,
            preference=preference, lang=_accept_lang(request),
        )

        return MealRecommendationsResponse(
            status="generating" if started else status_info["status"],
            date=utc_datetime_to_local_date(datetime.datetime.now(datetime.timezone.utc), tz).isoformat(),
            recommendations=[],
            totals=None,
            refreshing_meals=[],
        )
    except Exception as e:
        logger.error(f"触发推荐生成失败: {e}", exc_info=True)
        raise LocalizedHTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, message='触发推荐生成失败')


class SetPlanRequest(BaseModel):
    """把试算方案设为今日一餐/三餐"""
    plan_id: int
    meal_type: str | None = Field(None, pattern="^(breakfast|lunch|dinner)$")


@router.post("/recommendations/set-plan", response_model=MealRecommendationsResponse)
def set_plan_as_recommendation(
    request: SetPlanRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tz: str = Depends(get_timezone),
):
    """
    试算方案 → 今日推荐：方案来源餐（source='plan' + plan_id）。

    - kind='meal' 需给 meal_type（未给则用当前餐）
    - kind='day' 一次设三餐
    - 该餐今天还没有推荐时自动先生成再覆盖
    """
    import datetime
    from app.models.meal_plan import MealPlan
    from app.services.meal_recommender import _load_today_records

    try:
        plan = (
            db.query(MealPlan)
            .filter(
                MealPlan.id == request.plan_id,
                MealPlan.user_id == current_user.id,
                MealPlan.is_active == True,  # noqa: E712
            )
            .first()
        )
        if plan is None:
            raise LocalizedHTTPException(status_code=404, message='试算方案不存在')

        today = utc_datetime_to_local_date(datetime.datetime.now(datetime.timezone.utc), tz)
        from app.services.meal_recommender import _load_today_records as _load

        records = {r.meal_type: r for r in _load(db, current_user.id, today)}

        if plan.kind == "meal":
            meal_type = request.meal_type
            if meal_type is None:
                current = _current_meal_for_plan(tz)
                meal_type = current or "lunch"
            targets = [meal_type]
        else:
            targets = ["breakfast", "lunch", "dinner"]

        for mt in targets:
            rec = records.get(mt)
            if rec is None:
                # 该餐今天没有推荐：直接建一条 plan 来源记录
                from app.models.daily_recommendation import DailyRecommendation

                rec = DailyRecommendation(
                    user_id=current_user.id, date=today, meal_type=mt,
                    source="plan", plan_id=plan.id,
                )
                db.add(rec)
            else:
                rec.source = "plan"
                rec.plan_id = plan.id
        db.commit()

        all_records = _load(db, current_user.id, today)
        return _build_response_from_records_sync(
            db, all_records, current_user, tz=tz,
        )
    except HTTPException:
        raise
    except LocalizedHTTPException:
        raise
    except Exception as e:
        logger.error(f"设为今日一餐失败: {e}", exc_info=True)
        raise LocalizedHTTPException(status_code=500, message='设为今日一餐失败')


def _current_meal_for_plan(tz: str) -> str | None:
    import datetime
    from app.utils.date_range_utils import _zone

    hour = datetime.datetime.now(_zone(tz)).hour
    if 5 <= hour < 10:
        return "breakfast"
    if 10 <= hour < 14:
        return "lunch"
    if 14 <= hour < 22:
        return "dinner"
    return None


@router.post("/recommendations/refresh", response_model=MealRecommendationsResponse)
def refresh_recommendation(
    request: RefreshMealRequest,
    http_request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tz: str = Depends(get_timezone),
):
    """
    刷新某一餐的推荐（后台异步模式）。

    - recipe_id 为空 = 整餐重搭；给定 = 单道换（保持其它菜不变）
    - 触发后台线程重新组合，立即返回当前推荐 + refreshing_meals 中含该餐标识
    - 前端应轮询 GET /recommendations 直到 refreshing_meals 不含该餐
    - 每餐每天最多刷新 5 次，超出返回 429
    - 该餐已在刷新中 → 返回 409
    """
    from app.services.meal_recommender import MAX_REFRESH_PER_MEAL, _count_today_refreshes

    try:
        # 先检查刷新次数（refresh_count 列，修复后真实计数）
        today = utc_datetime_to_local_date(datetime.datetime.now(datetime.timezone.utc), tz)
        counts = _count_today_refreshes(db, current_user.id, today)
        current_count = counts.get(request.meal_type, 0)
        if current_count >= MAX_REFRESH_PER_MEAL:
            raise LocalizedHTTPException(
                status_code=429,
                message='今天{meal_type}推荐已经刷新 {max} 次了，明天再来吧～',
                meal_type=request.meal_type, max=MAX_REFRESH_PER_MEAL,
            )

        # 检查是否已在刷新
        if is_refreshing(current_user.id, request.meal_type):
            # 返回当前推荐，frontend 可以继续轮询
            status_info = check_today_status(db, current_user.id, tz)
            if status_info["status"] == "ready":
                return _build_response_from_records_sync(
                    db, status_info["existing_records"], current_user,
                    refreshing_meals=status_info.get("refreshing_meals", []),
                )
            return MealRecommendationsResponse(
                status="generating",
                date=today.isoformat(),
                recommendations=[],
                totals=None,
                refreshing_meals=status_info.get("refreshing_meals", []),
            )

        # 确保推荐已存在（否则应该先走 generate）
        status_info = check_today_status(db, current_user.id, tz)
        if status_info["status"] != "ready":
            return MealRecommendationsResponse(
                status="not_generated",
                date=today.isoformat(),
                recommendations=[],
                totals=None,
            )

        # 触发后台刷新
        started, error = trigger_background_refresh(
            current_user.id, request.meal_type, tz,
            target_recipe_id=request.recipe_id,
            preference=request.preference,
            lang=_accept_lang(http_request),
        )
        if not started:
            raise LocalizedHTTPException(status_code=409, message='刷新失败: {error}', error=error)

        # 返回当前推荐 + 刷新中标记
        return _build_response_from_records_sync(
            db, status_info["existing_records"], current_user,
            refreshing_meals=[request.meal_type],
            tz=tz,
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"刷新推荐失败: {e}", exc_info=True)
        raise LocalizedHTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, message='刷新推荐失败')
