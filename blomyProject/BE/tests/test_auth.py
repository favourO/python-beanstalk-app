from fastapi.testclient import TestClient
from datetime import UTC, datetime

from phora.api.app import create_app
from phora.core.security import decode_token_safe
from phora.services.auth import AuthService
from phora.services.email import EmailService


def test_signup_verify_login_flow(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'auth.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "otp@example.com",
            "password": "password123",
            "first_name": "Otp",
            "last_name": "Tester",
            "country": "US",
            "account_type": "individual",
        },
    )
    assert signup.status_code == 200
    assert sent_codes["otp@example.com"].isdigit()
    assert len(sent_codes["otp@example.com"]) == 6

    blocked_login = client.post(
        "/api/0.1.0/auth/login",
        json={"email": "otp@example.com", "password": "password123"},
    )
    assert blocked_login.status_code == 202
    blocked_body = blocked_login.json()
    assert blocked_body["requires_verification"] is True
    assert blocked_body["email"] == "otp@example.com"

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "otp@example.com", "code": sent_codes["otp@example.com"]},
    )
    assert verify.status_code == 200
    verify_body = verify.json()
    assert verify_body["user"]["email_verified"] is True
    assert verify_body["is_new_user"] is True
    assert verify_body["access_token"]

    login = client.post(
        "/api/0.1.0/auth/login",
        json={"email": "otp@example.com", "password": "password123"},
    )
    assert login.status_code == 200
    login_body = login.json()
    assert login_body["user"]["email"] == "otp@example.com"


def test_login_flags_reflect_onboarding_and_subscription_selection(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'auth-flags.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "flags@example.com",
            "password": "password123",
            "first_name": "Flag",
            "last_name": "User",
            "country": "UK",
            "account_type": "email",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "flags@example.com", "code": sent_codes["flags@example.com"]},
    )
    assert verify.status_code == 200
    assert verify.json()["onboarding_completed"] is False
    assert verify.json()["onboarding_current_step"] == 1
    assert verify.json()["onboarding_progress"] is None
    assert verify.json()["show_onboarding_flow"] is True
    assert verify.json()["subscription_selected"] is False
    assert verify.json()["show_subscription_screen"] is False

    access_token = verify.json()["access_token"]
    headers = {"Authorization": f"Bearer {access_token}"}

    progress = client.patch(
        "/api/v1/onboarding/progress",
        headers=headers,
        json={
            "current_step": 2,
            "period_length": 5,
            "last_period_start": "2026-04-06",
            "last_period_end": "2026-04-10",
        },
    )
    assert progress.status_code == 200

    complete = client.post(
        "/api/v1/onboarding/complete",
        headers=headers,
        json={
            "cycle_history": {
                "last_period_start": "2026-04-06",
                "last_period_end": "2026-04-10",
                "average_period_length": 5,
                "average_cycle_length": 28,
            },
            "goal": "avoid_pregnancy",
            "health_conditions": ["PCOS"],
        },
    )
    assert complete.status_code == 200

    login_after_onboarding = client.post(
        "/api/0.1.0/auth/login",
        json={"email": "flags@example.com", "password": "password123"},
    )
    assert login_after_onboarding.status_code == 200
    assert login_after_onboarding.json()["onboarding_completed"] is True
    assert login_after_onboarding.json()["onboarding_current_step"] is None
    assert login_after_onboarding.json()["onboarding_progress"] is None
    assert login_after_onboarding.json()["show_onboarding_flow"] is False
    assert login_after_onboarding.json()["subscription_selected"] is False
    assert login_after_onboarding.json()["show_subscription_screen"] is True
    assert login_after_onboarding.json()["show_premium_screen"] is True

    selection = client.post(
        "/api/v1/billing/subscription-selection",
        headers=headers,
        json={"tier": "free"},
    )
    assert selection.status_code == 200

    login_after_selection = client.post(
        "/api/0.1.0/auth/login",
        json={"email": "flags@example.com", "password": "password123"},
    )
    assert login_after_selection.status_code == 200
    assert login_after_selection.json()["onboarding_completed"] is True
    assert login_after_selection.json()["onboarding_current_step"] is None
    assert login_after_selection.json()["onboarding_progress"] is None
    assert login_after_selection.json()["subscription_selected"] is True
    assert login_after_selection.json()["show_subscription_screen"] is False
    assert login_after_selection.json()["subscription_tier"] == "free"
    assert login_after_selection.json()["subscription_active"] is True


def test_login_returns_saved_onboarding_progress(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'auth-progress.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "resume@example.com",
            "password": "password123",
            "first_name": "Resume",
            "last_name": "User",
            "country": "UK",
            "account_type": "email",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "resume@example.com", "code": sent_codes["resume@example.com"]},
    )
    assert verify.status_code == 200
    headers = {"Authorization": f"Bearer {verify.json()['access_token']}"}

    draft = client.patch(
        "/api/v1/onboarding/progress",
        headers=headers,
        json={
            "current_step": 3,
            "period_length": 5,
            "last_period_start": "2026-04-06",
            "last_period_end": "2026-04-10",
            "goal": "avoid_pregnancy",
            "health_conditions": ["PCOS"],
        },
    )
    assert draft.status_code == 200

    login = client.post(
        "/api/0.1.0/auth/login",
        json={"email": "resume@example.com", "password": "password123"},
    )
    assert login.status_code == 200
    assert login.json()["onboarding_completed"] is False
    assert login.json()["onboarding_current_step"] == 3
    assert login.json()["onboarding_progress"] == {
        "period_length": 5,
        "last_period_start": "2026-04-06",
        "last_period_end": "2026-04-10",
        "goal": "avoid",
        "health_conditions": ["PCOS"],
    }


def test_signup_fails_when_email_exists(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'auth-conflict.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    monkeypatch.setattr(EmailService, "send_signup_otp", lambda self, recipient, code, locale="en": None)

    app = create_app()
    client = TestClient(app)

    payload = {
        "email": "dup@example.com",
        "password": "password123",
        "first_name": "Dup",
        "last_name": "User",
        "country": "US",
        "account_type": "business",
    }
    assert client.post("/api/0.1.0/auth/signup", json=payload).status_code == 200
    conflict = client.post("/api/0.1.0/auth/signup", json=payload)
    assert conflict.status_code == 409


def test_signup_blocks_disposable_email_domain(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'auth-disposable.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "fake@mailinator.com",
            "password": "password123",
            "first_name": "Fake",
            "last_name": "User",
            "country": "US",
            "account_type": "email",
        },
    )

    assert signup.status_code == 400
    assert signup.json()["detail"] == "Temporary or disposable email addresses are not allowed."


def test_auth_tokens_expire_after_at_least_one_year(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'auth-token-expiry.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")
    monkeypatch.setenv("PHORA_ACCESS_TOKEN_EXP_MINUTES", str(365 * 24 * 60))
    monkeypatch.setenv("PHORA_REFRESH_TOKEN_EXP_MINUTES", str(365 * 24 * 60))

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "expiry@example.com",
            "password": "password123",
            "first_name": "Expiry",
            "last_name": "User",
            "country": "US",
            "account_type": "email",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "expiry@example.com", "code": sent_codes["expiry@example.com"]},
    )
    assert verify.status_code == 200

    for token_key in ("access_token", "refresh_token"):
        payload = decode_token_safe(verify.json()[token_key])
        assert payload is not None
        expires_at = datetime.fromtimestamp(payload["exp"], UTC)
        assert (expires_at - datetime.now(UTC)).days >= 364


def test_refresh_rotates_refresh_token_and_detects_reuse(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'auth-refresh.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "refresh@example.com",
            "password": "password123",
            "first_name": "Refresh",
            "last_name": "User",
            "country": "US",
            "account_type": "email",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "refresh@example.com", "code": sent_codes["refresh@example.com"]},
    )
    assert verify.status_code == 200
    old_access_token = verify.json()["access_token"]
    old_refresh_token = verify.json()["refresh_token"]

    rotated = client.post("/api/v1/auth/refresh", json={"refresh_token": old_refresh_token})
    assert rotated.status_code == 200
    new_access_token = rotated.json()["access_token"]
    new_refresh_token = rotated.json()["refresh_token"]
    assert new_access_token != old_access_token
    assert new_refresh_token != old_refresh_token
    assert decode_token_safe(new_refresh_token)["jti"] != decode_token_safe(old_refresh_token)["jti"]

    replay = client.post("/api/v1/auth/refresh", json={"refresh_token": old_refresh_token})
    assert replay.status_code == 401
    assert replay.json()["detail"] == "Refresh token reuse detected"

    family_revoked = client.post("/api/v1/auth/refresh", json={"refresh_token": new_refresh_token})
    assert family_revoked.status_code == 401
    assert family_revoked.json()["detail"] == "Refresh token has been revoked"

    blocked_access = client.post(
        "/api/v1/onboarding/health-conditions",
        headers={"Authorization": f"Bearer {new_access_token}"},
        json={"conditions": ["PCOS"]},
    )
    assert blocked_access.status_code == 401
    assert blocked_access.json()["detail"] == "Token has been revoked"


def test_signup_accepts_extended_payload(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'auth-extended.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    monkeypatch.setattr(EmailService, "send_signup_otp", lambda self, recipient, code, locale="en": None)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "extended@example.com",
            "password": "password123",
            "first_name": "Sarah",
            "last_name": "Chen",
            "country": "United Kingdom",
            "birth_date": "1998-04-12",
            "account_type": "email",
            "signup_method": "email",
            "consents": {
                "terms_accepted": True,
                "privacy_policy_accepted": True,
            },
            "registration_context": {
                "client": "mobile",
                "app_version": "1.2.3",
            },
        },
    )
    assert signup.status_code == 200

    login = client.post(
        "/api/0.1.0/auth/login",
        json={"email": "extended@example.com", "password": "password123"},
    )
    assert login.status_code == 202
    assert login.json()["requires_verification"] is True


def test_signup_rejects_future_birth_date(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'auth-birth-date.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    monkeypatch.setattr(EmailService, "send_signup_otp", lambda self, recipient, code, locale="en": None)

    app = create_app()
    client = TestClient(app)

    response = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "future@example.com",
            "password": "password123",
            "first_name": "Future",
            "last_name": "User",
            "country": "US",
            "account_type": "email",
            "birth_date": "2999-01-01",
        },
    )
    assert response.status_code == 422


def test_signup_and_login_support_passwords_longer_than_72_bytes(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'auth-long-password.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)
    long_password = "p" * 100

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "longpass@example.com",
            "password": long_password,
            "first_name": "Long",
            "last_name": "Password",
            "country": "UK",
            "account_type": "email",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "longpass@example.com", "code": sent_codes["longpass@example.com"]},
    )
    assert verify.status_code == 200

    login = client.post(
        "/api/0.1.0/auth/login",
        json={"email": "longpass@example.com", "password": long_password},
    )
    assert login.status_code == 200


def test_signup_and_login_support_multibyte_passwords_longer_than_72_bytes(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'auth-multibyte-password.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)
    long_password = "🙂" * 30

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "multibyte@example.com",
            "password": long_password,
            "first_name": "Multi",
            "last_name": "Byte",
            "country": "UK",
            "account_type": "email",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "multibyte@example.com", "code": sent_codes["multibyte@example.com"]},
    )
    assert verify.status_code == 200

    login = client.post(
        "/api/0.1.0/auth/login",
        json={"email": "multibyte@example.com", "password": long_password},
    )
    assert login.status_code == 200


def test_forgot_password_and_reset_flow(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'reset.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture_signup(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[f"signup:{recipient}"] = code

    def capture_reset(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[f"reset:{recipient}"] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture_signup)
    monkeypatch.setattr(EmailService, "send_password_reset_otp", capture_reset)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "reset@example.com",
            "password": "password123",
            "first_name": "Reset",
            "last_name": "User",
            "country": "US",
            "account_type": "individual",
        },
    )
    assert signup.status_code == 200

    forgot = client.post("/api/0.1.0/auth/forgot-password", json={"email": "reset@example.com"})
    assert forgot.status_code == 200
    assert sent_codes["reset:reset@example.com"].isdigit()

    reset = client.post(
        "/api/0.1.0/auth/reset-password",
        json={
            "email": "reset@example.com",
            "code": sent_codes["reset:reset@example.com"],
            "new_password": "new-password-123",
        },
    )
    assert reset.status_code == 200

    old_login = client.post(
        "/api/0.1.0/auth/login",
        json={"email": "reset@example.com", "password": "password123"},
    )
    assert old_login.status_code == 401

    new_login = client.post(
        "/api/0.1.0/auth/login",
        json={"email": "reset@example.com", "password": "new-password-123"},
    )
    assert new_login.status_code == 200


def test_change_password_flow(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'change-password.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "changepass@example.com",
            "password": "password123",
            "first_name": "Change",
            "last_name": "Password",
            "country": "UK",
            "account_type": "individual",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={
            "email": "changepass@example.com",
            "code": sent_codes["changepass@example.com"],
        },
    )
    assert verify.status_code == 200
    access_token = verify.json()["access_token"]

    changed = client.post(
        "/api/0.1.0/auth/change-password",
        headers={"Authorization": f"Bearer {access_token}"},
        json={
            "current_password": "password123",
            "new_password": "new-password-123",
        },
    )
    assert changed.status_code == 200
    assert changed.json() == {"message": "Password updated successfully."}

    old_login = client.post(
        "/api/0.1.0/auth/login",
        json={"email": "changepass@example.com", "password": "password123"},
    )
    assert old_login.status_code == 401

    new_login = client.post(
        "/api/0.1.0/auth/login",
        json={"email": "changepass@example.com", "password": "new-password-123"},
    )
    assert new_login.status_code == 200


def test_forgot_password_does_not_attempt_email_for_unknown_user(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'forgot-missing.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    def fail_if_called(self, recipient: str, code: str, locale: str = "en") -> None:
        raise AssertionError(f"password reset email should not be sent for unknown user: {recipient} {code}")

    monkeypatch.setattr(EmailService, "send_password_reset_otp", fail_if_called)

    app = create_app()
    client = TestClient(app)

    forgot = client.post("/api/0.1.0/auth/forgot-password", json={"email": "missing@example.com"})
    assert forgot.status_code == 200
    assert forgot.json() == {"message": "If we find a matching account, we’ll send reset instructions."}


def test_totp_setup_enable_and_login_requires_code(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'totp.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "mfa@example.com",
            "password": "password123",
            "first_name": "Mfa",
            "last_name": "User",
            "country": "US",
            "account_type": "individual",
        },
    )
    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "mfa@example.com", "code": sent_codes["mfa@example.com"]},
    )
    token = verify.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    start = client.post("/api/0.1.0/auth/mfa/totp/setup/start", headers=headers)
    assert start.status_code == 200
    manual_key = start.json()["manual_entry_key"]
    code = AuthService._totp_code(manual_key, int(__import__("time").time()))

    enable = client.post("/api/0.1.0/auth/mfa/totp/setup/verify", json={"code": code}, headers=headers)
    assert enable.status_code == 200
    assert enable.json()["enabled"] is True

    blocked = client.post(
        "/api/0.1.0/auth/login",
        json={"email": "mfa@example.com", "password": "password123"},
    )
    assert blocked.status_code == 403
    assert blocked.json()["detail"] == "TOTP code required"

    allowed = client.post(
        "/api/0.1.0/auth/login",
        json={"email": "mfa@example.com", "password": "password123", "totp_code": code},
    )
    assert allowed.status_code == 200

    disable = client.request("DELETE", "/api/0.1.0/auth/mfa/totp", json={"code": code}, headers=headers)
    assert disable.status_code == 200
    assert disable.json()["enabled"] is False


def test_refresh_reuse_clears_cookie(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'auth-cookie-clear.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}
    monkeypatch.setattr(EmailService, "send_signup_otp", lambda self, r, c, locale="en": sent_codes.__setitem__(r, c))

    app = create_app()
    client = TestClient(app)

    client.post(
        "/api/0.1.0/auth/signup",
        json={"email": "cookieclear@example.com", "password": "password123",
              "first_name": "Cookie", "last_name": "Clear", "country": "US", "account_type": "email"},
    )
    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "cookieclear@example.com", "code": sent_codes["cookieclear@example.com"]},
    )
    old_refresh = verify.json()["refresh_token"]

    rotated = client.post("/api/v1/auth/refresh", json={"refresh_token": old_refresh})
    assert rotated.status_code == 200
    new_refresh = rotated.json()["refresh_token"]

    client.cookies.set("phora_refresh", old_refresh, path="/api/v1/auth/refresh")
    replay = client.post("/api/v1/auth/refresh")
    assert replay.status_code == 401
    assert replay.json()["detail"] == "Refresh token reuse detected"
    cookie_header = replay.headers.get("set-cookie", "")
    assert "phora_refresh=" in cookie_header
    assert "Max-Age=0" in cookie_header or "expires=" in cookie_header.lower()

    client.cookies.set("phora_refresh", new_refresh, path="/api/v1/auth/refresh")
    family_attempt = client.post("/api/v1/auth/refresh")
    assert family_attempt.status_code == 401
    cookie_header2 = family_attempt.headers.get("set-cookie", "")
    assert "phora_refresh=" in cookie_header2
    assert "Max-Age=0" in cookie_header2 or "expires=" in cookie_header2.lower()


def test_signout_revokes_access_token_and_clears_refresh_cookie(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'auth-signout.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "signout@example.com",
            "password": "password123",
            "first_name": "Sign",
            "last_name": "Out",
            "country": "US",
            "account_type": "email",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "signout@example.com", "code": sent_codes["signout@example.com"]},
    )
    assert verify.status_code == 200
    access_token = verify.json()["access_token"]
    refresh_token = verify.json()["refresh_token"]
    payload = decode_token_safe(access_token)
    assert payload is not None
    assert payload["gen"] == 0

    client.cookies.set("phora_refresh", refresh_token, path="/api/v1/auth/refresh")
    signout = client.post(
        "/api/v1/auth/signout",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert signout.status_code == 200
    assert signout.json()["message"] == "Signed out successfully."
    cookie = signout.headers.get("set-cookie", "")
    assert "phora_refresh=" in cookie
    assert "Max-Age=0" in cookie or "expires=" in cookie.lower()

    blocked = client.post(
        "/api/v1/onboarding/health-conditions",
        headers={"Authorization": f"Bearer {access_token}"},
        json={"conditions": ["PCOS"]},
    )
    assert blocked.status_code == 401
    assert blocked.json()["detail"] == "Token has been revoked"


def test_login_with_unverified_account_resends_otp(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'unverified.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, list[str]] = {}

    def capture(self, recipient: str, code: str, locale: str = "en") -> None:
        sent_codes.setdefault(recipient, []).append(code)

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "unverified@example.com",
            "password": "password123",
            "first_name": "Un",
            "last_name": "Verified",
            "country": "US",
            "account_type": "individual",
        },
    )
    assert signup.status_code == 200
    assert len(sent_codes["unverified@example.com"]) == 1

    # Login before verifying — should return 202 and resend OTP
    pending = client.post(
        "/api/0.1.0/auth/login",
        json={"email": "unverified@example.com", "password": "password123"},
    )
    assert pending.status_code == 202
    body = pending.json()
    assert body["requires_verification"] is True
    assert body["email"] == "unverified@example.com"
    assert len(sent_codes["unverified@example.com"]) == 2

    # Wrong password should still 401
    wrong_pw = client.post(
        "/api/0.1.0/auth/login",
        json={"email": "unverified@example.com", "password": "wrongpassword"},
    )
    assert wrong_pw.status_code == 401

    # Verifying with the resent code should succeed
    new_code = sent_codes["unverified@example.com"][-1]
    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "unverified@example.com", "code": new_code},
    )
    assert verify.status_code == 200
    assert verify.json()["user"]["email_verified"] is True

    # Subsequent login should now return full auth response
    login = client.post(
        "/api/0.1.0/auth/login",
        json={"email": "unverified@example.com", "password": "password123"},
    )
    assert login.status_code == 200
    assert login.json()["user"]["email"] == "unverified@example.com"
