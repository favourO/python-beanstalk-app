import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/design_tokens.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

BoxDecoration authBackgroundDecoration(BuildContext context) {
  final isLight = Theme.of(context).brightness == Brightness.light;
  return BoxDecoration(
    color: isLight ? const Color(0xFFFFF6F0) : const Color(0xFF120D13),
    image: DecorationImage(
      image: const AssetImage('assets/images/onboarding_background.png'),
      fit: BoxFit.cover,
      opacity: isLight ? 1 : 0.18,
      colorFilter:
          isLight
              ? null
              : const ColorFilter.mode(Color(0xE6120D13), BlendMode.darken),
    ),
  );
}

abstract final class _AuthPalette {
  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  static Color primaryText(BuildContext context) =>
      isLight(context) ? const Color(0xFF4A2C1A) : const Color(0xFFFFF3E8);

  static Color secondaryText(BuildContext context) =>
      isLight(context) ? const Color(0xFF8C5A42) : const Color(0xFFD6B8A7);

  static Color mutedText(BuildContext context) =>
      isLight(context) ? const Color(0xFFA88775) : const Color(0xFFB79DAB);

  static Color surface(BuildContext context) =>
      isLight(context)
          ? Colors.white.withValues(alpha: 0.84)
          : const Color(0xFF1C1520).withValues(alpha: 0.94);

  static Color border(BuildContext context) =>
      isLight(context) ? const Color(0xFFFFE0CE) : const Color(0xFF3B2C3E);

  static const accent = Color(0xFFFF8A4C);
}

void showAuthError(BuildContext context, Object error) {
  final message = switch (error) {
    ApiFailure failure => failure.message,
    String value => value,
    _ => () {
      final value = error.toString().trim();
      if (value.isEmpty ||
          value == 'Exception' ||
          value == 'Instance of Exception' ||
          value == 'Instance of Object') {
        return context.l10n.authGenericError;
      }
      return value.startsWith('Exception: ')
          ? value.substring('Exception: '.length)
          : value;
    }(),
  };

  showAuthToast(context, message: message, isError: true);
}

void showAuthSuccess(BuildContext context, String message) {
  showAuthToast(context, message: message);
}

void showAuthToast(
  BuildContext context, {
  required String message,
  bool isError = false,
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) {
    return;
  }

  final colors = context.phora.colors;
  final dims = context.dims;
  final entry = OverlayEntry(
    builder: (context) {
      return _AuthToastOverlay(
        message: message,
        isError: isError,
        colors: colors,
        dims: dims,
      );
    },
  );

  overlay.insert(entry);
  Future<void>.delayed(const Duration(seconds: 3), entry.remove);
}

class AuthBackButton extends StatelessWidget {
  const AuthBackButton({
    super.key,
    required this.fallbackLocation,
    this.label = 'Back',
  });

  final String fallbackLocation;
  final String label;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Material(
      color: _AuthPalette.surface(context),
      borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
        onTap: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(fallbackLocation);
          }
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dims.scaleWidth(12),
            vertical: dims.scaleSpace(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_rounded,
                color: _AuthPalette.primaryText(context),
                size: dims.scaleText(18),
              ),
              SizedBox(width: dims.scaleWidth(6)),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: dims.scaleText(13),
                  fontWeight: FontWeight.w700,
                  color: _AuthPalette.primaryText(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthSecondaryButton extends StatelessWidget {
  const AuthSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Material(
      color: _AuthPalette.surface(context),
      borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
        onTap: onPressed,
        child: SizedBox(
          height: dims.scaleHeight(50),
          width: double.infinity,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: dims.scaleText(14),
                color: _AuthPalette.primaryText(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontSize: dims.scaleText(15),
        fontWeight: FontWeight.w700,
        color: _AuthPalette.primaryText(context),
      ),
    );
  }
}

class _AuthToastOverlay extends StatelessWidget {
  const _AuthToastOverlay({
    required this.message,
    required this.isError,
    required this.colors,
    required this.dims,
  });

  final String message;
  final bool isError;
  final AppColors colors;
  final AppDimensions dims;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              dims.scaleWidth(20),
              dims.scaleSpace(16),
              dims.scaleWidth(20),
              0,
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(maxWidth: dims.scaleWidth(420)),
                padding: EdgeInsets.symmetric(
                  horizontal: dims.scaleWidth(16),
                  vertical: dims.scaleSpace(14),
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
                  border: Border.all(color: colors.accentDanger),
                  boxShadow: [
                    BoxShadow(
                      color: colors.textPrimary.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.accentDanger,
                    fontSize: dims.scaleText(14),
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthBrandBadge extends StatelessWidget {
  const AuthBrandBadge({super.key, this.size = 116});

  final double size;

  @override
  Widget build(BuildContext context) {
    return PhoraLogo(size: size);
  }
}

class PhoraLogo extends StatelessWidget {
  const PhoraLogo({super.key, this.size = 112});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final logoWidth = dims.scaleWidth(size * 1.72, min: 0.78, max: 1.2);
    final logoHeight = dims.scaleHeight(size * 0.78, min: 0.78, max: 1.2);

    return Center(
      child: SizedBox(
        width: logoWidth,
        height: logoHeight,
        child: Image.asset('assets/icons/phora_logo.png', fit: BoxFit.contain),
      ),
    );
  }
}

class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.label,
  });

  final Widget icon;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Material(
      color: _AuthPalette.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
        side: BorderSide(color: _AuthPalette.border(context), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
        onTap: onTap,
        child: SizedBox(
          height: dims.scaleHeight(74),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(18)),
            child:
                label == null
                    ? Center(child: icon)
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        icon,
                        SizedBox(width: dims.scaleWidth(12)),
                        Flexible(
                          child: Text(
                            label!,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              fontSize: dims.scaleText(14),
                              fontWeight: FontWeight.w700,
                              color: _AuthPalette.primaryText(context),
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}

class AuthSupportCard extends StatelessWidget {
  const AuthSupportCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      padding: EdgeInsets.all(dims.scaleWidth(16)),
      decoration: BoxDecoration(
        color: _AuthPalette.surface(context),
        borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
        border: Border.all(color: _AuthPalette.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: dims.scaleWidth(34),
            height: dims.scaleWidth(34),
            decoration: BoxDecoration(
              color: _AuthPalette.accent.withValues(
                alpha: _AuthPalette.isLight(context) ? 0.12 : 0.18,
              ),
              borderRadius: BorderRadius.circular(dims.scaleRadius(12)),
            ),
            child: Icon(
              icon,
              size: dims.scaleText(18),
              color: _AuthPalette.accent,
            ),
          ),
          SizedBox(width: dims.scaleWidth(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(14),
                    fontWeight: FontWeight.w700,
                    color: _AuthPalette.primaryText(context),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(4)),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(13),
                    color: _AuthPalette.secondaryText(context),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AuthOtpDigitField extends StatelessWidget {
  const AuthOtpDigitField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onKeyEvent,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return SizedBox(
      width: dims.scaleWidth(48),
      child: Focus(
        onKeyEvent: (_, event) {
          onKeyEvent(event);
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          maxLength: 6,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: dims.scaleText(22),
            color: _AuthPalette.primaryText(context),
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.symmetric(vertical: dims.scaleSpace(14)),
            fillColor: _AuthPalette.surface(context),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
              borderSide: BorderSide(color: _AuthPalette.border(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
              borderSide: const BorderSide(
                color: _AuthPalette.accent,
                width: 1.4,
              ),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.maxLines = 1,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final int maxLines;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      obscureText: obscureText,
      maxLines: maxLines,
      onSubmitted: onSubmitted,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: _AuthPalette.primaryText(context),
        fontSize: dims.scaleText(16),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: _AuthPalette.mutedText(context),
          fontSize: dims.scaleText(16),
        ),
        filled: true,
        fillColor: _AuthPalette.surface(context),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        contentPadding: EdgeInsets.symmetric(
          horizontal: dims.scaleWidth(20),
          vertical: dims.scaleSpace(18),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dims.scaleRadius(22)),
          borderSide: BorderSide(color: _AuthPalette.border(context)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
          borderSide: BorderSide(color: _AuthPalette.accent, width: 1.5),
        ),
      ),
    );
  }
}
