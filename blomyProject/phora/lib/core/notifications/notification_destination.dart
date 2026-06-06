String notificationDestinationFromData(Map<String, dynamic> data) {
  final actionUrl = _readString(data['action_url'] ?? data['actionUrl']);
  final orderId = _readString(
    data['order_id'] ??
        data['orderId'] ??
        data['wearable_order_id'] ??
        data['wearableOrderId'],
  );

  if (orderId != null) {
    return '/wearable/orders/${Uri.encodeComponent(orderId)}/tracking';
  }

  final normalizedActionUrl = _normalizeActionUrl(actionUrl);
  if (normalizedActionUrl != null) {
    return normalizedActionUrl;
  }

  return '/notifications';
}

String? _normalizeActionUrl(String? actionUrl) {
  if (actionUrl == null || !actionUrl.startsWith('/')) {
    return null;
  }

  final uri = Uri.tryParse(actionUrl);
  if (uri == null) {
    return null;
  }

  final segments = uri.pathSegments;
  if (segments.length >= 3 &&
      segments[0] == 'wearable' &&
      segments[1] == 'orders') {
    return '/wearable/orders/${Uri.encodeComponent(segments[2])}';
  }

  return actionUrl;
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
