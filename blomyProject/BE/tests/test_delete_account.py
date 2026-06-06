from fastapi.testclient import TestClient

from phora.api.app import create_app
from phora.services.email import EmailService


def _setup(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'del.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")
    monkeypatch.setattr(EmailService, "send_signup_otp", lambda *a, **k: None)


def _register_and_verify(client) -> str:
    sent: dict[str, str] = {}

    orig = EmailService.send_signup_otp

    def capture(self, r, code, locale="en"):
        sent[r] = code

    EmailService.send_signup_otp = capture

    client.post(
        "/api/v1/auth/signup",
        json={
            "email": "del@example.com",
            "password": "password123",
            "first_name": "Del",
            "last_name": "User",
            "country": "GB",
            "account_type": "individual",
        },
    )
    client.post(
        "/api/v1/auth/verify",
        json={"email": "del@example.com", "code": sent.get("del@example.com", "")},
    )
    EmailService.send_signup_otp = orig

    login = client.post(
        "/api/v1/auth/login",
        json={"email": "del@example.com", "password": "password123"},
    )
    return login.json()["access_token"]


def test_delete_account_anonymises_user(tmp_path, monkeypatch):
    _setup(tmp_path, monkeypatch)

    sent: dict[str, str] = {}

    def capture(self, r, code, locale="en"):
        sent[r] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    # register + verify
    client.post(
        "/api/v1/auth/signup",
        json={
            "email": "del@example.com",
            "password": "password123",
            "first_name": "Del",
            "last_name": "User",
            "country": "GB",
            "account_type": "individual",
        },
    )
    client.post(
        "/api/v1/auth/verify",
        json={"email": "del@example.com", "code": sent["del@example.com"]},
    )
    login_resp = client.post(
        "/api/v1/auth/login",
        json={"email": "del@example.com", "password": "password123"},
    )
    assert login_resp.status_code == 200
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # delete account
    resp = client.delete("/api/v1/user/account", headers=headers)
    assert resp.status_code == 200
    assert "personal information" in resp.json()["message"]

    # original access token is now invalid (token_generation bumped)
    profile_resp = client.get("/api/v1/user/profile", headers=headers)
    assert profile_resp.status_code == 401

    # cannot log back in with original credentials
    relogin = client.post(
        "/api/v1/auth/login",
        json={"email": "del@example.com", "password": "password123"},
    )
    assert relogin.status_code in (401, 400, 403)


def test_delete_account_requires_auth(tmp_path, monkeypatch):
    _setup(tmp_path, monkeypatch)
    app = create_app()
    client = TestClient(app)

    resp = client.delete("/api/v1/user/account")
    assert resp.status_code == 401
