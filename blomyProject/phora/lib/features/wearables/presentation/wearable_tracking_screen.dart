import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
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

class WearableTrackingScreen extends ConsumerStatefulWidget {
  const WearableTrackingScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  final String orderId;
  final WearableOrder? initialOrder;

  @override
  ConsumerState<WearableTrackingScreen> createState() =>
      _WearableTrackingScreenState();
}

class _WearableTrackingScreenState extends ConsumerState<WearableTrackingScreen> {
  WearableOrder? _lastOrder;

  @override
  Widget build(BuildContext context) {
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackingAsync = ref.watch(
      wearableOrderTrackingProvider(widget.orderId),
    );

    final fetched = trackingAsync.valueOrNull;
    if (fetched != null) _lastOrder = fetched;
    final order = _lastOrder ?? widget.initialOrder;

    return _WearableTrackingAutoRefresh(
      orderId: widget.orderId,
      child: Scaffold(
        backgroundColor: isDark ? colors.bg : const Color(0xFFFFFBF7),
        body: DecoratedBox(
          decoration: authBackgroundDecoration(context),
          child: SafeArea(
            child: Column(
              children: [
                _TrackingHeader(
                  onBack: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/subscription');
                    }
                  },
                  onRefresh:
                      () => ref.invalidate(
                        wearableOrderTrackingProvider(widget.orderId),
                      ),
                ),
                Expanded(
                  child:
                      trackingAsync.isLoading && order == null
                          ? const Center(child: PhoraLoadingIndicator())
                          : order == null
                          ? _TrackingErrorState(
                            onRetry:
                                () => ref.invalidate(
                                  wearableOrderTrackingProvider(widget.orderId),
                                ),
                          )
                          : RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(
                                wearableOrderTrackingProvider(widget.orderId),
                              );
                              await ref.read(
                                wearableOrderTrackingProvider(
                                  widget.orderId,
                                ).future,
                              );
                            },
                            child: _TrackingBody(order: order),
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

class _WearableTrackingAutoRefresh extends ConsumerStatefulWidget {
  const _WearableTrackingAutoRefresh({
    required this.orderId,
    required this.child,
  });

  final String orderId;
  final Widget child;

  @override
  ConsumerState<_WearableTrackingAutoRefresh> createState() =>
      _WearableTrackingAutoRefreshState();
}

class _WearableTrackingAutoRefreshState
    extends ConsumerState<_WearableTrackingAutoRefresh> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      ref.invalidate(wearableOrderTrackingProvider(widget.orderId));
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

class _TrackingHeader extends StatelessWidget {
  const _TrackingHeader({required this.onBack, required this.onRefresh});

  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? colors.textPrimary : const Color(0xFF10232B);
    final subtitleColor =
        isDark ? colors.textSecondary : const Color(0xFF6E5750);

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
              _RoundHeaderButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: onBack,
              ),
              _RoundHeaderButton(icon: Icons.refresh_rounded, onTap: onRefresh),
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
                  'Your Vyla Wearable',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontFamily: 'Georgia',
                    fontSize: dims.scaleText(24),
                    fontWeight: FontWeight.w500,
                    color: titleColor,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(8)),
                Text(
                  "It's on the way! You can track your delivery\nin real time below.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(12),
                    height: 1.45,
                    color: subtitleColor,
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

class _RoundHeaderButton extends StatelessWidget {
  const _RoundHeaderButton({required this.icon, required this.onTap});

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

class _TrackingErrorState extends StatelessWidget {
  const _TrackingErrorState({required this.onRetry});

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
              'Could not load tracking details',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
                fontSize: dims.scaleText(13),
              ),
            ),
            SizedBox(height: dims.scaleSpace(10)),
            TextButton(onPressed: onRetry, child: Text(context.l10n.retryLabel)),
          ],
        ),
      ),
    );
  }
}

class _TrackingBody extends StatelessWidget {
  const _TrackingBody({required this.order});

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
        _TrackingStatusCard(order: order),
        SizedBox(height: dims.scaleSpace(12)),
        _TrackingOrderCard(order: order),
        SizedBox(height: dims.scaleSpace(12)),
        _TrackingTimelineCard(order: order),
        SizedBox(height: dims.scaleSpace(12)),
        _TrackingDetailsCard(order: order),
        SizedBox(height: dims.scaleSpace(12)),
        _TrackingHelpCard(),
        SizedBox(height: dims.scaleSpace(16)),
        _BackHomeButton(),
      ],
    );
  }
}

class _TrackingStatusCard extends StatelessWidget {
  const _TrackingStatusCard({required this.order});

  final WearableOrder order;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _shipmentStatus(order.fulfillmentStatus);
    final onTrack = order.fulfillmentStatus != 'cancelled';

    return _SoftTrackingCard(
      child: Row(
        children: [
          _PeachIcon(icon: status.icon),
          SizedBox(width: dims.scaleWidth(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STATUS',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: dims.scaleText(9),
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF8B7066),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(2)),
                Text(
                  status.label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontFamily: 'Georgia',
                    fontSize: dims.scaleText(21),
                    fontWeight: FontWeight.w500,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF10232B),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(3)),
                Text(
                  status.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(10.5),
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF5F4B45),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: dims.scaleWidth(10)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: dims.scaleWidth(10),
              vertical: dims.scaleSpace(5),
            ),
            decoration: BoxDecoration(
              color:
                  onTrack ? const Color(0xFFE6F4E7) : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
            ),
            child: Text(
              onTrack ? 'On Track' : 'Updated',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: dims.scaleText(9.5),
                fontWeight: FontWeight.w700,
                color:
                    onTrack ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingOrderCard extends StatelessWidget {
  const _TrackingOrderCard({required this.order});

  final WearableOrder order;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = DateFormat('d MMM yyyy').format(order.createdAt.toLocal());

    return _SoftTrackingCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WearablePlaceholder(),
              SizedBox(width: dims.scaleWidth(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: dims.scaleWidth(8),
                      runSpacing: dims.scaleSpace(4),
                      children: [
                        Text(
                          order.wearableName,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontFamily: 'Georgia',
                            fontSize: dims.scaleText(17),
                            fontWeight: FontWeight.w500,
                            color:
                                isDark
                                    ? colors.textPrimary
                                    : const Color(0xFF10232B),
                          ),
                        ),
                        _TinyPill('One-time purchase'),
                      ],
                    ),
                    SizedBox(height: dims.scaleSpace(12)),
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
                        SizedBox(width: dims.scaleWidth(14)),
                        Expanded(
                          child: _OrderMeta(label: 'Order date', value: date),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(14)),
          Divider(
            height: 1,
            color:
                isDark
                    ? colors.border
                    : const Color(0xFFFFE1D5).withValues(alpha: 0.8),
          ),
          SizedBox(height: dims.scaleSpace(14)),
          Row(
            children: [
              _PeachIcon(icon: Icons.calendar_month_outlined),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: _OrderMeta(
                  label: 'Estimated delivery',
                  value: _deliveryWindow(order),
                  accentValue: true,
                  caption: '3-5 business days',
                ),
              ),
              SizedBox(width: dims.scaleWidth(10)),
              _OrderMeta(
                label: 'Courier',
                value:
                    order.courier?.isNotEmpty == true ? order.courier! : 'TBC',
                alignEnd: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackingTimelineCard extends StatelessWidget {
  const _TrackingTimelineCard({required this.order});

  final WearableOrder order;

  @override
  Widget build(BuildContext context) {
    final entries = _timelineEntries(order);
    final currentIndex = entries.lastIndexWhere((entry) => entry.isCompleted);
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SoftTrackingCard(
      child: Column(
        children: List.generate(entries.length, (index) {
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
      ),
    );
  }
}

class _TrackingDetailsCard extends StatelessWidget {
  const _TrackingDetailsCard({required this.order});

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

    return _SoftTrackingCard(
      child: Column(
        children: [
          Row(
            children: [
              _PeachIcon(icon: Icons.shopping_bag_outlined),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tracking details',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: dims.scaleText(13),
                        fontWeight: FontWeight.w700,
                        color:
                            isDark
                                ? colors.textPrimary
                                : const Color(0xFF2D170F),
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(6)),
                    Text(
                      hasTracking
                          ? 'Tracking number\n${order.trackingNumber ?? 'Available'}'
                          : 'Tracking details will appear after dispatch.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: dims.scaleText(11),
                        height: 1.45,
                        color:
                            isDark
                                ? colors.textSecondary
                                : const Color(0xFF5F4B45),
                      ),
                    ),
                  ],
                ),
              ),
              if (order.trackingUrl?.isNotEmpty == true)
                OutlinedButton.icon(
                  onPressed: () => _launchTracking(order.trackingUrl!),
                  icon: Icon(
                    Icons.open_in_new_rounded,
                    size: dims.scaleText(13),
                  ),
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
          ),
          SizedBox(height: dims.scaleSpace(12)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: dims.scaleWidth(12),
              vertical: dims.scaleSpace(10),
            ),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? colors.bgSurface
                      : const Color(0xFFFFF3EC).withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(dims.scaleRadius(10)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: dims.scaleText(14),
                  color: const Color(0xFFB77A5D),
                ),
                SizedBox(width: dims.scaleWidth(8)),
                Expanded(
                  child: Text(
                    'Tracking updates may take up to 24 hours to appear.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: dims.scaleText(10),
                      color:
                          isDark
                              ? colors.textSecondary
                              : const Color(0xFF765B50),
                    ),
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

class _TrackingHelpCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SoftTrackingCard(
      compact: true,
      child: Row(
        children: [
          _PeachIcon(icon: Icons.help_outline_rounded, small: true),
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
                  'Visit our Help Centre or contact support.',
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

class _BackHomeButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return SizedBox(
      height: dims.scaleHeight(54),
      child: FilledButton(
        onPressed: () => context.go('/today'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B2F),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
          ),
          textStyle: TextStyle(
            fontSize: dims.scaleText(15),
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Row(
          children: [
            const Spacer(),
            Text(context.l10n.backToHomeLabel),
            const Spacer(),
            Icon(Icons.arrow_forward_rounded, size: dims.scaleText(21)),
          ],
        ),
      ),
    );
  }
}

class _SoftTrackingCard extends StatelessWidget {
  const _SoftTrackingCard({required this.child, this.compact = false});

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

class _PeachIcon extends StatelessWidget {
  const _PeachIcon({required this.icon, this.small = false});

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

class _WearablePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return SvgPicture.string(
      _wearableHeartWatchSvg,
      width: dims.scaleWidth(78),
      height: dims.scaleWidth(78),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill(this.label);

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

class _ShipmentStatus {
  const _ShipmentStatus(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;
}

_ShipmentStatus _shipmentStatus(String status) {
  return switch (status.toLowerCase()) {
    'processing' => const _ShipmentStatus(
      'Processing',
      "We're preparing your Vyla Wearable.",
      Icons.inventory_2_outlined,
    ),
    'dispatched' => const _ShipmentStatus(
      'Dispatched',
      'Your order is on its way.',
      Icons.local_shipping_outlined,
    ),
    'out_for_delivery' => const _ShipmentStatus(
      'Out for delivery',
      'Your order should arrive soon.',
      Icons.delivery_dining_outlined,
    ),
    'delivered' => const _ShipmentStatus(
      'Delivered',
      'Your Vyla Wearable has arrived.',
      Icons.check_circle_outline_rounded,
    ),
    'cancelled' => const _ShipmentStatus(
      'Cancelled',
      'This order is no longer being fulfilled.',
      Icons.cancel_outlined,
    ),
    _ => const _ShipmentStatus(
      'Order confirmed',
      "We've received your order.",
      Icons.local_shipping_outlined,
    ),
  };
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
    return DateFormat('d MMM yyyy').format(entry.completedAt!.toLocal());
  }
  return current ? 'Current step' : 'Upcoming';
}

String _deliveryWindow(WearableOrder order) {
  final estimated = order.estimatedDeliveryDate;
  if (estimated == null) {
    return 'To be confirmed';
  }
  return DateFormat('d MMM yyyy').format(estimated.toLocal());
}

Future<void> _launchTracking(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
