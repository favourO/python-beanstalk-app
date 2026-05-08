import sys
import types

import pytest
import jwt

from phora.core.config import Settings
from phora.services.firebase_auth import verify_apple_id_token, verify_google_id_token


def _install_fake_google_modules(monkeypatch, decoded_payload):
    requests_module = types.ModuleType("google.auth.transport.requests")
    requests_module.Request = lambda: object()

    id_token_module = types.ModuleType("google.oauth2.id_token")
    id_token_module.verify_oauth2_token = lambda token, request, audience=None: decoded_payload

    monkeypatch.setitem(sys.modules, "google", types.ModuleType("google"))
    monkeypatch.setitem(sys.modules, "google.auth", types.ModuleType("google.auth"))
    monkeypatch.setitem(sys.modules, "google.auth.transport", types.ModuleType("google.auth.transport"))
    monkeypatch.setitem(sys.modules, "google.auth.transport.requests", requests_module)
    monkeypatch.setitem(sys.modules, "google.oauth2", types.ModuleType("google.oauth2"))
    monkeypatch.setitem(sys.modules, "google.oauth2.id_token", id_token_module)


def test_verify_google_id_token_accepts_ios_audience(monkeypatch):
    _install_fake_google_modules(
        monkeypatch,
        {
            "aud": "ios-client-id.apps.googleusercontent.com",
            "iss": "https://accounts.google.com",
            "email": "google@example.com",
        },
    )
    settings = Settings(
        secret_key="test-secret",
        google_oauth_client_id="server-client-id.apps.googleusercontent.com",
        firebase_ios_client_id="ios-client-id.apps.googleusercontent.com",
    )

    decoded = verify_google_id_token("token", settings)

    assert decoded["aud"] == "ios-client-id.apps.googleusercontent.com"


def test_verify_google_id_token_rejects_unknown_audience(monkeypatch):
    _install_fake_google_modules(
        monkeypatch,
        {
            "aud": "unknown-client-id.apps.googleusercontent.com",
            "iss": "https://accounts.google.com",
            "email": "google@example.com",
        },
    )
    settings = Settings(
        secret_key="test-secret",
        google_oauth_client_id="server-client-id.apps.googleusercontent.com",
        firebase_ios_client_id="ios-client-id.apps.googleusercontent.com",
    )

    with pytest.raises(ValueError, match="audience is not recognized"):
        verify_google_id_token("token", settings)


def test_verify_apple_id_token_accepts_configured_bundle_id(monkeypatch):
    class FakeSigningKey:
        key = "test-key"

    class FakeJWKClient:
        def get_signing_key_from_jwt(self, token):
            assert token == "token"
            return FakeSigningKey()

    monkeypatch.setattr("phora.services.firebase_auth._apple_jwk_client", FakeJWKClient())
    monkeypatch.setattr(
        "phora.services.firebase_auth.jwt.decode",
        lambda token, key, algorithms, audience, issuer: {
            "aud": "com.phora.ios",
            "iss": issuer,
            "email": "apple@example.com",
            "email_verified": "true",
        },
    )

    settings = Settings(secret_key="test-secret", apple_bundle_id="com.phora.ios")

    decoded = verify_apple_id_token("token", settings)

    assert decoded["aud"] == "com.phora.ios"


def test_verify_apple_id_token_requires_configured_audience():
    settings = Settings(secret_key="test-secret")

    with pytest.raises(RuntimeError, match="Apple Sign-In is not configured"):
        verify_apple_id_token("token", settings)


def test_verify_apple_id_token_rejects_invalid_token(monkeypatch):
    class FakeSigningKey:
        key = "test-key"

    class FakeJWKClient:
        def get_signing_key_from_jwt(self, token):
            return FakeSigningKey()

    monkeypatch.setattr("phora.services.firebase_auth._apple_jwk_client", FakeJWKClient())

    def raise_invalid(*args, **kwargs):
        raise jwt.InvalidTokenError("boom")

    monkeypatch.setattr("phora.services.firebase_auth.jwt.decode", raise_invalid)

    settings = Settings(secret_key="test-secret", apple_bundle_id="com.phora.ios")

    with pytest.raises(ValueError, match="Apple identity token is invalid"):
        verify_apple_id_token("token", settings)
