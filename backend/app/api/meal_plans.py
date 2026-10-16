"""试算方案 API（设计 §5.2-5.3）。

- CRUD：方案含条目一体保存；仅本人可见。
- POST /evaluate：草稿求值（不落库）。
- GET /{id}/cost-trend：方案成本 as-of 逐日走势。
- POST /meals/recommendations/set-plan：把方案设为今日一餐/三餐
  （挂到 meals 路由域，见 api/meals.py）。
"""
import logging
from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.core.exceptions import LocalizedHTTPException
from app.core.security import get_current_user
from app.api.deps import get_timezone
from app.models.meal_plan import MealPlan, MealPlanItem
from app.models.user import User
from app.services.meal_plan_service import evaluate_plan, plan_cost_trend

logger = logging.getLogger("meal_plans")
router = APIRouter()

_ITEM_TYPES = ("recipe", "ingredient", "product")
_GROUPS = ("breakfast", "lunch", "dinner", "other")


class PlanItemIn(BaseModel):
    group: str = "other"
    item_type: str
    recipe_id: Optional[int] = None
    ingredient_id: Optional[int] = None
    product_id: Optional[int] = None
    servings: Optional[float] = Field(None, ge=0)
    quantity: Optional[float] = Field(None, ge=0)
    unit_id: Optional[int] = None
    sort_order: int = 0
    note: Optional[str] = None


class PlanCreate(BaseModel):
    name: str = Field(..., max_length=120)
    kind: str = Field("meal", pattern="^(meal|day)$")
    note: Optional[str] = Field(None, max_length=200)
    items: List[PlanItemIn] = []


class PlanUpdate(BaseModel):
    name: Optional[str] = Field(None, max_length=120)
    kind: Optional[str] = Field(None, pattern="^(meal|day)$")
    note: Optional[str] = Field(None, max_length=200)
    items: Optional[List[PlanItemIn]] = None


class EvaluateRequest(BaseModel):
    kind: str = Field("meal", pattern="^(meal|day)$")
    meal_type: str = Field("lunch", pattern="^(breakfast|lunch|dinner)$")
    items: List[PlanItemIn] = []


def _load_owned(db: Session, user: User, plan_id: int) -> MealPlan:
    plan = (
        db.query(MealPlan)
        .options(joinedload(MealPlan.items))
        .filter(
            MealPlan.id == plan_id,
            MealPlan.user_id == user.id,
            MealPlan.is_active == True,  # noqa: E712
        )
        .first()
    )
    if plan is None:
        raise LocalizedHTTPException(status_code=404, message='试算方案不存在')
    return plan


def _validate_items(items: List[PlanItemIn]) -> None:
    for it in items:
        if it.item_type not in _ITEM_TYPES:
            raise LocalizedHTTPException(
                status_code=400, message='不支持的条目类型：{item_type}', item_type=it.item_type)
        if it.group not in _GROUPS:
            raise LocalizedHTTPException(
                status_code=400, message='不支持的分组：{group}', group=it.group)
        entity_id = {
            "recipe": it.recipe_id, "ingredient": it.ingredient_id, "product": it.product_id,
        }.get(it.item_type)
        if not entity_id:
            raise LocalizedHTTPException(
                status_code=400, message='条目类型 {item_type} 缺少对应实体 ID',
                item_type=it.item_type)


def _apply_items(db: Session, plan: MealPlan, items: List[PlanItemIn]) -> None:
    # 全量替换（条目数小，简单可靠）；批量 delete 不触发 ORM 级联，先显式删子行
    db.query(MealPlanItem).filter(MealPlanItem.plan_id == plan.id).delete(
        synchronize_session=False)
    for it in sorted(items, key=lambda x: x.sort_order):
        db.add(MealPlanItem(
            plan_id=plan.id,
            group=it.group,
            item_type=it.item_type,
            recipe_id=it.recipe_id, ingredient_id=it.ingredient_id,
            product_id=it.product_id,
            servings=it.servings, quantity=it.quantity, unit_id=it.unit_id,
            sort_order=it.sort_order, note=it.note,
            created_by=plan.user_id, updated_by=plan.user_id,
        ))


def _serialize(db: Session, plan: MealPlan) -> dict:
    items = []
    for it in sorted(plan.items, key=lambda x: x.sort_order):
        if it.is_active is False:
            continue
        name = None
        if it.item_type == "recipe" and it.recipe:
            name = it.recipe.name
        elif it.item_type == "ingredient" and it.ingredient:
            name = it.ingredient.name
        elif it.item_type == "product" and it.product:
            name = it.product.name
        items.append({
            "id": it.id,
            "group": it.group,
            "item_type": it.item_type,
            "recipe_id": it.recipe_id,
            "ingredient_id": it.ingredient_id,
            "product_id": it.product_id,
            "name": name,
            "servings": float(it.servings) if it.servings is not None else None,
            "quantity": float(it.quantity) if it.quantity is not None else None,
            "unit_id": it.unit_id,
            "unit": it.unit.abbreviation if it.unit else None,
            "sort_order": it.sort_order,
            "note": it.note,
        })
    return {
        "id": plan.id,
        "name": plan.name,
        "kind": plan.kind,
        "note": plan.note,
        "items": items,
        "created_at": plan.created_at.isoformat() if plan.created_at else None,
        "updated_at": plan.updated_at.isoformat() if plan.updated_at else None,
    }


@router.get("")
async def list_plans(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    plans = (
        db.query(MealPlan)
        .options(joinedload(MealPlan.items))
        .filter(MealPlan.user_id == current_user.id, MealPlan.is_active == True)  # noqa: E712
        .order_by(MealPlan.updated_at.desc())
        .all()
    )
    return {"items": [_serialize(db, p) for p in plans]}


@router.post("")
async def create_plan(
    body: PlanCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _validate_items(body.items)
    plan = MealPlan(
        user_id=current_user.id, name=body.name, kind=body.kind, note=body.note,
        created_by=current_user.id, updated_by=current_user.id,
    )
    db.add(plan)
    db.flush()
    _apply_items(db, plan, body.items)
    db.commit()
    db.refresh(plan)
    return _serialize(db, plan)


@router.get("/{plan_id}")
async def get_plan(
    plan_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return _serialize(db, _load_owned(db, current_user, plan_id))


@router.put("/{plan_id}")
async def update_plan(
    plan_id: int,
    body: PlanUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    plan = _load_owned(db, current_user, plan_id)
    if body.name is not None:
        plan.name = body.name
    if body.kind is not None:
        plan.kind = body.kind
    if body.note is not None:
        plan.note = body.note
    plan.updated_by = current_user.id
    if body.items is not None:
        _validate_items(body.items)
        _apply_items(db, plan, body.items)
    db.commit()
    db.refresh(plan)
    return _serialize(db, plan)


@router.delete("/{plan_id}")
async def delete_plan(
    plan_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    plan = _load_owned(db, current_user, plan_id)
    plan.is_active = False
    plan.updated_by = current_user.id
    db.commit()
    return {"ok": True}


@router.post("/evaluate")
async def evaluate(
    body: EvaluateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tz: str = Depends(get_timezone),
):
    _validate_items(body.items)
    from app.services.meal_plan_service import evaluate_items

    items = [it.model_dump() for it in body.items]
    return await evaluate_items(db, current_user, items, body.kind, body.meal_type, tz)


@router.get("/{plan_id}/cost-trend")
async def cost_trend(
    plan_id: int,
    days: int = Query(90, ge=7, le=3650),
    offset_days: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    tz: str = Depends(get_timezone),
):
    plan = _load_owned(db, current_user, plan_id)
    return plan_cost_trend(db, current_user, plan, days, offset_days, tz)
