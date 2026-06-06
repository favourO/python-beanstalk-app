import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/api/api_client.dart';
import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/core/api/versioned_api_url.dart';

final cycleRepositoryProvider = Provider<CycleRepository>((ref) {
  return CycleRepository(apiClient: ref.watch(apiClientProvider));
});

class CycleRepository {
  CycleRepository({required this.apiClient});

  final ApiClient apiClient;

  Dio get dio => apiClient.dio;

  Future<void> logPeriodStart({
    required DateTime startedAt,
    String? flowIntensity,
    String? flowColor,
    List<String>? symptoms,
    String? notes,
  }) async {
    await _post(
      '/api/v1/cycle/period/start',
      {
        'start_date': _dateOnly(startedAt),
      },
    );
  }

  Future<void> logLh({
    required DateTime logDate,
    required String state,
    required String testTime,
    bool? positive,
    double? ratio,
  }) async {
    await _post(
      '/api/v1/cycle/log/lh',
      {
        'log_date': _dateOnly(logDate),
        'test_time': testTime,
        'state': state,
        'positive': positive ?? _isPositiveLhState(state),
        if (ratio != null) 'ratio': ratio,
      },
    );
  }

  Future<LhImageAnalysisResult> logLhImage({
    required DateTime logDate,
    required String testTime,
    required String imagePath,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/cycle/log/lh/image'),
        data: FormData.fromMap({
          'log_date': _dateOnly(logDate),
          'test_time': testTime,
          'image': await MultipartFile.fromFile(
            imagePath,
            filename: imagePath.split(Platform.pathSeparator).last,
          ),
        }),
      );
      final payload = _payloadFromMap(response.data);
      return LhImageAnalysisResult(
        status: _stringValue(payload['status']) ?? 'rejected',
        stripValid: payload['strip_valid'] == true,
        state: _stringValue(payload['state']) ?? 'invalid_strip',
        positive: payload['positive'] == true,
        ratio: _doubleValue(payload['ratio']),
        confidence: _doubleValue(payload['confidence']),
        explanation: _stringValue(payload['explanation']),
        analysisVersion: _stringValue(payload['analysis_version']),
        logId: _stringValue(payload['log_id']),
        testTime: _stringValue(payload['test_time']),
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<LhLogHistoryResponse> fetchLhHistory({
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(
          dio,
          '/api/v1/cycle/log/lh/history?limit=$limit&offset=$offset',
        ),
      );
      final payload = _payloadFromMap(response.data);
      final rawItems =
          (payload['items'] is List ? payload['items'] as List : const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
      return LhLogHistoryResponse(
        items: rawItems.map(_lhHistoryItemFromJson).toList(),
        total: (payload['total'] as num?)?.toInt() ?? rawItems.length,
        limit: (payload['limit'] as num?)?.toInt() ?? limit,
        offset: (payload['offset'] as num?)?.toInt() ?? offset,
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<void> logMucus({
    required DateTime loggedAt,
    required String mucusType,
    required String amount,
    String? notes,
  }) async {
    await _post(
      '/api/v1/cycle/log/mucus',
      {
        'log_date': _dateOnly(loggedAt),
        'score': _mucusScore(
          mucusType: mucusType,
          amount: amount,
        ),
      },
    );
  }

  Future<void> logSymptoms({
    required DateTime logDate,
    required List<String> symptoms,
    required String severity,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    await _post(
      '/api/v1/cycle/symptom-log',
      {
        'log_date': _dateOnly(logDate),
        'symptoms': symptoms,
        'severity': severity,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      },
    );
  }

  Future<void> logIntimacy({
    required DateTime logDate,
    required bool hadIntimacy,
    required bool protectionUsed,
    required bool ejaculation,
    String? partnerGender,
    String? notes,
  }) async {
    await _post(
      '/api/v1/cycle/intimacy-log',
      {
        'log_date': _dateOnly(logDate),
        'had_intimacy': hadIntimacy,
        'protection_used': protectionUsed,
        'ejaculation': ejaculation,
        if (partnerGender != null && partnerGender.isNotEmpty)
          'partner_gender': partnerGender,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  Future<void> _post(String path, Map<String, dynamic> data) async {
    try {
      await dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, path),
        data: data,
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Map<String, dynamic> _payloadFromMap(Map<String, dynamic>? response) {
    final map = response ?? <String, dynamic>{};
    final data = map['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return map;
  }

  String? _stringValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  double? _doubleValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  bool _isPositiveLhState(String state) {
    return switch (state.trim().toLowerCase()) {
      'peak' || 'high' => true,
      _ => false,
    };
  }

  LhLogHistoryItem _lhHistoryItemFromJson(Map<String, dynamic> json) {
    return LhLogHistoryItem(
      id: _stringValue(json['id']) ?? '',
      logDate: _stringValue(json['log_date']) ?? '',
      testTime: _stringValue(json['test_time']),
      state: _stringValue(json['state']),
      rawValue: _doubleValue(json['raw_value']),
      ratio: _doubleValue(json['ratio']),
      positive: json['positive'] == true,
      cycleDay: (json['cycle_day'] as num?)?.toInt(),
      source: _stringValue(json['source']) ?? 'manual',
      stripValid: json['strip_valid'] as bool?,
      confidence: _doubleValue(json['confidence']),
      explanation: _stringValue(json['explanation']),
      analysisVersion: _stringValue(json['analysis_version']),
      loggedAt: _stringValue(json['logged_at']) ?? '',
    );
  }

  String _dateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  double _mucusScore({
    required String mucusType,
    required String amount,
  }) {
    final typeScore = switch (mucusType) {
      'Dry / None' => 0.0,
      'Sticky' => 0.25,
      'Creamy' => 0.5,
      'Watery' => 0.7,
      'Egg White (Fertile)' => 0.9,
      _ => 0.5,
    };

    final amountAdjustment = switch (amount) {
      'Light' => -0.1,
      'Moderate' => 0.0,
      'Heavy' => 0.1,
      _ => 0.0,
    };

    return (typeScore + amountAdjustment).clamp(0.0, 1.0);
  }
}

class LhImageAnalysisResult {
  const LhImageAnalysisResult({
    required this.status,
    required this.stripValid,
    required this.state,
    required this.positive,
    this.ratio,
    this.confidence,
    this.explanation,
    this.analysisVersion,
    this.logId,
    this.testTime,
  });

  final String status;
  final bool stripValid;
  final String state;
  final bool positive;
  final double? ratio;
  final double? confidence;
  final String? explanation;
  final String? analysisVersion;
  final String? logId;
  final String? testTime;
}

class LhLogHistoryResponse {
  const LhLogHistoryResponse({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<LhLogHistoryItem> items;
  final int total;
  final int limit;
  final int offset;
}

class LhLogHistoryItem {
  const LhLogHistoryItem({
    required this.id,
    required this.logDate,
    required this.positive,
    required this.source,
    required this.loggedAt,
    this.testTime,
    this.state,
    this.rawValue,
    this.ratio,
    this.cycleDay,
    this.stripValid,
    this.confidence,
    this.explanation,
    this.analysisVersion,
  });

  final String id;
  final String logDate;
  final String? testTime;
  final String? state;
  final double? rawValue;
  final double? ratio;
  final bool positive;
  final int? cycleDay;
  final String source;
  final bool? stripValid;
  final double? confidence;
  final String? explanation;
  final String? analysisVersion;
  final String loggedAt;
}
