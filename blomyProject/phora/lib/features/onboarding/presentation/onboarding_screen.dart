import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/features/onboarding/presentation/widgets/onboarding_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final PageController _pageController;
  double _page = 0;

  static const _stepCount = 4;

  @override
  void initState() {
    super.initState();
    _pageController =
        PageController()..addListener(() {
          setState(() {
            _page =
                _pageController.page ?? _pageController.initialPage.toDouble();
          });
        });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    final currentStep = _page.round();
    if (currentStep < _stepCount - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    await _finishOnboarding();
  }

  Future<void> _finishOnboarding() async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (!mounted) {
      return;
    }
    context.go('/sign-in');
  }

  Future<void> _handleBack() async {
    final currentStep = _page.round();
    if (currentStep <= 0) {
      return;
    }
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _page.round();
    final isLastStep = currentStep >= _stepCount - 1;
    final showSkip = currentStep < 3;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctaLabel =
        isLastStep
            ? context.l10n.onboardingStartTrackingLabel
            : context.l10n.onboardingNextLabel;

    return OnboardingPager(
      controller: _pageController,
      page: _page,
      stepCount: _stepCount,
      showAtmosphere: true,
      backgroundColor:
          isDark ? const Color(0xFF120D13) : const Color(0xFFFFF6F0),
      ctaLabel: ctaLabel,
      onContinue: _handleContinue,
      onBack: currentStep > 0 ? _handleBack : null,
      secondaryLabel: showSkip ? context.l10n.onboardingSkipLabel : null,
      onSecondary: showSkip ? _finishOnboarding : null,
      children: [
        _WelcomeSlide(),
        _RhythmSlide(),
        const _PrivacySlide(),
        const _AiAssistantSlide(),
      ],
    );
  }
}

class _WelcomeSlide extends StatelessWidget {
  const _WelcomeSlide();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          dims.scaleWidth(24),
          dims.scaleSpace(8),
          dims.scaleWidth(24),
          dims.scaleSpace(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: dims.scaleSpace(16)),
            _WelcomeHeroBlock(),
            SizedBox(height: dims.scaleSpace(18)),
            const _PhaseStripeRow(),
            SizedBox(height: dims.scaleSpace(18)),
            _PhaseInfoCard(
              icon: _MenstrualPhaseIcon(),
              title: context.l10n.onboardingPhaseMenstrualTitle,
              subtitle: context.l10n.onboardingPhaseMenstrualSubtitle,
              dayLabel: context.l10n.onboardingPhaseMenstrualDays,
              dayBackground: _WelcomePalette.badgeBackground(context),
              dayTextColor: _WelcomePalette.accent,
            ),
            SizedBox(height: dims.scaleSpace(16)),
            _PhaseInfoCard(
              icon: _FollicularPhaseIcon(),
              title: context.l10n.onboardingPhaseFollicularTitle,
              subtitle: context.l10n.onboardingPhaseFollicularSubtitle,
              dayLabel: context.l10n.onboardingPhaseFollicularDays,
              dayBackground: _WelcomePalette.follicularSoft(context),
              dayTextColor: Color(0xFF46C79A),
            ),
            SizedBox(height: dims.scaleSpace(16)),
            _PhaseInfoCard(
              icon: _OvulationPhaseIcon(),
              title: context.l10n.onboardingPhaseOvulationTitle,
              subtitle: context.l10n.onboardingPhaseOvulationSubtitle,
              dayLabel: context.l10n.onboardingPhaseOvulationDays,
              dayBackground: _WelcomePalette.ovulationSoft(context),
              dayTextColor: Color(0xFF43B6DE),
            ),
            SizedBox(height: dims.scaleSpace(16)),
            _PhaseInfoCard(
              icon: _LutealPhaseIcon(),
              title: context.l10n.onboardingPhaseLutealTitle,
              subtitle: context.l10n.onboardingPhaseLutealSubtitle,
              dayLabel: context.l10n.onboardingPhaseLutealDays,
              dayBackground: _WelcomePalette.lutealSoft(context),
              dayTextColor: Color(0xFFA56BD8),
            ),
            SizedBox(height: dims.scaleSpace(18)),
          ],
        ),
      ),
    );
  }
}

class _RhythmSlide extends StatelessWidget {
  const _RhythmSlide();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          dims.scaleWidth(24),
          dims.scaleSpace(8),
          dims.scaleWidth(24),
          dims.scaleSpace(12),
        ),
        child: Column(
          children: [
            SizedBox(height: dims.scaleSpace(16)),
            Text(
              context.l10n.onboardingRhythmTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: dims.scaleText(35),
                height: 0.94,
                color: _WelcomePalette.primaryText(context),
                fontWeight: FontWeight.w700,
                fontFamily: 'Georgia',
              ),
            ),
            SizedBox(height: dims.scaleSpace(16)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(14)),
              child: Text(
                context.l10n.onboardingRhythmSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: dims.scaleText(13),
                  height: 1.5,
                  color: _WelcomePalette.secondaryText(context),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            SizedBox(height: dims.scaleSpace(18)),
            const _CalendarPreviewCard(),
            SizedBox(height: dims.scaleSpace(14)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(6)),
              child: Text(
                'Connect your wearable for effective tracking',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: dims.scaleText(13),
                  height: 1.5,
                  color: _WelcomePalette.secondaryText(context),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            SizedBox(height: dims.scaleSpace(10)),
            const _WearablePreviewCard(),
            SizedBox(height: dims.scaleSpace(14)),
          ],
        ),
      ),
    );
  }
}

class _WelcomeHeroBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: dims.scaleSpace(16)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                context.l10n.onboardingPhasesTitle,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: dims.scaleText(33),
                  height: 0.94,
                  color: _WelcomePalette.primaryText(context),
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Georgia',
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: dims.scaleSpace(14)),
        Text(
          context.l10n.onboardingPhasesSubtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: dims.scaleText(13),
            height: 1.5,
            color: _WelcomePalette.secondaryText(context),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _CalendarPreviewCard extends StatelessWidget {
  const _CalendarPreviewCard();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final isDark = _WelcomePalette.isDark(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(18),
        dims.scaleSpace(14),
        dims.scaleWidth(18),
        dims.scaleSpace(18),
      ),
      decoration: BoxDecoration(
        color: _WelcomePalette.surface(context),
        borderRadius: BorderRadius.circular(dims.scaleRadius(26)),
        border: Border.all(color: _WelcomePalette.decorativeLineArt(context)),
        boxShadow: [
          BoxShadow(
            color: (isDark
                    ? Colors.black
                    : _WelcomePalette.decorativeLineArt(context))
                .withValues(alpha: isDark ? 0.24 : 0.42),
            blurRadius: isDark ? 22 : 20,
            offset: Offset(0, isDark ? 10 : 8),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1.42,
        child: CustomPaint(painter: _CalendarPreviewPainter(isDark: isDark)),
      ),
    );
  }
}

class _WearablePreviewCard extends StatelessWidget {
  const _WearablePreviewCard();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final isDark = _WelcomePalette.isDark(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(16),
        vertical: dims.scaleSpace(14),
      ),
      decoration: BoxDecoration(
        color: _WelcomePalette.surface(context),
        borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
        border: Border.all(color: _WelcomePalette.decorativeLineArt(context)),
        boxShadow: [
          BoxShadow(
            color: (isDark
                    ? Colors.black
                    : _WelcomePalette.decorativeLineArt(context))
                .withValues(alpha: isDark ? 0.2 : 0.22),
            blurRadius: isDark ? 14 : 10,
            offset: Offset(0, isDark ? 6 : 3),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _WearableChoice(
              label: 'Vyla Wear',
              child: _PhoraWearIconTile(),
            ),
          ),
        ],
      ),
    );
  }
}

class _WearableChoice extends StatelessWidget {
  const _WearableChoice({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        SizedBox(height: dims.scaleSpace(8)),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: dims.scaleText(10.5),
            fontWeight: FontWeight.w700,
            color: _WelcomePalette.primaryText(context),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _PhoraWearIconTile extends StatelessWidget {
  const _PhoraWearIconTile();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final isDark = _WelcomePalette.isDark(context);

    return SizedBox(
      width: dims.scaleWidth(74),
      height: dims.scaleWidth(88),
      child: Center(
        child: Container(
          width: dims.scaleWidth(58),
          height: dims.scaleWidth(58),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                isDark
                    ? _WelcomePalette.surfaceStrong(context)
                    : const Color(0xFFF3F3F3),
          ),
          child: Icon(
            Icons.watch_rounded,
            color: _WelcomePalette.primaryText(context),
            size: dims.scaleText(30),
          ),
        ),
      ),
    );
  }
}

class _CalendarPreviewPainter extends CustomPainter {
  const _CalendarPreviewPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final sheetPaint =
        Paint()
          ..color = isDark ? const Color(0xFF221A27) : Colors.white
          ..style = PaintingStyle.fill;
    final borderPaint =
        Paint()
          ..color = isDark ? const Color(0xFF3B2C3E) : const Color(0xFFFFE6D6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
    final topBarPaint =
        Paint()
          ..color = isDark ? const Color(0xFF2E222F) : const Color(0xFFFFE5D2)
          ..style = PaintingStyle.fill;
    final shadowPaint =
        Paint()
          ..color = (isDark ? Colors.black : const Color(0xFFFFD9C3))
              .withValues(alpha: isDark ? 0.28 : 0.65)
          ..style = PaintingStyle.fill;

    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height * 0.08, size.width, size.height * 0.86),
      const Radius.circular(20),
    );
    canvas.drawRRect(
      outer.shift(Offset(size.width * 0.02, size.height * 0.02)),
      shadowPaint,
    );
    canvas.drawRRect(outer, sheetPaint);
    canvas.drawRRect(outer, borderPaint);

    final header = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, size.height * 0.08, size.width, size.height * 0.16),
      const Radius.circular(20),
    );
    canvas.drawRRect(header, topBarPaint);

    final ringPaint =
        Paint()
          ..color = const Color(0xFFD9A27F)
          ..style = PaintingStyle.fill;
    final ringHolePaint =
        Paint()
          ..color = isDark ? const Color(0xFF120D13) : const Color(0xFFFFF6F0)
          ..style = PaintingStyle.fill;
    final ringY = size.height * 0.16;
    for (var i = 0; i < 9; i++) {
      final x = size.width * (0.07 + (i * 0.11));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, ringY - 16), width: 8, height: 24),
          const Radius.circular(8),
        ),
        topBarPaint,
      );
      canvas.drawCircle(Offset(x, ringY - 1), 7, ringPaint);
      canvas.drawCircle(Offset(x, ringY - 7), 4.4, ringHolePaint);
    }

    final gridTop = size.height * 0.28;
    final gridLeft = size.width * 0.06;
    final gridWidth = size.width * 0.88;
    final gridHeight = size.height * 0.54;
    final columnWidth = gridWidth / 7;
    final rowHeight = gridHeight / 5;
    final gridPaint =
        Paint()
          ..color = isDark ? const Color(0xFF4C3C4F) : const Color(0xFFF1DED1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    for (var c = 0; c <= 7; c++) {
      final x = gridLeft + (columnWidth * c);
      canvas.drawLine(
        Offset(x, gridTop),
        Offset(x, gridTop + gridHeight),
        gridPaint,
      );
    }
    for (var r = 0; r <= 5; r++) {
      final y = gridTop + (rowHeight * r);
      canvas.drawLine(
        Offset(gridLeft, y),
        Offset(gridLeft + gridWidth, y),
        gridPaint,
      );
    }

    final markPaint =
        Paint()
          ..color = _WelcomePalette.accent
          ..style = PaintingStyle.fill;
    final deepPaint =
        Paint()
          ..color = isDark ? const Color(0xFFFFF3E8) : const Color(0xFF4A2C1A)
          ..style = PaintingStyle.fill;
    final softPaint =
        Paint()
          ..color = isDark ? const Color(0xFF3A2A31) : const Color(0xFFFFD8C2)
          ..style = PaintingStyle.fill;
    final orangePaint =
        Paint()
          ..color = const Color(0xFFF06A16)
          ..style = PaintingStyle.fill;

    final cells = [
      (1, 0, markPaint),
      (2, 0, deepPaint),
      (4, 0, markPaint),
      (6, 0, markPaint),
      (2, 2, orangePaint),
      (5, 3, markPaint),
      (0, 4, softPaint),
    ];
    for (final (column, row, paint) in cells) {
      canvas.drawRect(
        Rect.fromLTWH(
          gridLeft + (columnWidth * column),
          gridTop + (rowHeight * row),
          columnWidth,
          rowHeight,
        ),
        paint,
      );
    }

    final crossPaint =
        Paint()
          ..color = _WelcomePalette.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
    void drawCross(int column, int row) {
      final center = Offset(
        gridLeft + (columnWidth * column) + (columnWidth / 2),
        gridTop + (rowHeight * row) + (rowHeight / 2),
      );
      canvas.drawLine(
        center.translate(-7, -7),
        center.translate(7, 7),
        crossPaint,
      );
      canvas.drawLine(
        center.translate(7, -7),
        center.translate(-7, 7),
        crossPaint,
      );
    }

    drawCross(1, 0);
    drawCross(3, 4);

    final notePaint =
        Paint()
          ..color = isDark ? const Color(0xFF5A485A) : const Color(0xFFFFE0D0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
    for (final (dx, dy) in const [
      (1.45, 0.35),
      (1.15, 1.15),
      (4.15, 1.15),
      (6.15, 2.15),
      (0.15, 3.20),
      (2.15, 4.15),
      (5.15, 4.05),
    ]) {
      final x = gridLeft + (columnWidth * dx);
      final y = gridTop + (rowHeight * dy);
      canvas.drawLine(Offset(x, y), Offset(x + 18, y), notePaint);
      canvas.drawLine(Offset(x, y + 8), Offset(x + 12, y + 8), notePaint);
    }

    final squarePaint =
        Paint()
          ..color = isDark ? const Color(0xFFFAE2D3) : const Color(0xFFFFE7D8)
          ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(gridLeft + (columnWidth * 6) + 5, gridTop + 6, 12, 12),
      squarePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        gridLeft + (columnWidth * 2) + 5,
        gridTop + (rowHeight * 2) + 6,
        12,
        12,
      ),
      squarePaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        gridLeft + (columnWidth * 5) + 5,
        gridTop + (rowHeight * 3) + 6,
        12,
        12,
      ),
      squarePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

abstract final class _WelcomePalette {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color primaryText(BuildContext context) =>
      isDark(context) ? const Color(0xFFFFF3E8) : const Color(0xFF4A2C1A);
  static Color secondaryText(BuildContext context) =>
      isDark(context) ? const Color(0xFFD6B8A7) : const Color(0xFFA06A52);
  static const accent = Color(0xFFFF8A4C);
  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF1C1520) : Colors.white;
  static Color surfaceStrong(BuildContext context) =>
      isDark(context) ? const Color(0xFF241B29) : const Color(0xFFFFEBDC);
  static Color follicularSoft(BuildContext context) =>
      isDark(context) ? const Color(0xFF17332B) : const Color(0xFFE6F7F0);
  static Color ovulationSoft(BuildContext context) =>
      isDark(context) ? const Color(0xFF162E3A) : const Color(0xFFEAF6FB);
  static Color lutealSoft(BuildContext context) =>
      isDark(context) ? const Color(0xFF2D223B) : const Color(0xFFF3EAFB);
  static Color decorativeLineArt(BuildContext context) =>
      isDark(context) ? const Color(0xFF3B2C3E) : const Color(0xFFFFE6D6);
  static Color badgeBackground(BuildContext context) =>
      isDark(context) ? const Color(0xFF312329) : const Color(0xFFFFF0E6);
}

class _PhaseStripeRow extends StatelessWidget {
  const _PhaseStripeRow();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    const stripes = [
      _WelcomePalette.accent,
      Color(0xFF46C79A),
      Color(0xFF43B6DE),
      Color(0xFFA56BD8),
    ];

    return Row(
      children:
          stripes
              .map(
                (color) => Expanded(
                  child: Container(
                    height: dims.scaleHeight(5),
                    margin: EdgeInsets.only(
                      right: color == stripes.last ? 0 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(
                        dims.scaleRadius(999),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }
}

class _MenstrualPhaseIcon extends StatelessWidget {
  const _MenstrualPhaseIcon();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return ClipRRect(
      borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
      child: Image.asset(
        'assets/icons/menstrual_drop.png',
        width: dims.scaleWidth(50),
        height: dims.scaleWidth(50),
        fit: BoxFit.cover,
      ),
    );
  }
}

class _FollicularPhaseIcon extends StatelessWidget {
  const _FollicularPhaseIcon();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return ClipRRect(
      borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
      child: Image.asset(
        'assets/icons/follicular_leaf.png',
        width: dims.scaleWidth(50),
        height: dims.scaleWidth(50),
        fit: BoxFit.cover,
      ),
    );
  }
}

class _OvulationPhaseIcon extends StatelessWidget {
  const _OvulationPhaseIcon();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return ClipRRect(
      borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
      child: Image.asset(
        'assets/icons/ovulation_sun.png',
        width: dims.scaleWidth(50),
        height: dims.scaleWidth(50),
        fit: BoxFit.cover,
      ),
    );
  }
}

class _LutealPhaseIcon extends StatelessWidget {
  const _LutealPhaseIcon();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return ClipRRect(
      borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
      child: Image.asset(
        'assets/icons/luteal_moon.png',
        width: dims.scaleWidth(50),
        height: dims.scaleWidth(50),
        fit: BoxFit.cover,
      ),
    );
  }
}

class _PhaseInfoCard extends StatelessWidget {
  const _PhaseInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.dayLabel,
    required this.dayBackground,
    required this.dayTextColor,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final String dayLabel;
  final Color dayBackground;
  final Color dayTextColor;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(20),
        vertical: dims.scaleSpace(18),
      ),
      decoration: BoxDecoration(
        color: _WelcomePalette.surface(context),
        borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
        border: Border.all(color: _WelcomePalette.decorativeLineArt(context)),
        boxShadow: [
          BoxShadow(
            color: (_WelcomePalette.isDark(context)
                    ? Colors.black
                    : _WelcomePalette.decorativeLineArt(context))
                .withValues(
                  alpha: _WelcomePalette.isDark(context) ? 0.2 : 0.22,
                ),
            blurRadius: _WelcomePalette.isDark(context) ? 14 : 10,
            offset: Offset(0, _WelcomePalette.isDark(context) ? 6 : 2),
          ),
        ],
      ),
      child: Row(
        children: [
          icon,
          SizedBox(width: dims.scaleWidth(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: dims.scaleText(15),
                    fontWeight: FontWeight.w700,
                    color: _WelcomePalette.primaryText(context),
                    fontFamily: 'Georgia',
                  ),
                ),
                SizedBox(height: dims.scaleSpace(2)),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: dims.scaleText(11),
                    color: _WelcomePalette.secondaryText(context),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: dims.scaleWidth(14),
              vertical: dims.scaleSpace(8),
            ),
            decoration: BoxDecoration(
              color: dayBackground,
              borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
            ),
            child: Text(
              dayLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: dims.scaleText(10),
                fontWeight: FontWeight.w500,
                color: dayTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacySlide extends StatelessWidget {
  const _PrivacySlide();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final title = context.l10n.onboardingPrivacyTitle.split('\n');

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          dims.scaleWidth(22),
          dims.scaleSpace(8),
          dims.scaleWidth(22),
          dims.scaleSpace(12),
        ),
        child: Column(
          children: [
            SizedBox(height: dims.scaleSpace(16)),
            const _PrivacyHero(),
            SizedBox(height: dims.scaleSpace(18)),
            Text(
              title.join('\n'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: dims.scaleText(30),
                height: 0.94,
                color: _WelcomePalette.primaryText(context),
                fontWeight: FontWeight.w700,
                fontFamily: 'Georgia',
              ),
            ),
            SizedBox(height: dims.scaleSpace(12)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(10)),
              child: Text(
                context.l10n.onboardingPrivacySubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: dims.scaleText(13),
                  height: 1.55,
                  color: _WelcomePalette.secondaryText(context),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            SizedBox(height: dims.scaleSpace(18)),
            _PrivacyFeatureTile(
              icon: Icons.lock_rounded,
              text: context.l10n.onboardingPrivacyFeatureEncryption,
            ),
            SizedBox(height: dims.scaleSpace(10)),
            _PrivacyFeatureTile(
              icon: Icons.do_not_disturb_on_outlined,
              text: context.l10n.onboardingPrivacyFeatureNoSelling,
            ),
            SizedBox(height: dims.scaleSpace(10)),
            _PrivacyFeatureTile(
              icon: Icons.smartphone_rounded,
              text: context.l10n.onboardingPrivacyFeatureLocalMode,
            ),
            SizedBox(height: dims.scaleSpace(18)),
          ],
        ),
      ),
    );
  }
}

class _AiAssistantSlide extends StatelessWidget {
  const _AiAssistantSlide();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          dims.scaleWidth(24),
          dims.scaleSpace(8),
          dims.scaleWidth(24),
          dims.scaleSpace(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: dims.scaleSpace(16)),
            const _AiPillLabel(),
            SizedBox(height: dims.scaleSpace(18)),
            Text(
              context.l10n.onboardingAiTitle,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: dims.scaleText(35),
                height: 0.94,
                color: _WelcomePalette.primaryText(context),
                fontWeight: FontWeight.w700,
                fontFamily: 'Georgia',
              ),
            ),
            SizedBox(height: dims.scaleSpace(16)),
            Padding(
              padding: EdgeInsets.only(right: dims.scaleWidth(18)),
              child: Text(
                context.l10n.onboardingAiSubtitle,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: dims.scaleText(13.5),
                  height: 1.6,
                  color: _WelcomePalette.secondaryText(context),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            SizedBox(height: dims.scaleSpace(24)),
            Align(
              alignment: Alignment.centerRight,
              child: _AiChatBubble(
                text: context.l10n.onboardingAiQuestion,
                alignRight: true,
                widthFactor: 0.78,
              ),
            ),
            SizedBox(height: dims.scaleSpace(18)),
            Padding(
              padding: EdgeInsets.only(left: dims.scaleWidth(10)),
              child: Text(
                context.l10n.onboardingAiBadge,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: dims.scaleText(15),
                  fontWeight: FontWeight.w700,
                  color: _WelcomePalette.primaryText(context),
                  fontFamily: 'Georgia',
                ),
              ),
            ),
            SizedBox(height: dims.scaleSpace(10)),
            _AiChatBubble(
              text: context.l10n.onboardingAiResponse,
              alignRight: false,
              widthFactor: 0.82,
              highlighted: true,
            ),
            SizedBox(height: dims.scaleSpace(18)),
          ],
        ),
      ),
    );
  }
}

class _PrivacyHero extends StatelessWidget {
  const _PrivacyHero();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      width: dims.scaleWidth(176),
      height: dims.scaleWidth(176),
      decoration: BoxDecoration(
        color: _WelcomePalette.surfaceStrong(context),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (_WelcomePalette.isDark(context)
                    ? _WelcomePalette.accent
                    : _WelcomePalette.decorativeLineArt(context))
                .withValues(
                  alpha: _WelcomePalette.isDark(context) ? 0.18 : 0.30,
                ),
            blurRadius: _WelcomePalette.isDark(context) ? 26 : 18,
            offset: Offset(0, _WelcomePalette.isDark(context) ? 12 : 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.lock_rounded,
        size: dims.scaleText(74),
        color: _WelcomePalette.accent,
      ),
    );
  }
}

class _PrivacyFeatureTile extends StatelessWidget {
  const _PrivacyFeatureTile({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(12),
        vertical: dims.scaleSpace(11),
      ),
      decoration: BoxDecoration(
        color: (_WelcomePalette.isDark(context)
                ? _WelcomePalette.surface(context)
                : Colors.white)
            .withValues(alpha: _WelcomePalette.isDark(context) ? 0.94 : 0.72),
        borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
        border: Border.all(color: _WelcomePalette.decorativeLineArt(context)),
        boxShadow: [
          BoxShadow(
            color: (_WelcomePalette.isDark(context)
                    ? Colors.black
                    : _WelcomePalette.decorativeLineArt(context))
                .withValues(
                  alpha: _WelcomePalette.isDark(context) ? 0.18 : 0.18,
                ),
            blurRadius: 10,
            offset: Offset(0, _WelcomePalette.isDark(context) ? 4 : 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: dims.scaleWidth(44),
            height: dims.scaleWidth(44),
            decoration: BoxDecoration(
              color: _WelcomePalette.badgeBackground(context),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: dims.scaleText(22),
              color: _WelcomePalette.accent,
            ),
          ),
          SizedBox(width: dims.scaleWidth(12)),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: dims.scaleText(12.5),
                height: 1.25,
                color: _WelcomePalette.secondaryText(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiPillLabel extends StatelessWidget {
  const _AiPillLabel();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(14),
        vertical: dims.scaleSpace(9),
      ),
      decoration: BoxDecoration(
        color: _WelcomePalette.surfaceStrong(
          context,
        ).withValues(alpha: _WelcomePalette.isDark(context) ? 0.92 : 0.42),
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        border: Border.all(color: _WelcomePalette.decorativeLineArt(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.onboardingAiBadge,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: dims.scaleText(14),
              fontWeight: FontWeight.w700,
              color: _WelcomePalette.primaryText(context),
              fontFamily: 'Georgia',
            ),
          ),
          SizedBox(width: dims.scaleWidth(8)),
          Icon(
            Icons.auto_awesome,
            size: dims.scaleText(14),
            color: _WelcomePalette.accent,
          ),
        ],
      ),
    );
  }
}

class _AiChatBubble extends StatelessWidget {
  const _AiChatBubble({
    required this.text,
    required this.alignRight,
    required this.widthFactor,
    this.highlighted = false,
  });

  final String text;
  final bool alignRight;
  final double widthFactor;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bubbleWidth = screenWidth * widthFactor;

    return Container(
      width: bubbleWidth.clamp(dims.scaleWidth(150), dims.scaleWidth(280)),
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(18),
        vertical: dims.scaleSpace(16),
      ),
      decoration: BoxDecoration(
        color:
            _WelcomePalette.isDark(context)
                ? (highlighted
                    ? const Color(0xFF2B1F25)
                    : const Color(0xFF241A20))
                : (highlighted
                    ? const Color(0xFFFFE7D8)
                    : const Color(0xFFFFF0E6)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(dims.scaleRadius(24)),
          topRight: Radius.circular(dims.scaleRadius(24)),
          bottomLeft: Radius.circular(dims.scaleRadius(alignRight ? 24 : 0)),
          bottomRight: Radius.circular(dims.scaleRadius(alignRight ? 0 : 24)),
        ),
        border: Border.all(color: _WelcomePalette.decorativeLineArt(context)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontSize: dims.scaleText(13),
          height: 1.6,
          color: _WelcomePalette.primaryText(context),
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
