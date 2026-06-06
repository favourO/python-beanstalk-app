import 'package:flutter/material.dart';

@immutable
class AppColors {
  const AppColors({
    required this.bg,
    required this.bgElevated,
    required this.bgSurface,
    required this.bgCard,
    required this.border,                                                 
    required this.borderStrong,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textQuaternary,
    required this.accentPrimary,
    required this.accentSuccess,
    required this.accentWarning,
    required this.accentInfo,
    required this.accentDanger,
    required this.phaseMenstrual,
    required this.phaseFollicular,
    required this.phaseOvulatory,
    required this.phaseLuteal,
  });

  final Color bg;
  final Color bgElevated;
  final Color bgSurface;
  final Color bgCard;

  final Color border;
  final Color borderStrong;
  final Color divider;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textQuaternary;

  final Color accentPrimary;
  final Color accentSuccess;
  final Color accentWarning;
  final Color accentInfo;
  final Color accentDanger;

  final Color phaseMenstrual;
  final Color phaseFollicular;
  final Color phaseOvulatory;
  final Color phaseLuteal;

  AppColors lerp(AppColors other, double t) {
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      bgCard: Color.lerp(bgCard, other.bgCard, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textQuaternary: Color.lerp(textQuaternary, other.textQuaternary, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      accentSuccess: Color.lerp(accentSuccess, other.accentSuccess, t)!,
      accentWarning: Color.lerp(accentWarning, other.accentWarning, t)!,
      accentInfo: Color.lerp(accentInfo, other.accentInfo, t)!,
      accentDanger: Color.lerp(accentDanger, other.accentDanger, t)!,
      phaseMenstrual: Color.lerp(phaseMenstrual, other.phaseMenstrual, t)!,
      phaseFollicular: Color.lerp(phaseFollicular, other.phaseFollicular, t)!,
      phaseOvulatory: Color.lerp(phaseOvulatory, other.phaseOvulatory, t)!,
      phaseLuteal: Color.lerp(phaseLuteal, other.phaseLuteal, t)!,
    );
  }
}

@immutable
class AppGradients {
  const AppGradients({
    required this.menstrual,
    required this.follicular,
    required this.ovulatory,
    required this.luteal,
    required this.primary,
  });

  final List<Color> menstrual;
  final List<Color> follicular;
  final List<Color> ovulatory;
  final List<Color> luteal;
  final List<Color> primary;
}

abstract final class PhoraDesignTokens {
  static const lightColors = AppColors(
    bg: Color.fromARGB(255, 244, 239, 245),
    bgElevated: Color(0xFFFAFAFA),
    bgSurface: Color(0xFFF5F5F5),
    bgCard: Color(0xFFFFFFFF),
    border: Color(0xFFE5E5E5),
    borderStrong: Color(0xFFD4D4D8),
    divider: Color.fromRGBO(0, 0, 0, 0.06),
    textPrimary: Color(0xFF18181B),
    textSecondary: Color(0xFF52525B),
    textTertiary: Color(0xFF71717A),
    textQuaternary: Color(0xFFA1A1AA),
    accentPrimary: Color(0xFFDC2626),
    accentSuccess: Color(0xFF059669),
    accentWarning: Color(0xFFD97706),
    accentInfo: Color(0xFF2563EB),
    accentDanger: Color(0xFFDC2626),
    phaseMenstrual: Color(0xFFDC2626),
    phaseFollicular: Color(0xFF9333EA),
    phaseOvulatory: Color(0xFF0891B2),
    phaseLuteal: Color(0xFFD97706),
  );

  static const darkColors = AppColors(
    bg: Color(0xFF0F0F12),
    bgElevated: Color(0xFF18181C),
    bgSurface: Color(0xFF1F1F24),
    bgCard: Color(0xFF26262E),
    border: Color(0xFF2A2A34),
    borderStrong: Color(0xFF35353F),
    divider: Color.fromRGBO(255, 255, 255, 0.06),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFFA8A8B8),
    textTertiary: Color(0xFF6E6E7E),
    textQuaternary: Color(0xFF4A4A56),
    accentPrimary: Color(0xFFEF4D78),
    accentSuccess: Color(0xFF34D399),
    accentWarning: Color(0xFFFBBF24),
    accentInfo: Color(0xFF60A5FA),
    accentDanger: Color(0xFFF87171),
    phaseMenstrual: Color(0xFFEF4D78),
    phaseFollicular: Color(0xFFC084FC),
    phaseOvulatory: Color(0xFF22D3EE),
    phaseLuteal: Color(0xFFFBBF24),
  );

  static const lightGradients = AppGradients(
    menstrual: [Color(0xFFDC2626), Color(0xFF991B1B)],
    follicular: [Color(0xFF9333EA), Color(0xFF7E22CE)],
    ovulatory: [Color(0xFF0891B2), Color(0xFF0E7490)],
    luteal: [Color(0xFFD97706), Color(0xFFB45309)],
    primary: [Color(0xFFDC2626), Color(0xFF9333EA)],
  );

  static const darkGradients = AppGradients(
    menstrual: [Color(0xFFEF4D78), Color(0xFFDC2626)],
    follicular: [Color(0xFFC084FC), Color(0xFFA855F7)],
    ovulatory: [Color(0xFF22D3EE), Color(0xFF06B6D4)],
    luteal: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
    primary: [Color(0xFFEF4D78), Color(0xFFC084FC)],
  );
}
