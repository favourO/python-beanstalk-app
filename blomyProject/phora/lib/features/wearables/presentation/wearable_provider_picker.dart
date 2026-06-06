import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/features/home/home_providers.dart';
import 'package:phora/features/wearables/domain/wearable_models.dart';
import 'package:phora/features/wearables/domain/wearable_provider.dart';
import 'package:phora/features/wearables/repositories/wearable_repository.dart';

Future<void> showWearableProviderPicker(
  BuildContext context,
  WidgetRef ref, {
  ValueChanged<WearableProviderDescriptor>? onVylaWearSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder:
        (context) => Consumer(
          builder: (context, ref, _) {
            return _WearableProviderPickerSheet(
              onSelected: (descriptor) async {
                Navigator.of(context).pop();
                if (descriptor.id == WearableProviderIds.vylaWearable &&
                    onVylaWearSelected != null) {
                  onVylaWearSelected(descriptor);
                  return;
                }
                await _connectProvider(context, ref, descriptor);
              },
            );
          },
        ),
  );
}

Future<void> _connectProvider(
  BuildContext context,
  WidgetRef ref,
  WearableProviderDescriptor descriptor,
) async {
  try {
    final repository = ref.read(wearableRepositoryProvider);
    await repository.connect(descriptor.id);
    if (descriptor.id == WearableProviderIds.vylaWearable) {
      try {
        await repository.sync(descriptor.id);
      } catch (_) {
        // Keep the pairing if collection/upload is temporarily unavailable.
        // The background controller and manual sync can retry without forcing
        // the user through pairing again.
      }
    }
    await ref.read(homeDashboardProvider.notifier).refresh();
    ref.invalidate(wearableConnectionStatusesProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${descriptor.name} connected to Vyla.')),
    );
  } catch (error) {
    final message =
        error is WearableConnectionException
            ? error.message
            : 'Could not connect ${descriptor.name}.';
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _WearableProviderPickerSheet extends ConsumerWidget {
  const _WearableProviderPickerSheet({required this.onSelected});

  final ValueChanged<WearableProviderDescriptor> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final providers = ref.watch(wearableProviderDescriptorsProvider);
    final statuses =
        ref.watch(wearableConnectionStatusesProvider).valueOrNull ?? const [];

    final anyConnected = statuses.any((s) => s.isConnected);
    final visibleProviders =
        anyConnected
            ? providers
                .where((p) => _statusFor(statuses, p.id)?.isConnected == true)
                .toList()
            : providers;

    return Container(
      margin: EdgeInsets.only(top: dims.scaleSpace(48)),
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(18),
        dims.scaleSpace(10),
        dims.scaleWidth(18),
        dims.scaleSpace(24),
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.bgElevated : const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(dims.scaleRadius(28)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: dims.scaleWidth(42),
              height: dims.scaleHeight(4),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          SizedBox(height: dims.scaleSpace(18)),
          Text(
            anyConnected ? 'Connected Wearable' : 'Connect Wearable',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFamily: AppTheme.headingFontFamily,
              fontSize: dims.scaleText(22),
              color: colors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: dims.scaleSpace(6)),
          Text(
            anyConnected
                ? 'Your connected device is syncing data to Vyla.'
                : 'Choose a source for sleep, heart, activity, and temperature trends. Vyla keeps BBT separate from daytime temperature.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
              height: 1.35,
              fontSize: dims.scaleText(12.5),
            ),
          ),
          SizedBox(height: dims.scaleSpace(16)),
          for (final provider in visibleProviders) ...[
            _ProviderPickerTile(
              descriptor: provider,
              status: _statusFor(statuses, provider.id),
              onTap: () => onSelected(provider),
            ),
            SizedBox(height: dims.scaleSpace(10)),
          ],
        ],
      ),
    );
  }

  WearableConnectionStatus? _statusFor(
    List<WearableConnectionStatus> statuses,
    String providerId,
  ) {
    for (final status in statuses) {
      if (status.providerId == providerId) {
        return status;
      }
    }
    return null;
  }
}

class _ProviderPickerTile extends StatelessWidget {
  const _ProviderPickerTile({
    required this.descriptor,
    required this.status,
    required this.onTap,
  });

  final WearableProviderDescriptor descriptor;
  final WearableConnectionStatus? status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final connected = status?.isConnected == true;

    return Material(
      color: isDark ? colors.bgSurface : Colors.white,
      borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(dims.scaleWidth(14)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
            border: Border.all(color: colors.border.withValues(alpha: 0.55)),
          ),
          child: Row(
            children: [
              Container(
                width: dims.scaleWidth(44),
                height: dims.scaleWidth(44),
                decoration: BoxDecoration(
                  color: descriptor.accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(dims.scaleRadius(15)),
                ),
                child: Icon(
                  descriptor.icon,
                  color: descriptor.accentColor,
                  size: dims.scaleText(22),
                ),
              ),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      descriptor.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: dims.scaleText(14),
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(3)),
                    Text(
                      descriptor.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        height: 1.3,
                        fontSize: dims.scaleText(11.5),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: dims.scaleWidth(8)),
              _StatusPill(connected: connected),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final color = connected ? const Color(0xFF2EAD68) : const Color(0xFFFF8A4C);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(9),
        vertical: dims.scaleSpace(5),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        connected ? 'Connected' : 'Connect',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontSize: dims.scaleText(10),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
