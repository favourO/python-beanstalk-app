from sqlalchemy.orm import Session

from phora.repositories.core import AuditRepository


class GrowthAnalyticsService:
    def __init__(self, db: Session):
        self.db = db
        self.audit = AuditRepository(db)

    def track(self, user_id: str | None, event: str, payload: dict) -> None:
        self.audit.log(user_id, event, payload)
