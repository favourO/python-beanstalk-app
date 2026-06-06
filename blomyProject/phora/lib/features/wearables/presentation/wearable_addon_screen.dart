import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phora/core/payments/payment_country_catalog.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/core/ui/phora_loading.dart';
import 'package:phora/features/auth/presentation/auth_ui.dart';
import 'package:phora/features/wearables/domain/wearable_order_models.dart';
import 'package:phora/features/wearables/providers/wearable_order_providers.dart';

class WearableAddonScreen extends ConsumerStatefulWidget {
  const WearableAddonScreen({
    super.key,
    required this.country,
    required this.planId,
    required this.interval,
    this.planName,
    this.planDisplayPrice,
    this.planCadence,
    this.standalone = false,
  });

  final String country;
  final String planId;
  final String interval;
  final String? planName;
  final String? planDisplayPrice;
  final String? planCadence;
  final bool standalone;

  @override
  ConsumerState<WearableAddonScreen> createState() =>
      _WearableAddonScreenState();
}

class _WearableAddonScreenState extends ConsumerState<WearableAddonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _line1Ctrl = TextEditingController();
  final _line2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countyCtrl = TextEditingController();
  final _postcodeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _addWearable = true;
  String _shippingCountry = 'United Kingdom';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _cityCtrl.dispose();
    _countyCtrl.dispose();
    _postcodeCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue(WearableAvailability availability) async {
    final effectiveAddWearable = _addWearable && availability.available;
    if (widget.standalone && !availability.available) {
      return;
    }
    if (widget.standalone &&
        effectiveAddWearable &&
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final address =
        widget.standalone && effectiveAddWearable
            ? ShippingAddress(
              fullName: _nameCtrl.text.trim(),
              line1: _line1Ctrl.text.trim(),
              line2:
                  _line2Ctrl.text.trim().isEmpty
                      ? null
                      : _line2Ctrl.text.trim(),
              city: _cityCtrl.text.trim(),
              county:
                  _countyCtrl.text.trim().isEmpty
                      ? null
                      : _countyCtrl.text.trim(),
              postcode: _postcodeCtrl.text.trim(),
              country: _shippingCountry,
              phone: _phoneCtrl.text.trim(),
            )
            : const ShippingAddress(country: 'GB');

    if (!context.mounted) return;
    context.push(
      '/wearable/checkout',
      extra: WearableCheckoutArgs(
        country: widget.country,
        planId: widget.planId,
        interval: widget.interval,
        planName: widget.planName,
        planDisplayPrice: widget.planDisplayPrice,
        planCadence: widget.planCadence,
        availability: availability,
        shippingAddress: address,
        addWearable: effectiveAddWearable,
        standalone: widget.standalone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final availabilityAsync = ref.watch(
      wearableAvailabilityProvider(widget.country),
    );

    return Scaffold(
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? colors.bg
              : const Color(0xFFFFFBF7),
      body: availabilityAsync.when(
        loading: () => const Center(child: PhoraLoadingIndicator()),
        error:
            (e, _) => Center(
              child: Padding(
                padding: EdgeInsets.all(dims.scaleWidth(24)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: colors.accentDanger,
                    ),
                    SizedBox(height: dims.scaleSpace(12)),
                    Text(
                      'Could not load wearable info',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: dims.scaleSpace(16)),
                    TextButton(
                      onPressed:
                          () => ref.invalidate(
                            wearableAvailabilityProvider(widget.country),
                          ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        data:
            (availability) => _Body(
              dims: dims,
              colors: colors,
              availability: availability,
              addWearable:
                  widget.standalone || (_addWearable && availability.available),
              formKey: _formKey,
              nameCtrl: _nameCtrl,
              line1Ctrl: _line1Ctrl,
              line2Ctrl: _line2Ctrl,
              cityCtrl: _cityCtrl,
              countyCtrl: _countyCtrl,
              postcodeCtrl: _postcodeCtrl,
              phoneCtrl: _phoneCtrl,
              country: _shippingCountry,
              onCountryChanged:
                  (value) => setState(() => _shippingCountry = value),
              onToggleWearable: (v) => setState(() => _addWearable = v),
              onContinue: () => _continue(availability),
              standalone: widget.standalone,
              interval: widget.interval,
              planName: widget.planName,
              planDisplayPrice: widget.planDisplayPrice,
              planCadence: widget.planCadence,
            ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.dims,
    required this.colors,
    required this.availability,
    required this.addWearable,
    required this.formKey,
    required this.nameCtrl,
    required this.line1Ctrl,
    required this.line2Ctrl,
    required this.cityCtrl,
    required this.countyCtrl,
    required this.postcodeCtrl,
    required this.phoneCtrl,
    required this.country,
    required this.onCountryChanged,
    required this.onToggleWearable,
    required this.onContinue,
    required this.standalone,
    required this.interval,
    required this.planName,
    required this.planDisplayPrice,
    required this.planCadence,
  });

  final AppDimensions dims;
  final dynamic colors;
  final WearableAvailability availability;
  final bool addWearable;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController line1Ctrl;
  final TextEditingController line2Ctrl;
  final TextEditingController cityCtrl;
  final TextEditingController countyCtrl;
  final TextEditingController postcodeCtrl;
  final TextEditingController phoneCtrl;
  final String country;
  final ValueChanged<String> onCountryChanged;
  final ValueChanged<bool> onToggleWearable;
  final VoidCallback onContinue;
  final bool standalone;
  final String interval;
  final String? planName;
  final String? planDisplayPrice;
  final String? planCadence;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = addWearable && availability.available;
    final wearablePriceLabel = _wearablePriceLabel(availability);
    final planTitle =
        standalone
            ? availability.productName
            : (planName ??
                (interval == 'year' ? 'Premium Annual' : 'Premium Monthly'));
    final rawPlanPrice =
        standalone ? wearablePriceLabel : (planDisplayPrice ?? '');
    final planPrice =
        rawPlanPrice.trim().isNotEmpty
            ? rawPlanPrice.trim()
            : _fallbackPlanPriceLabel(interval);
    final cadence =
        standalone
            ? 'One-time purchase'
            : (planCadence ?? (interval == 'year' ? '/ year' : '/ month'));
    final planAmount = standalone ? 0 : _minorFromDisplayPrice(planPrice);
    final totalMinor =
        (standalone ? 0 : planAmount) +
        (selected ? availability.priceMinor : 0);
    final totalLabel =
        totalMinor > 0
            ? '${availability.currencySymbol}${(totalMinor / 100).toStringAsFixed(2)}'
            : planPrice;

    return DecoratedBox(
      decoration: authBackgroundDecoration(context),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(24)),
              child: Column(
                children: [
                  SizedBox(height: dims.scaleSpace(4)),
                  _WearableFlowHeader(
                    title: standalone ? 'Your Vyla Wearable' : 'Almost there!',
                    onBack: () => _returnToPreviousPage(context),
                    dims: dims,
                    colors: colors,
                  ),
                  SizedBox(height: dims.scaleSpace(6)),
                  Text(
                    standalone
                        ? 'Purchase your wearable and track your delivery in the app.'
                        : 'Add the Vyla Wearable to unlock even \ndeeper insights into your health.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                      fontSize: dims.scaleText(10),
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: dims.scaleSpace(10)),
                ],
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: dims.scaleWidth(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (!standalone) ...[
                            Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.topCenter,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: dims.scaleSpace(11),
                                  ),
                                  child: _PlanSummaryCard(
                                    dims: dims,
                                    colors: colors,
                                    title: planTitle,
                                    price: planPrice,
                                    cadence: cadence,
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  child: _StepBadge(dims: dims),
                                ),
                              ],
                            ),
                            SizedBox(height: dims.scaleSpace(18)),
                          ],
                          _WearableAddonCard(
                            dims: dims,
                            colors: colors,
                            availability: availability,
                            selected: selected,
                            onToggle: onToggleWearable,
                            standalone: standalone,
                          ),
                          if (standalone &&
                              addWearable &&
                              availability.available) ...[
                            SizedBox(height: dims.scaleSpace(28)),
                            Text(
                              'SHIPPING ADDRESS',
                              style: Theme.of(
                                context,
                              ).textTheme.labelMedium?.copyWith(
                                color: colors.textSecondary,
                                fontSize: dims.scaleText(11),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(height: dims.scaleSpace(12)),
                            Form(
                              key: formKey,
                              child: Column(
                                children: [
                                  _Field(
                                    ctrl: nameCtrl,
                                    label: 'Full name',
                                    required: true,
                                  ),
                                  SizedBox(height: dims.scaleSpace(10)),
                                  _Field(
                                    ctrl: line1Ctrl,
                                    label: 'Address line 1',
                                    required: true,
                                  ),
                                  SizedBox(height: dims.scaleSpace(10)),
                                  _Field(
                                    ctrl: line2Ctrl,
                                    label: 'Address line 2 (optional)',
                                  ),
                                  SizedBox(height: dims.scaleSpace(10)),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _Field(
                                          ctrl: cityCtrl,
                                          label: 'City',
                                          required: true,
                                        ),
                                      ),
                                      SizedBox(width: dims.scaleWidth(10)),
                                      Expanded(
                                        child: _Field(
                                          ctrl: postcodeCtrl,
                                          label: 'Postcode',
                                          required: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: dims.scaleSpace(10)),
                                  _Field(
                                    ctrl: countyCtrl,
                                    label: 'County (optional)',
                                  ),
                                  SizedBox(height: dims.scaleSpace(10)),
                                  _CountryDropdown(
                                    value: country,
                                    onChanged: onCountryChanged,
                                  ),
                                  SizedBox(height: dims.scaleSpace(10)),
                                  _Field(
                                    ctrl: phoneCtrl,
                                    label: 'Phone',
                                    required: true,
                                    keyboardType: TextInputType.phone,
                                    helperText:
                                        'Use a valid UK number, e.g. 07123 456789 or +44 7123 456789',
                                    validator:
                                        (value) =>
                                            _isValidPhoneForCountry(
                                                  value,
                                                  country,
                                                )
                                                ? null
                                                : 'Enter a valid phone number',
                                  ),
                                ],
                              ),
                            ),
                          ],
                          SizedBox(height: dims.scaleSpace(16)),
                          _OrderSummaryCard(
                            dims: dims,
                            colors: colors,
                            planTitle: standalone ? null : planTitle,
                            planPrice:
                                standalone
                                    ? null
                                    : '$planPrice ${cadence.startsWith('/') ? cadence : ''}'
                                        .trim(),
                            wearableName:
                                selected ? availability.productName : null,
                            wearablePrice: selected ? wearablePriceLabel : null,
                            totalLabel: totalLabel,
                          ),
                          SizedBox(height: dims.scaleSpace(18)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: dims.scaleText(15),
                                color:
                                    isDark
                                        ? colors.textSecondary
                                        : const Color(0xFF9B6D5C),
                              ),
                              SizedBox(width: dims.scaleWidth(8)),
                              Text(
                                'Secure checkout powered by Stripe',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  fontSize: dims.scaleText(11),
                                  color:
                                      isDark
                                          ? colors.textSecondary
                                          : const Color(0xFF8A6B5E),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: dims.scaleSpace(18)),
                          SizedBox(
                            width: double.infinity,
                            height: dims.scaleSpace(56),
                            child: FilledButton(
                              onPressed:
                                  availability.available || !standalone
                                      ? onContinue
                                      : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B35),
                                disabledBackgroundColor: const Color(
                                  0xFFFF6B35,
                                ).withValues(alpha: 0.45),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    dims.scaleRadius(18),
                                  ),
                                ),
                              ),
                              child: SizedBox.expand(
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Center(
                                      child: Text(
                                        'Continue to Payment',
                                        style: TextStyle(
                                          fontSize: dims.scaleText(14),
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: dims.scaleWidth(2),
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        size: dims.scaleText(16),
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: dims.scaleSpace(24)),
                        ],
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
}

class _WearableFlowHeader extends StatelessWidget {
  const _WearableFlowHeader({
    required this.title,
    required this.onBack,
    required this.dims,
    required this.colors,
  });

  final String title;
  final VoidCallback onBack;
  final AppDimensions dims;
  final dynamic colors;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: onBack,
            child: Container(
              width: dims.scaleWidth(38),
              height: dims.scaleWidth(38),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isDark
                        ? colors.bgElevated
                        : Colors.white.withValues(alpha: 0.9),
                border: Border.all(
                  color: isDark ? colors.border : const Color(0xFFFFE2D4),
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: dims.scaleWidth(16),
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(44)),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFamily: 'Georgia',
              fontWeight: FontWeight.w500,
              fontSize: dims.scaleText(26),
              color: isDark ? colors.textPrimary : const Color(0xFF10212A),
            ),
          ),
        ),
      ],
    );
  }
}

class _WearableAddonCard extends StatelessWidget {
  const _WearableAddonCard({
    required this.dims,
    required this.colors,
    required this.availability,
    required this.selected,
    required this.onToggle,
    required this.standalone,
  });

  final AppDimensions dims;
  final dynamic colors;
  final WearableAvailability availability;
  final bool selected;
  final ValueChanged<bool> onToggle;
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inStock = availability.available;
    return GestureDetector(
      onTap: inStock ? () => onToggle(!selected) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color:
              isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
          border: Border.all(
            color:
                selected && inStock
                    ? const Color(0xFFFF9F7A)
                    : (isDark ? colors.border : const Color(0xFFFFDFD1)),
            width: selected && inStock ? 1.4 : 1,
          ),
          boxShadow:
              isDark
                  ? null
                  : const [
                    BoxShadow(
                      color: Color(0x0FC78862),
                      blurRadius: 32,
                      offset: Offset(0, 12),
                    ),
                  ],
        ),
        padding: EdgeInsets.fromLTRB(
          dims.scaleWidth(18),
          dims.scaleSpace(18),
          dims.scaleWidth(16),
          dims.scaleSpace(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (standalone || !inStock) ...[
                        _SmallPill(
                          dims: dims,
                          label:
                              inStock
                                  ? 'VYLA WEARABLE'
                                  : availability.isCountryBlocked
                                  ? 'NOT AVAILABLE IN YOUR REGION'
                                  : 'OUT OF STOCK',
                        ),
                        SizedBox(height: dims.scaleSpace(12)),
                      ],
                      Text(
                        'Add Vyla Wearable',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          fontFamily: 'Georgia',
                          fontSize: dims.scaleText(17),
                          height: 1,
                          fontWeight: FontWeight.w500,
                          color:
                              isDark
                                  ? colors.textPrimary
                                  : const Color(0xFF10212A),
                        ),
                      ),
                      SizedBox(height: dims.scaleSpace(10)),
                      Text(
                        'Track your body with precision and unlock the most accurate insights.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: dims.scaleText(9),
                          height: 1.35,
                          color:
                              isDark
                                  ? colors.textSecondary
                                  : const Color(0xFF765A50),
                        ),
                      ),
                      SizedBox(height: dims.scaleSpace(12)),
                      _BenefitLine(
                        dims: dims,
                        icon: Icons.thermostat_outlined,
                        title: 'Temperature',
                        subtitle: 'Track nightly skin temperature',
                      ),
                      _BenefitLine(
                        dims: dims,
                        icon: Icons.favorite_border_rounded,
                        title: 'HRV',
                        subtitle: 'Understand your recovery',
                      ),
                      _BenefitLine(
                        dims: dims,
                        icon: Icons.nightlight_round,
                        title: 'Sleep',
                        subtitle: 'Get deeper sleep insights',
                      ),
                      _BenefitLine(
                        dims: dims,
                        icon: Icons.bolt_outlined,
                        title: 'Recovery',
                        subtitle: 'Know when your body is ready',
                      ),
                    ],
                  ),
                ),
                SizedBox(width: dims.scaleWidth(8)),
                Align(
                  alignment: Alignment.topRight,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: dims.scaleWidth(32),
                    height: dims.scaleWidth(32),
                    decoration: BoxDecoration(
                      color:
                          selected && inStock
                              ? const Color(0xFFFF6B35)
                              : Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(dims.scaleRadius(8)),
                      border: Border.all(
                        color:
                            selected && inStock
                                ? const Color(0xFFFF6B35)
                                : const Color(0xFFFFB89B),
                      ),
                      boxShadow:
                          selected && !isDark
                              ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF6B35,
                                  ).withValues(alpha: 0.26),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                              : null,
                    ),
                    child:
                        selected && inStock
                            ? Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: dims.scaleText(22),
                            )
                            : null,
                  ),
                ),
              ],
            ),
            SizedBox(height: dims.scaleSpace(8)),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _wearablePriceLabel(availability),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: dims.scaleText(18),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFF6B35),
                    ),
                  ),
                ),
                _PricePill(dims: dims, label: 'One-time purchase'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.dims});

  final AppDimensions dims;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(18),
        vertical: dims.scaleSpace(6),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
        border: Border.all(color: const Color(0xFFFFDCCF)),
      ),
      child: Text(
        'STEP 2 OF 2',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: dims.scaleText(7.5),
          fontWeight: FontWeight.w800,
          color: const Color(0xFF8C5A42),
        ),
      ),
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({
    required this.dims,
    required this.colors,
    required this.title,
    required this.price,
    required this.cadence,
  });

  final AppDimensions dims;
  final dynamic colors;
  final String title;
  final String price;
  final String cadence;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(20),
        dims.scaleSpace(26),
        dims.scaleWidth(20),
        dims.scaleSpace(18),
      ),
      decoration: BoxDecoration(
        color:
            isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFFFDFD1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: dims.scaleWidth(56),
                height: dims.scaleWidth(56),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF8A54), Color(0xFFFF4D1F)],
                  ),
                ),
                child: Icon(
                  Icons.workspace_premium_outlined,
                  size: dims.scaleText(20),
                  color: Colors.white,
                ),
              ),
              SizedBox(width: dims.scaleWidth(4)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Plan',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: dims.scaleText(10),
                        color:
                            isDark
                                ? colors.textSecondary
                                : const Color(0xFF8C5A42),
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(3)),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: 'Georgia',
                        fontSize: dims.scaleText(16),
                        fontWeight: FontWeight.w700,
                        color:
                            isDark
                                ? colors.textPrimary
                                : const Color(0xFF10212A),
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(3)),
                    RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: price,
                            style: TextStyle(
                              fontSize: dims.scaleText(12),
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFFF6B35),
                            ),
                          ),
                          TextSpan(
                            text: ' $cadence',
                            style: TextStyle(
                              fontSize: dims.scaleText(8),
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark
                                      ? colors.textPrimary
                                      : const Color(0xFF10212A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(18)),
          Wrap(
            spacing: dims.scaleWidth(14),
            runSpacing: dims.scaleSpace(8),
            children: const [
              _MiniFeature(label: 'AI insights'),
              _MiniFeature(label: 'Vyla Wear'),
              _MiniFeature(label: 'Advanced reports'),
              _MiniFeature(label: 'Priority support'),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.dims,
    required this.colors,
    required this.planTitle,
    required this.planPrice,
    required this.wearableName,
    required this.wearablePrice,
    required this.totalLabel,
  });

  final AppDimensions dims;
  final dynamic colors;
  final String? planTitle;
  final String? planPrice;
  final String? wearableName;
  final String? wearablePrice;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(18)),
      decoration: BoxDecoration(
        color:
            isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFFFDFD1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontFamily: 'Georgia',
              fontSize: dims.scaleText(13),
              fontWeight: FontWeight.w700,
              color: isDark ? colors.textPrimary : const Color(0xFF2D170F),
            ),
          ),
          SizedBox(height: dims.scaleSpace(14)),
          if (planTitle != null && planPrice != null)
            _SummaryLine(dims: dims, label: planTitle!, value: planPrice!),
          if (wearableName != null && wearablePrice != null)
            _SummaryLine(
              dims: dims,
              label: wearableName!,
              value: wearablePrice!,
            ),
          Divider(
            height: dims.scaleSpace(28),
            color:
                isDark
                    ? colors.border.withValues(alpha: 0.5)
                    : const Color(0xFFFFE2D4),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  "Today's Total",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: dims.scaleText(11),
                    fontWeight: FontWeight.w800,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF10212A),
                  ),
                ),
              ),
              Text(
                totalLabel,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: dims.scaleText(18),
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFF6B35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.dims,
    required this.label,
    required this.value,
  });

  final AppDimensions dims;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: dims.scaleSpace(10)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: dims.scaleText(9),
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: dims.scaleText(9),
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniFeature extends StatelessWidget {
  const _MiniFeature({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: dims.scaleText(11),
          color: const Color(0xFFFF6B35),
        ),
        SizedBox(width: dims.scaleWidth(5)),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: dims.scaleText(7.5),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _BenefitLine extends StatelessWidget {
  const _BenefitLine({
    required this.dims,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final AppDimensions dims;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: dims.scaleSpace(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: dims.scaleWidth(34),
            height: dims.scaleWidth(34),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFFF0E8),
            ),
            child: Icon(
              icon,
              size: dims.scaleText(15),
              color: const Color(0xFFFF6B35),
            ),
          ),
          SizedBox(width: dims.scaleWidth(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(10.5),
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(2)),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(9),
                    color: colors.textSecondary,
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

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.dims, required this.label});

  final AppDimensions dims;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(10),
        vertical: dims.scaleSpace(5),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: dims.scaleText(7),
          height: 1,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFFF6B35),
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.dims, required this.label});

  final AppDimensions dims;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(12),
        vertical: dims.scaleSpace(5),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF6E9E1),
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: dims.scaleText(7),
          fontWeight: FontWeight.w700,
          color: const Color(0xFF8C5A42),
        ),
      ),
    );
  }
}

int _minorFromDisplayPrice(String value) {
  final match = RegExp(r'([0-9]+(?:[.,][0-9]{1,2})?)').firstMatch(value);
  if (match == null) return 0;
  final normalized = match.group(1)!.replaceAll(',', '.');
  final parsed = double.tryParse(normalized);
  if (parsed == null) return 0;
  return (parsed * 100).round();
}

void _returnToPreviousPage(BuildContext context) {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  } else {
    context.go('/subscription');
  }
}

String _wearablePriceLabel(WearableAvailability availability) {
  final direct = availability.displayPrice.trim();
  if (direct.isNotEmpty) return direct;
  if (availability.priceMinor <= 0) return '${availability.currencySymbol}0.00';
  return '${availability.currencySymbol}${(availability.priceMinor / 100).toStringAsFixed(2)}';
}

String _fallbackPlanPriceLabel(String interval) {
  return interval == 'year' ? '£35.00' : '£3.99';
}

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.label,
    this.required = false,
    this.keyboardType,
    this.helperText,
    this.validator,
  });

  final TextEditingController ctrl;
  final String label;
  final bool required;
  final TextInputType? keyboardType;
  final String? helperText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: TextStyle(
        fontSize: dims.scaleText(13.5),
        color: colors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 2,
        labelStyle: TextStyle(
          fontSize: dims.scaleText(12.5),
          color: colors.textSecondary,
        ),
        filled: true,
        fillColor: colors.bgElevated,
        contentPadding: EdgeInsets.symmetric(
          horizontal: dims.scaleWidth(14),
          vertical: dims.scaleSpace(12),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dims.scaleRadius(12)),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dims.scaleRadius(12)),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dims.scaleRadius(12)),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
        ),
      ),
      validator: (v) {
        if (required && (v == null || v.trim().isEmpty)) return 'Required';
        return validator?.call(v);
      },
    );
  }
}

class _CountryDropdown extends StatelessWidget {
  const _CountryDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final selected =
        supportedPaymentCountries.contains(value) ? value : 'United Kingdom';

    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      items:
          supportedPaymentCountries
              .map(
                (country) => DropdownMenuItem<String>(
                  value: country,
                  child: Text(
                    country,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: dims.scaleText(13.5),
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      decoration: InputDecoration(
        labelText: 'Country',
        labelStyle: TextStyle(
          fontSize: dims.scaleText(12.5),
          color: colors.textSecondary,
        ),
        filled: true,
        fillColor: colors.bgElevated,
        contentPadding: EdgeInsets.symmetric(
          horizontal: dims.scaleWidth(14),
          vertical: dims.scaleSpace(12),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dims.scaleRadius(12)),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dims.scaleRadius(12)),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(dims.scaleRadius(12)),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
        ),
      ),
    );
  }
}

bool _isValidPhoneForCountry(String? value, String? country) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return false;
  final compact = raw.replaceAll(RegExp(r'[\s().-]'), '');
  final normalizedCountry = (country ?? '').trim().toLowerCase();
  final isUk =
      normalizedCountry == 'gb' ||
      normalizedCountry == 'uk' ||
      normalizedCountry == 'united kingdom' ||
      normalizedCountry == 'great britain';
  if (isUk) {
    return RegExp(r'^(\+44|44|0)7\d{9}$').hasMatch(compact) ||
        RegExp(r'^(\+44|44|0)[1-3]\d{8,9}$').hasMatch(compact);
  }
  return RegExp(r'^\+?[1-9]\d{7,14}$').hasMatch(compact);
}

// Passed as extra to GoRouter for type-safe navigation
class WearableCheckoutArgs {
  const WearableCheckoutArgs({
    required this.country,
    required this.planId,
    required this.interval,
    this.planName,
    this.planDisplayPrice,
    this.planCadence,
    required this.availability,
    required this.shippingAddress,
    required this.addWearable,
    this.standalone = false,
  });

  final String country;
  final String planId;
  final String interval;
  final String? planName;
  final String? planDisplayPrice;
  final String? planCadence;
  final WearableAvailability availability;
  final ShippingAddress? shippingAddress;
  final bool addWearable;
  final bool standalone;
}
