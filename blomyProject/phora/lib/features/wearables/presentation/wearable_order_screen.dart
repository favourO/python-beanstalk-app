import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/core/ui/phora_loading.dart';
import 'package:phora/features/auth/presentation/auth_ui.dart';
import 'package:phora/features/wearables/domain/wearable_order_models.dart';
import 'package:phora/features/wearables/providers/wearable_order_providers.dart';
import 'package:url_launcher/url_launcher.dart';

const _wearableHeartWatchSvg = '''
<svg width="96" height="96" viewBox="0 0 96 96" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="48" cy="48" r="46" fill="#FFF0E8" stroke="#FFD8C8" stroke-width="2"/>
  <path d="M39 25C39 21.6863 41.6863 19 45 19H51C54.3137 19 57 21.6863 57 25V31H39V25Z" fill="#FFE4D6" stroke="#FF6B2F" stroke-width="3" stroke-linejoin="round"/>
  <rect x="32" y="30" width="32" height="38" rx="10" fill="#FFFFFF" stroke="#FF6B2F" stroke-width="3"/>
  <path d="M39 68H57V74C57 77.3137 54.3137 80 51 80H45C41.6863 80 39 77.3137 39 74V68Z" fill="#FFE4D6" stroke="#FF6B2F" stroke-width="3" stroke-linejoin="round"/>
  <path d="M64 43H67C68.1046 43 69 43.8954 69 45V51C69 52.1046 68.1046 53 67 53H64" stroke="#FF6B2F" stroke-width="3" stroke-linecap="round"/>
  <path d="M41 49L46 54L56 42" stroke="#2E8C3D" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';

// ── Single order detail screen ─────────────────────────────────────────────

class WearableOrderDetailScreen extends ConsumerWidget {
  const WearableOrderDetailScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  final String orderId;
  final WearableOrder? initialOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orderAsync = ref.watch(wearableOrderProvider(orderId));

    final order = orderAsync.valueOrNull ?? initialOrder;

    return _WearableOrderAutoRefresh(
      orderId: orderId,
      child: Scaffold(
        backgroundColor: isDark ? colors.bg : const Color(0xFFFFFBF7),
        body: DecoratedBox(
          decoration: authBackgroundDecoration(context),
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: _OrderHeader(
                  onBack: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/you');
                    }
                  },
                  onRefresh:
                      () => ref.invalidate(wearableOrderProvider(orderId)),
                ),
              ),
              Expanded(
                child:
                    orderAsync.isLoading && order == null
                        ? const Center(child: PhoraLoadingIndicator())
                        : order == null
                        ? _OrderErrorState(
                          onRetry:
                              () => ref.invalidate(
                                wearableOrderProvider(orderId),
                              ),
                        )
                        : RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(wearableOrderProvider(orderId));
                            await ref.read(
                              wearableOrderProvider(orderId).future,
                            );
                          },
                          child: _OrderDetailBody(order: order),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WearableOrderAutoRefresh extends ConsumerStatefulWidget {
  const _WearableOrderAutoRefresh({required this.orderId, required this.child});

  final String orderId;
  final Widget child;

  @override
  ConsumerState<_WearableOrderAutoRefresh> createState() =>
      _WearableOrderAutoRefreshState();
}

class _WearableOrderAutoRefreshState
    extends ConsumerState<_WearableOrderAutoRefresh> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      ref.invalidate(wearableOrderProvider(widget.orderId));
      ref.invalidate(myWearableOrdersProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.onBack, required this.onRefresh});

  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(18),
        dims.scaleSpace(8),
        dims.scaleWidth(18),
        dims.scaleSpace(10),
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _OrderRoundButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: onBack,
              ),
              _OrderRoundButton(icon: Icons.refresh_rounded, onTap: onRefresh),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(
              left: dims.scaleWidth(42),
              right: dims.scaleWidth(42),
            ),
            child: Column(
              children: [
                Text(
                  'View my order',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontFamily: 'Georgia',
                    fontSize: dims.scaleText(24),
                    fontWeight: FontWeight.w500,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF10232B),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(7)),
                Text(
                  'Here are all the details about your Vyla Wearable order.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(12),
                    height: 1.4,
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF6E5750),
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

class _OrderRoundButton extends StatelessWidget {
  const _OrderRoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: dims.scaleWidth(36),
          height: dims.scaleWidth(36),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                isDark ? colors.bgCard : Colors.white.withValues(alpha: 0.78),
            border: Border.all(
              color:
                  isDark
                      ? colors.border
                      : const Color(0xFFFFD9C8).withValues(alpha: 0.78),
            ),
          ),
          child: Icon(
            icon,
            size: dims.scaleText(17),
            color: isDark ? colors.textPrimary : const Color(0xFF2D170F),
          ),
        ),
      ),
    );
  }
}

class _OrderErrorState extends StatelessWidget {
  const _OrderErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(dims.scaleWidth(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: const Color(0xFFFF6B2F),
              size: dims.scaleText(42),
            ),
            SizedBox(height: dims.scaleSpace(12)),
            Text(
              'Could not load order details',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
                fontSize: dims.scaleText(13),
              ),
            ),
            SizedBox(height: dims.scaleSpace(10)),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _OrderDetailBody extends StatelessWidget {
  const _OrderDetailBody({required this.order});

  final WearableOrder order;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(20),
        dims.scaleSpace(14),
        dims.scaleWidth(20),
        dims.scaleSpace(26),
      ),
      children: [
        _OrderProductCard(order: order),
        SizedBox(height: dims.scaleSpace(12)),
        _DeliveryOverviewCard(order: order),
        SizedBox(height: dims.scaleSpace(12)),
        _OrderProgressCard(order: order),
        SizedBox(height: dims.scaleSpace(12)),
        _OrderTrackingDetailsCard(order: order),
        SizedBox(height: dims.scaleSpace(12)),
        _DeliveryAddressCard(address: order.shippingAddress),
        SizedBox(height: dims.scaleSpace(12)),
        _OrderHelpCard(),
      ],
    );
  }
}

class _OrderProductCard extends StatelessWidget {
  const _OrderProductCard({required this.order});

  final WearableOrder order;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orderDate = DateFormat(
      'd MMM yyyy',
    ).format(order.createdAt.toLocal());

    return _OrderSoftCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OrderWearableImage(size: 92),
          SizedBox(width: dims.scaleWidth(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: dims.scaleWidth(8),
                  runSpacing: dims.scaleSpace(5),
                  children: [
                    Text(
                      order.wearableName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFamily: 'Georgia',
                        fontSize: dims.scaleText(17),
                        fontWeight: FontWeight.w500,
                        color:
                            isDark
                                ? colors.textPrimary
                                : const Color(0xFF10232B),
                      ),
                    ),
                    _OrderTinyPill('One-time purchase'),
                  ],
                ),
                SizedBox(height: dims.scaleSpace(14)),
                Row(
                  children: [
                    Expanded(
                      child: _OrderMeta(
                        label: 'Order number',
                        value:
                            order.orderNumber.isEmpty
                                ? 'Pending'
                                : order.orderNumber,
                      ),
                    ),
                    SizedBox(width: dims.scaleWidth(12)),
                    Expanded(
                      child: _OrderMeta(label: 'Order date', value: orderDate),
                    ),
                  ],
                ),
                SizedBox(height: dims.scaleSpace(12)),
                Divider(
                  height: 1,
                  color:
                      isDark
                          ? colors.border
                          : const Color(0xFFFFE1D5).withValues(alpha: 0.85),
                ),
                SizedBox(height: dims.scaleSpace(12)),
                Row(
                  children: [
                    Expanded(
                      child: _OrderMeta(
                        label: 'Total paid',
                        value:
                            order.displayPrice.isEmpty
                                ? _formatPrice(order.wearablePrice)
                                : order.displayPrice,
                      ),
                    ),
                    SizedBox(width: dims.scaleWidth(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment status',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              fontSize: dims.scaleText(10),
                              color:
                                  isDark
                                      ? colors.textSecondary
                                      : const Color(0xFF6F5A52),
                            ),
                          ),
                          SizedBox(height: dims.scaleSpace(5)),
                          _OrderPaymentPill(status: order.paymentStatus),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryOverviewCard extends StatelessWidget {
  const _DeliveryOverviewCard({required this.order});

  final WearableOrder order;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return _OrderSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OrderCardTitle('Delivery overview'),
          SizedBox(height: dims.scaleSpace(14)),
          Row(
            children: [
              _OrderPeachIcon(icon: Icons.calendar_month_outlined),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: _OrderMeta(
                  label: 'Estimated delivery',
                  value: _deliveryWindow(order),
                  accentValue: true,
                  caption: '3-5 business days after dispatch',
                ),
              ),
              SizedBox(width: dims.scaleWidth(10)),
              Expanded(
                child: _OrderMeta(
                  label: 'Courier',
                  value:
                      order.courier?.isNotEmpty == true
                          ? order.courier!
                          : 'TBC',
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderProgressCard extends StatelessWidget {
  const _OrderProgressCard({required this.order});

  final WearableOrder order;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entries = _timelineEntries(order);
    final currentIndex = entries.lastIndexWhere((entry) => entry.isCompleted);

    return _OrderSoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OrderCardTitle('Order progress'),
          SizedBox(height: dims.scaleSpace(14)),
          ...List.generate(entries.length, (index) {
            final entry = entries[index];
            final isLast = index == entries.length - 1;
            final completed = entry.isCompleted;
            final current = !completed && index == currentIndex + 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: dims.scaleWidth(28),
                        height: dims.scaleWidth(28),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              completed
                                  ? const Color(0xFFFF6B2F)
                                  : current
                                  ? Colors.white
                                  : isDark
                                  ? colors.bgSurface
                                  : const Color(0xFFF2F1EF),
                          border: Border.all(
                            color:
                                completed || current
                                    ? const Color(0xFFFF8B5C)
                                    : const Color(0xFFD8D4D0),
                          ),
                        ),
                        child: Icon(
                          completed
                              ? Icons.check_rounded
                              : _timelineIcon(entry.status),
                          size: dims.scaleText(15),
                          color:
                              completed
                                  ? Colors.white
                                  : current
                                  ? const Color(0xFFFF6B2F)
                                  : const Color(0xFF9D9995),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 1.5,
                            margin: EdgeInsets.symmetric(
                              vertical: dims.scaleSpace(3),
                            ),
                            color:
                                completed
                                    ? const Color(0xFFFFB091)
                                    : const Color(0xFFD8D4D0),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: dims.scaleWidth(12)),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: isLast ? 0 : dims.scaleSpace(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              fontSize: dims.scaleText(13),
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark
                                      ? colors.textPrimary
                                      : const Color(0xFF2D170F),
                            ),
                          ),
                          SizedBox(height: dims.scaleSpace(2)),
                          Text(
                            entry.description,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              fontSize: dims.scaleText(10.5),
                              height: 1.35,
                              color:
                                  isDark
                                      ? colors.textSecondary
                                      : const Color(0xFF6B5A53),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: dims.scaleWidth(8)),
                  Text(
                    _timelineTrailing(entry, current),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: dims.scaleText(10),
                      fontWeight: FontWeight.w600,
                      color:
                          completed
                              ? const Color(0xFF2E7D32)
                              : current
                              ? const Color(0xFFFF6B2F)
                              : const Color(0xFF9D9995),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _OrderTrackingDetailsCard extends StatelessWidget {
  const _OrderTrackingDetailsCard({required this.order});

  final WearableOrder order;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasTracking =
        order.trackingNumber?.isNotEmpty == true ||
        order.trackingUrl?.isNotEmpty == true;
    final courier =
        order.courier?.isNotEmpty == true ? order.courier! : 'courier';

    return _OrderSoftCard(
      child: Row(
        children: [
          _OrderPeachIcon(icon: Icons.shopping_bag_outlined),
          SizedBox(width: dims.scaleWidth(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OrderCardTitle('Tracking details'),
                SizedBox(height: dims.scaleSpace(7)),
                Text(
                  hasTracking
                      ? 'Tracking number\n${order.trackingNumber ?? 'Available'}'
                      : 'Tracking details will appear after dispatch.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(11),
                    height: 1.45,
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF5F4B45),
                  ),
                ),
              ],
            ),
          ),
          if (order.trackingUrl?.isNotEmpty == true) ...[
            SizedBox(width: dims.scaleWidth(10)),
            OutlinedButton.icon(
              onPressed: () => _launchTracking(order.trackingUrl!),
              icon: Icon(Icons.open_in_new_rounded, size: dims.scaleText(13)),
              label: Text('Track with $courier'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF6B2F),
                side: const BorderSide(color: Color(0xFFFFB79A)),
                padding: EdgeInsets.symmetric(
                  horizontal: dims.scaleWidth(10),
                  vertical: dims.scaleSpace(9),
                ),
                textStyle: TextStyle(
                  fontSize: dims.scaleText(10.5),
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(dims.scaleRadius(9)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeliveryAddressCard extends StatelessWidget {
  const _DeliveryAddressCard({required this.address});

  final ShippingAddress address;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lines = address.displayLines;

    return _OrderSoftCard(
      child: Row(
        children: [
          _OrderPeachIcon(icon: Icons.location_on_outlined),
          SizedBox(width: dims.scaleWidth(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OrderCardTitle('Delivery address'),
                SizedBox(height: dims.scaleSpace(7)),
                Text(
                  lines.isNotEmpty ? lines : 'No address provided',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(11),
                    height: 1.45,
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF5F4B45),
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

class _OrderHelpCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _OrderSoftCard(
      compact: true,
      child: Row(
        children: [
          _OrderPeachIcon(icon: Icons.help_outline_rounded, small: true),
          SizedBox(width: dims.scaleWidth(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need help?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(12.5),
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF2D170F),
                  ),
                ),
                Text(
                  'Contact Vyla at support@vyla.health',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(10.5),
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF80685D),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: dims.scaleText(23),
            color: isDark ? colors.textSecondary : const Color(0xFF6D4A3C),
          ),
        ],
      ),
    );
  }
}

class _OrderSoftCard extends StatelessWidget {
  const _OrderSoftCard({required this.child, this.compact = false});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(compact ? 12 : 16)),
      decoration: BoxDecoration(
        color: isDark ? colors.bgCard : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        border: Border.all(
          color:
              isDark
                  ? colors.border
                  : const Color(0xFFFFDDCF).withValues(alpha: 0.8),
        ),
        boxShadow:
            isDark
                ? null
                : [
                  BoxShadow(
                    color: const Color(0xFFFF6B2F).withValues(alpha: 0.045),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
      ),
      child: child,
    );
  }
}

class _OrderWearableImage extends StatelessWidget {
  const _OrderWearableImage({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return SvgPicture.string(
      _wearableHeartWatchSvg,
      width: dims.scaleWidth(size),
      height: dims.scaleWidth(size),
      fit: BoxFit.contain,
    );
  }
}

class _OrderPeachIcon extends StatelessWidget {
  const _OrderPeachIcon({required this.icon, this.small = false});

  final IconData icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = small ? 38.0 : 54.0;

    return Container(
      width: dims.scaleWidth(size),
      height: dims.scaleWidth(size),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? colors.bgSurface : const Color(0xFFFFF1EA),
      ),
      child: Icon(
        icon,
        size: dims.scaleText(small ? 19 : 26),
        color: const Color(0xFFFF6B2F),
      ),
    );
  }
}

class _OrderTinyPill extends StatelessWidget {
  const _OrderTinyPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(8),
        vertical: dims.scaleSpace(4),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EA),
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: dims.scaleText(9),
          fontWeight: FontWeight.w700,
          color: const Color(0xFFFF6B2F),
        ),
      ),
    );
  }
}

class _OrderPaymentPill extends StatelessWidget {
  const _OrderPaymentPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final lower = status.toLowerCase();
    final paid = lower == 'paid';
    final failed = lower == 'failed';
    final bg =
        paid
            ? const Color(0xFFE6F4E7)
            : failed
            ? const Color(0xFFFFEBEE)
            : const Color(0xFFFFF8E1);
    final fg =
        paid
            ? const Color(0xFF2E7D32)
            : failed
            ? const Color(0xFFC62828)
            : const Color(0xFFE65100);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(8),
        vertical: dims.scaleSpace(3),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(dims.scaleRadius(6)),
      ),
      child: Text(
        _labelStatus(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: dims.scaleText(9),
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _OrderCardTitle extends StatelessWidget {
  const _OrderCardTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontFamily: 'Georgia',
        fontSize: dims.scaleText(15),
        fontWeight: FontWeight.w500,
        color: isDark ? colors.textPrimary : const Color(0xFF2D170F),
      ),
    );
  }
}

class _OrderMeta extends StatelessWidget {
  const _OrderMeta({
    required this.label,
    required this.value,
    this.caption,
    this.alignEnd = false,
    this.accentValue = false,
  });

  final String label;
  final String value;
  final String? caption;
  final bool alignEnd;
  final bool accentValue;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: dims.scaleText(10),
            color: isDark ? colors.textSecondary : const Color(0xFF6F5A52),
          ),
        ),
        SizedBox(height: dims.scaleSpace(3)),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: dims.scaleText(12),
            fontWeight: FontWeight.w700,
            color:
                accentValue
                    ? const Color(0xFFFF6B2F)
                    : isDark
                    ? colors.textPrimary
                    : const Color(0xFF2D170F),
          ),
        ),
        if (caption != null) ...[
          SizedBox(height: dims.scaleSpace(2)),
          Text(
            caption!,
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: dims.scaleText(10),
              color: isDark ? colors.textSecondary : const Color(0xFF6F5A52),
            ),
          ),
        ],
      ],
    );
  }
}

List<WearableTimelineEntry> _timelineEntries(WearableOrder order) {
  if (order.timeline.isNotEmpty) {
    return order.timeline;
  }
  final created = order.createdAt;
  final status = order.fulfillmentStatus.toLowerCase();
  DateTime? completedFor(String step) {
    final completedSteps = switch (status) {
      'processing' => {'order_confirmed', 'processing'},
      'dispatched' => {'order_confirmed', 'processing', 'dispatched'},
      'out_for_delivery' => {
        'order_confirmed',
        'processing',
        'dispatched',
        'out_for_delivery',
      },
      'delivered' => {
        'order_confirmed',
        'processing',
        'dispatched',
        'out_for_delivery',
        'delivered',
      },
      _ => {'order_confirmed'},
    };
    return completedSteps.contains(step) ? created : null;
  }

  return [
    WearableTimelineEntry(
      status: 'order_confirmed',
      title: 'Order confirmed',
      description: "We've received your order.",
      completedAt: completedFor('order_confirmed'),
    ),
    WearableTimelineEntry(
      status: 'processing',
      title: 'Processing',
      description: "We're preparing your Vyla Wearable.",
      completedAt: completedFor('processing'),
    ),
    WearableTimelineEntry(
      status: 'dispatched',
      title: 'Dispatched',
      description: 'Your order is on its way.',
      completedAt: order.shippedAt ?? completedFor('dispatched'),
    ),
    WearableTimelineEntry(
      status: 'out_for_delivery',
      title: 'Out for delivery',
      description: 'Your order is out for delivery.',
      completedAt: completedFor('out_for_delivery'),
    ),
    WearableTimelineEntry(
      status: 'delivered',
      title: 'Delivered',
      description: 'Your Vyla Wearable has been delivered.',
      completedAt: order.deliveredAt ?? completedFor('delivered'),
    ),
  ];
}

IconData _timelineIcon(String status) {
  return switch (status.toLowerCase()) {
    'processing' => Icons.inventory_2_outlined,
    'dispatched' => Icons.local_shipping_outlined,
    'out_for_delivery' => Icons.delivery_dining_outlined,
    'delivered' => Icons.home_outlined,
    _ => Icons.check_rounded,
  };
}

String _timelineTrailing(WearableTimelineEntry entry, bool current) {
  if (entry.completedAt != null) {
    final local = entry.completedAt!.toLocal();
    return '${DateFormat('d MMM yyyy').format(local)}\n${DateFormat('hh:mm a').format(local)}';
  }
  return current ? 'Current step' : 'Upcoming';
}

String _deliveryWindow(WearableOrder order) {
  if (order.estimatedDeliveryDate != null) {
    final end = order.estimatedDeliveryDate!.toLocal();
    final start = end.subtract(const Duration(days: 2));
    if (start.month == end.month && start.year == end.year) {
      return '${DateFormat('d').format(start)} - ${DateFormat('d MMM yyyy').format(end)}';
    }
    return '${DateFormat('d MMM').format(start)} - ${DateFormat('d MMM yyyy').format(end)}';
  }
  return order.isDispatched ? '3-5 business days' : 'After dispatch';
}

String _formatPrice(double price) => '£${price.toStringAsFixed(2)}';

String _labelStatus(String status) {
  final words = status.replaceAll('_', ' ').split(' ');
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

Future<void> _launchTracking(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
