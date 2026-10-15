"""AI 使用策略层（通用，不限餐食推荐；设计 §4.8）。

配置来源：
- 全局：translation_configs 单行 JSON 的 `meal_plan` 与 `ai_policy` 区块
  （由 usda_admin.DEFAULT_* 提供默认值，本模块提供读取与合并兜底）。
- 用户级：user_ai_settings（method / BYOK 凭据 / 上限覆盖）。

解析顺序：用户 method（在全局允许范围内）→ 全局 default_method → rule。
api_key 用 Fernet 加密落库（key 由 SECRET_KEY 派生），接口只回显打码值。
"""
import base64
import datetime
import hashlib
import logging
from typing import Optional

from cryptography.fernet import Fernet, InvalidToken
from sqlalchemy.orm import Session

from app.config import settings

logger = logging.getLogger("ai_policy")

SCOPE_MEAL_PLAN = "meal_plan"

DEFAULT_MEAL_PLAN = {"provider": "claude_code", "timeout_seconds": 120}
DEFAULT_AI_POLICY = {
    "default_method": "system_ai",
    "allow_user_choice": True,
    "allow_byok": True,
    "allow_custom_base_url": False,
    "daily_ai_limit": 20,
    "show_ai_badge": True,
}

VALID_METHODS = ("rule", "system_ai", "user_ai")
USER_AI_PROVIDERS = ("openai", "anthropic")

_fernet_cache: Optional[Fernet] = None


def _fernet() -> Fernet:
    global _fernet_cache
    if _fernet_cache is None:
        digest = hashlib.sha256(settings.jwt_secret_key.encode("utf-8")).digest()
        _fernet_cache = Fernet(base64.urlsafe_b64encode(digest))
    return _fernet_cache


def encrypt_api_key(plain: str) -> str:
    return _fernet().encrypt(plain.encode("utf-8")).decode("ascii")


def decrypt_api_key(enc: str) -> str:
    try:
        return _fernet().decrypt(enc.encode("ascii")).decode("utf-8")
    except (InvalidToken, ValueError):
        logger.warning("api_key 解密失败（密钥轮换或数据损坏），按未配置处理")
        return ""


def mask_key(plain: str) -> str:
    if not plain:
        return ""
    if len(plain) <= 8:
        return "*" * len(plain)
    return f"{plain[:4]}****{plain[-4:]}"


def get_meal_plan_cfg(db: Session) -> dict:
    """meal_plan 区块（provider + timeout_seconds），带默认合并。"""
    from app.models.usda import TranslationConfig

    row = db.query(TranslationConfig).first()
    stored = (row.to_dict() or {}) if row else {}
    cfg = dict(DEFAULT_MEAL_PLAN)
    cfg.update(stored.get("meal_plan") or {})
    return cfg


def get_policy(db: Session) -> dict:
    """ai_policy 区块，带默认合并。"""
    from app.models.usda import TranslationConfig

    row = db.query(TranslationConfig).first()
    stored = (row.to_dict() or {}) if row else {}
    policy = dict(DEFAULT_AI_POLICY)
    policy.update(stored.get("ai_policy") or {})
    return policy


def get_user_ai_settings(db: Session, user_id: int):
    from app.models.user_ai_settings import UserAiSettings

    return db.query(UserAiSettings).filter(
        UserAiSettings.user_id == user_id
    ).first()


def resolve_ai_credentials(db: Session, user, scope: str = SCOPE_MEAL_PLAN) -> dict:
    """解析用户的 AI 使用方法与凭据。

    返回：
      {"method": "rule"}
      或 {"method": "system_ai"|"user_ai", "provider": str,
          "section": dict, "timeout": int}
    """
    from app.services.translate.registry import find_provider_section

    policy = get_policy(db)
    meal_cfg = get_meal_plan_cfg(db)

    row = get_user_ai_settings(db, user.id)
    user_method = (row.method if row else None) or policy["default_method"]

    # 用户自选必须被允许；否则落全局默认
    if row is not None and row.method and row.method != policy["default_method"]:
        if not policy.get("allow_user_choice"):
            user_method = policy["default_method"]

    if user_method not in ("system_ai", "user_ai"):
        return {"method": "rule"}

    timeout = int(meal_cfg.get("timeout_seconds") or 120)

    if user_method == "user_ai":
        if not policy.get("allow_byok") or row is None or not row.provider:
            return {"method": "rule"}
        if row.provider not in USER_AI_PROVIDERS:
            return {"method": "rule"}
        api_key = decrypt_api_key(row.api_key_enc) if row.api_key_enc else ""
        if not api_key:
            return {"method": "rule"}
        base_url = row.base_url
        if base_url and not policy.get("allow_custom_base_url"):
            # 自定义端点未放开时，BYOK 只能配合管理员配置的同 provider 端点：
            # 取全局该 provider 的 base_url（若无配置则视为不可用）
            global_section = _global_ai_section(db, row.provider)
            if not global_section:
                return {"method": "rule"}
            base_url = global_section.get("base_url")
        if not base_url:
            return {"method": "rule"}
        return {
            "method": "user_ai",
            "provider": row.provider,
            "section": {
                "base_url": base_url,
                "api_key": api_key,
                "model": row.model or "",
            },
            "timeout": timeout,
        }

    # system_ai：meal_plan.provider 的全局配置
    provider = meal_cfg.get("provider")
    section = _global_ai_section(db, provider)
    if not section:
        return {"method": "rule"}
    return {
        "method": "system_ai",
        "provider": provider,
        "section": section,
        "timeout": timeout,
    }


def _global_ai_section(db: Session, provider: str) -> Optional[dict]:
    """translation_configs 里 AI provider 的配置段；claude_code/codex 无需 key。"""
    from app.models.usda import TranslationConfig
    from app.services.translate.registry import find_provider_section

    if provider in ("claude_code", "codex"):
        return {"enabled": True}
    row = db.query(TranslationConfig).first()
    stored = (row.to_dict() or {}) if row else {}
    section = find_provider_section(stored, provider)
    if not section or not section.get("enabled"):
        return None
    if not section.get("api_key") or not section.get("base_url"):
        return None
    return section


def count_today_system_ai_usage(db: Session, user_id: int, scope: str = SCOPE_MEAL_PLAN) -> int:
    """今天（UTC 日）system_ai 的 ok/fallback 次数（error 不计入消耗）。"""
    from app.models.ai_usage_event import AiUsageEvent

    start = datetime.datetime.now(datetime.timezone.utc).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    return db.query(AiUsageEvent).filter(
        AiUsageEvent.user_id == user_id,
        AiUsageEvent.scope == scope,
        AiUsageEvent.method == "system_ai",
        AiUsageEvent.status.in_(("ok", "fallback")),
        AiUsageEvent.created_at >= start,
    ).count()


def system_ai_limit_reached(db: Session, user, policy: Optional[dict] = None) -> bool:
    policy = policy or get_policy(db)
    limit = policy.get("daily_ai_limit")
    if limit is None:
        return False
    row = get_user_ai_settings(db, user.id)
    if row is not None and row.daily_ai_limit_override is not None:
        limit = row.daily_ai_limit_override
    if limit is None or limit < 0:
        return False
    return count_today_system_ai_usage(db, user.id) >= int(limit)


def record_usage(
    db: Session, user_id: int, scope: str, method: str,
    provider: Optional[str], status: str,
) -> None:
    """记一条用量事件并提交；失败只留日志，不影响主流程。"""
    from app.models.ai_usage_event import AiUsageEvent

    try:
        db.add(AiUsageEvent(
            user_id=user_id, scope=scope, method=method,
            provider=provider, status=status,
        ))
        db.commit()
    except Exception:
        db.rollback()
        logger.warning("记录 AI 用量事件失败", exc_info=True)
