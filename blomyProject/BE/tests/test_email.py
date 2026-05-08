from email.message import EmailMessage

import pytest

from phora.core.config import Settings
from phora.services.email import EmailDeliveryError, EmailService


class _DummySMTP:
    sent_messages: list[EmailMessage] = []

    def __init__(self, host: str, port: int, timeout: int = 10):
        self.host = host
        self.port = port
        self.timeout = timeout

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def starttls(self):
        return None

    def login(self, username: str, password: str):
        self.username = username
        self.password = password

    def send_message(self, message: EmailMessage):
        self.sent_messages.append(message)


def test_send_signup_otp_builds_html_email_with_inline_logo(monkeypatch):
    _DummySMTP.sent_messages = []
    monkeypatch.setattr("phora.services.email.smtplib.SMTP", _DummySMTP)

    settings = Settings(
        smtp_enabled=True,
        smtp_host="smtp.example.com",
        smtp_port=587,
        smtp_from_email="noreply@example.com",
        smtp_from_name="Vyla",
        smtp_use_tls=True,
    )
    service = EmailService(settings)

    service.send_signup_otp("user@example.com", "842193")

    assert len(_DummySMTP.sent_messages) == 1
    message = _DummySMTP.sent_messages[0]
    html_parts = [part for part in message.walk() if part.get_content_type() == "text/html"]
    plain_parts = [part for part in message.walk() if part.get_content_type() == "text/plain"]
    image_parts = [part for part in message.walk() if part.get_content_maintype() == "image"]

    assert plain_parts
    assert "842193" in plain_parts[0].get_content()

    assert html_parts
    html = html_parts[0].get_content()
    assert "Verify it" in html
    assert all(d in html for d in "842193")
    assert "Keep your account safe" in html
    assert "Didn" in html and "request this" in html
    assert "Vyla Health Ltd." in html
    assert "#FF8A4C" in html
    assert "cid:" in html

    assert len(image_parts) == 1
    assert image_parts[0].get_filename() == "vyla-logo.png"


def test_deployed_environment_raises_when_smtp_disabled():
    settings = Settings(environment="prod", smtp_enabled=False)
    service = EmailService(settings)

    with pytest.raises(EmailDeliveryError, match="SMTP is disabled"):
        service.send_signup_otp("user@example.com", "842193")
