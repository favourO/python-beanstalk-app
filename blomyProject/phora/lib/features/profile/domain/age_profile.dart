class AgeProfile {
  const AgeProfile({
    this.dateOfBirth,
    this.ageBand,
    this.perimenopauseModeActive = false,
    this.perimenopauseModeSource,
    this.reproductiveStage,
  });

  final DateTime? dateOfBirth;
  final String? ageBand;
  final bool perimenopauseModeActive;
  final String? perimenopauseModeSource;
  final String? reproductiveStage;
}
