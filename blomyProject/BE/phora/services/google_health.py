from __future__ import annotations

import base64
import hashlib
import secrets
from datetime import UTC, date, datetime, time, timedelta
from urllib.parse import urlencode

import httpx
from cryptography.fernet import Fernet
from jose import jwt
from sqlalchemy.orm import Session

from phora.core.config import Settings
from phora.models import GoogleHealthConnection, SensorReading
from phora.models.enums import WearableType
from phora.repositories.core import AuditRepository, GoogleHealthConnectionRepository, UserRepository
from phora.services.wearable_metrics import build_trend_metric


class GoogleHealthError(RuntimeError):
    pass


GOOGLE_HEALTH_SCOPES = [
    "https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly",
    "https://www.googleapis.com/auth/googlehealth.sleep.readonly",
    "https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly",
    "https://www.googleapis.com/auth/googlehealth.profile.readonly",
    "https://www.googleapis.com/auth/googlehealth.settings.readonly",
]


class GoogleHealthService:
    def __init__(self, db: Session, settings: Settings):
        self.db = db
        self.settings = settings
        self.connections = GoogleHealthConnectionRepository(db)
        self.users = UserRepository(db)
        self.audit = AuditRepository(db)

    def authorization_url(self, user_id: str) -> str:
        self._assert_configured()
        state = jwt.encode(
            {
                "sub": user_id,
                "nonce": secrets.token_urlsafe(16),
                "type": "google_health_oauth",
                "exp": datetime.now(UTC) + timedelta(minutes=15),
            },
            self.settings.secret_key,
            algorithm=self.settings.algorithm,
        )
        query = urlencode(
            {
                "client_id": self.settings.google_health_client_id,
                "redirect_uri": self.settings.google_health_redirect_uri,
                "response_type": "code",
                "scope": " ".join(GOOGLE_HEALTH_SCOPES),
                "access_type": "offline",
                "prompt": "consent",
                "include_granted_scopes": "true",
                "state": state,
            }
        )
        return f"https://accounts.google.com/o/oauth2/v2/auth?{query}"

    def complete_callback(self, *, code: str, state: str) -> str:
        self._assert_configured()
        try:
            payload = jwt.decode(
                state,
                self.settings.secret_key,
                algorithms=[self.settings.algorithm],
            )
        except Exception as exc:
            raise GoogleHealthError("Invalid or expired Google Health OAuth state.") from exc
        if payload.get("type") != "google_health_oauth" or not payload.get("sub"):
            raise GoogleHealthError("Invalid Google Health OAuth state.")

        user_id = str(payload["sub"])
        token_payload = self._exchange_code(code)
        access_token = token_payload.get("access_token")
        refresh_token = token_payload.get("refresh_token")
        if not access_token:
            raise GoogleHealthError("Google did not return an access token.")

        existing = self.connections.any_by_user(user_id)
        connection = existing or GoogleHealthConnection(user_id=user_id)
        if refresh_token:
            connection.refresh_token_ciphertext = self._encrypt(refresh_token)
        elif not connection.refresh_token_ciphertext:
            raise GoogleHealthError("Google did not return a refresh token. Re-consent is required.")

        connection.oauth_type = "google"
        connection.access_token_ciphertext = self._encrypt(access_token)
        connection.access_token_expires_at = datetime.now(UTC) + timedelta(
            seconds=int(token_payload.get("expires_in") or 3600)
        )
        connection.granted_scopes = str(token_payload.get("scope") or "").split()
        connection.updated_at = datetime.now(UTC)
        connection.revoked_at = None
        connection.last_sync_error = None

        identity = self._identity(access_token)
        connection.raw_identity = identity
        connection.google_user_id = str(identity.get("userId") or identity.get("googleUserId") or "") or None
        connection.fitbit_legacy_user_id = str(identity.get("fitbitUserId") or identity.get("legacyUserId") or "") or None

        self.connections.save(connection)
        profile = self.users.ensure_profile(user_id)
        profile.wearable_type = WearableType.FITBIT
        self.audit.log(user_id, "wearable.google_health.connected", {"scopes": connection.granted_scopes})
        self.db.commit()
        return self.settings.google_health_oauth_success_redirect

    def status(self, user_id: str) -> dict:
        connection = self.connections.by_user(user_id)
        if not connection:
            return {
                "connected": False,
                "provider": "google_health",
                "sync_health": "unavailable",
                "granted_scopes": [],
            }
        sync_health = "healthy"
        if connection.last_sync_error:
            sync_health = "needs_attention"
        elif not connection.last_synced_at:
            sync_health = "stale"
        return {
            "connected": True,
            "provider": "google_health",
            "last_synced_at": connection.last_synced_at,
            "sync_health": sync_health,
            "granted_scopes": connection.granted_scopes or [],
            "last_error": connection.last_sync_error,
        }

    def sync(self, user_id: str) -> dict:
        connection = self.connections.by_user(user_id)
        if not connection:
            raise GoogleHealthError("Google Health is not connected.")
        access_token = self._valid_access_token(connection)
        profile = self.users.ensure_profile(user_id)
        self._identity(access_token)
        try:
            saved = self._sync_daily_rollups(
                user_id=user_id,
                access_token=access_token,
                timezone_name=profile.timezone,
            )
        except GoogleHealthError as exc:
            connection.last_sync_error = str(exc)
            connection.updated_at = datetime.now(UTC)
            self.db.commit()
            raise
        connection.last_synced_at = datetime.now(UTC)
        connection.last_sync_error = None
        connection.updated_at = datetime.now(UTC)
        self.audit.log(user_id, "wearable.google_health.synced", {"saved": saved})
        self.db.commit()
        return {
            "synced": True,
            "saved": saved,
            "last_synced_at": connection.last_synced_at,
            "detail": "Google Health sync completed.",
        }

    def _sync_daily_rollups(self, *, user_id: str, access_token: str, timezone_name: str | None) -> int:
        end = datetime.now(UTC).date() + timedelta(days=1)
        start = end - timedelta(days=14)
        saved = 0
        for data_type in (
            "steps",
            "daily-resting-heart-rate",
            "daily-heart-rate-variability",
            "daily-sleep-temperature-derivations",
        ):
            payload = self._daily_rollup(access_token, data_type, start, end)
            for point in payload.get("rollupDataPoints") or []:
                saved += self._save_rollup_point(
                    user_id=user_id,
                    data_type=data_type,
                    point=point,
                    timezone_name=timezone_name,
                )
        return saved

    def _daily_rollup(self, access_token: str, data_type: str, start: date, end: date) -> dict:
        response = httpx.post(
            f"https://health.googleapis.com/v4/users/me/dataTypes/{data_type}/dataPoints:dailyRollUp",
            headers={"Authorization": f"Bearer {access_token}"},
            json={
                "range": {
                    "start": _civil_datetime(start),
                    "end": _civil_datetime(end),
                },
                "windowSizeDays": 1,
                "dataSourceFamily": "users/me/dataSourceFamilies/google-wearables",
            },
            timeout=30,
        )
        if response.status_code >= 400:
            raise GoogleHealthError(f"Google Health {data_type} sync failed.")
        return response.json()

    def _save_rollup_point(
        self,
        *,
        user_id: str,
        data_type: str,
        point: dict,
        timezone_name: str | None,
    ) -> int:
        measured_at = _rollup_measured_at(point)
        if data_type == "steps":
            value = _number(point.get("steps"), "countSum")
            return self._save_metric(
                user_id=user_id,
                source="fitbit",
                metric_type="steps",
                sensor_metric="steps",
                value=value,
                unit="count",
                measured_at=measured_at,
                timezone_name=timezone_name,
                confidence="medium",
                raw_payload=point,
            )
        if data_type == "daily-resting-heart-rate":
            value = _midpoint(point.get("restingHeartRatePersonalRange"), "beatsPerMinuteMin", "beatsPerMinuteMax")
            return self._save_metric(
                user_id=user_id,
                source="fitbit",
                metric_type="heart_rate",
                sensor_metric="rhr",
                value=value,
                unit="bpm",
                measured_at=measured_at,
                timezone_name=timezone_name,
                confidence="medium",
                raw_payload=point,
            )
        if data_type == "daily-heart-rate-variability":
            value = _midpoint(
                point.get("heartRateVariabilityPersonalRange"),
                "averageHeartRateVariabilityMillisecondsMin",
                "averageHeartRateVariabilityMillisecondsMax",
            )
            return self._save_metric(
                user_id=user_id,
                source="fitbit",
                metric_type="hrv",
                sensor_metric="hrv",
                value=value,
                unit="ms",
                measured_at=measured_at,
                timezone_name=timezone_name,
                confidence="medium",
                raw_payload=point,
            )
        if data_type == "daily-sleep-temperature-derivations":
            temp = point.get("dailySleepTemperatureDerivations") or point.get("sleepTemperatureDerivations") or point
            value = _number(temp, "nightlyTemperatureCelsius")
            baseline = _number(temp, "baselineTemperatureCelsius")
            if value is None:
                return 0
            self.db.add(
                SensorReading(
                    user_id=user_id,
                    metric="wrist_temp",
                    value=float(value),
                    delta=float(value - baseline) if baseline is not None else float(value),
                    source="fitbit",
                    recorded_at=measured_at,
                )
            )
            self.db.add(
                build_trend_metric(
                    user_id=user_id,
                    source="fitbit",
                    metric_type="skin_temperature",
                    value=float(value),
                    unit="celsius",
                    measured_at=measured_at,
                    collected_at=datetime.now(UTC),
                    timezone_name=timezone_name,
                    confidence="medium",
                    excluded_from_ovulation_prediction=True,
                    exclusion_reason=(
                        "Fitbit sleep temperature is stored as a skin temperature trend "
                        "and is not treated as confirmed BBT."
                    ),
                    raw_payload=point,
                )
            )
            return 1
        return 0

    def _save_metric(
        self,
        *,
        user_id: str,
        source: str,
        metric_type: str,
        sensor_metric: str,
        value: float | None,
        unit: str,
        measured_at: datetime,
        timezone_name: str | None,
        confidence: str,
        raw_payload: dict,
    ) -> int:
        if value is None or value <= 0:
            return 0
        self.db.add(
            SensorReading(
                user_id=user_id,
                metric=sensor_metric,
                value=float(value),
                delta=float(value),
                source=source,
                recorded_at=measured_at,
            )
        )
        self.db.add(
            build_trend_metric(
                user_id=user_id,
                source=source,
                metric_type=metric_type,
                value=float(value),
                unit=unit,
                measured_at=measured_at,
                collected_at=datetime.now(UTC),
                timezone_name=timezone_name,
                confidence=confidence,
                raw_payload=raw_payload,
            )
        )
        return 1

    def disconnect(self, user_id: str) -> None:
        connection = self.connections.by_user(user_id)
        if connection:
            connection.revoked_at = datetime.now(UTC)
            connection.updated_at = datetime.now(UTC)
        profile = self.users.ensure_profile(user_id)
        if profile.wearable_type == WearableType.FITBIT:
            profile.wearable_type = WearableType.NONE
        self.audit.log(user_id, "wearable.google_health.disconnected", {})
        self.db.commit()

    def _exchange_code(self, code: str) -> dict:
        response = httpx.post(
            "https://oauth2.googleapis.com/token",
            data={
                "code": code,
                "client_id": self.settings.google_health_client_id,
                "client_secret": self.settings.google_health_client_secret,
                "redirect_uri": self.settings.google_health_redirect_uri,
                "grant_type": "authorization_code",
            },
            timeout=20,
        )
        if response.status_code >= 400:
            raise GoogleHealthError("Google Health token exchange failed.")
        return response.json()

    def _valid_access_token(self, connection: GoogleHealthConnection) -> str:
        if (
            connection.access_token_ciphertext
            and connection.access_token_expires_at
            and connection.access_token_expires_at > datetime.now(UTC) + timedelta(minutes=5)
        ):
            return self._decrypt(connection.access_token_ciphertext)
        if not connection.refresh_token_ciphertext:
            raise GoogleHealthError("Google Health refresh token is missing.")
        token_payload = self._refresh_token(self._decrypt(connection.refresh_token_ciphertext))
        access_token = token_payload.get("access_token")
        if not access_token:
            raise GoogleHealthError("Google Health token refresh failed.")
        connection.access_token_ciphertext = self._encrypt(access_token)
        connection.access_token_expires_at = datetime.now(UTC) + timedelta(
            seconds=int(token_payload.get("expires_in") or 3600)
        )
        connection.updated_at = datetime.now(UTC)
        self.db.flush()
        return access_token

    def _refresh_token(self, refresh_token: str) -> dict:
        response = httpx.post(
            "https://oauth2.googleapis.com/token",
            data={
                "refresh_token": refresh_token,
                "client_id": self.settings.google_health_client_id,
                "client_secret": self.settings.google_health_client_secret,
                "grant_type": "refresh_token",
            },
            timeout=20,
        )
        if response.status_code >= 400:
            raise GoogleHealthError("Google Health token refresh failed.")
        return response.json()

    def _identity(self, access_token: str) -> dict:
        response = httpx.get(
            "https://health.googleapis.com/v4/users/me/identity",
            headers={"Authorization": f"Bearer {access_token}"},
            timeout=20,
        )
        if response.status_code >= 400:
            return {}
        return response.json()

    def _encrypt(self, value: str) -> str:
        return self._fernet().encrypt(value.encode("utf-8")).decode("utf-8")

    def _decrypt(self, value: str) -> str:
        return self._fernet().decrypt(value.encode("utf-8")).decode("utf-8")

    def _fernet(self) -> Fernet:
        key = base64.urlsafe_b64encode(hashlib.sha256(self.settings.secret_key.encode("utf-8")).digest())
        return Fernet(key)

    def _assert_configured(self) -> None:
        if (
            not self.settings.google_health_client_id
            or not self.settings.google_health_client_secret
            or not self.settings.google_health_redirect_uri
        ):
            raise GoogleHealthError("Google Health OAuth is not configured.")


def _civil_datetime(value: date) -> dict:
    return {
        "year": value.year,
        "month": value.month,
        "day": value.day,
        "hours": 0,
        "minutes": 0,
        "seconds": 0,
    }


def _rollup_measured_at(point: dict) -> datetime:
    civil = point.get("civilStartTime") or {}
    try:
        return datetime.combine(
            date(int(civil["year"]), int(civil["month"]), int(civil["day"])),
            time.min,
            tzinfo=UTC,
        )
    except Exception:
        return datetime.now(UTC)


def _number(payload: dict | None, key: str) -> float | None:
    if not isinstance(payload, dict):
        return None
    value = payload.get(key)
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _midpoint(payload: dict | None, min_key: str, max_key: str) -> float | None:
    low = _number(payload, min_key)
    high = _number(payload, max_key)
    if low is None and high is None:
        return None
    if low is None:
        return high
    if high is None:
        return low
    return (low + high) / 2
