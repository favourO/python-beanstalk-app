import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PrivacyChoiceScreen extends ConsumerStatefulWidget {
  const PrivacyChoiceScreen({super.key});

  @override
  ConsumerState<PrivacyChoiceScreen> createState() =>
      _PrivacyChoiceScreenState();
}

class _PrivacyChoiceScreenState extends ConsumerState<PrivacyChoiceScreen> {
  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authSessionProvider);
    final isBusy = authState.isLoading;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF120D13) : const Color(0xFFFFF6F0),
        ),
        child: Stack(
          children: [
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
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      dims.scaleWidth(24),
                      dims.scaleSpace(12),
                      dims.scaleWidth(24),
                      dims.scaleSpace(18),
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: dims.scaleSpace(6)),
                        _PrivacyChoiceHero(isDark: isDark),
                        SizedBox(height: dims.scaleSpace(18)),
                        Text(
                          context.l10n.privacyChoiceTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.displayLarge?.copyWith(
                            fontSize: dims.scaleText(31),
                            height: 1.08,
                            color:
                                isDark
                                    ? const Color(0xFFFFF3E8)
                                    : const Color(0xFF4A2C1A),
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Georgia',
                          ),
                        ),
                        SizedBox(height: dims.scaleSpace(12)),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: dims.scaleWidth(18),
                          ),
                          child: Text(
                            'Create an account with email to keep your Vyla data synced and recoverable.',
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              fontSize: dims.scaleText(13),
                              height: 1.55,
                              color:
                                  isDark
                                      ? const Color(0xFFD6B8A7)
                                      : const Color(0xFF8C5A42),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        SizedBox(height: dims.scaleSpace(20)),
                        _PrivacyChoiceCard(
                          title: context.l10n.privacyChoiceEmailTitle,
                          badge: context.l10n.privacyChoiceEmailBadge,
                          description:
                              context.l10n.privacyChoiceEmailDescription,
                          isSelected: true,
                          isDark: isDark,
                          onTap: () {},
                        ),
                        const Spacer(),
                        _PrivacyChoicePrimaryButton(
                          label: context.l10n.privacyChoiceEmailCta,
                          onTap: isBusy ? null : () => context.go('/sign-up'),
                        ),
                        SizedBox(height: dims.scaleSpace(16)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              context.l10n.privacyChoiceExistingAccountPrompt,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(
                                fontSize: dims.scaleText(14),
                                color:
                                    isDark
                                        ? const Color(0xFFD6B8A7)
                                        : const Color(0xFF8C5A42),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                debugPrint(
                                  '[AuthNav] Existing account Sign in tapped -> /sign-in',
                                );
                                context.go('/sign-in');
                              },
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: EdgeInsets.symmetric(
                                  horizontal: dims.scaleWidth(6),
                                  vertical: dims.scaleSpace(4),
                                ),
                              ),
                              child: Text(
                                context.l10n.signInLinkLabel,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  fontSize: dims.scaleText(14),
                                  color: const Color(0xFFFF8A4C),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: dims.scaleSpace(4)),
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

class _PrivacyChoiceHero extends StatelessWidget {
  const _PrivacyChoiceHero({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      width: dims.scaleWidth(172),
      height: dims.scaleWidth(172),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFF241B29) : const Color(0xFFFFEBDC),
        boxShadow: [
          BoxShadow(
            color: (isDark ? const Color(0xFFFF8A4C) : const Color(0xFFFFE6D6))
                .withValues(alpha: isDark ? 0.18 : 0.36),
            blurRadius: isDark ? 28 : 22,
            offset: Offset(0, isDark ? 14 : 10),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: dims.scaleText(82),
        color: const Color(0xFFFF8A4C),
      ),
    );
  }
}

class _PrivacyChoiceCard extends StatelessWidget {
  const _PrivacyChoiceCard({
    required this.title,
    required this.badge,
    required this.description,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String title;
  final String badge;
  final String description;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            dims.scaleWidth(18),
            dims.scaleSpace(18),
            dims.scaleWidth(18),
            dims.scaleSpace(18),
          ),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF1C1520) : Colors.white).withValues(
              alpha: isDark ? 0.94 : 0.86,
            ),
            borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
            border: Border.all(
              color:
                  isSelected
                      ? const Color(0xFFFF8A4C)
                      : (isDark
                          ? const Color(0xFF3B2C3E)
                          : const Color(0xFFFFE6D6)),
              width: isSelected ? 2 : 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : const Color(0xFFFFE6D6))
                    .withValues(alpha: isDark ? 0.22 : 0.14),
                blurRadius: isDark ? 14 : 10,
                offset: Offset(0, isDark ? 6 : 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PrivacyChoiceRadio(isSelected: isSelected, isDark: isDark),
              SizedBox(width: dims.scaleWidth(16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              fontSize: dims.scaleText(17),
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark
                                      ? const Color(0xFFFFF3E8)
                                      : const Color(0xFF4A2C1A),
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: dims.scaleWidth(10),
                            vertical: dims.scaleSpace(6),
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? const Color(0xFF312329)
                                    : const Color(0xFFFFF0E6),
                            borderRadius: BorderRadius.circular(
                              dims.scaleRadius(999),
                            ),
                            border: Border.all(
                              color:
                                  isDark
                                      ? const Color(0xFF4A394D)
                                      : const Color(0xFFFFE0CE),
                            ),
                          ),
                          child: Text(
                            badge,
                            style: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(
                              fontSize: dims.scaleText(9.8),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color:
                                  isSelected
                                      ? const Color(0xFFFF8A4C)
                                      : (isDark
                                          ? const Color(0xFFD6B8A7)
                                          : const Color(0xFF8C5A42)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: dims.scaleSpace(12)),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: dims.scaleText(13.2),
                        height: 1.5,
                        color:
                            isDark
                                ? const Color(0xFFD6B8A7)
                                : const Color(0xFF8C5A42),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyChoiceRadio extends StatelessWidget {
  const _PrivacyChoiceRadio({required this.isSelected, required this.isDark});

  final bool isSelected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      width: dims.scaleWidth(28),
      height: dims.scaleWidth(28),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color:
              isSelected
                  ? const Color(0xFFFF8A4C)
                  : (isDark
                      ? const Color(0xFF8E7180)
                      : const Color(0xFFD9B8A4)),
          width: 2.2,
        ),
      ),
      alignment: Alignment.center,
      child:
          isSelected
              ? Container(
                width: dims.scaleWidth(12),
                height: dims.scaleWidth(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF8A4C),
                  shape: BoxShape.circle,
                ),
              )
              : null,
    );
  }
}

class _PrivacyChoicePrimaryButton extends StatelessWidget {
  const _PrivacyChoicePrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final enabled = onTap != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFFF8A4C) : const Color(0xFFFFC6A7),
        borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFFFF8A4C,
            ).withValues(alpha: enabled ? 0.26 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
          onTap: onTap,
          child: SizedBox(
            height: dims.scaleHeight(56),
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(28)),
              child: Row(
                children: [
                  const Spacer(),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: dims.scaleText(16),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: dims.scaleText(24),
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
