from __future__ import annotations

from collections.abc import Iterable
from functools import lru_cache
from pathlib import Path


_RESERVED_FAKE_DOMAINS = frozenset({"localhost", "local"})
_RESERVED_FAKE_TLDS = ("invalid", "localhost", "test")


def is_blocked_signup_email(email: str, blocked_domains: Iterable[str]) -> bool:
    domain = _email_domain(email)
    if not domain:
        return True

    if domain in _RESERVED_FAKE_DOMAINS:
        return True
    if any(
        domain == tld or domain.endswith(f".{tld}")
        for tld in _RESERVED_FAKE_TLDS
    ):
        return True

    blocked = _disposable_email_domains() | {
        _normalize_domain(value)
        for value in blocked_domains
    }
    blocked.discard("")
    return any(domain == value or domain.endswith(f".{value}") for value in blocked)


@lru_cache(maxsize=1)
def _disposable_email_domains() -> set[str]:
    path = Path(__file__).resolve().parents[1] / "assets" / "disposable_email_blocklist.conf"
    if not path.exists():
        return set()
    return {
        domain
        for line in path.read_text(encoding="utf-8").splitlines()
        if (domain := _normalize_domain(line)) and not domain.startswith("#")
    }


def _email_domain(email: str) -> str:
    _, separator, domain = email.strip().lower().rpartition("@")
    if not separator:
        return ""
    return _normalize_domain(domain)


def _normalize_domain(domain: str) -> str:
    return domain.strip().lower().lstrip("@").strip(".")
