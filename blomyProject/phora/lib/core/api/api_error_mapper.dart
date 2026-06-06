import 'package:phora/features/subscription/domain/subscription_models.dart';
import 'package:dio/dio.dart';

sealed class ApiFailure implements Exception {
  const ApiFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final class UnexpectedApiFailure extends ApiFailure {
  const UnexpectedApiFailure() : super('Unexpected API error.');
}

final class MessageApiFailure extends ApiFailure {
  const MessageApiFailure(super.message);
}

final class PendingVerificationFailure extends ApiFailure {
  const PendingVerificationFailure({
    required this.email,
    String message =
        'Email not verified. A new verification code has been sent.',
  }) : super(message);

  final String email;
}

final class UnauthorizedFailure extends ApiFailure {
  const UnauthorizedFailure([super.message = 'Session expired.']);
}

final class FeatureGateFailure extends ApiFailure {
  const FeatureGateFailure({
    required this.reason,
    required this.requiredTier,
    required this.currentTier,
  }) : super('Feature is not available for the current plan.');

  final PaywallReason reason;
  final SubscriptionTier requiredTier;
  final SubscriptionTier currentTier;
}

final class ChatQuotaExceededFailure extends ApiFailure {
  ChatQuotaExceededFailure({
    required this.limit,
    required this.used,
    required this.resetAt,
    required this.tier,
  }) : super(_buildMessage(limit: limit, resetAt: resetAt, tier: tier));

  final int limit;
  final int used;
  final String resetAt;
  final String tier;

  static String _buildMessage({
    required int limit,
    required String resetAt,
    required String tier,
  }) {
    String resetLabel = '';
    try {
      final dt = DateTime.parse(resetAt).toLocal();
      resetLabel =
          ' Your quota resets on '
          '${dt.day}/${dt.month}/${dt.year} at '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}.';
    } catch (_) {}
    final tierLabel = tier == 'premium' ? 'premium' : 'free';
    return 'You\'ve used all $limit Vyla AI messages included in your $tierLabel plan this week.$resetLabel Upgrade for more.';
  }
}

ApiFailure mapDioError(DioException exception) {
  final statusCode = exception.response?.statusCode;
  final data = exception.response?.data;

  if (statusCode == 401) {
    final message = _extractErrorMessage(data);
    return UnauthorizedFailure(message ?? 'Session expired.');
  }

  if (statusCode == 402) {
    final detail = data is Map<String, dynamic> ? data['detail'] : null;
    final detailMap =
        detail is Map<String, dynamic> ? detail : <String, dynamic>{};
    final rawReason =
        data is Map<String, dynamic>
            ? (data['paywall_reason'] as String? ??
                detailMap['paywall_reason'] as String?)
            : null;
    return FeatureGateFailure(
      reason: switch (rawReason) {
        'stress_monitoring_premium' => PaywallReason.stressMonitoringPremium,
        'ai_chat_premium' => PaywallReason.aiChatPremium,
        'ovulation_shift_premium_plus' ||
        'ovulation_shift_premium' => PaywallReason.ovulationShiftPremium,
        _ => PaywallReason.genericUpgrade,
      },
      requiredTier: SubscriptionTier.premium,
      currentTier: SubscriptionTier.free,
    );
  }

  if (statusCode == 429) {
    final detail = data is Map<String, dynamic> ? data['detail'] : null;
    final quotaMap =
        detail is Map<String, dynamic>
            ? detail
            : data is Map<String, dynamic>
            ? data
            : null;
    if (quotaMap != null) {
      final limit = (quotaMap['chat_limit'] as num?)?.toInt();
      final used = (quotaMap['chats_used'] as num?)?.toInt();
      final resetAt = quotaMap['quota_reset_at'] as String?;
      final tier = (quotaMap['tier'] as String?) ?? 'free';
      if (limit != null && used != null && resetAt != null) {
        return ChatQuotaExceededFailure(
          limit: limit,
          used: used,
          resetAt: resetAt,
          tier: tier,
        );
      }
    }
    final message = _extractErrorMessage(data);
    return MessageApiFailure(
      message ?? 'You\'ve reached your Vyla AI message limit for this week.',
    );
  }

  final message = _extractErrorMessage(data);
  if (message != null) {
    return MessageApiFailure(message);
  }

  return const UnexpectedApiFailure();
}

String? _extractErrorMessage(dynamic data) {
  if (data is String && data.trim().isNotEmpty) {
    return data.trim();
  }

  if (data is! Map) {
    return null;
  }

  final map = Map<String, dynamic>.from(data);
  final detail = map['detail'];
  if (detail is String && detail.trim().isNotEmpty) {
    return detail.trim();
  }
  if (detail is Map) {
    final nested = detail['message'];
    if (nested is String && nested.trim().isNotEmpty) {
      return nested.trim();
    }
  }
  if (detail is List && detail.isNotEmpty) {
    final messages =
        detail
            .map((item) {
              if (item is String) {
                return item.trim();
              }
              if (item is Map && item['msg'] is String) {
                return (item['msg'] as String).trim();
              }
              return '';
            })
            .where((value) => value.isNotEmpty)
            .toList();
    if (messages.isNotEmpty) {
      return messages.join('\n');
    }
  }

  for (final key in const ['message', 'error']) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }

  return null;
}
