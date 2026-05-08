from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from phora.api.deps import get_current_user_id, get_ml_client, get_settings_dep
from phora.core.config import Settings
from phora.db.session import get_db
from phora.schemas.growth import (
    ComparisonPermissionUpdateRequest,
    ComparisonSummaryResponse,
    FriendConnectionResponse,
    FriendNetworkResponse,
    FriendRequestCreateRequest,
    GrowthActionResponse,
    ReferralClaimRequest,
    ReferralStatusResponse,
    ShareEventRequest,
    ShareGenerateRequest,
    ShareGenerateResponse,
    ShareInsightConfigResponse,
    ShareInsightResponse,
)
from phora.services.comparison_service import ComparisonService
from phora.services.referral_service import ReferralService
from phora.services.share_service import ShareService
from phora.services.ml_client import MlClient

router = APIRouter(prefix="/growth", tags=["growth"])


def _value_error(exc: Exception) -> HTTPException:
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))


@router.get("/share-insight", response_model=ShareInsightResponse)
def get_share_insight(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
    ml_client: MlClient = Depends(get_ml_client),
) -> ShareInsightResponse:
    try:
        payload = ShareService(db, settings, ml_client).build_payload(user_id)
        db.commit()
        return ShareInsightResponse(**payload)
    except ValueError as exc:
        db.rollback()
        raise _value_error(exc) from exc


@router.get("/share-insight/config", response_model=ShareInsightConfigResponse)
def get_share_insight_config(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
    ml_client: MlClient = Depends(get_ml_client),
) -> ShareInsightConfigResponse:
    try:
        payload = ShareService(db, settings, ml_client).get_share_config(user_id)
        db.commit()
        return ShareInsightConfigResponse(**payload)
    except ValueError as exc:
        db.rollback()
        raise _value_error(exc) from exc


@router.get("/cycle-report/config", response_model=ShareInsightConfigResponse)
def get_cycle_report_config(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
    ml_client: MlClient = Depends(get_ml_client),
) -> ShareInsightConfigResponse:
    try:
        payload = ShareService(db, settings, ml_client).get_cycle_report_config(user_id)
        db.commit()
        return ShareInsightConfigResponse(**payload)
    except ValueError as exc:
        db.rollback()
        raise _value_error(exc) from exc


@router.post("/share-insight/generate", response_model=ShareGenerateResponse)
def generate_share_insight(
    payload: ShareGenerateRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
    ml_client: MlClient = Depends(get_ml_client),
) -> ShareGenerateResponse:
    try:
        response = ShareService(db, settings, ml_client).generate_share(
            user_id,
            section_ids=payload.section_ids,
            audience=payload.audience,
            method=payload.method,
            cycle_count=payload.cycle_count,
        )
        db.commit()
        return ShareGenerateResponse(**response)
    except ValueError as exc:
        db.rollback()
        raise _value_error(exc) from exc


@router.post("/cycle-report/generate", response_model=ShareGenerateResponse)
def generate_cycle_report(
    payload: ShareGenerateRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
    ml_client: MlClient = Depends(get_ml_client),
) -> ShareGenerateResponse:
    try:
        response = ShareService(db, settings, ml_client).generate_share(
            user_id,
            section_ids=payload.section_ids,
            audience=payload.audience,
            method=payload.method,
            cycle_count=payload.cycle_count,
        )
        db.commit()
        return ShareGenerateResponse(**response)
    except ValueError as exc:
        db.rollback()
        raise _value_error(exc) from exc


@router.post("/share-events", response_model=GrowthActionResponse)
def track_share_event(
    payload: ShareEventRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
    ml_client: MlClient = Depends(get_ml_client),
) -> GrowthActionResponse:
    ShareService(db, settings, ml_client).track_event(
        user_id,
        share_id=payload.share_id,
        event=payload.event,
        channel=payload.channel,
        deep_link_id=payload.deep_link_id,
    )
    db.commit()
    return GrowthActionResponse()


@router.get("/friends", response_model=FriendNetworkResponse)
def get_friend_network(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> FriendNetworkResponse:
    return FriendNetworkResponse(**ComparisonService(db, settings).friend_network(user_id))


@router.post("/friends/requests", response_model=FriendConnectionResponse)
def create_friend_request(
    payload: FriendRequestCreateRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> FriendConnectionResponse:
    try:
        response = ComparisonService(db, settings).send_request(user_id, payload.email)
        db.commit()
        return FriendConnectionResponse(**response)
    except (ValueError, PermissionError) as exc:
        db.rollback()
        raise _value_error(exc) from exc


@router.post("/friends/requests/{connection_id}/accept", response_model=FriendConnectionResponse)
def accept_friend_request(
    connection_id: str,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> FriendConnectionResponse:
    try:
        response = ComparisonService(db, settings).respond_to_request(user_id, connection_id, accept=True)
        db.commit()
        return FriendConnectionResponse(**response)
    except (ValueError, PermissionError) as exc:
        db.rollback()
        raise _value_error(exc) from exc


@router.post("/friends/requests/{connection_id}/decline", response_model=FriendConnectionResponse)
def decline_friend_request(
    connection_id: str,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> FriendConnectionResponse:
    try:
        response = ComparisonService(db, settings).respond_to_request(user_id, connection_id, accept=False)
        db.commit()
        return FriendConnectionResponse(**response)
    except (ValueError, PermissionError) as exc:
        db.rollback()
        raise _value_error(exc) from exc


@router.put("/friends/{friend_id}/comparison-permission", response_model=FriendConnectionResponse)
def update_comparison_permission(
    friend_id: str,
    payload: ComparisonPermissionUpdateRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> FriendConnectionResponse:
    try:
        response = ComparisonService(db, settings).update_permission(user_id, friend_id, enabled=payload.enabled)
        db.commit()
        return FriendConnectionResponse(**response)
    except (ValueError, PermissionError) as exc:
        db.rollback()
        raise _value_error(exc) from exc


@router.get("/compare/{friend_id}", response_model=ComparisonSummaryResponse)
def compare_with_friend(
    friend_id: str,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> ComparisonSummaryResponse:
    try:
        return ComparisonSummaryResponse(**ComparisonService(db, settings).compare_summary(user_id, friend_id))
    except (ValueError, PermissionError) as exc:
        raise _value_error(exc) from exc


@router.get("/referral", response_model=ReferralStatusResponse)
def get_referral_status(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> ReferralStatusResponse:
    response = ReferralService(db, settings).get_status(user_id)
    db.commit()
    return ReferralStatusResponse(**response)


@router.post("/referral/claim", response_model=GrowthActionResponse)
def claim_referral(
    payload: ReferralClaimRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings_dep),
) -> GrowthActionResponse:
    try:
        ReferralService(db, settings).claim_code(
            user_id,
            payload.referral_code,
            source=payload.source,
            deep_link_id=payload.deep_link_id,
        )
        db.commit()
        return GrowthActionResponse()
    except ValueError as exc:
        db.rollback()
        raise _value_error(exc) from exc
