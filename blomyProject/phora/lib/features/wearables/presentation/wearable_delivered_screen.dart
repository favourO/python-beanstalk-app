import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/wearables/domain/wearable_order_models.dart';
import 'package:phora/features/wearables/presentation/wearable_widgets.dart';
import 'package:phora/features/wearables/providers/wearable_order_providers.dart';

class WearableDeliveredScreen extends ConsumerWidget {
  const WearableDeliveredScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  final String orderId;
  final WearableOrder? initialOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final orderAsync = ref.watch(wearableOrderProvider(orderId));

    final order = orderAsync.valueOrNull ?? initialOrder;

    if (order == null) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: dims.scaleSpace(20)),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/you');
                    }
                  },
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: dims.scaleWidth(20),
                    color: colors.textPrimary,
                  ),
                ),
              ),
              SizedBox(height: dims.scaleSpace(32)),
              Container(
                width: dims.scaleWidth(100),
                height: dims.scaleWidth(100),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF9F67F5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.watch_outlined,
                  size: dims.scaleWidth(52),
                  color: Colors.white,
                ),
              ),
              SizedBox(height: dims.scaleSpace(24)),
              Text(
                'Your Vyla Wearable\nhas arrived!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: dims.scaleText(26),
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: dims.scaleSpace(10)),
              Text(
                order.deliveredAt != null
                    ? 'Delivered on ${DateFormat('d MMMM yyyy').format(order.deliveredAt!.toLocal())}'
                    : 'Your order has been delivered.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textSecondary,
                  fontSize: dims.scaleText(14),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: dims.scaleSpace(32)),
              // Delivery summary card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.bgCard,
                  borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
                  border: Border.all(color: colors.border),
                ),
                padding: EdgeInsets.all(dims.scaleWidth(16)),
                child: Column(
                  children: [
                    _Row(
                      dims: dims,
                      colors: colors,
                      label: 'Order',
                      value: order.orderNumber,
                    ),
                    Divider(height: dims.scaleSpace(20), color: colors.divider),
                    _Row(
                      dims: dims,
                      colors: colors,
                      label: 'Item',
                      value: order.wearableName,
                    ),
                    if (order.courier?.isNotEmpty == true) ...[
                      Divider(
                        height: dims.scaleSpace(20),
                        color: colors.divider,
                      ),
                      _Row(
                        dims: dims,
                        colors: colors,
                        label: 'Delivered by',
                        value: order.courier!,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: dims.scaleSpace(20)),
              // Setup prompt
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE7F6),
                  borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
                ),
                padding: EdgeInsets.all(dims.scaleWidth(16)),
                child: Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_outlined,
                      size: dims.scaleWidth(24),
                      color: const Color(0xFF7C3AED),
                    ),
                    SizedBox(width: dims.scaleWidth(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Set up your wearable',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: dims.scaleText(13),
                              color: const Color(0xFF7C3AED),
                            ),
                          ),
                          SizedBox(height: dims.scaleSpace(2)),
                          Text(
                            'Go to Connected Devices in your profile to pair your Vyla wearable.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF6B21A8),
                              fontSize: dims.scaleText(11.5),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: dims.scaleSpace(24)),
              SizedBox(
                width: double.infinity,
                height: dims.scaleSpace(52),
                child: FilledButton(
                  onPressed: () => context.go('/you/connected-devices'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
                    ),
                  ),
                  child: Text(
                    'Set up now',
                    style: TextStyle(
                      fontSize: dims.scaleText(15),
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: dims.scaleSpace(12)),
              TextButton(
                onPressed: () => context.go('/today'),
                child: Text(
                  'Back to home',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: dims.scaleText(14),
                  ),
                ),
              ),
              SizedBox(height: dims.scaleSpace(20)),
              const WearableSupportCard(),
              SizedBox(height: dims.scaleSpace(32)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
            fontSize: dims.scaleText(12.5),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: dims.scaleText(12.5),
          ),
        ),
      ],
    );
  }
}
