from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from phora.api.app import create_app
from phora.db.session import get_session_factory
from phora.models import CycleRecord, DailyLog, MedicalChatMessage, MedicalChatThread, SensorReading, UserProfile
from phora.models.enums import LogType
from phora.services.email import EmailService


def _verified_client(tmp_path, monkeypatch) -> tuple[TestClient, dict[str, str], dict]:
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'ai-chat.db'}")
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
            "email": "medical-ai@example.com",
            "password": "password123",
            "first_name": "Medical",
            "last_name": "AI",
            "country": "United Kingdom",
            "account_type": "individual",
        },
    )
    assert signup.status_code == 200

    verify = client.post(
        "/api/0.1.0/auth/verify",
        json={"email": "medical-ai@example.com", "code": sent_codes["medical-ai@example.com"]},
    )
    assert verify.status_code == 200
    headers = {"Authorization": f"Bearer {verify.json()['access_token']}"}
    return client, headers, verify.json()


def test_medical_chat_rejects_non_medical_questions(tmp_path, monkeypatch):
    client, headers, _ = _verified_client(tmp_path, monkeypatch)

    response = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "Write me a haiku about London."},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["medical_only"] is True
    assert body["sufficient_data"] is False
    assert body["thread_id"] is not None
    assert "only answers reproductive and health-related questions" in body["answer"]


def test_medical_chat_consent_persists_on_profile(tmp_path, monkeypatch):
    client, headers, verify = _verified_client(tmp_path, monkeypatch)

    initial = client.get("/api/v1/ai/chat/consent", headers=headers)
    assert initial.status_code == 200
    assert initial.json() == {"accepted": False, "accepted_at": None}

    accepted = client.post(
        "/api/v1/ai/chat/consent",
        headers=headers,
        json={"accepted": True},
    )
    assert accepted.status_code == 200
    body = accepted.json()
    assert body["accepted"] is True
    assert body["accepted_at"] is not None

    fetched = client.get("/api/v1/ai/chat/consent", headers=headers)
    assert fetched.status_code == 200
    assert fetched.json()["accepted"] is True
    assert fetched.json()["accepted_at"] == body["accepted_at"]

    with get_session_factory()() as db:
        profile = db.query(UserProfile).filter(UserProfile.user_id == verify["user"]["id"]).one()
        ai_preferences = (profile.conditions or {}).get("ai_preferences", {})
        assert ai_preferences["chat_consent_accepted"] is True
        assert ai_preferences["chat_consent_accepted_at"] == body["accepted_at"]


def test_medical_chat_requests_missing_cycle_data_for_fertility_question(tmp_path, monkeypatch):
    client, headers, _ = _verified_client(tmp_path, monkeypatch)

    response = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "When am I likely to ovulate?"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["sufficient_data"] is False
    assert body["thread_id"] is not None
    assert body["missing_data"][0]["action"] == "save_period_start"
    assert body["missing_data"][0]["endpoint"] == "POST /api/v1/cycle/period/start"


def test_medical_chat_can_save_period_and_temperature_data(tmp_path, monkeypatch):
    client, headers, verify = _verified_client(tmp_path, monkeypatch)

    period_response = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={
            "message": "I want to track my fertility.",
            "data_action": {"action": "save_period_start", "payload": {"start_date": "2026-04-05"}},
        },
    )
    assert period_response.status_code == 200
    assert period_response.json()["saved_records"][0].startswith("cycle.period_start:")

    temperature_response = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={
            "message": "My temperature was 0.2 above baseline today. What does that mean?",
            "data_action": {
                "action": "save_temperature",
                "payload": {
                    "records": [
                        {
                            "timestamp": "2026-04-06T07:30:00Z",
                            "delta_c": 0.2,
                            "sleep_quality_score": 0.9,
                            "source": "manual",
                        }
                    ]
                },
            },
        },
    )
    assert temperature_response.status_code == 200
    body = temperature_response.json()
    assert body["saved_records"][0].startswith("sensor.temperature:")
    assert body["thread_id"] is not None
    assert "latest logged temperature delta is 0.2" in body["answer"].lower()

    with get_session_factory()() as db:
        cycle = db.query(CycleRecord).filter(CycleRecord.user_id == verify["user"]["id"]).one()
        assert cycle.period_start_date.isoformat() == "2026-04-05"
        reading = db.query(SensorReading).filter(SensorReading.user_id == verify["user"]["id"]).one()
        assert reading.delta == 0.2


def test_medical_chat_handles_existing_active_cycle_context(tmp_path, monkeypatch):
    client, headers, verify = _verified_client(tmp_path, monkeypatch)

    with get_session_factory()() as db:
        db.add(
            CycleRecord(
                user_id=verify["user"]["id"],
                period_start_date=datetime(2026, 4, 5, tzinfo=UTC).date(),
                cycle_length_days=29,
                menses_length=5,
                is_active=True,
            )
        )
        db.commit()

    response = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "What phase might I be in right now?"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["thread_id"] is not None
    assert body["answer"]




def test_period_log_assistant_extracts_structured_fields(tmp_path, monkeypatch):
    client, headers, _ = _verified_client(tmp_path, monkeypatch)

    response = client.post(
        "/api/v1/ai/log/period-assist",
        headers=headers,
        json={
            "message": "I have light flow, dark colour, cramps, back pain, and I am feeling very tired today.",
            "current": {"period": {}, "symptoms": {}},
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["period"]["intensity"] == "Light"
    assert body["period"]["colour"] == "Dark"
    assert "Cramps" in body["period"]["symptoms"]
    assert "Back Pain" in body["period"]["symptoms"]
    assert "Fatigue" in body["symptoms"]["physical"]
    assert body["next_step"] == "review"
    assert "captured all the period details" in body["assistant_message"]

def test_medical_chat_tracks_threads_and_extracts_period_and_symptom_logs(tmp_path, monkeypatch):
    client, headers, verify = _verified_client(tmp_path, monkeypatch)
    expected_yesterday = (datetime.now(UTC).date() - timedelta(days=1)).isoformat()

    first = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "My period started yesterday and I had cramps."},
    )
    assert first.status_code == 200
    first_body = first.json()
    assert first_body["thread_id"] is not None
    assert any(item.startswith("cycle.period_start:") for item in first_body["saved_records"])
    assert any(item.startswith("cycle.symptom:") for item in first_body["saved_records"])

    second = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={
            "thread_id": first_body["thread_id"],
            "message": "Given that, what does it suggest about my cycle today?",
        },
    )
    assert second.status_code == 200
    second_body = second.json()
    assert second_body["thread_id"] == first_body["thread_id"]
    assert second_body["used_user_data"]

    with get_session_factory()() as db:
        cycle = db.query(CycleRecord).filter(CycleRecord.user_id == verify["user"]["id"]).one()
        assert cycle.period_start_date.isoformat() == expected_yesterday

        symptom_log = (
            db.query(DailyLog)
            .filter(DailyLog.user_id == verify["user"]["id"], DailyLog.log_type == LogType.SYMPTOM)
            .one()
        )
        assert symptom_log.log_date.isoformat() == expected_yesterday
        assert symptom_log.payload["symptoms"] == ["cramps"]

        thread = db.query(MedicalChatThread).filter(MedicalChatThread.id == first_body["thread_id"]).one()
        assert thread.user_id == verify["user"]["id"]

        messages = (
            db.query(MedicalChatMessage)
            .filter(MedicalChatMessage.thread_id == first_body["thread_id"])
            .order_by(MedicalChatMessage.created_at.asc())
            .all()
        )
        assert len(messages) == 4
        assert messages[0].role == "user"
        assert messages[0].content == "My period started yesterday and I had cramps."
        assert messages[-1].role == "assistant"


def test_medical_chat_latest_thread_returns_persisted_messages(tmp_path, monkeypatch):
    client, headers, _ = _verified_client(tmp_path, monkeypatch)

    first = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "My period started yesterday and I had cramps."},
    )
    assert first.status_code == 200
    thread_id = first.json()["thread_id"]

    second = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"thread_id": thread_id, "message": "What phase might I be in now?"},
    )
    assert second.status_code == 200

    history = client.get("/api/v1/ai/chat/latest", headers=headers)
    assert history.status_code == 200
    body = history.json()
    assert body["thread_id"] == thread_id
    assert len(body["messages"]) == 4
    assert body["messages"][0]["role"] == "user"
    assert body["messages"][0]["content"] == "My period started yesterday and I had cramps."
    assert body["messages"][1]["role"] == "assistant"
    assert body["messages"][2]["role"] == "user"
    assert body["messages"][2]["content"] == "What phase might I be in now?"


def test_medical_chat_lists_threads_and_loads_selected_history(tmp_path, monkeypatch):
    client, headers, _ = _verified_client(tmp_path, monkeypatch)

    first = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "My period started yesterday and I had cramps."},
    )
    assert first.status_code == 200
    first_thread_id = first.json()["thread_id"]

    second = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "I noticed egg white mucus today. What might that mean?"},
    )
    assert second.status_code == 200
    second_thread_id = second.json()["thread_id"]
    assert second_thread_id != first_thread_id

    list_response = client.get("/api/v1/ai/chat/threads", headers=headers)
    assert list_response.status_code == 200
    threads = list_response.json()["threads"]
    assert len(threads) == 2
    assert threads[0]["thread_id"] == second_thread_id
    assert threads[0]["message_count"] == 2
    assert "egg white mucus" in threads[0]["title"].lower()
    assert threads[1]["thread_id"] == first_thread_id

    history_response = client.get(
        f"/api/v1/ai/chat/threads/{first_thread_id}",
        headers=headers,
    )
    assert history_response.status_code == 200
    history = history_response.json()
    assert history["thread_id"] == first_thread_id
    assert len(history["messages"]) == 2
    assert history["messages"][0]["content"] == "My period started yesterday and I had cramps."
