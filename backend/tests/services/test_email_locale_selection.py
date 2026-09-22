"""邮件模板按收件人语言选择。"""
import pytest

from app.models.email_template import EmailTemplate
from app.services.email_service import EmailService
from app.services.email_template_seed import ensure_email_templates


@pytest.fixture()
def clean_templates(db_session):
    db_session.query(EmailTemplate).delete()
    db_session.commit()
    yield db_session
    db_session.query(EmailTemplate).delete()
    db_session.commit()


def test_send_template_selects_recipient_locale(clean_templates, monkeypatch):
    db = clean_templates
    ensure_email_templates(db)
    service = EmailService()
    service._cfg = type("Config", (), {"enabled": True, "host": "smtp.test"})()
    sent = []
    monkeypatch.setattr(service, "_send_async", lambda to, subject, body: sent.append((to, subject, body)))

    service.send_template_async(
        "proposal_submitted", "user@example.test", {"proposal_id": "1"}, db, locale="ar"
    )

    assert len(sent) == 1
    assert sent[0][1] == "[LiveCalc] اقتراح تغيير جديد #1"
    assert "اقتراح تغيير جديد" in sent[0][2]


def test_send_template_falls_back_for_unsupported_locale(clean_templates, monkeypatch):
    db = clean_templates
    ensure_email_templates(db)
    service = EmailService()
    service._cfg = type("Config", (), {"enabled": True, "host": "smtp.test"})()
    sent = []
    monkeypatch.setattr(service, "_send_async", lambda to, subject, body: sent.append((to, subject, body)))

    service.send_template_async(
        "proposal_submitted", "user@example.test", {"proposal_id": "1"}, db, locale="ja-JP"
    )

    assert len(sent) == 1
    assert sent[0][1] == "[LiveCalc] 新提议 #1"
    assert "新变更提议" in sent[0][2]


def test_seed_preserves_existing_localized_row(clean_templates):
    db = clean_templates
    ensure_email_templates(db)
    row = db.query(EmailTemplate).filter(
        EmailTemplate.key == "proposal_submitted",
        EmailTemplate.locale == "en-US",
    ).one()
    row.subject = "EDITED"
    db.commit()

    ensure_email_templates(db)

    db.refresh(row)
    assert row.subject == "EDITED"
    assert db.query(EmailTemplate).count() == 9


def test_send_test_uses_requested_catalog_translations(monkeypatch):
    service = EmailService()
    sent = []
    monkeypatch.setattr(service, "_send_async", lambda to, subject, body: sent.append((to, subject, body)))

    service.send_test_async("user@example.test", "ar")
    service.send_test_async("default@example.test")

    assert sent[0][1] == "بريد اختباري - LiveCalc"
    assert "<h1>اختبار إعدادات SMTP</h1>" in sent[0][2]
    assert sent[1][1] == "测试邮件 - LiveCalc"
    assert "<h1>SMTP 配置测试</h1>" in sent[1][2]
