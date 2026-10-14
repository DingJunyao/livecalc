"""收藏：原料 / 商品 / 菜谱（商家收藏见 api/merchants.py）。

收藏是个人私有数据：登录即可读写，不走 proposals 审批（对齐商家收藏）。
"""
from fastapi import APIRouter, Depends
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.core.exceptions import LocalizedHTTPException
from app.core.security import get_current_user
from app.models.user import User
from app.models.user_favorite import UserFavorite

router = APIRouter()

_ENTITY_TYPES = ("ingredient", "product", "recipe")


def _favorite_items(db: Session, user_id: int, entity_type: str) -> list:
    """按收藏时间倒序返回某类型的收藏条目（轻量浏览信息）。

    不复用各列表页的 display override 与待审逻辑：聚合页只要可点击的浏览项，
    把审批态混进收藏列表反而容易误导。
    """
    fav_rows = (
        db.query(UserFavorite)
        .filter(UserFavorite.user_id == user_id, UserFavorite.entity_type == entity_type)
        .order_by(UserFavorite.created_at.desc(), UserFavorite.id.desc())
        .all()
    )
    ids = [f.entity_id for f in fav_rows]
    if not ids:
        return []
    items = []
    if entity_type == "ingredient":
        from app.models.nutrition import Ingredient

        rows = db.query(Ingredient).filter(
            Ingredient.id.in_(ids), Ingredient.is_active == True
        ).all()
        items = [
            {"id": r.id, "name": r.name, "subtitle": None, "image": None} for r in rows
        ]
    elif entity_type == "product":
        from app.models.product_entity import Product

        rows = db.query(Product).options(joinedload(Product.ingredient)).filter(
            Product.id.in_(ids), Product.is_active == True
        ).all()
        items = [
            {
                "id": r.id,
                "name": r.name,
                "subtitle": r.ingredient.name if r.ingredient else None,
                "image": r.image_url,
            }
            for r in rows
        ]
    elif entity_type == "recipe":
        from app.models.recipe import Recipe

        rows = db.query(Recipe).filter(
            Recipe.id.in_(ids), Recipe.is_active == True
        ).all()
        items = [
            {
                "id": r.id,
                "name": r.name,
                "subtitle": r.category,
                "image": (r.images or [None])[0],
            }
            for r in rows
        ]
    order = {row_id: idx for idx, row_id in enumerate(ids)}
    items.sort(key=lambda it: order.get(it["id"], 1 << 30))
    return items


def _ensure_favoritable(db: Session, entity_type: str, entity_id: int) -> None:
    if entity_type not in _ENTITY_TYPES:
        raise LocalizedHTTPException(
            status_code=400, message='不支持的收藏类型：{entity_type}', entity_type=entity_type
        )
    if entity_type == "ingredient":
        from app.models.nutrition import Ingredient

        row = db.query(Ingredient.id).filter(
            Ingredient.id == entity_id, Ingredient.is_active == True
        ).first()
    elif entity_type == "product":
        from app.models.product_entity import Product

        row = db.query(Product.id).filter(
            Product.id == entity_id, Product.is_active == True
        ).first()
    else:
        from app.models.recipe import Recipe

        row = db.query(Recipe.id).filter(
            Recipe.id == entity_id, Recipe.is_active == True
        ).first()
    if row is None:
        raise LocalizedHTTPException(status_code=404, message='收藏对象不存在或已删除')


@router.get("")
@router.get("/")
async def list_all_favorites(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """聚合四类收藏（供「我的收藏」页）。商家读既有收藏表并补齐有效币种。"""
    from app.api.merchants import _attach_effective_currency
    from app.models.merchant import Merchant
    from app.models.user_merchant_favorite import UserMerchantFavorite
    from app.schemas.merchant import MerchantResponse

    merchant_ids = [
        r[0]
        for r in db.query(UserMerchantFavorite.merchant_id)
        .filter(UserMerchantFavorite.user_id == current_user.id)
        .all()
    ]
    merchants = []
    if merchant_ids:
        merchants = db.query(Merchant).filter(Merchant.id.in_(merchant_ids)).all()
        _attach_effective_currency(db, merchants)
        merchants = [MerchantResponse.model_validate(m) for m in merchants]
    return {
        "ingredients": _favorite_items(db, current_user.id, "ingredient"),
        "products": _favorite_items(db, current_user.id, "product"),
        "recipes": _favorite_items(db, current_user.id, "recipe"),
        "merchants": merchants,
    }


@router.get("/{entity_type}")
async def list_favorites_by_type(
    entity_type: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if entity_type not in _ENTITY_TYPES:
        raise LocalizedHTTPException(
            status_code=400, message='不支持的收藏类型：{entity_type}', entity_type=entity_type
        )
    return _favorite_items(db, current_user.id, entity_type)


@router.post("/{entity_type}/{entity_id}")
async def add_favorite(
    entity_type: str,
    entity_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """收藏（幂等）。"""
    _ensure_favoritable(db, entity_type, entity_id)
    existing = db.query(UserFavorite).filter(
        UserFavorite.user_id == current_user.id,
        UserFavorite.entity_type == entity_type,
        UserFavorite.entity_id == entity_id,
    ).first()
    if existing:
        return {"ok": True}
    db.add(UserFavorite(
        user_id=current_user.id, entity_type=entity_type, entity_id=entity_id
    ))
    try:
        db.commit()
    except IntegrityError:
        # 并发双击：唯一约束兜底，视为已收藏
        db.rollback()
    return {"ok": True}


@router.delete("/{entity_type}/{entity_id}")
async def remove_favorite(
    entity_type: str,
    entity_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """取消收藏（幂等，物理删）。"""
    if entity_type not in _ENTITY_TYPES:
        raise LocalizedHTTPException(
            status_code=400, message='不支持的收藏类型：{entity_type}', entity_type=entity_type
        )
    db.query(UserFavorite).filter(
        UserFavorite.user_id == current_user.id,
        UserFavorite.entity_type == entity_type,
        UserFavorite.entity_id == entity_id,
    ).delete()
    db.commit()
    return {"ok": True}
