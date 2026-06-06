class WearableAvailability {
  const WearableAvailability({
    required this.sku,
    required this.productName,
    required this.available,
    required this.availableStock,
    required this.lowStock,
    required this.lowStockThreshold,
    required this.priceMinor,
    required this.currency,
    required this.currencySymbol,
    required this.displayPrice,
    this.country,
    this.countryCode,
    this.availabilityReason = 'in_stock',
    this.supportedCountryCodes = const [],
  });

  final String sku;
  final String productName;
  final bool available;
  final int availableStock;
  final bool lowStock;
  final int lowStockThreshold;
  final int priceMinor;
  final String currency;
  final String currencySymbol;
  final String displayPrice;
  final String? country;
  final String? countryCode;
  final String availabilityReason;
  final List<String> supportedCountryCodes;

  bool get isCountryBlocked => availabilityReason == 'country_not_allowed';
}

class ShippingAddress {
  const ShippingAddress({
    this.fullName,
    this.line1,
    this.line2,
    this.city,
    this.county,
    this.postcode,
    this.country,
    this.phone,
  });

  final String? fullName;
  final String? line1;
  final String? line2;
  final String? city;
  final String? county;
  final String? postcode;
  final String? country;
  final String? phone;

  Map<String, dynamic> toJson() => {
    'full_name': fullName,
    'line1': line1,
    'line2': line2,
    'city': city,
    'county': county,
    'postcode': postcode,
    'country': country,
    'phone': phone,
  };

  factory ShippingAddress.fromJson(Map<String, dynamic> json) =>
      ShippingAddress(
        fullName: json['full_name'] as String?,
        line1: json['line1'] as String?,
        line2: json['line2'] as String?,
        city: json['city'] as String?,
        county: json['county'] as String?,
        postcode: json['postcode'] as String?,
        country: json['country'] as String?,
        phone: json['phone'] as String?,
      );

  String get displayLines {
    final parts = <String>[
      if (fullName?.isNotEmpty == true) fullName!,
      if (line1?.isNotEmpty == true) line1!,
      if (line2?.isNotEmpty == true) line2!,
      if (city?.isNotEmpty == true) city!,
      if (postcode?.isNotEmpty == true) postcode!,
      if (country?.isNotEmpty == true) country!,
      if (phone?.isNotEmpty == true) phone!,
    ];
    return parts.join('\n');
  }
}

class WearableTimelineEntry {
  const WearableTimelineEntry({
    required this.status,
    required this.title,
    required this.description,
    this.completedAt,
  });

  final String status;
  final String title;
  final String description;
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  factory WearableTimelineEntry.fromJson(Map<String, dynamic> json) =>
      WearableTimelineEntry(
        status: (json['status'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        completedAt:
            json['completed_at'] != null
                ? DateTime.tryParse(json['completed_at'] as String)
                : null,
      );
}

class WearableOrder {
  const WearableOrder({
    required this.id,
    required this.orderNumber,
    required this.wearableSku,
    required this.wearableName,
    required this.wearablePrice,
    required this.wearableCurrency,
    required this.displayPrice,
    required this.paymentStatus,
    required this.fulfillmentStatus,
    required this.shippingAddress,
    required this.timeline,
    required this.createdAt,
    required this.updatedAt,
    this.trackingNumber,
    this.trackingUrl,
    this.courier,
    this.estimatedDeliveryDate,
    this.shippedAt,
    this.deliveredAt,
  });

  final String id;
  final String orderNumber;
  final String wearableSku;
  final String wearableName;
  final double wearablePrice;
  final String wearableCurrency;
  final String displayPrice;
  final String paymentStatus;
  final String fulfillmentStatus;
  final ShippingAddress shippingAddress;
  final List<WearableTimelineEntry> timeline;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? trackingNumber;
  final String? trackingUrl;
  final String? courier;
  final DateTime? estimatedDeliveryDate;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;

  bool get isDelivered => fulfillmentStatus == 'delivered';
  bool get isDispatched =>
      fulfillmentStatus == 'dispatched' ||
      fulfillmentStatus == 'out_for_delivery' ||
      isDelivered;
  bool get hasTracking =>
      trackingNumber?.isNotEmpty == true || trackingUrl?.isNotEmpty == true;

  factory WearableOrder.fromJson(Map<String, dynamic> json) {
    final addrJson = json['shipping_address'] as Map<String, dynamic>? ?? {};
    final timelineRaw = (json['timeline'] as List?) ?? [];
    return WearableOrder(
      id: (json['id'] as String?) ?? '',
      orderNumber: (json['order_number'] as String?) ?? '',
      wearableSku: (json['wearable_sku'] as String?) ?? '',
      wearableName: (json['wearable_name'] as String?) ?? 'Vyla Wearable',
      wearablePrice: ((json['wearable_price'] as num?) ?? 0).toDouble(),
      wearableCurrency: (json['wearable_currency'] as String?) ?? 'GBP',
      displayPrice: (json['display_price'] as String?) ?? '',
      paymentStatus: (json['payment_status'] as String?) ?? 'pending',
      fulfillmentStatus: (json['fulfillment_status'] as String?) ?? 'pending',
      shippingAddress: ShippingAddress.fromJson(addrJson),
      timeline:
          timelineRaw
              .whereType<Map>()
              .map(
                (e) => WearableTimelineEntry.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList(),
      createdAt:
          DateTime.tryParse((json['created_at'] as String?) ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((json['updated_at'] as String?) ?? '') ??
          DateTime.now(),
      trackingNumber: json['tracking_number'] as String?,
      trackingUrl: json['tracking_url'] as String?,
      courier: json['courier'] as String?,
      estimatedDeliveryDate:
          json['estimated_delivery_date'] != null
              ? DateTime.tryParse(json['estimated_delivery_date'] as String)
              : null,
      shippedAt:
          json['shipped_at'] != null
              ? DateTime.tryParse(json['shipped_at'] as String)
              : null,
      deliveredAt:
          json['delivered_at'] != null
              ? DateTime.tryParse(json['delivered_at'] as String)
              : null,
    );
  }
}

class WearableCheckoutSession {
  const WearableCheckoutSession({
    required this.paymentIntentClientSecret,
    required this.customerId,
    required this.customerEphemeralKeySecret,
    required this.publishableKey,
    required this.providerSubscriptionId,
    required this.planId,
    required this.interval,
    required this.currency,
    required this.subscriptionAmountMinor,
    required this.wearableAmountMinor,
    required this.totalAmountMinor,
    required this.displayPrice,
    required this.wearableSku,
    required this.wearableName,
    required this.providerPaymentIntentId,
    this.customerEmail,
  });

  final String paymentIntentClientSecret;
  final String customerId;
  final String customerEphemeralKeySecret;
  final String publishableKey;
  final String providerSubscriptionId;
  final String planId;
  final String interval;
  final String currency;
  final int subscriptionAmountMinor;
  final int wearableAmountMinor;
  final int totalAmountMinor;
  final String displayPrice;
  final String wearableSku;
  final String wearableName;
  final String providerPaymentIntentId;
  final String? customerEmail;

  factory WearableCheckoutSession.fromJson(
    Map<String, dynamic> json,
  ) => WearableCheckoutSession(
    paymentIntentClientSecret:
        (json['payment_intent_client_secret'] as String?) ?? '',
    customerId: (json['customer_id'] as String?) ?? '',
    customerEphemeralKeySecret:
        (json['customer_ephemeral_key_secret'] as String?) ?? '',
    publishableKey: (json['publishable_key'] as String?) ?? '',
    providerSubscriptionId: (json['provider_subscription_id'] as String?) ?? '',
    planId: (json['plan_id'] as String?) ?? '',
    interval: (json['interval'] as String?) ?? 'month',
    currency: (json['currency'] as String?) ?? 'GBP',
    subscriptionAmountMinor: (json['subscription_amount_minor'] as int?) ?? 0,
    wearableAmountMinor: (json['wearable_amount_minor'] as int?) ?? 0,
    totalAmountMinor: (json['total_amount_minor'] as int?) ?? 0,
    displayPrice: (json['display_price'] as String?) ?? '',
    wearableSku: (json['wearable_sku'] as String?) ?? '',
    wearableName: (json['wearable_name'] as String?) ?? 'Vyla Wearable',
    providerPaymentIntentId:
        (json['provider_payment_intent_id'] as String?) ??
        _paymentIntentIdFromClientSecret(
          (json['payment_intent_client_secret'] as String?) ?? '',
        ),
    customerEmail: json['customer_email'] as String?,
  );
}

String _paymentIntentIdFromClientSecret(String clientSecret) {
  final marker = '_secret_';
  final markerIndex = clientSecret.indexOf(marker);
  if (markerIndex <= 0) {
    return '';
  }
  return clientSecret.substring(0, markerIndex);
}
