import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phora/core/auth/age_gate.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/onboarding/data/onboarding_repository.dart';
import 'package:phora/features/profile/data/profile_repository.dart';
import 'package:phora/features/profile/domain/age_profile.dart';
import 'package:phora/features/profile/domain/user_profile.dart';
import 'package:phora/features/profile/profile_providers.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _birthdayController;
  late final TextEditingController _countryController;
  DateTime? _selectedBirthday;
  bool _dobVisible = false;
  bool _didSeedProfile = false;
  bool _didSeedAgeProfile = false;
  bool _didSeedCountry = false;
  bool _isSaving = false;
  bool _seedScheduled = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _birthdayController = TextEditingController();
    _countryController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _birthdayController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final l10n = context.l10n;
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _scheduleSeedProfile(profile);

    final ageProfile = ref.watch(ageProfileProvider).valueOrNull;
    _scheduleSeedAgeProfile(ageProfile);
    _scheduleSeedCountry();

    final pageBackground = isDark ? colors.bg : const Color(0xFFFFFBF7);
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: Stack(
          children: [
            if (!isDark) const _EditProfileBackdrop(),
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    dims.scaleWidth(20),
                    dims.scaleSpace(10),
                    dims.scaleWidth(20),
                    0,
                  ),
                  child: _TopBar(
                    title: l10n.editProfileLabel,
                    subtitle: l10n.editProfileHeaderSubtitle,
                    onBack: () => context.go('/you'),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      dims.scaleWidth(20),
                      dims.scaleSpace(14),
                      dims.scaleWidth(20),
                      dims.scaleSpace(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              SizedBox(height: dims.scaleSpace(2)),
                              Container(
                                width: dims.scaleWidth(138),
                                height: dims.scaleWidth(138),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient:
                                      isDark
                                          ? LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              colors.bgElevated,
                                              colors.bgSurface,
                                            ],
                                          )
                                          : const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFFFFE3D4),
                                              Color(0xFFFFF4ED),
                                            ],
                                          ),
                                  border: Border.all(
                                    color:
                                        isDark
                                            ? colors.borderStrong
                                            : const Color(0xFFFFE8DB),
                                    width: 8,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _initials(_fullNameController.text),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.displaySmall?.copyWith(
                                    fontSize: dims.scaleText(40),
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Georgia',
                                    color:
                                        isDark
                                            ? colors.textPrimary
                                            : const Color(0xFFC24715),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: dims.scaleSpace(28)),
                        _SectionHeading(title: l10n.editProfilePersonalInfo),
                        SizedBox(height: dims.scaleSpace(12)),
                        _SectionCard(
                          child: Column(
                            children: [
                              _DetailTile(
                                icon: Icons.person_outline_rounded,
                                title: l10n.editProfileFullNameLabel,
                                value:
                                    _fullNameController.text.trim().isEmpty
                                        ? l10n.notSetLabel
                                        : _fullNameController.text.trim(),
                                valueMuted:
                                    _fullNameController.text.trim().isEmpty,
                                onTap:
                                    () => _editTextValue(
                                      title: l10n.editProfileFullNameLabel,
                                      controller: _fullNameController,
                                      keyboardType: TextInputType.name,
                                    ),
                              ),
                              const _TileDivider(),
                              _DetailTile(
                                icon: Icons.mail_outline_rounded,
                                title: l10n.emailLabel,
                                value:
                                    _emailController.text.trim().isEmpty
                                        ? l10n.notSetLabel
                                        : _emailController.text.trim(),
                                onTap:
                                    () => _showReadOnlyHint(
                                      l10n.editProfileEmailReadOnlyHint,
                                    ),
                              ),
                              const _TileDivider(),
                              _DobDetailTile(
                                icon: Icons.calendar_today_outlined,
                                title: l10n.editProfileDateOfBirthLabel,
                                value:
                                    _birthdayController.text.trim().isEmpty
                                        ? l10n.notSetLabel
                                        : _birthdayController.text.trim(),
                                valueMuted:
                                    _birthdayController.text.trim().isEmpty,
                                visible: _dobVisible,
                                onToggleVisibility:
                                    _birthdayController.text.trim().isEmpty
                                        ? null
                                        : () => setState(
                                          () => _dobVisible = !_dobVisible,
                                        ),
                                onTap: _pickBirthday,
                              ),
                              const _TileDivider(),
                              _DetailTile(
                                icon: Icons.public_outlined,
                                title: l10n.editProfileCountryLabel,
                                value:
                                    _countryController.text.trim().isEmpty
                                        ? l10n.notSetLabel
                                        : _countryController.text.trim(),
                                valueMuted:
                                    _countryController.text.trim().isEmpty,
                                onTap:
                                    () => _editTextValue(
                                      title: l10n.editProfileCountryLabel,
                                      controller: _countryController,
                                      keyboardType: TextInputType.streetAddress,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: dims.scaleSpace(26)),
                        _SectionHeading(title: l10n.editProfileAccountSecurity),
                        SizedBox(height: dims.scaleSpace(12)),
                        _SectionCard(
                          child: _ActionTile(
                            icon: Icons.lock_outline_rounded,
                            title: l10n.passwordLabel,
                            subtitle: l10n.editProfilePasswordSubtitle,
                            actionLabel: l10n.updateLabel,
                            onTap: () => context.go('/you/change-password'),
                          ),
                        ),
                        SizedBox(height: dims.scaleSpace(28)),
                        _SaveButton(
                          isSaving: _isSaving,
                          label:
                              _isSaving
                                  ? l10n.savingLabel
                                  : l10n.editProfileSaveChanges,
                          onTap: _isSaving ? null : _saveProfile,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final l10n = context.l10n;
    setState(() => _isSaving = true);
    try {
      final dateOfBirth = _selectedBirthday;
      if (dateOfBirth != null &&
          !isAtLeastMinimumRegistrationAge(dateOfBirth)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.signUpAgeRestrictionError)));
        return;
      }
      await ref
          .read(onboardingRepositoryProvider)
          .submitProfile(
            fullName: _fullNameController.text.trim(),
            dateOfBirth: dateOfBirth,
            country: _countryController.text.trim(),
          );
      await ref
          .read(profileRepositoryProvider)
          .updateAgeProfile(dateOfBirth: dateOfBirth);
      await ref.read(currentUserProfileProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.editProfileUpdated)));
      context.go('/you');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickBirthday() async {
    final existing = _selectedBirthday;
    final now = DateTime.now();
    final latestAllowedDate = latestAllowedBirthDate(now: now);
    final picked = await showDatePicker(
      context: context,
      initialDate: clampBirthDateToRegistrationAge(
        existing ?? DateTime(now.year - 28, now.month, now.day),
        now: now,
      ),
      firstDate: DateTime(1900),
      lastDate: latestAllowedDate,
      helpText: context.l10n.editProfileSelectDateOfBirth,
    );
    if (picked == null || !mounted) return;
    if (!isAtLeastMinimumRegistrationAge(picked)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.signUpAgeRestrictionError)),
      );
      return;
    }
    setState(() {
      _selectedBirthday = picked;
      _birthdayController.text = _formatDate(context, picked);
    });
  }

  Future<void> _editTextValue({
    required String title,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) async {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final updated = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => _TextEditSheet(
            title: title,
            initialValue: controller.text.trim(),
            keyboardType: keyboardType,
            isDark: isDark,
            backgroundColor:
                isDark ? colors.bgElevated : const Color(0xFFFFFCF8),
            fieldFillColor: isDark ? colors.bgSurface : const Color(0xFFFFF5EF),
            dragHandleColor:
                isDark ? colors.borderStrong : const Color(0xFFD7C7BE),
            dims: dims,
          ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      controller.text = updated;
    });
  }

  void _showReadOnlyHint(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _scheduleSeedProfile(UserProfile? profile) {
    if (_didSeedProfile || _seedScheduled || profile == null) {
      return;
    }
    _seedScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedScheduled = false;
      if (!mounted || _didSeedProfile) {
        return;
      }
      setState(() {
        _didSeedProfile = true;
        _fullNameController.text = profile.fullName;
        _emailController.text = profile.email;
      });
    });
  }

  void _scheduleSeedAgeProfile(AgeProfile? ageProfile) {
    if (_didSeedAgeProfile || ageProfile == null) return;
    _didSeedAgeProfile = true;
    final dob = ageProfile.dateOfBirth;
    if (dob != null && _birthdayController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedBirthday = dob;
          _birthdayController.text = _formatDate(context, dob);
        });
      });
    }
  }

  void _scheduleSeedCountry() {
    if (_didSeedCountry) return;
    _didSeedCountry = true;
    ref.read(appPreferencesProvider).getBillingCountry().then((country) {
      if (!mounted || country == null || country.isEmpty) return;
      if (_countryController.text.isEmpty) {
        setState(() => _countryController.text = country);
      }
    });
  }
}

class _EditProfileBackdrop extends StatelessWidget {
  const _EditProfileBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -40,
            left: -36,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x19FFB08C), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
          Positioned(
            top: 90,
            right: -48,
            child: Container(
              width: 210,
              height: 210,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x12FF8E54), Color(0x00FFFFFF)],
                ),
              ),
            ),
          ),
          const Positioned(top: 126, right: 18, child: _FloralAccent()),
        ],
      ),
    );
  }
}

class _FloralAccent extends StatelessWidget {
  const _FloralAccent();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 166,
      child: CustomPaint(painter: _FloralAccentPainter()),
    );
  }
}

class _FloralAccentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x26E9A27B)
          ..strokeCap = StrokeCap.round;

    final stem =
        Path()
          ..moveTo(size.width * 0.74, size.height)
          ..quadraticBezierTo(
            size.width * 0.62,
            size.height * 0.70,
            size.width * 0.56,
            size.height * 0.48,
          )
          ..quadraticBezierTo(
            size.width * 0.48,
            size.height * 0.22,
            size.width * 0.30,
            0,
          );
    canvas.drawPath(stem, stroke);

    final leafA =
        Path()
          ..moveTo(size.width * 0.58, size.height * 0.74)
          ..quadraticBezierTo(
            size.width * 0.28,
            size.height * 0.62,
            size.width * 0.14,
            size.height * 0.44,
          )
          ..quadraticBezierTo(
            size.width * 0.34,
            size.height * 0.52,
            size.width * 0.58,
            size.height * 0.74,
          );
    canvas.drawPath(leafA, stroke);

    final leafB =
        Path()
          ..moveTo(size.width * 0.58, size.height * 0.62)
          ..quadraticBezierTo(
            size.width * 0.84,
            size.height * 0.54,
            size.width * 0.92,
            size.height * 0.30,
          )
          ..quadraticBezierTo(
            size.width * 0.74,
            size.height * 0.42,
            size.width * 0.58,
            size.height * 0.62,
          );
    canvas.drawPath(leafB, stroke);

    void drawBloom(Offset center, double scale) {
      for (final angle in <double>[0, 1.2, 2.4]) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle);
        final petal =
            Path()
              ..moveTo(0, 0)
              ..quadraticBezierTo(-14 * scale, -12 * scale, 0, -28 * scale)
              ..quadraticBezierTo(14 * scale, -12 * scale, 0, 0);
        canvas.drawPath(petal, stroke);
        canvas.restore();
      }
    }

    drawBloom(Offset(size.width * 0.28, size.height * 0.20), 1.0);
    drawBloom(Offset(size.width * 0.52, size.height * 0.42), 0.88);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: isDark ? colors.bgElevated : const Color(0xFFFFF4ED),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onBack,
            child: Padding(
              padding: EdgeInsets.all(dims.scaleWidth(16)),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: dims.scaleText(20),
                color: isDark ? colors.textPrimary : const Color(0xFF5A2A18),
              ),
            ),
          ),
        ),
        SizedBox(width: dims.scaleWidth(12)),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              top: dims.scaleSpace(8),
              right: dims.scaleWidth(56),
            ),
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: dims.scaleText(32),
                    height: 1,
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.w500,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF2D170F),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(10)),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(13),
                    height: 1.45,
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF7F6357),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontSize: dims.scaleText(18),
        fontWeight: FontWeight.w700,
        color: isDark ? colors.textPrimary : const Color(0xFF21140F),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(14),
        vertical: dims.scaleSpace(10),
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(dims.scaleRadius(28)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF0E1D7),
        ),
        boxShadow:
            isDark
                ? null
                : const [
                  BoxShadow(
                    color: Color(0x08C78862),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
      ),
      child: child,
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.valueMuted = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool valueMuted;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(12)),
          child: Row(
            children: [
              _IconBadge(icon: icon),
              SizedBox(width: dims.scaleWidth(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: dims.scaleText(13),
                        color:
                            isDark
                                ? colors.textSecondary
                                : const Color(0xFF7F6357),
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(6)),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: dims.scaleText(16),
                        fontWeight: FontWeight.w700,
                        color:
                            valueMuted
                                ? (isDark
                                    ? colors.textTertiary
                                    : const Color(0xFFA39A95))
                                : (isDark
                                    ? colors.textPrimary
                                    : const Color(0xFF21140F)),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: dims.scaleWidth(10)),
              Icon(
                Icons.chevron_right_rounded,
                size: dims.scaleText(26),
                color: isDark ? colors.textTertiary : const Color(0xFF9C8E86),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DobDetailTile extends StatelessWidget {
  const _DobDetailTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.visible,
    required this.onTap,
    this.valueMuted = false,
    this.onToggleVisibility,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool visible;
  final bool valueMuted;
  final VoidCallback onTap;
  final VoidCallback? onToggleVisibility;

  static const _mask = '●●●● ●● ●●';

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayValue = valueMuted ? value : (visible ? value : _mask);
    final textColor =
        valueMuted
            ? (isDark ? colors.textTertiary : const Color(0xFFA39A95))
            : (isDark ? colors.textPrimary : const Color(0xFF21140F));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(12)),
          child: Row(
            children: [
              _IconBadge(icon: icon),
              SizedBox(width: dims.scaleWidth(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: dims.scaleText(13),
                        color:
                            isDark
                                ? colors.textSecondary
                                : const Color(0xFF7F6357),
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(6)),
                    Text(
                      displayValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: dims.scaleText(16),
                        fontWeight: FontWeight.w700,
                        letterSpacing: valueMuted || visible ? null : 1.5,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (onToggleVisibility != null) ...[
                SizedBox(width: dims.scaleWidth(4)),
                GestureDetector(
                  onTap: onToggleVisibility,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.all(dims.scaleWidth(6)),
                    child: Icon(
                      visible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: dims.scaleText(20),
                      color:
                          isDark
                              ? colors.textSecondary
                              : const Color(0xFF9C8E86),
                    ),
                  ),
                ),
              ] else
                SizedBox(width: dims.scaleWidth(10)),
              Icon(
                Icons.chevron_right_rounded,
                size: dims.scaleText(26),
                color: isDark ? colors.textTertiary : const Color(0xFF9C8E86),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(12)),
          child: Row(
            children: [
              _IconBadge(icon: icon),
              SizedBox(width: dims.scaleWidth(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: dims.scaleText(16),
                        fontWeight: FontWeight.w700,
                        color:
                            isDark
                                ? colors.textPrimary
                                : const Color(0xFF21140F),
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(4)),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: dims.scaleText(13),
                        height: 1.45,
                        color:
                            isDark
                                ? colors.textSecondary
                                : const Color(0xFF7F6357),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: dims.scaleWidth(12)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dims.scaleWidth(16),
                  vertical: dims.scaleSpace(10),
                ),
                decoration: BoxDecoration(
                  color: isDark ? colors.bgSurface : const Color(0xFFFFF1EA),
                  borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
                ),
                child: Text(
                  actionLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: dims.scaleText(12.5),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFF7C45),
                  ),
                ),
              ),
              SizedBox(width: dims.scaleWidth(8)),
              Icon(
                Icons.chevron_right_rounded,
                size: dims.scaleText(24),
                color: isDark ? colors.textTertiary : const Color(0xFF9C8E86),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: dims.scaleWidth(48),
      height: dims.scaleWidth(48),
      decoration: BoxDecoration(
        color: isDark ? colors.bgSurface : const Color(0xFFFFF4ED),
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        border: isDark ? Border.all(color: colors.border) : null,
      ),
      child: Icon(
        icon,
        color: const Color(0xFFFF7C45),
        size: dims.scaleText(24),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(left: context.dims.scaleWidth(62)),
      child: Divider(
        height: 1,
        color: isDark ? colors.border : const Color(0xFFF3E8E1),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.label,
    required this.onTap,
    required this.isSaving,
  });

  final String label;
  final VoidCallback? onTap;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7A3D), Color(0xFFFF6A2E)],
        ),
        borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24FF8B52),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(18)),
            child: Center(
              child:
                  isSaving
                      ? SizedBox(
                        width: dims.scaleWidth(18),
                        height: dims.scaleWidth(18),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : Text(
                        label,
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
      ),
    );
  }
}

class _TextEditSheet extends StatefulWidget {
  const _TextEditSheet({
    required this.title,
    required this.initialValue,
    required this.keyboardType,
    required this.isDark,
    required this.backgroundColor,
    required this.fieldFillColor,
    required this.dragHandleColor,
    required this.dims,
  });

  final String title;
  final String initialValue;
  final TextInputType? keyboardType;
  final bool isDark;
  final Color backgroundColor;
  final Color fieldFillColor;
  final Color dragHandleColor;
  final AppDimensions dims;

  @override
  State<_TextEditSheet> createState() => _TextEditSheetState();
}

class _TextEditSheetState extends State<_TextEditSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dims = widget.dims;
    final colors = context.phora.colors;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          padding: EdgeInsets.fromLTRB(
            dims.scaleWidth(20),
            dims.scaleSpace(20),
            dims.scaleWidth(20),
            dims.scaleSpace(20),
          ),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(dims.scaleRadius(28)),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: dims.scaleWidth(48),
                    height: dims.scaleSpace(5),
                    decoration: BoxDecoration(
                      color: widget.dragHandleColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(18)),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: dims.scaleText(28),
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.w500,
                    color:
                        widget.isDark
                            ? context.phora.colors.textPrimary
                            : const Color(0xFF2D170F),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(6)),
                Text(
                  context.l10n.editProfileSheetSubtitle(widget.title),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(13),
                    color:
                        widget.isDark
                            ? context.phora.colors.textSecondary
                            : const Color(0xFF7F6357),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(18)),
                TextField(
                  controller: _controller,
                  keyboardType: widget.keyboardType,
                  autofocus: true,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(16),
                    fontWeight: FontWeight.w600,
                    color:
                        widget.isDark
                            ? context.phora.colors.textPrimary
                            : const Color(0xFF2F1C14),
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: widget.fieldFillColor,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: dims.scaleWidth(18),
                      vertical: dims.scaleSpace(16),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
                      borderSide: BorderSide(
                        color:
                            widget.isDark ? colors.border : Colors.transparent,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
                      borderSide: const BorderSide(color: Color(0xFFFF7C45)),
                    ),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(18)),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.l10n.cancelLabel),
                      ),
                    ),
                    SizedBox(width: dims.scaleWidth(12)),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7C45),
                          foregroundColor: Colors.white,
                        ),
                        onPressed:
                            () => Navigator.of(
                              context,
                            ).pop(_controller.text.trim()),
                        child: Text(context.l10n.saveLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _initials(String fullName) {
  final parts =
      fullName
          .trim()
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .toList();
  if (parts.isEmpty) {
    return 'P';
  }
  if (parts.length == 1) {
    return parts.first
        .substring(0, parts.first.length.clamp(1, 2))
        .toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

String _formatDate(BuildContext context, DateTime date) {
  return DateFormat.yMMMMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).format(date);
}
