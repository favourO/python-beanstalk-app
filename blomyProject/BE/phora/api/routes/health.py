from fastapi import APIRouter, Depends

from phora.api.deps import get_settings_dep
from phora.core.config import Settings
from phora.core.metrics import metrics_response

router = APIRouter(tags=["health"])


@router.get("/health")
def health(settings: Settings = Depends(get_settings_dep)) -> dict:
    return {"status": "ok", "service": settings.app_name, "ml": None}


@router.get("/metrics")
def metrics():
    return metrics_response()
