from datetime import date

from phora.services.age import age_on_day, derive_age_band, should_activate_perimenopause_mode


def test_age_band_boundaries():
    assert derive_age_band(19) == "A"
    assert derive_age_band(20) == "B"
    assert derive_age_band(35) == "C"
    assert derive_age_band(40) == "D"
    assert derive_age_band(45) == "E"


def test_age_on_day_handles_birthday():
    assert age_on_day(date(1990, 4, 5), date(2026, 4, 4)) == 35
    assert age_on_day(date(1990, 4, 4), date(2026, 4, 4)) == 36


def test_perimenopause_activation_rules():
    assert should_activate_perimenopause_mode("E", None) == (True, "age_band")
    assert should_activate_perimenopause_mode("D", 6.0) == (True, "variability_triggered")
    assert should_activate_perimenopause_mode("B", None, perimenopause_self_reported=True) == (True, "self_reported")

