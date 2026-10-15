"""用户级 AI 设置端点（BYOK 与方法选择；设计 §4.8）。

- GET /api/v1/profile/ai-settings        自己的设置（管理员可带 ?user_id= 看他人）
- PUT /api/v1/profile/ai-settings        修改；管理员可带 user_id 改他人
密钥只回显打码值；api_key 传空串=不变，传 null=清除。
"""
import logging
from typing import Optional

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.exceptions import LocalizedHTTPException
from app.core.security import get_current_user
from app.models.user import User
from app.services.ai_policy import (
    DEFAULT_AI_POLICY,
    USER_AI_PROVIDERS,
    VALID_METHODS,
    encrypt_api_key,
    get_policy,
    get_user_ai_settings,
    mask_key,
    decrypt_api_key,
)

logger = logging.getLogger("ai_settings")
router = APIRouter()


class AiSettingsUpdate(BaseModel):
    method: Optional[str] = None
    provider: Optional[str] = None
    base_url: Optional[str] = None
    model: Optional[str] = None
    api_key: Optional[str] = None  # 空串=不变；None=清除；其余=更新
    daily_limit_override: Optional[int] = None


def _target_user(db: Session, current_user: User, user_id: Optional[int]) -> User:
    if user_id is None or user_id == current_user.id:
        return current_user
    if not current_user.is_admin:
        raise LocalizedHTTPException(status_code=403, message='仅管理员可查看或修改其他用户的 AI 设置')
    from app.models.user import User as UserModel

    target = db.query(UserModel).filter(UserModel.id == user_id).first()
    if target is None:
        raise LocalizedHTTPException(status_code=404, message='用户不存在')
    return target


def _serialize(row, policy: dict) -> dict:
    plain = decrypt_api_key(row.api_key_enc) if row and row.api_key_enc else ""
    return {
        "method": row.method if row else None,
        "provider": row.provider if row else None,
        "base_url": row.base_url if row else None,
        "model": row.model if row else None,
        "api_key_masked": mask_key(plain) if plain else "",
        "has_api_key": bool(plain),
        "daily_limit_override": row.daily_ai_limit_override if row else None,
        "policy": policy,
    }


@router.get("")
async def get_ai_settings(
    user_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target = _target_user(db, current_user, user_id)
    return _serialize(get_user_ai_settings(db, target.id), get_policy(db))


@router.put("")
async def update_ai_settings(
    body: AiSettingsUpdate,
    user_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target = _target_user(db, current_user, user_id)
    policy = get_policy(db)

    if body.method is not None:
        if body.method not in VALID_METHODS:
            raise LocalizedHTTPException(
                status_code=400, message='不支持的 AI 方法：{method}', method=body.method)
        if body.method not in ("rule",) and body.method != policy["default_method"]:
            if not policy.get("allow_user_choice") and not current_user.is_admin:
                raise LocalizedHTTPException(status_code=400, message='管理员未开放 AI 方法自选')
        if body.method == "user_ai" and not policy.get("allow_byok") and not current_user.is_admin:
            raise LocalizedHTTPException(status_code=400, message='管理员未开放自备密钥（BYOK）')

    if body.provider is not None and body.provider not in USER_AI_PROVIDERS:
        raise LocalizedHTTPException(
            status_code=400, message='自备密钥仅支持：{providers}',
            providers='、'.join(USER_AI_PROVIDERS))

    if body.base_url and not policy.get("allow_custom_base_url") and not current_user.is_admin:
        raise LocalizedHTTPException(status_code=400, message='管理员未开放自定义端点地址')

    row = get_user_ai_settings(db, target.id)
    if row is None:
        from app.models.user_ai_settings import UserAiSettings

        row = UserAiSettings(user_id=target.id)
        db.add(row)

    if body.method is not None:
        row.method = body.method
    if body.provider is not None:
        row.provider = body.provider
    if body.base_url is not None:
        row.base_url = body.base_url or None
    if body.model is not None:
        row.model = body.model or None
    if body.api_key is not None:
        # 空串 = 保持不变；None 由 None 判断进不来（见下），显式清除用字段 "clear"
        row.api_key_enc = encrypt_api_key(body.api_key) if body.api_key else row.api_key_enc
    if body.daily_limit_override is not None:
        row.daily_ai_limit_override = body.daily_limit_override or None

    db.commit()
    db.refresh(row)
    return _serialize(row, policy)


@router.delete("/api-key")
async def clear_api_key(
    user_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """清除自备密钥。"""
    target = _target_user(db, current_user, user_id)
    row = get_user_ai_settings(db, target.id)
    if row is not None and row.api_key_enc:
        row.api_key_enc = None
        db.commit()
    return {"ok": True}


# 供路由挂载时引用的默认策略（前端空态展示用）
DEFAULT_POLICY = DEFAULT_AI_POLICY
