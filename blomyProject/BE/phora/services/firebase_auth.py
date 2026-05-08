from __future__ import annotations

import json
import threading
from pathlib import Path
from typing import Any

import jwt

from phora.core.config import Settings

_init_lock = threading.RLock()
_initialized_app = None
_apple_jwk_client = None
_apple_jwk_lock = threading.RLock()


def _load_firebase_credentials(settings: Settings):
    raw = settings.firebase_credentials_json
    if not raw:
        raise RuntimeError("PHORA_FIREBASE_CREDENTIALS_JSON is required for Firebase authentication.")

    try:
        from firebase_admin import credentials
    except ImportError as exc:  # pragma: no cover
        raise RuntimeError("firebase-admin is not installed.") from exc

    try:
        data = json.loads(raw)
        return credentials.Certificate(data)
    except json.JSONDecodeError:
        path = Path(raw).expanduser().resolve()
        if not path.exists():
            raise RuntimeError(f"PHORA_FIREBASE_CREDENTIALS_JSON path does not exist: {path}")
        return credentials.Certificate(str(path))


def ensure_firebase_app(settings: Settings):
    global _initialized_app
    if _initialized_app is not None:
        return _initialized_app

    with _init_lock:
        if _initialized_app is not None:
            return _initialized_app

        try:
            import firebase_admin
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError("firebase-admin is not installed.") from exc

        cred = _load_firebase_credentials(settings)
        options: dict[str, Any] = {}
        if settings.firebase_project_id:
            options["projectId"] = settings.firebase_project_id
        _initialized_app = firebase_admin.initialize_app(cred, options or None)
        return _initialized_app


def verify_firebase_id_token(id_token: str, settings: Settings) -> dict[str, Any]:
    from firebase_admin import auth as firebase_auth

    app = ensure_firebase_app(settings)
    decoded = firebase_auth.verify_id_token(id_token, app=app)
    allowed_audiences = {
        settings.firebase_web_client_id,
        settings.firebase_ios_client_id,
        settings.firebase_android_client_id,
    }
    allowed_audiences = {aud for aud in allowed_audiences if aud}
    if allowed_audiences and decoded.get("aud") not in allowed_audiences:
        raise ValueError("Token audience is not recognized.")
    return decoded


def verify_google_id_token(id_token: str, settings: Settings) -> dict[str, Any]:
    try:
        from google.auth.transport import requests as google_requests
        from google.oauth2 import id_token as google_id_token
    except ImportError as exc:  # pragma: no cover
        raise RuntimeError("google-auth is not installed.") from exc

    request = google_requests.Request()
    decoded = google_id_token.verify_oauth2_token(id_token, request, audience=None)
    allowed_audiences = {
        settings.google_oauth_client_id,
        settings.firebase_web_client_id,
        settings.firebase_ios_client_id,
        settings.firebase_android_client_id,
    }
    allowed_audiences = {aud for aud in allowed_audiences if aud}
    if allowed_audiences and decoded.get("aud") not in allowed_audiences:
        raise ValueError("Google token audience is not recognized.")
    return decoded


def _apple_jwk_client_factory():
    return jwt.PyJWKClient("https://appleid.apple.com/auth/keys")


def _get_apple_jwk_client():
    global _apple_jwk_client
    if _apple_jwk_client is not None:
        return _apple_jwk_client

    with _apple_jwk_lock:
        if _apple_jwk_client is None:
            _apple_jwk_client = _apple_jwk_client_factory()
    return _apple_jwk_client


def verify_apple_id_token(id_token: str, settings: Settings) -> dict[str, Any]:
    allowed_audiences = {
        settings.apple_bundle_id,
        settings.apple_service_id,
    }
    allowed_audiences = {aud for aud in allowed_audiences if aud}
    if not allowed_audiences:
        raise RuntimeError("Apple Sign-In is not configured. Set PHORA_APPLE_BUNDLE_ID and/or PHORA_APPLE_SERVICE_ID.")

    try:
        signing_key = _get_apple_jwk_client().get_signing_key_from_jwt(id_token)
        decoded = jwt.decode(
            id_token,
            signing_key.key,
            algorithms=["RS256"],
            audience=list(allowed_audiences),
            issuer="https://appleid.apple.com",
        )
    except jwt.InvalidTokenError as exc:
        raise ValueError(f"Apple identity token is invalid: {exc}") from exc
    except Exception as exc:
        # Includes JWK fetch/network/key-discovery failures that should not surface as 500s.
        raise ValueError(f"Apple identity token verification failed: {exc}") from exc

    if decoded.get("aud") not in allowed_audiences:
        raise ValueError("Apple token audience is not recognized.")
    return decoded
