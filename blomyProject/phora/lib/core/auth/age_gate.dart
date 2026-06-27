const minimumRegistrationAgeYears = 16;

DateTime latestAllowedBirthDate({DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  return DateTime(
    today.year - minimumRegistrationAgeYears,
    today.month,
    today.day,
  );
}

bool isAtLeastMinimumRegistrationAge(DateTime birthDate, {DateTime? now}) {
  final selected = _dateOnly(birthDate);
  final latestAllowed = latestAllowedBirthDate(now: now);
  return !selected.isAfter(latestAllowed);
}

DateTime clampBirthDateToRegistrationAge(DateTime date, {DateTime? now}) {
  final latestAllowed = latestAllowedBirthDate(now: now);
  if (date.isAfter(latestAllowed)) {
    return latestAllowed;
  }
  return date;
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
