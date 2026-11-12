"""用户自定义计算范围（多地区组合）CRUD。

一个范围 = 名称 + region_ids（administrative_regions.id，层级可混合，
如一个县 + 一个地级市）。计算按各地区子树并集过滤（price_region.py）。

设为默认走 PATCH /api/v1/me 的 default_calc_scope_id（与 default_calc_scope
层级档位互斥写入），本路由只管范围本身；is_default 由 users.default_calc_scope_id
派生，便于前端展示。删除时清空指向本范围的默认引用。
"""
from typing import List

from fastapi import APIRouter, Depends, Request
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.exceptions import LocalizedHTTPException
from app.core.i18n import request_locale
from app.core.security import get_current_user
from app.models.administrative_region import AdministrativeRegion
from app.models.user import User
from app.models.user_calc_scope import UserCalcScope
from app.schemas.calc_scope import CalcScopeCreate, CalcScopeResponse, CalcScopeUpdate
from app.services.catalog_display import region_display_name

router = APIRouter(tags=["自定义计算范围"])

MAX_SCOPES_PER_USER = 20
MAX_REGIONS_PER_SCOPE = 50


def _normalize_region_ids(db: Session, region_ids: List[int]) -> List[int]:
    """去重保序 + 存在性校验（活跃地区），返回规范化列表。"""
    ids = list(dict.fromkeys(int(r) for r in (region_ids or [])))
    if not ids:
        raise LocalizedHTTPException(status_code=400, message='至少选择一个地区')
    if len(ids) > MAX_REGIONS_PER_SCOPE:
        raise LocalizedHTTPException(
            status_code=400,
            message='每个范围最多选择 {limit} 个地区',
            limit=MAX_REGIONS_PER_SCOPE,
        )
    rows = db.query(AdministrativeRegion.id).filter(
        AdministrativeRegion.id.in_(ids),
        AdministrativeRegion.is_active == True,  # noqa: E712
    ).all()
    found = {r[0] for r in rows}
    missing = [str(r) for r in ids if r not in found]
    if missing:
        raise LocalizedHTTPException(
            status_code=400,
            message='未知地区: {regions}',
            regions=", ".join(missing),
        )
    return ids


def _validate_name(db: Session, user_id: int, name: str, exclude_id: int = None) -> str:
    name = (name or "").strip()
    if not name:
        raise LocalizedHTTPException(status_code=400, message='范围名称不能为空')
    query = db.query(UserCalcScope.id).filter(
        UserCalcScope.user_id == user_id,
        UserCalcScope.name == name,
    )
    if exclude_id is not None:
        query = query.filter(UserCalcScope.id != exclude_id)
    if query.first() is not None:
        raise LocalizedHTTPException(status_code=400, message='已存在同名范围')
    return name


def _scope_to_response(db: Session, scope: UserCalcScope, user: User, locale: str) -> CalcScopeResponse:
    ids = list(dict.fromkeys(scope.region_ids or []))
    rows = db.query(AdministrativeRegion).filter(
        AdministrativeRegion.id.in_(ids),
        AdministrativeRegion.is_active == True,  # noqa: E712
    ).all() if ids else []
    by_id = {r.id: r for r in rows}
    regions = [
        {
            "id": rid,
            "name": by_id[rid].name,
            "display_name": region_display_name(by_id[rid], locale),
            "level": by_id[rid].level,
        }
        for rid in ids
        if rid in by_id
    ]
    return CalcScopeResponse(
        id=scope.id,
        name=scope.name,
        region_ids=ids,
        regions=regions,
        # getattr 兜底：测试的 FakeUser 占位对象没有该属性
        is_default=getattr(user, "default_calc_scope_id", None) == scope.id,
    )


def _get_owned_scope(db: Session, scope_id: int, user: User) -> UserCalcScope:
    scope = db.query(UserCalcScope).filter(
        UserCalcScope.id == scope_id,
        UserCalcScope.user_id == user.id,
    ).first()
    if not scope:
        raise LocalizedHTTPException(status_code=404, message='自定义计算范围不存在')
    return scope


@router.get("", response_model=List[CalcScopeResponse])
@router.get("/", response_model=List[CalcScopeResponse])
def list_calc_scopes(
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """当前用户的自定义计算范围列表（含地区明细与默认标记）。"""
    try:
        scopes = (
            db.query(UserCalcScope)
            .filter(UserCalcScope.user_id == current_user.id)
            .order_by(UserCalcScope.created_at.asc(), UserCalcScope.id.asc())
            .all()
        )
    except SQLAlchemyError:
        raise LocalizedHTTPException(status_code=500, message='获取自定义计算范围失败')
    locale = request_locale(request)
    return [_scope_to_response(db, s, current_user, locale) for s in scopes]


@router.post("", response_model=CalcScopeResponse, status_code=201)
@router.post("/", response_model=CalcScopeResponse, status_code=201)
def create_calc_scope(
    payload: CalcScopeCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """创建自定义计算范围。"""
    count = db.query(UserCalcScope).filter(
        UserCalcScope.user_id == current_user.id
    ).count()
    if count >= MAX_SCOPES_PER_USER:
        raise LocalizedHTTPException(
            status_code=400,
            message='最多创建 {limit} 个自定义计算范围',
            limit=MAX_SCOPES_PER_USER,
        )
    name = _validate_name(db, current_user.id, payload.name)
    ids = _normalize_region_ids(db, payload.region_ids)
    try:
        scope = UserCalcScope(user_id=current_user.id, name=name, region_ids=ids)
        db.add(scope)
        db.commit()
        db.refresh(scope)
    except SQLAlchemyError:
        db.rollback()
        raise LocalizedHTTPException(status_code=500, message='创建自定义计算范围失败')
    return _scope_to_response(db, scope, current_user, request_locale(request))


@router.put("/{scope_id}", response_model=CalcScopeResponse)
def update_calc_scope(
    scope_id: int,
    payload: CalcScopeUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """更新自定义计算范围（名称 / 地区列表）。"""
    scope = _get_owned_scope(db, scope_id, current_user)
    if payload.name is not None:
        scope.name = _validate_name(db, current_user.id, payload.name, exclude_id=scope.id)
    if payload.region_ids is not None:
        scope.region_ids = _normalize_region_ids(db, payload.region_ids)
    try:
        db.commit()
        db.refresh(scope)
    except SQLAlchemyError:
        db.rollback()
        raise LocalizedHTTPException(status_code=500, message='更新自定义计算范围失败')
    return _scope_to_response(db, scope, current_user, request_locale(request))


@router.delete("/{scope_id}", status_code=200)
def delete_calc_scope(
    scope_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """删除自定义计算范围；引用它的 users.default_calc_scope_id 一并清空。"""
    scope = _get_owned_scope(db, scope_id, current_user)
    try:
        db.query(User).filter(
            User.default_calc_scope_id == scope.id
        ).update({User.default_calc_scope_id: None}, synchronize_session=False)
        db.delete(scope)
        db.commit()
    except SQLAlchemyError:
        db.rollback()
        raise LocalizedHTTPException(status_code=500, message='删除自定义计算范围失败')
    return {"ok": True}
