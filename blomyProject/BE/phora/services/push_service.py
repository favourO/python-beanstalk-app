from __future__ import annotations

from dataclasses import dataclass

from phora.core.config import Settings
from phora.services.firebase_auth import ensure_firebase_app


@dataclass
class PushSendResult:
    delivered_tokens: list[str]
    invalid_tokens: list[str]
    failed_tokens: list[str]


class FcmPushService:
    def __init__(self, settings: Settings):
        self.settings = settings

    def send_notification(
        self,
        *,
        tokens: list[str],
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> PushSendResult:
        if not tokens:
            return PushSendResult(delivered_tokens=[], invalid_tokens=[], failed_tokens=[])

        from firebase_admin import messaging

        app = ensure_firebase_app(self.settings)
        delivered_tokens: list[str] = []
        invalid_tokens: list[str] = []
        failed_tokens: list[str] = []
        payload_data = {str(key): str(value) for key, value in (data or {}).items()}

        for token in tokens:
            message = messaging.Message(
                token=token,
                notification=messaging.Notification(title=title, body=body),
                data=payload_data,
            )
            try:
                messaging.send(message, app=app)
                delivered_tokens.append(token)
            except Exception as exc:  # pragma: no cover
                if self._is_invalid_token_error(exc):
                    invalid_tokens.append(token)
                else:
                    failed_tokens.append(token)

        return PushSendResult(
            delivered_tokens=delivered_tokens,
            invalid_tokens=invalid_tokens,
            failed_tokens=failed_tokens,
        )

    def _is_invalid_token_error(self, exc: Exception) -> bool:
        code = getattr(exc, "code", None)
        if code in {"registration-token-not-registered", "invalid-argument", "unregistered"}:
            return True
        text = str(exc).lower()
        return "registration-token-not-registered" in text or "not registered" in text or "invalid registration token" in text
