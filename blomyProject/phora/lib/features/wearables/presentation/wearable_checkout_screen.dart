import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:go_router/go_router.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/payments/payment_country_catalog.dart';
import 'package:phora/core/payments/stripe_wallet_config.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/auth/presentation/auth_ui.dart';
import 'package:phora/features/wearables/domain/wearable_order_models.dart';
import 'package:phora/features/wearables/presentation/wearable_addon_screen.dart';
import 'package:phora/features/wearables/presentation/wearable_order_confirmed_screen.dart';
import 'package:phora/features/wearables/providers/wearable_order_providers.dart';

const _reviewOrderEstimatedDeliveryBg = Color(0xFFFFE6D8);
const _reviewOrderAccent = Color(0xFFFF6B35);

class WearableCheckoutScreen extends ConsumerStatefulWidget {
  const WearableCheckoutScreen({super.key, required this.args});

  final WearableCheckoutArgs args;

  @override
  ConsumerState<WearableCheckoutScreen> createState() =>
      _WearableCheckoutScreenState();
}

class _WearableCheckoutScreenState
    extends ConsumerState<WearableCheckoutScreen> {
  bool _processing = false;
  String? _error;
  ShippingAddress? _shippingAddress;

  ShippingAddress get _effectiveShippingAddress =>
      _shippingAddress ??
      widget.args.shippingAddress ??
      const ShippingAddress(country: 'GB');

  @override
  void initState() {
    super.initState();
    _shippingAddress = _effectiveShippingAddress;
  }

  bool get _hasRequiredShippingAddress {
    final address = _effectiveShippingAddress;
    return address.fullName?.trim().isNotEmpty == true &&
        address.line1?.trim().isNotEmpty == true &&
        address.city?.trim().isNotEmpty == true &&
        address.country?.trim().isNotEmpty == true &&
        address.postcode?.trim().isNotEmpty == true &&
        _isValidPhoneForCountry(address.phone, address.country);
  }

  Future<void> _editShippingAddress() async {
    final result = await showModalBottomSheet<ShippingAddress>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) =>
              _ShippingAddressSheet(initialAddress: _effectiveShippingAddress),
    );
    if (result == null || !mounted) return;
    setState(() {
      _shippingAddress = result;
      _error = null;
    });
  }

  Future<void> _pay() async {
    if (_processing) return;
    final args = widget.args;
    final wearableSelected =
        (args.standalone || args.addWearable) && args.availability.available;
    if (wearableSelected && !_hasRequiredShippingAddress) {
      if (!mounted) return;
      setState(() => _error = 'Enter your shipping address before payment.');
      await _editShippingAddress();
      return;
    }
    if (!mounted) return;
    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final wearableSku = wearableSelected ? args.availability.sku : '';

      final address =
          wearableSku.isNotEmpty
              ? _effectiveShippingAddress
              : const ShippingAddress(country: 'GB');

      final session = await ref
          .read(wearableCheckoutProvider.notifier)
          .createCheckout(
            WearableCheckoutInput(
              country: args.country,
              planId: args.planId,
              interval: args.interval,
              wearableSku: wearableSku,
              shippingAddress: address,
              standalone: args.standalone,
            ),
          );

      if (session == null) {
        final errMsg = ref.read(wearableCheckoutProvider).error;
        if (!mounted) return;
        setState(() {
          _processing = false;
          _error = errMsg ?? 'Could not start checkout. Please try again.';
        });
        return;
      }

      if (!context.mounted) return;

      stripe.Stripe.publishableKey = session.publishableKey;
      stripe.Stripe.merchantIdentifier = stripeApplePayMerchantIdentifier;
      stripe.Stripe.urlScheme = 'vyla';
      stripe.Stripe.setReturnUrlSchemeOnAndroid = true;
      await stripe.Stripe.instance.applySettings();

      await stripe.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: stripe.SetupPaymentSheetParameters(
          paymentIntentClientSecret: session.paymentIntentClientSecret,
          customerEphemeralKeySecret: session.customerEphemeralKeySecret,
          customerId: session.customerId,
          merchantDisplayName: 'Vyla',
          applePay: stripePaymentSheetApplePay,
          googlePay: stripePaymentSheetGooglePay,
          style: ThemeMode.system,
        ),
      );

      await stripe.Stripe.instance.presentPaymentSheet();

      // Payment confirmed by Stripe — backend confirm errors must not block navigation.
      WearableOrder? confirmedOrder;
      if (wearableSku.isNotEmpty &&
          session.providerPaymentIntentId.isNotEmpty) {
        try {
          final confirmedOrders = await ref
              .read(wearableOrderRepositoryProvider)
              .confirmCheckout(session: session, shippingAddress: address);
          confirmedOrder = _bestConfirmedOrder(confirmedOrders, wearableSku);
        } catch (_) {
          // Backend confirm failed but Stripe payment succeeded — proceed.
        }
      }

      await ref.read(currentSubscriptionProvider.notifier).refresh();
      ref.invalidate(myWearableOrdersProvider);

      if (!mounted) return;
      if (!context.mounted) return;

      if (confirmedOrder != null || wearableSku.isNotEmpty) {
        context.pushReplacement(
          '/wearable/order-confirmed',
          extra: WearableOrderConfirmedArgs(
            session: session,
            order: confirmedOrder,
          ),
        );
      } else {
        context.pushReplacement('/subscription');
      }
    } on stripe.StripeException catch (e) {
      if (e.error.code == stripe.FailureCode.Canceled) {
        if (!mounted) return;
        setState(() => _processing = false);
        return;
      }
      // Session may be expired because payment already went through.
      // Refresh subscription and redirect if active.
      try {
        await ref.read(currentSubscriptionProvider.notifier).refresh();
        if (!mounted) return;
        final sub = ref.read(currentSubscriptionProvider).valueOrNull;
        if (sub != null && (sub.isActive || sub.hasPaidAccess)) {
          context.pushReplacement('/subscription');
          return;
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error =
            e.error.localizedMessage ?? e.error.message ?? 'Payment failed.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final args = widget.args;
    final checkoutState = ref.watch(wearableCheckoutProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final planName =
        args.planName ??
        'Premium ${args.interval == 'year' ? 'Annual' : 'Monthly'}';
    final planPrice = _planPriceLabel(args);
    final planCadence =
        args.planCadence ?? (args.interval == 'year' ? '/ year' : '/ month');
    final wearableSelected =
        (args.standalone || args.addWearable) && args.availability.available;
    final canPay =
        !_processing &&
        !checkoutState.isLoading &&
        (!wearableSelected || _hasRequiredShippingAddress);
    final wearablePrice = _wearablePriceLabel(args.availability);
    final subscriptionMinor =
        args.standalone ? 0 : _minorFromDisplayPrice(planPrice);
    final wearableMinor = wearableSelected ? args.availability.priceMinor : 0;
    final totalMinor = subscriptionMinor + wearableMinor;
    final totalLabel =
        totalMinor > 0
            ? '${args.availability.currencySymbol}${(totalMinor / 100).toStringAsFixed(2)}'
            : (args.standalone ? wearablePrice : planPrice);
    final primaryActionNeedsAddress =
        wearableSelected && !_hasRequiredShippingAddress;
    final primaryActionBackground =
        primaryActionNeedsAddress
            ? _reviewOrderEstimatedDeliveryBg
            : _reviewOrderAccent;
    final primaryActionForeground =
        primaryActionNeedsAddress ? _reviewOrderAccent : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? colors.bg : const Color(0xFFFFFBF7),
      body: DecoratedBox(
        decoration: authBackgroundDecoration(context),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(24)),
                child: Column(
                  children: [
                    SizedBox(height: dims.scaleSpace(4)),
                    _CheckoutHeader(
                      dims: dims,
                      colors: colors,
                      onBack: () => _returnToPreviousPage(context),
                    ),
                    if (!args.standalone) ...[
                      SizedBox(height: dims.scaleSpace(18)),
                      _CheckoutStepper(dims: dims),
                      SizedBox(height: dims.scaleSpace(8)),
                    ] else
                      SizedBox(height: dims.scaleSpace(8)),
                    Text(
                      args.standalone
                          ? 'Review your wearable delivery details before payment.'
                          : "You're one step away from unlocking\npremium insights and advanced tracking.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            isDark
                                ? colors.textSecondary
                                : const Color(0xFF765A50),
                        fontSize: dims.scaleText(11),
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(14)),
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
                            _YourOrderCard(
                              dims: dims,
                              colors: colors,
                              planName: args.standalone ? null : planName,
                              planPrice:
                                  args.standalone
                                      ? null
                                      : '$planPrice $planCadence'.trim(),
                              planCadenceText:
                                  args.interval == 'year'
                                      ? 'Billed once a year'
                                      : 'Billed monthly',
                              wearableName:
                                  wearableSelected
                                      ? args.availability.productName
                                      : null,
                              wearablePrice:
                                  wearableSelected ? wearablePrice : null,
                              totalLabel: totalLabel,
                            ),
                            if (wearableSelected) ...[
                              SizedBox(height: dims.scaleSpace(16)),
                              _ShippingAddressSection(
                                dims: dims,
                                colors: colors,
                                address: _effectiveShippingAddress,
                                onEdit: _editShippingAddress,
                              ),
                            ],
                            SizedBox(height: dims.scaleSpace(22)),
                            _SecureStripeNote(dims: dims, colors: colors),
                            if (_error != null) ...[
                              SizedBox(height: dims.scaleSpace(12)),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: colors.accentDanger,
                                  fontSize: dims.scaleText(11),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            SizedBox(height: dims.scaleSpace(22)),
                            SizedBox(
                              width: double.infinity,
                              height: dims.scaleSpace(58),
                              child: FilledButton(
                                onPressed:
                                    _processing || checkoutState.isLoading
                                        ? null
                                        : (canPay
                                            ? _pay
                                            : _editShippingAddress),
                                style: FilledButton.styleFrom(
                                  backgroundColor: primaryActionBackground,
                                  disabledBackgroundColor:
                                      primaryActionBackground.withValues(
                                        alpha: 0.5,
                                      ),
                                  side: BorderSide(
                                    color: _reviewOrderAccent.withValues(
                                      alpha: 0.45,
                                    ),
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      dims.scaleRadius(18),
                                    ),
                                  ),
                                ),
                                child:
                                    _processing || checkoutState.isLoading
                                        ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                        : SizedBox.expand(
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Text(
                                                canPay
                                                    ? 'Pay $totalLabel'
                                                    : 'Add shipping address',
                                                style: TextStyle(
                                                  fontSize: dims.scaleText(16),
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      primaryActionForeground,
                                                ),
                                              ),
                                              Positioned(
                                                right: dims.scaleWidth(2),
                                                child: Icon(
                                                  Icons.lock_outline_rounded,
                                                  size: dims.scaleText(18),
                                                  color:
                                                      primaryActionForeground,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                              ),
                            ),
                            SizedBox(height: dims.scaleSpace(12)),
                            _TermsLine(dims: dims, colors: colors),
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
      ),
    );
  }
}

WearableOrder? _bestConfirmedOrder(
  List<WearableOrder> orders,
  String wearableSku,
) {
  if (orders.isEmpty) return null;
  final matchingOrders =
      orders.where((order) => order.wearableSku == wearableSku).toList();
  final candidates = matchingOrders.isEmpty ? orders : matchingOrders;
  candidates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return candidates.first;
}

class _CheckoutHeader extends StatelessWidget {
  const _CheckoutHeader({
    required this.dims,
    required this.colors,
    required this.onBack,
  });

  final AppDimensions dims;
  final dynamic colors;
  final VoidCallback onBack;

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
            'Review your order',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFamily: 'Georgia',
              fontWeight: FontWeight.w500,
              fontSize: dims.scaleText(24),
              color: isDark ? colors.textPrimary : const Color(0xFF10212A),
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckoutStepper extends StatelessWidget {
  const _CheckoutStepper({required this.dims});

  final AppDimensions dims;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: dims.scaleWidth(260),
      child: Column(
        children: [
          Row(
            children: [
              _StepDot(dims: dims, completed: true, label: Icons.check_rounded),
              Expanded(
                child: Container(height: 1, color: const Color(0xFFFFBDA5)),
              ),
              _StepDot(dims: dims, completed: false, text: '2'),
            ],
          ),
          SizedBox(height: dims.scaleSpace(8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Plan & Add-ons',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: dims.scaleText(8),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF765A50),
                ),
              ),
              Text(
                'Checkout & Pay',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: dims.scaleText(8),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF765A50),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.dims,
    required this.completed,
    this.label,
    this.text,
  });

  final AppDimensions dims;
  final bool completed;
  final IconData? label;
  final String? text;

  @override
  Widget build(BuildContext context) {
    final fillColor =
        completed ? Colors.white : _reviewOrderEstimatedDeliveryBg;
    final contentColor =
        completed ? const Color(0xFF8C6D5C) : _reviewOrderAccent;
    return Container(
      width: dims.scaleWidth(28),
      height: dims.scaleWidth(28),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
        border: Border.all(color: const Color(0xFFFFBDA5), width: 1.4),
      ),
      alignment: Alignment.center,
      child:
          label != null
              ? Icon(label, size: dims.scaleText(13), color: contentColor)
              : Text(
                text ?? '',
                style: TextStyle(
                  color: contentColor,
                  fontSize: dims.scaleText(10),
                  fontWeight: FontWeight.w800,
                ),
              ),
    );
  }
}

class _SoftPanel extends StatelessWidget {
  const _SoftPanel({
    required this.dims,
    required this.colors,
    required this.child,
    this.padding,
  });

  final AppDimensions dims;
  final dynamic colors;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(dims.scaleWidth(18)),
      decoration: BoxDecoration(
        color:
            isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFFFDFD1),
        ),
        boxShadow:
            isDark
                ? null
                : const [
                  BoxShadow(
                    color: Color(0x0FC78862),
                    blurRadius: 30,
                    offset: Offset(0, 12),
                  ),
                ],
      ),
      child: child,
    );
  }
}

class _YourOrderCard extends StatelessWidget {
  const _YourOrderCard({
    required this.dims,
    required this.colors,
    required this.planName,
    required this.planPrice,
    required this.planCadenceText,
    required this.wearableName,
    required this.wearablePrice,
    required this.totalLabel,
  });

  final AppDimensions dims;
  final dynamic colors;
  final String? planName;
  final String? planPrice;
  final String planCadenceText;
  final String? wearableName;
  final String? wearablePrice;
  final String totalLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _SoftPanel(
      dims: dims,
      colors: colors,
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(18),
        dims.scaleSpace(18),
        dims.scaleWidth(18),
        dims.scaleSpace(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Order',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFamily: 'Georgia',
              fontSize: dims.scaleText(16),
              fontWeight: FontWeight.w500,
              color: isDark ? colors.textPrimary : const Color(0xFF2D170F),
            ),
          ),
          SizedBox(height: dims.scaleSpace(20)),
          if (planName != null && planPrice != null) ...[
            _OrderItemRow(
              dims: dims,
              colors: colors,
              icon: Icons.workspace_premium_outlined,
              title: planName!,
              subtitle: planCadenceText,
              price: planPrice!,
              useGradientIcon: true,
            ),
            Divider(
              height: dims.scaleSpace(30),
              color:
                  isDark
                      ? colors.border.withValues(alpha: 0.4)
                      : const Color(0xFFF1E4DC),
            ),
          ],
          if (wearableName != null && wearablePrice != null) ...[
            _OrderItemRow(
              dims: dims,
              colors: colors,
              icon: Icons.watch_outlined,
              title: wearableName!,
              subtitle:
                  'Track temperature, HRV, sleep\nand recovery with precision.',
              price: wearablePrice!,
              chip: 'One-time',
            ),
            Divider(
              height: dims.scaleSpace(32),
              color:
                  isDark
                      ? colors.border.withValues(alpha: 0.4)
                      : const Color(0xFFF1E4DC),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total Today',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(13),
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Text(
                totalLabel,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: dims.scaleText(19),
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({
    required this.dims,
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.price,
    this.chip,
    this.useGradientIcon = false,
  });

  final AppDimensions dims;
  final dynamic colors;
  final IconData icon;
  final String title;
  final String subtitle;
  final String price;
  final String? chip;
  final bool useGradientIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: dims.scaleWidth(56),
          height: dims.scaleWidth(56),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: useGradientIcon ? null : const Color(0xFFFFF0E8),
            gradient:
                useGradientIcon
                    ? const LinearGradient(
                      colors: [Color(0xFFFF8A54), Color(0xFFFF4D1F)],
                    )
                    : null,
          ),
          child: Icon(
            icon,
            size: dims.scaleText(useGradientIcon ? 22 : 24),
            color: useGradientIcon ? Colors.white : const Color(0xFFFF6B35),
          ),
        ),
        SizedBox(width: dims.scaleWidth(16)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFamily: 'Georgia',
                        fontSize: dims.scaleText(14),
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  if (chip != null) ...[
                    SizedBox(width: dims.scaleWidth(8)),
                    _TinyPill(dims: dims, label: chip!),
                  ],
                ],
              ),
              SizedBox(height: dims.scaleSpace(5)),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: dims.scaleText(8.5),
                  height: 1.25,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: dims.scaleWidth(12)),
        Text(
          price,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: dims.scaleText(13),
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ShippingAddressSection extends StatelessWidget {
  const _ShippingAddressSection({
    required this.dims,
    required this.colors,
    required this.address,
    required this.onEdit,
  });

  final AppDimensions dims;
  final dynamic colors;
  final ShippingAddress address;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final lines = address.displayLines.trim();
    final hasFullAddress =
        address.fullName?.isNotEmpty == true ||
        address.line1?.isNotEmpty == true ||
        address.city?.isNotEmpty == true ||
        address.postcode?.isNotEmpty == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _SoftPanel(
      dims: dims,
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            dims: dims,
            colors: colors,
            title: 'Shipping Address',
            onEdit: onEdit,
          ),
          SizedBox(height: dims.scaleSpace(14)),
          Text(
            !hasFullAddress || lines.isEmpty
                ? 'Shipping address will be confirmed at checkout.'
                : lines,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: dims.scaleText(10),
              height: 1.45,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: dims.scaleSpace(18)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(dims.scaleWidth(14)),
            decoration: BoxDecoration(
              color: isDark ? colors.bg : const Color(0xFFFFF4EE),
              borderRadius: BorderRadius.circular(dims.scaleRadius(12)),
              border: Border.all(
                color: isDark ? colors.border : const Color(0xFFFFE2D4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.local_shipping_outlined,
                  size: dims.scaleText(26),
                  color: const Color(0xFFFF6B35),
                ),
                SizedBox(width: dims.scaleWidth(16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated delivery',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontSize: dims.scaleText(10),
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: dims.scaleSpace(2)),
                      Text(
                        "3-5 business days after dispatch\nYou'll receive tracking details via email and in-app.",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: dims.scaleText(8),
                          height: 1.25,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.info_outline_rounded,
                  size: dims.scaleText(16),
                  color:
                      isDark ? colors.textSecondary : const Color(0xFF8C6D5C),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.dims,
    required this.colors,
    required this.title,
    this.onEdit,
  });

  final AppDimensions dims;
  final dynamic colors;
  final String title;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFamily: 'Georgia',
              fontSize: dims.scaleText(16),
              fontWeight: FontWeight.w500,
              color: isDark ? colors.textPrimary : const Color(0xFF2D170F),
            ),
          ),
        ),
        GestureDetector(
          onTap: onEdit,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: dims.scaleWidth(16),
              vertical: dims.scaleSpace(7),
            ),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? colors.bg.withValues(alpha: 0.72)
                      : Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
              border: Border.all(
                color: isDark ? colors.border : const Color(0xFFFFC9B6),
              ),
            ),
            child: Text(
              'Edit',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: dims.scaleText(8),
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFF6B35),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SecureStripeNote extends StatelessWidget {
  const _SecureStripeNote({required this.dims, required this.colors});

  final AppDimensions dims;
  final dynamic colors;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(18),
        vertical: dims.scaleSpace(16),
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.bgElevated : const Color(0xFFFFF4EE),
        borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
        border: Border.all(color: isDark ? colors.border : Colors.transparent),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: dims.scaleText(14),
            color: isDark ? colors.textSecondary : const Color(0xFF9B6D5C),
          ),
          SizedBox(width: dims.scaleWidth(10)),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure checkout powered by Stripe',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(9),
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF765A50),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(2)),
                Text(
                  'Your payment information is safe and encrypted.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(7.5),
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

class _TermsLine extends StatelessWidget {
  const _TermsLine({required this.dims, required this.colors});

  final AppDimensions dims;
  final dynamic colors;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: 'By continuing, you agree to our ',
        children: const [
          TextSpan(
            text: 'Terms of Use',
            style: TextStyle(
              color: Color(0xFFFF6B35),
              decoration: TextDecoration.underline,
            ),
          ),
          TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy.',
            style: TextStyle(
              color: Color(0xFFFF6B35),
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: dims.scaleText(7.5),
        color: colors.textSecondary,
      ),
    );
  }
}

class _ShippingAddressSheet extends StatefulWidget {
  const _ShippingAddressSheet({required this.initialAddress});

  final ShippingAddress initialAddress;

  @override
  State<_ShippingAddressSheet> createState() => _ShippingAddressSheetState();
}

class _ShippingAddressSheetState extends State<_ShippingAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _line1Ctrl;
  late final TextEditingController _line2Ctrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _countyCtrl;
  late final TextEditingController _postcodeCtrl;
  late final TextEditingController _phoneCtrl;
  late String _selectedCountry;

  @override
  void initState() {
    super.initState();
    final address = widget.initialAddress;
    _nameCtrl = TextEditingController(text: address.fullName ?? '');
    _line1Ctrl = TextEditingController(text: address.line1 ?? '');
    _line2Ctrl = TextEditingController(text: address.line2 ?? '');
    _cityCtrl = TextEditingController(text: address.city ?? '');
    _countyCtrl = TextEditingController(text: address.county ?? '');
    _selectedCountry = _countryNameFromValue(address.country);
    _postcodeCtrl = TextEditingController(text: address.postcode ?? '');
    _phoneCtrl = TextEditingController(text: address.phone ?? '');
  }

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

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      ShippingAddress(
        fullName: _nameCtrl.text.trim(),
        line1: _line1Ctrl.text.trim(),
        line2: _line2Ctrl.text.trim().isEmpty ? null : _line2Ctrl.text.trim(),
        city: _cityCtrl.text.trim(),
        county:
            _countyCtrl.text.trim().isEmpty ? null : _countyCtrl.text.trim(),
        postcode: _postcodeCtrl.text.trim(),
        country: _selectedCountry,
        phone: _phoneCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? colors.bg : const Color(0xFFFFFBF7),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(dims.scaleRadius(28)),
          ),
          border: Border.all(
            color: isDark ? colors.border : const Color(0xFFFFDFD1),
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            dims.scaleWidth(24),
            dims.scaleSpace(14),
            dims.scaleWidth(24),
            dims.scaleSpace(24),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: dims.scaleWidth(48),
                    height: dims.scaleSpace(5),
                    decoration: BoxDecoration(
                      color: isDark ? colors.border : const Color(0xFFD0C1B9),
                      borderRadius: BorderRadius.circular(
                        dims.scaleRadius(999),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(18)),
                Text(
                  'Shipping address',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontFamily: 'Georgia',
                    fontSize: dims.scaleText(22),
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(16)),
                _SheetField(
                  controller: _nameCtrl,
                  label: 'Full name',
                  required: true,
                ),
                _SheetField(
                  controller: _line1Ctrl,
                  label: 'Address line 1',
                  required: true,
                ),
                _SheetField(controller: _line2Ctrl, label: 'Address line 2'),
                _SheetField(
                  controller: _phoneCtrl,
                  label: 'Phone number',
                  required: true,
                  keyboardType: TextInputType.phone,
                  helperText:
                      'Use a valid UK number, e.g. 07123 456789 or +44 7123 456789',
                  validator:
                      (value) =>
                          _isValidPhoneForCountry(value, _selectedCountry)
                              ? null
                              : 'Enter a valid phone number',
                ),
                Row(
                  children: [
                    Expanded(
                      child: _SheetField(
                        controller: _cityCtrl,
                        label: 'City',
                        required: true,
                      ),
                    ),
                    SizedBox(width: dims.scaleWidth(10)),
                    Expanded(
                      child: _SheetField(
                        controller: _postcodeCtrl,
                        label: 'Postcode',
                        required: true,
                      ),
                    ),
                  ],
                ),
                _SheetField(controller: _countyCtrl, label: 'County'),
                _CountryDropdown(
                  value: _selectedCountry,
                  onChanged:
                      (value) => setState(() => _selectedCountry = value),
                ),
                SizedBox(height: dims.scaleSpace(18)),
                SizedBox(
                  width: double.infinity,
                  height: dims.scaleSpace(52),
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          dims.scaleRadius(16),
                        ),
                      ),
                    ),
                    child: Text(
                      'Save address',
                      style: TextStyle(
                        fontSize: dims.scaleText(14),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
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

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.label,
    this.required = false,
    this.keyboardType,
    this.helperText,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final TextInputType? keyboardType;
  final String? helperText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: dims.scaleSpace(10)),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.next,
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: dims.scaleText(12),
        ),
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          helperMaxLines: 2,
          labelStyle: TextStyle(
            color: colors.textSecondary,
            fontSize: dims.scaleText(11),
          ),
          filled: true,
          fillColor: isDark ? colors.bgElevated : Colors.white,
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
            borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 1.4),
          ),
        ),
        validator: (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return 'Required';
          }
          return validator?.call(value);
        },
      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected =
        supportedPaymentCountries.contains(value)
            ? value
            : supportedPaymentCountries.first;

    return Padding(
      padding: EdgeInsets.only(bottom: dims.scaleSpace(10)),
      child: DropdownButtonFormField<String>(
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
                        fontSize: dims.scaleText(12),
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
            color: colors.textSecondary,
            fontSize: dims.scaleText(11),
          ),
          filled: true,
          fillColor: isDark ? colors.bgElevated : Colors.white,
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
            borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 1.4),
          ),
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

String _countryNameFromValue(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return 'United Kingdom';
  if (supportedPaymentCountries.contains(raw)) return raw;
  final lower = raw.toLowerCase();
  return switch (lower) {
    'gb' || 'uk' || 'great britain' => 'United Kingdom',
    'us' || 'usa' => 'United States',
    _ => supportedPaymentCountries.firstWhere(
      (country) => country.toLowerCase() == lower,
      orElse: () => 'United Kingdom',
    ),
  };
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.dims, required this.label});

  final AppDimensions dims;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(8),
        vertical: dims.scaleSpace(4),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: dims.scaleText(6),
          height: 1,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFFF6B35),
        ),
      ),
    );
  }
}

String _planPriceLabel(WearableCheckoutArgs args) {
  final direct = args.planDisplayPrice?.trim();
  if (direct != null && direct.isNotEmpty) return direct;
  return args.interval == 'year' ? '£35.00' : '£3.99';
}

String _wearablePriceLabel(WearableAvailability availability) {
  final direct = availability.displayPrice.trim();
  if (direct.isNotEmpty) return direct;
  if (availability.priceMinor <= 0) return '${availability.currencySymbol}0.00';
  return '${availability.currencySymbol}${(availability.priceMinor / 100).toStringAsFixed(2)}';
}

int _minorFromDisplayPrice(String value) {
  final match = RegExp(r'([0-9]+(?:[.,][0-9]{1,2})?)').firstMatch(value);
  if (match == null) return 0;
  final parsed = double.tryParse(match.group(1)!.replaceAll(',', '.'));
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
