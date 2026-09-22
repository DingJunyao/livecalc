"""邮件通知：提议提交/审核通过/驳回时发送邮件。

从 proposals.py 提取，消除直接调用 proposal_service.submit() 绕过通知的问题。
"""
import logging
from typing import Optional

from app.core.i18n import DEFAULT_LOCALE, normalize_locale

logger = logging.getLogger(__name__)


# 与前端 entityTypeLabel / actionLabel 保持一致的翻译映射
_ENTITY_TYPE_LABELS: dict[str, dict[str, str]] = {
    "ingredient": {"zh-CN": "原料", "en-US": "Ingredient", "ar": "مكون"},
    "ingredient_merge": {
        "zh-CN": "原料合并", "en-US": "Ingredient merge", "ar": "دمج المكونات",
    },
    "ingredient_split": {
        "zh-CN": "原料拆分", "en-US": "Ingredient split", "ar": "تقسيم المكونات",
    },
    "nutrition": {
        "zh-CN": "营养数据", "en-US": "Nutrition data", "ar": "بيانات التغذية",
    },
    "unit": {"zh-CN": "单位", "en-US": "Unit", "ar": "وحدة"},
    "hierarchy": {
        "zh-CN": "食材层级关系",
        "en-US": "Ingredient hierarchy",
        "ar": "تسلسل المكونات",
    },
    "merchant": {"zh-CN": "商家", "en-US": "Merchant", "ar": "تاجر"},
    "merchant_merge": {
        "zh-CN": "商家合并", "en-US": "Merchant merge", "ar": "دمج التجار",
    },
    "product_split": {
        "zh-CN": "商品拆分", "en-US": "Product split", "ar": "تقسيم المنتجات",
    },
    "product_merge": {
        "zh-CN": "商品合并", "en-US": "Product merge", "ar": "دمج المنتجات",
    },
    "product": {"zh-CN": "商品", "en-US": "Product", "ar": "منتج"},
    "recipe": {"zh-CN": "菜谱", "en-US": "Recipe", "ar": "وصفة"},
    "recipe_edit": {
        "zh-CN": "菜谱编辑", "en-US": "Recipe edit", "ar": "تعديل الوصفة",
    },
    "entity_unit_override": {
        "zh-CN": "实体单位覆盖",
        "en-US": "Entity unit override",
        "ar": "تجاوز وحدة الكيان",
    },
    "entity_density": {
        "zh-CN": "实体密度", "en-US": "Entity density", "ar": "كثافة الكيان",
    },
    "usda_ingredient_match": {
        "zh-CN": "USDA 原料匹配",
        "en-US": "USDA ingredient match",
        "ar": "مطابقة مكون USDA",
    },
    "usda_product_match": {
        "zh-CN": "USDA 商品匹配",
        "en-US": "USDA product match",
        "ar": "مطابقة منتج USDA",
    },
    "product_nutrition": {
        "zh-CN": "商品营养", "en-US": "Product nutrition", "ar": "تغذية المنتج",
    },
}

_ACTION_LABELS: dict[str, dict[str, str]] = {
    "create": {"zh-CN": "创建", "en-US": "Create", "ar": "إنشاء"},
    "update": {"zh-CN": "更新", "en-US": "Update", "ar": "تحديث"},
    "delete": {"zh-CN": "删除", "en-US": "Delete", "ar": "حذف"},
    "merge": {"zh-CN": "合并", "en-US": "Merge", "ar": "دمج"},
    "publish": {"zh-CN": "发布", "en-US": "Publish", "ar": "نشر"},
}


def _entity_label_for_email(db, proposal) -> str:
    """获取实体的可读标签用于邮件。"""
    from app.services.proposals.registry import ExecutorRegistry
    executor = ExecutorRegistry.get(proposal.entity_type)
    if executor is not None:
        try:
            label = executor.entity_label(db, proposal)
            if label:
                return label
        except Exception:
            pass
    return (f"{proposal.entity_type}#{proposal.entity_id}"
            if proposal.entity_id else proposal.entity_type)


def _build_variables(
    db,
    proposal,
    extra_vars: Optional[dict] = None,
    locale: str = DEFAULT_LOCALE,
) -> dict:
    """构造邮件模板变量。"""
    from app.models.user import User
    selected_locale = normalize_locale(locale) or DEFAULT_LOCALE
    proposer = db.query(User).filter(User.id == proposal.proposer_id).first()
    entity_type_labels = _ENTITY_TYPE_LABELS.get(proposal.entity_type, {})
    action_labels = _ACTION_LABELS.get(proposal.action, {})
    variables = {
        "proposer_name": f"#{proposal.proposer_id}" if proposer is None else (proposer.username or f"#{proposal.proposer_id}"),
        "proposal_id": str(proposal.id),
        "entity_type_label": entity_type_labels.get(
            selected_locale, proposal.entity_type
        ),
        "action_label": action_labels.get(selected_locale, proposal.action),
        "entity_label": _entity_label_for_email(db, proposal),
    }
    if extra_vars:
        variables.update(extra_vars)
    return variables


def _get_email_service(db):
    """按当前 SMTP 配置构造 EmailService。"""
    from app.models.smtp_config import SmtpConfig
    from app.services.email_service import EmailService
    config = db.query(SmtpConfig).first()
    return EmailService(config)


def notify_admins_on_submit(db, proposal) -> None:
    """有新的 manual 提议时通知所有管理员。在 submit 后调用。"""
    from app.models.user import User
    service = _get_email_service(db)
    if not service.ready:
        return
    admins = db.query(User).filter(User.is_admin.is_(True)).all()
    if not admins:
        return
    recipients_by_locale: dict[str, list[str]] = {}
    for admin in admins:
        if not admin.email:
            continue
        locale = normalize_locale(admin.locale) or DEFAULT_LOCALE
        recipients_by_locale.setdefault(locale, []).append(admin.email)

    for locale, emails in recipients_by_locale.items():
        variables = _build_variables(db, proposal, locale=locale)
        service.send_template_async(
            "proposal_submitted", emails, variables, db, locale=locale
        )


def notify_proposer(db, proposal, template_key: str, extra_vars: Optional[dict] = None) -> None:
    """审核完成后通知提议发起者。在 review 后调用。"""
    from app.models.user import User
    service = _get_email_service(db)
    if not service.ready:
        return
    proposer = db.query(User).filter(User.id == proposal.proposer_id).first()
    if not proposer or not proposer.email:
        return
    locale = normalize_locale(proposer.locale) or DEFAULT_LOCALE
    variables = _build_variables(db, proposal, extra_vars, locale=locale)
    service.send_template_async(template_key, proposer.email, variables, db, locale=locale)
