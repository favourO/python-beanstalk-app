from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from phora.api.deps import get_current_user_id
from phora.db.session import get_db
from phora.schemas.notification import (
    NotificationDeviceDeleteRequest,
    NotificationDeviceResponse,
    NotificationDeviceUpsertRequest,
    NotificationDispatchResponse,
    NotificationListResponse,
    NotificationMarkReadResponse,
    NotificationPreferencesResponse,
    NotificationPreferencesUpdateRequest,
    NotificationSettingsResponse,
    NotificationSettingsUpdateRequest,
    NotificationTriggerRequest,
)
from phora.services.notification_service import NotificationService

router = APIRouter(prefix="/notifications", tags=["notifications"])


def _service(db: Session) -> NotificationService:
    return NotificationService(db)


@router.get("/preferences", response_model=NotificationPreferencesResponse)
def get_preferences(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    return _service(db).get_preferences(user_id)


@router.put("/preferences", response_model=NotificationPreferencesResponse)
def update_preferences(
    payload: NotificationPreferencesUpdateRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    return _service(db).update_preferences(user_id, payload)


@router.get("/settings", response_model=NotificationSettingsResponse)
def get_settings(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    return _service(db).get_settings(user_id)


@router.put("/settings", response_model=NotificationSettingsResponse)
def update_settings(
    payload: NotificationSettingsUpdateRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    return _service(db).update_settings(user_id, payload)


@router.get("", response_model=NotificationListResponse)
def list_notifications(
    unread_only: bool = Query(default=False),
    limit: int = Query(default=50, ge=1, le=100),
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    items, unread_count = _service(db).list_notifications(user_id, unread_only=unread_only, limit=limit)
    return NotificationListResponse(items=items, unread_count=unread_count)


@router.get("/devices", response_model=list[NotificationDeviceResponse])
def list_devices(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    return _service(db).list_devices(user_id)


@router.post("/devices", response_model=NotificationDeviceResponse)
def register_device(
    payload: NotificationDeviceUpsertRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    return _service(db).register_device(user_id, payload)


@router.delete("/devices", response_model=NotificationMarkReadResponse)
def unregister_device(
    payload: NotificationDeviceDeleteRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    return NotificationMarkReadResponse(updated=_service(db).unregister_device(user_id, payload.device_id))


@router.post("/read-all", response_model=NotificationMarkReadResponse)
def mark_all_read(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    return NotificationMarkReadResponse(updated=_service(db).mark_all_read(user_id))


@router.post("/{notification_id}/read", response_model=NotificationMarkReadResponse)
def mark_read(
    notification_id: str,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    return NotificationMarkReadResponse(
        updated=_service(db).mark_read(user_id, notification_id),
    )


@router.post("/trigger", response_model=NotificationDispatchResponse)
def trigger_notification(
    payload: NotificationTriggerRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    return _service(db).trigger_notification(user_id, payload)


@router.post("/evaluate", response_model=NotificationDispatchResponse)
def evaluate_notifications(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    return _service(db).evaluate_due_notifications(user_id)
