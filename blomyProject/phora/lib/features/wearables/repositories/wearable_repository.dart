import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/preferences/app_preferences.dart';
import 'package:phora/features/wearables/domain/wearable_models.dart';
import 'package:phora/features/wearables/domain/wearable_provider.dart';
import 'package:phora/features/wearables/providers/vyla_provider.dart';
import 'package:phora/features/wearables/sync/wearable_sync_queue.dart';

import '../data/gtl1_watch_sync_repository.dart';

final wearableProvidersProvider = Provider<List<WearableProvider>>((ref) {
  return <WearableProvider>[
    VylaWearableProvider(
      repository: ref.watch(gtl1WatchSyncRepositoryProvider),
    ),
  ];
});

final wearableRepositoryProvider = Provider<WearableRepository>((ref) {
  return WearableRepository(
    preferences: ref.watch(appPreferencesProvider),
    providers: ref.watch(wearableProvidersProvider),
    syncQueue: WearableSyncQueue(),
  );
});

final wearableProviderDescriptorsProvider =
    Provider<List<WearableProviderDescriptor>>((ref) {
      return ref
          .watch(wearableProvidersProvider)
          .map((provider) => provider.descriptor)
          .toList();
    });

final wearableConnectionStatusesProvider =
    FutureProvider<List<WearableConnectionStatus>>((ref) {
      return ref.watch(wearableRepositoryProvider).connectionStatuses();
    });

class WearableRepository {
  WearableRepository({
    required AppPreferences preferences,
    required List<WearableProvider> providers,
    required WearableSyncQueue syncQueue,
  }) : _preferences = preferences,
       _providers = {
         for (final provider in providers) provider.descriptor.id: provider,
       },
       _syncQueue = syncQueue;

  final AppPreferences _preferences;
  final Map<String, WearableProvider> _providers;
  final WearableSyncQueue _syncQueue;

  List<WearableProviderDescriptor> get descriptors =>
      _providers.values.map((provider) => provider.descriptor).toList();

  WearableProviderDescriptor descriptorFor(String providerId) {
    return _provider(providerId).descriptor;
  }

  Future<void> connect(String providerId) async {
    final existing = await connectionStatuses();
    for (final status in existing) {
      if (status.isConnected && status.providerId != providerId) {
        try {
          await disconnect(status.providerId);
        } catch (_) {}
      }
    }

    final provider = _provider(providerId);
    try {
      final previous = await _storedStatus(providerId);
      await provider.connect();
      final current = await provider.getConnectionStatus();
      await _saveStatus(_connectedStatus(current, previous));
    } catch (error) {
      await _saveStatus(
        WearableConnectionStatus(
          providerId: providerId,
          isConnected: false,
          syncHealth: WearableSyncHealth.needsAttention,
          lastError: _messageFor(error),
        ),
      );
      rethrow;
    }
  }

  Future<void> disconnect(String providerId) async {
    await _provider(providerId).disconnect();
    await _preferences.removeWearableConnectionRecord(providerId);
  }

  Future<WearableData> sync(String providerId) async {
    late WearableData data;
    await _syncQueue.enqueue(providerId, () async {
      data = await _provider(providerId).sync();
      await _saveStatus(
        WearableConnectionStatus(
          providerId: providerId,
          isConnected: true,
          syncHealth: WearableSyncHealth.healthy,
          connectedAt: DateTime.now(),
          lastSyncedAt: data.syncedAt,
          batteryLevel: data.batteryLevel,
          isCharging: data.isCharging,
        ),
      );
    });
    return data;
  }

  Future<List<WearableConnectionStatus>> connectionStatuses() async {
    final stored = await _preferences.getWearableConnectionRecords();
    final statuses = <String, WearableConnectionStatus>{
      for (final entry in stored.entries)
        entry.key: WearableConnectionStatus.fromJson(entry.key, entry.value),
    };

    final pairing = await _preferences.getPairedPhoraWear();
    if (pairing != null) {
      statuses[WearableProviderIds.vylaWearable] = WearableConnectionStatus(
        providerId: WearableProviderIds.vylaWearable,
        isConnected: true,
        syncHealth:
            pairing.lastSyncedAt == null
                ? WearableSyncHealth.stale
                : WearableSyncHealth.healthy,
        connectedAt: pairing.pairedAt,
        lastSyncedAt: pairing.lastSyncedAt,
      );
    }

    return descriptors
        .map(
          (descriptor) =>
              statuses[descriptor.id] ??
              WearableConnectionStatus(
                providerId: descriptor.id,
                isConnected: false,
                syncHealth: WearableSyncHealth.unavailable,
              ),
        )
        .toList();
  }

  Future<void> _saveStatus(WearableConnectionStatus status) {
    return _preferences.setWearableConnectionRecord(
      status.providerId,
      status.toJson(),
    );
  }

  Future<WearableConnectionStatus?> _storedStatus(String providerId) async {
    final stored = await _preferences.getWearableConnectionRecords();
    final json = stored[providerId];
    if (json == null) {
      return null;
    }
    return WearableConnectionStatus.fromJson(providerId, json);
  }

  WearableConnectionStatus _connectedStatus(
    WearableConnectionStatus current,
    WearableConnectionStatus? previous,
  ) {
    final lastSyncedAt = current.lastSyncedAt ?? previous?.lastSyncedAt;
    return WearableConnectionStatus(
      providerId: current.providerId,
      isConnected: true,
      syncHealth:
          lastSyncedAt == null
              ? current.syncHealth
              : WearableSyncHealth.healthy,
      connectedAt:
          current.connectedAt ?? previous?.connectedAt ?? DateTime.now(),
      lastSyncedAt: lastSyncedAt,
      batteryLevel: current.batteryLevel ?? previous?.batteryLevel,
      isCharging: current.isCharging ?? previous?.isCharging,
    );
  }

  WearableProvider _provider(String providerId) {
    final provider = _providers[providerId];
    if (provider == null) {
      throw ArgumentError.value(providerId, 'providerId', 'Unknown provider');
    }
    return provider;
  }

  String _messageFor(Object error) {
    if (error is WearableConnectionException) {
      return error.message;
    }
    return error.toString();
  }
}
