import 'package:dio/dio.dart';
import 'package:phora/core/api/api_client.dart';
import 'package:phora/core/api/versioned_api_url.dart';
import 'package:url_launcher/url_launcher.dart';

class FitbitOAuthService {
  FitbitOAuthService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Dio get _dio => _apiClient.dio;

  Future<void> beginOAuth() async {
    final response = await _dio.get<Map<String, dynamic>>(
      buildVersionedApiUrl(_dio, '/api/v1/wearables/google-health/auth-url'),
    );
    final authUrl = response.data?['authorization_url'] as String?;
    if (authUrl == null || authUrl.trim().isEmpty) {
      throw StateError('Google Health authorization URL was not returned.');
    }
    final uri = Uri.parse(authUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open Google Health sign in.');
    }
  }

  Future<GoogleHealthConnectionStatus> getStatus() async {
    final response = await _dio.get<Map<String, dynamic>>(
      buildVersionedApiUrl(_dio, '/api/v1/wearables/google-health/status'),
    );
    return GoogleHealthConnectionStatus.fromJson(response.data ?? const {});
  }

  Future<GoogleHealthSyncResult> sync() async {
    final response = await _dio.post<Map<String, dynamic>>(
      buildVersionedApiUrl(_dio, '/api/v1/wearables/google-health/sync'),
    );
    return GoogleHealthSyncResult.fromJson(response.data ?? const {});
  }

  Future<void> disconnect() async {
    await _dio.post<void>(
      buildVersionedApiUrl(_dio, '/api/v1/wearables/google-health/disconnect'),
    );
  }
}

class GoogleHealthConnectionStatus {
  const GoogleHealthConnectionStatus({
    required this.connected,
    required this.syncHealth,
    this.lastSyncedAt,
    this.lastError,
  });

  final bool connected;
  final String syncHealth;
  final DateTime? lastSyncedAt;
  final String? lastError;

  factory GoogleHealthConnectionStatus.fromJson(Map<String, dynamic> json) {
    return GoogleHealthConnectionStatus(
      connected: json['connected'] == true,
      syncHealth: json['sync_health'] as String? ?? 'unavailable',
      lastSyncedAt: DateTime.tryParse(json['last_synced_at'] as String? ?? ''),
      lastError: json['last_error'] as String?,
    );
  }
}

class GoogleHealthSyncResult {
  const GoogleHealthSyncResult({
    required this.synced,
    required this.saved,
    this.lastSyncedAt,
    this.detail,
  });

  final bool synced;
  final int saved;
  final DateTime? lastSyncedAt;
  final String? detail;

  factory GoogleHealthSyncResult.fromJson(Map<String, dynamic> json) {
    return GoogleHealthSyncResult(
      synced: json['synced'] == true,
      saved: (json['saved'] as num?)?.toInt() ?? 0,
      lastSyncedAt: DateTime.tryParse(json['last_synced_at'] as String? ?? ''),
      detail: json['detail'] as String?,
    );
  }
}
