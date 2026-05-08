from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from phora.api.deps import get_current_user_id, get_ml_client, get_settings_dep
from phora.db.session import get_db
from phora.schemas.home import HomeResponse
from phora.services.home_service import HomeService
from phora.services.ml_client import MlClient

router = APIRouter(prefix="/home", tags=["home"])


@router.get("", response_model=HomeResponse)
def get_home(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
    ml_client: MlClient = Depends(get_ml_client),
) -> HomeResponse:
    return HomeService(db, settings, ml_client).get_home_payload(user_id)
