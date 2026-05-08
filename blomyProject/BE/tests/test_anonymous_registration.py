import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import select

from phora.api.app import create_app
from phora.api.routes import auth as auth_routes
from phora.db.session import get_session_factory, reset_db_state
from phora.models import AuditEvent, User


def _words(phrase: str) -> list[str]:
    return [part for part in phrase.split(" ") if part]


@pytest_asyncio.fixture
async def anonymous_client(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'anonymous.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "anonymous-test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    reset_db_state()
    auth_routes._auth_rate_limit_buckets.clear()
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        yield client
    auth_routes._auth_rate_limit_buckets.clear()
    reset_db_state()


@pytest.mark.asyncio
async def test_anonymous_register_returns_201(anonymous_client: AsyncClient):
    response = await anonymous_client.post("/api/0.1.0/auth/register/anonymous")
    assert response.status_code == 201


@pytest.mark.asyncio
async def test_anonymous_register_response_has_access_token(anonymous_client: AsyncClient):
    response = await anonymous_client.post("/api/0.1.0/auth/register/anonymous")
    body = response.json()
    assert isinstance(body["access_token"], str)
    assert body["access_token"]


@pytest.mark.asyncio
async def test_anonymous_register_response_has_recovery_phrase(anonymous_client: AsyncClient):
    response = await anonymous_client.post("/api/0.1.0/auth/register/anonymous")
    phrase = response.json()["recovery_phrase"]
    assert isinstance(phrase, str)
    assert len(_words(phrase)) == 24


@pytest.mark.asyncio
async def test_anonymous_register_response_has_no_refresh_token_in_body(anonymous_client: AsyncClient):
    response = await anonymous_client.post("/api/0.1.0/auth/register/anonymous")
    assert "refresh_token" not in response.text


@pytest.mark.asyncio
async def test_anonymous_register_sets_refresh_cookie(anonymous_client: AsyncClient):
    response = await anonymous_client.post("/api/0.1.0/auth/register/anonymous")
    cookie = response.headers.get("set-cookie", "")
    assert "phora_refresh=" in cookie
    assert "HttpOnly" in cookie
    assert "Path=/api/v1/auth/refresh" in cookie


@pytest.mark.asyncio
async def test_anonymous_register_rate_limited(anonymous_client: AsyncClient):
    for _ in range(10):
        response = await anonymous_client.post("/api/0.1.0/auth/register/anonymous")
        assert response.status_code == 201
    limited = await anonymous_client.post("/api/0.1.0/auth/register/anonymous")
    assert limited.status_code == 429


@pytest.mark.asyncio
async def test_recovery_phrase_not_stored_in_db(anonymous_client: AsyncClient):
    response = await anonymous_client.post("/api/0.1.0/auth/register/anonymous")
    phrase = response.json()["recovery_phrase"]
    with get_session_factory()() as session:
        user = session.scalar(select(User).where(User.account_mode == "anonymous"))
        assert user is not None
        assert user.email is None
        assert user.password_hash != phrase
        assert user.account_mode == "anonymous"


@pytest.mark.asyncio
async def test_no_raw_ip_in_audit_log(anonymous_client: AsyncClient):
    await anonymous_client.post("/api/0.1.0/auth/register/anonymous")
    with get_session_factory()() as session:
        event = session.scalar(select(AuditEvent).where(AuditEvent.action == "anonymous_user_registered"))
        assert event is not None
        payload = event.payload or {}
        assert "ip" not in payload
        assert "ip_address" not in payload
        assert "remote_addr" not in payload


@pytest.mark.asyncio
async def test_anonymous_login_with_correct_phrase_succeeds(anonymous_client: AsyncClient):
    register = await anonymous_client.post("/api/0.1.0/auth/register/anonymous")
    phrase = register.json()["recovery_phrase"]
    response = await anonymous_client.post(
        "/api/0.1.0/auth/login/recovery-phrase",
        json={"recovery_phrase": phrase},
    )
    assert response.status_code == 200
    assert response.json()["access_token"]


@pytest.mark.asyncio
async def test_anonymous_login_with_wrong_phrase_returns_401(anonymous_client: AsyncClient):
    register = await anonymous_client.post("/api/0.1.0/auth/register/anonymous")
    phrase = register.json()["recovery_phrase"]
    words = _words(phrase)
    wrong_phrase = " ".join(list(reversed(words)))
    assert wrong_phrase != phrase
    response = await anonymous_client.post(
        "/api/0.1.0/auth/login/recovery-phrase",
        json={"recovery_phrase": wrong_phrase},
    )
    assert response.status_code == 401
