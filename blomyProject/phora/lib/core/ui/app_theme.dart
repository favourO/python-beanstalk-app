import 'package:phora/core/ui/design_tokens.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:flutter/material.dart';

@immutable
class PhoraThemeTokens extends ThemeExtension<PhoraThemeTokens> {
  const PhoraThemeTokens({required this.colors, required this.gradients});

  final AppColors colors;
  final AppGradients gradients;

  @override
  PhoraThemeTokens copyWith({AppColors? colors, AppGradients? gradients}) {
    return PhoraThemeTokens(
      colors: colors ?? this.colors,
      gradients: gradients ?? this.gradients,
    );
  }

  @override
  PhoraThemeTokens lerp(ThemeExtension<PhoraThemeTokens>? other, double t) {
    if (other is! PhoraThemeTokens) {
      return this;
    }

    return PhoraThemeTokens(
      colors: colors.lerp(other.colors, t),
      gradients: t < 0.5 ? gradients : other.gradients,
    );
  }
}

abstract final class AppTheme {
  static const headingFontFamily = 'Plus Jakarta Sans';
  static const bodyFontFamily = 'Inter';
  static const monoFontFamily = 'DM Mono';

  static TextStyle? screenHeaderStyle(
    BuildContext context,
    AppDimensions dims, {
    Color? color,
  }) {
    return Theme.of(context).textTheme.displaySmall?.copyWith(
      fontSize: dims.scaleText(32),
      height: 1,
      fontFamily: 'Georgia',
      fontWeight: FontWeight.w500,
      color: color,
    );
  }

  static ThemeData light() {
    return _build(
      brightness: Brightness.light,
      colors: PhoraDesignTokens.lightColors,
      gradients: PhoraDesignTokens.lightGradients,
    );
  }

  static ThemeData dark() {
    return _build(
      brightness: Brightness.dark,
      colors: PhoraDesignTokens.darkColors,
      gradients: PhoraDesignTokens.darkGradients,
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required AppColors colors,
    required AppGradients gradients,
  }) {
    final isLight = brightness == Brightness.light;
    final primaryButtonColor =
        isLight ? const Color(0xFFF58F93) : const Color(0xFFE67884);
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primaryButtonColor,
      onPrimary: Colors.white,
      secondary: colors.phaseFollicular,
      onSecondary: Colors.white,
      error: colors.accentDanger,
      onError: Colors.white,
      surface: colors.bgCard,
      onSurface: colors.textPrimary,
      surfaceContainerHighest: colors.bgElevated,
      outline: colors.border,
      outlineVariant: colors.borderStrong,
      tertiary: colors.phaseOvulatory,
      onTertiary: Colors.white,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: colors.bgSurface,
      onInverseSurface: colors.textPrimary,
      inversePrimary: primaryButtonColor,
    );

    final baseTextTheme =
        brightness == Brightness.dark
            ? Typography.material2021(platform: TargetPlatform.iOS).white
            : Typography.material2021(platform: TargetPlatform.iOS).black;

    final interTextTheme = baseTextTheme.apply(
      fontFamily: bodyFontFamily,
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    );

    final textTheme = interTextTheme.copyWith(
      displayLarge: interTextTheme.displayLarge?.copyWith(
        fontFamily: headingFontFamily,
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: interTextTheme.displayMedium?.copyWith(
        fontFamily: headingFontFamily,
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: interTextTheme.displaySmall?.copyWith(
        fontFamily: headingFontFamily,
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: interTextTheme.headlineLarge?.copyWith(
        fontFamily: headingFontFamily,
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: interTextTheme.headlineMedium?.copyWith(
        fontFamily: headingFontFamily,
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: interTextTheme.headlineSmall?.copyWith(
        fontFamily: headingFontFamily,
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: interTextTheme.titleLarge?.copyWith(
        fontFamily: headingFontFamily,
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: interTextTheme.titleMedium?.copyWith(
        fontFamily: headingFontFamily,
        color: colors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: interTextTheme.titleSmall?.copyWith(
        fontFamily: headingFontFamily,
        color: colors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: interTextTheme.bodyLarge?.copyWith(
        fontFamily: bodyFontFamily,
        color: colors.textSecondary,
        height: 1.5,
      ),
      bodyMedium: interTextTheme.bodyMedium?.copyWith(
        fontFamily: bodyFontFamily,
        color: colors.textSecondary,
        height: 1.5,
      ),
      bodySmall: interTextTheme.bodySmall?.copyWith(
        fontFamily: bodyFontFamily,
        color: colors.textTertiary,
        height: 1.45,
      ),
      labelLarge: interTextTheme.labelLarge?.copyWith(
        fontFamily: bodyFontFamily,
        color: colors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: interTextTheme.labelMedium?.copyWith(
        fontFamily: bodyFontFamily,
        color: colors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: interTextTheme.labelSmall?.copyWith(
        fontFamily: bodyFontFamily,
        color: colors.textTertiary,
        fontWeight: FontWeight.w500,
      ),
    );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: colors.bg,
      colorScheme: colorScheme,
      fontFamily: bodyFontFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: [PhoraThemeTokens(colors: colors, gradients: gradients)],
      dividerColor: colors.divider,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colors.bg,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colors.bgCard,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.bgElevated,
        indicatorColor: colors.accentPrimary.withValues(alpha: 0.16),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? colors.accentPrimary : colors.textTertiary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            color: isSelected ? colors.textPrimary : colors.textTertiary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? colors.bgElevated : colors.bgSurface,
        hintStyle: TextStyle(color: colors.textQuaternary),
        labelStyle: TextStyle(color: colors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: isLight ? colors.borderStrong : colors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.accentPrimary, width: 1.4),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: isLight ? colors.borderStrong : colors.border,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryButtonColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryButtonColor,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.accentPrimary;
          }
          return colors.bgCard;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.accentPrimary.withValues(alpha: 0.32);
          }
          return colors.borderStrong;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accentPrimary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.white,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.accentDanger,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: colors.accentDanger,
        closeIconColor: colors.accentDanger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

extension PhoraThemeX on BuildContext {
  PhoraThemeTokens get phora => Theme.of(this).extension<PhoraThemeTokens>()!;
}
