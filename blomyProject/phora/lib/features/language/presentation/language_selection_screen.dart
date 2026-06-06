import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phora/core/i18n/app_supported_locale.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/i18n/locale_controller.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key, this.settingsMode = false});

  final bool settingsMode;

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  bool _submitting = false;
  String? _selectedTag;
  bool _useDeviceLocale = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeState = ref.read(localeControllerProvider).valueOrNull;
    if (localeState == null || _selectedTag != null) {
      return;
    }
    _useDeviceLocale = localeState.useDeviceLocale;
    _selectedTag = localeState.activeLocale.tag;
  }

  Future<void> _saveSelection() async {
    if (_submitting) {
      return;
    }
    setState(() => _submitting = true);
    final controller = ref.read(localeControllerProvider.notifier);
    if (_useDeviceLocale) {
      await controller.useDeviceLocale();
    } else {
      final locale = AppSupportedLocale.fromTag(_selectedTag);
      if (locale != null) {
        await controller.setExplicitLocale(locale);
      }
    }
    await controller.markLanguageSelectionCompleted();
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (widget.settingsMode) {
      context.go('/you');
      return;
    }
    context.go('/splash');
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localeState = ref.watch(localeControllerProvider);
    final current = localeState.valueOrNull;

    if (current != null && _selectedTag == null) {
      _selectedTag = current.activeLocale.tag;
      _useDeviceLocale = current.useDeviceLocale;
    }

    final deviceSubtitle =
        current == null
            ? null
            : '${context.l10n.currentLanguageLabel}: ${current.activeLocale.nativeDisplayName}';

    return Scaffold(
      backgroundColor: _LanguageScreenPalette.background(context),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _LanguageScreenPalette.background(context),
              _LanguageScreenPalette.backgroundBottom(context),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(child: _LanguageBackdrop(isDark: isDark)),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      dims.scaleWidth(24),
                      dims.scaleSpace(16),
                      dims.scaleWidth(24),
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LanguageTopBar(
                          settingsMode: widget.settingsMode,
                          title: context.l10n.languageScreenTitle,
                        ),
                        SizedBox(height: dims.scaleSpace(5)),
                        _LanguageHero(
                          subtitle: context.l10n.languageScreenSubtitle,
                        ),
                        SizedBox(height: dims.scaleSpace(3)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        dims.scaleWidth(24),
                        dims.scaleSpace(26),
                        dims.scaleWidth(24),
                        dims.scaleSpace(24),
                      ),
                      children: [
                        _LanguageDeviceCard(
                          title: context.l10n.useDeviceLanguage,
                          subtitle: deviceSubtitle,
                          selected: _useDeviceLocale,
                          onTap: () => setState(() => _useDeviceLocale = true),
                        ),
                        SizedBox(height: dims.scaleSpace(28)),
                        Text(
                          context.l10n.languageSectionTitle,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontSize: dims.scaleText(16),
                            fontWeight: FontWeight.w700,
                            color: _LanguageScreenPalette.secondaryText(
                              context,
                            ),
                          ),
                        ),
                        SizedBox(height: dims.scaleSpace(14)),
                        ...AppSupportedLocale.all.map(
                          (locale) => Padding(
                            padding: EdgeInsets.only(
                              bottom: dims.scaleSpace(12),
                            ),
                            child: _LanguageOptionTile(
                              title: _displayName(context, locale),
                              subtitle: locale.nativeDisplayName,
                              badge: _localeBadge(locale),
                              selected:
                                  !_useDeviceLocale &&
                                  _selectedTag == locale.tag,
                              onTap: () {
                                setState(() {
                                  _useDeviceLocale = false;
                                  _selectedTag = locale.tag;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      dims.scaleWidth(24),
                      dims.scaleSpace(8),
                      dims.scaleWidth(24),
                      dims.scaleSpace(24),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submitting ? null : _saveSelection,
                        style: FilledButton.styleFrom(
                          backgroundColor: _LanguageScreenPalette.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            vertical: dims.scaleSpace(17),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              dims.scaleRadius(20),
                            ),
                          ),
                        ),
                        child: Text(
                          widget.settingsMode
                              ? context.l10n.saveLabel
                              : context.l10n.continueLabel,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontSize: dims.scaleText(16),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayName(BuildContext context, AppSupportedLocale locale) {
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

  String _localeBadge(AppSupportedLocale locale) {
    final countryCode = locale.countryCode;
    if (countryCode != null && countryCode.isNotEmpty) {
      return countryCode.toUpperCase();
    }
    return locale.languageCode.toUpperCase();
  }
}

abstract final class _LanguageScreenPalette {
  static const accent = Color(0xFFFF8A4C);

  static Color background(BuildContext context) {
    final colors = context.phora.colors;
    return Theme.of(context).brightness == Brightness.dark
        ? colors.bg
        : const Color(0xFFFFF6F0);
  }

  static Color backgroundBottom(BuildContext context) {
    final colors = context.phora.colors;
    return Theme.of(context).brightness == Brightness.dark
        ? colors.bgElevated
        : const Color(0xFFFFFBF7);
  }

  static Color primaryText(BuildContext context) {
    final colors = context.phora.colors;
    return Theme.of(context).brightness == Brightness.dark
        ? colors.textPrimary
        : const Color(0xFF4A2C1A);
  }

  static Color secondaryText(BuildContext context) {
    final colors = context.phora.colors;
    return Theme.of(context).brightness == Brightness.dark
        ? colors.textSecondary
        : const Color(0xFFA06A52);
  }

  static Color optionBackground(BuildContext context) {
    final colors = context.phora.colors;
    return Theme.of(context).brightness == Brightness.dark
        ? colors.bgSurface
        : const Color(0xFFFFEDE2);
  }

  static Color deviceBackground(BuildContext context) {
    final colors = context.phora.colors;
    return Theme.of(context).brightness == Brightness.dark
        ? colors.bgSurface.withValues(alpha: 0.92)
        : const Color(0xFFFFF0E5);
  }

  static Color selectedBackground(BuildContext context) {
    final colors = context.phora.colors;
    return Theme.of(context).brightness == Brightness.dark
        ? colors.bgCard
        : Colors.white;
  }

  static Color iconBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF3A2720)
        : const Color(0xFFFFE6D6);
  }

  static Color border(BuildContext context) {
    final colors = context.phora.colors;
    return Theme.of(context).brightness == Brightness.dark
        ? colors.borderStrong
        : const Color(0xFFFFD9C2);
  }

  static Color unselectedIndicator(BuildContext context) {
    final colors = context.phora.colors;
    return Theme.of(context).brightness == Brightness.dark
        ? colors.textTertiary
        : const Color(0xFFFFB78F);
  }
}

class _LanguageTopBar extends StatelessWidget {
  const _LanguageTopBar({required this.settingsMode, required this.title});

  final bool settingsMode;
  final String title;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return SizedBox(
      height: dims.scaleHeight(56),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.screenHeaderStyle(
            context,
            dims,
            color: _LanguageScreenPalette.primaryText(context),
          ),
        ),
      ),
    );
  }
}

class _LanguageHero extends StatelessWidget {
  const _LanguageHero({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: dims.scaleText(14),
            color: _LanguageScreenPalette.secondaryText(context),
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _LanguageDeviceCard extends StatelessWidget {
  const _LanguageDeviceCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return _LanguageCardShell(
      background:
          selected
              ? _LanguageScreenPalette.selectedBackground(context)
              : _LanguageScreenPalette.deviceBackground(context),
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          _LanguageIconBubble(
            child: Icon(
              Icons.language_rounded,
              color: _LanguageScreenPalette.accent,
              size: dims.scaleText(28),
            ),
          ),
          SizedBox(width: dims.scaleWidth(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: dims.scaleText(15),
                    fontWeight: FontWeight.w700,
                    color: _LanguageScreenPalette.primaryText(context),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  SizedBox(height: dims.scaleSpace(6)),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: dims.scaleText(12.5),
                      color: _LanguageScreenPalette.secondaryText(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _LanguageSelectionIndicator(selected: selected),
        ],
      ),
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return _LanguageCardShell(
      background:
          selected
              ? _LanguageScreenPalette.selectedBackground(context)
              : _LanguageScreenPalette.optionBackground(context),
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          _LanguageIconBubble(
            child: Text(
              badge,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: dims.scaleText(16),
                fontWeight: FontWeight.w700,
                color: _LanguageScreenPalette.accent,
              ),
            ),
          ),
          SizedBox(width: dims.scaleWidth(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: dims.scaleText(15),
                    fontWeight: FontWeight.w700,
                    color: _LanguageScreenPalette.primaryText(context),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(6)),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(12.5),
                    color: _LanguageScreenPalette.secondaryText(context),
                  ),
                ),
              ],
            ),
          ),
          _LanguageSelectionIndicator(selected: selected),
        ],
      ),
    );
  }
}

class _LanguageCardShell extends StatelessWidget {
  const _LanguageCardShell({
    required this.child,
    required this.background,
    required this.selected,
    required this.onTap,
  });

  final Widget child;
  final Color background;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.all(dims.scaleWidth(18)),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
            border: Border.all(
              color:
                  selected
                      ? _LanguageScreenPalette.accent
                      : _LanguageScreenPalette.border(context),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _LanguageScreenPalette.accent.withValues(
                  alpha: selected ? 0.10 : 0.04,
                ),
                blurRadius: selected ? 20 : 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _LanguageIconBubble extends StatelessWidget {
  const _LanguageIconBubble({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      width: dims.scaleWidth(52),
      height: dims.scaleWidth(52),
      decoration: BoxDecoration(
        color: _LanguageScreenPalette.iconBackground(context),
        shape: BoxShape.circle,
      ),
      child: Center(child: child),
    );
  }
}

class _LanguageSelectionIndicator extends StatelessWidget {
  const _LanguageSelectionIndicator({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      width: dims.scaleWidth(30),
      height: dims.scaleWidth(30),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color:
              selected
                  ? _LanguageScreenPalette.accent
                  : _LanguageScreenPalette.unselectedIndicator(context),
          width: 2,
        ),
      ),
      child:
          selected
              ? Center(
                child: Container(
                  width: dims.scaleWidth(12),
                  height: dims.scaleWidth(12),
                  decoration: const BoxDecoration(
                    color: _LanguageScreenPalette.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              )
              : null,
    );
  }
}

class _LanguageBackdrop extends StatelessWidget {
  const _LanguageBackdrop({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Stack(
      children: [
        Positioned(
          top: dims.scaleSpace(72),
          right: -dims.scaleWidth(38),
          child: _BackdropArc(
            size: dims.scaleWidth(240),
            color: _LanguageScreenPalette.border(
              context,
            ).withValues(alpha: isDark ? 0.46 : 0.85),
          ),
        ),
        Positioned(
          top: dims.scaleSpace(204),
          right: dims.scaleWidth(12),
          child: Icon(
            Icons.auto_awesome_outlined,
            color: _LanguageScreenPalette.border(
              context,
            ).withValues(alpha: isDark ? 0.42 : 0.8),
            size: dims.scaleText(26),
          ),
        ),
        Positioned(
          top: dims.scaleSpace(250),
          right: -dims.scaleWidth(46),
          child: _BackdropLeaf(
            height: dims.scaleHeight(320),
            color: _LanguageScreenPalette.border(
              context,
            ).withValues(alpha: isDark ? 0.38 : 0.78),
          ),
        ),
        Positioned(
          bottom: dims.scaleSpace(18),
          left: -dims.scaleWidth(12),
          child: Icon(
            Icons.auto_awesome_outlined,
            color: _LanguageScreenPalette.border(
              context,
            ).withValues(alpha: isDark ? 0.34 : 0.72),
            size: dims.scaleText(28),
          ),
        ),
      ],
    );
  }
}

class _BackdropArc extends StatelessWidget {
  const _BackdropArc({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size),
        border: Border.all(color: color),
      ),
    );
  }
}

class _BackdropLeaf extends StatelessWidget {
  const _BackdropLeaf({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return SizedBox(
      width: dims.scaleWidth(180),
      height: height,
      child: CustomPaint(painter: _LeafPainter(color: color)),
    );
  }
}

class _LeafPainter extends CustomPainter {
  const _LeafPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1;

    final stem =
        Path()
          ..moveTo(size.width * 0.88, 0)
          ..quadraticBezierTo(
            size.width * 0.56,
            size.height * 0.28,
            size.width * 0.82,
            size.height,
          );
    canvas.drawPath(stem, stroke);

    final leafA =
        Path()
          ..moveTo(size.width * 0.58, size.height * 0.18)
          ..quadraticBezierTo(
            size.width * 0.26,
            size.height * 0.26,
            size.width * 0.44,
            size.height * 0.40,
          )
          ..quadraticBezierTo(
            size.width * 0.62,
            size.height * 0.31,
            size.width * 0.58,
            size.height * 0.18,
          );
    canvas.drawPath(leafA, stroke);

    final leafB =
        Path()
          ..moveTo(size.width * 0.70, size.height * 0.40)
          ..quadraticBezierTo(
            size.width * 0.94,
            size.height * 0.34,
            size.width * 0.96,
            size.height * 0.56,
          )
          ..quadraticBezierTo(
            size.width * 0.84,
            size.height * 0.58,
            size.width * 0.70,
            size.height * 0.40,
          );
    canvas.drawPath(leafB, stroke);

    final leafC =
        Path()
          ..moveTo(size.width * 0.60, size.height * 0.64)
          ..quadraticBezierTo(
            size.width * 0.34,
            size.height * 0.74,
            size.width * 0.46,
            size.height * 0.88,
          )
          ..quadraticBezierTo(
            size.width * 0.66,
            size.height * 0.82,
            size.width * 0.60,
            size.height * 0.64,
          );
    canvas.drawPath(leafC, stroke);
  }

  @override
  bool shouldRepaint(covariant _LeafPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
