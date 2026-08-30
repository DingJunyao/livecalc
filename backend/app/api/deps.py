"""API 公共依赖。"""
import re
from typing import Optional

from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user

from fastapi import Depends, Header, HTTPException, Request
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

_OFFSET_PATTERN = re.compile(r'^UTC([+-])(\d{2}):(\d{2})$')


def get_timezone(x_timezone: Optional[str] = Header(None, alias="X-Timezone")) -> str:
    """校验请求头 X-Timezone 为合法 IANA 时区名或 UTC+HH:mm 偏移格式。

    缺失或非法均返回 400（非 422）。前端拦截器统一注入，正常流程不会触发。
    """
    if not x_timezone:
        raise HTTPException(status_code=400, detail="缺少 X-Timezone 请求头")
    try:
        ZoneInfo(x_timezone)
    except (ZoneInfoNotFoundError, ValueError):
        if not _OFFSET_PATTERN.match(x_timezone):
            raise HTTPException(status_code=400, detail=f"无效时区: {x_timezone}")
    return x_timezone


async def get_session_currency_override(
    request: Request,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user),
):
    """请求级临时币种覆盖（X-Currency 头）：仅当前请求有效，不落库。

    覆盖后所有价格折算与 exchange_rate 均按「用户币种 → 会话币种」当日汇率换算；
    用户配置（default_currency 等）不变。写路径（新增/修改价格记录）通过
    ignore_session=True 跳过覆盖，快照仍按用户真实币种落库。
    """
    code = (request.headers.get("x-currency") or "").strip().upper()
    region_raw = (request.headers.get("x-region") or "").strip()
    if not code and not region_raw:
        yield
        return

    from datetime import date
    from decimal import Decimal

    from app.core.security import get_current_user
    from app.models.currency import Currency
    from app.services import exchange_rate_service
    from app.services.currency_service import get_user_default_currency
    from app.services.session_context import reset_session_currency, set_session_currency, reset_session_region

    user = current_user

    if code:
        cur = db.query(Currency).filter(
            Currency.code == code,
            Currency.is_active == True,  # noqa: E712
        ).first()
        if not cur:
            raise HTTPException(status_code=400, detail=f"未知币种: {code}")

        user_currency = get_user_default_currency(db, user)
        if code == user_currency:
            rate = Decimal("1")
        else:
            rate = exchange_rate_service.convert(db, Decimal("1"), user_currency, code, date.today())
            if rate is None:
                raise HTTPException(
                    status_code=400,
                    detail=f"无法获取 {user_currency} → {code} 汇率，请稍后重试",
                )
        set_session_currency(code, float(rate))
    # 会话级地区覆盖（X-Region）：前端已解析到生效节点；all 表示明确不筛选。
    region_override = None
    if region_raw:
        if region_raw != "all":
            from app.models.administrative_region import AdministrativeRegion
            if not region_raw.isdigit():
                raise HTTPException(status_code=400, detail="无效地区 X-Region")
            rnode = db.query(AdministrativeRegion).filter(
                AdministrativeRegion.id == int(region_raw),
                AdministrativeRegion.is_active == True,  # noqa: E712
            ).first()
            if not rnode:
                raise HTTPException(status_code=400, detail="未知地区")
            region_override = rnode.id
    from app.services.session_context import set_session_region
    if region_raw:
        set_session_region(region_override)
    try:
        yield
    finally:
        reset_session_currency()
        reset_session_region()
