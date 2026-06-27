import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/features/home/domain/home_dashboard.dart';
import 'package:phora/features/wearables/domain/wearable_models.dart';
import 'package:phora/features/wearables/insights/bbt_collection_window_service.dart';
import 'package:phora/features/wearables/repositories/wearable_repository.dart';

final bbtReminderServiceProvider = Provider<BBTReminderService>((ref) {
  return BBTReminderService(
    wearableRepository: ref.watch(wearableRepositoryProvider),
  );
});

class BBTCollectionHomeState {
  const BBTCollectionHomeState({
    required this.window,
    required this.providerName,
    required this.statusLabel,
    required this.message,
    required this.actionLabel,
    required this.needsPermission,
    required this.syncNeeded,
  });

  final BBTCollectionWindow window;
  final String providerName;
  final String statusLabel;
  final String message;
  final String actionLabel;
  final bool needsPermission;
  final bool syncNeeded;
}

class BBTReminderService {
  BBTReminderService({required WearableRepository wearableRepository})
    : _wearableRepository = wearableRepository;

  final WearableRepository _wearableRepository;
  final BBTCollectionWindowService _windowService =
      const BBTCollectionWindowService();

  Future<BBTCollectionHomeState?> homeState(HomeDashboard dashboard) async {
    final window = _windowService.fromHomeDashboard(dashboard);
    if (window == null || !window.isTodayInCollectionWindow) {
      return null;
    }

    final statuses = await _wearableRepository.connectionStatuses();
    final connected = statuses.where((status) => status.isConnected).toList();
    if (connected.isEmpty) {
      return BBTCollectionHomeState(
        window: window,
        providerName: 'No wearable',
        statusLabel: 'Manual BBT suggested',
        message:
            'BBT tracking is active. Connect a wearable or log your temperature after waking to help Vyla improve this month’s prediction.',
        actionLabel: 'Connect wearable',
        needsPermission: false,
        syncNeeded: false,
      );
    }

    final status = connected.first;
    final descriptor = _wearableRepository.descriptorFor(status.providerId);
    final syncNeeded = status.isStale || status.lastSyncedAt == null;
    final lastSync = status.lastSyncedAt;
    return BBTCollectionHomeState(
      window: window,
      providerName: descriptor.name,
      statusLabel:
          syncNeeded
              ? '${descriptor.name} connected · Sync needed'
              : '${descriptor.name} connected · Last synced ${_relative(lastSync!)}',
      message:
          syncNeeded
              ? 'BBT tracking is active. Sync your device so Vyla can check for overnight temperature trends.'
              : 'BBT tracking is active. Wear your device tonight to help Vyla improve your ovulation prediction.',
      actionLabel: syncNeeded ? 'Sync device' : 'View device',
      needsPermission: status.syncHealth == WearableSyncHealth.needsAttention,
      syncNeeded: syncNeeded,
    );
  }

  String _relative(DateTime value) {
    final difference = DateTime.now().difference(value);
    if (difference.inMinutes < 1) {
      return 'just now';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inDays}d ago';
  }
}
