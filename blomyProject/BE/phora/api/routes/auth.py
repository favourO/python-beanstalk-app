import time
from collections import deque

from fastapi import APIRouter, Body, Depends, HTTPException, Request, Response, status
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from phora.api.deps import get_settings_dep
from phora.api.deps import get_current_user_id
from phora.core.security import hash_ip_for_rate_limit
from phora.db.session import get_db
from phora.schemas.auth import (
    AppleLoginRequest,
    AnonymousLoginResponse,
    AnonymousRegisterResponse,
    AuthResponse,
    ChangePasswordRequest,
    ChangePasswordResponse,
    FirebaseLoginRequest,
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    GoogleLoginRequest,
    LoginRequest,
    PendingVerificationResponse,
    RecoveryPhraseLoginRequest,
    RegisterRequest,
    RefreshTokenRequest,
    ResetPasswordRequest,
    ResetPasswordResponse,
    ResendOtpRequest,
    SignoutResponse,
    SignupRequest,
    SignupResponse,
    TOTPCodeVerifyRequest,
    TOTPSetupStartResponse,
    TOTPStatusResponse,
    TOTPToggleResponse,
    TokenPair,
    VerifyRequest,
)
from phora.services.auth import AuthService, ConflictError, InvalidAuthRequestError, UnverifiedAccountError
from phora.services.email import EmailDeliveryError, EmailService

router = APIRouter(prefix="/auth", tags=["auth"])
_AUTH_RATE_LIMIT_WINDOW_SECONDS = 60
_auth_rate_limit_buckets: dict[str, deque[float]] = {}


def _service(db: Session, settings) -> AuthService:
    return AuthService(db, settings, EmailService(settings))


def _set_refresh_cookie(response: Response, refresh_token: str, settings) -> None:
    response.set_cookie(
        key="phora_refresh",
        value=refresh_token,
        httponly=True,
        samesite="strict",
        secure=settings.environment in {"stage", "staging", "prod"},
        path="/api/v1/auth/refresh",
        max_age=settings.refresh_token_exp_minutes * 60,
    )


def _clear_refresh_cookie(response: Response, settings) -> None:
    response.delete_cookie(
        key="phora_refresh",
        httponly=True,
        samesite="strict",
        secure=settings.environment in {"stage", "staging", "prod"},
        path="/api/v1/auth/refresh",
    )


def _check_auth_rate_limit(request: Request) -> None:
    client_host = request.client.host if request.client else "unknown"
    hashed_ip = hash_ip_for_rate_limit(client_host)
    now = time.monotonic()
    bucket = _auth_rate_limit_buckets.setdefault(hashed_ip, deque())
    while bucket and now - bucket[0] >= _AUTH_RATE_LIMIT_WINDOW_SECONDS:
        bucket.popleft()
    if len(bucket) >= 10:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Too many requests")
    bucket.append(now)


@router.post("/register", response_model=TokenPair)
def register(payload: RegisterRequest, db: Session = Depends(get_db)) -> TokenPair:
    raise HTTPException(status_code=status.HTTP_410_GONE, detail="Use /auth/signup")


@router.post("/signup", response_model=SignupResponse)
def signup(
    payload: SignupRequest,
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> SignupResponse:
    try:
        return _service(db, settings).signup(payload)
    except EmailDeliveryError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc
    except InvalidAuthRequestError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc


@router.post("/verify", response_model=AuthResponse)
def verify(
    payload: VerifyRequest,
    response: Response,
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> AuthResponse:
    try:
        auth_response = _service(db, settings).verify(payload)
        _set_refresh_cookie(response, auth_response.refresh_token, settings)
        return auth_response
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/resend-otp", response_model=SignupResponse)
def resend_otp(
    payload: ResendOtpRequest,
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> SignupResponse:
    try:
        return _service(db, settings).resend_otp(payload)
    except EmailDeliveryError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc


@router.post("/social-login", response_model=AuthResponse)
def social_login(
    payload: FirebaseLoginRequest,
    response: Response,
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> AuthResponse:
    try:
        auth_response = _service(db, settings).social_login(payload)
        _set_refresh_cookie(response, auth_response.refresh_token, settings)
        return auth_response
    except InvalidAuthRequestError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc


@router.post("/google-login", response_model=AuthResponse)
def google_login(
    payload: GoogleLoginRequest,
    response: Response,
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> AuthResponse:
    try:
        auth_response = _service(db, settings).google_login(payload)
        _set_refresh_cookie(response, auth_response.refresh_token, settings)
        return auth_response
    except InvalidAuthRequestError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc


@router.post("/google-signup", response_model=AuthResponse)
def google_signup(
    payload: GoogleLoginRequest,
    response: Response,
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> AuthResponse:
    try:
        auth_response = _service(db, settings).google_signup(payload)
        _set_refresh_cookie(response, auth_response.refresh_token, settings)
        return auth_response
    except ConflictError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except InvalidAuthRequestError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc


@router.post("/apple-login", response_model=AuthResponse)
def apple_login(
    payload: AppleLoginRequest,
    response: Response,
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> AuthResponse:
    try:
        auth_response = _service(db, settings).apple_login(payload)
        _set_refresh_cookie(response, auth_response.refresh_token, settings)
        return auth_response
    except InvalidAuthRequestError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc


@router.post("/apple-signup", response_model=AuthResponse)
def apple_signup(
    payload: AppleLoginRequest,
    response: Response,
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> AuthResponse:
    try:
        auth_response = _service(db, settings).apple_signup(payload)
        _set_refresh_cookie(response, auth_response.refresh_token, settings)
        return auth_response
    except ConflictError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    except InvalidAuthRequestError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc


@router.post("/login", response_model=AuthResponse)
def login(
    payload: LoginRequest,
    response: Response,
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
):
    try:
        auth_response = _service(db, settings).login(payload)
        _set_refresh_cookie(response, auth_response.refresh_token, settings)
        return auth_response
    except UnverifiedAccountError as exc:
        return JSONResponse(
            status_code=status.HTTP_202_ACCEPTED,
            content=PendingVerificationResponse(email=exc.email).model_dump(),
        )
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc


@router.post("/refresh", response_model=TokenPair)
def refresh(
    request: Request,
    response: Response,
    payload: RefreshTokenRequest | None = Body(default=None),
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> TokenPair:
    refresh_token = (payload.refresh_token if payload else None) or request.cookies.get("phora_refresh")
    if not refresh_token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing refresh token")
    try:
        tokens = _service(db, settings).refresh(refresh_token)
    except PermissionError as exc:
        error_response = JSONResponse(
            status_code=status.HTTP_401_UNAUTHORIZED,
            content={"detail": str(exc)},
        )
        _clear_refresh_cookie(error_response, settings)
        return error_response
    _set_refresh_cookie(response, tokens["refresh_token"], settings)
    return TokenPair(**tokens)


@router.post("/signout", response_model=SignoutResponse)
def signout(
    response: Response,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> SignoutResponse:
    _service(db, settings).signout(user_id)
    _clear_refresh_cookie(response, settings)
    return SignoutResponse()


@router.post("/register/anonymous", response_model=AnonymousRegisterResponse, status_code=status.HTTP_201_CREATED)
def register_anonymous(
    request: Request,
    response: Response,
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> AnonymousRegisterResponse:
    _check_auth_rate_limit(request)
    try:
        tokens = _service(db, settings).register_anonymous()
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Registration failed") from exc
    db.commit()
    _set_refresh_cookie(response, tokens["refresh_token"], settings)
    return AnonymousRegisterResponse(
        access_token=tokens["access_token"],
        token_type=tokens["token_type"],
        recovery_phrase=tokens["recovery_phrase"],
    )


@router.post("/login/recovery-phrase", response_model=AnonymousLoginResponse)
def login_with_recovery_phrase(
    payload: RecoveryPhraseLoginRequest,
    request: Request,
    response: Response,
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> AnonymousLoginResponse:
    _check_auth_rate_limit(request)
    try:
        tokens = _service(db, settings).login_with_recovery_phrase(payload)
    except ValueError as exc:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    db.commit()
    _set_refresh_cookie(response, tokens["refresh_token"], settings)
    return AnonymousLoginResponse(access_token=tokens["access_token"], token_type=tokens["token_type"])


@router.post("/forgot-password", response_model=ForgotPasswordResponse)
def forgot_password(
    payload: ForgotPasswordRequest,
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> ForgotPasswordResponse:
    try:
        return _service(db, settings).start_password_reset(payload)
    except EmailDeliveryError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc


@router.post("/reset-password", response_model=ResetPasswordResponse)
def reset_password(
    payload: ResetPasswordRequest,
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> ResetPasswordResponse:
    try:
        return _service(db, settings).reset_password(payload)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.post("/change-password", response_model=ChangePasswordResponse)
def change_password(
    payload: ChangePasswordRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> ChangePasswordResponse:
    try:
        return _service(db, settings).change_password(user_id, payload)
    except PermissionError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc


@router.get("/mfa/totp/status", response_model=TOTPStatusResponse)
def totp_status(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> TOTPStatusResponse:
    try:
        return _service(db, settings).totp_status(user_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.post("/mfa/totp/setup/start", response_model=TOTPSetupStartResponse)
def totp_setup_start(
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> TOTPSetupStartResponse:
    try:
        return _service(db, settings).totp_setup_start(user_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc


@router.post("/mfa/totp/setup/verify", response_model=TOTPToggleResponse)
def totp_setup_verify(
    payload: TOTPCodeVerifyRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> TOTPToggleResponse:
    try:
        return _service(db, settings).totp_setup_verify(user_id, payload)
    except ValueError as exc:
        detail = str(exc)
        code = status.HTTP_404_NOT_FOUND if detail == "TOTP setup not started" else status.HTTP_401_UNAUTHORIZED
        raise HTTPException(status_code=code, detail=detail) from exc


@router.delete("/mfa/totp", response_model=TOTPToggleResponse)
def totp_disable(
    payload: TOTPCodeVerifyRequest,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
    settings=Depends(get_settings_dep),
) -> TOTPToggleResponse:
    try:
        return _service(db, settings).totp_disable(user_id, payload)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(exc)) from exc
