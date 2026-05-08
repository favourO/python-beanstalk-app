import logging
from collections.abc import Callable

import httpx

from phora.core.config import Settings
from phora.schemas.ml import MlEnsembleRequest, MlEnsembleResponse, MlHealthResponse, MlLHStripResponse

logger = logging.getLogger(__name__)


class MlClient:
    def __init__(self, settings: Settings, client_factory: Callable[[], httpx.Client] | None = None):
        self.settings = settings
        self._client_factory = client_factory or (
            lambda: httpx.Client(base_url=settings.ml_base_url, timeout=settings.ml_timeout_ms / 1000)
        )

    def _request(self, method: str, path: str, json: dict | None = None) -> dict:
        last_error: Exception | None = None
        for attempt in range(self.settings.ml_retry_count + 1):
            try:
                with self._client_factory() as client:
                    response = client.request(method, path, json=json)
                    response.raise_for_status()
                    return response.json()
            except Exception as exc:  # pragma: no cover - network path
                last_error = exc
                logger.warning("ML request failed", extra={"path": path, "attempt": attempt, "error": str(exc)})
        raise RuntimeError(f"ML request failed after retries: {last_error}") from last_error

    def _request_bytes(self, method: str, path: str, *, content: bytes, content_type: str) -> dict:
        last_error: Exception | None = None
        for attempt in range(self.settings.ml_retry_count + 1):
            try:
                with self._client_factory() as client:
                    response = client.request(method, path, content=content, headers={"content-type": content_type})
                    response.raise_for_status()
                    return response.json()
            except Exception as exc:  # pragma: no cover - network path
                last_error = exc
                logger.warning("ML request failed", extra={"path": path, "attempt": attempt, "error": str(exc)})
        raise RuntimeError(f"ML request failed after retries: {last_error}") from last_error

    def health(self) -> MlHealthResponse:
        return MlHealthResponse.model_validate(self._request("GET", "/health"))

    def model_versions(self) -> dict:
        return self._request("GET", "/models/versions")

    def predict_ensemble(self, payload: MlEnsembleRequest) -> MlEnsembleResponse:
        return MlEnsembleResponse.model_validate(self._request("POST", "/predict/ensemble", json=payload.model_dump(mode="json")))

    def analyze_lh_strip(self, image_bytes: bytes, content_type: str) -> MlLHStripResponse:
        return MlLHStripResponse.model_validate(
            self._request_bytes("POST", "/analyze/lh-strip", content=image_bytes, content_type=content_type)
        )


class DisabledMlClient(MlClient):
    def __init__(self, settings: Settings):
        self.settings = settings
        self._client_factory = lambda: None

    def health(self) -> MlHealthResponse:
        return MlHealthResponse(status="disabled", models_loaded=False, uptime=None)

    def model_versions(self) -> dict:
        return {}

    def predict_ensemble(self, payload: MlEnsembleRequest) -> MlEnsembleResponse:
        raise RuntimeError("ML predictions are disabled")

    def analyze_lh_strip(self, image_bytes: bytes, content_type: str) -> MlLHStripResponse:
        raise RuntimeError("LH strip image analysis is disabled")
