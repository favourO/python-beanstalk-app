import 'package:dio/dio.dart';
import 'package:phora/core/api/api_client.dart';
import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/core/api/versioned_api_url.dart';
import 'package:phora/features/wearables/domain/wearable_order_models.dart';

class WearableOrderRepository {
  WearableOrderRepository(this.apiClient);

  final ApiClient apiClient;

  Dio get _dio => apiClient.dio;

  // ── Inventory ──────────────────────────────────────────────────────────────

  Future<WearableAvailability> checkAvailability({
    String sku = 'VYLA-WEARABLE-V1',
    String? country,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(_dio, '/api/v1/wearable/inventory/availability'),
        queryParameters: {
          'sku': sku,
          if (country != null && country.isNotEmpty) 'country': country,
        },
      );
      final data = response.data ?? <String, dynamic>{};
      return WearableAvailability(
        sku: (data['sku'] as String?) ?? sku,
        productName: (data['product_name'] as String?) ?? 'Vyla Wearable',
        available: (data['available'] as bool?) ?? false,
        availableStock: (data['available_stock'] as int?) ?? 0,
        lowStock: (data['low_stock'] as bool?) ?? false,
        lowStockThreshold: (data['low_stock_threshold'] as int?) ?? 0,
        priceMinor: (data['price_minor'] as int?) ?? 2500,
        currency: (data['currency'] as String?) ?? 'GBP',
        currencySymbol: (data['currency_symbol'] as String?) ?? '£',
        displayPrice: (data['display_price'] as String?) ?? '£25.00',
        country: data['country'] as String?,
        countryCode: data['country_code'] as String?,
        availabilityReason: (data['availability_reason'] as String?) ?? 'in_stock',
        supportedCountryCodes: ((data['supported_country_codes'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  // ── Checkout ───────────────────────────────────────────────────────────────

  Future<WearableCheckoutSession> createAddonCheckout({
    required String country,
    required String planId,
    required String interval,
    required String wearableSku,
    required ShippingAddress shippingAddress,
    bool standalone = false,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(
          _dio,
          standalone
              ? '/api/v1/wearable/checkout/standalone'
              : '/api/v1/wearable/checkout/addon',
        ),
        data:
            standalone
                ? {
                  'wearable_sku': wearableSku,
                  'country': country,
                  'shipping_address': shippingAddress.toJson(),
                }
                : {
                  'country': country,
                  'plan_id': planId,
                  'interval': interval,
                  'wearable_sku': wearableSku,
                  'shipping_address': shippingAddress.toJson(),
                },
      );
      return WearableCheckoutSession.fromJson(
        response.data ?? <String, dynamic>{},
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<List<WearableOrder>> confirmCheckout({
    required WearableCheckoutSession session,
    required ShippingAddress shippingAddress,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        buildVersionedApiUrl(_dio, '/api/v1/wearable/checkout/confirm'),
        data: {
          'provider_payment_intent_id': session.providerPaymentIntentId,
          'provider_subscription_id': session.providerSubscriptionId,
          'wearable_sku': session.wearableSku,
          'shipping_address': shippingAddress.toJson(),
        },
      );
      final data = response.data ?? <String, dynamic>{};
      final raw = (data['orders'] as List?) ?? [];
      return raw
          .whereType<Map>()
          .map((e) => WearableOrder.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  // ── Orders ─────────────────────────────────────────────────────────────────

  Future<List<WearableOrder>> getMyOrders() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(_dio, '/api/v1/wearable/orders/my'),
      );
      final data = response.data ?? <String, dynamic>{};
      final raw = (data['orders'] as List?) ?? [];
      return raw
          .whereType<Map>()
          .map((e) => WearableOrder.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<WearableOrder> getOrder(String orderId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(_dio, '/api/v1/wearable/orders/$orderId'),
      );
      return WearableOrder.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<WearableOrder> getOrderTracking(String orderId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        buildVersionedApiUrl(_dio, '/api/v1/wearable/orders/$orderId/tracking'),
      );
      return WearableOrder.fromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}
