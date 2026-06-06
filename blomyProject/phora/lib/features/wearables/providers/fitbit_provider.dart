import 'package:flutter/material.dart';
import 'package:phora/features/wearables/domain/wearable_models.dart';
import 'package:phora/features/wearables/domain/wearable_provider.dart';
import 'package:phora/features/wearables/services/fitbit_oauth_service.dart';

class FitbitProvider implements WearableProvider {
  FitbitProvider({required FitbitOAuthService oauthService})
    : _oauthService = oauthService;

  final FitbitOAuthService _oauthService;
  bool _connected = false;

  @override
  WearableProviderDescriptor get descriptor => const WearableProviderDescriptor(
    id: WearableProviderIds.fitbit,
    source: WearableSource.fitbit,
    name: 'Fitbit',
    subtitle: 'Connect Fitbit sleep, HRV, heart rate, temperature, and steps.',
    icon: Icons.directions_run_rounded,
    accentColor: Color(0xFF00B0B9),
    capabilities: [
      'Sleep stages',
      'Resting heart rate',
      'HRV when available',
      'Temperature trends when available',
      'Activity and steps',
      'OAuth token refresh',
    ],
  );

  @override
  WearableProviderCapabilities get capabilities =>
      const WearableProviderCapabilities(
        supportsBBT: false,
        supportsSkinTemperature: true,
        supportsSleep: true,
        supportsHRV: true,
        supportsRestingHeartRate: true,
        supportsSteps: true,
      );

  @override
  Future<void> connect() async {
    final status = await _oauthService.getStatus();
    if (status.connected) {
      _connected = true;
      return;
    }
    await _oauthService.beginOAuth();
    throw const WearableConnectionException(
      'Finish Fitbit sign in, then return to Vyla to complete connection.',
    );
  }

  @override
  Future<void> disconnect() async {
    await _oauthService.disconnect();
    _connected = false;
  }

  @override
  Future<WearableData> sync() async {
    final status = await _oauthService.getStatus();
    if (!status.connected) {
      throw const WearableConnectionException('Fitbit is not connected.');
    }
    final result = await _oauthService.sync();
    return WearableData(
      providerId: WearableProviderIds.fitbit,
      syncedAt: result.lastSyncedAt ?? DateTime.now(),
      dailyMetrics: const [],
    );
  }

  @override
  bool get isConnected => _connected;

  @override
  Future<WearableConnectionStatus> getConnectionStatus() async {
    final status = await _oauthService.getStatus();
    return WearableConnectionStatus(
      providerId: WearableProviderIds.fitbit,
      isConnected: status.connected,
      syncHealth: _syncHealth(status.syncHealth),
      lastSyncedAt: status.lastSyncedAt,
      lastError: status.lastError,
    );
  }

  @override
  Future<DateTime?> getLastSuccessfulSync() async {
    return (await _oauthService.getStatus()).lastSyncedAt;
  }

  @override
  Future<BBTReading?> getLatestValidBBT() async {
    return null;
  }

  WearableSyncHealth _syncHealth(String value) {
    return switch (value) {
      'healthy' => WearableSyncHealth.healthy,
      'stale' => WearableSyncHealth.stale,
      'needs_attention' => WearableSyncHealth.needsAttention,
      _ => WearableSyncHealth.unavailable,
    };
  }
}
