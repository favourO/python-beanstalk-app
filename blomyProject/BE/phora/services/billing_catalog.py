from __future__ import annotations

import os
from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP

from phora.schemas.billing import BillingPlanOffer, BillingPlanOffersResponse, BillingPlanPriceOption

_STRIPE_PRODUCT_IDS_LIVE = {
    "premium_plus": "prod_UHVBHeX529Udc0",
}

_STRIPE_PRICE_IDS_LIVE = {
    ("AED", "premium_plus", "month"): "price_1TKRXfGRl5Hb5Dey5TSMZZaf",
    ("AED", "premium_plus", "year"): "price_1TKRXfGRl5Hb5DeyWB6buS0a",
    ("AUD", "premium_plus", "month"): "price_1TKRUzGRl5Hb5DeyArocwSHB",
    ("AUD", "premium_plus", "year"): "price_1TKRUzGRl5Hb5Dey8z2SPfw6",
    ("BRL", "premium_plus", "month"): "price_1TKRV0GRl5Hb5DeyfV0dUIAa",
    ("BRL", "premium_plus", "year"): "price_1TKRV0GRl5Hb5DeyuEUcaC8p",
    ("CAD", "premium_plus", "month"): "price_1TKRXOGRl5Hb5Dey9U3jwMWB",
    ("CAD", "premium_plus", "year"): "price_1TKRXPGRl5Hb5Dey6UONxxjs",
    ("CHF", "premium_plus", "month"): "price_1TKRXVGRl5Hb5DeyNqg2BS38",
    ("CHF", "premium_plus", "year"): "price_1TKRXWGRl5Hb5DeyjfRbpjF9",
    ("CZK", "premium_plus", "month"): "price_1TKRXPGRl5Hb5DeyqEx2dNt9",
    ("CZK", "premium_plus", "year"): "price_1TKRXQGRl5Hb5DeyV7p1oxM4",
    ("DKK", "premium_plus", "month"): "price_1TKRXQGRl5Hb5DeyaGIadf0R",
    ("DKK", "premium_plus", "year"): "price_1TKRXQGRl5Hb5DeygLXaENsm",
    ("GBP", "premium_plus", "month"): os.getenv("PHORA_STRIPE_PREMIUM_GBP_MONTH_PRICE_ID", ""),
    ("EUR", "premium_plus", "month"): "price_1TKRQbGRl5Hb5DeytO3X0C7G",
    ("HKD", "premium_plus", "month"): "price_1TKRXRGRl5Hb5DeyRKiEaLoX",
    ("HKD", "premium_plus", "year"): "price_1TKRXRGRl5Hb5DeyQ3FrQpkO",
    ("HUF", "premium_plus", "month"): "price_1TKRXSGRl5Hb5DeyCITSbGjy",
    ("HUF", "premium_plus", "year"): "price_1TKRXSGRl5Hb5Deye60cyCO5",
    ("IDR", "premium_plus", "month"): "price_1TKRXUGRl5Hb5DeyxQ0R0fXL",
    ("IDR", "premium_plus", "year"): "price_1TKRXUGRl5Hb5Dey7m4huVoX",
    ("INR", "premium_plus", "month"): "price_1TKRXTGRl5Hb5DeysK1l4iaO",
    ("INR", "premium_plus", "year"): "price_1TKRXTGRl5Hb5DeyqILZgGFu",
    ("JPY", "premium_plus", "month"): "price_1TKRXUGRl5Hb5DeyogPCOzpg",
    ("JPY", "premium_plus", "year"): "price_1TKRXVGRl5Hb5DeyBQ1qO5bW",
    ("MXN", "premium_plus", "month"): "price_1TKRXXGRl5Hb5DeySaaGgYbc",
    ("MXN", "premium_plus", "year"): "price_1TKRXYGRl5Hb5DeyTb4QMfGO",
    ("MYR", "premium_plus", "month"): "price_1TKRXWGRl5Hb5DeydD6kxBX1",
    ("MYR", "premium_plus", "year"): "price_1TKRXXGRl5Hb5Dey4OaMyz3L",
    ("NOK", "premium_plus", "month"): "price_1TKRXZGRl5Hb5DeyRvTKDi8K",
    ("NOK", "premium_plus", "year"): "price_1TKRXZGRl5Hb5DeyRA0KCNps",
    ("NZD", "premium_plus", "month"): "price_1TKRXYGRl5Hb5Dey4lCC8v5w",
    ("NZD", "premium_plus", "year"): "price_1TKRXYGRl5Hb5Deyi9TRoe9n",
    ("PLN", "premium_plus", "month"): "price_1TKRXaGRl5Hb5DeyP1s9ceLZ",
    ("PLN", "premium_plus", "year"): "price_1TKRXaGRl5Hb5DeyD9oIfLeY",
    ("RON", "premium_plus", "month"): "price_1TKRXbGRl5Hb5Deyqr7QannJ",
    ("RON", "premium_plus", "year"): "price_1TKRXbGRl5Hb5DeyEP96wavs",
    ("SEK", "premium_plus", "month"): "price_1TKRXdGRl5Hb5DeycaPNxsmF",
    ("SEK", "premium_plus", "year"): "price_1TKRXdGRl5Hb5DeyQ44aV2WU",
    ("SGD", "premium_plus", "month"): "price_1TKRXcGRl5Hb5DeyQoY0q38A",
    ("SGD", "premium_plus", "year"): "price_1TKRXcGRl5Hb5Dey4yMhHSkO",
    ("THB", "premium_plus", "month"): "price_1TKRXeGRl5Hb5DeyNeiwU5dx",
    ("THB", "premium_plus", "year"): "price_1TKRXeGRl5Hb5DeyTzwYPUK1",
    ("USD", "premium_plus", "month"): "price_1TIwFOGRl5Hb5DeyGaYnuDP0",
    ("GBP", "premium_plus", "year"): os.getenv("PHORA_STRIPE_PREMIUM_GBP_YEAR_PRICE_ID", ""),
    ("EUR", "premium_plus", "year"): "price_1TKRQaGRl5Hb5DeysnoxMDOT",
    ("USD", "premium_plus", "year"): "price_1TIwFnGRl5Hb5Dey3nJzr4Dx",
}
_STRIPE_PRODUCT_IDS_TEST = {
    "premium_plus": "prod_UHWvb0SEUJR4Hk",
}

_STRIPE_PRICE_IDS_TEST = {
    ("AED", "premium_plus", "month"): "price_1TKzK1GRl5Hb5DeyCCDsaJHv",
    ("AED", "premium_plus", "year"): "price_1TKzK2GRl5Hb5DeyEx4B8zhU",
    ("AUD", "premium_plus", "month"): "price_1TKzK2GRl5Hb5DeyRhTGhxRI",
    ("AUD", "premium_plus", "year"): "price_1TKzK2GRl5Hb5DeyliwVZdMt",
    ("BRL", "premium_plus", "month"): "price_1TKzK3GRl5Hb5DeySdxQLB9s",
    ("BRL", "premium_plus", "year"): "price_1TKzK3GRl5Hb5Deyb2BSJylM",
    ("CAD", "premium_plus", "month"): "price_1TKzK3GRl5Hb5DeyAnBcbSNR",
    ("CAD", "premium_plus", "year"): "price_1TKzK4GRl5Hb5DeyKB33aNuj",
    ("CHF", "premium_plus", "month"): "price_1TKzK4GRl5Hb5DeyVPFxPu8Q",
    ("CHF", "premium_plus", "year"): "price_1TKzK4GRl5Hb5Dey9qhhL2sN",
    ("CZK", "premium_plus", "month"): "price_1TKz69GRl5Hb5DeyCXknTQ8p",
    ("CZK", "premium_plus", "year"): "price_1TKz69GRl5Hb5DeyFWY3R8qU",
    ("DKK", "premium_plus", "month"): "price_1TKzK5GRl5Hb5Dey1caYdrPN",
    ("DKK", "premium_plus", "year"): "price_1TKzK5GRl5Hb5Deyu0F41zII",
    ("GBP", "premium_plus", "month"): "price_1TTR20GRl5Hb5Deyw0zaAes6",
    ("USD", "premium_plus", "month"): "price_1TIxtDGRl5Hb5DeyaKYhDiIY",
    ("EUR", "premium_plus", "month"): "price_1TIxtDGRl5Hb5DeygKFNxDKV",
    ("HKD", "premium_plus", "month"): "price_1TKzK5GRl5Hb5DeyygygD5Jp",
    ("HKD", "premium_plus", "year"): "price_1TKzK6GRl5Hb5Dey1otZ3mQo",
    ("HUF", "premium_plus", "month"): "price_1TKzK6GRl5Hb5DeyVzUtISFO",
    ("HUF", "premium_plus", "year"): "price_1TKzK6GRl5Hb5DeyKg3gHB25",
    ("IDR", "premium_plus", "month"): "price_1TKzK7GRl5Hb5DeyvNeifarT",
    ("IDR", "premium_plus", "year"): "price_1TKzK7GRl5Hb5DeyReYxP0sr",
    ("INR", "premium_plus", "month"): "price_1TKzK7GRl5Hb5Dey9SThlVx7",
    ("INR", "premium_plus", "year"): "price_1TKzK8GRl5Hb5Dey9KC4HLWF",
    ("JPY", "premium_plus", "month"): "price_1TKzK8GRl5Hb5DeyrTv3nAHT",
    ("JPY", "premium_plus", "year"): "price_1TKzK8GRl5Hb5DeylR9sEJXC",
    ("MXN", "premium_plus", "month"): "price_1TKzK9GRl5Hb5Deyvm0od5dg",
    ("MXN", "premium_plus", "year"): "price_1TKzK9GRl5Hb5DeylNU7U942",
    ("MYR", "premium_plus", "month"): "price_1TKzK9GRl5Hb5DeyAUb0NJyo",
    ("MYR", "premium_plus", "year"): "price_1TKzKAGRl5Hb5DeynvvmqvFk",
    ("NOK", "premium_plus", "month"): "price_1TKzKAGRl5Hb5Dey651mesU5",
    ("NOK", "premium_plus", "year"): "price_1TKzKAGRl5Hb5Deyvx6nQTNr",
    ("NZD", "premium_plus", "month"): "price_1TKzKBGRl5Hb5DeyPbOTDO87",
    ("NZD", "premium_plus", "year"): "price_1TKzKBGRl5Hb5DeyjKFH6wO6",
    ("PLN", "premium_plus", "month"): "price_1TKzKBGRl5Hb5Dey7VXNoSHQ",
    ("PLN", "premium_plus", "year"): "price_1TKzKCGRl5Hb5DeyYgtvAzSc",
    ("RON", "premium_plus", "month"): "price_1TKzKCGRl5Hb5DeyLmboBsjU",
    ("RON", "premium_plus", "year"): "price_1TKzKDGRl5Hb5DeyuRg8MfPH",
    ("SEK", "premium_plus", "month"): "price_1TKzKDGRl5Hb5Deyoix6ILTA",
    ("SEK", "premium_plus", "year"): "price_1TKzKDGRl5Hb5Dey7hBbSDM7",
    ("SGD", "premium_plus", "month"): "price_1TKzKEGRl5Hb5Dey8pcdCZJn",
    ("SGD", "premium_plus", "year"): "price_1TKzKEGRl5Hb5DeywEfa24c2",
    ("THB", "premium_plus", "month"): "price_1TKzKEGRl5Hb5DeyKp7hVYRU",
    ("THB", "premium_plus", "year"): "price_1TKzKFGRl5Hb5DeyzcblGfID",
    ("GBP", "premium_plus", "year"): "price_1TTR20GRl5Hb5DeyR2UCLkOX",
    ("USD", "premium_plus", "year"): "price_1TIxtWGRl5Hb5DeyuUNpCmW4",
    ("EUR", "premium_plus", "year"): "price_1TIxtWGRl5Hb5DeyBjnF3y2e",
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

    return os.getenv("PHORA_ENVIRONMENT", "").lower() in {"stage", "staging", "dev"}


def _stripe_product_ids() -> dict[str, str]:
    return _STRIPE_PRODUCT_IDS_TEST if _use_test_stripe_catalog() else _STRIPE_PRODUCT_IDS_LIVE


def _stripe_price_ids() -> dict[tuple[str, str, str], str]:
    price_ids = dict(_STRIPE_PRICE_IDS_TEST if _use_test_stripe_catalog() else _STRIPE_PRICE_IDS_LIVE)
    if not _use_test_stripe_catalog():
        monthly_gbp = os.getenv("PHORA_STRIPE_PREMIUM_GBP_MONTH_PRICE_ID", "").strip()
        yearly_gbp = os.getenv("PHORA_STRIPE_PREMIUM_GBP_YEAR_PRICE_ID", "").strip()
        if monthly_gbp:
            price_ids[("GBP", "premium_plus", "month")] = monthly_gbp
        if yearly_gbp:
            price_ids[("GBP", "premium_plus", "year")] = yearly_gbp
    return price_ids


def _stripe_price_id(currency: str, plan_id: str, interval: str) -> str | None:
    return _stripe_price_ids().get((currency, plan_id, interval)) or None


def _stripe_price_id_lookup() -> dict[str, dict[str, str]]:
    return {
        price_id: {"currency": currency, "plan_id": plan_id, "interval": interval}
        for (currency, plan_id, interval), price_id in _stripe_price_ids().items()
        if price_id
    }


@dataclass(frozen=True)
class CountryPricingProfile:
    country: str
    currency: str
    primary_provider: str | None
    available_providers: tuple[str, ...]
    regional_subheadline: str


_CURRENCY_SYMBOLS = {
    "AED": "AED",
    "AUD": "A$",
    "BRL": "R$",
    "BGN": "лв",
    "CAD": "C$",
    "CHF": "CHF",
    "CZK": "Kc",
    "DKK": "kr",
    "EUR": "EUR",
    "GBP": "£",
    "GHS": "GH₵",
    "HKD": "HK$",
    "HUF": "Ft",
    "IDR": "Rp",
    "INR": "₹",
    "JPY": "¥",
    "KES": "KSh",
    "MAD": "MAD",
    "MWK": "MK",
    "MXN": "MX$",
    "MYR": "RM",
    "NGN": "₦",
    "NOK": "kr",
    "NZD": "NZ$",
    "PLN": "zł",
    "RON": "lei",
    "RWF": "FRw",
    "SEK": "kr",
    "SGD": "S$",
    "THB": "฿",
    "TZS": "TSh",
    "UGX": "USh",
    "USD": "$",
    "XAF": "FCFA",
    "XOF": "CFA",
    "ZAR": "R",
    "ZMW": "ZK",
}

_ZERO_DECIMAL_CURRENCIES = {"JPY", "RWF", "UGX", "XAF", "XOF"}
_BASE_STRIPE_PREMIUM_PLUS_USD = Decimal("4.99")
_BASE_FLUTTERWAVE_PREMIUM_PLUS_USD = Decimal("2")

# Static reference pricing rather than live FX. This keeps the mobile paywall
# deterministic across clients and easy to review with product.
_USD_TO_CURRENCY = {
    "AED": Decimal("3.67"),
    "AUD": Decimal("1.52"),
    "BRL": Decimal("5.05"),
    "BGN": Decimal("1.80"),
    "CAD": Decimal("1.36"),
    "CHF": Decimal("0.91"),
    "CZK": Decimal("23.00"),
    "DKK": Decimal("6.90"),
    "EUR": Decimal("0.92"),
    "GBP": Decimal("0.79"),
    "GHS": Decimal("14.50"),
    "HKD": Decimal("7.80"),
    "HUF": Decimal("360"),
    "IDR": Decimal("15800"),
    "INR": Decimal("83"),
    "JPY": Decimal("150"),
    "KES": Decimal("130"),
    "MAD": Decimal("9.90"),
    "MWK": Decimal("1730"),
    "MXN": Decimal("17.00"),
    "MYR": Decimal("4.70"),
    "NGN": Decimal("1500"),
    "NOK": Decimal("10.70"),
    "NZD": Decimal("1.64"),
    "PLN": Decimal("4.00"),
    "RON": Decimal("4.60"),
    "RWF": Decimal("1300"),
    "SEK": Decimal("10.60"),
    "SGD": Decimal("1.35"),
    "THB": Decimal("36.00"),
    "TZS": Decimal("2550"),
    "UGX": Decimal("3850"),
    "USD": Decimal("1.00"),
    "XAF": Decimal("600"),
    "XOF": Decimal("600"),
    "ZAR": Decimal("18.50"),
    "ZMW": Decimal("27.00"),
}

_PRICE_OVERRIDES_MINOR = {
    "GBP": {"premium_plus": 399},
    "USD": {"premium_plus": 499},
}

_YEARLY_PRICE_OVERRIDES_MINOR = {
    "GBP": {"premium_plus": 3500},
    "USD": {"premium_plus": 4000},
}

_PLAN_FEATURES = {
    "free": [
        "Calendar and period tracking",
        "Manual logging and reminders",
        "Basic cycle insights",
    ],
    "premium_plus": [
        "Everything in Free",
        "Advanced cycle predictions",
        "Premium insights and reminders",
        "AI support features",
        "Priority experience",
    ],
}

_STRIPE_COUNTRIES = {
    "AUSTRALIA": ("Australia", "AUD"),
    "AUSTRIA": ("Austria", "EUR"),
    "BELGIUM": ("Belgium", "EUR"),
    "BRAZIL": ("Brazil", "BRL"),
    "BULGARIA": ("Bulgaria", "EUR"),
    "CANADA": ("Canada", "CAD"),
    "CROATIA": ("Croatia", "EUR"),
    "CYPRUS": ("Cyprus", "EUR"),
    "CZECHREPUBLIC": ("Czech Republic", "CZK"),
    "DENMARK": ("Denmark", "DKK"),
    "ESTONIA": ("Estonia", "EUR"),
    "FINLAND": ("Finland", "EUR"),
    "FRANCE": ("France", "EUR"),
    "GERMANY": ("Germany", "EUR"),
    "GIBRALTAR": ("Gibraltar", "GBP"),
    "GREECE": ("Greece", "EUR"),
    "HONGKONG": ("Hong Kong", "HKD"),
    "HUNGARY": ("Hungary", "HUF"),
    "INDIA": ("India", "INR"),
    "INDONESIA": ("Indonesia", "IDR"),
    "IRELAND": ("Ireland", "EUR"),
    "ITALY": ("Italy", "EUR"),
    "JAPAN": ("Japan", "JPY"),
    "LATVIA": ("Latvia", "EUR"),
    "LIECHTENSTEIN": ("Liechtenstein", "CHF"),
    "LITHUANIA": ("Lithuania", "EUR"),
    "LUXEMBOURG": ("Luxembourg", "EUR"),
    "MALAYSIA": ("Malaysia", "MYR"),
    "MALTA": ("Malta", "EUR"),
    "MEXICO": ("Mexico", "MXN"),
    "NETHERLANDS": ("Netherlands", "EUR"),
    "NEWZEALAND": ("New Zealand", "NZD"),
    "NORWAY": ("Norway", "NOK"),
    "POLAND": ("Poland", "PLN"),
    "PORTUGAL": ("Portugal", "EUR"),
    "ROMANIA": ("Romania", "RON"),
    "SINGAPORE": ("Singapore", "SGD"),
    "SLOVAKIA": ("Slovakia", "EUR"),
    "SLOVENIA": ("Slovenia", "EUR"),
    "SPAIN": ("Spain", "EUR"),
    "SWEDEN": ("Sweden", "SEK"),
    "SWITZERLAND": ("Switzerland", "CHF"),
    "THAILAND": ("Thailand", "THB"),
    "UNITEDARABEMIRATES": ("United Arab Emirates", "AED"),
    "UNITEDKINGDOM": ("United Kingdom", "GBP"),
    "UNITEDSTATES": ("United States", "USD"),
}

_FLUTTERWAVE_PREFERRED_COUNTRIES = {
    "NIGERIA": ("Nigeria", "NGN"),
    "GHANA": ("Ghana", "GHS"),
    "KENYA": ("Kenya", "KES"),
    "SOUTHAFRICA": ("South Africa", "ZAR"),
    "UGANDA": ("Uganda", "UGX"),
    "TANZANIA": ("Tanzania", "TZS"),
    "RWANDA": ("Rwanda", "RWF"),
    "MALAWI": ("Malawi", "MWK"),
    "CAMEROON": ("Cameroon", "XAF"),
    "IVORYCOAST": ("Ivory Coast", "XOF"),
    "COTEDIVOIRE": ("Ivory Coast", "XOF"),
    "SENEGAL": ("Senegal", "XOF"),
    "ZAMBIA": ("Zambia", "ZMW"),
    "BENIN": ("Benin", "XOF"),
    "BURKINAFASO": ("Burkina Faso", "XOF"),
    "GUINEABISSAU": ("Guinea-Bissau", "XOF"),
    "MALI": ("Mali", "XOF"),
    "NIGER": ("Niger", "XOF"),
    "TOGO": ("Togo", "XOF"),
    "CENTRALAFRICANREPUBLIC": ("Central African Republic", "XAF"),
    "CHAD": ("Chad", "XAF"),
    "CONGO": ("Congo", "XAF"),
    "EQUATORIALGUINEA": ("Equatorial Guinea", "XAF"),
    "GABON": ("Gabon", "XAF"),
}

_COUNTRY_ALIASES = {
    "UK": "UNITEDKINGDOM",
    "GREATBRITAIN": "UNITEDKINGDOM",
    "ENGLAND": "UNITEDKINGDOM",
    "USA": "UNITEDSTATES",
    "UNITEDSTATESOFAMERICA": "UNITEDSTATES",
    "UAE": "UNITEDARABEMIRATES",
}


def _normalize_country(value: str) -> str:
    letters_only = "".join(char for char in value.upper().strip() if char.isalnum())
    return _COUNTRY_ALIASES.get(letters_only, letters_only)


def _format_minor_amount(currency: str, minor_amount: int) -> str:
    symbol = _CURRENCY_SYMBOLS.get(currency, currency)
    if currency in _ZERO_DECIMAL_CURRENCIES:
        amount = f"{minor_amount:,}"
    else:
        major = Decimal(minor_amount) / Decimal("100")
        if major == major.to_integral_value():
            amount = f"{int(major):,}"
        else:
            amount = f"{major:,.2f}"
    return f"{symbol}{amount}"


def _price_minor_for(profile: CountryPricingProfile, tier: str) -> int:
    override = _PRICE_OVERRIDES_MINOR.get(profile.currency, {}).get(tier)
    if override is not None:
        return override

    usd_amount = _BASE_FLUTTERWAVE_PREMIUM_PLUS_USD if profile.primary_provider == "flutterwave" else _BASE_STRIPE_PREMIUM_PLUS_USD

    rate = _USD_TO_CURRENCY.get(profile.currency, Decimal("1.0"))
    converted = usd_amount * rate
    if profile.currency in _ZERO_DECIMAL_CURRENCIES:
        return int(converted.quantize(Decimal("1"), rounding=ROUND_HALF_UP))
    return int((converted.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)) * 100)


def _yearly_price_minor(profile: CountryPricingProfile, tier: str) -> int:
    override = _YEARLY_PRICE_OVERRIDES_MINOR.get(profile.currency, {}).get(tier)
    if override is not None:
        return override

    usd_amount = Decimal("18") if profile.primary_provider == "flutterwave" else Decimal("40")
    rate = _USD_TO_CURRENCY.get(profile.currency, Decimal("1.0"))
    converted = usd_amount * rate
    if profile.currency in _ZERO_DECIMAL_CURRENCIES:
        return int(converted.quantize(Decimal("1"), rounding=ROUND_HALF_UP))
    return int((converted.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)) * 100)


def _country_profile(country: str) -> CountryPricingProfile:
    normalized = _normalize_country(country)

    if normalized in _FLUTTERWAVE_PREFERRED_COUNTRIES:
        display_country, currency = _FLUTTERWAVE_PREFERRED_COUNTRIES[normalized]
        return CountryPricingProfile(
            country=display_country,
            currency=currency,
            primary_provider="flutterwave",
            available_providers=("flutterwave",),
            regional_subheadline=f"Regional pricing for {display_country}",
        )

    if normalized in _STRIPE_COUNTRIES:
        display_country, currency = _STRIPE_COUNTRIES[normalized]
        return CountryPricingProfile(
            country=display_country,
            currency=currency if currency in _CURRENCY_SYMBOLS else "USD",
            primary_provider="stripe",
            available_providers=("stripe",),
            regional_subheadline=f"Local pricing for {display_country}",
        )

    return CountryPricingProfile(
        country=country.strip(),
        currency="USD",
        primary_provider=None,
        available_providers=(),
        regional_subheadline=f"Pricing is not yet localized for {country.strip()}",
    )


def build_plan_offers(country: str, include_free: bool = True) -> BillingPlanOffersResponse:
    profile = _country_profile(country)
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
                features=_PLAN_FEATURES["free"],
            )
        )

    for tier, name, description, highlighted, badge in (
        ("premium_plus", "Premium", "Advanced insights and premium support", True, "POPULAR"),
    ):
        price_minor = _price_minor_for(profile, tier)
        yearly_price_minor = _yearly_price_minor(profile, tier)
        price_options = [
            BillingPlanPriceOption(
                interval="month",
                provider_price_id=_stripe_price_id(profile.currency, tier, "month") if profile.primary_provider == "stripe" else None,
                price_minor=price_minor,
                display_price=_format_minor_amount(profile.currency, price_minor),
            ),
            BillingPlanPriceOption(
                interval="year",
                provider_price_id=_stripe_price_id(profile.currency, tier, "year") if profile.primary_provider == "stripe" else None,
                price_minor=yearly_price_minor,
                display_price=_format_minor_amount(profile.currency, yearly_price_minor),
            ),
        ]
        plans.append(
            BillingPlanOffer(
                id=tier,
                name=name,
                description=description,
                provider=profile.primary_provider,
                provider_product_id=_stripe_product_ids().get(tier) if profile.primary_provider == "stripe" else None,
                provider_price_id=price_options[0].provider_price_id,
                price_minor=price_minor,
                currency=profile.currency,
                currency_symbol=currency_symbol,
                display_price=price_options[0].display_price,
                billing_period="month",
                highlighted=highlighted,
                badge=badge,
                cta_label=f"Upgrade to {name}",
                features=_PLAN_FEATURES[tier],
                price_options=price_options,
            )
        )

    return BillingPlanOffersResponse(
        country=country.strip(),
        normalized_country=profile.country,
        supported=profile.primary_provider is not None,
        primary_provider=profile.primary_provider,
        available_providers=list(profile.available_providers),
        currency=profile.currency,
        currency_symbol=currency_symbol,
        subheadline=profile.regional_subheadline,
        plans=plans,
    )


def resolve_stripe_price(country: str, plan_id: str, interval: str) -> dict[str, str | int]:
    profile = _country_profile(country)
    if profile.primary_provider != "stripe":
        raise ValueError(f"Stripe billing is not available for {profile.country}.")

    provider_price_id = _stripe_price_id(profile.currency, plan_id, interval)
    if not provider_price_id:
        raise ValueError(f"No Stripe price is configured for {profile.country} {plan_id} ({interval}).")

    provider_product_id = _stripe_product_ids().get(plan_id)
    if not provider_product_id:
        raise ValueError(f"No Stripe product is configured for {plan_id}.")

    price_minor = _price_minor_for(profile, plan_id) if interval == "month" else _yearly_price_minor(profile, plan_id)
    return {
        "country": profile.country,
        "currency": profile.currency,
        "provider": profile.primary_provider,
        "provider_product_id": provider_product_id,
        "provider_price_id": provider_price_id,
        "price_minor": price_minor,
        "display_price": _format_minor_amount(profile.currency, price_minor),
    }


def resolve_billing_price(country: str, plan_id: str, interval: str) -> dict[str, str | int | None]:
    if plan_id == "free":
        return {
            "country": country.strip(),
            "currency": None,
            "provider": None,
            "provider_product_id": None,
            "provider_price_id": None,
            "price_minor": 0,
            "display_price": "0",
        }

    profile = _country_profile(country)
    if interval not in {"month", "year"}:
        raise ValueError("interval must be month or year")
    if plan_id != "premium_plus":
        raise ValueError("Only premium_plus is supported")

    price_minor = _price_minor_for(profile, plan_id) if interval == "month" else _yearly_price_minor(profile, plan_id)
    provider_price_id = _stripe_price_id(profile.currency, plan_id, interval) if profile.primary_provider == "stripe" else None
    if profile.primary_provider == "stripe" and provider_price_id is None:
        raise ValueError(f"No Stripe price is configured for {profile.country} {plan_id} ({interval}).")
    provider_product_id = _stripe_product_ids().get(plan_id) if profile.primary_provider == "stripe" else None
    return {
        "country": profile.country,
        "currency": profile.currency,
        "provider": profile.primary_provider,
        "provider_product_id": provider_product_id,
        "provider_price_id": provider_price_id,
        "price_minor": price_minor,
        "display_price": _format_minor_amount(profile.currency, price_minor),
    }


def stripe_price_metadata(price_id: str) -> dict[str, str] | None:
    metadata = _stripe_price_id_lookup().get(price_id)
    if not metadata:
        return None
    return dict(metadata)
