import base64
import hashlib
import hmac
import secrets
import time
from datetime import UTC, datetime, timedelta
from typing import Any

from jose import JWTError, jwt
from passlib.context import CryptContext
from passlib.hash import bcrypt, bcrypt_sha256

from phora.core.config import get_settings

# bcrypt truncates inputs above 72 bytes. Use bcrypt_sha256 for new hashes
# while still accepting legacy bcrypt hashes already stored in the database.
pwd_context = CryptContext(schemes=["bcrypt_sha256", "bcrypt"], deprecated="auto")
_CROCKFORD_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
_UNUSABLE_PASSWORD_PREFIX = "!phora-unusable-password$"


def hash_password(password: str) -> str:
    # Hash new passwords with bcrypt_sha256 explicitly so multi-byte passwords
    # never hit bcrypt's 72-byte input limit during signup or reset flows.
    return bcrypt_sha256.hash(password)


def make_unusable_password() -> str:
    return f"{_UNUSABLE_PASSWORD_PREFIX}{secrets.token_urlsafe(24)}"


def is_password_usable(hashed_password: str | None) -> bool:
    return bool(hashed_password) and not hashed_password.startswith(_UNUSABLE_PASSWORD_PREFIX)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    if not is_password_usable(hashed_password):
        return False
    scheme = pwd_context.identify(hashed_password)
    if scheme == "bcrypt_sha256":
        return bcrypt_sha256.verify(plain_password, hashed_password)
    if scheme == "bcrypt":
        return bcrypt.verify(plain_password, hashed_password)
    return False


def create_token(
    subject: str,
    token_type: str,
    expires_minutes: int,
    generation: int = 0,
    extra_claims: dict[str, Any] | None = None,
) -> str:
    settings = get_settings()
    expire = datetime.now(UTC) + timedelta(minutes=expires_minutes)
    payload: dict[str, Any] = {"sub": subject, "type": token_type, "exp": expire, "gen": generation}
    if extra_claims:
        payload.update(extra_claims)
    return jwt.encode(payload, settings.secret_key, algorithm=settings.algorithm)


def decode_token(token: str) -> dict[str, Any]:
    settings = get_settings()
    return jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])


def decode_token_safe(token: str) -> dict[str, Any] | None:
    try:
        return decode_token(token)
    except JWTError:
        return None


def new_ulid() -> str:
    timestamp_ms = int(time.time() * 1000)
    randomness = secrets.token_bytes(10)
    value = (timestamp_ms << 80) | int.from_bytes(randomness, "big")
    chars: list[str] = []
    for _ in range(26):
        chars.append(_CROCKFORD_ALPHABET[value & 0x1F])
        value >>= 5
    return "".join(reversed(chars))


def hash_ip_for_rate_limit(ip_address: str) -> str:
    return hashlib.sha256(ip_address.encode("utf-8")).hexdigest()[:16]


def hash_token(token: str, secret_key: str) -> str:
    return hmac.new(secret_key.encode("utf-8"), token.encode("utf-8"), hashlib.sha256).hexdigest()
