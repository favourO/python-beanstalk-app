from __future__ import annotations

from dataclasses import dataclass

from fastapi import Request
from sqlalchemy.orm import Session

from phora.core.config import Settings
from phora.models.billing import BillingActivity, PricingEligibilityReviewLog, Subscription
from phora.models.user import UserProfile
from phora.services.billing_catalog import PLAN_TYPE_FREE, PLAN_TYPE_PAID

AFRICA_FREE_LAUNCH_PROVIDER = "africa_free_launch"
AFRICA_FREE_LAUNCH_PLAN_ID = "africa_free_launch_premium_plus"
AFRICA_FREE_LAUNCH_RULE = "africa_free_launch_promotion"

_COUNTRY_TO_ALPHA2 = {
    "ALGERIA": "DZ", "DZ": "DZ",
    "ANGOLA": "AO", "AO": "AO",
    "BENIN": "BJ", "BJ": "BJ",
    "BOTSWANA": "BW", "BW": "BW",
    "BURKINAFASO": "BF", "BF": "BF",
    "BURUNDI": "BI", "BI": "BI",
    "CABOVERDE": "CV", "CAPEVERDE": "CV", "CV": "CV",
    "CAMEROON": "CM", "CM": "CM",
    "CENTRALAFRICANREPUBLIC": "CF", "CF": "CF",
    "CHAD": "TD", "TD": "TD",
    "COMOROS": "KM", "KM": "KM",
    "CONGO": "CG", "REPUBLICOFTHECONGO": "CG", "CG": "CG",
    "DEMOCRATICREPUBLICOFTHECONGO": "CD", "DRC": "CD", "CONGOKINSHASA": "CD", "CD": "CD",
    "COTEDIVOIRE": "CI", "IVORYCOAST": "CI", "CI": "CI",
    "DJIBOUTI": "DJ", "DJ": "DJ",
    "EGYPT": "EG", "EG": "EG",
    "EQUATORIALGUINEA": "GQ", "GQ": "GQ",
    "ERITREA": "ER", "ER": "ER",
    "ESWATINI": "SZ", "SWAZILAND": "SZ", "SZ": "SZ",
    "ETHIOPIA": "ET", "ET": "ET",
    "GABON": "GA", "GA": "GA",
    "GAMBIA": "GM", "THEGAMBIA": "GM", "GM": "GM",
    "GHANA": "GH", "GH": "GH",
    "GUINEA": "GN", "GN": "GN",
    "GUINEABISSAU": "GW", "GW": "GW",
    "KENYA": "KE", "KE": "KE",
    "LESOTHO": "LS", "LS": "LS",
    "LIBERIA": "LR", "LR": "LR",
    "LIBYA": "LY", "LY": "LY",
    "MADAGASCAR": "MG", "MG": "MG",
    "MALAWI": "MW", "MW": "MW",
    "MALI": "ML", "ML": "ML",
    "MAURITANIA": "MR", "MR": "MR",
    "MAURITIUS": "MU", "MU": "MU",
    "MOROCCO": "MA", "MA": "MA",
    "MOZAMBIQUE": "MZ", "MZ": "MZ",
    "NAMIBIA": "NA", "NA": "NA",
    "NIGER": "NE", "NE": "NE",
    "NIGERIA": "NG", "NG": "NG",
    "RWANDA": "RW", "RW": "RW",
    "SAOTOMEANDPRINCIPE": "ST", "ST": "ST",
    "SENEGAL": "SN", "SN": "SN",
    "SEYCHELLES": "SC", "SC": "SC",
    "SIERRALEONE": "SL", "SL": "SL",
    "SOMALIA": "SO", "SO": "SO",
    "SOUTHAFRICA": "ZA", "ZA": "ZA",
    "SOUTHSUDAN": "SS", "SS": "SS",
    "SUDAN": "SD", "SD": "SD",
    "TANZANIA": "TZ", "UNITEDREPUBLICOFTANZANIA": "TZ", "TZ": "TZ",
    "TOGO": "TG", "TG": "TG",
    "TUNISIA": "TN", "TN": "TN",
    "UGANDA": "UG", "UG": "UG",
    "ZAMBIA": "ZM", "ZM": "ZM",
    "ZIMBABWE": "ZW", "ZW": "ZW",
    "UNITEDKINGDOM": "GB", "UK": "GB", "GREATBRITAIN": "GB", "GB": "GB",
    "UNITEDSTATES": "US", "UNITEDSTATESOFAMERICA": "US", "USA": "US", "US": "US",
    "GERMANY": "DE", "DE": "DE",
    "FRANCE": "FR", "FR": "FR",
    "CANADA": "CA", "CA": "CA",
    "AUSTRALIA": "AU", "AU": "AU",
    "SWITZERLAND": "CH", "CH": "CH",
    "DENMARK": "DK", "DK": "DK",
    "NORWAY": "NO", "NO": "NO",
    "SWEDEN": "SE", "SE": "SE",
    "FINLAND": "FI", "FI": "FI",
    "ICELAND": "IS", "IS": "IS",
    "NETHERLANDS": "NL", "NL": "NL",
    "IRELAND": "IE", "IE": "IE",
    "SPAIN": "ES", "ES": "ES",
    "ITALY": "IT", "IT": "IT",
    "CZECHREPUBLIC": "CZ", "CZECHIA": "CZ", "CZ": "CZ",
    "POLAND": "PL", "PL": "PL",
    "PORTUGAL": "PT", "PT": "PT",
    "GREECE": "GR", "GR": "GR",
    "CROATIA": "HR", "HR": "HR",
    "LITHUANIA": "LT", "LT": "LT",
    "LATVIA": "LV", "LV": "LV",
    "SLOVAKIA": "SK", "SK": "SK",
    "SLOVENIA": "SI", "SI": "SI",
    "INDIA": "IN", "IN": "IN",
    "BRAZIL": "BR", "BR": "BR",
    "MEXICO": "MX", "MX": "MX",
    "TURKEY": "TR", "TURKIYE": "TR", "TR": "TR",
    "INDONESIA": "ID", "ID": "ID",
    "PHILIPPINES": "PH", "PH": "PH",
    "THAILAND": "TH", "TH": "TH",
}

_PHONE_PREFIX_TO_COUNTRY = {
    "20": "EG", "211": "SS", "212": "MA", "213": "DZ", "216": "TN", "218": "LY",
    "220": "GM", "221": "SN", "222": "MR", "223": "ML", "224": "GN", "225": "CI",
    "226": "BF", "227": "NE", "228": "TG", "229": "BJ", "230": "MU", "231": "LR",
    "232": "SL", "233": "GH", "234": "NG", "235": "TD", "236": "CF", "237": "CM",
    "238": "CV", "239": "ST", "240": "GQ", "241": "GA", "242": "CG", "243": "CD",
    "244": "AO", "245": "GW", "248": "SC", "249": "SD", "250": "RW", "251": "ET",
    "252": "SO", "253": "DJ", "254": "KE", "255": "TZ", "256": "UG", "257": "BI",
    "258": "MZ", "260": "ZM", "261": "MG", "262": "RE", "263": "ZW", "264": "NA",
    "265": "MW", "266": "LS", "267": "BW", "268": "SZ", "269": "KM", "27": "ZA",
    "290": "SH", "291": "ER",
}


@dataclass(frozen=True)
class CountrySignal:
    source: str
    country_code: str
    ip_based: bool = False


@dataclass(frozen=True)
class PricingEligibilityDecision:
    is_free_region: bool
    requires_payment: bool
    country: str | None
    pricing_rule: str
    reason: str
    review_flagged: bool = False

    @property
    def free_launch_plan_id(self) -> str | None:
        return AFRICA_FREE_LAUNCH_PLAN_ID if self.is_free_region else None

    @property
    def plan_type(self) -> str:
        return PLAN_TYPE_FREE if self.is_free_region else PLAN_TYPE_PAID


def normalize_country_code(value: str | None) -> str | None:
    if not value:
        return None
    key = "".join(char for char in value.upper().strip() if char.isalnum())
    return _COUNTRY_TO_ALPHA2.get(key)


def phone_country_code(phone_number: str | None) -> str | None:
    if not phone_number:
        return None
    digits = "".join(char for char in phone_number if char.isdigit())
    if phone_number.strip().startswith("+"):
        for prefix in sorted(_PHONE_PREFIX_TO_COUNTRY, key=len, reverse=True):
            if digits.startswith(prefix):
                return _PHONE_PREFIX_TO_COUNTRY[prefix]
    return None


class PricingEligibilityService:
    def __init__(self, db: Session, settings: Settings):
        self.db = db
        self.settings = settings

    def evaluate(
        self,
        *,
        user_id: str | None = None,
        request: Request | None = None,
        country: str | None = None,
        device_locale_country: str | None = None,
        device_location_country: str | None = None,
        app_store_country: str | None = None,
        play_store_country: str | None = None,
        phone_number: str | None = None,
        billing_country: str | None = None,
        ip_country: str | None = None,
    ) -> PricingEligibilityDecision:
        if not self.settings.africa_free_launch_enabled:
            return PricingEligibilityDecision(
                is_free_region=False,
                requires_payment=True,
                country=normalize_country_code(country),
                pricing_rule="standard_paid_pricing",
                reason="feature_flag_disabled",
            )

        signals = self._collect_signals(
            user_id=user_id,
            request=request,
            country=country,
            device_locale_country=device_locale_country,
            device_location_country=device_location_country,
            app_store_country=app_store_country,
            play_store_country=play_store_country,
            phone_number=phone_number,
            billing_country=billing_country,
            ip_country=ip_country,
        )
        africa_codes = {code.upper() for code in self.settings.africa_free_launch_country_codes}
        non_ip_codes = {signal.country_code for signal in signals if not signal.ip_based}
        ip_codes = {signal.country_code for signal in signals if signal.ip_based}
        african_non_ip = non_ip_codes & africa_codes
        non_african_non_ip = non_ip_codes - africa_codes
        african_ip_only = not non_ip_codes and bool(ip_codes & africa_codes)
        mismatch = bool(african_non_ip and non_african_non_ip)
        ip_mismatch = bool(non_ip_codes and ip_codes and not ip_codes.issubset(non_ip_codes))
        resolved_country = self._resolved_country(signals, africa_codes=africa_codes)

        if mismatch:
            self._log_review(user_id, signals, resolved_country, "country_signal_mismatch")
            return PricingEligibilityDecision(
                is_free_region=False,
                requires_payment=True,
                country=resolved_country,
                pricing_rule="standard_paid_pricing",
                reason="country_signal_mismatch",
                review_flagged=True,
            )

        if african_ip_only:
            self._log_review(user_id, signals, resolved_country, "africa_ip_only")
            return PricingEligibilityDecision(
                is_free_region=False,
                requires_payment=True,
                country=resolved_country,
                pricing_rule="standard_paid_pricing",
                reason="ip_only_not_enough",
                review_flagged=True,
            )

        if african_non_ip:
            if ip_mismatch:
                self._log_review(user_id, signals, resolved_country, "ip_country_mismatch")
            return PricingEligibilityDecision(
                is_free_region=True,
                requires_payment=False,
                country=resolved_country,
                pricing_rule=AFRICA_FREE_LAUNCH_RULE,
                reason="africa_free_launch_region",
                review_flagged=ip_mismatch,
            )

        return PricingEligibilityDecision(
            is_free_region=False,
            requires_payment=True,
            country=resolved_country,
            pricing_rule="standard_paid_pricing",
            reason="not_africa_free_launch_region",
            review_flagged=ip_mismatch,
        )

    def log_pricing_fallback(
        self,
        *,
        user_id: str | None,
        resolved_country: str | None,
        reason: str,
    ) -> None:
        self.db.add(
            PricingEligibilityReviewLog(
                user_id=user_id,
                resolved_country=resolved_country if resolved_country and len(resolved_country) == 2 else None,
                reason=reason,
                signals={"pricing_fallback": True},
            )
        )
        self.db.commit()

    def grant_free_launch_access(
        self,
        *,
        user_id: str,
        country: str | None,
    ) -> Subscription:
        subscription = (
            self.db.query(Subscription)
            .filter(Subscription.user_id == user_id)
            .order_by(Subscription.created_at.desc())
            .first()
        )
        if not subscription:
            subscription = Subscription(user_id=user_id)
            self.db.add(subscription)

        subscription.tier = "premium_plus"
        subscription.status = "active"
        subscription.provider = AFRICA_FREE_LAUNCH_PROVIDER
        subscription.provider_subscription_id = None
        subscription.provider_customer_id = None
        subscription.provider_price_id = AFRICA_FREE_LAUNCH_PLAN_ID
        subscription.amount = 0.0
        subscription.currency = country
        subscription.billing_interval = None
        subscription.current_period_end = None
        subscription.cancel_at_period_end = False
        subscription.pending_billing_interval = None
        subscription.pending_provider_price_id = None
        subscription.pending_amount = None
        subscription.pending_currency = None
        subscription.pending_change_effective_at = None
        self.db.flush()

        existing_activity = (
            self.db.query(BillingActivity)
            .filter(
                BillingActivity.subscription_id == subscription.id,
                BillingActivity.event_type == "africa_free_launch_granted",
            )
            .first()
        )
        if not existing_activity:
            self.db.add(
                BillingActivity(
                    user_id=user_id,
                    subscription_id=subscription.id,
                    event_type="africa_free_launch_granted",
                    title="Free launch access granted",
                    subtitle="Africa free launch promotion",
                )
            )
        self.db.commit()
        return subscription

    def _collect_signals(
        self,
        *,
        user_id: str | None,
        request: Request | None,
        country: str | None,
        device_locale_country: str | None,
        device_location_country: str | None,
        app_store_country: str | None,
        play_store_country: str | None,
        phone_number: str | None,
        billing_country: str | None,
        ip_country: str | None,
    ) -> list[CountrySignal]:
        candidates: list[tuple[str, str | None, bool]] = [
            ("billing_country", billing_country, False),
            ("app_store_country", app_store_country, False),
            ("play_store_country", play_store_country, False),
            ("device_location_country", device_location_country, False),
            ("request_country", country, False),
            ("device_locale_country", device_locale_country, False),
            ("ip_country", ip_country, True),
        ]
        if request:
            candidates.extend(
                [
                    ("app_store_country_header", request.headers.get("x-app-store-country"), False),
                    ("play_store_country_header", request.headers.get("x-play-store-country"), False),
                    ("store_country_header", request.headers.get("x-vyla-store-country"), False),
                    ("cf_ipcountry_header", request.headers.get("cf-ipcountry"), True),
                    ("vercel_ip_country_header", request.headers.get("x-vercel-ip-country"), True),
                    ("cloudfront_country_header", request.headers.get("cloudfront-viewer-country"), True),
                ]
            )
        if user_id:
            profile = self.db.query(UserProfile).filter(UserProfile.user_id == user_id).one_or_none()
            if profile and isinstance(profile.conditions, dict):
                candidates.append(("profile_country", profile.conditions.get("country"), False))
                registration_context = profile.conditions.get("registration_context") or {}
                if isinstance(registration_context, dict):
                    candidates.append(("registration_app_store_country", registration_context.get("app_store_country"), False))
                    candidates.append(("registration_play_store_country", registration_context.get("play_store_country"), False))
                    phone_number = phone_number or registration_context.get("phone_number")

        signals: list[CountrySignal] = []
        seen: set[tuple[str, str]] = set()
        for source, value, ip_based in candidates:
            code = normalize_country_code(value)
            if code and (source, code) not in seen:
                seen.add((source, code))
                signals.append(CountrySignal(source=source, country_code=code, ip_based=ip_based))

        phone_prefix = phone_country_code(phone_number)
        if phone_prefix:
            signals.append(CountrySignal(source="phone_country_code", country_code=phone_prefix, ip_based=False))
        return signals

    def _resolved_country(self, signals: list[CountrySignal], *, africa_codes: set[str]) -> str | None:
        if not signals:
            return None
        priority = [
            "billing_country",
            "app_store_country",
            "play_store_country",
            "app_store_country_header",
            "play_store_country_header",
            "store_country_header",
            "phone_country_code",
            "profile_country",
            "registration_app_store_country",
            "registration_play_store_country",
            "request_country",
            "device_location_country",
            "device_locale_country",
            "ip_country",
            "cf_ipcountry_header",
            "vercel_ip_country_header",
            "cloudfront_country_header",
        ]
        by_source = {signal.source: signal.country_code for signal in signals}
        for source in priority:
            if source in by_source:
                return by_source[source]
        for signal in signals:
            if signal.country_code in africa_codes and not signal.ip_based:
                return signal.country_code
        return signals[0].country_code

    def _log_review(
        self,
        user_id: str | None,
        signals: list[CountrySignal],
        resolved_country: str | None,
        reason: str,
    ) -> None:
        self.db.add(
            PricingEligibilityReviewLog(
                user_id=user_id,
                resolved_country=resolved_country if resolved_country and len(resolved_country) == 2 else None,
                reason=reason,
                signals={
                    "countries": [
                        {"source": signal.source, "country": signal.country_code, "ip_based": signal.ip_based}
                        for signal in signals
                    ],
                },
            )
        )
        self.db.commit()
