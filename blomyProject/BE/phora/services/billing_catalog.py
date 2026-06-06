from __future__ import annotations

import os
from dataclasses import dataclass
from decimal import Decimal

from phora.schemas.billing import BillingPlanOffer, BillingPlanOffersResponse, BillingPlanPriceOption

PLAN_TYPE_PAID = "STRIPE_LOCAL_PAID"
PLAN_TYPE_FREE = "AFRICA_FREE_LAUNCH"
PRICING_STRATEGY = "AFFORDABILITY_BASED"

_STRIPE_PRODUCT_IDS_LIVE = {
    "premium_plus": "prod_UHVBHeX529Udc0",
}
_STRIPE_PRODUCT_IDS_TEST = {
    "premium_plus": "prod_UHWvb0SEUJR4Hk",
}

_COUNTRY_ALIASES = {
    "UK": "GB",
    "GREATBRITAIN": "GB",
    "ENGLAND": "GB",
    "UNITEDKINGDOM": "GB",
    "USA": "US",
    "UNITEDSTATES": "US",
    "UNITEDSTATESOFAMERICA": "US",
    "CZECHREPUBLIC": "CZ",
    "CZECHIA": "CZ",
    "GERMANY": "DE",
    "FRANCE": "FR",
    "NETHERLANDS": "NL",
    "IRELAND": "IE",
    "SPAIN": "ES",
    "ITALY": "IT",
    "CANADA": "CA",
    "AUSTRALIA": "AU",
    "SWITZERLAND": "CH",
    "DENMARK": "DK",
    "NORWAY": "NO",
    "SWEDEN": "SE",
    "FINLAND": "FI",
    "ICELAND": "IS",
    "POLAND": "PL",
    "PORTUGAL": "PT",
    "GREECE": "GR",
    "CROATIA": "HR",
    "LITHUANIA": "LT",
    "LATVIA": "LV",
    "SLOVAKIA": "SK",
    "SLOVENIA": "SI",
    "INDIA": "IN",
    "BRAZIL": "BR",
    "MEXICO": "MX",
    "TURKEY": "TR",
    "TURKIYE": "TR",
    "INDONESIA": "ID",
    "PHILIPPINES": "PH",
    "THAILAND": "TH",
    "NIGERIA": "NG",
    "SOUTHAFRICA": "ZA",
    "GHANA": "GH",
    "KENYA": "KE",
    "ETHIOPIA": "ET",
    "TANZANIA": "TZ",
    "UGANDA": "UG",
}

_COUNTRY_NAMES = {
    "GB": "United Kingdom",
    "US": "United States",
    "CA": "Canada",
    "AU": "Australia",
    "CH": "Switzerland",
    "DK": "Denmark",
    "NO": "Norway",
    "SE": "Sweden",
    "FI": "Finland",
    "IS": "Iceland",
    "DE": "Germany",
    "FR": "France",
    "NL": "Netherlands",
    "IE": "Ireland",
    "ES": "Spain",
    "IT": "Italy",
    "CZ": "Czech Republic",
    "PL": "Poland",
    "PT": "Portugal",
    "GR": "Greece",
    "HR": "Croatia",
    "LT": "Lithuania",
    "LV": "Latvia",
    "SK": "Slovakia",
    "SI": "Slovenia",
    "IN": "India",
    "BR": "Brazil",
    "MX": "Mexico",
    "TR": "Turkey",
    "ID": "Indonesia",
    "PH": "Philippines",
    "TH": "Thailand",
}

_CURRENCY_SYMBOLS = {
    "AUD": "A$",
    "BRL": "R$",
    "CAD": "C$",
    "CHF": "CHF",
    "CZK": "Kc",
    "DKK": "kr",
    "EUR": "€",
    "GBP": "£",
    "IDR": "Rp",
    "INR": "₹",
    "MXN": "MX$",
    "NOK": "kr",
    "PHP": "₱",
    "PLN": "zł",
    "SEK": "kr",
    "THB": "฿",
    "TRY": "₺",
    "USD": "$",
}

_ZERO_DECIMAL_CURRENCIES = set()

_USD_TO_CURRENCY = {
    "USD": Decimal("1"),
    "GBP": Decimal("0.79"),
    "EUR": Decimal("0.92"),
    "CAD": Decimal("1.35"),
    "AUD": Decimal("1.50"),
    "CHF": Decimal("0.90"),
    "DKK": Decimal("6.86"),
    "NOK": Decimal("10.50"),
    "SEK": Decimal("10.40"),
    "CZK": Decimal("22.80"),
    "PLN": Decimal("4.00"),
    "INR": Decimal("83.00"),
    "BRL": Decimal("5.00"),
    "MXN": Decimal("17.00"),
    "TRY": Decimal("32.00"),
    "IDR": Decimal("16000"),
    "PHP": Decimal("56.00"),
    "THB": Decimal("36.00"),
}


@dataclass(frozen=True)
class FixedPrice:
    amount_minor: int
    display_amount: str
    stripe_price_id: str

    @property
    def display_amount_value(self) -> int:
        return self.amount_minor // 100 if self.amount_minor % 100 == 0 else self.amount_minor


@dataclass(frozen=True)
class CountryPricingProfile:
    country: str
    country_code: str
    currency: str
    pricing_tier: str
    primary_provider: str | None
    available_providers: tuple[str, ...]
    monthly: FixedPrice
    yearly: FixedPrice
    fallback_applied: bool = False
    fallback_reason: str | None = None

    @property
    def regional_subheadline(self) -> str:
        if self.fallback_applied:
            return f"Default pricing for {self.country}"
        return f"Local pricing for {self.country}"


_AFFORDABILITY_PRICES: dict[str, dict[str, str | int]] = {
    "GB": {"currency": "GBP", "tier": "TIER_1_PREMIUM", "month": 299, "year": 3500, "m": "price_1TaYVaGRl5Hb5DeyQDl1oONm", "y": "price_1TaYWVGRl5Hb5DeypepmhPgc"},
    "US": {"currency": "USD", "tier": "TIER_1_PREMIUM", "month": 299, "year": 3500, "m": "price_1TaYWVGRl5Hb5Deyl6kkG0zi", "y": "price_1TaYWVGRl5Hb5DeyfpOWtvDv"},
    "CA": {"currency": "CAD", "tier": "TIER_1_PREMIUM", "month": 399, "year": 4500, "m": "price_1TaYWVGRl5Hb5DeylVwzpJLj", "y": "price_1TaYWVGRl5Hb5DeyKKUwnxAJ"},
    "AU": {"currency": "AUD", "tier": "TIER_1_PREMIUM", "month": 499, "year": 5500, "m": "price_1TaYWXGRl5Hb5Dey0ibJRoAE", "y": "price_1TaYWuGRl5Hb5DeyN3cmBoiC"},
    "CH": {"currency": "CHF", "tier": "TIER_1_PREMIUM", "month": 299, "year": 3500, "m": "price_1TaYWtGRl5Hb5DeyCrNuF6Mp", "y": "price_1TaYWtGRl5Hb5DeyTfPvOFnq"},
    "DK": {"currency": "DKK", "tier": "TIER_1_PREMIUM", "month": 2200, "year": 26000, "m": "price_1TaYWtGRl5Hb5DeyPf2NpavY", "y": "price_1TaYWtGRl5Hb5DeyKbrCykZm"},
    "NO": {"currency": "NOK", "tier": "TIER_1_PREMIUM", "month": 3500, "year": 39900, "m": "price_1TaYWtGRl5Hb5DeyZk652dLE", "y": "price_1TaYXHGRl5Hb5Dey8d37mBp3"},
    "SE": {"currency": "SEK", "tier": "TIER_1_PREMIUM", "month": 3500, "year": 39900, "m": "price_1TaYXHGRl5Hb5DeyPjGnUIZp", "y": "price_1TaYXHGRl5Hb5DeylRMPUl7h"},
    "FI": {"currency": "EUR", "tier": "TIER_1_PREMIUM", "month": 299, "year": 3500, "m": "price_1TaYXHGRl5Hb5Dey1ytrnj4Q", "y": "price_1TaYXHGRl5Hb5DeyMhUPbOi3"},
    "IS": {"currency": "EUR", "tier": "TIER_1_PREMIUM", "month": 299, "year": 3500, "m": "price_1TaYXHGRl5Hb5Dey1ytrnj4Q", "y": "price_1TaYXHGRl5Hb5DeyMhUPbOi3"},
    "DE": {"currency": "EUR", "tier": "TIER_2_STANDARD", "month": 249, "year": 2900, "m": "price_1TaYXHGRl5Hb5Deylzups3z7", "y": "price_1TaYXcGRl5Hb5Dey5tNdSL7D"},
    "FR": {"currency": "EUR", "tier": "TIER_2_STANDARD", "month": 249, "year": 2900, "m": "price_1TaYXHGRl5Hb5Deylzups3z7", "y": "price_1TaYXcGRl5Hb5Dey5tNdSL7D"},
    "NL": {"currency": "EUR", "tier": "TIER_2_STANDARD", "month": 249, "year": 2900, "m": "price_1TaYXHGRl5Hb5Deylzups3z7", "y": "price_1TaYXcGRl5Hb5Dey5tNdSL7D"},
    "IE": {"currency": "EUR", "tier": "TIER_2_STANDARD", "month": 249, "year": 2900, "m": "price_1TaYXHGRl5Hb5Deylzups3z7", "y": "price_1TaYXcGRl5Hb5Dey5tNdSL7D"},
    "ES": {"currency": "EUR", "tier": "TIER_2_STANDARD", "month": 199, "year": 2300, "m": "price_1TaYXdGRl5Hb5DeyqvhSKxuv", "y": "price_1TaYXcGRl5Hb5Deyn1HARZah"},
    "IT": {"currency": "EUR", "tier": "TIER_2_STANDARD", "month": 199, "year": 2300, "m": "price_1TaYXdGRl5Hb5DeyqvhSKxuv", "y": "price_1TaYXcGRl5Hb5Deyn1HARZah"},
    "CZ": {"currency": "CZK", "tier": "TIER_3_VALUE", "month": 4900, "year": 59000, "m": "price_1TaYXcGRl5Hb5Deytk7gUTwL", "y": "price_1TaYXcGRl5Hb5DeyoBzWtRRc"},
    "PL": {"currency": "PLN", "tier": "TIER_3_VALUE", "month": 999, "year": 11900, "m": "price_1TaYXcGRl5Hb5Dey8MnRlL3C", "y": "price_1TaYXwGRl5Hb5Dey744NISA1"},
    "PT": {"currency": "EUR", "tier": "TIER_3_VALUE", "month": 149, "year": 1700, "m": "price_1TaYXwGRl5Hb5DeynwhkmXyv", "y": "price_1TaYXxGRl5Hb5Deyamj5U2zY"},
    "GR": {"currency": "EUR", "tier": "TIER_3_VALUE", "month": 149, "year": 1700, "m": "price_1TaYXwGRl5Hb5DeynwhkmXyv", "y": "price_1TaYXxGRl5Hb5Deyamj5U2zY"},
    "HR": {"currency": "EUR", "tier": "TIER_3_VALUE", "month": 149, "year": 1700, "m": "price_1TaYXwGRl5Hb5DeynwhkmXyv", "y": "price_1TaYXxGRl5Hb5Deyamj5U2zY"},
    "LT": {"currency": "EUR", "tier": "TIER_3_VALUE", "month": 149, "year": 1700, "m": "price_1TaYXwGRl5Hb5DeynwhkmXyv", "y": "price_1TaYXxGRl5Hb5Deyamj5U2zY"},
    "LV": {"currency": "EUR", "tier": "TIER_3_VALUE", "month": 149, "year": 1700, "m": "price_1TaYXwGRl5Hb5DeynwhkmXyv", "y": "price_1TaYXxGRl5Hb5Deyamj5U2zY"},
    "SK": {"currency": "EUR", "tier": "TIER_3_VALUE", "month": 149, "year": 1700, "m": "price_1TaYXwGRl5Hb5DeynwhkmXyv", "y": "price_1TaYXxGRl5Hb5Deyamj5U2zY"},
    "SI": {"currency": "EUR", "tier": "TIER_3_VALUE", "month": 149, "year": 1700, "m": "price_1TaYXwGRl5Hb5DeynwhkmXyv", "y": "price_1TaYXxGRl5Hb5Deyamj5U2zY"},
    "IN": {"currency": "INR", "tier": "TIER_4_GROWTH", "month": 9900, "year": 119900, "m": "price_1TaYXwGRl5Hb5DeymNEHmaaA", "y": "price_1TaYXwGRl5Hb5DeyKuAfBA20"},
    "BR": {"currency": "BRL", "tier": "TIER_4_GROWTH", "month": 990, "year": 11900, "m": "price_1TaYXwGRl5Hb5Dey42PzENKj", "y": "price_1TaYYHGRl5Hb5DeyFFJ30K71"},
    "MX": {"currency": "MXN", "tier": "TIER_4_GROWTH", "month": 4900, "year": 59000, "m": "price_1TaYYHGRl5Hb5DeyvzZtExX3", "y": "price_1TaYYHGRl5Hb5DeyeimcosuS"},
    "TR": {"currency": "TRY", "tier": "TIER_4_GROWTH", "month": 4999, "year": 59900, "m": "price_1TaYYHGRl5Hb5Dey4D70KdQb", "y": "price_1TaYYHGRl5Hb5DeykKxwuAa8"},
    "ID": {"currency": "IDR", "tier": "TIER_4_GROWTH", "month": 2900000, "year": 34900000, "m": "price_1TaYYHGRl5Hb5Dey9zuCZxRz", "y": "price_1TaYYUGRl5Hb5DeyVD90t0pw"},
    "PH": {"currency": "PHP", "tier": "TIER_4_GROWTH", "month": 9900, "year": 119900, "m": "price_1TaYYUGRl5Hb5DeyRxeoD2Nh", "y": "price_1TaYYUGRl5Hb5Deyt4Ofy1dK"},
    "TH": {"currency": "THB", "tier": "TIER_4_GROWTH", "month": 7900, "year": 94900, "m": "price_1TaYYUGRl5Hb5Dey9qB3Za9h", "y": "price_1TaYYUGRl5Hb5DeyklJMsgEM"},
}


def _use_test_stripe_catalog() -> bool:
    explicit = os.getenv("PHORA_STRIPE_CATALOG_MODE", "").strip().lower()
    if explicit in {"test", "live"}:
        return explicit == "test"

    stripe_secret = os.getenv("PHORA_STRIPE_SECRET_KEY", "").strip()
    stripe_publishable = os.getenv("PHORA_STRIPE_PUBLISHABLE_KEY", "").strip()
    if stripe_secret.startswith("sk_live_") or stripe_publishable.startswith("pk_live_"):
        return False
    if stripe_secret.startswith("sk_test_") or stripe_publishable.startswith("pk_test_"):
        return True

    environment = os.getenv("PHORA_ENVIRONMENT", "").lower()
    if environment in {"prod", "production", "live"}:
        return False
    return True


def _stripe_product_ids() -> dict[str, str]:
    return _STRIPE_PRODUCT_IDS_TEST if _use_test_stripe_catalog() else _STRIPE_PRODUCT_IDS_LIVE


def _normalize_country(value: str | None) -> str:
    if not value:
        return ""
    compact = "".join(char for char in value.upper().strip() if char.isalnum())
    if len(compact) == 2:
        return compact
    return _COUNTRY_ALIASES.get(compact, compact)


def _format_minor_amount(currency: str, minor_amount: int) -> str:
    symbol = _CURRENCY_SYMBOLS.get(currency, currency)
    if currency in _ZERO_DECIMAL_CURRENCIES:
        amount = f"{minor_amount:,}"
    else:
        whole = minor_amount // 100
        cents = minor_amount % 100
        if cents == 0:
            amount = f"{whole:,}"
        else:
            amount = f"{whole:,}.{cents:02d}"
    return f"{symbol}{amount}"


def _default_country_code() -> str:
    configured = _normalize_country(os.getenv("DEFAULT_PRICING_COUNTRY") or os.getenv("PHORA_DEFAULT_PRICING_COUNTRY", "GB"))
    return configured if configured in _AFFORDABILITY_PRICES else "GB"


def _price_id(raw_price_id: str, country_code: str, interval: str) -> str:
    env_name = f"PHORA_STRIPE_PRICE_{country_code}_{interval.upper()}"
    configured = os.getenv(env_name, "").strip()
    if configured:
        return configured
    if not raw_price_id:
        raise RuntimeError(
            f"No Stripe price configured for {country_code} {interval}. "
            f"Set {env_name} or add a price ID to the catalog."
        )
    return raw_price_id


def _profile_for_country(country: str | None, *, allow_fallback: bool = True) -> CountryPricingProfile:
    country_code = _normalize_country(country)
    fallback_applied = False
    fallback_reason = None
    local_enabled = (os.getenv("LOCAL_CURRENCY_PRICING_ENABLED") or os.getenv("PHORA_LOCAL_CURRENCY_PRICING_ENABLED", "true")).strip().lower()
    if local_enabled in {"0", "false", "no", "off"}:
        fallback_applied = country_code not in {"", _default_country_code()}
        fallback_reason = "local_currency_pricing_disabled" if fallback_applied else None
        country_code = _default_country_code()
    elif country_code not in _AFFORDABILITY_PRICES:
        if not allow_fallback:
            raise ValueError(f"Stripe pricing is not configured for {country or 'unknown country'}.")
        fallback_applied = True
        fallback_reason = "unsupported_country"
        country_code = _default_country_code()

    raw = _AFFORDABILITY_PRICES[country_code]
    currency = str(raw["currency"])
    month = int(raw["month"])
    year = int(raw["year"])
    profile = CountryPricingProfile(
        country=_COUNTRY_NAMES.get(country_code, country_code),
        country_code=country_code,
        currency=currency,
        pricing_tier=str(raw["tier"]),
        primary_provider="stripe",
        available_providers=("stripe",),
        monthly=FixedPrice(
            amount_minor=month,
            display_amount=_format_minor_amount(currency, month),
            stripe_price_id=_price_id(str(raw["m"]), country_code, "month"),
        ),
        yearly=FixedPrice(
            amount_minor=year,
            display_amount=_format_minor_amount(currency, year),
            stripe_price_id=_price_id(str(raw["y"]), country_code, "year"),
        ),
        fallback_applied=fallback_applied,
        fallback_reason=fallback_reason,
    )
    return profile


def _country_profile(country: str) -> CountryPricingProfile:
    return _profile_for_country(country)


def stripe_supported_country_codes() -> set[str]:
    return set(_AFFORDABILITY_PRICES)


def build_plan_offers(country: str, include_free: bool = True) -> BillingPlanOffersResponse:
    profile = _profile_for_country(country)
    currency_symbol = _CURRENCY_SYMBOLS.get(profile.currency, profile.currency)

    plans: list[BillingPlanOffer] = []
    if include_free:
        plans.append(
            BillingPlanOffer(
                id="free",
                name="Free",
                description="Basic cycle tracking",
                provider=None,
                provider_product_id=None,
                provider_price_id=None,
                price_minor=0,
                currency=profile.currency,
                currency_symbol=currency_symbol,
                display_price=f"{currency_symbol}0",
                billing_period="year",
                highlighted=False,
                cta_label="Current plan",
                features=[
                    "Calendar and period tracking",
                    "Manual logging and reminders",
                    "Basic cycle insights",
                ],
            )
        )

    price_options = [
        BillingPlanPriceOption(
            interval="month",
            provider_price_id=profile.monthly.stripe_price_id,
            price_minor=profile.monthly.amount_minor,
            display_price=profile.monthly.display_amount,
        ),
        BillingPlanPriceOption(
            interval="year",
            provider_price_id=profile.yearly.stripe_price_id,
            price_minor=profile.yearly.amount_minor,
            display_price=profile.yearly.display_amount,
        ),
    ]
    plans.append(
        BillingPlanOffer(
            id="premium_plus",
            name="Premium",
            description="Advanced insights and premium support",
            provider="stripe",
            provider_product_id=_stripe_product_ids()["premium_plus"],
            provider_price_id=profile.monthly.stripe_price_id,
            price_minor=profile.monthly.amount_minor,
            currency=profile.currency,
            currency_symbol=currency_symbol,
            display_price=profile.monthly.display_amount,
            billing_period="month",
            highlighted=True,
            badge="POPULAR",
            cta_label="Upgrade to Premium",
            features=[
                "Everything in Free",
                "Advanced cycle predictions",
                "Premium insights and reminders",
                "AI support features",
                "Priority experience",
            ],
            price_options=price_options,
        )
    )

    return BillingPlanOffersResponse(
        country=country.strip(),
        normalized_country=profile.country_code,
        supported=True,
        primary_provider="stripe",
        available_providers=["stripe"],
        currency=profile.currency,
        currency_symbol=currency_symbol,
        pricing_tier=profile.pricing_tier,
        pricing_strategy=PRICING_STRATEGY,
        plan_type=PLAN_TYPE_PAID,
        fallback_applied=profile.fallback_applied,
        fallback_reason=profile.fallback_reason,
        monthly={
            "amount": profile.monthly.display_amount_value,
            "amountMinor": profile.monthly.amount_minor,
            "displayAmount": profile.monthly.display_amount,
            "stripePriceId": profile.monthly.stripe_price_id,
        },
        yearly={
            "amount": profile.yearly.display_amount_value,
            "amountMinor": profile.yearly.amount_minor,
            "displayAmount": profile.yearly.display_amount,
            "stripePriceId": profile.yearly.stripe_price_id,
        },
        subheadline=profile.regional_subheadline,
        plans=plans,
    )


def resolve_stripe_price(country: str, plan_id: str, interval: str) -> dict[str, str | int | bool | None]:
    if plan_id != "premium_plus":
        raise ValueError("Only premium_plus is supported")
    if interval not in {"month", "year"}:
        raise ValueError("interval must be month or year")

    profile = _profile_for_country(country)
    selected = profile.monthly if interval == "month" else profile.yearly
    provider_product_id = _stripe_product_ids().get(plan_id)
    if not provider_product_id:
        raise ValueError(f"No Stripe product is configured for {plan_id}.")

    return {
        "country": profile.country_code,
        "country_name": profile.country,
        "currency": profile.currency,
        "provider": "stripe",
        "provider_product_id": provider_product_id,
        "provider_price_id": selected.stripe_price_id,
        "price_minor": selected.amount_minor,
        "display_price": selected.display_amount,
        "pricing_tier": profile.pricing_tier,
        "pricing_strategy": PRICING_STRATEGY,
        "fallback_applied": profile.fallback_applied,
        "fallback_reason": profile.fallback_reason,
    }


def resolve_billing_price(country: str, plan_id: str, interval: str) -> dict[str, str | int | bool | None]:
    if plan_id == "free":
        return {
            "country": country.strip(),
            "currency": None,
            "provider": None,
            "provider_product_id": None,
            "provider_price_id": None,
            "price_minor": 0,
            "display_price": "0",
            "pricing_tier": "FREE",
            "pricing_strategy": PRICING_STRATEGY,
            "fallback_applied": False,
            "fallback_reason": None,
        }
    return resolve_stripe_price(country, plan_id, interval)


def stripe_price_metadata(price_id: str) -> dict[str, str] | None:
    for country_code, raw in _AFFORDABILITY_PRICES.items():
        for interval, key in (("month", "m"), ("year", "y")):
            if _price_id(str(raw[key]), country_code, interval) == price_id:
                return {
                    "country": country_code,
                    "currency": str(raw["currency"]),
                    "plan_id": "premium_plus",
                    "interval": interval,
                    "pricing_tier": str(raw["tier"]),
                }
    return None
