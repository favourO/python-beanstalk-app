import 'wearable_models.dart';

abstract class WearableProvider {
  WearableProviderDescriptor get descriptor;

  WearableProviderCapabilities get capabilities;

  Future<void> connect();

  Future<void> disconnect();

  Future<WearableData> sync();

  Future<WearableConnectionStatus> getConnectionStatus();

  Future<DateTime?> getLastSuccessfulSync();

  Future<BBTReading?> getLatestValidBBT();

  bool get isConnected;
}

class WearableConnectionException implements Exception {
  const WearableConnectionException(
    this.message, {
    this.canRetry = true,
    this.canOpenSettings = false,
  });

  final String message;
  final bool canRetry;
  final bool canOpenSettings;

  @override
  String toString() => message;
}
