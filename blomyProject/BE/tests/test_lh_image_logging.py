from datetime import date

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select

from phora.api.app import create_app
from phora.api.deps import get_ml_client
from phora.api.routes import auth as auth_routes
from phora.db.session import get_session_factory, reset_db_state
from phora.models import CycleRecord, DailyLog, User
from phora.models.enums import LogType
from phora.schemas.ml import MlLHStripResponse


class AcceptingMlClient:
    def analyze_lh_strip(self, image_bytes: bytes, content_type: str) -> MlLHStripResponse:
        assert image_bytes
        assert content_type == "image/png"
        return MlLHStripResponse(
            strip_valid=True,
            strip_confidence=0.96,
            state="peak",
            positive=True,
            ratio=1.18,
            result_confidence=0.91,
            explanation="Test line is darker than control line",
            analysis_version="lh-strip-v1",
        )


class RejectingMlClient:
    def analyze_lh_strip(self, image_bytes: bytes, content_type: str) -> MlLHStripResponse:
        return MlLHStripResponse(
            strip_valid=False,
            strip_confidence=0.97,
            state="invalid_strip",
            positive=False,
            ratio=None,
            result_confidence=0.0,
            explanation="No recognizable LH strip found",
            analysis_version="lh-strip-v1",
        )


class FailingMlClient:
    def analyze_lh_strip(self, image_bytes: bytes, content_type: str) -> MlLHStripResponse:
        raise RuntimeError("ml unavailable")


@pytest.fixture
def lh_image_client(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'lh-image.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "lh-image-test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    reset_db_state()
    auth_routes._auth_rate_limit_buckets.clear()
    app = create_app()
    client = TestClient(app)
    yield app, client
    auth_routes._auth_rate_limit_buckets.clear()
    reset_db_state()


def _register_anonymous_user(client: TestClient) -> tuple[str, str]:
    response = client.post("/api/0.1.0/auth/register/anonymous")
    assert response.status_code == 201
    access_token = response.json()["access_token"]
    with get_session_factory()() as db:
        user = db.scalar(select(User).where(User.account_mode == "anonymous"))
        assert user is not None
        user_id = user.id
    return user_id, access_token


def _create_active_cycle(user_id: str, *, start_date: date) -> None:
    with get_session_factory()() as db:
        db.add(CycleRecord(user_id=user_id, period_start_date=start_date, is_active=True))
        db.commit()


def test_lh_image_log_persists_valid_analysis(lh_image_client):
    app, client = lh_image_client
    app.dependency_overrides[get_ml_client] = lambda: AcceptingMlClient()
    user_id, access_token = _register_anonymous_user(client)
    _create_active_cycle(user_id, start_date=date(2026, 4, 1))

    response = client.post(
        "/api/v1/cycle/log/lh/image",
        headers={"Authorization": f"Bearer {access_token}"},
        data={"log_date": "2026-04-04", "test_time": "14:30"},
        files={"image": ("lh.png", b"png-bytes", "image/png")},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["strip_valid"] is True
    assert body["state"] == "peak"
    assert body["positive"] is True
    assert body["ratio"] == 1.18
    assert body["test_time"] == "14:30"

    with get_session_factory()() as db:
        log = db.scalar(select(DailyLog).where(DailyLog.user_id == user_id, DailyLog.log_type == LogType.LH))
        assert log is not None
        assert log.payload["state"] == "peak"
        assert log.payload["ratio"] == 1.18
        assert log.payload["positive"] is True
        assert log.payload["strip_valid"] is True
        assert log.payload["analysis_version"] == "lh-strip-v1"
        assert log.payload["cycle_day"] == 4
        assert log.payload["test_time"] == "14:30"

        cycle = db.scalar(select(CycleRecord).where(CycleRecord.user_id == user_id, CycleRecord.is_active.is_(True)))
        assert cycle is not None
        assert cycle.lh_surge_detected_date == date(2026, 4, 4)


def test_manual_lh_log_persists_test_time(lh_image_client):
    _, client = lh_image_client
    user_id, access_token = _register_anonymous_user(client)
    _create_active_cycle(user_id, start_date=date(2026, 4, 1))

    response = client.post(
        "/api/v1/cycle/log/lh",
        headers={"Authorization": f"Bearer {access_token}"},
        json={
            "log_date": "2026-04-04",
            "test_time": "14:30",
            "state": "peak",
            "positive": True,
        },
    )

    assert response.status_code == 200
    assert response.json()["status"] == "ok"

    with get_session_factory()() as db:
        log = db.scalar(select(DailyLog).where(DailyLog.user_id == user_id, DailyLog.log_type == LogType.LH))
        assert log is not None
        assert log.payload["test_time"] == "14:30"
        assert log.payload["state"] == "peak"
        assert log.payload["positive"] is True


def test_lh_history_returns_manual_and_image_logs(lh_image_client):
    app, client = lh_image_client
    app.dependency_overrides[get_ml_client] = lambda: AcceptingMlClient()
    user_id, access_token = _register_anonymous_user(client)
    _create_active_cycle(user_id, start_date=date(2026, 4, 1))

    manual = client.post(
        "/api/v1/cycle/log/lh",
        headers={"Authorization": f"Bearer {access_token}"},
        json={
            "log_date": "2026-04-04",
            "test_time": "10:15",
            "state": "low",
            "positive": False,
            "ratio": 0.52,
        },
    )
    assert manual.status_code == 200

    image = client.post(
        "/api/v1/cycle/log/lh/image",
        headers={"Authorization": f"Bearer {access_token}"},
        data={"log_date": "2026-04-05", "test_time": "14:30"},
        files={"image": ("lh.png", b"png-bytes", "image/png")},
    )
    assert image.status_code == 200

    response = client.get(
        "/api/v1/cycle/log/lh/history?limit=10&offset=0",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["total"] == 2
    assert body["limit"] == 10
    assert body["offset"] == 0
    assert len(body["items"]) == 2

    latest = body["items"][0]
    assert latest["log_date"] == "2026-04-05"
    assert latest["test_time"] == "14:30"
    assert latest["state"] == "peak"
    assert latest["source"] == "image_analysis"
    assert latest["strip_valid"] is True
    assert latest["confidence"] == 0.91
    assert latest["analysis_version"] == "lh-strip-v1"

    earlier = body["items"][1]
    assert earlier["log_date"] == "2026-04-04"
    assert earlier["test_time"] == "10:15"
    assert earlier["state"] == "low"
    assert earlier["source"] == "manual"
    assert earlier["strip_valid"] is None
    assert earlier["confidence"] is None


def test_lh_image_log_rejects_invalid_strip_without_persisting(lh_image_client):
    app, client = lh_image_client
    app.dependency_overrides[get_ml_client] = lambda: RejectingMlClient()
    user_id, access_token = _register_anonymous_user(client)
    _create_active_cycle(user_id, start_date=date(2026, 4, 1))

    response = client.post(
        "/api/v1/cycle/log/lh/image",
        headers={"Authorization": f"Bearer {access_token}"},
        data={"log_date": "2026-04-04"},
        files={"image": ("lh.png", b"png-bytes", "image/png")},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "rejected"
    assert body["strip_valid"] is False
    assert body["state"] == "invalid_strip"

    with get_session_factory()() as db:
        log = db.scalar(select(DailyLog).where(DailyLog.user_id == user_id, DailyLog.log_type == LogType.LH))
        assert log is None
        cycle = db.scalar(select(CycleRecord).where(CycleRecord.user_id == user_id, CycleRecord.is_active.is_(True)))
        assert cycle is not None
        assert cycle.lh_surge_detected_date is None


def test_lh_image_log_returns_manual_only_when_ml_unavailable(lh_image_client):
    app, client = lh_image_client
    app.dependency_overrides[get_ml_client] = lambda: FailingMlClient()
    user_id, access_token = _register_anonymous_user(client)
    _create_active_cycle(user_id, start_date=date(2026, 4, 1))

    response = client.post(
        "/api/v1/cycle/log/lh/image",
        headers={"Authorization": f"Bearer {access_token}"},
        data={"log_date": "2026-04-04"},
        files={"image": ("lh.png", b"png-bytes", "image/png")},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "manual_only"
    assert body["manual_entry_required"] is True
    assert body["explanation"] == "LH strip image analysis is unavailable in this deployment. Please log the result manually."

    with get_session_factory()() as db:
        log = db.scalar(select(DailyLog).where(DailyLog.user_id == user_id, DailyLog.log_type == LogType.LH))
        assert log is None
