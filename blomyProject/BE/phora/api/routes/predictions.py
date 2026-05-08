from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from phora.api.deps import get_current_user_id, get_ml_client, get_settings_dep
from phora.db.session import get_db
from phora.schemas.prediction import AgeContextResponse, CalendarPredictionResponse, PredictionSnapshotResponse
from phora.services.ml_client import MlClient
from phora.services.prediction_service import PredictionService

router = APIRouter(prefix="/predictions", tags=["predictions"])


def _service(db: Session, settings, ml_client: MlClient) -> PredictionService:
    return PredictionService(db, settings, ml_client)


@router.get("/current", response_model=PredictionSnapshotResponse)
def current_prediction(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
    ml_client: MlClient = Depends(get_ml_client),
):
    return _service(db, settings, ml_client).latest_prediction(user_id)


@router.get("/calendar", response_model=list[CalendarPredictionResponse])
def prediction_calendar(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
    ml_client: MlClient = Depends(get_ml_client),
):
    return _service(db, settings, ml_client).calendar(user_id)


@router.get("/fertile-window")
def fertile_window(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
    ml_client: MlClient = Depends(get_ml_client),
):
    return _service(db, settings, ml_client).latest_prediction(user_id).fertile_window


@router.get("/ovulation")
def ovulation(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
    ml_client: MlClient = Depends(get_ml_client),
):
    latest = _service(db, settings, ml_client).latest_prediction(user_id)
    return {"predicted_date": latest.ovulation_estimate.get("date"), "method_used": latest.audit.get("ovulation_estimate_source")}


@router.get("/next-period")
def next_period(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
    ml_client: MlClient = Depends(get_ml_client),
):
    return _service(db, settings, ml_client).latest_prediction(user_id).next_period_estimate


@router.get("/age-context", response_model=AgeContextResponse)
def age_context(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
    ml_client: MlClient = Depends(get_ml_client),
):
    return _service(db, settings, ml_client).age_context(user_id)

