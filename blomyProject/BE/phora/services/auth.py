import logging
import hashlib
import hmac
import base64
import random
import secrets
import struct
from urllib.parse import quote
from datetime import date, timedelta

from sqlalchemy import delete as sql_delete
from sqlalchemy.orm import Session

from phora.core.config import Settings
from phora.core.security import (
    create_token,
    decode_token_safe,
    hash_token,
    hash_password,
    make_unusable_password,
    new_ulid,
    verify_password,
)
from phora.models import EmailOtpCode, User, UserMFATOTP
from phora.models.notification import NotificationDevice
from phora.models.user import RefreshTokenSession
from phora.repositories.core import AuditRepository, OtpRepository, RefreshTokenRepository, TOTPRepository, UserRepository
from phora.schemas.auth import (
    AppleLoginRequest,
    AuthResponse,
    AuthUserResponse,
    ChangePasswordRequest,
    ChangePasswordResponse,
    FirebaseLoginRequest,
    ForgotPasswordRequest,
    ForgotPasswordResponse,
    GoogleLoginRequest,
    LoginRequest,
    ResetPasswordRequest,
    ResetPasswordResponse,
    ResendOtpRequest,
    SignupRequest,
    SignupResponse,
    SocialSignupMetadata,
    SocialProvider,
    TOTPCodeVerifyRequest,
    TOTPSetupStartResponse,
    TOTPStatusResponse,
    TOTPToggleResponse,
    VerifyRequest,
)
from phora.schemas.onboarding import OnboardingProgressPayload
from phora.services.age import utcnow
from phora.services.email import EmailDeliveryError, EmailService
from phora.services.email_reputation import is_blocked_signup_email
from phora.services.firebase_auth import verify_apple_id_token, verify_firebase_id_token, verify_google_id_token
from phora.services.premium_access import PremiumAccessService

logger = logging.getLogger(__name__)


class ConflictError(ValueError):
    pass


class InvalidAuthRequestError(ValueError):
    pass


class UnverifiedAccountError(Exception):
    def __init__(self, email: str):
        super().__init__(email)
        self.email = email


class AuthService:
    def __init__(self, db: Session, settings: Settings, email_service: EmailService):
        self.db = db
        self.settings = settings
        self.email_service = email_service
        self.users = UserRepository(db)
        self.otps = OtpRepository(db)
        self.totp = TOTPRepository(db)
        self.refresh_tokens = RefreshTokenRepository(db)
        self.audit = AuditRepository(db)

    def signup(self, payload: SignupRequest, locale: str = "en") -> SignupResponse:
        email = payload.email.lower().strip()
        self._require_signup_email_allowed(email)
        existing = self.users.by_email(email)
        if existing:
            raise ConflictError("Email already registered")

        user = User(email=email, password_hash=hash_password(payload.password), email_verified=False)
        self.db.add(user)
        self.db.flush()
        profile = self.users.ensure_profile(user.id)
        self._apply_registration_profile(
            profile,
            first_name=payload.first_name,
            last_name=payload.last_name,
            country=payload.country,
            account_type=payload.account_type,
            signup_method=payload.signup_method.value,
            consents=payload.consents.model_dump(mode="json") if payload.consents else None,
            registration_context=payload.registration_context,
            birth_date=payload.birth_date,
            overwrite=True,
        )

        code = self._issue_otp(user, email, purpose="signup_verification")
        try:
            self.email_service.send_signup_otp(email, code, locale=locale)
        except EmailDeliveryError:
            self.db.rollback()
            raise
        self.audit.log(
            user.id,
            "auth.signup_requested",
            {
                "email": email,
                "signup_method": payload.signup_method.value,
                "account_type": payload.account_type,
            },
        )
        self.db.commit()
        return SignupResponse(message="Verification code sent to email.")

    def verify(self, payload: VerifyRequest) -> AuthResponse:
        email = payload.email.lower().strip()
        user = self.users.by_email(email)
        if not user:
            raise ValueError("Account not found")

        otp = self.otps.latest_active(email, "signup_verification")
        if not otp:
            raise ValueError("No verification code found")
        expires_at = otp.expires_at if otp.expires_at.tzinfo else otp.expires_at.replace(tzinfo=utcnow().tzinfo)
        if expires_at < utcnow():
            raise ValueError("Verification code expired")
        if otp.code_hash != self._hash_code(payload.code.strip()):
            raise ValueError("Invalid verification code")

        otp.consumed_at = utcnow()
        user.email_verified = True
        self.audit.log(user.id, "auth.email_verified", {"email": email})
        self.db.commit()
        try:
            self.email_service.send_account_confirmed(email)
        except EmailDeliveryError:
            logger.warning("Account confirmation email failed", extra={"user_id": user.id})
        return self._auth_response(user, is_new_user=True)

    def login(self, payload: LoginRequest) -> AuthResponse:
        email = payload.email.lower().strip()
        user = self.users.by_email(email)
        if not user or not verify_password(payload.password, user.password_hash):
            raise ValueError("Invalid credentials")
        if not user.email_verified:
            code = self._issue_otp(user, email, purpose="signup_verification")
            try:
                self.email_service.send_signup_otp(email, code)
            except EmailDeliveryError:
                self.db.rollback()
                raise
            self.audit.log(user.id, "auth.login_resent_otp", {"email": email})
            self.db.commit()
            raise UnverifiedAccountError(email)
        self._require_valid_totp(user, payload.totp_code)
        return self._auth_response(user, is_new_user=user.profile.onboarding_completed_at is None if user.profile else True)

    def resend_otp(self, payload: ResendOtpRequest, locale: str = "en") -> SignupResponse:
        email = payload.email.lower().strip()
        user = self.users.by_email(email)
        if not user:
            return SignupResponse(message="If the account exists, a verification code was sent.")
        code = self._issue_otp(user, email, purpose=payload.purpose)
        try:
            if payload.purpose == "password_reset":
                self.email_service.send_password_reset_otp(email, code, locale=locale)
            else:
                self.email_service.send_signup_otp(email, code, locale=locale)
        except EmailDeliveryError:
            self.db.rollback()
            raise
        self.audit.log(user.id, "auth.otp_resent", {"email": email, "purpose": payload.purpose})
        self.db.commit()
        return SignupResponse(message="Verification code sent to email.")

    def social_login(self, payload: FirebaseLoginRequest) -> AuthResponse:
        try:
            decoded = verify_firebase_id_token(payload.id_token, self.settings)
        except ValueError as exc:
            raise ValueError(f"Invalid identity token: {exc}") from exc

        provider_id = (decoded.get("firebase") or {}).get("sign_in_provider")
        provider_map = {
            SocialProvider.google: "google.com",
            SocialProvider.facebook: "facebook.com",
            SocialProvider.apple: "apple.com",
        }
        expected_provider = provider_map.get(payload.provider)
        if expected_provider and provider_id != expected_provider:
            raise ValueError(f"Token provider mismatch. Expected {expected_provider}, got {provider_id or 'unknown'}.")
        if payload.signup_method and payload.signup_method.value != payload.provider.value:
            raise InvalidAuthRequestError("signup_method must match the social provider")

        return self._social_auth_response(
            decoded,
            created_via=f"{payload.provider.value}_firebase",
            totp_code=payload.totp_code,
            metadata=payload,
        )

    def google_login(self, payload: GoogleLoginRequest) -> AuthResponse:
        try:
            decoded = verify_google_id_token(payload.id_token, self.settings)
        except ValueError as exc:
            raise ValueError(f"Invalid Google identity token: {exc}") from exc

        email_verified = decoded.get("email_verified", True)
        if not email_verified:
            raise PermissionError("Google email is not verified.")
        if payload.signup_method and payload.signup_method.value != SocialProvider.google.value:
            raise InvalidAuthRequestError("signup_method must match the social provider")

        return self._social_auth_response(
            decoded,
            created_via="google",
            totp_code=payload.totp_code,
            metadata=payload,
            allow_existing=True,
            allow_create=False,
        )

    def google_signup(self, payload: GoogleLoginRequest) -> AuthResponse:
        try:
            decoded = verify_google_id_token(payload.id_token, self.settings)
        except ValueError as exc:
            raise ValueError(f"Invalid Google identity token: {exc}") from exc

        email_verified = decoded.get("email_verified", True)
        if not email_verified:
            raise PermissionError("Google email is not verified.")
        if payload.signup_method and payload.signup_method.value != SocialProvider.google.value:
            raise InvalidAuthRequestError("signup_method must match the social provider")

        return self._social_auth_response(
            decoded,
            created_via="google",
            totp_code=payload.totp_code,
            metadata=payload,
            allow_existing=False,
        )

    def apple_login(self, payload: AppleLoginRequest) -> AuthResponse:
        try:
            decoded = verify_apple_id_token(payload.id_token, self.settings)
        except ValueError as exc:
            raise ValueError(f"Invalid Apple identity token: {exc}") from exc

        email_verified = decoded.get("email_verified", True)
        if isinstance(email_verified, str):
            email_verified = email_verified.lower() == "true"
        if not email_verified:
            raise PermissionError("Apple email is not verified.")
        if payload.signup_method and payload.signup_method.value != SocialProvider.apple.value:
            raise InvalidAuthRequestError("signup_method must match the social provider")

        return self._social_auth_response(
            decoded,
            created_via="apple",
            totp_code=payload.totp_code,
            metadata=payload,
            allow_existing=True,
            allow_create=False,
        )

    def apple_signup(self, payload: AppleLoginRequest) -> AuthResponse:
        try:
            decoded = verify_apple_id_token(payload.id_token, self.settings)
        except ValueError as exc:
            raise ValueError(f"Invalid Apple identity token: {exc}") from exc

        email_verified = decoded.get("email_verified", True)
        if isinstance(email_verified, str):
            email_verified = email_verified.lower() == "true"
        if not email_verified:
            raise PermissionError("Apple email is not verified.")
        if payload.signup_method and payload.signup_method.value != SocialProvider.apple.value:
            raise InvalidAuthRequestError("signup_method must match the social provider")

        return self._social_auth_response(
            decoded,
            created_via="apple",
            totp_code=payload.totp_code,
            metadata=payload,
            allow_existing=False,
        )

    def start_password_reset(self, payload: ForgotPasswordRequest, locale: str = "en") -> ForgotPasswordResponse:
        email = payload.email.lower().strip()
        response = ForgotPasswordResponse()
        user = self.users.by_email(email)
        if not user:
            logger.info("Password reset requested for unknown email", extra={"email": email})
            return response

        last = self.otps.latest_active_for_user(user.id, "password_reset")
        if last:
            created_at = last.created_at if last.created_at.tzinfo else last.created_at.replace(tzinfo=utcnow().tzinfo)
            if (utcnow() - created_at).total_seconds() < 60:
                return response

        code = self._issue_otp(user, email, purpose="password_reset")
        try:
            self.email_service.send_password_reset_otp(email, code, locale=locale)
        except EmailDeliveryError:
            self.db.rollback()
            raise
        self.audit.log(user.id, "auth.password_reset_requested", {"email": email})
        self.db.commit()
        return response

    def reset_password(self, payload: ResetPasswordRequest) -> ResetPasswordResponse:
        email = payload.email.lower().strip()
        user = self.users.by_email(email)
        if not user:
            raise ValueError("Invalid reset code or email.")

        otp = self.otps.latest_active(email, "password_reset")
        if not otp:
            raise ValueError("Invalid reset code or email.")
        expires_at = otp.expires_at if otp.expires_at.tzinfo else otp.expires_at.replace(tzinfo=utcnow().tzinfo)
        if expires_at < utcnow():
            raise ValueError("Invalid reset code or email.")
        if otp.code_hash != self._hash_code(payload.code.strip()):
            raise ValueError("Invalid reset code or email.")

        otp.consumed_at = utcnow()
        user.password_hash = hash_password(payload.new_password)
        user.email_verified = True
        self.audit.log(user.id, "auth.password_reset_completed", {"email": email})
        self.db.commit()
        return ResetPasswordResponse()

    def send_set_password_otp(self, user_id: str, locale: str = "en") -> None:
        user = self._require_user(user_id)
        if not (not user.password_hash or user.password_hash.startswith("!phora-unusable-password$")):
            raise PermissionError("This account already has a password. Use Change Password instead.")

        last = self.otps.latest_active_for_user(user.id, "set_password")
        if last:
            created_at = last.created_at if last.created_at.tzinfo else last.created_at.replace(tzinfo=utcnow().tzinfo)
            if (utcnow() - created_at).total_seconds() < 60:
                return

        code = self._issue_otp(user, user.email, purpose="set_password")
        try:
            self.email_service.send_set_password_otp(user.email, code, locale=locale)
        except EmailDeliveryError:
            self.db.rollback()
            raise
        self.audit.log(user.id, "auth.set_password_otp_sent", {"email": user.email})
        self.db.commit()

    def set_password_with_otp(self, user_id: str, payload: "SetPasswordRequest") -> "SetPasswordResponse":
        from phora.schemas.auth import SetPasswordResponse

        user = self._require_user(user_id)
        if not (not user.password_hash or user.password_hash.startswith("!phora-unusable-password$")):
            raise PermissionError("This account already has a password. Use Change Password instead.")

        otp = self.otps.latest_active(user.email, "set_password")
        if not otp:
            raise ValueError("Invalid or expired verification code.")
        expires_at = otp.expires_at if otp.expires_at.tzinfo else otp.expires_at.replace(tzinfo=utcnow().tzinfo)
        if expires_at < utcnow():
            raise ValueError("Invalid or expired verification code.")
        if otp.code_hash != self._hash_code(payload.otp_code.strip()):
            raise ValueError("Invalid or expired verification code.")

        otp.consumed_at = utcnow()
        user.password_hash = hash_password(payload.new_password)
        user.email_verified = True
        self.audit.log(user.id, "auth.set_password_completed", {"email": user.email})
        self.db.commit()
        return SetPasswordResponse()

    def change_password(self, user_id: str, payload: ChangePasswordRequest) -> ChangePasswordResponse:
        user = self._require_user(user_id)
        if not verify_password(payload.current_password, user.password_hash):
            if not user.password_hash or user.password_hash.startswith("!phora-unusable-password$"):
                raise ValueError("This account does not have a password you can change here.")
            raise PermissionError("Current password is incorrect.")
        if payload.current_password == payload.new_password:
            raise ValueError("New password must be different from your current password.")

        user.password_hash = hash_password(payload.new_password)
        self.audit.log(user.id, "auth.password_changed", {"email": user.email})
        self.db.commit()
        return ChangePasswordResponse()

    def totp_status(self, user_id: str) -> TOTPStatusResponse:
        user = self._require_user(user_id)
        record = self.totp.by_user_id(user.id)
        if not record:
            return TOTPStatusResponse(configured=False, enabled=False, confirmed_at=None, last_used_at=None)
        return TOTPStatusResponse(
            configured=True,
            enabled=bool(record.is_enabled),
            confirmed_at=record.confirmed_at,
            last_used_at=record.last_used_at,
        )

    def totp_setup_start(self, user_id: str) -> TOTPSetupStartResponse:
        user = self._require_user(user_id)
        secret = self._generate_totp_secret()
        now = utcnow()
        record = self.totp.by_user_id(user.id)
        encrypted = self._encrypt_secret(secret)
        if record:
            record.secret_encrypted = encrypted
            record.is_enabled = False
            record.confirmed_at = None
            record.last_used_at = None
            record.updated_at = now
        else:
            record = UserMFATOTP(
                user_id=user.id,
                secret_encrypted=encrypted,
                is_enabled=False,
                confirmed_at=None,
                last_used_at=None,
                created_at=now,
                updated_at=now,
            )
        self.totp.save(record)
        self.audit.log(user.id, "auth.totp_setup_started", {"email": user.email})
        self.db.commit()
        return TOTPSetupStartResponse(
            message="Scan the QR/URI with Google Authenticator, then verify with a 6-digit code.",
            manual_entry_key=secret,
            otpauth_uri=self._build_totp_uri(secret, user.email),
        )

    def totp_setup_verify(self, user_id: str, payload: TOTPCodeVerifyRequest) -> TOTPToggleResponse:
        user = self._require_user(user_id)
        record = self.totp.by_user_id(user.id)
        if not record:
            raise ValueError("TOTP setup not started")
        secret = self._decrypt_secret(record.secret_encrypted)
        if not self._verify_totp(secret, payload.code):
            raise ValueError("Invalid or expired authenticator code")
        now = utcnow()
        record.is_enabled = True
        record.confirmed_at = now
        record.last_used_at = now
        record.updated_at = now
        self.totp.save(record)
        self.audit.log(user.id, "auth.totp_enabled", {"email": user.email})
        self.db.commit()
        return TOTPToggleResponse(message="Authenticator MFA enabled.", enabled=True)

    def totp_disable(self, user_id: str, payload: TOTPCodeVerifyRequest) -> TOTPToggleResponse:
        user = self._require_user(user_id)
        record = self.totp.by_user_id(user.id)
        if not record:
            return TOTPToggleResponse(message="TOTP MFA is already disabled.", enabled=False)
        secret = self._decrypt_secret(record.secret_encrypted)
        if not self._verify_totp(secret, payload.code):
            raise ValueError("Invalid or expired authenticator code")
        self.db.delete(record)
        self.audit.log(user.id, "auth.totp_disabled", {"email": user.email})
        self.db.commit()
        return TOTPToggleResponse(message="Authenticator MFA disabled.", enabled=False)

    def _auth_response(self, user: User, is_new_user: bool) -> AuthResponse:
        premium = PremiumAccessService(self.db).status(user.id)
        onboarding_completed = bool(user.profile and user.profile.onboarding_completed_at)
        draft = self.users.onboarding_progress(user.id)
        onboarding_current_step = None
        onboarding_progress = None
        if not onboarding_completed:
            onboarding_current_step = draft.current_step if draft and draft.current_step is not None else 1
            if draft and not draft.completed:
                onboarding_progress = OnboardingProgressPayload(
                    period_length=draft.period_length,
                    last_period_start=draft.last_period_start,
                    last_period_end=draft.last_period_end,
                    goal=draft.goal,
                    health_conditions=list(draft.health_conditions or []),
                )
        subscription_selected = premium.source != "free"
        subscription_active = premium.is_active
        show_subscription_screen = onboarding_completed and not subscription_selected
        tokens = self._issue_tokens(user)
        self.db.commit()
        return AuthResponse(
            access_token=tokens["access_token"],
            refresh_token=tokens["refresh_token"],
            user=self._user_response(user),
            is_new_user=is_new_user,
            show_premium_screen=show_subscription_screen,
            onboarding_completed=onboarding_completed,
            onboarding_current_step=onboarding_current_step,
            onboarding_progress=onboarding_progress,
            show_onboarding_flow=not onboarding_completed,
            subscription_selected=subscription_selected,
            show_subscription_screen=show_subscription_screen,
            subscription_tier=premium.tier,
            subscription_active=subscription_active,
            subscription_interval=premium.billing_interval,
        )

    def _issue_tokens(self, user: User) -> dict[str, str]:
        refresh_token = self._issue_refresh_token(user)
        return {
            "access_token": self._issue_access_token(user),
            "refresh_token": refresh_token,
            "token_type": "bearer",
        }

    def refresh(self, refresh_token: str) -> dict[str, str]:
        payload = decode_token_safe(refresh_token)
        if not payload or payload.get("type") != "refresh":
            raise PermissionError("Invalid refresh token")

        user_id = payload.get("sub")
        token_jti = payload.get("jti")
        family_id = payload.get("fam")
        if not user_id or not token_jti or not family_id:
            raise PermissionError("Invalid refresh token")

        user = self.users.by_id(user_id)
        if not user:
            raise PermissionError("Invalid refresh token")
        if payload.get("gen") != user.token_generation:
            raise PermissionError("Refresh token has been revoked")

        now = utcnow()
        token_hash = hash_token(refresh_token, self.settings.secret_key)
        record = self.refresh_tokens.by_hash(token_hash)
        if not record or record.token_jti != token_jti or record.family_id != family_id or record.user_id != user.id:
            raise PermissionError("Invalid refresh token")

        expires_at = record.expires_at if record.expires_at.tzinfo else record.expires_at.replace(tzinfo=now.tzinfo)
        if record.revoked_at is not None or record.used_at is not None or expires_at < now:
            self.refresh_tokens.revoke_family(record.family_id, now)
            user.token_generation += 1
            self.audit.log(user.id, "auth.refresh_reuse_detected", {"family_id": record.family_id})
            self.db.commit()
            raise PermissionError("Refresh token reuse detected")

        next_refresh_token = self._issue_refresh_token(user, family_id=record.family_id)
        next_payload = decode_token_safe(next_refresh_token) or {}
        record.used_at = now
        record.replaced_by_jti = next_payload.get("jti")
        self.audit.log(user.id, "auth.refresh_rotated", {"family_id": record.family_id})
        access_token = self._issue_access_token(user)
        if random.randint(1, 50) == 1:
            self.refresh_tokens.delete_expired(now)
        self.db.commit()
        return {
            "access_token": access_token,
            "refresh_token": next_refresh_token,
            "token_type": "bearer",
        }

    def _issue_refresh_token(self, user: User, family_id: str | None = None) -> str:
        token_jti = new_ulid()
        family = family_id or new_ulid()
        refresh_token = create_token(
            user.id,
            "refresh",
            self.settings.refresh_token_exp_minutes,
            user.token_generation,
            {"jti": token_jti, "fam": family},
        )
        self.refresh_tokens.create(
            RefreshTokenSession(
                user_id=user.id,
                family_id=family,
                token_jti=token_jti,
                token_hash=hash_token(refresh_token, self.settings.secret_key),
                expires_at=utcnow() + timedelta(minutes=self.settings.refresh_token_exp_minutes),
            )
        )
        return refresh_token

    def _issue_access_token(self, user: User) -> str:
        return create_token(
            user.id,
            "access",
            self.settings.access_token_exp_minutes,
            user.token_generation,
            {"jti": new_ulid()},
        )

    def _user_response(self, user: User) -> AuthUserResponse:
        profile = user.profile
        conditions = profile.conditions if profile else {}
        return AuthUserResponse(
            id=user.id,
            email=user.email or "anonymous@phora.invalid",
            first_name=conditions.get("first_name"),
            last_name=conditions.get("last_name"),
            country=conditions.get("country"),
            account_type=conditions.get("account_type"),
            email_verified=user.email_verified,
        )

    def _issue_otp(self, user: User, email: str, purpose: str) -> str:
        code = "".join(secrets.choice("0123456789") for _ in range(self.settings.otp_length))
        otp = EmailOtpCode(
            user_id=user.id,
            email=email,
            code_hash=self._hash_code(code),
            purpose=purpose,
            expires_at=utcnow() + timedelta(minutes=self.settings.otp_expiration_minutes),
        )
        self.otps.create(otp)
        return code

    def _social_auth_response(
        self,
        decoded: dict,
        created_via: str,
        totp_code: str | None,
        metadata: SocialSignupMetadata | None = None,
        *,
        allow_existing: bool = True,
        allow_create: bool = True,
    ) -> AuthResponse:
        email = (decoded.get("email") or "").strip().lower()
        if not email:
            raise ValueError("Identity token does not include an email address.")

        name = decoded.get("name") or ""
        given_name = decoded.get("given_name") or ""
        family_name = decoded.get("family_name") or ""
        inferred_first_name = (given_name or (name.split(" ")[0] if name else email.split("@")[0]) or "User").strip()
        inferred_last_name = (family_name or (name.split(" ")[-1] if name and " " in name else "")).strip()
        signup_method = metadata.signup_method.value if metadata and metadata.signup_method else created_via.split("_")[0]

        user = self.users.by_email(email)
        created_now = False
        if not user:
            if not allow_create:
                raise ValueError("Account not found. Please sign up first.")
            self._require_signup_email_allowed(email)
            if not metadata or not metadata.consents or not metadata.consents.accepted:
                raise InvalidAuthRequestError("terms_accepted and privacy_policy_accepted must both be true")
            if not metadata.country or not metadata.country.strip():
                raise InvalidAuthRequestError("country is required for social signup")
            user = User(email=email, password_hash=make_unusable_password(), email_verified=True)
            self.db.add(user)
            self.db.flush()
            profile = self.users.ensure_profile(user.id)
            self._apply_registration_profile(
                profile,
                first_name=metadata.first_name if metadata else inferred_first_name,
                last_name=metadata.last_name if metadata else inferred_last_name,
                country=metadata.country if metadata else None,
                account_type=metadata.account_type if metadata and metadata.account_type else "social",
                signup_method=signup_method,
                consents=metadata.consents.model_dump(mode="json") if metadata and metadata.consents else None,
                registration_context=metadata.registration_context if metadata else None,
                birth_date=metadata.birth_date if metadata else None,
                auth_provider=created_via,
                overwrite=True,
            )
            created_now = True
        else:
            if not allow_existing:
                raise ConflictError("Email already registered")
            profile = self.users.ensure_profile(user.id)
            self._apply_registration_profile(
                profile,
                first_name=metadata.first_name if metadata and metadata.first_name else inferred_first_name,
                last_name=metadata.last_name if metadata and metadata.last_name else inferred_last_name,
                country=metadata.country if metadata else None,
                account_type=metadata.account_type if metadata else None,
                signup_method=signup_method,
                consents=metadata.consents.model_dump(mode="json") if metadata and metadata.consents else None,
                registration_context=metadata.registration_context if metadata else None,
                birth_date=metadata.birth_date if metadata else None,
                auth_provider=created_via,
                overwrite=False,
            )
            if not user.email_verified:
                user.email_verified = True

        self._require_valid_totp(user, totp_code)

        self.audit.log(
            user.id,
            "auth.social_login",
            {"email": email, "provider": created_via, "created_now": created_now, "signup_method": signup_method},
        )
        self.db.commit()
        return self._auth_response(user, is_new_user=created_now)

    def _apply_registration_profile(
        self,
        profile,
        *,
        first_name: str | None,
        last_name: str | None,
        country: str | None = None,
        account_type: str | None = None,
        signup_method: str | None = None,
        consents: dict | None = None,
        registration_context: dict | None = None,
        birth_date: date | None = None,
        auth_provider: str | None = None,
        overwrite: bool,
    ) -> None:
        conditions = dict(profile.conditions or {})
        updates = {
            "first_name": self._clean_text(first_name),
            "last_name": self._clean_text(last_name),
            "country": self._clean_text(country),
            "account_type": self._clean_text(account_type),
            "signup_method": self._clean_text(signup_method),
            "auth_provider": self._clean_text(auth_provider),
        }
        for key, value in updates.items():
            if value is None:
                continue
            if overwrite or not conditions.get(key):
                conditions[key] = value

        if consents is not None and (overwrite or "consents" not in conditions):
            conditions["consents"] = consents
        if registration_context and (overwrite or "registration_context" not in conditions):
            conditions["registration_context"] = registration_context

        profile.conditions = conditions
        full_name = f"{conditions.get('first_name') or ''} {conditions.get('last_name') or ''}".strip()
        if full_name and (overwrite or not profile.full_name):
            profile.full_name = full_name
        if birth_date is not None and (overwrite or profile.date_of_birth is None):
            profile.date_of_birth = birth_date

    def _require_signup_email_allowed(self, email: str) -> None:
        if is_blocked_signup_email(email, self.settings.blocked_signup_email_domains):
            raise InvalidAuthRequestError("Temporary or disposable email addresses are not allowed.")

    @staticmethod
    def _clean_text(value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        return cleaned or None

    def _hash_code(self, code: str) -> str:
        return hashlib.sha256(f"{self.settings.secret_key}:{code}".encode("utf-8")).hexdigest()

    def _require_user(self, user_id: str) -> User:
        user = self.users.by_id(user_id)
        if not user:
            raise ValueError("User not found")
        return user

    def signout(self, user_id: str) -> None:
        user = self._require_user(user_id)
        user.token_generation += 1
        self.refresh_tokens.revoke_all_for_user(user.id, utcnow())
        self.audit.log(user.id, "auth.signed_out", {"email": user.email})
        self.db.commit()

    def request_delete_account_otp(self, user_id: str, locale: str = "en") -> None:
        user = self._require_user(user_id)
        if not user.email:
            raise ValueError("Email address required")
        code = self._issue_otp(user, user.email, purpose="account_deletion")
        try:
            self.email_service.send_account_deletion_otp(user.email, code, locale=locale)
        except EmailDeliveryError:
            self.db.rollback()
            raise
        self.audit.log(user.id, "account.delete_otp_requested", {"email": user.email})
        self.db.commit()

    def delete_account(self, user_id: str, otp_code: str) -> None:
        """
        Anonymise all PII and mark the account as deleted.

        Health data (cycle logs, sensor readings, predictions) is retained in
        de-identified form for ML quality and legal/audit purposes — following
        the Flo / Natural Cycles model and GDPR Art. 17(3)(b) exemption for
        scientific research purposes. All direct identifiers are removed.
        """
        user = self._require_user(user_id)
        if not user.email:
            raise ValueError("Email address required")
        otp = self.otps.latest_active(user.email, "account_deletion")
        if not otp:
            raise ValueError("No confirmation code found")
        expires_at = otp.expires_at if otp.expires_at.tzinfo else otp.expires_at.replace(tzinfo=utcnow().tzinfo)
        if expires_at < utcnow():
            raise ValueError("Confirmation code expired")
        if otp.code_hash != self._hash_code(otp_code.strip()):
            raise ValueError("Invalid confirmation code")
        otp.consumed_at = utcnow()
        now = utcnow()

        # --- revoke all sessions ---
        user.token_generation += 1
        self.refresh_tokens.revoke_all_for_user(user.id, now)

        # --- anonymise User row ---
        user.email = f"deleted-{user.id}@deleted.vyla.health"
        user.password_hash = secrets.token_hex(64)  # unguessable, login impossible
        user.deleted_at = now

        # --- anonymise UserProfile (remove all direct identifiers) ---
        profile = self.users.ensure_profile(user.id)
        profile.full_name = None
        profile.date_of_birth = None
        profile.height_cm = None
        profile.weight_kg = None
        profile.bmi = None

        # --- purge OTP codes (contain plaintext emails) ---
        self.db.execute(sql_delete(EmailOtpCode).where(EmailOtpCode.user_id == user.id))

        # --- purge device tokens (FCM tokens are device identifiers) ---
        self.db.execute(sql_delete(NotificationDevice).where(NotificationDevice.user_id == user.id))

        # --- purge TOTP secret ---
        totp = self.totp.by_user_id(user.id)
        if totp:
            self.db.delete(totp)

        self.audit.log(user.id, "account.deleted", {"account_mode": user.account_mode})
        self.db.commit()

    def _require_valid_totp(self, user: User, code: str | None) -> None:
        record = self.totp.by_user_id(user.id)
        if not record or not record.is_enabled:
            return
        if not code:
            raise PermissionError("TOTP code required")
        secret = self._decrypt_secret(record.secret_encrypted)
        if not self._verify_totp(secret, code):
            raise ValueError("Invalid or expired authenticator code")
        record.last_used_at = utcnow()
        record.updated_at = utcnow()
        self.totp.save(record)

    @staticmethod
    def _generate_totp_secret() -> str:
        return base64.b32encode(secrets.token_bytes(20)).decode("ascii").rstrip("=")

    @staticmethod
    def _normalize_totp_secret(secret: str) -> bytes:
        normalized = secret.strip().replace(" ", "").upper()
        padding = "=" * ((8 - len(normalized) % 8) % 8)
        return base64.b32decode(normalized + padding, casefold=True)

    @staticmethod
    def _totp_code(secret: str, for_time: int, period: int = 30, digits: int = 6) -> str:
        counter = int(for_time // period)
        key = AuthService._normalize_totp_secret(secret)
        msg = struct.pack(">Q", counter)
        digest = hmac.new(key, msg, hashlib.sha1).digest()
        offset = digest[-1] & 0x0F
        binary = struct.unpack(">I", digest[offset : offset + 4])[0] & 0x7FFFFFFF
        code = binary % (10**digits)
        return f"{code:0{digits}d}"

    @staticmethod
    def _verify_totp(secret: str, code: str, window: int = 1, period: int = 30) -> bool:
        code_norm = "".join(ch for ch in code if ch.isdigit())
        if len(code_norm) != 6:
            return False
        now = int(utcnow().timestamp())
        for step in range(-window, window + 1):
            if AuthService._totp_code(secret, now + (step * period), period=period) == code_norm:
                return True
        return False

    @staticmethod
    def _build_totp_uri(secret: str, email: str, issuer: str = "Vyla") -> str:
        label = f"{quote(issuer)}:{quote(email)}"
        return f"otpauth://totp/{label}?secret={secret}&issuer={quote(issuer)}&algorithm=SHA1&digits=6&period=30"

    def _encrypt_secret(self, secret: str) -> str:
        secret_bytes = secret.encode("utf-8")
        key_bytes = self.settings.secret_key.encode("utf-8")
        keystream = bytearray()
        counter = 0
        while len(keystream) < len(secret_bytes):
            block = hashlib.sha256(key_bytes + b":" + str(counter).encode("utf-8")).digest()
            keystream.extend(block)
            counter += 1
        encrypted = bytes(a ^ b for a, b in zip(secret_bytes, keystream))
        return base64.urlsafe_b64encode(encrypted).decode("ascii")

    def _decrypt_secret(self, secret_encrypted: str) -> str:
        encrypted = base64.urlsafe_b64decode(secret_encrypted.encode("ascii"))
        key_bytes = self.settings.secret_key.encode("utf-8")
        keystream = bytearray()
        counter = 0
        while len(keystream) < len(encrypted):
            block = hashlib.sha256(key_bytes + b":" + str(counter).encode("utf-8")).digest()
            keystream.extend(block)
            counter += 1
        decrypted = bytes(a ^ b for a, b in zip(encrypted, keystream))
        return decrypted.decode("utf-8")
