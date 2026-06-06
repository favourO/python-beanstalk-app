import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/wearables/domain/wearable_order_models.dart';

// ── Shipment status badge ───────────────────────────────────────────────────

class WearableStatusBadge extends StatelessWidget {
  const WearableStatusBadge({super.key, required this.fulfillmentStatus});

  final String fulfillmentStatus;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final (label, bg, fg) = _resolve(fulfillmentStatus);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(10),
        vertical: dims.scaleSpace(4),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: dims.scaleText(10),
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  static (String, Color, Color) _resolve(String status) {
    return switch (status) {
      'delivered' => ('Delivered', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      'dispatched' || 'out_for_delivery' => ('Dispatched', const Color(0xFFFFF8E1), const Color(0xFFE65100)),
      'processing' => ('Processing', const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
      'confirmed' => ('Confirmed', const Color(0xFFF3E5F5), const Color(0xFF6A1B9A)),
      _ => ('Pending', const Color(0xFFF5F5F5), const Color(0xFF424242)),
    };
  }
}

// ── Order summary card ──────────────────────────────────────────────────────

class WearableOrderSummaryCard extends StatelessWidget {
  const WearableOrderSummaryCard({
    super.key,
    required this.order,
    this.onTap,
  });

  final WearableOrder order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final dateStr = DateFormat('d MMM yyyy').format(order.createdAt.toLocal());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.bgCard,
          borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
          border: Border.all(color: colors.border),
        ),
        padding: EdgeInsets.all(dims.scaleWidth(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.wearableName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: dims.scaleText(14),
                    ),
                  ),
                ),
                WearableStatusBadge(fulfillmentStatus: order.fulfillmentStatus),
              ],
            ),
            SizedBox(height: dims.scaleSpace(6)),
            Text(
              order.orderNumber,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                fontSize: dims.scaleText(12),
              ),
            ),
            SizedBox(height: dims.scaleSpace(4)),
            Text(
              dateStr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textTertiary,
                fontSize: dims.scaleText(11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Timeline widget ────────────────────────────────────────────────────────

class WearableTimeline extends StatelessWidget {
  const WearableTimeline({super.key, required this.entries});

  final List<WearableTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Column(
      children: List.generate(entries.length, (i) {
        final entry = entries[i];
        final isLast = i == entries.length - 1;
        final completed = entry.isCompleted;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: dims.scaleWidth(20)),
              Column(
                children: [
                  Container(
                    width: dims.scaleWidth(20),
                    height: dims.scaleWidth(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: completed
                          ? const Color(0xFF7C3AED)
                          : colors.bgElevated,
                      border: Border.all(
                        color: completed
                            ? const Color(0xFF7C3AED)
                            : colors.border,
                        width: 2,
                      ),
                    ),
                    child: completed
                        ? Icon(
                            Icons.check,
                            size: dims.scaleWidth(12),
                            color: Colors.white,
                          )
                        : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: completed ? const Color(0xFF7C3AED) : colors.border,
                      ),
                    ),
                ],
              ),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: isLast ? 0 : dims.scaleSpace(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: dims.scaleText(13),
                          color: completed
                              ? colors.textPrimary
                              : colors.textTertiary,
                        ),
                      ),
                      SizedBox(height: dims.scaleSpace(2)),
                      Text(
                        entry.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                          fontSize: dims.scaleText(11.5),
                        ),
                      ),
                      if (entry.completedAt != null) ...[
                        SizedBox(height: dims.scaleSpace(2)),
                        Text(
                          DateFormat('d MMM, h:mm a').format(
                            entry.completedAt!.toLocal(),
                          ),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.textTertiary,
                            fontSize: dims.scaleText(10.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(width: dims.scaleWidth(20)),
            ],
          ),
        );
      }),
    );
  }
}

// ── Tracking info card ─────────────────────────────────────────────────────

class WearableTrackingCard extends StatelessWidget {
  const WearableTrackingCard({super.key, required this.order});

  final WearableOrder order;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
        border: Border.all(color: colors.border),
      ),
      padding: EdgeInsets.all(dims.scaleWidth(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tracking Info',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: dims.scaleText(13),
            ),
          ),
          SizedBox(height: dims.scaleSpace(12)),
          if (order.courier?.isNotEmpty == true)
            _TrackingRow(
              icon: Icons.local_shipping_outlined,
              label: 'Courier',
              value: order.courier!,
            ),
          if (order.trackingNumber?.isNotEmpty == true) ...[
            SizedBox(height: dims.scaleSpace(8)),
            _TrackingRow(
              icon: Icons.tag,
              label: 'Tracking No.',
              value: order.trackingNumber!,
            ),
          ],
          if (order.estimatedDeliveryDate != null) ...[
            SizedBox(height: dims.scaleSpace(8)),
            _TrackingRow(
              icon: Icons.calendar_today_outlined,
              label: 'Est. Delivery',
              value: DateFormat('d MMM yyyy').format(
                order.estimatedDeliveryDate!.toLocal(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackingRow extends StatelessWidget {
  const _TrackingRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    return Row(
      children: [
        Icon(icon, size: dims.scaleWidth(16), color: colors.textTertiary),
        SizedBox(width: dims.scaleWidth(8)),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
            fontSize: dims.scaleText(12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: dims.scaleText(12),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Support card ───────────────────────────────────────────────────────────

class WearableSupportCard extends StatelessWidget {
  const WearableSupportCard({super.key});

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
      ),
      padding: EdgeInsets.all(dims.scaleWidth(16)),
      child: Row(
        children: [
          Icon(
            Icons.help_outline_rounded,
            size: dims.scaleWidth(22),
            color: const Color(0xFF7C3AED),
          ),
          SizedBox(width: dims.scaleWidth(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need help?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: dims.scaleText(13),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(2)),
                Text(
                  'Contact support at hello@vyla.health',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                    fontSize: dims.scaleText(11.5),
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

// ── Shipping address display ───────────────────────────────────────────────

class ShippingAddressCard extends StatelessWidget {
  const ShippingAddressCard({super.key, required this.address});

  final ShippingAddress address;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final lines = address.displayLines;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.bgCard,
        borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
        border: Border.all(color: colors.border),
      ),
      padding: EdgeInsets.all(dims.scaleWidth(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: dims.scaleWidth(16),
                color: colors.textSecondary,
              ),
              SizedBox(width: dims.scaleWidth(6)),
              Text(
                'Shipping Address',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.textSecondary,
                  fontSize: dims.scaleText(11.5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(8)),
          Text(
            lines.isNotEmpty ? lines : 'No address provided',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textPrimary,
              fontSize: dims.scaleText(12.5),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section heading ────────────────────────────────────────────────────────

class WearableSectionHeading extends StatelessWidget {
  const WearableSectionHeading(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    return Text(
      title,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: colors.textSecondary,
        fontSize: dims.scaleText(11),
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}
