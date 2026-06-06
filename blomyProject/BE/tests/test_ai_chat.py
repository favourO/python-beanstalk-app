from datetime import UTC, datetime, timedelta

from fastapi.testclient import TestClient

from phora.api.app import create_app
from phora.db.session import get_session_factory
from phora.models import CycleRecord, DailyLog, MedicalChatMessage, MedicalChatThread, PredictionSnapshot, SensorReading, Subscription, UserProfile
from phora.models.enums import LogType
from phora.services.email import EmailService


def _verified_client(tmp_path, monkeypatch) -> tuple[TestClient, dict[str, str], dict]:
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'ai-chat.db'}")
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


def test_medical_chat_answers_luteal_phase_education_without_cycle_data(tmp_path, monkeypatch):
    client, headers, _ = _verified_client(tmp_path, monkeypatch)

    response = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "what is luteal phase"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["medical_only"] is True
    assert body["sufficient_data"] is True
    assert body["missing_data"] == []
    assert "after ovulation" in body["answer"]
    assert "progesterone" in body["answer"]


def test_medical_chat_answers_fibroid_education_before_sparse_profile_fallback(tmp_path, monkeypatch):
    client, headers, verify = _verified_client(tmp_path, monkeypatch)

    with get_session_factory()() as db:
        profile = db.query(UserProfile).filter(UserProfile.user_id == verify["user"]["id"]).one()
        profile.conditions = {"health_conditions": ["Irregular cycle"]}
        db.commit()

    response = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "What is the cause of fibroids?"},
    )

    assert response.status_code == 200
    body = response.json()
    answer = body["answer"].lower()
    assert body["sufficient_data"] is True
    assert body["missing_data"] == []
    assert "fibroids are non-cancerous growths" in answer
    assert "oestrogen and progesterone" in answer
    assert "useful follow-up questions" in answer
    assert "i do not have enough recent cycle" not in answer


def test_medical_chat_answers_pcos_fasting_question_before_sparse_profile_fallback(tmp_path, monkeypatch):
    client, headers, verify = _verified_client(tmp_path, monkeypatch)

    with get_session_factory()() as db:
        profile = db.query(UserProfile).filter(UserProfile.user_id == verify["user"]["id"]).one()
        profile.conditions = {"health_conditions": ["Irregular cycle"]}
        db.commit()

    response = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "Can someone with PCOS fast, and eat once a day by 4pm"},
    )

    assert response.status_code == 200
    body = response.json()
    answer = body["answer"].lower()
    assert "pcos" in answer
    assert "insulin resistance" in answer
    assert "once a day" in answer
    assert "useful follow-up questions" in answer
    assert "i do not have enough recent cycle" not in answer


def test_medical_chat_remembers_previous_messages_for_contextual_follow_up(tmp_path, monkeypatch):
    client, headers, _ = _verified_client(tmp_path, monkeypatch)

    first = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "What is the cause of fibroids?"},
    )
    assert first.status_code == 200
    thread_id = first.json()["thread_id"]

    follow_up = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"thread_id": thread_id, "message": "What about treatment?"},
    )

    assert follow_up.status_code == 200
    body = follow_up.json()
    assert body["thread_id"] == thread_id
    assert body["medical_only"] is True
    assert "only answers reproductive and health-related questions" not in body["answer"]
    assert "we were discussing" not in body["answer"].lower()
    assert "fibroid" in body["answer"].lower()


def test_medical_chat_answers_uploaded_file_follow_up_naturally(tmp_path, monkeypatch):
    client, headers, verify = _verified_client(tmp_path, monkeypatch)

    with get_session_factory()() as db:
        db.add(
            Subscription(
                user_id=verify["user"]["id"],
                tier="premium_plus",
                status="active",
                provider="stripe",
                billing_interval="month",
                current_period_end=datetime.now(UTC) + timedelta(days=30),
            )
        )
        db.commit()

    upload = client.post(
        "/api/v1/ai/chat/document-analysis",
        headers=headers,
        files={
            "file": (
                "blood-results.txt",
                b"Patient laboratory report\nFerritin 8 ug/L\nHaemoglobin 10.9 g/dL\nReference range included",
                "text/plain",
            )
        },
    )
    assert upload.status_code == 200

    follow_up = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={
            "thread_id": upload.json()["thread_id"],
            "message": "What does the file uploaded earlier say about my health?",
        },
    )

    assert follow_up.status_code == 200
    answer = follow_up.json()["answer"]
    assert "The file looked like a medical document" in answer
    assert "we were discussing" not in answer.lower()
    assert "safest next step is to be specific" not in answer.lower()
    assert "I can see this in your saved Vyla health profile" not in answer


def test_medical_document_analysis_requires_premium(tmp_path, monkeypatch):
    client, headers, _ = _verified_client(tmp_path, monkeypatch)

    response = client.post(
        "/api/v1/ai/chat/document-analysis",
        headers=headers,
        data={"question": "Can you explain this?"},
        files={"file": ("lab.txt", b"Patient lab report\nFerritin 8 ug/L\nReference range 15-150", "text/plain")},
    )

    assert response.status_code == 402
    assert response.json()["detail"]["paywall_reason"] == "ai_chat_premium"


def test_premium_medical_document_analysis_reads_text_without_storing_upload(tmp_path, monkeypatch):
    client, headers, verify = _verified_client(tmp_path, monkeypatch)

    with get_session_factory()() as db:
        db.add(
            Subscription(
                user_id=verify["user"]["id"],
                tier="premium_plus",
                status="active",
                provider="stripe",
                billing_interval="month",
                current_period_end=datetime.now(UTC) + timedelta(days=30),
            )
        )
        db.commit()

    response = client.post(
        "/api/v1/ai/chat/document-analysis",
        headers=headers,
        data={"question": "What should I ask my doctor?"},
        files={
            "file": (
                "blood-results.txt",
                b"Patient laboratory report\nFerritin 8 ug/L\nHaemoglobin 10.9 g/dL\nReference range included",
                "text/plain",
            )
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["sufficient_data"] is True
    assert body["document_type"] == "text"
    assert body["extracted_text_chars"] > 20
    assert "ferritin" in body["answer"].lower()
    assert "haemoglobin" in body["answer"].lower()
    assert "i can read this as" not in body["answer"].lower()
    assert body["chat_limit"] == 50

    with get_session_factory()() as db:
        user_messages = (
            db.query(MedicalChatMessage)
            .filter(MedicalChatMessage.user_id == verify["user"]["id"], MedicalChatMessage.role == "user")
            .all()
        )
        assert user_messages
        assert all("Ferritin 8" not in item.content for item in user_messages)


def test_premium_medical_document_analysis_accepts_files_over_15mb(tmp_path, monkeypatch):
    client, headers, verify = _verified_client(tmp_path, monkeypatch)

    with get_session_factory()() as db:
        db.add(
            Subscription(
                user_id=verify["user"]["id"],
                tier="premium_plus",
                status="active",
                provider="stripe",
                billing_interval="month",
                current_period_end=datetime.now(UTC) + timedelta(days=30),
            )
        )
        db.commit()

    repeated = b"Patient medical laboratory report Ferritin blood result reference range. "
    large_medical_text = repeated * ((16 * 1024 * 1024 // len(repeated)) + 1)
    assert len(large_medical_text) > 15 * 1024 * 1024

    response = client.post(
        "/api/v1/ai/chat/document-analysis",
        headers=headers,
        data={"question": "Summarise this large report."},
        files={"file": ("large-lab-report.txt", large_medical_text, "text/plain")},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["sufficient_data"] is True
    assert body["document_type"] == "text"
    assert body["extracted_text_chars"] <= 24000


def test_medical_document_analysis_rejects_non_medical_documents(tmp_path, monkeypatch):
    client, headers, verify = _verified_client(tmp_path, monkeypatch)

    with get_session_factory()() as db:
        db.add(
            Subscription(
                user_id=verify["user"]["id"],
                tier="premium_plus",
                status="active",
                provider="stripe",
                billing_interval="month",
                current_period_end=datetime.now(UTC) + timedelta(days=30),
            )
        )
        db.commit()

    response = client.post(
        "/api/v1/ai/chat/document-analysis",
        headers=headers,
        files={"file": ("shopping.txt", b"Milk\nBread\nCoffee\nLaundry detergent", "text/plain")},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["medical_only"] is False
    assert body["sufficient_data"] is False
    assert "does not look like a medical document" in body["answer"]


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
    assert "0.2" in body["answer"]

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


def test_medical_chat_uses_latest_period_log_when_active_cycle_missing(tmp_path, monkeypatch):
    client, headers, verify = _verified_client(tmp_path, monkeypatch)
    period_day = (datetime.now(UTC) - timedelta(days=8)).date()

    with get_session_factory()() as db:
        db.add(
            DailyLog(
                user_id=verify["user"]["id"],
                cycle_id=None,
                log_date=period_day,
                log_type=LogType.PERIOD,
                payload={"intensity": "Medium", "colour": "Red"},
            )
        )
        db.commit()

    response = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "When is my next period likely to come?"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["sufficient_data"] is True
    assert body["missing_data"] == []
    assert "cycle.period_log" in body["used_user_data"]
    assert "cycle day" in body["answer"].lower()


def test_medical_chat_uses_prediction_for_next_cycle_question(tmp_path, monkeypatch):
    client, headers, verify = _verified_client(tmp_path, monkeypatch)
    user_id = verify["user"]["id"]

    with get_session_factory()() as db:
        profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).one()
        profile.conditions = {"health_conditions": ["Irregular cycle"]}
        db.add(
            PredictionSnapshot(
                prediction_id="pred_next_cycle",
                user_id=user_id,
                current_phase="luteal",
                confidence=0.82,
                fertile_window={"start": "2026-05-08", "end": "2026-05-10"},
                next_period_estimate={"date": "2026-05-24", "range_days": 2},
                contributing_signals=[{"signal": "cycle_history", "available": True}],
            )
        )
        db.commit()

    response = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "When is my next cycle"},
    )

    assert response.status_code == 200
    body = response.json()
    answer = body["answer"].lower()
    assert body["sufficient_data"] is True
    assert "2026-05-24" in answer
    assert "next cycle starts when your next period begins" in answer
    assert "luteal" in answer
    assert "{'signal'" not in body["answer"]
    assert "cycle history" in answer
    assert "i do not have enough recent cycle" not in answer


def test_medical_chat_requests_period_start_for_next_cycle_without_prediction(tmp_path, monkeypatch):
    client, headers, verify = _verified_client(tmp_path, monkeypatch)

    with get_session_factory()() as db:
        profile = db.query(UserProfile).filter(UserProfile.user_id == verify["user"]["id"]).one()
        profile.conditions = {"health_conditions": ["Irregular cycle"]}
        db.commit()

    response = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "When is my next cycle"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["sufficient_data"] is False
    assert body["missing_data"][0]["action"] == "save_period_start"
    assert "I do not have enough recent cycle" not in body["answer"]


def test_medical_chat_free_user_is_limited_to_three_chats_per_week(tmp_path, monkeypatch):
    client, headers, _ = _verified_client(tmp_path, monkeypatch)

    for index in range(3):
        response = client.post(
            "/api/v1/ai/chat",
            headers=headers,
            json={"message": f"What is luteal phase? {index}"},
        )
        assert response.status_code == 200
        body = response.json()
        assert body["chat_limit"] == 3
        assert body["chats_used"] == index + 1
        assert body["chats_remaining"] == 2 - index

    blocked = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "What causes fibroids?"},
    )

    assert blocked.status_code == 429
    detail = blocked.json()["detail"]
    assert detail["tier"] == "free"
    assert detail["chat_limit"] == 3
    assert detail["chats_used"] == 3
    assert detail["chats_remaining"] == 0


def test_medical_chat_premium_user_gets_fifty_chats_per_week(tmp_path, monkeypatch):
    client, headers, verify = _verified_client(tmp_path, monkeypatch)
    user_id = verify["user"]["id"]

    with get_session_factory()() as db:
        db.add(
            Subscription(
                user_id=user_id,
                tier="premium_plus",
                status="active",
                provider="stripe",
                provider_subscription_id="sub_ai_quota",
                provider_price_id="price_ai_quota",
                billing_interval="month",
            )
        )
        db.commit()

    for index in range(4):
        response = client.post(
            "/api/v1/ai/chat",
            headers=headers,
            json={"message": f"What is luteal phase? premium {index}"},
        )
        assert response.status_code == 200
        body = response.json()
        assert body["chat_limit"] == 50
        assert body["chats_used"] == index + 1
        assert body["chats_remaining"] == 49 - index


def test_medical_chat_uses_lh_and_mucus_for_ovulation_context(tmp_path, monkeypatch):
    client, headers, verify = _verified_client(tmp_path, monkeypatch)
    user_id = verify["user"]["id"]
    now = datetime.now(UTC)

    with get_session_factory()() as db:
        cycle = CycleRecord(
            user_id=user_id,
            period_start_date=(now - timedelta(days=12)).date(),
            cycle_length_days=28,
            menses_length=5,
            is_active=True,
        )
        db.add(cycle)
        db.flush()
        db.add_all(
            [
                DailyLog(
                    user_id=user_id,
                    cycle_id=cycle.id,
                    log_date=now.date(),
                    log_type=LogType.LH,
                    payload={"state": "peak", "positive": True, "cycle_day": 13},
                ),
                DailyLog(
                    user_id=user_id,
                    cycle_id=cycle.id,
                    log_date=now.date(),
                    log_type=LogType.MUCUS,
                    payload={"type": "egg white", "amount": "moderate"},
                ),
            ]
        )
        db.commit()

    response = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "Am I close to ovulation?"},
    )

    assert response.status_code == 200
    body = response.json()
    answer = body["answer"].lower()
    assert body["sufficient_data"] is True
    assert "cycle.lh" in body["used_user_data"]
    assert "cycle.mucus" in body["used_user_data"]
    assert "lh" in answer
    assert "egg white" in answer


def test_medical_chat_escalates_urgent_symptoms(tmp_path, monkeypatch):
    client, headers, _ = _verified_client(tmp_path, monkeypatch)

    response = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "I have severe pain and very heavy bleeding today."},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["sufficient_data"] is True
    assert "potentially urgent" in body["answer"]
    assert "urgent medical help" in body["answer"]


def test_medical_chat_personalizes_fatigue_with_cycle_and_wearables(tmp_path, monkeypatch):
    client, headers, verify = _verified_client(tmp_path, monkeypatch)
    user_id = verify["user"]["id"]
    now = datetime.now(UTC).replace(microsecond=0)

    with get_session_factory()() as db:
        db.add(
            CycleRecord(
                user_id=user_id,
                period_start_date=(now - timedelta(days=22)).date(),
                cycle_length_days=29,
                menses_length=5,
                is_active=True,
            )
        )
        db.add_all(
            [
                SensorReading(
                    user_id=user_id,
                    metric="sleep_minutes",
                    value=360,
                    source="vyla",
                    recorded_at=now - timedelta(days=1),
                ),
                SensorReading(
                    user_id=user_id,
                    metric="hrv",
                    value=34,
                    source="vyla",
                    recorded_at=now - timedelta(days=1),
                ),
                SensorReading(
                    user_id=user_id,
                    metric="rhr",
                    value=74,
                    source="vyla",
                    recorded_at=now - timedelta(days=1),
                ),
            ]
        )
        db.commit()

    response = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "Why am I so tired today?"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["sufficient_data"] is True
    assert "fatigue" in body["answer"].lower()
    assert "cycle day" in body["answer"]
    assert "sleep" in body["answer"].lower()
    assert "hrv" in body["answer"].lower()


def test_medical_chat_does_not_expose_raw_profile_metadata(tmp_path, monkeypatch):
    client, headers, verify = _verified_client(tmp_path, monkeypatch)

    with get_session_factory()() as db:
        profile = db.query(UserProfile).filter(UserProfile.user_id == verify["user"]["id"]).one()
        profile.conditions = {
            "first_name": "Melissa",
            "last_name": "Nti",
            "country": "United Kingdom",
            "account_type": "email",
            "consents": {"terms_accepted": True, "privacy_policy_accepted": True},
            "registration_context": {"client": "mobile", "app_version": "1.0.0"},
            "health_conditions": ["Hormone imbalance", "PCOS"],
            "ai_preferences": {"chat_consent_accepted": True},
        }
        db.commit()

    response = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "What does PCOS mean for me?"},
    )

    assert response.status_code == 200
    answer = response.json()["answer"]
    assert "PCOS" in answer
    assert "Hormone imbalance" in answer
    assert "first_name" not in answer
    assert "consents" not in answer
    assert "registration_context" not in answer
    assert "{" not in answer




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
    assert body["has_more"] is False
    assert body["next_before"] is None


def test_medical_chat_history_paginates_older_messages(tmp_path, monkeypatch):
    client, headers, verify = _verified_client(tmp_path, monkeypatch)

    with get_session_factory()() as db:
        db.add(
            Subscription(
                user_id=verify["user"]["id"],
                tier="premium_plus",
                status="active",
                provider="stripe",
                billing_interval="month",
                current_period_end=datetime.now(UTC) + timedelta(days=30),
            )
        )
        db.commit()

    response = client.post(
        "/api/v1/ai/chat",
        headers=headers,
        json={"message": "What is luteal phase? page 0"},
    )
    assert response.status_code == 200
    thread_id = response.json()["thread_id"]

    for index in range(1, 5):
        response = client.post(
            "/api/v1/ai/chat",
            headers=headers,
            json={"thread_id": thread_id, "message": f"What is luteal phase? page {index}"},
        )
        assert response.status_code == 200

    latest = client.get(
        f"/api/v1/ai/chat/threads/{thread_id}",
        headers=headers,
        params={"limit": 4},
    )
    assert latest.status_code == 200
    latest_body = latest.json()
    assert len(latest_body["messages"]) == 4
    assert latest_body["has_more"] is True
    assert latest_body["next_before"] is not None
    assert "page 3" in latest_body["messages"][0]["content"] or latest_body["messages"][0]["role"] == "assistant"

    older = client.get(
        f"/api/v1/ai/chat/threads/{thread_id}",
        headers=headers,
        params={"limit": 4, "before": latest_body["next_before"]},
    )
    assert older.status_code == 200
    older_body = older.json()
    assert len(older_body["messages"]) == 4
    assert older_body["messages"][-1]["created_at"] < latest_body["messages"][0]["created_at"]


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
