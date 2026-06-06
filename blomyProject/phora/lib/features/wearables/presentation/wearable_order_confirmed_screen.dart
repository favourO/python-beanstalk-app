import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/core/ui/phora_loading.dart';
import 'package:phora/features/auth/presentation/auth_ui.dart';
import 'package:phora/features/wearables/domain/wearable_order_models.dart';
import 'package:phora/features/wearables/providers/wearable_order_providers.dart';

class WearableOrderConfirmedScreen extends ConsumerStatefulWidget {
  const WearableOrderConfirmedScreen({super.key, this.session, this.order});

  final WearableCheckoutSession? session;
  final WearableOrder? order;

  @override
  ConsumerState<WearableOrderConfirmedScreen> createState() =>
      _WearableOrderConfirmedScreenState();
}

class _WearableOrderConfirmedScreenState
    extends ConsumerState<WearableOrderConfirmedScreen> {
  Timer? _recoveryTimer;

  @override
  void initState() {
    super.initState();
    if (widget.order == null && _sessionHasWearable(widget.session)) {
      _recoveryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        final orders = ref.read(myWearableOrdersProvider).valueOrNull;
        if (_latestWearableOrder(orders) != null) {
          _recoveryTimer?.cancel();
          _recoveryTimer = null;
          return;
        }
        ref.invalidate(myWearableOrdersProvider);
      });
    }
  }

  @override
  void dispose() {
    _recoveryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = widget.session;
    final order = widget.order;
    final ordersAsync =
        order == null && (session == null || _sessionHasWearable(session))
            ? ref.watch(myWearableOrdersProvider)
            : null;
    final latestOrder = order ?? _latestWearableOrder(ordersAsync?.valueOrNull);
    final hasWearable =
        session?.wearableSku.trim().isNotEmpty == true || latestOrder != null;
    final hasPremium = (session?.subscriptionAmountMinor ?? 0) > 0;
    final isRecovering = session == null && ordersAsync?.isLoading == true;

    return Scaffold(
      backgroundColor: isDark ? colors.bg : const Color(0xFFFFFBF7),
      body: DecoratedBox(
        decoration: authBackgroundDecoration(context),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: dims.scaleWidth(24),
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: dims.scaleSpace(12)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => context.go('/today'),
                          child: Container(
                            width: dims.scaleWidth(34),
                            height: dims.scaleWidth(34),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  isDark
                                      ? colors.bgElevated
                                      : Colors.white.withValues(alpha: 0.85),
                              border: Border.all(
                                color:
                                    isDark
                                        ? colors.border
                                        : const Color(0xFFFFE2D4),
                              ),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: dims.scaleText(18),
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: dims.scaleSpace(18)),
                      Text(
                        hasWearable
                            ? 'Your order is confirmed!'
                            : hasPremium
                            ? 'Your subscription is active!'
                            : 'Payment confirmed!',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(
                          fontFamily: 'Georgia',
                          fontWeight: FontWeight.w500,
                          fontSize: dims.scaleText(26),
                          height: 1.08,
                          color:
                              isDark
                                  ? colors.textPrimary
                                  : const Color(0xFF10212A),
                        ),
                      ),
                      SizedBox(height: dims.scaleSpace(10)),
                      Text(
                        hasWearable
                            ? 'Your Vyla Wearable is on its way.\nWe will keep you updated every step of the way.'
                            : hasPremium
                            ? 'Your Premium access is ready.\nYou can manage your plan from subscription settings.'
                            : 'We are finishing your order details.\nYou can view your orders shortly.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: dims.scaleText(12),
                          height: 1.35,
                          color: colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: dims.scaleSpace(26)),
                      if (isRecovering)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: dims.scaleSpace(18),
                          ),
                          child: const PhoraLoadingIndicator(),
                        )
                      else
                        _OrderOverviewCard(
                          dims: dims,
                          colors: colors,
                          session: session,
                          order: latestOrder,
                          hasWearable: hasWearable,
                          hasPremium: hasPremium,
                        ),
                      SizedBox(height: dims.scaleSpace(14)),
                      if (hasWearable) ...[
                        _ProgressCard(dims: dims, colors: colors),
                        SizedBox(height: dims.scaleSpace(14)),
                        _UpdatesCard(dims: dims, colors: colors),
                        SizedBox(height: dims.scaleSpace(12)),
                      ],
                      _HelpCard(dims: dims, colors: colors),
                      SizedBox(height: dims.scaleSpace(18)),
                      SizedBox(
                        width: double.infinity,
                        height: dims.scaleSpace(58),
                        child: FilledButton(
                          onPressed: hasWearable
                              ? (latestOrder != null
                                  ? () =>
                                      _openOrderDetail(context, latestOrder)
                                  : null)
                              : hasPremium
                              ? () => context.go('/subscription')
                              : (latestOrder != null
                                  ? () =>
                                      _openOrderDetail(context, latestOrder)
                                  : null),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B35),
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
                                Text(
                                  hasWearable
                                      ? (latestOrder != null
                                          ? 'View my order'
                                          : 'Loading order...')
                                      : hasPremium
                                      ? 'Manage subscription'
                                      : 'Continue',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: dims.scaleText(16),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Positioned(
                                  right: dims.scaleWidth(2),
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    size: dims.scaleText(20),
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: dims.scaleSpace(10)),
                      TextButton(
                        onPressed: () => context.go('/today'),
                        child: Text(
                          'Go to Home',
                          style: TextStyle(
                            color: const Color(0xFFFF6B35),
                            fontSize: dims.scaleText(13),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(height: dims.scaleSpace(18)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _sessionHasWearable(WearableCheckoutSession? session) {
  return session?.wearableSku.trim().isNotEmpty == true;
}

class WearableOrderConfirmedArgs {
  const WearableOrderConfirmedArgs({this.session, this.order});

  final WearableCheckoutSession? session;
  final WearableOrder? order;
}

void _openOrderDetail(BuildContext context, WearableOrder? order) {
  if (order == null) return;
  if (order.isDelivered) {
    context.go('/wearable/orders/${order.id}/delivered', extra: order);
  } else if (order.isDispatched) {
    context.go('/wearable/orders/${order.id}/tracking', extra: order);
  } else {
    context.go('/wearable/orders/${order.id}', extra: order);
  }
}

class _OrderOverviewCard extends StatelessWidget {
  const _OrderOverviewCard({
    required this.dims,
    required this.colors,
    this.session,
    this.order,
    required this.hasWearable,
    required this.hasPremium,
  });

  final AppDimensions dims;
  final dynamic colors;
  final WearableCheckoutSession? session;
  final WearableOrder? order;
  final bool hasWearable;
  final bool hasPremium;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wearableName =
        order?.wearableName ??
        (session?.wearableName.trim().isNotEmpty == true
            ? session!.wearableName
            : 'Vyla Wearable');
    final interval = session?.interval ?? 'month';
    final orderNumber =
        order?.orderNumber.isNotEmpty == true
            ? order!.orderNumber
            : 'Processing';
    final orderDate =
        order == null ? _todayLabel() : _dateLabel(order!.createdAt.toLocal());

    return _SoftPanel(
      dims: dims,
      colors: colors,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: dims.scaleWidth(72),
                height: dims.scaleWidth(72),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? colors.bgSurface : const Color(0xFFFFF0E8),
                  border: Border.all(
                    color: isDark ? colors.border : const Color(0xFFFFE2D4),
                  ),
                ),
                child: Icon(
                  hasWearable
                      ? Icons.watch_outlined
                      : Icons.workspace_premium_outlined,
                  color: const Color(0xFFFF6B35),
                  size: dims.scaleText(34),
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
                            hasWearable
                                ? wearableName
                                : 'Premium ${interval == 'year' ? 'Annual' : 'Monthly'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              fontFamily: 'Georgia',
                              fontSize: dims.scaleText(17),
                              fontWeight: FontWeight.w500,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        if (hasWearable) ...[
                          SizedBox(width: dims.scaleWidth(8)),
                          _TinyPill(dims: dims, label: 'One-time purchase'),
                        ],
                      ],
                    ),
                    SizedBox(height: dims.scaleSpace(10)),
                    if (hasWearable)
                      _TwoColumnDetails(
                        dims: dims,
                        colors: colors,
                        leftLabel: 'Order number',
                        leftValue: orderNumber,
                        rightLabel: 'Order date',
                        rightValue: orderDate,
                      )
                    else
                      _TwoColumnDetails(
                        dims: dims,
                        colors: colors,
                        leftLabel: 'Plan',
                        leftValue: interval == 'year' ? 'Annual' : 'Monthly',
                        rightLabel: 'Status',
                        rightValue: 'Active',
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (hasWearable) ...[
            SizedBox(height: dims.scaleSpace(16)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(dims.scaleWidth(14)),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? colors.bgSurface.withValues(alpha: 0.9)
                        : const Color(0xFFFFF4EE),
                borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
                border: Border.all(
                  color: isDark ? colors.border : const Color(0xFFFFE2D4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: dims.scaleWidth(44),
                    height: dims.scaleWidth(44),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? colors.bgCard : const Color(0xFFFFF0E8),
                      border: Border.all(
                        color:
                            isDark
                                ? colors.borderStrong
                                : const Color(0xFFFFE2D4),
                      ),
                    ),
                    child: Icon(
                      Icons.local_shipping_outlined,
                      size: dims.scaleText(24),
                      color: const Color(0xFFFF6B35),
                    ),
                  ),
                  SizedBox(width: dims.scaleWidth(14)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated delivery',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            fontSize: dims.scaleText(12),
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: dims.scaleSpace(3)),
                        Text(
                          '3-5 business days after dispatch',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            fontSize: dims.scaleText(10),
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: dims.scaleText(24),
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TwoColumnDetails extends StatelessWidget {
  const _TwoColumnDetails({
    required this.dims,
    required this.colors,
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final AppDimensions dims;
  final dynamic colors;
  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniDetail(
            dims: dims,
            colors: colors,
            label: leftLabel,
            value: leftValue,
          ),
        ),
        SizedBox(width: dims.scaleWidth(16)),
        Expanded(
          child: _MiniDetail(
            dims: dims,
            colors: colors,
            label: rightLabel,
            value: rightValue,
          ),
        ),
      ],
    );
  }
}

class _MiniDetail extends StatelessWidget {
  const _MiniDetail({
    required this.dims,
    required this.colors,
    required this.label,
    required this.value,
  });

  final AppDimensions dims;
  final dynamic colors;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: dims.scaleText(9),
            color: colors.textSecondary,
          ),
        ),
        SizedBox(height: dims.scaleSpace(4)),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: dims.scaleText(11),
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.dims, required this.colors});

  final AppDimensions dims;
  final dynamic colors;

  @override
  Widget build(BuildContext context) {
    final steps = const [
      ('Order confirmed', 'We have received your order.', true),
      ('Processing', 'We are packing your Vyla Wearable.', false),
      (
        'Dispatched',
        'You will receive tracking details once it is on the way.',
        false,
      ),
      ('Delivered', 'Get ready to connect and unlock deeper insights.', false),
    ];
    return _SoftPanel(
      dims: dims,
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What happens next?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontFamily: 'Georgia',
              fontSize: dims.scaleText(17),
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: dims.scaleSpace(16)),
          for (var i = 0; i < steps.length; i++)
            _TimelineStep(
              dims: dims,
              colors: colors,
              title: steps[i].$1,
              subtitle: steps[i].$2,
              completed: steps[i].$3,
              trailing: i == 0 ? _todayLabel() : null,
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.dims,
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.completed,
    required this.isLast,
    this.trailing,
  });

  final AppDimensions dims;
  final dynamic colors;
  final String title;
  final String subtitle;
  final bool completed;
  final bool isLast;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: dims.scaleWidth(30),
              height: dims.scaleWidth(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed ? const Color(0xFFFF6B35) : Colors.transparent,
                border: Border.all(
                  color:
                      completed
                          ? const Color(0xFFFF6B35)
                          : colors.border.withValues(alpha: 0.8),
                ),
              ),
              child: Icon(
                completed ? Icons.check_rounded : Icons.inventory_2_outlined,
                size: dims.scaleText(16),
                color: completed ? Colors.white : colors.textSecondary,
              ),
            ),
            if (!isLast)
              Container(
                width: 1,
                height: dims.scaleSpace(34),
                color:
                    completed
                        ? const Color(0xFFFFC1AA)
                        : colors.border.withValues(alpha: 0.8),
              ),
          ],
        ),
        SizedBox(width: dims.scaleWidth(14)),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: dims.scaleSpace(2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: dims.scaleText(12),
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (trailing != null)
                      Text(
                        trailing!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: dims.scaleText(10),
                          color: const Color(0xFFFF6B35),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: dims.scaleSpace(3)),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(10),
                    color: colors.textSecondary,
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

class _UpdatesCard extends StatelessWidget {
  const _UpdatesCard({required this.dims, required this.colors});

  final AppDimensions dims;
  final dynamic colors;

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      dims: dims,
      colors: colors,
      padding: EdgeInsets.all(dims.scaleWidth(14)),
      child: Row(
        children: [
          Icon(
            Icons.mail_outline_rounded,
            size: dims.scaleText(24),
            color: const Color(0xFFFF6B35),
          ),
          SizedBox(width: dims.scaleWidth(14)),
          Expanded(
            child: Text(
              'We will send order and tracking updates by email and in-app notifications.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: dims.scaleText(10),
                height: 1.3,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.dims, required this.colors});

  final AppDimensions dims;
  final dynamic colors;

  @override
  Widget build(BuildContext context) {
    return _SoftPanel(
      dims: dims,
      colors: colors,
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(16),
        vertical: dims.scaleSpace(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.help_outline_rounded,
            size: dims.scaleText(22),
            color: const Color(0xFFFF6B35),
          ),
          SizedBox(width: dims.scaleWidth(14)),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Need help?\n',
                style: TextStyle(
                  fontSize: dims.scaleText(11),
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: 'Visit our Help Centre or contact support.',
                    style: TextStyle(
                      fontSize: dims.scaleText(9.5),
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: dims.scaleText(24),
            color: colors.textSecondary,
          ),
        ],
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

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.dims, required this.label});

  final AppDimensions dims;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(8),
        vertical: dims.scaleSpace(4),
      ),
      decoration: BoxDecoration(
        color:
            isDark
                ? const Color(0xFFFF6B35).withValues(alpha: 0.16)
                : const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
        border: Border.all(
          color: const Color(
            0xFFFF6B35,
          ).withValues(alpha: isDark ? 0.34 : 0.08),
        ),
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

String _todayLabel() {
  final now = DateTime.now();
  return _dateLabel(now);
}

String _dateLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

WearableOrder? _latestWearableOrder(List<WearableOrder>? orders) {
  if (orders == null || orders.isEmpty) {
    return null;
  }
  final sorted = [...orders]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted.first;
}
