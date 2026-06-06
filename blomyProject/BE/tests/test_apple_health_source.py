"""Tests for Apple Health source isolation — data_source, dedup, and independence from Vyla wearable."""
import pytest
from datetime import date, datetime, UTC
from fastapi.testclient import TestClient
from sqlalchemy import select

from phora.api.app import create_app
from phora.core.config import get_settings
from phora.core.security import create_token
from phora.db.session import get_session_factory, reset_db_state
from phora.models import SensorReading, User, UserProfile, WearableMetric
from phora.models.enums import WearableType
from phora.services.wearable_metrics import classify_data_source, build_trend_metric


# ── classify_data_source unit tests ─────────────────────────────────────────

class TestClassifyDataSource:
    def test_gtl1_maps_to_vyla_wearable(self):
        assert classify_data_source("gtl1") == "vyla_wearable"

    def test_phora_wear_maps_to_vyla_wearable(self):
        assert classify_data_source("phora_wear") == "vyla_wearable"

    def test_vyla_wearable_passthrough(self):
        assert classify_data_source("vyla_wearable") == "vyla_wearable"

    def test_healthkit_maps_to_apple_health(self):
        assert classify_data_source("healthkit") == "apple_health"

    def test_apple_watch_maps_to_apple_health(self):
        assert classify_data_source("apple_watch") == "apple_health"

    def test_apple_health_passthrough(self):
        assert classify_data_source("apple_health") == "apple_health"

    def test_manual_maps_to_manual_entry(self):
        assert classify_data_source("manual") == "manual_entry"

    def test_manual_bbt_maps_to_manual_entry(self):
        assert classify_data_source("manual_bbt") == "manual_entry"

    def test_unknown_defaults_to_manual_entry(self):
        assert classify_data_source("unknown_source") == "manual_entry"


# ── API integration tests ────────────────────────────────────────────────────

@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'test.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret-key")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    reset_db_state()
    app = create_app()
    with TestClient(app) as c:
        yield c
    reset_db_state()


@pytest.fixture()
def user_token(client):
    with get_session_factory()() as session:
        user = User(email="healthtest@example.com", password_hash="x")
        session.add(user)
        session.flush()
        profile = UserProfile(user_id=user.id)
        session.add(profile)
        session.commit()
        uid = user.id
    token = create_token(uid, "access", get_settings().access_token_exp_minutes)
    return uid, token


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


class TestAppleHealthSync:
    def test_sync_saves_data_source_apple_health(self, client, user_token):
        uid, token = user_token
        resp = client.post(
            "/api/v1/wearables/apple-health/sync",
            json={
                "synced_at": datetime.now(UTC).isoformat(),
                "days": [{"date": "2026-05-20", "steps": 8000, "resting_heart_rate": 62.0}],
            },
            headers=_auth(token),
        )
        assert resp.status_code == 200
        assert resp.json()["synced"] is True

        with get_session_factory()() as session:
            metrics = list(session.scalars(
                select(WearableMetric).where(WearableMetric.user_id == uid)
            ))
        assert len(metrics) > 0
        for m in metrics:
            assert m.data_source == "apple_health", f"{m.metric_type} has wrong data_source: {m.data_source}"

    def test_sync_does_not_overwrite_vyla_wearable_connection(self, client, user_token):
        uid, token = user_token
        with get_session_factory()() as session:
            profile = session.scalar(select(UserProfile).where(UserProfile.user_id == uid))
            profile.wearable_type = WearableType.GTL1
            session.commit()

        resp = client.post(
            "/api/v1/wearables/apple-health/sync",
            json={
                "synced_at": datetime.now(UTC).isoformat(),
                "days": [{"date": "2026-05-20", "steps": 5000}],
            },
            headers=_auth(token),
        )
        assert resp.status_code == 200

        with get_session_factory()() as session:
            profile = session.scalar(select(UserProfile).where(UserProfile.user_id == uid))
        assert profile.wearable_type == WearableType.GTL1, "Apple Health sync must not overwrite Vyla wearable type"

    def test_sync_tracks_connection_in_conditions(self, client, user_token):
        uid, token = user_token
        resp = client.post(
            "/api/v1/wearables/apple-health/sync",
            json={"synced_at": datetime.now(UTC).isoformat(), "days": []},
            headers=_auth(token),
        )
        assert resp.status_code == 200

        with get_session_factory()() as session:
            profile = session.scalar(select(UserProfile).where(UserProfile.user_id == uid))
        assert (profile.conditions or {}).get("apple_health", {}).get("connected") is True

    def test_sync_deduplicates_per_source(self, client, user_token):
        uid, token = user_token
        payload = {
            "synced_at": datetime.now(UTC).isoformat(),
            "days": [{"date": "2026-05-20", "steps": 7000}],
        }
        client.post("/api/v1/wearables/apple-health/sync", json=payload, headers=_auth(token))
        client.post("/api/v1/wearables/apple-health/sync", json=payload, headers=_auth(token))

        with get_session_factory()() as session:
            count = len(list(session.scalars(
                select(WearableMetric).where(
                    WearableMetric.user_id == uid,
                    WearableMetric.data_source == "apple_health",
                    WearableMetric.metric_type == "steps",
                )
            )))
        assert count == 1, "Duplicate Apple Health record should be skipped on re-sync"

    def test_external_id_stored(self, client, user_token):
        uid, token = user_token
        resp = client.post(
            "/api/v1/wearables/apple-health/sync",
            json={
                "synced_at": datetime.now(UTC).isoformat(),
                "days": [{"date": "2026-05-20", "hrv": 42.5, "external_id": "hk-sample-abc"}],
            },
            headers=_auth(token),
        )
        assert resp.status_code == 200

        with get_session_factory()() as session:
            metric = session.scalar(
                select(WearableMetric).where(
                    WearableMetric.user_id == uid,
                    WearableMetric.metric_type == "hrv",
                )
            )
        assert metric is not None
        assert metric.external_id == "hk-sample-abc:hrv"


class TestAppleHealthStatus:
    def test_status_returns_disconnected_initially(self, client, user_token):
        uid, token = user_token
        resp = client.get("/api/v1/wearables/apple-health/status", headers=_auth(token))
        assert resp.status_code == 200
        assert resp.json()["connected"] is False

    def test_status_returns_connected_after_sync(self, client, user_token):
        uid, token = user_token
        client.post(
            "/api/v1/wearables/apple-health/sync",
            json={"synced_at": datetime.now(UTC).isoformat(), "days": []},
            headers=_auth(token),
        )
        resp = client.get("/api/v1/wearables/apple-health/status", headers=_auth(token))
        assert resp.status_code == 200
        assert resp.json()["connected"] is True


class TestAppleHealthDisconnect:
    def test_disconnect_clears_connection_only(self, client, user_token):
        uid, token = user_token
        with get_session_factory()() as session:
            profile = session.scalar(select(UserProfile).where(UserProfile.user_id == uid))
            profile.wearable_type = WearableType.GTL1
            session.commit()

        client.post(
            "/api/v1/wearables/apple-health/sync",
            json={"synced_at": datetime.now(UTC).isoformat(), "days": []},
            headers=_auth(token),
        )
        resp = client.post("/api/v1/wearables/apple-health/disconnect", headers=_auth(token))
        assert resp.json()["disconnected"] is True

        with get_session_factory()() as session:
            profile = session.scalar(select(UserProfile).where(UserProfile.user_id == uid))
        assert profile.wearable_type == WearableType.GTL1, "Disconnect must not affect Vyla wearable"
        assert (profile.conditions or {}).get("apple_health", {}).get("connected") is False


class TestHealthMetricsFilter:
    def test_filter_by_apple_health_source(self, client, user_token):
        uid, token = user_token
        client.post(
            "/api/v1/wearables/apple-health/sync",
            json={"synced_at": datetime.now(UTC).isoformat(), "days": [{"date": "2026-05-20", "steps": 9000}]},
            headers=_auth(token),
        )
        resp = client.get("/api/v1/wearables/health-metrics?source=apple_health", headers=_auth(token))
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] > 0
        for m in data["metrics"]:
            assert m["data_source"] == "apple_health"

    def test_filter_returns_empty_for_vyla_when_no_data(self, client, user_token):
        uid, token = user_token
        client.post(
            "/api/v1/wearables/apple-health/sync",
            json={"synced_at": datetime.now(UTC).isoformat(), "days": [{"date": "2026-05-20", "steps": 9000}]},
            headers=_auth(token),
        )
        resp = client.get("/api/v1/wearables/health-metrics?source=vyla_wearable", headers=_auth(token))
        assert resp.status_code == 200
        assert resp.json()["total"] == 0

    def test_source_label_present(self, client, user_token):
        uid, token = user_token
        client.post(
            "/api/v1/wearables/apple-health/sync",
            json={"synced_at": datetime.now(UTC).isoformat(), "days": [{"date": "2026-05-20", "hrv": 38.0}]},
            headers=_auth(token),
        )
        resp = client.get("/api/v1/wearables/health-metrics?metric_type=hrv", headers=_auth(token))
        assert resp.status_code == 200
        metrics = resp.json()["metrics"]
        assert len(metrics) == 1
        assert metrics[0]["source_label"] == "Apple Health"
