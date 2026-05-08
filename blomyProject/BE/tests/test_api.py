import base64
from datetime import UTC, date, datetime
from uuid import uuid4

from fastapi.testclient import TestClient

from phora.api.app import create_app
from phora.api.deps import get_ml_client
from phora.core.security import create_token
from phora.db.session import get_session_factory
from phora.models import (
    CycleRecord,
    DailyLog,
    PredictionSnapshot,
    SensorReading,
    User,
    UserProfile,
    WearableMetric,
)
from phora.models.enums import LogType, WearableType
from phora.schemas.ml import MlEnsembleResponse, PredictionAudit
from phora.services.email import EmailService
from phora.services.home_service import HomeService
from phora.services.prediction_service import PredictionService
from phora.services.share_service import ShareService


class StubMlClient:
    def health(self):
        return type("Health", (), {"status": "ok", "model_dump": lambda self, mode="json": {"status": "ok"}})()

    def model_versions(self):
        return {"rf_fedcycle_version": "rf-v1"}

    def predict_ensemble(self, payload):
        return MlEnsembleResponse(
            user_id=payload.user_id,
            prediction_id=str(uuid4()),
            current_phase="follicular",
            phase_distribution={"menstrual": 0.01, "follicular": 0.63, "ovulatory": 0.22, "luteal": 0.14},
            ovulation_estimate=14,
            confidence=0.63,
            confidence_explanation="Fused from RF and fallback signals.",
            warning_flags=[],
            models_used=["population_rf", "cusum_detector"],
            model_audits=[],
            audit=PredictionAudit(
                cusum_triggered=False,
                pcos_flag=False,
                lh_override_applied=True,
                ovulation_estimate_source="lh_fallback",
                rf_direct_threshold=0.55,
            ),
            generated_at=datetime(2026, 4, 4, tzinfo=UTC),
        )


def test_prediction_service_derives_ovulatory_phase_from_ovulation_day():
    assert (
        PredictionService._derive_current_phase(
            cycle_day=14,
            ovulation_day=14,
            menses_length=5,
        )
        == "ovulatory"
    )
    assert (
        PredictionService._derive_current_phase(
            cycle_day=4,
            ovulation_day=14,
            menses_length=5,
        )
        == "menstrual"
    )


def test_home_health_snapshot_prompts_wearable_connection_when_disconnected():
    service = HomeService.__new__(HomeService)
    snapshot = service._build_health_snapshot(WearableType.NONE, None, None, None, None, None, None, None, None, None, None, None)

    assert snapshot.wearable_connected is False
    assert snapshot.wearable_type is None
    assert snapshot.body_signal_state == "connect_wearable"
    assert snapshot.body_signal_title == "Connect wearable"
    assert snapshot.body_signal_action_label == "Connect wearable"


def test_home_refreshes_cached_absolute_temperature_cusum_prediction():
    service = HomeService.__new__(HomeService)
    snapshot = type(
        "Snapshot",
        (),
        {
            "audit": {"ovulation_estimate_source": "cusum_fallback"},
            "ml_payload": {"temp_series": [{"delta_temp": 36.3}]},
        },
    )()

    assert service._should_refresh_prediction_snapshot(snapshot) is True


def test_home_keeps_current_pipeline_cusum_prediction():
    service = HomeService.__new__(HomeService)
    snapshot = type(
        "Snapshot",
        (),
        {
            "audit": {
                "ovulation_estimate_source": "cusum_fallback",
                "input_pipeline_version": "wearable_daily_dedup_v2",
            },
            "ml_payload": {"temp_series": [{"delta_temp": 0.24}]},
        },
    )()

    assert service._should_refresh_prediction_snapshot(snapshot) is False


def test_prediction_endpoint_falls_back_cleanly_when_ml_is_disabled(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'test_no_ml.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")
    monkeypatch.setenv("PHORA_ML_ENABLED", "false")
    monkeypatch.setattr(
        PredictionService,
        "_now_utc",
        staticmethod(lambda: datetime(2026, 4, 4, 12, 0, tzinfo=UTC)),
    )

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str) -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "noml@example.com",
            "password": "password123",
            "first_name": "No",
            "last_name": "Ml",
            "country": "US",
            "account_type": "individual",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "noml@example.com", "code": sent_codes["noml@example.com"]},
    )
    assert verify.status_code == 200
    headers = {"Authorization": f"Bearer {verify.json()['access_token']}"}

    profile = client.post(
        "/api/v1/onboarding/profile",
        headers=headers,
        json={
            "full_name": "No Ml",
            "date_of_birth": "1995-01-01",
            "country": "US",
            "conditions": {"pcos": False},
        },
    )
    assert profile.status_code == 200

    cycle = client.post(
        "/api/v1/onboarding/cycle-history",
        headers=headers,
        json={"last_period_date": "2026-04-01", "avg_cycle_length": 28, "avg_period_duration": 5},
    )
    assert cycle.status_code == 200

    prediction = client.get("/api/v1/predictions/current", headers=headers)
    assert prediction.status_code == 200
    body = prediction.json()
    assert body["audit"]["ovulation_estimate_source"] == "calendar_fallback"
    assert body["models_used"] == ["calendar_fallback"]
    assert body["confidence"] == 0.35


def test_prediction_flow(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'test.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")
    monkeypatch.setattr(
        PredictionService,
        "_now_utc",
        staticmethod(lambda: datetime(2026, 4, 4, 12, 0, tzinfo=UTC)),
    )

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str) -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    app.dependency_overrides[get_ml_client] = lambda: StubMlClient()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "user@example.com",
            "password": "password123",
            "first_name": "Test",
            "last_name": "User",
            "country": "US",
            "account_type": "individual",
        },
    )
    assert signup.status_code == 200
    register = client.post("/api/0.1.0/auth/verify", json={"email": "user@example.com", "code": sent_codes["user@example.com"]})
    assert register.status_code == 200
    access_token = register.json()["access_token"]
    headers = {"Authorization": f"Bearer {access_token}"}

    profile = client.post(
        "/api/v1/onboarding/profile",
        headers=headers,
        json={
            "full_name": "Test User",
            "date_of_birth": "1995-01-01",
            "age_at_menarche": 12,
            "height_cm": 165,
            "weight_kg": 65,
            "conditions": {"pcos": False},
        },
    )
    assert profile.status_code == 200

    cycle = client.post(
        "/api/v1/onboarding/cycle-history",
        headers=headers,
        json={"last_period_date": "2026-04-01", "avg_cycle_length": 28, "avg_period_duration": 5},
    )
    assert cycle.status_code == 200

    symptom_log = client.post(
        "/api/v1/cycle/symptom-log",
        headers=headers,
        json={
            "log_date": "2026-04-04",
            "symptoms": ["cramps", "bloating"],
            "severity": "moderate",
            "notes": "Worse in the evening",
            "metadata": {"energy_level": "low"},
        },
    )
    assert symptom_log.status_code == 200
    assert symptom_log.json()["symptoms"] == ["cramps", "bloating"]

    intimacy_log = client.post(
        "/api/v1/cycle/intimacy-log",
        headers=headers,
        json={
            "log_date": "2026-04-04",
            "had_intimacy": True,
            "protection_used": False,
            "ejaculation": True,
            "notes": "Trying to conceive",
        },
    )
    assert intimacy_log.status_code == 200

    wearable = client.post("/api/v1/onboarding/wearable", headers=headers, json={"wearable_type": "fitbit"})
    assert wearable.status_code == 200

    health_conditions = client.post(
        "/api/v1/onboarding/health-conditions",
        headers=headers,
        json={"conditions": ["Endometriosis", "PCOS"]},
    )
    assert health_conditions.status_code == 200
    assert health_conditions.json()["conditions"] == ["Endometriosis", "PCOS"]

    privacy_preferences = client.post(
        "/api/v1/onboarding/privacy-preferences",
        headers=headers,
        json={
            "research_data_sharing": False,
            "health_analytics": True,
            "personalized_recommendations": True,
            "product_messaging_optimization": False,
        },
    )
    assert privacy_preferences.status_code == 200
    assert privacy_preferences.json()["privacy_preferences"]["health_analytics"] is True

    with get_session_factory()() as db:
        profile_row = db.query(UserProfile).filter(UserProfile.user_id == register.json()["user"]["id"]).one()
        assert profile_row.conditions["health_conditions"] == ["Endometriosis", "PCOS"]
        assert profile_row.conditions["privacy_preferences"] == {
            "research_data_sharing": False,
            "health_analytics": True,
            "personalized_recommendations": True,
            "product_messaging_optimization": False,
        }
        symptom_row = db.query(DailyLog).filter(DailyLog.log_type == LogType.SYMPTOM).one()
        assert symptom_row.payload["symptoms"] == ["cramps", "bloating"]
        assert symptom_row.payload["severity"] == "moderate"
        assert symptom_row.payload["energy_level"] == "low"
        intimacy_row = db.query(DailyLog).filter(DailyLog.log_type == LogType.INTERCOURSE).one()
        assert intimacy_row.payload["had_intimacy"] is True
        assert intimacy_row.payload["protection_used"] is False
        assert intimacy_row.payload["ejaculation"] is True

    profile_response = client.get("/api/v1/user/profile", headers=headers)
    assert profile_response.status_code == 200
    assert profile_response.json() == {
        "user_id": register.json()["user"]["id"],
        "email": "user@example.com",
        "email_verified": True,
        "account_mode": "registered",
        "full_name": "Test User",
        "date_of_birth": "1995-01-01",
        "age_at_menarche": 12,
        "height_cm": 165.0,
        "weight_kg": 65.0,
        "bmi": 23.88,
        "goal": None,
        "wearable_type": "fitbit",
        "timezone": "UTC",
        "conditions": {
            "pcos": False,
            "health_conditions": ["Endometriosis", "PCOS"],
            "privacy_preferences": {
                "research_data_sharing": False,
                "health_analytics": True,
                "personalized_recommendations": True,
                "product_messaging_optimization": False,
            },
        },
        "health_conditions": ["Endometriosis", "PCOS"],
        "privacy_preferences": {
            "research_data_sharing": False,
            "health_analytics": True,
            "personalized_recommendations": True,
            "product_messaging_optimization": False,
        },
        "onboarding_completed_at": profile_response.json()["onboarding_completed_at"],
        "age_band": "B",
        "perimenopause_mode_active": False,
        "perimenopause_mode_source": None,
    }

    temp = client.post(
        "/api/v1/sensor/ingest/temperature",
        headers=headers,
        json={"records": [{"timestamp": "2026-04-04T00:00:00Z", "delta_c": 0.14, "sleep_quality_score": 1.0, "source": "fitbit"}]},
    )
    assert temp.status_code == 200

    current = client.get("/api/v1/predictions/current", headers=headers)
    assert current.status_code == 200
    body = current.json()
    assert body["current_phase"] == "menstrual"
    assert body["audit"]["ovulation_estimate_source"] == "lh_fallback"
    assert body["disclaimer"].startswith("Vyla is a prediction application")

    with get_session_factory()() as db:
        db.add_all(
            [
                CycleRecord(
                    user_id=register.json()["user"]["id"],
                    period_start_date=date(2026, 2, 4),
                    period_end_date=date(2026, 2, 8),
                    menses_length=5,
                    cycle_length_days=28,
                    is_active=False,
                ),
                CycleRecord(
                    user_id=register.json()["user"]["id"],
                    period_start_date=date(2026, 3, 4),
                    period_end_date=date(2026, 3, 8),
                    menses_length=5,
                    cycle_length_days=29,
                    is_active=False,
                ),
                SensorReading(
                    user_id=register.json()["user"]["id"],
                    metric="wrist_temp",
                    value=0.12,
                    delta=0.12,
                    source="fitbit",
                    recorded_at=datetime(2026, 4, 3, tzinfo=UTC),
                ),
                SensorReading(
                    user_id=register.json()["user"]["id"],
                    metric="hrv",
                    value=42.0,
                    source="fitbit",
                    recorded_at=datetime(2026, 4, 3, tzinfo=UTC),
                ),
                SensorReading(
                    user_id=register.json()["user"]["id"],
                    metric="hrv",
                    value=45.0,
                    source="fitbit",
                    recorded_at=datetime(2026, 4, 4, tzinfo=UTC),
                ),
            ]
        )
        db.commit()

    stats = client.get("/api/v1/cycle/stats", headers=headers)
    assert stats.status_code == 200
    assert stats.json() == {
        "tracked_cycles": 3,
        "first_period_start_date": "2026-02-04",
        "average_cycle_length_days": 28.5,
        "average_period_length_days": 5.0,
        "regularity_score": 0.93,
        "temperature_trend": [
            {
                "recorded_at": "2026-04-03T00:00:00+00:00",
                "value": 0.12,
            },
            {
                "recorded_at": "2026-04-04T00:00:00+00:00",
                "value": 0.14,
            },
        ],
        "hrv_trend": [
            {
                "recorded_at": "2026-04-03T00:00:00+00:00",
                "value": 42.0,
            },
            {
                "recorded_at": "2026-04-04T00:00:00+00:00",
                "value": 45.0,
            },
        ],
        "symptom_patterns": {
            "most_common": "cramps",
            "energy_dips": "Day 4",
        },
    }


def test_post_signup_onboarding_accepts_mobile_payload_shape(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'test_mobile_onboarding.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str) -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "mobile@example.com",
            "password": "password123",
            "first_name": "Mobile",
            "last_name": "User",
            "country": "UK",
            "account_type": "email",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "mobile@example.com", "code": sent_codes["mobile@example.com"]},
    )
    assert verify.status_code == 200
    headers = {"Authorization": f"Bearer {verify.json()['access_token']}"}

    cycle = client.post(
        "/api/v1/onboarding/cycle-history",
        headers=headers,
        json={
            "last_period_start": "2026-04-06",
            "last_period_end": "2026-04-10",
            "average_period_length": 5,
        },
    )
    assert cycle.status_code == 200

    goal = client.post(
        "/api/v1/onboarding/goal",
        headers=headers,
        json={"goal": "avoid_pregnancy"},
    )
    assert goal.status_code == 200
    assert goal.json()["goal"] == "avoid"

    conditions = client.post(
        "/api/v1/onboarding/health-conditions",
        headers=headers,
        json={"conditions": ["Hormone imbalance", "Irregular cycle", "PCOS"]},
    )
    assert conditions.status_code == 200

    with get_session_factory()() as db:
        cycle_record = db.query(CycleRecord).filter(CycleRecord.user_id == verify.json()["user"]["id"]).one()
        assert cycle_record.period_start_date.isoformat() == "2026-04-06"
        assert cycle_record.period_end_date.isoformat() == "2026-04-10"
        assert cycle_record.menses_length == 5
        assert cycle_record.mu_cycle == 28.0

        profile = db.query(UserProfile).filter(UserProfile.user_id == verify.json()["user"]["id"]).one()
        assert profile.goal.value == "avoid"
        assert profile.conditions["health_conditions"] == [
            "Hormone imbalance",
            "Irregular cycle",
            "PCOS",
        ]


def test_post_signup_onboarding_complete_persists_full_payload(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'test_onboarding_complete.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str) -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "complete@example.com",
            "password": "password123",
            "first_name": "Complete",
            "last_name": "Flow",
            "country": "UK",
            "account_type": "email",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "complete@example.com", "code": sent_codes["complete@example.com"]},
    )
    assert verify.status_code == 200
    user_id = verify.json()["user"]["id"]
    headers = {"Authorization": f"Bearer {verify.json()['access_token']}"}

    response = client.post(
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
            "health_conditions": [
                "Hormone imbalance",
                "Irregular cycle",
                "PCOS",
                "Miscarriage history",
            ],
        },
    )
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert response.json()["goal"] == "avoid"
    assert response.json()["health_conditions"] == [
        "Hormone imbalance",
        "Irregular cycle",
        "PCOS",
        "Miscarriage history",
    ]

    with get_session_factory()() as db:
        cycle_record = db.query(CycleRecord).filter(CycleRecord.user_id == user_id).one()
        assert cycle_record.period_start_date.isoformat() == "2026-04-06"
        assert cycle_record.period_end_date.isoformat() == "2026-04-10"
        assert cycle_record.menses_length == 5
        assert cycle_record.mu_cycle == 28.0

        profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).one()
        assert profile.goal.value == "avoid"
        assert profile.conditions["health_conditions"] == [
            "Hormone imbalance",
            "Irregular cycle",
            "PCOS",
            "Miscarriage history",
        ]


def test_onboarding_progress_round_trip_and_complete_clears_draft(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'test_onboarding_progress.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str) -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "draft@example.com",
            "password": "password123",
            "first_name": "Draft",
            "last_name": "User",
            "country": "UK",
            "account_type": "email",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "draft@example.com", "code": sent_codes["draft@example.com"]},
    )
    assert verify.status_code == 200
    user_id = verify.json()["user"]["id"]
    headers = {"Authorization": f"Bearer {verify.json()['access_token']}"}

    initial = client.get("/api/v1/onboarding/progress", headers=headers)
    assert initial.status_code == 200
    assert initial.json()["current_step"] == 1
    assert initial.json()["completed"] is False
    assert initial.json()["health_conditions"] == []

    updated = client.patch(
        "/api/v1/onboarding/progress",
        headers=headers,
        json={
            "current_step": 2,
            "period_length": 5,
            "last_period_start": "2026-04-06",
            "last_period_end": "2026-04-10",
            "goal": "avoid_pregnancy",
            "health_conditions": ["PCOS", "Irregular cycle"],
        },
    )
    assert updated.status_code == 200
    assert updated.json()["current_step"] == 2
    assert updated.json()["goal"] == "avoid"
    assert updated.json()["health_conditions"] == ["PCOS", "Irregular cycle"]

    restored = client.get("/api/v1/onboarding/progress", headers=headers)
    assert restored.status_code == 200
    assert restored.json()["current_step"] == 2
    assert restored.json()["period_length"] == 5
    assert restored.json()["last_period_start"] == "2026-04-06"
    assert restored.json()["last_period_end"] == "2026-04-10"

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
            "health_conditions": ["PCOS", "Irregular cycle"],
        },
    )
    assert complete.status_code == 200

    post_complete = client.get("/api/v1/onboarding/progress", headers=headers)
    assert post_complete.status_code == 200
    assert post_complete.json()["completed"] is True
    assert post_complete.json()["current_step"] is None
    assert post_complete.json()["period_length"] is None
    assert post_complete.json()["last_period_start"] is None
    assert post_complete.json()["last_period_end"] is None
    assert post_complete.json()["goal"] is None
    assert post_complete.json()["health_conditions"] == []

    with get_session_factory()() as db:
        profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).one()
        assert profile.onboarding_completed_at is not None


def test_home_payload_aggregates_prediction_cycle_and_sensor_data(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'test_home.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_SMTP_ENABLED", "false")
    monkeypatch.setattr(HomeService, "_now_utc", staticmethod(lambda: datetime(2026, 4, 14, 9, 0, tzinfo=UTC)))
    monkeypatch.setattr(
        PredictionService,
        "_now_utc",
        staticmethod(lambda: datetime(2026, 4, 14, 9, 0, tzinfo=UTC)),
    )

    sent_codes: dict[str, str] = {}

    def capture(self, recipient: str, code: str) -> None:
        sent_codes[recipient] = code

    monkeypatch.setattr(EmailService, "send_signup_otp", capture)

    app = create_app()
    app.dependency_overrides[get_ml_client] = lambda: StubMlClient()
    client = TestClient(app)

    signup = client.post(
        "/api/0.1.0/auth/signup",
        json={
            "email": "home@example.com",
            "password": "password123",
            "first_name": "Favour",
            "last_name": "Home",
            "country": "NG",
            "account_type": "individual",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "home@example.com", "code": sent_codes["home@example.com"]},
    )
    assert verify.status_code == 200
    user_id = verify.json()["user"]["id"]
    headers = {"Authorization": f"Bearer {verify.json()['access_token']}"}

    profile = client.post(
        "/api/v1/onboarding/profile",
        headers=headers,
        json={
            "full_name": "Favour Home",
            "date_of_birth": "1997-01-01",
            "timezone": "Africa/Lagos",
            "conditions": {"pcos": False},
        },
    )
    assert profile.status_code == 200

    cycle = client.post(
        "/api/v1/onboarding/cycle-history",
        headers=headers,
        json={"last_period_date": "2026-04-01", "avg_cycle_length": 28, "avg_period_duration": 5},
    )
    assert cycle.status_code == 200

    wearable = client.post("/api/v1/onboarding/wearable", headers=headers, json={"wearable_type": "fitbit"})
    assert wearable.status_code == 200

    sleep = client.post(
        "/api/v1/sensor/ingest/sleep",
        headers=headers,
        json={"date": "2026-04-14", "total_minutes": 450, "sleep_quality_score": 0.9},
    )
    assert sleep.status_code == 200

    heart = client.post(
        "/api/v1/sensor/ingest/heart-rate",
        headers=headers,
        json={"date": "2026-04-14", "rhr_bpm": 68, "hrv_sdnn_ms": 44, "source": "fitbit"},
    )
    assert heart.status_code == 200

    temp = client.post(
        "/api/v1/sensor/ingest/temperature",
        headers=headers,
        json={"records": [{"timestamp": "2026-04-14T06:00:00Z", "delta_c": 0.18, "sleep_quality_score": 0.9, "source": "fitbit"}]},
    )
    assert temp.status_code == 200

    with get_session_factory()() as db:
        db.add(
            CycleRecord(
                user_id=user_id,
                period_start_date=date(2026, 3, 4),
                period_end_date=date(2026, 3, 8),
                cycle_length_days=28,
                menses_length=5,
                is_active=False,
            )
        )
        db.commit()

    home = client.get("/api/v1/home", headers=headers)
    assert home.status_code == 200
    body = home.json()

    assert body["user"] == {"id": user_id, "first_name": "Favour"}
    assert body["main_status"] == {
        "current_cycle_day": 14,
        "current_phase": "ovulation",
        "current_phase_raw": "ovulatory",
        "next_predicted_period_date": "2026-04-29",
        "countdown_to_next_period_days": 15,
        "prediction_confidence": "medium",
        "prediction_confidence_score": 0.63,
        "cycle_length_days": 28,
        "period_length_days": 5,
    }
    assert body["fertility"] == {
        "fertile_today": True,
        "fertile_window_start": "2026-04-09",
        "fertile_window_end": "2026-04-15",
        "predicted_ovulation_date": "2026-04-14",
        "prediction_method": "lh_fallback",
    }
    assert {
        key: body["cycle_prediction_impact"][key]
        for key in (
            "before_ovulation_date",
            "before_period_date",
            "after_ovulation_date",
            "after_period_date",
            "confidence_before",
            "confidence_after",
            "confidence_delta",
            "method",
        )
    } == {
        "before_ovulation_date": "2026-04-14",
        "before_period_date": "2026-04-29",
        "after_ovulation_date": "2026-04-14",
        "after_period_date": "2026-04-29",
        "confidence_before": 0.35,
        "confidence_after": 0.63,
        "confidence_delta": 0.28,
        "method": "lh_fallback",
    }
    assert body["cycle_prediction_impact"]["explanation"]
    assert {
        key: body["today_focus"][key]
        for key in ("title", "message", "tags")
    } == {
        "title": "Fertile window active",
        "message": "Your fertile window is open today based on your current cycle prediction.",
        "tags": ["fertile_window", "ovulation"],
    }
    assert body["today_focus"]["nutrition_recommendation"]
    assert body["today_focus"]["activity_recommendation"]
    assert body["today_focus"]["foods_to_eat"]
    assert body["today_focus"]["workout_exercises"]
    assert body["fitness_guidance"] == {
        "recommended_intensity": "moderate_high",
        "recommended_focus": ["cardio", "strength"],
        "recovery_priority": "normal",
        "message": "This is a good day for moderate to intense work if you feel good.",
        "reason": "Follicular and ovulation phases are commonly associated with higher perceived energy.",
    }
    assert body["health_snapshot"] == {
        "wearable_connected": True,
        "wearable_type": "fitbit",
        "body_signal_state": "readings_available",
        "body_signal_title": "Wearable readings",
        "body_signal_message": "Showing the latest readings synced from your connected device.",
        "body_signal_action_label": None,
        "sleep_hours": 7.5,
        "sleep_deep_minutes": None,
        "sleep_light_minutes": None,
        "sleep_awake_minutes": None,
        "steps": None,
        "resting_heart_rate": 68.0,
        "blood_oxygen_avg": None,
        "blood_oxygen_min": None,
        "stress_avg": None,
        "hrv": 44.0,
        "temperature_delta_c": 0.18,
        "latest_recorded_at": "2026-04-14T06:00:00",
        "cycle_support_signals": ["temperature", "resting_heart_rate", "hrv", "sleep"],
    }
    assert body["prediction_disclaimer"].startswith("Vyla provides wellness and cycle awareness insights only.")
    insight_types = [item["type"] for item in body["device_cycle_insights"]]
    assert "ovulation_window" in insight_types
    assert "temperature" in insight_types
    assert "sleep" in insight_types
    assert "resting_hr" in insight_types
    assert body["quick_actions"] == [
        {"type": "log_period", "label": "Log Period"},
        {"type": "log_cramps", "label": "Log Cramps"},
        {"type": "log_mood", "label": "Log Mood"},
        {"type": "log_discharge", "label": "Log Discharge"},
        {"type": "log_sleep", "label": "Log Sleep"},
        {"type": "log_workout", "label": "Log Workout"},
    ]
    assert body["alerts"] == [
        {
            "type": "prediction_improves_with_data",
            "message": "Prediction accuracy improves as you log more cycles.",
        }
    ]


def test_gtl1_watch_sync_saves_body_signal_readings(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'watch-sync.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    user_id = "01TESTWATCHSYNC000000000000"
    with get_session_factory()() as db:
        db.add(
            User(
                id=user_id,
                email="watch-sync@example.com",
                password_hash="!phora-unusable-password$test",
                email_verified=True,
            )
        )
        db.commit()

    headers = {"Authorization": f"Bearer {create_token(user_id, 'access', 30)}"}
    response = client.post(
        "/api/v1/watch/sync",
        headers=headers,
        json={
            "device_type": "gtl1",
            "synced_at": "2026-04-25T10:00:00Z",
            "days": [
                {
                    "date": "2026-04-25",
                    "steps": 1200,
                    "caloriesKcal": 42.5,
                    "distanceMeters": 860,
                    "heartRate": {"resting": 66, "avg": 72, "min": 58, "max": 105},
                    "sleep": {"totalMinutes": 430, "deepMinutes": 90, "lightMinutes": 300, "awakeMinutes": 40},
                    "bloodOxygen": {"avg": 97, "min": 94},
                    "temperature": {"avg": 0.21},
                    "stress": {"avg": 32},
                }
            ],
        },
    )

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "days": 1, "records": 13}
    with get_session_factory()() as db:
        profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).one()
        assert profile.wearable_type == WearableType.GTL1
        metrics = {item.metric for item in db.query(SensorReading).filter(SensorReading.user_id == user_id).all()}
        assert metrics == {
            "blood_oxygen_avg",
            "blood_oxygen_min",
            "calories_kcal",
            "distance_meters",
            "heart_rate_avg",
            "rhr",
            "sleep_minutes",
            "sleep_deep_minutes",
            "sleep_light_minutes",
            "sleep_awake_minutes",
            "steps",
            "wrist_temp",
        }


def test_daily_log_section_save_and_fetch(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'daily-log.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    user_id = "01TESTDAILYLOG0000000000000"
    with get_session_factory()() as db:
        db.add(
            User(
                id=user_id,
                email="daily-log@example.com",
                password_hash="!phora-unusable-password$test",
                email_verified=True,
            )
        )
        db.commit()

    headers = {"Authorization": f"Bearer {create_token(user_id, 'access', 30)}"}

    period_response = client.post(
        "/api/v1/log/daily/period",
        headers=headers,
        json={
            "date": "2026-04-14",
            "period": {
                "intensity": "Medium",
                "colour": "Red",
                "symptoms": ["Bloating", "Back Pain"],
            },
        },
    )
    assert period_response.status_code == 200

    symptoms_response = client.post(
        "/api/v1/log/daily/symptoms",
        headers=headers,
        json={
            "date": "2026-04-14",
            "symptoms": {
                "mood": "Happy",
                "energy_level": 7,
                "pain_level": 3,
                "sleep_quality": "Good",
                "physical": ["Fatigue"],
            },
        },
    )
    assert symptoms_response.status_code == 200

    fetch_response = client.get(
        "/api/v1/log/daily?date=2026-04-14",
        headers=headers,
    )
    assert fetch_response.status_code == 200
    assert fetch_response.json() == {
        "user_id": user_id,
        "date": "2026-04-14",
        "period": {
            "intensity": "Medium",
            "colour": "Red",
            "symptoms": ["Bloating", "Back Pain"],
        },
        "symptoms": {
            "mood": "Happy",
            "energy_level": 7,
            "physical": ["Fatigue"],
            "pain_level": 3,
            "sleep_quality": "Good",
            "notes": None,
        },
        "temperature": None,
        "lh_test": None,
        "cervical_mucus": None,
        "intimacy": None,
        "notes": None,
    }


def test_growth_share_config_and_generate(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'growth-share.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    monkeypatch.setenv("PHORA_PUBLIC_APP_URL", "http://testserver")
    monkeypatch.setenv("PHORA_REPORT_SHARE_BUCKET", "test-report-shares")
    uploaded_objects: dict[str, dict] = {}

    class FakeS3Client:
        def put_object(self, **kwargs):
            uploaded_objects[kwargs["Key"]] = kwargs

        def generate_presigned_url(self, operation_name, *, Params, ExpiresIn):
            assert operation_name == "get_object"
            return (
                "https://reports.example.com/"
                f"{Params['Key']}?bucket={Params['Bucket']}&expires={ExpiresIn}"
            )

    monkeypatch.setattr(
        ShareService,
        "_get_report_storage_client",
        lambda self: FakeS3Client(),
    )
    monkeypatch.setattr(
        HomeService,
        "_now_utc",
        staticmethod(lambda: datetime(2026, 4, 30, 10, 0, tzinfo=UTC)),
    )

    app = create_app()
    client = TestClient(app)

    user_id = "01TESTGROWTHSHARE0000000000"
    active_cycle_id = "cycle-active-001"
    with get_session_factory()() as db:
        db.add(
            User(
                id=user_id,
                email="growth-share@example.com",
                password_hash="!phora-unusable-password$test",
                email_verified=True,
            )
        )
        db.add(
            UserProfile(
                user_id=user_id,
                full_name="Ava Bloom",
                timezone="UTC",
                wearable_type=WearableType.APPLE_WATCH,
            )
        )
        db.add_all(
            [
                CycleRecord(
                    id=active_cycle_id,
                    user_id=user_id,
                    period_start_date=date(2026, 4, 24),
                    period_end_date=date(2026, 4, 28),
                    menses_length=5,
                    cycle_length_days=29,
                    is_active=True,
                ),
                CycleRecord(
                    id="cycle-older-001",
                    user_id=user_id,
                    period_start_date=date(2026, 3, 26),
                    period_end_date=date(2026, 3, 30),
                    menses_length=5,
                    cycle_length_days=30,
                    is_active=False,
                ),
                CycleRecord(
                    id="cycle-older-002",
                    user_id=user_id,
                    period_start_date=date(2026, 2, 26),
                    period_end_date=date(2026, 3, 2),
                    menses_length=5,
                    cycle_length_days=28,
                    is_active=False,
                ),
                PredictionSnapshot(
                    prediction_id="pred-growth-share-001",
                    user_id=user_id,
                    cycle_id=active_cycle_id,
                    generated_at=datetime(2026, 4, 30, 8, 0, tzinfo=UTC),
                    current_phase="follicular",
                    ovulation_estimate={"date": "2026-05-07"},
                    confidence=0.82,
                    confidence_explanation="Stable recent cycle pattern.",
                    warning_flags=[],
                    models_used=["stub"],
                    model_audits=[],
                    audit={"ovulation_estimate_source": "lh_fallback"},
                    fertile_window={"start": "2026-05-05", "end": "2026-05-09"},
                    next_period_estimate={"date": "2026-05-23"},
                    phase_distribution={"follicular": 0.82},
                    contributing_signals=[],
                    ml_payload={"temp_series": [{"delta_temp": 0.21}]},
                    source="shadow",
                ),
                DailyLog(
                    user_id=user_id,
                    cycle_id=active_cycle_id,
                    log_date=date(2026, 4, 24),
                    log_type=LogType.PERIOD,
                    payload={
                        "intensity": "Medium",
                        "colour": "Red",
                        "symptoms": ["Cramps"],
                    },
                ),
                DailyLog(
                    user_id=user_id,
                    cycle_id=active_cycle_id,
                    log_date=date(2026, 4, 29),
                    log_type=LogType.SYMPTOM,
                    payload={
                        "mood": "Calm",
                        "pain_level": 2,
                        "physical": ["Bloating", "Fatigue", "Cramps"],
                        "notes": "Felt steadier after more sleep.",
                    },
                ),
            ]
        )
        db.commit()

    headers = {"Authorization": f"Bearer {create_token(user_id, 'access', 30)}"}

    config_response = client.get("/api/v1/growth/share-insight/config", headers=headers)
    assert config_response.status_code == 200
    config = config_response.json()
    assert config["default_audience"] == "partner"
    assert config["default_method"] == "secure_link"
    assert [item["value"] for item in config["cycle_count_options"]] == [1, 3, 6]
    assert config["sections"][0]["id"] == "cycle_overview"

    cycle_report_config_response = client.get(
        "/api/v1/growth/cycle-report/config",
        headers=headers,
    )
    assert cycle_report_config_response.status_code == 200
    cycle_report_config = cycle_report_config_response.json()
    assert cycle_report_config["screen_title"] == "Cycle Report"
    assert cycle_report_config["default_audience"] == "doctor"
    assert cycle_report_config["default_method"] == "pdf_report"
    assert [item["value"] for item in cycle_report_config["cycle_count_options"]] == [
        1,
        3,
        6,
        12,
    ]

    generate_response = client.post(
        "/api/v1/growth/share-insight/generate",
        headers=headers,
        json={
            "section_ids": ["cycle_overview", "symptoms", "notes"],
            "audience": "doctor",
            "method": "pdf_report",
            "cycle_count": 3,
        },
    )
    assert generate_response.status_code == 200
    payload = generate_response.json()
    assert payload["method"] == "pdf_report"
    assert payload["audience"] == "doctor"
    assert payload["secure_link_url"].startswith("https://reports.example.com/")
    assert len(payload["sections"]) == 3
    assert "Doctor" in payload["email_body"]
    assert "Cycle overview" in payload["share_text"]
    assert payload["report_file_name"].endswith(".pdf")
    assert base64.b64decode(payload["report_pdf_base64"]).startswith(b"%PDF")

    cycle_report_generate_response = client.post(
        "/api/v1/growth/cycle-report/generate",
        headers=headers,
        json={
            "section_ids": ["cycle_overview", "period_details", "trends_insights"],
            "audience": "doctor",
            "method": "pdf_report",
            "cycle_count": 6,
        },
    )
    assert cycle_report_generate_response.status_code == 200
    cycle_report_payload = cycle_report_generate_response.json()
    assert cycle_report_payload["method"] == "pdf_report"
    assert cycle_report_payload["audience"] == "doctor"
    assert len(cycle_report_payload["sections"]) == 3
    assert cycle_report_payload["subtitle"].endswith("Last 6 cycles")
    assert cycle_report_payload["secure_link_url"].startswith(
        "https://reports.example.com/"
    )
    assert base64.b64decode(cycle_report_payload["report_pdf_base64"]).startswith(
        b"%PDF"
    )
    assert uploaded_objects
    uploaded_object = next(iter(uploaded_objects.values()))
    assert uploaded_object["Bucket"] == "test-report-shares"
    assert uploaded_object["ContentType"] == "application/pdf"
    assert uploaded_object["Body"].startswith(b"%PDF")


def test_daily_temperature_log_creates_normalized_bbt_metric(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'bbt-log.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    user_id = "01TESTBBTMETRIC000000000000"
    with get_session_factory()() as db:
        db.add(
            User(
                id=user_id,
                email="bbt@example.com",
                password_hash="!phora-unusable-password$test",
            )
        )
        db.add(
            UserProfile(
                user_id=user_id,
                full_name="Sarah",
                timezone="Europe/London",
            )
        )
        db.commit()

    headers = {"Authorization": f"Bearer {create_token(user_id, 'access', 30)}"}
    response = client.post(
        "/api/v1/log/daily/temperature",
        headers=headers,
        json={
            "date": "2026-05-01",
            "temperature": {
                "temperature_celsius": 36.45,
                "measured_at": "06:15:00",
                "same_time_as_yesterday": True,
                "uninterrupted_sleep": True,
                "measured_before_getting_up": True,
                "method": "oral",
                "unit": "C",
            },
        },
    )
    assert response.status_code == 200

    with get_session_factory()() as db:
        metrics = list(db.query(WearableMetric).filter(WearableMetric.user_id == user_id))
        assert len(metrics) == 1
        metric = metrics[0]
        assert metric.source == "manual"
        assert metric.metric_type == "basal_body_temperature"
        assert metric.unit == "celsius"
        assert metric.is_morning_bbt_window is True
        assert metric.excluded_from_ovulation_prediction is False
        assert metric.confidence == "high"
        assert metric.raw_payload["method"] == "oral"


def test_daily_temperature_log_persists_exclusion_reason_and_disruption_flags(
    tmp_path, monkeypatch
):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'bbt-log-flags.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    user_id = "01TESTBBTFLAGS000000000000"
    with get_session_factory()() as db:
        db.add(
            User(
                id=user_id,
                email="bbt-flags@example.com",
                password_hash="!phora-unusable-password$test",
            )
        )
        db.add(
            UserProfile(
                user_id=user_id,
                full_name="Sarah",
                timezone="Europe/London",
            )
        )
        db.commit()

    headers = {"Authorization": f"Bearer {create_token(user_id, 'access', 30)}"}
    response = client.post(
        "/api/v1/log/daily/temperature",
        headers=headers,
        json={
            "date": "2026-05-01",
            "temperature": {
                "temperature_celsius": 36.82,
                "measured_at": "08:10:00",
                "same_time_as_yesterday": False,
                "uninterrupted_sleep": False,
                "measured_before_getting_up": False,
                "method": "wearable",
                "illness_flag": True,
                "alcohol_flag": True,
                "stress_flag": True,
                "travel_flag": True,
                "unit": "C",
            },
        },
    )
    assert response.status_code == 200

    with get_session_factory()() as db:
        metric = db.query(WearableMetric).filter(WearableMetric.user_id == user_id).one()
        assert metric.metric_type == "basal_body_temperature"
        assert metric.is_morning_bbt_window is False
        assert metric.excluded_from_ovulation_prediction is True
        assert (
            metric.exclusion_reason
            == "Temperature was not collected during the early-morning BBT window."
        )
        assert metric.confidence == "low"
        assert metric.raw_payload == {
            "method": "wearable",
            "same_time_as_yesterday": False,
            "uninterrupted_sleep": False,
            "measured_before_getting_up": False,
            "illness_flag": True,
            "alcohol_flag": True,
            "stress_flag": True,
            "travel_flag": True,
        }


def test_temperature_ingest_persists_normalized_metric_metadata(
    tmp_path, monkeypatch
):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'sensor-ingest.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")

    app = create_app()
    client = TestClient(app)

    user_id = "01TESTSENSORBBT00000000000"
    with get_session_factory()() as db:
        db.add(
            User(
                id=user_id,
                email="sensor-bbt@example.com",
                password_hash="!phora-unusable-password$test",
            )
        )
        db.add(
            UserProfile(
                user_id=user_id,
                full_name="Tolu",
                timezone="Africa/Lagos",
            )
        )
        db.commit()

    headers = {"Authorization": f"Bearer {create_token(user_id, 'access', 30)}"}
    response = client.post(
        "/api/v1/sensor/ingest/temperature",
        headers=headers,
        json={
            "records": [
                {
                    "timestamp": "2026-05-01T04:45:00Z",
                    "measured_at": "2026-05-01T04:30:00Z",
                    "collected_at": "2026-05-01T04:45:00Z",
                    "delta_c": 0.21,
                    "temperature_celsius": 36.51,
                    "metric_type": "body_temperature",
                    "unit": "celsius",
                    "sleep_minutes": 402,
                    "sleep_quality_score": 0.87,
                    "illness_flag": True,
                    "alcohol_flag": False,
                    "stress_flag": True,
                    "travel_flag": False,
                    "excluded_from_ovulation_prediction": True,
                    "exclusion_reason": "User marked this reading as distorted.",
                    "source": "apple_watch",
                    "raw_payload": {"method": "wearable"},
                }
            ]
        },
    )
    assert response.status_code == 200

    with get_session_factory()() as db:
        sensor = db.query(SensorReading).filter(SensorReading.user_id == user_id).one()
        assert sensor.metric == "wrist_temp"
        assert sensor.source == "apple_watch"
        assert sensor.delta == 0.21

        metric = db.query(WearableMetric).filter(WearableMetric.user_id == user_id).one()
        assert metric.source == "healthkit"
        assert metric.metric_type == "body_temperature"
        assert metric.value == 36.51
        assert metric.unit == "celsius"
        assert metric.is_morning_bbt_window is True
        assert metric.excluded_from_ovulation_prediction is True
        assert metric.exclusion_reason == "User marked this reading as distorted."
        assert metric.confidence == "low"
        assert metric.raw_payload == {
            "profile_timezone": "Africa/Lagos",
            "delta_c": 0.21,
            "sleep_minutes": 402,
            "sleep_quality_score": 0.87,
            "illness_flag": True,
            "alcohol_flag": False,
            "stress_flag": True,
            "travel_flag": False,
            "method": "wearable",
        }
