from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from phora.core.config import Settings, get_settings
from phora.core.security import decode_token_safe
from phora.db.session import get_db
from phora.models.user import User
from phora.repositories.core import UserRepository
from phora.services.inprocess_ml_client import InProcessMlClient
from phora.services.ml_client import DisabledMlClient, MlClient

bearer_scheme = HTTPBearer(auto_error=False)


def get_settings_dep() -> Settings:
    return get_settings()


def get_ml_client(settings: Settings = Depends(get_settings_dep)) -> MlClient:
    if not settings.ml_enabled:
        return DisabledMlClient(settings)
    if settings.ml_inprocess:
        return InProcessMlClient(settings)
    if settings.ml_base_url:
        return MlClient(settings)
    return DisabledMlClient(settings)


def _resolve_user(
    credentials: HTTPAuthorizationCredentials | None,
    db: Session,
) -> User:
    if not credentials:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
    payload = decode_token_safe(credentials.credentials)
    if not payload or payload.get("type") != "access":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    user = UserRepository(db).by_id(payload["sub"])
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    token_generation = payload.get("gen")
    if token_generation is None:
        if user.token_generation != 0:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token has been revoked")
    elif token_generation != user.token_generation:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token has been revoked")
    return user


def get_current_user_id(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> str:
    return _resolve_user(credentials, db).id


def get_current_admin_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> User:
    user = _resolve_user(credentials, db)
    if not user.is_admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user
