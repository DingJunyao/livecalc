"""邮件模板默认种子数据与服务。

``email_templates`` 表由 ``create_all`` 建表，但默认模板的数据原本只写在
alembic 迁移（``20260704_0001``）和手动 SQL 脚本里——本项目走 ``create_all``、
不跑 alembic，故默认模板从未被插入，导致 ``email_service.send_template_async``
查不到模板而静默跳过所有审核通知邮件。

本模块作为默认模板的**唯一数据源**，供 lifespan 启动时幂等补齐缺失模板。
"""
import logging

from sqlalchemy.orm import Session

from app.core.i18n import SUPPORTED_LOCALES
from app.models.email_template import EmailTemplate

logger = logging.getLogger(__name__)


# ── 默认邮件模板（按 key + locale 组织，展开为九条种子记录）──────
# body_html 使用 string.Template 语法（${var}），与 EmailService.send_template_async
# 的 safe_substitute 对齐。注意：这里不能用 f-string，否则 ${} 会被误解析。
_EMAIL_TEMPLATE_CATALOG = {
    "proposal_submitted": {
        "zh-CN": {
            "name": "新提议通知（管理员）",
            "subject": "[LiveCalc] 新提议 #${proposal_id}",
            "body_html": (
                "<h2>新变更提议</h2>"
                "<p>用户 <strong>${proposer_name}</strong> 提交了一条新的变更提议，需要审核。</p>"
                "<table>"
                "<tr><td>提议编号</td><td>#${proposal_id}</td></tr>"
                "<tr><td>实体类型</td><td>${entity_type_label}</td></tr>"
                "<tr><td>操作</td><td>${action_label}</td></tr>"
                "<tr><td>目标</td><td>${entity_label}</td></tr>"
                "</table>"
            ),
            "description": "用户提交变更提议时通知所有管理员",
        },
        "en-US": {
            "name": "New change proposal notification (admin)",
            "subject": "[LiveCalc] New change proposal #${proposal_id}",
            "body_html": (
                "<h2>New change proposal</h2>"
                "<p>User <strong>${proposer_name}</strong> submitted a new change proposal that requires review.</p>"
                "<table>"
                "<tr><td>Proposal ID</td><td>#${proposal_id}</td></tr>"
                "<tr><td>Entity type</td><td>${entity_type_label}</td></tr>"
                "<tr><td>Action</td><td>${action_label}</td></tr>"
                "<tr><td>Target</td><td>${entity_label}</td></tr>"
                "</table>"
            ),
            "description": "Notify all administrators when a user submits a change proposal",
        },
        "ar": {
            "name": "إشعار اقتراح تغيير جديد (مسؤول)",
            "subject": "[LiveCalc] اقتراح تغيير جديد #${proposal_id}",
            "body_html": (
                "<h2>اقتراح تغيير جديد</h2>"
                "<p>قدّم المستخدم <strong>${proposer_name}</strong> اقتراح تغيير جديدًا يتطلب المراجعة.</p>"
                "<table>"
                "<tr><td>معرّف الاقتراح</td><td>#${proposal_id}</td></tr>"
                "<tr><td>نوع الكيان</td><td>${entity_type_label}</td></tr>"
                "<tr><td>الإجراء</td><td>${action_label}</td></tr>"
                "<tr><td>الهدف</td><td>${entity_label}</td></tr>"
                "</table>"
            ),
            "description": "إشعار جميع المسؤولين عند تقديم اقتراح تغيير",
        },
    },
    "proposal_approved": {
        "zh-CN": {
            "name": "提议通过通知（发起者）",
            "subject": "[LiveCalc] 提议 #${proposal_id} 已通过",
            "body_html": (
                "<h2>提议已通过</h2>"
                "<p>您的变更提议已通过审核并生效。</p>"
                "<table>"
                "<tr><td>提议编号</td><td>#${proposal_id}</td></tr>"
                "<tr><td>实体类型</td><td>${entity_type_label}</td></tr>"
                "<tr><td>操作</td><td>${action_label}</td></tr>"
                "<tr><td>目标</td><td>${entity_label}</td></tr>"
                "</table>"
            ),
            "description": "提议审核通过时通知发起者",
        },
        "en-US": {
            "name": "Proposal approved notification (proposer)",
            "subject": "[LiveCalc] Proposal #${proposal_id} approved",
            "body_html": (
                "<h2>Proposal approved</h2>"
                "<p>Your change proposal has been approved and is now in effect.</p>"
                "<table>"
                "<tr><td>Proposal ID</td><td>#${proposal_id}</td></tr>"
                "<tr><td>Entity type</td><td>${entity_type_label}</td></tr>"
                "<tr><td>Action</td><td>${action_label}</td></tr>"
                "<tr><td>Target</td><td>${entity_label}</td></tr>"
                "</table>"
            ),
            "description": "Notify the proposer after a proposal is approved",
        },
        "ar": {
            "name": "إشعار الموافقة على الاقتراح (مقدم الاقتراح)",
            "subject": "[LiveCalc] تمت الموافقة على الاقتراح #${proposal_id}",
            "body_html": (
                "<h2>تمت الموافقة على الاقتراح</h2>"
                "<p>تمت الموافقة على اقتراح التغيير الخاص بك وبدأ سريانه.</p>"
                "<table>"
                "<tr><td>معرّف الاقتراح</td><td>#${proposal_id}</td></tr>"
                "<tr><td>نوع الكيان</td><td>${entity_type_label}</td></tr>"
                "<tr><td>الإجراء</td><td>${action_label}</td></tr>"
                "<tr><td>الهدف</td><td>${entity_label}</td></tr>"
                "</table>"
            ),
            "description": "إشعار مقدم الاقتراح بعد الموافقة عليه",
        },
    },
    "proposal_rejected": {
        "zh-CN": {
            "name": "提议驳回通知（发起者）",
            "subject": "[LiveCalc] 提议 #${proposal_id} 未通过",
            "body_html": (
                "<h2>提议未通过</h2>"
                "<p>您的变更提议未通过审核。</p>"
                "<table>"
                "<tr><td>提议编号</td><td>#${proposal_id}</td></tr>"
                "<tr><td>实体类型</td><td>${entity_type_label}</td></tr>"
                "<tr><td>操作</td><td>${action_label}</td></tr>"
                "<tr><td>目标</td><td>${entity_label}</td></tr>"
                "</table>"
                "<p>审核备注：${review_note}</p>"
            ),
            "description": "提议审核驳回时通知发起者",
        },
        "en-US": {
            "name": "Proposal rejected notification (proposer)",
            "subject": "[LiveCalc] Proposal #${proposal_id} rejected",
            "body_html": (
                "<h2>Proposal rejected</h2>"
                "<p>Your change proposal was not approved.</p>"
                "<table>"
                "<tr><td>Proposal ID</td><td>#${proposal_id}</td></tr>"
                "<tr><td>Entity type</td><td>${entity_type_label}</td></tr>"
                "<tr><td>Action</td><td>${action_label}</td></tr>"
                "<tr><td>Target</td><td>${entity_label}</td></tr>"
                "</table>"
                "<p>Review note: ${review_note}</p>"
            ),
            "description": "Notify the proposer after a proposal is rejected",
        },
        "ar": {
            "name": "إشعار رفض الاقتراح (مقدم الاقتراح)",
            "subject": "[LiveCalc] تم رفض الاقتراح #${proposal_id}",
            "body_html": (
                "<h2>تم رفض الاقتراح</h2>"
                "<p>لم تتم الموافقة على اقتراح التغيير الخاص بك.</p>"
                "<table>"
                "<tr><td>معرّف الاقتراح</td><td>#${proposal_id}</td></tr>"
                "<tr><td>نوع الكيان</td><td>${entity_type_label}</td></tr>"
                "<tr><td>الإجراء</td><td>${action_label}</td></tr>"
                "<tr><td>الهدف</td><td>${entity_label}</td></tr>"
                "</table>"
                "<p>ملاحظة المراجعة: ${review_note}</p>"
            ),
            "description": "إشعار مقدم الاقتراح بعد رفضه",
        },
    },
}


EMAIL_TEMPLATES = [
    {**template, "key": key, "locale": locale}
    for key, templates in _EMAIL_TEMPLATE_CATALOG.items()
    for locale, template in templates.items()
    if locale in SUPPORTED_LOCALES
]


def _create_templates(db: Session) -> int:
    """补齐缺失的默认模板（按 key + locale 判断，已存在项一律不动）。

    返回新增条数。采用「按 key 逐个补齐」而非「count>0 跳过」——模板可能被
    管理员经 ``PUT /admin/email-config/templates/{key}`` 编辑过，按 key 补齐
    既能保护管理员修改、又能在中途失败后重启补齐缺失项。
    """
    existing_templates = set(db.query(EmailTemplate.key, EmailTemplate.locale).all())
    created = 0
    for tpl in EMAIL_TEMPLATES:
        if (tpl["key"], tpl["locale"]) in existing_templates:
            continue
        db.add(EmailTemplate(**tpl))
        created += 1
    if created:
        db.commit()
    return created


def ensure_email_templates(db: Session) -> None:
    """幂等确保默认邮件模板存在：仅补缺失项，不覆盖已存在模板。"""
    created = _create_templates(db)
    if created:
        logger.info("邮件模板初始化完成：新增 %d 条", created)
    else:
        logger.info("默认邮件模板均已存在，跳过初始化")
