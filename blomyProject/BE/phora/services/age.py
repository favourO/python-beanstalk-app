from datetime import UTC, date, datetime


AGE_BAND_LABELS = {
    "A": "Adolescent",
    "B": "Prime reproductive",
    "C": "Advanced reproductive",
    "D": "Perimenopause-adjacent",
    "E": "Perimenopause / late reproductive",
}

POPULATION_PRIORS = {
    "A": {"mean_cycle_length": 30.2, "ovulation_probability": 0.80},
    "B": {"mean_cycle_length": 28.9, "ovulation_probability": 0.95},
    "C": {"mean_cycle_length": 28.1, "ovulation_probability": 0.90},
    "D": {"mean_cycle_length": 27.3, "ovulation_probability": 0.75},
    "E": {"mean_cycle_length": None, "ovulation_probability": 0.45},
}


def age_on_day(date_of_birth: date | None, on_date: date) -> int | None:
    if not date_of_birth:
        return None
    years = on_date.year - date_of_birth.year
    birthday_passed = (on_date.month, on_date.day) >= (date_of_birth.month, date_of_birth.day)
    return years if birthday_passed else years - 1


def derive_age_band(age: int | None) -> str | None:
    if age is None:
        return None
    if age < 20:
        return "A"
    if age < 35:
        return "B"
    if age < 40:
        return "C"
    if age < 45:
        return "D"
    return "E"


def age_band_label(age_band: str | None) -> str | None:
    return AGE_BAND_LABELS.get(age_band) if age_band else None


def should_activate_perimenopause_mode(
    age_band: str | None,
    cycle_variability_sigma: float | None,
    perimenopause_self_reported: bool = False,
    conditions: dict | None = None,
) -> tuple[bool, str | None]:
    conditions = conditions or {}
    if perimenopause_self_reported:
        return True, "self_reported"
    if conditions.get("perimenopause"):
        return True, "conditions"
    if age_band == "E":
        return True, "age_band"
    if age_band == "D" and (cycle_variability_sigma or 0) > 5:
        return True, "variability_triggered"
    return False, None


def build_age_context(age_band: str | None, perimenopause_mode_active: bool) -> str:
    if age_band == "E" or perimenopause_mode_active:
        return "Predictions are softened for higher cycle variability and possible skipped ovulation."
    if age_band == "D":
        return "Predictions relax temperature and LH thresholds to reflect perimenopause-adjacent variability."
    if age_band == "C":
        return "Predictions increase monitoring for shorter follicular phases and shifting ovulation timing."
    if age_band == "A":
        return "Predictions use wider priors because higher cycle variability is expected earlier after menarche."
    return "Predictions use the standard ensemble pathway calibrated to your age band."


def utcnow() -> datetime:
    return datetime.now(UTC)
