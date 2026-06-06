import 'package:phora/core/i18n/app_supported_locale.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/i18n/locale_controller.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingPager extends ConsumerWidget {
  const OnboardingPager({
    super.key,
    required this.controller,
    required this.children,
    required this.page,
    required this.stepCount,
    required this.ctaLabel,
    required this.onContinue,
    this.onBack,
    this.showAtmosphere = true,
    this.backgroundColor,
    this.secondaryLabel,
    this.onSecondary,
  });

  final PageController controller;
  final List<Widget> children;
  final double page;
  final int stepCount;
  final String ctaLabel;
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final bool showAtmosphere;
  final Color? backgroundColor;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  static const _darkSurface = Color(0xFF1C1520);
  static const _darkBorder = Color(0xFF3B2C3E);
  static const _darkText = Color(0xFFFFF3E8);
  static const _darkMuted = Color(0xFFD6B8A7);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localeState = ref.watch(localeControllerProvider).valueOrNull;
    final activeLocale = localeState?.activeLocale;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor ?? colors.bg,
        ),
        child: Stack(
          children: [
            if (showAtmosphere)
              Positioned.fill(
                child: IgnorePointer(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Opacity(
                        opacity: isDark ? 0.18 : 1,
                        child: Image.asset(
                          'assets/images/onboarding_background.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                      ),
                      if (isDark)
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xCC120D13),
                                Color(0xE6120D13),
                                Color(0xFF120D13),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding =
                      constraints.maxWidth > 480
                          ? dims.scaleWidth(32)
                          : dims.scaleWidth(24);
                  final secondarySlotHeight = dims.scaleHeight(42);
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      dims.scaleSpace(16),
                      horizontalPadding,
                      dims.scaleSpace(20),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: dims.scaleHeight(42),
                          child: Row(
                            children: [
                              if (onBack != null)
                                IconButton(
                                  onPressed: onBack,
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  color:
                                      isDark
                                          ? _darkText
                                          : const Color(0xFF4A2C1A),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              else
                                SizedBox(width: dims.scaleWidth(24)),
                              const Spacer(),
                              _OnboardingLanguageMenu(
                                activeLocale: activeLocale,
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: dims.scaleSpace(4)),
                        Expanded(
                          child: PageView(
                            controller: controller,
                            children: children,
                          ),
                        ),
                        SizedBox(height: dims.scaleSpace(10)),
                        SizedBox(
                          height: secondarySlotHeight,
                          child:
                              secondaryLabel != null && onSecondary != null
                                  ? Center(
                                    child: TextButton(
                                      onPressed: onSecondary,
                                      style: TextButton.styleFrom(
                                        foregroundColor: const Color(0xFFFF8A4C),
                                        textStyle: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontSize: dims.scaleText(15),
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      child: Text(secondaryLabel!),
                                    ),
                                  )
                                  : null,
                        ),
                        OnboardingProgressDots(
                          count: stepCount,
                          page: page,
                        ),
                        SizedBox(height: dims.scaleSpace(20)),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: OnboardingPrimaryButton(
                            label: ctaLabel,
                            onPressed: onContinue,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingLanguageMenu extends ConsumerWidget {
  const _OnboardingLanguageMenu({
    required this.activeLocale,
    required this.isDark,
  });

  final AppSupportedLocale? activeLocale;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dims = context.dims;
    final controller = ref.read(localeControllerProvider.notifier);
    final currentLocale = activeLocale ?? AppSupportedLocale.english;

    String displayName(AppSupportedLocale locale) {
      return switch (locale.tag) {
        'en' => context.l10n.localeEnglishGlobal,
        'en-GB' => context.l10n.localeEnglishUk,
        'en-US' => context.l10n.localeEnglishUs,
        'en-CA' => context.l10n.localeEnglishCanada,
        'en-AU' => context.l10n.localeEnglishAustralia,
        'es' => context.l10n.localeSpanishGlobal,
        'es-ES' => context.l10n.localeSpanishSpain,
        'es-419' => context.l10n.localeSpanishLatam,
        'fr' => context.l10n.localeFrenchGlobal,
        'fr-FR' => context.l10n.localeFrenchFrance,
        'fr-CA' => context.l10n.localeFrenchCanada,
        'de' => context.l10n.localeGermanGlobal,
        'de-DE' => context.l10n.localeGermanGermany,
        'de-AT' => context.l10n.localeGermanAustria,
        'de-CH' => context.l10n.localeGermanSwitzerland,
        'pt' => context.l10n.localePortugueseGlobal,
        'pt-BR' => context.l10n.localePortugueseBrazil,
        'pt-PT' => context.l10n.localePortuguesePortugal,
        _ => locale.displayName,
      };
    }

    String badge(AppSupportedLocale locale) {
      final countryCode = locale.countryCode;
      if (countryCode != null && countryCode.isNotEmpty) {
        return countryCode.toUpperCase();
      }
      return locale.languageCode.toUpperCase();
    }

    return PopupMenuButton<String>(
      tooltip: context.l10n.profileLanguageTitle,
      onSelected: (tag) async {
        final locale = AppSupportedLocale.fromTag(tag);
        if (locale != null) {
          await controller.setExplicitLocale(locale);
        }
      },
      color: isDark ? OnboardingPager._darkSurface : Colors.white,
      surfaceTintColor: isDark ? OnboardingPager._darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        side: BorderSide(
          color:
              isDark
                  ? OnboardingPager._darkBorder
                  : const Color(0xFFFFE0CE),
        ),
      ),
      itemBuilder:
          (context) => AppSupportedLocale.all
              .map(
                (locale) => PopupMenuItem<String>(
                  value: locale.tag,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName(locale),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                isDark
                                    ? OnboardingPager._darkText
                                    : const Color(0xFF4A2C1A),
                            fontSize: dims.scaleText(13),
                          ),
                        ),
                      ),
                      if (locale.tag == currentLocale.tag)
                        Icon(
                          Icons.check_rounded,
                          color: const Color(0xFFFF8A4C),
                          size: dims.scaleText(18),
                        ),
                    ],
                  ),
                ),
              )
              .toList(),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dims.scaleWidth(12),
          vertical: dims.scaleSpace(8),
        ),
        decoration: BoxDecoration(
          color:
              isDark
                  ? OnboardingPager._darkSurface.withValues(alpha: 0.94)
                  : Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
          border: Border.all(
            color:
                isDark
                    ? OnboardingPager._darkBorder
                    : const Color(0xFFFFE0CE),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.language_rounded,
              size: dims.scaleText(16),
              color: const Color(0xFFFF8A4C),
            ),
            SizedBox(width: dims.scaleWidth(8)),
            Text(
              badge(currentLocale),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color:
                    isDark
                        ? OnboardingPager._darkText
                        : const Color(0xFF4A2C1A),
                fontSize: dims.scaleText(11),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            SizedBox(width: dims.scaleWidth(4)),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: dims.scaleText(18),
              color:
                  isDark
                      ? OnboardingPager._darkMuted
                      : const Color(0xFF4A2C1A),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingSlide extends StatelessWidget {
  const OnboardingSlide({
    super.key,
    required this.hero,
    required this.subtitle,
    required this.bottomContent,
    this.title,
    this.titleLines,
    this.heroBottomSpacing,
    this.titleFontSize = 28,
    this.titleSpacing = 10,
    this.subtitleFontSize = 16,
    this.subtitleBottomSpacing = 8,
    this.wrapHeroInCard = true,
  }) : assert(title != null || titleLines != null);

  final Widget hero;
  final String? title;
  final List<OnboardingTitleLine>? titleLines;
  final String subtitle;
  final Widget bottomContent;
  final double? heroBottomSpacing;
  final double titleFontSize;
  final double titleSpacing;
  final double subtitleFontSize;
  final double subtitleBottomSpacing;
  final bool wrapHeroInCard;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 420,
                minHeight: constraints.maxHeight,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(4)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(height: dims.scaleSpace(14)),
                    if (wrapHeroInCard)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.fromLTRB(
                          dims.scaleWidth(20),
                          dims.scaleSpace(20),
                          dims.scaleWidth(20),
                          dims.scaleSpace(22),
                        ),
                        decoration: BoxDecoration(
                          color: colors.bgCard.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(dims.scaleRadius(30)),
                          border: Border.all(
                            color: colors.border.withValues(alpha: 0.9),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.textPrimary.withValues(alpha: 0.04),
                              blurRadius: 30,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: hero,
                      )
                    else
                      hero,
                    SizedBox(
                      height: dims.scaleSpace(heroBottomSpacing ?? 44),
                    ),
                    if (title != null)
                      Text(
                        title!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontSize: dims.scaleText(titleFontSize),
                          height: 1.12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      )
                    else
                      Column(
                        children: titleLines!
                            .map((line) => _TitleSegment(line: line))
                            .toList(),
                      ),
                    SizedBox(height: dims.scaleSpace(titleSpacing)),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.textSecondary,
                        fontSize: dims.scaleText(subtitleFontSize),
                        height: 1.55,
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(subtitleBottomSpacing)),
                    bottomContent,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class OnboardingTitleLine {
  const OnboardingTitleLine({
    required this.text,
    this.highlighted = false,
  });

  final String text;
  final bool highlighted;
}

class _TitleSegment extends StatelessWidget {
  const _TitleSegment({required this.line});

  final OnboardingTitleLine line;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final textStyle = Theme.of(context).textTheme.displaySmall?.copyWith(
      fontSize: dims.scaleText(28),
      height: 1.12,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
    );

    if (!line.highlighted) {
      return Text(
        line.text,
        textAlign: TextAlign.center,
        style: textStyle,
      );
    }

    return Text(
      line.text,
      textAlign: TextAlign.center,
      style: textStyle,
    );
  }
}

class OnboardingHeroOrb extends StatefulWidget {
  const OnboardingHeroOrb({
    super.key,
    required this.emoji,
    required this.gradientColors,
    this.baseSize = 224,
    this.emojiSize = 74,
  });

  final String emoji;
  final List<Color> gradientColors;
  final double baseSize;
  final double emojiSize;

  @override
  State<OnboardingHeroOrb> createState() => _OnboardingHeroOrbState();
}

class _OnboardingHeroOrbState extends State<OnboardingHeroOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _offsetAnimation = Tween<double>(
      begin: -8,
      end: 8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, dims.scaleHeight(_offsetAnimation.value)),
          child: child,
        );
      },
      child: Container(
        width: dims.scaleWidth(widget.baseSize),
        height: dims.scaleWidth(widget.baseSize),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.gradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.gradientColors.first.withValues(alpha: 0.18),
              blurRadius: 40,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: widget.gradientColors.last.withValues(alpha: 0.14),
              blurRadius: 56,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: colors.bg.withValues(alpha: 0.20),
              blurRadius: 80,
              spreadRadius: -10,
            ),
          ],
        ),
        child: Center(
          child: Text(
            widget.emoji,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: dims.scaleText(widget.emojiSize),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingFeatureCard extends StatelessWidget {
  const OnboardingFeatureCard({
    super.key,
    required this.icon,
    required this.text,
    this.compact = false,
  });

  final String icon;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(compact ? 12 : 14),
        vertical: dims.scaleHeight(compact ? 12 : 14),
      ),
      decoration: BoxDecoration(
        color: colors.bgCard.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(dims.scaleRadius(compact ? 16 : 18)),
        border: Border.all(color: colors.border.withValues(alpha: 0.9)),
      ),
      child: Row(
        children: [
          Container(
            width: dims.scaleWidth(compact ? 30 : 34),
            height: dims.scaleWidth(compact ? 30 : 34),
            decoration: BoxDecoration(
              color: colors.bgSurface,
              borderRadius: BorderRadius.circular(dims.scaleRadius(compact ? 8 : 10)),
            ),
            alignment: Alignment.center,
            child: Text(
              icon,
              style: TextStyle(fontSize: dims.scaleText(compact ? 14 : 16)),
            ),
          ),
          SizedBox(width: dims.scaleWidth(compact ? 10 : 12)),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: dims.scaleText(compact ? 13 : 14),
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingSelectionCard extends StatelessWidget {
  const OnboardingSelectionCard({
    super.key,
    required this.title,
    required this.badge,
    required this.description,
    required this.isHighlighted,
    required this.onTap,
  });

  final String title;
  final String badge;
  final String description;
  final bool isHighlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final dims = context.dims;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(dims.scaleWidth(18)),
          decoration: BoxDecoration(
            color: isLight
                ? (isHighlighted ? colors.bgCard : colors.bgElevated)
                : (isHighlighted
                    ? colors.bgCard.withValues(alpha: 0.64)
                    : colors.bgCard.withValues(alpha: 0.92)),
            borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
            border: Border.all(
              color: isHighlighted
                  ? const Color(0xFFB777E7)
                  : (isLight ? colors.border : colors.borderStrong),
              width: isHighlighted ? 2 : 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: dims.scaleText(16),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    badge,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: dims.scaleText(10),
                      color: isHighlighted
                          ? const Color(0xFFB777E7)
                          : colors.textTertiary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              SizedBox(height: dims.scaleSpace(10)),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: dims.scaleText(13),
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingProgressDots extends StatelessWidget {
  const OnboardingProgressDots({
    super.key,
    required this.count,
    required this.page,
  });

  final int count;
  final double page;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotSize = dims.scaleWidth(8);
    final activeWidth = dims.scaleWidth(36);
    final gap = dims.scaleWidth(8);
    final stepWidth = dotSize + gap;
    final activeOffset = page.clamp(0, count - 1) * stepWidth;
    final trackWidth = (count * dotSize) + ((count - 1) * gap);

    return SizedBox(
      width: trackWidth + (activeWidth - dotSize),
      height: dotSize,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(count, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == count - 1 ? 0 : gap,
                    ),
                    child: Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? const Color(0xFF4A394D)
                                : context.phora.colors.borderStrong,
                        borderRadius: BorderRadius.circular(
                          dims.scaleRadius(999),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          Positioned(
            left: activeOffset,
            top: 0,
            child: Container(
              width: activeWidth,
              height: dotSize,
              decoration: BoxDecoration(
                color: const Color(0xFFFF8A4C),
                borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPrimaryButton extends StatelessWidget {
  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final primaryButtonColor =
        Theme.of(context).brightness == Brightness.light
            ? const Color(0xFFFF8A4C)
            : const Color(0xFFFF8A4C);
    final isEnabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            if (isEnabled) ...[
              primaryButtonColor,
              primaryButtonColor,
            ] else ...[
              colors.borderStrong,
              colors.border,
            ],
          ],
        ),
        borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
        boxShadow: [
          BoxShadow(
            color: (isEnabled ? primaryButtonColor : colors.borderStrong)
                .withValues(alpha: isEnabled ? 0.2 : 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
          onTap: onPressed,
          child: SizedBox(
            height: dims.scaleHeight(54),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: isEnabled ? Colors.white : colors.textTertiary,
                  fontSize: dims.scaleText(14),
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
