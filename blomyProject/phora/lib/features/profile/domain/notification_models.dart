import 'package:flutter/material.dart';

@immutable
class NotificationQuietHours {
  const NotificationQuietHours({
    required this.enabled,
    required this.startTime,
    required this.endTime,
    required this.allowCriticalAlerts,
  });

  factory NotificationQuietHours.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return NotificationQuietHours(
      enabled: data['enabled'] != false,
      startTime: _readString(data['start_time']) ?? '22:00',
      endTime: _readString(data['end_time']) ?? '08:00',
      allowCriticalAlerts: data['allow_critical_alerts'] != false,
    );
  }

  final bool enabled;
  final String startTime;
  final String endTime;
  final bool allowCriticalAlerts;

  NotificationQuietHours copyWith({
    bool? enabled,
    String? startTime,
    String? endTime,
    bool? allowCriticalAlerts,
  }) {
    return NotificationQuietHours(
      enabled: enabled ?? this.enabled,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      allowCriticalAlerts: allowCriticalAlerts ?? this.allowCriticalAlerts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'start_time': startTime,
      'end_time': endTime,
      'allow_critical_alerts': allowCriticalAlerts,
    };
  }
}

@immutable
class NotificationSettings {
  const NotificationSettings({
    required this.allNotifications,
    required this.periodApproaching,
    required this.periodDetected,
    required this.fertileWindowOpen,
    required this.ovulationConfirmed,
    required this.cycleDelayAlert,
    required this.cyclePatternChange,
    required this.unusualSymptom,
    required this.stressAlert,
    required this.sleepAlert,
    required this.dailySymptomReminder,
    required this.bangleSyncReminder,
    required this.lhTestReminder,
    required this.blogPosts,
    required this.wearableOvulationReminder,
    required this.updateReminders,
    required this.quietHours,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return NotificationSettings(
      allNotifications: data['all_notifications'] != false,
      periodApproaching: data['period_approaching'] != false,
      periodDetected: data['period_detected'] != false,
      fertileWindowOpen: data['fertile_window_open'] != false,
      ovulationConfirmed: data['ovulation_confirmed'] != false,
      cycleDelayAlert: data['cycle_delay_alert'] != false,
      cyclePatternChange: data['cycle_pattern_change'] != false,
      unusualSymptom: data['unusual_symptom'] != false,
      stressAlert: data['stress_alert'] != false,
      sleepAlert: data['sleep_alert'] == true,
      dailySymptomReminder: data['daily_symptom_reminder'] == true,
      bangleSyncReminder: data['bangle_sync_reminder'] != false,
      lhTestReminder: data['lh_test_reminder'] == true,
      blogPosts: data['blog_posts'] != false,
      wearableOvulationReminder: data['wearable_ovulation_reminder'] != false,
      updateReminders: data['update_reminders'] != false,
      quietHours: NotificationQuietHours.fromJson(
        data['quiet_hours'] is Map<String, dynamic>
            ? data['quiet_hours'] as Map<String, dynamic>
            : null,
      ),
    );
  }

  final bool allNotifications;
  final bool periodApproaching;
  final bool periodDetected;
  final bool fertileWindowOpen;
  final bool ovulationConfirmed;
  final bool cycleDelayAlert;
  final bool cyclePatternChange;
  final bool unusualSymptom;
  final bool stressAlert;
  final bool sleepAlert;
  final bool dailySymptomReminder;
  final bool bangleSyncReminder;
  final bool lhTestReminder;
  final bool blogPosts;
  final bool wearableOvulationReminder;
  final bool updateReminders;
  final NotificationQuietHours quietHours;

  NotificationSettings copyWith({
    bool? allNotifications,
    bool? periodApproaching,
    bool? periodDetected,
    bool? fertileWindowOpen,
    bool? ovulationConfirmed,
    bool? cycleDelayAlert,
    bool? cyclePatternChange,
    bool? unusualSymptom,
    bool? stressAlert,
    bool? sleepAlert,
    bool? dailySymptomReminder,
    bool? bangleSyncReminder,
    bool? lhTestReminder,
    bool? blogPosts,
    bool? wearableOvulationReminder,
    bool? updateReminders,
    NotificationQuietHours? quietHours,
  }) {
    return NotificationSettings(
      allNotifications: allNotifications ?? this.allNotifications,
      periodApproaching: periodApproaching ?? this.periodApproaching,
      periodDetected: periodDetected ?? this.periodDetected,
      fertileWindowOpen: fertileWindowOpen ?? this.fertileWindowOpen,
      ovulationConfirmed: ovulationConfirmed ?? this.ovulationConfirmed,
      cycleDelayAlert: cycleDelayAlert ?? this.cycleDelayAlert,
      cyclePatternChange: cyclePatternChange ?? this.cyclePatternChange,
      unusualSymptom: unusualSymptom ?? this.unusualSymptom,
      stressAlert: stressAlert ?? this.stressAlert,
      sleepAlert: sleepAlert ?? this.sleepAlert,
      dailySymptomReminder: dailySymptomReminder ?? this.dailySymptomReminder,
      bangleSyncReminder: bangleSyncReminder ?? this.bangleSyncReminder,
      lhTestReminder: lhTestReminder ?? this.lhTestReminder,
      blogPosts: blogPosts ?? this.blogPosts,
      wearableOvulationReminder: wearableOvulationReminder ?? this.wearableOvulationReminder,
      updateReminders: updateReminders ?? this.updateReminders,
      quietHours: quietHours ?? this.quietHours,
    );
  }
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.category,
    required this.priority,
    required this.createdAt,
    required this.isRead,
    required this.actionUrl,
    required this.payload,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id:
          _readString(json['id']) ??
          _readString(json['notification_id']) ??
          _readString(json['event_id']) ??
          UniqueKey().toString(),
      notificationType: _readString(json['notification_type']) ?? 'update',
      title: _readString(json['title']) ?? 'Notification',
      body: _readString(json['body']) ?? '',
      category: _readString(json['category']) ?? 'general',
      priority: _readString(json['priority']) ?? 'medium',
      createdAt: _readDateTime(
        json['created_at'] ??
            json['delivered_at'] ??
            json['sent_at'] ??
            json['scheduled_for'] ??
            json['timestamp'],
      ),
      isRead:
          json['is_read'] == true ||
          json['read'] == true ||
          json['read_at'] != null,
      actionUrl: _readString(json['action_url'] ?? json['actionUrl']),
      payload:
          json['payload'] is Map
              ? Map<String, dynamic>.from(json['payload'] as Map)
              : const <String, dynamic>{},
    );
  }

  final String id;
  final String notificationType;
  final String title;
  final String body;
  final String category;
  final String priority;
  final DateTime? createdAt;
  final bool isRead;
  final String? actionUrl;
  final Map<String, dynamic>? payload;
}

@immutable
class NotificationHistory {
  const NotificationHistory({required this.items, required this.unreadCount});

  const NotificationHistory.empty() : items = const [], unreadCount = 0;

  final List<AppNotification> items;
  final int unreadCount;
}

String? _readString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  if (value is num) {
    return value.toString();
  }
  return null;
}

DateTime? _readDateTime(dynamic value) {
  final raw = _readString(value);
  if (raw == null) {
    return null;
  }
  return DateTime.tryParse(raw)?.toLocal();
}
