import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/api/api_client.dart';
import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/core/api/versioned_api_url.dart';

final aiChatRepositoryProvider = Provider<AiChatRepository>((ref) {
  return AiChatRepository(apiClient: ref.watch(apiClientProvider));
});

class AiChatRepository {
  AiChatRepository({required this.apiClient});

  final ApiClient apiClient;

  Dio get dio => apiClient.dio;

  Future<AiChatConsentStatus> fetchConsentStatus() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/ai/chat/consent'),
      );
      final data = response.data ?? <String, dynamic>{};
      return AiChatConsentStatus.fromJson(data);
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<AiChatConsentStatus> updateConsentStatus({
    required AiChatConsentStatus consent,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/ai/chat/consent'),
        data: consent.toJson(),
      );
      final data = response.data ?? <String, dynamic>{};
      return AiChatConsentStatus.fromJson(data);
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<AiChatResponse> sendMessage({
    String? threadId,
    required String message,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/ai/chat'),
        data: {
          if (threadId != null && threadId.isNotEmpty) 'thread_id': threadId,
          'message': message,
        },
      );
      final data = response.data ?? <String, dynamic>{};
      return AiChatResponse(
        threadId: _stringValue(data['thread_id']) ?? '',
        answer: _stringValue(data['answer']) ?? '',
        medicalOnly: data['medical_only'] == true,
        sufficientData: data['sufficient_data'] != false,
        usedUserData: _stringList(data['used_user_data']),
        savedRecords: _stringList(data['saved_records']),
        missingData: _missingDataList(data['missing_data']),
        disclaimer: _stringValue(data['disclaimer']),
        dataUseReceipt: _dataUseReceipt(data['data_use_receipt']),
        auditEventId: _stringValue(data['audit_event_id']),
        policyDecision: _stringValue(data['policy_decision']),
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Stream<AiChatStreamEvent> sendMessageStream({
    String? threadId,
    required String message,
  }) async* {
    late final Response<ResponseBody> response;
    try {
      response = await dio.post<ResponseBody>(
        buildVersionedApiUrl(dio, '/api/v1/ai/chat/stream'),
        data: {
          if (threadId != null && threadId.isNotEmpty) 'thread_id': threadId,
          'message': message,
        },
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero,
        ),
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }

    final stream = response.data?.stream;
    if (stream == null) return;

    var buffer = '';
    await for (final chunk in stream) {
      buffer += utf8.decode(chunk);
      final lines = buffer.split('\n');
      buffer = lines.removeLast();
      for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data: ')) continue;
        final payload = trimmed.substring(6).trim();
        if (payload.isEmpty) continue;
        try {
          final data = jsonDecode(payload);
          if (data is! Map<String, dynamic>) continue;
          final event = _parseStreamEvent(data);
          if (event != null) yield event;
        } catch (_) {}
      }
    }
    if (buffer.trim().startsWith('data: ')) {
      final payload = buffer.trim().substring(6).trim();
      try {
        final data = jsonDecode(payload);
        if (data is Map<String, dynamic>) {
          final event = _parseStreamEvent(data);
          if (event != null) yield event;
        }
      } catch (_) {}
    }
  }

  AiChatStreamEvent? _parseStreamEvent(Map<String, dynamic> data) {
    switch (data['event'] as String?) {
      case 'start':
        return AiChatStreamStart(
          threadId: _stringValue(data['thread_id']) ?? '',
          chatLimit: (data['chat_limit'] as num?)?.toInt(),
          chatsUsed: (data['chats_used'] as num?)?.toInt(),
          chatsRemaining: (data['chats_remaining'] as num?)?.toInt(),
          quotaResetAt: _stringValue(data['quota_reset_at']),
        );
      case 'delta':
        final text = data['text'] as String? ?? '';
        return text.isEmpty ? null : AiChatStreamDelta(text: text);
      case 'done':
        return AiChatStreamDone(
          sufficientData: data['sufficient_data'] != false,
          missingData: _missingDataList(data['missing_data']),
          savedRecords: _stringList(data['saved_records']),
          usedUserData: _stringList(data['used_user_data']),
          disclaimer: _stringValue(data['disclaimer']),
          dataUseReceipt: _dataUseReceipt(data['data_use_receipt']),
          auditEventId: _stringValue(data['audit_event_id']),
          policyDecision: _stringValue(data['policy_decision']),
        );
      case 'error':
        return AiChatStreamError(
          message:
              _stringValue(data['message']) ?? 'An unexpected error occurred.',
          code: _stringValue(data['code']),
        );
      default:
        return null;
    }
  }

  Future<AiChatResponse> analyzeDocument({
    required String filePath,
    required String filename,
    String? threadId,
    String? question,
    ProgressCallback? onUploadProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
        if (threadId != null && threadId.isNotEmpty) 'thread_id': threadId,
        if (question != null && question.trim().isNotEmpty)
          'question': question.trim(),
      });
      final response = await dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/ai/chat/document-analysis'),
        data: formData,
        onSendProgress: onUploadProgress,
      );
      final data = response.data ?? <String, dynamic>{};
      return AiChatResponse(
        threadId: _stringValue(data['thread_id']) ?? '',
        answer: _stringValue(data['answer']) ?? '',
        medicalOnly: data['medical_only'] == true,
        sufficientData: data['sufficient_data'] != false,
        usedUserData: _stringList(data['used_user_data']),
        savedRecords: _stringList(data['saved_records']),
        missingData: _missingDataList(data['missing_data']),
        disclaimer: _stringValue(data['disclaimer']),
        dataUseReceipt: _dataUseReceipt(data['data_use_receipt']),
        auditEventId: _stringValue(data['audit_event_id']),
        policyDecision: _stringValue(data['policy_decision']),
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<AiChatHistoryResponse> fetchLatestThread({
    String? before,
    int limit = 24,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/ai/chat/latest'),
        queryParameters: {
          'limit': limit,
          if (before != null && before.isNotEmpty) 'before': before,
        },
      );
      final data = response.data ?? <String, dynamic>{};
      return AiChatHistoryResponse(
        threadId: _stringValue(data['thread_id']),
        messages: _historyList(data['messages']),
        hasMore: data['has_more'] == true,
        nextBefore: _stringValue(data['next_before']),
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<AiChatThreadPage> fetchThreads({
    String? before,
    int limit = 20,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/ai/chat/threads'),
        queryParameters: {
          'limit': limit,
          if (before != null && before.isNotEmpty) 'before': before,
        },
      );
      final data = response.data ?? <String, dynamic>{};
      final rawThreads = data['threads'];
      if (rawThreads is! List) {
        return const AiChatThreadPage(threads: []);
      }
      final threads =
          rawThreads
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .map(AiChatThreadSummary.fromJson)
              .toList();
      return AiChatThreadPage(
        threads: threads,
        hasMore: data['has_more'] == true,
        nextBefore: _stringValue(data['next_before']),
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<AiDataUseReceipt> fetchDataUseReceipt({
    required String threadId,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/ai/chat/threads/$threadId/data-use'),
      );
      return AiDataUseReceipt.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<void> deleteAiMemory() async {
    try {
      await dio.delete<void>(
        buildVersionedApiUrl(dio, '/api/v1/ai/chat/memory'),
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<AiChatHistoryResponse> fetchThread(
    String threadId, {
    String? before,
    int limit = 24,
  }) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(dio, '/api/v1/ai/chat/threads/$threadId'),
        queryParameters: {
          'limit': limit,
          if (before != null && before.isNotEmpty) 'before': before,
        },
      );
      final data = response.data ?? <String, dynamic>{};
      return AiChatHistoryResponse(
        threadId: _stringValue(data['thread_id']),
        messages: _historyList(data['messages']),
        hasMore: data['has_more'] == true,
        nextBefore: _stringValue(data['next_before']),
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => _stringValue(item))
          .whereType<String>()
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  List<AiMissingDataPrompt> _missingDataList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => AiMissingDataPrompt(
            action: _stringValue(item['action']) ?? '',
            endpoint: _stringValue(item['endpoint']) ?? '',
            reason: _stringValue(item['reason']) ?? '',
            prompt: _stringValue(item['prompt']) ?? '',
            payloadTemplate:
                item['payload_template'] is Map
                    ? Map<String, dynamic>.from(item['payload_template'] as Map)
                    : const {},
          ),
        )
        .toList();
  }

  List<AiChatHistoryItem> _historyList(dynamic value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .map(
          (item) => AiChatHistoryItem(
            role: _stringValue(item['role']) ?? '',
            content: _stringValue(item['content']) ?? '',
            createdAt: _stringValue(item['created_at']),
          ),
        )
        .where((item) => item.role.isNotEmpty && item.content.isNotEmpty)
        .toList();
  }

  AiDataUseReceipt? _dataUseReceipt(dynamic value) {
    if (value is! Map) return null;
    return AiDataUseReceipt.fromJson(Map<String, dynamic>.from(value));
  }

  String? _stringValue(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num) {
      return value.toString();
    }
    return null;
  }
}

class AiChatResponse {
  const AiChatResponse({
    required this.threadId,
    required this.answer,
    required this.medicalOnly,
    required this.sufficientData,
    required this.usedUserData,
    required this.savedRecords,
    required this.missingData,
    this.disclaimer,
    this.dataUseReceipt,
    this.auditEventId,
    this.policyDecision,
  });

  final String threadId;
  final String answer;
  final bool medicalOnly;
  final bool sufficientData;
  final List<String> usedUserData;
  final List<String> savedRecords;
  final List<AiMissingDataPrompt> missingData;
  final String? disclaimer;
  final AiDataUseReceipt? dataUseReceipt;
  final String? auditEventId;
  final String? policyDecision;
}

class AiChatConsentStatus {
  const AiChatConsentStatus({
    required this.accepted,
    this.canUseAIInsights = false,
    this.canUseCycleLogs = false,
    this.canUseSymptoms = false,
    this.canUseWearableData = false,
    this.canUseIntimacyData = false,
    this.acceptedAt,
  });

  factory AiChatConsentStatus.fromJson(Map<String, dynamic> json) {
    final accepted =
        json['accepted'] == true || json['can_use_ai_insights'] == true;
    return AiChatConsentStatus(
      accepted: accepted,
      canUseAIInsights: json['can_use_ai_insights'] == true || accepted,
      canUseCycleLogs: json['can_use_cycle_logs'] == true || accepted,
      canUseSymptoms: json['can_use_symptoms'] == true || accepted,
      canUseWearableData: json['can_use_wearable_data'] == true,
      canUseIntimacyData: json['can_use_intimacy_data'] == true,
      acceptedAt: _stringJsonValue(json['accepted_at']),
    );
  }

  factory AiChatConsentStatus.fullConsent() {
    return const AiChatConsentStatus(
      accepted: true,
      canUseAIInsights: true,
      canUseCycleLogs: true,
      canUseSymptoms: true,
      canUseWearableData: true,
      canUseIntimacyData: true,
    );
  }

  AiChatConsentStatus copyWith({
    bool? accepted,
    bool? canUseAIInsights,
    bool? canUseCycleLogs,
    bool? canUseSymptoms,
    bool? canUseWearableData,
    bool? canUseIntimacyData,
    String? acceptedAt,
  }) {
    return AiChatConsentStatus(
      accepted: accepted ?? this.accepted,
      canUseAIInsights: canUseAIInsights ?? this.canUseAIInsights,
      canUseCycleLogs: canUseCycleLogs ?? this.canUseCycleLogs,
      canUseSymptoms: canUseSymptoms ?? this.canUseSymptoms,
      canUseWearableData: canUseWearableData ?? this.canUseWearableData,
      canUseIntimacyData: canUseIntimacyData ?? this.canUseIntimacyData,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accepted': accepted,
      'can_use_ai_insights': canUseAIInsights,
      'can_use_cycle_logs': canUseCycleLogs,
      'can_use_symptoms': canUseSymptoms,
      'can_use_wearable_data': canUseWearableData,
      'can_use_intimacy_data': canUseIntimacyData,
    };
  }

  final bool accepted;
  final bool canUseAIInsights;
  final bool canUseCycleLogs;
  final bool canUseSymptoms;
  final bool canUseWearableData;
  final bool canUseIntimacyData;
  final String? acceptedAt;
}

String? _stringJsonValue(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  if (value is num) {
    return value.toString();
  }
  return null;
}

class AiChatHistoryResponse {
  const AiChatHistoryResponse({
    required this.threadId,
    required this.messages,
    this.hasMore = false,
    this.nextBefore,
  });

  final String? threadId;
  final List<AiChatHistoryItem> messages;
  final bool hasMore;
  final String? nextBefore;
}

class AiChatHistoryItem {
  const AiChatHistoryItem({
    required this.role,
    required this.content,
    this.createdAt,
  });

  final String role;
  final String content;
  final String? createdAt;
}

class AiChatThreadSummary {
  const AiChatThreadSummary({
    required this.threadId,
    this.title,
    this.preview,
    this.createdAt,
    this.updatedAt,
    required this.messageCount,
  });

  factory AiChatThreadSummary.fromJson(Map<String, dynamic> json) {
    String? stringValue(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      return null;
    }

    return AiChatThreadSummary(
      threadId: stringValue(json['thread_id']) ?? '',
      title: stringValue(json['title']),
      preview: stringValue(json['preview']),
      createdAt: stringValue(json['created_at']),
      updatedAt: stringValue(json['updated_at']),
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
    );
  }

  final String threadId;
  final String? title;
  final String? preview;
  final String? createdAt;
  final String? updatedAt;
  final int messageCount;
}

class AiChatThreadPage {
  const AiChatThreadPage({
    required this.threads,
    this.hasMore = false,
    this.nextBefore,
  });

  final List<AiChatThreadSummary> threads;
  final bool hasMore;
  final String? nextBefore;
}

class AiMissingDataPrompt {
  const AiMissingDataPrompt({
    required this.action,
    required this.endpoint,
    required this.reason,
    required this.prompt,
    required this.payloadTemplate,
  });

  final String action;
  final String endpoint;
  final String reason;
  final String prompt;
  final Map<String, dynamic> payloadTemplate;
}

class AiDataUseReceipt {
  const AiDataUseReceipt({
    required this.usedData,
    required this.sensitivityLabels,
    this.policyDecision,
    this.auditEventId,
    this.retention,
  });

  factory AiDataUseReceipt.fromJson(Map<String, dynamic> json) {
    return AiDataUseReceipt(
      usedData: _stringListJson(json['used_data']),
      sensitivityLabels: _stringListJson(json['sensitivity_labels']),
      policyDecision: _stringJsonValue(json['policy_decision']),
      auditEventId: _stringJsonValue(json['audit_event_id']),
      retention: _stringJsonValue(json['retention']),
    );
  }

  final List<String> usedData;
  final List<String> sensitivityLabels;
  final String? policyDecision;
  final String? auditEventId;
  final String? retention;
}

List<String> _stringListJson(dynamic value) {
  if (value is! List) return const [];
  return value.map(_stringJsonValue).whereType<String>().toList();
}

sealed class AiChatStreamEvent {}

class AiChatStreamStart extends AiChatStreamEvent {
  AiChatStreamStart({
    required this.threadId,
    this.chatLimit,
    this.chatsUsed,
    this.chatsRemaining,
    this.quotaResetAt,
  });

  final String threadId;
  final int? chatLimit;
  final int? chatsUsed;
  final int? chatsRemaining;
  final String? quotaResetAt;
}

class AiChatStreamDelta extends AiChatStreamEvent {
  AiChatStreamDelta({required this.text});

  final String text;
}

class AiChatStreamDone extends AiChatStreamEvent {
  AiChatStreamDone({
    required this.sufficientData,
    required this.missingData,
    required this.savedRecords,
    required this.usedUserData,
    this.disclaimer,
    this.dataUseReceipt,
    this.auditEventId,
    this.policyDecision,
  });

  final bool sufficientData;
  final List<AiMissingDataPrompt> missingData;
  final List<String> savedRecords;
  final List<String> usedUserData;
  final String? disclaimer;
  final AiDataUseReceipt? dataUseReceipt;
  final String? auditEventId;
  final String? policyDecision;
}

class AiChatStreamError extends AiChatStreamEvent {
  AiChatStreamError({required this.message, this.code});

  final String message;
  final String? code;
}
