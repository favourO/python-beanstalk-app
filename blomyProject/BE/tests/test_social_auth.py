from fastapi.testclient import TestClient

from phora.api.app import create_app
from phora.core.security import verify_password
from phora.db.session import get_session_factory
from phora.models import User


def test_social_login_creates_verified_user(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'social.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    from phora.services import auth as auth_service_module

    monkeypatch.setattr(
        auth_service_module,
        "verify_firebase_id_token",
        lambda token, settings: {
            "email": "social@example.com",
            "name": "Social User",
            "given_name": "Social",
            "family_name": "User",
            "firebase": {"sign_in_provider": "google.com"},
            "aud": "test-audience",
        },
    )

    app = create_app()
    client = TestClient(app)

    response = client.post(
        "/api/0.1.0/auth/social-login",
        json={
            "provider": "google",
            "id_token": "x" * 32,
            "signup_method": "google",
            "first_name": "Social",
            "last_name": "User",
            "country": "United Kingdom",
            "birth_date": "1998-04-12",
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
    assert response.status_code == 200
    body = response.json()
    assert body["user"]["email"] == "social@example.com"
    assert body["user"]["email_verified"] is True
    assert body["is_new_user"] is True
    assert body["user"]["first_name"] == "Social"
    assert body["user"]["country"] == "United Kingdom"


def test_google_login_rejects_unknown_mobile_audience_account(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'google-social.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_GOOGLE_OAUTH_CLIENT_ID", "server-client-id.apps.googleusercontent.com")
    monkeypatch.setenv("PHORA_FIREBASE_IOS_CLIENT_ID", "ios-client-id.apps.googleusercontent.com")

    from phora.services import auth as auth_service_module

    monkeypatch.setattr(
        auth_service_module,
        "verify_google_id_token",
        lambda token, settings: {
            "email": "google@example.com",
            "name": "Google User",
            "given_name": "Google",
            "family_name": "User",
            "aud": "ios-client-id.apps.googleusercontent.com",
            "email_verified": True,
        },
    )

    app = create_app()
    client = TestClient(app)

    response = client.post(
        "/api/0.1.0/auth/google-login",
        json={
            "id_token": "x" * 32,
        },
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Account not found. Please sign up first."


def test_google_signup_creates_verified_user_from_mobile_audience(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'google-signup.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_GOOGLE_OAUTH_CLIENT_ID", "server-client-id.apps.googleusercontent.com")
    monkeypatch.setenv("PHORA_FIREBASE_IOS_CLIENT_ID", "ios-client-id.apps.googleusercontent.com")

    from phora.services import auth as auth_service_module

    monkeypatch.setattr(
        auth_service_module,
        "verify_google_id_token",
        lambda token, settings: {
            "email": "google@example.com",
            "name": "Google User",
            "given_name": "Google",
            "family_name": "User",
            "aud": "ios-client-id.apps.googleusercontent.com",
            "email_verified": True,
        },
    )

    app = create_app()
    client = TestClient(app)

    response = client.post(
        "/api/0.1.0/auth/google-signup",
        json={
            "id_token": "x" * 32,
            "signup_method": "google",
            "first_name": "Google",
            "last_name": "User",
            "country": "United Kingdom",
            "consents": {
                "terms_accepted": True,
                "privacy_policy_accepted": True,
            },
        },
    )
    assert response.status_code == 200
    body = response.json()
    assert body["user"]["email"] == "google@example.com"
    assert body["user"]["email_verified"] is True
    assert body["is_new_user"] is True


def test_google_signup_rejects_existing_email(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'google-signup-conflict.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    from phora.services import auth as auth_service_module

    monkeypatch.setattr(
        auth_service_module,
        "verify_google_id_token",
        lambda token, settings: {
            "email": "existing@example.com",
            "name": "Existing User",
            "given_name": "Existing",
            "family_name": "User",
            "aud": "ios-client-id.apps.googleusercontent.com",
            "email_verified": True,
        },
    )

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        user = User(email="existing@example.com", password_hash="hashed-password", email_verified=True)
        db.add(user)
        db.commit()

    response = client.post(
        "/api/0.1.0/auth/google-signup",
        json={
            "id_token": "x" * 32,
            "signup_method": "google",
            "first_name": "Existing",
            "last_name": "User",
            "country": "United Kingdom",
            "consents": {
                "terms_accepted": True,
                "privacy_policy_accepted": True,
            },
        },
    )

    assert response.status_code == 409
    assert response.json()["detail"] == "Email already registered"


def test_google_login_reuses_existing_email_account(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'google-login-existing.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    from phora.services import auth as auth_service_module

    monkeypatch.setattr(
        auth_service_module,
        "verify_google_id_token",
        lambda token, settings: {
            "email": "existing@example.com",
            "name": "Existing User",
            "given_name": "Existing",
            "family_name": "User",
            "aud": "ios-client-id.apps.googleusercontent.com",
            "email_verified": True,
        },
    )

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        user = User(email="existing@example.com", password_hash="hashed-password", email_verified=True)
        db.add(user)
        db.commit()

    response = client.post(
        "/api/0.1.0/auth/google-login",
        json={
            "id_token": "x" * 32,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["user"]["email"] == "existing@example.com"
    assert body["is_new_user"] is False


def test_apple_login_rejects_unknown_ios_audience_account(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'apple-social.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_APPLE_BUNDLE_ID", "com.phora.ios")

    from phora.services import auth as auth_service_module

    monkeypatch.setattr(
        auth_service_module,
        "verify_apple_id_token",
        lambda token, settings: {
            "email": "apple@example.com",
            "given_name": "Apple",
            "family_name": "User",
            "aud": "com.phora.ios",
            "email_verified": "true",
        },
    )

    app = create_app()
    client = TestClient(app)

    response = client.post(
        "/api/0.1.0/auth/apple-login",
        json={
            "id_token": "x" * 32,
        },
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "Account not found. Please sign up first."


def test_apple_signup_creates_verified_user_from_ios_audience(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'apple-signup.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_APPLE_BUNDLE_ID", "com.phora.ios")

    from phora.services import auth as auth_service_module

    monkeypatch.setattr(
        auth_service_module,
        "verify_apple_id_token",
        lambda token, settings: {
            "email": "apple@example.com",
            "given_name": "Apple",
            "family_name": "User",
            "aud": "com.phora.ios",
            "email_verified": "true",
        },
    )

    app = create_app()
    client = TestClient(app)

    response = client.post(
        "/api/0.1.0/auth/apple-signup",
        json={
            "id_token": "x" * 32,
            "signup_method": "apple",
            "first_name": "Apple",
            "last_name": "User",
            "country": "United Kingdom",
            "consents": {
                "terms_accepted": True,
                "privacy_policy_accepted": True,
            },
        },
    )
    assert response.status_code == 200
    body = response.json()
    assert body["user"]["email"] == "apple@example.com"
    assert body["user"]["email_verified"] is True
    assert body["is_new_user"] is True


def test_apple_signup_rejects_existing_email(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'apple-signup-conflict.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_APPLE_BUNDLE_ID", "com.phora.ios")

    from phora.services import auth as auth_service_module

    monkeypatch.setattr(
        auth_service_module,
        "verify_apple_id_token",
        lambda token, settings: {
            "email": "existing@example.com",
            "given_name": "Existing",
            "family_name": "User",
            "aud": "com.phora.ios",
            "email_verified": "true",
        },
    )

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        user = User(email="existing@example.com", password_hash="hashed-password", email_verified=True)
        db.add(user)
        db.commit()

    response = client.post(
        "/api/0.1.0/auth/apple-signup",
        json={
            "id_token": "x" * 32,
            "signup_method": "apple",
            "first_name": "Existing",
            "last_name": "User",
            "country": "United Kingdom",
            "consents": {
                "terms_accepted": True,
                "privacy_policy_accepted": True,
            },
        },
    )

    assert response.status_code == 409
    assert response.json()["detail"] == "Email already registered"


def test_apple_login_reuses_existing_email_account(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'apple-login-existing.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_APPLE_BUNDLE_ID", "com.phora.ios")

    from phora.services import auth as auth_service_module

    monkeypatch.setattr(
        auth_service_module,
        "verify_apple_id_token",
        lambda token, settings: {
            "email": "existing@example.com",
            "given_name": "Existing",
            "family_name": "User",
            "aud": "com.phora.ios",
            "email_verified": "true",
        },
    )

    app = create_app()
    client = TestClient(app)

    with get_session_factory()() as db:
        user = User(email="existing@example.com", password_hash="hashed-password", email_verified=True)
        db.add(user)
        db.commit()

    response = client.post(
        "/api/0.1.0/auth/apple-login",
        json={
            "id_token": "x" * 32,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["user"]["email"] == "existing@example.com"
    assert body["is_new_user"] is False


def test_apple_login_rejects_unverified_email(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'apple-unverified.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_APPLE_BUNDLE_ID", "com.phora.ios")

    from phora.services import auth as auth_service_module

    monkeypatch.setattr(
        auth_service_module,
        "verify_apple_id_token",
        lambda token, settings: {
            "email": "apple@example.com",
            "aud": "com.phora.ios",
            "email_verified": "false",
        },
    )

    app = create_app()
    client = TestClient(app)

    response = client.post(
        "/api/0.1.0/auth/apple-login",
        json={
            "id_token": "x" * 32,
            "signup_method": "apple",
            "country": "United Kingdom",
            "consents": {
                "terms_accepted": True,
                "privacy_policy_accepted": True,
            },
        },
    )
    assert response.status_code == 403
    assert "not verified" in response.json()["detail"].lower()


def test_google_signup_creates_unusable_password_for_new_social_account(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'social-unusable-password.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    from phora.services import auth as auth_service_module
    from phora.db.session import get_session_factory
    from phora.models import User

    monkeypatch.setattr(
        auth_service_module,
        "verify_google_id_token",
        lambda token, settings: {
            "email": "social-pass@example.com",
            "name": "Social Pass",
            "given_name": "Social",
            "family_name": "Pass",
            "aud": "ios-client-id.apps.googleusercontent.com",
            "email_verified": True,
        },
    )

    app = create_app()
    client = TestClient(app)

    response = client.post(
        "/api/0.1.0/auth/google-signup",
        json={
            "id_token": "x" * 32,
            "signup_method": "google",
            "first_name": "Social",
            "last_name": "Pass",
            "country": "United Kingdom",
            "consents": {
                "terms_accepted": True,
                "privacy_policy_accepted": True,
            },
        },
    )
    assert response.status_code == 200

    with get_session_factory()() as db:
        user = db.query(User).filter(User.email == "social-pass@example.com").one()
        assert verify_password("not-their-password", user.password_hash) is False


def test_social_login_requires_consents_for_new_account(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'social-consents.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    from phora.services import auth as auth_service_module

    monkeypatch.setattr(
        auth_service_module,
        "verify_firebase_id_token",
        lambda token, settings: {
            "email": "social-consent@example.com",
            "name": "Social Consent",
            "given_name": "Social",
            "family_name": "Consent",
            "firebase": {"sign_in_provider": "google.com"},
            "aud": "test-audience",
        },
    )

    app = create_app()
    client = TestClient(app)

    response = client.post(
        "/api/0.1.0/auth/social-login",
        json={
            "provider": "google",
            "id_token": "x" * 32,
            "country": "United Kingdom",
        },
    )
    assert response.status_code == 400
    assert "terms_accepted" in response.json()["detail"]


def test_resend_otp_returns_ok_for_missing_account(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'resend.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    response = client.post("/api/0.1.0/auth/resend-otp", json={"email": "missing@example.com"})
    assert response.status_code == 200
    assert "sent" in response.json()["message"].lower()
