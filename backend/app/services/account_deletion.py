"""账号注销：按外键依赖顺序清理用户全部数据，并删除其图片对象。

App Store 审核指南 5.1.1(v) 与 Google Play 的账号删除政策都要求 App 内提供
自助注销；PIPL 下注销也应删除个人信息。

本项目除 product_barcodes 外没有 ON DELETE CASCADE，因此必须显式按
「子表 → 主表 → users」顺序清理，否则 Postgres/MySQL 会因外键约束失败。

两条数据保护规则：
- 他人仍在引用的内容（其他用户的方案/每日推荐里引用的菜谱、他人记录里的商家）
  不物理删除，改为 user_id=None 匿名化，避免破坏其他用户的数据。
- 只删本用户名下的图片对象（头像、菜谱图），并同步清 image_tracking 行。
"""
from __future__ import annotations

import logging
from typing import Iterable, List, Optional

from sqlalchemy.orm import Session

from app.models.agent_approval import AgentApproval
from app.models.agent_message import AgentMessage
from app.models.agent_session import AgentSession
from app.models.ai_usage_event import AiUsageEvent
from app.models.blacklist_group_subscription import BlacklistGroupSubscription
from app.models.change_proposal import ChangeProposal
from app.models.daily_recommendation import DailyRecommendation
from app.models.daily_recommendation_item import DailyRecommendationItem
from app.models.expense import Expense
from app.models.image_tracking import ImageTracking
from app.models.import_task import ImportTask
from app.models.ingredient_merge_record import IngredientMergeRecord
from app.models.invite_code import InviteCode
from app.models.meal_plan import MealPlan, MealPlanItem
from app.models.merchant import Merchant
from app.models.nutrition_data import AIIngredientMatch, NutritionEditHistory
from app.models.operation_log import OperationLog
from app.models.product import ProductRecord
from app.models.recipe import Recipe, RecipeCostHistory, RecipeIngredient
from app.models.region_unit_setting import UserUnitPreference
from app.models.user import User
from app.models.user_ai_settings import UserAiSettings
from app.models.user_calc_scope import UserCalcScope
from app.models.user_favorite import UserFavorite
from app.models.user_ingredient_blacklist import UserIngredientBlacklist
from app.models.user_ingredient_preference import UserIngredientPreference
from app.models.user_merchant_favorite import UserMerchantFavorite
from app.models.user_merchant_product_order import UserMerchantProductOrder
from app.models.user_oauth_account import UserOauthAccount
from app.models.user_place import UserPlace
from app.models.user_product_weight_override import UserProductWeightOverride

logger = logging.getLogger("account_deletion")

_STATIC_IMAGES_PREFIX = "/static/images/"

# 直接按 user_id 物理删除的用户主表（都必须在 users 之前删）
_USER_OWNED_MODELS = (
    UserFavorite,
    UserMerchantFavorite,
    UserCalcScope,
    UserAiSettings,
    UserOauthAccount,
    UserPlace,
    UserIngredientPreference,
    UserIngredientBlacklist,
    BlacklistGroupSubscription,
    UserUnitPreference,
    UserProductWeightOverride,
    UserMerchantProductOrder,
    Expense,
    ImportTask,
    OperationLog,
    AiUsageEvent,
    AgentSession,
    DailyRecommendation,
    MealPlan,
    ProductRecord,
)


def _img_key(value) -> Optional[str]:
    """旧格式 /static/images/xxx 归一化为 storage key xxx（与 recipes.py 同口径）。"""
    if not isinstance(value, str) or not value:
        return None
    return value[len(_STATIC_IMAGES_PREFIX):] if value.startswith(_STATIC_IMAGES_PREFIX) else value


def _ids(db: Session, column, model, uid: int) -> List[int]:
    rows = db.query(column).filter(model.user_id == uid).all()
    return [r[0] for r in rows if r[0] is not None]


def _delete_in(db: Session, model, column, values: Iterable[int]) -> None:
    """按 id 集合删除；空集合直接跳过（避免空 IN 在不同方言下的差异）。"""
    values = list(values)
    if not values:
        return
    db.query(model).filter(column.in_(values)).delete(synchronize_session=False)


def _delete_by_user(db: Session, model, uid: int) -> None:
    db.query(model).filter(model.user_id == uid).delete(synchronize_session=False)


def _purge_images(db: Session, keys: Iterable[str]) -> None:
    keys = [k for k in {_img_key(raw) for raw in keys if raw} if k]
    if not keys:
        return
    try:
        from app.services.storage.factory import get_storage

        storage = get_storage()
        for key in keys:
            try:
                storage.delete(key)
            except FileNotFoundError:
                pass
            except Exception:  # noqa: BLE001 - 单个对象删除失败不应阻断账号注销
                logger.warning("删除图片对象失败：%s", key, exc_info=True)
    except Exception:  # noqa: BLE001 - 存储后端未配置时跳过对象删除
        logger.warning("存储后端不可用，跳过图片对象删除", exc_info=True)
    _delete_in(db, ImageTracking, ImageTracking.key, keys)


def delete_user_account(db: Session, user: User) -> None:
    """物理删除 user 及其全部关联数据。调用方负责校验密码与鉴权。"""
    uid = user.id

    recipe_ids = _ids(db, Recipe.id, Recipe, uid)
    plan_ids = _ids(db, MealPlan.id, MealPlan, uid)
    rec_ids = _ids(db, DailyRecommendation.id, DailyRecommendation, uid)
    session_ids = _ids(db, AgentSession.id, AgentSession, uid)
    merchant_ids = _ids(db, Merchant.id, Merchant, uid)

    # ── 1. 找出「被他人引用」的内容，这些匿名化保留而不是删除 ──────────────
    referenced_recipe_ids: set[int] = set()
    if recipe_ids:
        referenced_recipe_ids |= {
            row[0]
            for row in db.query(MealPlanItem.recipe_id).filter(
                MealPlanItem.recipe_id.in_(recipe_ids),
                MealPlanItem.plan_id.notin_(plan_ids or [-1]),
            ).all()
        }
        referenced_recipe_ids |= {
            row[0]
            for row in db.query(DailyRecommendationItem.recipe_id).filter(
                DailyRecommendationItem.recipe_id.in_(recipe_ids),
                DailyRecommendationItem.recommendation_id.notin_(rec_ids or [-1]),
            ).all()
        }

    still_used_merchant_ids: set[int] = set()
    if merchant_ids:
        # 只看「他人」的引用：自己的引用随后会被一并删除，不应把商家误判为公共保留
        for model, column in (
            (ProductRecord, ProductRecord.merchant_id),
            (UserMerchantFavorite, UserMerchantFavorite.merchant_id),
            (UserMerchantProductOrder, UserMerchantProductOrder.merchant_id),
        ):
            still_used_merchant_ids |= {
                row[0]
                for row in db.query(column).filter(
                    column.in_(merchant_ids), model.user_id != uid
                ).all()
            }

    # ── 2. 子表（先于父表删除）────────────────────────────────────────────
    _delete_in(db, RecipeIngredient, RecipeIngredient.recipe_id, recipe_ids)
    _delete_in(db, RecipeCostHistory, RecipeCostHistory.recipe_id, recipe_ids)
    _delete_in(db, MealPlanItem, MealPlanItem.plan_id, plan_ids)
    _delete_in(db, DailyRecommendationItem, DailyRecommendationItem.recommendation_id, rec_ids)
    _delete_in(db, AgentApproval, AgentApproval.session_id, session_ids)
    _delete_in(db, AgentMessage, AgentMessage.session_id, session_ids)

    # 我方营养编辑历史 edited_by 非空，随账号删除；AI 匹配的审核人仅解绑
    db.query(NutritionEditHistory).filter(
        NutritionEditHistory.edited_by == uid
    ).delete(synchronize_session=False)
    db.query(AIIngredientMatch).filter(
        AIIngredientMatch.verified_by == uid
    ).update({AIIngredientMatch.verified_by: None}, synchronize_session=False)

    # ── 3. 用户主表 ──────────────────────────────────────────────────────
    for model in _USER_OWNED_MODELS:
        _delete_by_user(db, model, uid)

    # 评审/审批/邀请码：删除自己的提案，解绑他人的评审与创建人引用
    db.query(ChangeProposal).filter(
        ChangeProposal.proposer_id == uid
    ).delete(synchronize_session=False)
    db.query(ChangeProposal).filter(ChangeProposal.reviewer_id == uid).update(
        {ChangeProposal.reviewer_id: None}, synchronize_session=False
    )
    db.query(AgentApproval).filter(AgentApproval.decided_by == uid).update(
        {AgentApproval.decided_by: None}, synchronize_session=False
    )
    db.query(InviteCode).filter(InviteCode.created_by == uid).update(
        {InviteCode.created_by: None}, synchronize_session=False
    )
    # 合并记录是审计日志，merged_by 非空，随账号删除
    db.query(IngredientMergeRecord).filter(
        IngredientMergeRecord.merged_by_user_id == uid
    ).delete(synchronize_session=False)

    # ── 4. 菜谱：被他人引用 → 匿名化保留；否则删除并清图片 ──────────────────
    keep_recipe_ids = [rid for rid in recipe_ids if rid in referenced_recipe_ids]
    delete_recipe_ids = [rid for rid in recipe_ids if rid not in referenced_recipe_ids]

    if delete_recipe_ids:
        image_keys: List[str] = [user.avatar] if getattr(user, "avatar", None) else []
        for recipe in db.query(Recipe).filter(Recipe.id.in_(delete_recipe_ids)).all():
            if isinstance(recipe.images, list):
                image_keys.extend(recipe.images)
        # 他人方案里若仍引用（理论上不会走到，因为已算入 referenced），先解绑避免外键失败
        db.query(MealPlanItem).filter(
            MealPlanItem.recipe_id.in_(delete_recipe_ids)
        ).update({MealPlanItem.recipe_id: None}, synchronize_session=False)
        # 每日推荐条目 recipe_id 非空，只能删条目（每日推荐本身是临时数据）
        db.query(DailyRecommendationItem).filter(
            DailyRecommendationItem.recipe_id.in_(delete_recipe_ids)
        ).delete(synchronize_session=False)
        _delete_in(db, Recipe, Recipe.id, delete_recipe_ids)
        _purge_images(db, image_keys)
    elif getattr(user, "avatar", None):
        _purge_images(db, [user.avatar])

    if keep_recipe_ids:
        db.query(Recipe).filter(Recipe.id.in_(keep_recipe_ids)).update(
            {Recipe.user_id: None}, synchronize_session=False
        )

    # ── 5. 商家：被他人引用 → 匿名化为公共；否则删除 ─────────────────────
    keep_merchant_ids = [mid for mid in merchant_ids if mid in still_used_merchant_ids]
    delete_merchant_ids = [mid for mid in merchant_ids if mid not in still_used_merchant_ids]
    if keep_merchant_ids:
        db.query(Merchant).filter(Merchant.id.in_(keep_merchant_ids)).update(
            {Merchant.user_id: None}, synchronize_session=False
        )
    _delete_in(db, Merchant, Merchant.id, delete_merchant_ids)

    db.flush()
    db.query(User).filter(User.id == uid).delete(synchronize_session=False)
    db.commit()
    logger.info("账号已注销：user_id=%s", uid)
