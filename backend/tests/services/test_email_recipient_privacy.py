"""Focused SMTP recipient privacy test."""
from app.services.email_service import EmailService


class FakeSMTP:
    def __init__(self, *args, **kwargs):
        self.sent = []

    def starttls(self):
        pass

    def login(self, *args, **kwargs):
        pass

    def sendmail(self, from_address, recipients, raw_message):
        self.sent.append((from_address, list(recipients), raw_message))

    def quit(self):
        pass


def test_grouped_send_hides_extra_recipients_from_to_header(monkeypatch):
    cfg = type("Config", (), {
        "host": "smtp.test",
        "port": 25,
        "username": "",
        "password": "",
        "use_ssl": False,
        "use_tls": False,
        "from_address": "sender@example.test",
        "from_name": "LiveCalc",
    })()
    service = EmailService()
    service._cfg = cfg
    fake = FakeSMTP()
    monkeypatch.setattr("app.services.email_service.smtplib.SMTP", lambda *args, **kwargs: fake)

    service._send_sync(
        ["first@example.test", "second@example.test", "third@example.test"],
        "Subject",
        "<p>body</p>",
    )

    assert len(fake.sent) == 1
    from_address, recipients, raw_message = fake.sent[0]
    assert from_address == "sender@example.test"
    assert recipients == [
        "first@example.test",
        "second@example.test",
        "third@example.test",
    ]
    assert "To: first@example.test" in raw_message
    assert "To: first@example.test, second@example.test" not in raw_message
    assert "Bcc: second@example.test, third@example.test" in raw_message
