import 'package:phora/app/env.dart';
import 'package:phora/core/api/api_client.dart';
import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/core/api/api_interceptors.dart';
import 'package:phora/features/subscription/domain/subscription_models.dart';
import 'package:dio/dio.dart';

class PricingCountrySignals {
  const PricingCountrySignals({
    required this.country,
    this.deviceLocaleCountry,
    this.deviceLocationCountry,
  });

  final String country;
  final String? deviceLocaleCountry;
  final String? deviceLocationCountry;

  Map<String, dynamic> toJson() {
    return {
      'country': country,
      'billing_country': country,
      if (deviceLocaleCountry != null && deviceLocaleCountry!.isNotEmpty)
        'device_locale_country': deviceLocaleCountry,
      if (deviceLocationCountry != null && deviceLocationCountry!.isNotEmpty)
        'device_location_country': deviceLocationCountry,
    };
  }

  Map<String, dynamic> toQueryParameters() => toJson();
}

class SubscriptionRepository {
  SubscriptionRepository(this.apiClient);

  final ApiClient apiClient;

  Future<SubscriptionState> getCurrentSubscription() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        _versionedApiUrl(kSubscriptionStatusPath),
      );
      return _subscriptionStateFromResponse(
        response.data ?? <String, dynamic>{},
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<List<Plan>> getPlans() async {
    return (await getPlanOffers(country: 'United Kingdom')).plans;
  }

  Future<BillingPlanOffers> getPlanOffers({required String country}) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        _versionedApiUrl(
          '/api/v1/billing/plan-offers?country=${Uri.encodeQueryComponent(country)}',
        ),
        options: Options(extra: const {kSkipUnauthorizedLogoutKey: true}),
      );
      return _planOffersFromResponse(
        response.data ?? <String, dynamic>{},
        fallbackCountry: country,
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<BillingPlanOffers> getPlanOffersWithSignals({
    required PricingCountrySignals signals,
  }) async {
    try {
      final query = signals.toQueryParameters();
      final response = await dio.get<Map<String, dynamic>>(
        _versionedApiUrl('/api/v1/billing/plan-offers'),
        queryParameters: query,
        options: Options(extra: const {kSkipUnauthorizedLogoutKey: true}),
      );
      return _planOffersFromResponse(
        response.data ?? <String, dynamic>{},
        fallbackCountry: signals.country,
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  BillingPlanOffers _planOffersFromResponse(
    Map<String, dynamic> body, {
    required String fallbackCountry,
  }) {
    final payload = _responsePayload(body);
    final rawPlans =
        (payload['plans'] is List ? payload['plans'] as List : const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

    return BillingPlanOffers(
      country:
          _firstString(payload, const [
            ['normalized_country'],
            ['country'],
          ]) ??
          fallbackCountry,
      supported:
          _firstBool(payload, const [
            ['supported'],
          ]) ??
          true,
      isFreeRegion:
          _firstBool(payload, const [
            ['isFreeRegion'],
            ['is_free_region'],
          ]) ??
          false,
      requiresPayment:
          _firstBool(payload, const [
            ['requiresPayment'],
            ['requires_payment'],
          ]) ??
          true,
      primaryProvider: _firstString(payload, const [
        ['primary_provider'],
      ]),
      availableProviders:
          (payload['available_providers'] is List
                  ? (payload['available_providers'] as List)
                  : const [])
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(),
      currency: _firstString(payload, const [
        ['currency'],
      ]),
      currencySymbol: _firstString(payload, const [
        ['currency_symbol'],
      ]),
      headline:
          _firstString(payload, const [
            ['headline'],
          ]) ??
          'Choose your Plan',
      subheadline:
          _firstString(payload, const [
            ['subheadline'],
          ]) ??
          'Pricing for $fallbackCountry',
      plans: rawPlans.map(_planFromJson).toList(),
    );
  }

  Future<List<Invoice>> getInvoices() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        _versionedApiUrl('/api/v1/billing/invoices'),
      );
      final body = response.data ?? <String, dynamic>{};
      final payload = _responsePayload(body);
      final rawItems =
          (payload['items'] is List ? payload['items'] as List : const [])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
      return rawItems.map(_invoiceFromJson).toList();
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<SubscriptionSelectionResult> saveSubscriptionSelection({
    required SubscriptionTier tier,
    String? interval,
    String? country,
    PricingCountrySignals? signals,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        _versionedApiUrl('/api/v1/billing/subscription-selection'),
        data: {
          'tier': _tierToApiValue(tier),
          if (interval != null && interval.isNotEmpty) 'interval': interval,
          if (country != null && country.isNotEmpty) 'country': country,
          if (signals != null) ...signals.toJson(),
        },
      );
      final body = response.data ?? <String, dynamic>{};
      final payload = _responsePayload(body);
      final provider =
          _firstString(payload, const [
            ['provider'],
          ]) ??
          _firstString(body, const [
            ['provider'],
          ]);
      final checkoutEndpoint =
          _firstString(payload, const [
            ['checkout_endpoint'],
          ]) ??
          _firstString(body, const [
            ['checkout_endpoint'],
          ]);
      final checkoutPublicKey =
          _firstString(payload, const [
            ['checkout_public_key'],
            ['publishable_key'],
          ]) ??
          _firstString(body, const [
            ['checkout_public_key'],
            ['publishable_key'],
          ]);
      final providerConfiguredFlag =
          _firstBool(payload, const [
            ['provider_configured'],
          ]) ??
          _firstBool(body, const [
            ['provider_configured'],
          ]);
      final providerConfigured =
          providerConfiguredFlag ??
          ((provider?.isNotEmpty ?? false) ||
              (checkoutEndpoint?.isNotEmpty ?? false) ||
              (checkoutPublicKey?.isNotEmpty ?? false));

      return SubscriptionSelectionResult(
        provider: provider,
        tier: _parseTier(
          _firstString(payload, const [
                ['tier'],
                ['subscription_tier'],
              ]) ??
              _firstString(body, const [
                ['tier'],
                ['subscription_tier'],
              ]),
        ),
        status:
            _firstString(payload, const [
              ['status'],
            ]) ??
            _firstString(body, const [
              ['status'],
            ]),
        selectionMade:
            _firstBool(payload, const [
              ['selection_made'],
            ]) ??
            _firstBool(body, const [
              ['selection_made'],
            ]) ??
            false,
        planSaved:
            _firstBool(payload, const [
              ['plan_saved'],
            ]) ??
            _firstBool(body, const [
              ['plan_saved'],
            ]) ??
            false,
        isActive:
            _firstBool(payload, const [
              ['is_active'],
            ]) ??
            _firstBool(body, const [
              ['is_active'],
            ]) ??
            false,
        redirectToHome:
            _firstBool(payload, const [
              ['redirect_to_home'],
            ]) ??
            _firstBool(body, const [
              ['redirect_to_home'],
            ]) ??
            false,
        showSubscriptionScreen:
            _firstBool(payload, const [
              ['show_subscription_screen'],
            ]) ??
            _firstBool(body, const [
              ['show_subscription_screen'],
            ]) ??
            false,
        isFreeRegion:
            _firstBool(payload, const [
              ['isFreeRegion'],
              ['is_free_region'],
            ]) ??
            _firstBool(body, const [
              ['isFreeRegion'],
              ['is_free_region'],
            ]) ??
            false,
        requiresPayment:
            _firstBool(payload, const [
              ['requiresPayment'],
              ['requires_payment'],
            ]) ??
            _firstBool(body, const [
              ['requiresPayment'],
              ['requires_payment'],
            ]) ??
            true,
        providerConfigured: providerConfigured,
        checkoutEndpoint: checkoutEndpoint,
        checkoutPublicKey: checkoutPublicKey,
        currency:
            _firstString(payload, const [
              ['currency'],
            ]) ??
            _firstString(body, const [
              ['currency'],
            ]),
        amount: _parseDouble(
          _firstValue(payload, const [
                ['amount'],
              ]) ??
              _firstValue(body, const [
                ['amount'],
              ]),
        ),
        billingInterval:
            _firstString(payload, const [
              ['billing_interval'],
            ]) ??
            _firstString(body, const [
              ['billing_interval'],
            ]),
        providerPriceId:
            _firstString(payload, const [
              ['provider_price_id'],
            ]) ??
            _firstString(body, const [
              ['provider_price_id'],
            ]),
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<CheckoutSession> createStripeCheckoutSession({
    required String country,
    required String planId,
    required String interval,
    required String successUrl,
    required String cancelUrl,
    PricingCountrySignals? signals,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        _versionedApiUrl('/api/v1/billing/stripe/checkout-sessions'),
        data: {
          'country': country,
          'plan_id': planId,
          'interval': interval,
          'success_url': successUrl,
          'cancel_url': cancelUrl,
          if (signals != null) ...signals.toJson(),
        },
      );
      final payload = _responsePayload(response.data ?? <String, dynamic>{});
      final checkoutUrl =
          _firstString(payload, const [
            ['checkout_url'],
            ['url'],
          ]) ??
          _firstString(response.data ?? <String, dynamic>{}, const [
            ['checkout_url'],
            ['url'],
          ]);

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw const UnexpectedApiFailure();
      }

      return CheckoutSession(
        provider:
            _firstString(payload, const [
              ['provider'],
            ]) ??
            _firstString(response.data ?? <String, dynamic>{}, const [
              ['provider'],
            ]) ??
            'stripe',
        checkoutUrl: checkoutUrl,
        sessionId:
            _firstString(payload, const [
              ['session_id'],
              ['checkout_session_id'],
              ['id'],
            ]) ??
            _firstString(response.data ?? <String, dynamic>{}, const [
              ['session_id'],
              ['checkout_session_id'],
              ['id'],
            ]),
        publicKey:
            _firstString(payload, const [
              ['publishable_key'],
              ['public_key'],
            ]) ??
            _firstString(response.data ?? <String, dynamic>{}, const [
              ['publishable_key'],
              ['public_key'],
            ]),
        customerEmail:
            _firstString(payload, const [
              ['customer_email'],
            ]) ??
            _firstString(response.data ?? <String, dynamic>{}, const [
              ['customer_email'],
            ]),
        providerProductId:
            _firstString(payload, const [
              ['provider_product_id'],
            ]) ??
            _firstString(response.data ?? <String, dynamic>{}, const [
              ['provider_product_id'],
            ]),
        providerPriceId:
            _firstString(payload, const [
              ['provider_price_id'],
            ]) ??
            _firstString(response.data ?? <String, dynamic>{}, const [
              ['provider_price_id'],
            ]),
        planId:
            _firstString(payload, const [
              ['plan_id'],
            ]) ??
            _firstString(response.data ?? <String, dynamic>{}, const [
              ['plan_id'],
            ]),
        interval:
            _firstString(payload, const [
              ['interval'],
            ]) ??
            _firstString(response.data ?? <String, dynamic>{}, const [
              ['interval'],
            ]),
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<StripePaymentSheetSession> createStripePaymentSheetSession({
    required String country,
    required String planId,
    required String interval,
    PricingCountrySignals? signals,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        _versionedApiUrl('/api/v1/billing/stripe/payment-sheet'),
        data: {
          'country': country,
          'plan_id': planId,
          'interval': interval,
          if (signals != null) ...signals.toJson(),
        },
      );
      final body = response.data ?? <String, dynamic>{};
      final payload = _responsePayload(body);
      final paymentIntentClientSecret =
          _firstString(payload, const [
            ['payment_intent_client_secret'],
          ]) ??
          _firstString(body, const [
            ['payment_intent_client_secret'],
          ]);
      final customerId =
          _firstString(payload, const [
            ['customer_id'],
          ]) ??
          _firstString(body, const [
            ['customer_id'],
          ]);
      final customerEphemeralKeySecret =
          _firstString(payload, const [
            ['customer_ephemeral_key_secret'],
          ]) ??
          _firstString(body, const [
            ['customer_ephemeral_key_secret'],
          ]);
      final publishableKey =
          _firstString(payload, const [
            ['publishable_key'],
          ]) ??
          _firstString(body, const [
            ['publishable_key'],
          ]);
      final subscriptionId =
          _firstString(payload, const [
            ['provider_subscription_id'],
          ]) ??
          _firstString(body, const [
            ['provider_subscription_id'],
          ]);
      final providerProductId =
          _firstString(payload, const [
            ['provider_product_id'],
          ]) ??
          _firstString(body, const [
            ['provider_product_id'],
          ]);
      final providerPriceId =
          _firstString(payload, const [
            ['provider_price_id'],
          ]) ??
          _firstString(body, const [
            ['provider_price_id'],
          ]);
      if (paymentIntentClientSecret == null ||
          customerId == null ||
          customerEphemeralKeySecret == null ||
          publishableKey == null ||
          subscriptionId == null ||
          providerProductId == null ||
          providerPriceId == null) {
        throw const UnexpectedApiFailure();
      }

      return StripePaymentSheetSession(
        paymentIntentClientSecret: paymentIntentClientSecret,
        customerId: customerId,
        customerEphemeralKeySecret: customerEphemeralKeySecret,
        publishableKey: publishableKey,
        customerEmail:
            _firstString(payload, const [
              ['customer_email'],
            ]) ??
            _firstString(body, const [
              ['customer_email'],
            ]),
        subscriptionId: subscriptionId,
        providerProductId: providerProductId,
        providerPriceId: providerPriceId,
        planId:
            _firstString(payload, const [
              ['plan_id'],
            ]) ??
            _firstString(body, const [
              ['plan_id'],
            ]) ??
            planId,
        interval:
            _firstString(payload, const [
              ['interval'],
            ]) ??
            _firstString(body, const [
              ['interval'],
            ]) ??
            interval,
        currency:
            _firstString(payload, const [
              ['currency'],
            ]) ??
            _firstString(body, const [
              ['currency'],
            ]) ??
            '',
        amountMinor:
            _parseInt(
              _firstValue(payload, const [
                    ['amount_minor'],
                  ]) ??
                  _firstValue(body, const [
                    ['amount_minor'],
                  ]),
            ) ??
            0,
        displayPrice:
            _firstString(payload, const [
              ['display_price'],
            ]) ??
            _firstString(body, const [
              ['display_price'],
            ]) ??
            '',
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<SubscriptionState> syncStripePaymentSheetSubscription({
    required String subscriptionId,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        _versionedApiUrl('/api/v1/billing/stripe/payment-sheet/sync'),
        data: {'provider_subscription_id': subscriptionId},
      );
      return _subscriptionStateFromResponse(
        response.data ?? <String, dynamic>{},
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<SubscriptionState> verifyAppleReceipt({
    required String receiptData,
    required String productId,
  }) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        _versionedApiUrl('/api/v1/billing/apple/verify-receipt'),
        data: {'receipt_data': receiptData, 'product_id': productId},
      );
      return _subscriptionStateFromResponse(
        response.data ?? <String, dynamic>{},
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<SubscriptionState> cancelSubscription() async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        _versionedApiUrl('/api/v1/billing/subscription/cancel'),
        data: const {'immediate': false},
      );
      return _subscriptionStateFromResponse(
        response.data ?? <String, dynamic>{},
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<SubscriptionState> restartSubscription() async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        _versionedApiUrl('/api/v1/billing/subscription/restart'),
      );
      return _subscriptionStateFromResponse(
        response.data ?? <String, dynamic>{},
      );
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<SubscriptionState> changeSubscriptionInterval({
    required String country,
    required String interval,
  }) async {
    try {
      await dio.post<Map<String, dynamic>>(
        _versionedApiUrl('/api/v1/billing/subscription/change-interval'),
        data: {'country': country, 'interval': interval},
      );
      return getCurrentSubscription();
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Future<SubscriptionState> cancelScheduledSubscriptionIntervalChange() async {
    try {
      await dio.post<Map<String, dynamic>>(
        _versionedApiUrl('/api/v1/billing/subscription/change-interval/cancel'),
      );
      return getCurrentSubscription();
    } on DioException catch (exception) {
      throw mapDioError(exception);
    }
  }

  Invoice _invoiceFromJson(Map<String, dynamic> json) {
    return Invoice(
      id:
          _firstString(json, const [
            ['id'],
          ]) ??
          '',
      itemType:
          _firstString(json, const [
            ['item_type'],
            ['itemType'],
            ['type'],
          ]) ??
          'payment',
      title: _firstString(json, const [
        ['title'],
      ]),
      subtitle: _firstString(json, const [
        ['subtitle'],
      ]),
      actionUrl: _firstString(json, const [
        ['action_url'],
        ['actionUrl'],
      ]),
      providerInvoiceId: _firstString(json, const [
        ['provider_invoice_id'],
      ]),
      amountLabel:
          _firstString(json, const [
            ['amount_label'],
            ['amountLabel'],
          ]) ??
          '',
      status:
          _firstString(json, const [
            ['status'],
          ]) ??
          '',
      createdAt: _parseDateTime(
        _firstString(json, const [
          ['created_at'],
          ['createdAt'],
        ]),
      ),
    );
  }

  SubscriptionState _subscriptionStateFromResponse(Map<String, dynamic> body) {
    final payload = _responsePayload(body);

    return SubscriptionState(
      tier: _parseTier(
        _firstString(payload, const [
              ['tier'],
              ['subscription_tier'],
              ['plan', 'tier'],
              ['plan', 'name'],
              ['subscription', 'tier'],
              ['subscription', 'plan', 'tier'],
            ]) ??
            _firstString(body, const [
              ['tier'],
              ['subscription_tier'],
            ]),
      ),
      status: _parseStatus(
        _firstString(payload, const [
              ['status'],
              ['subscription_status'],
              ['subscription', 'status'],
            ]) ??
            _firstString(body, const [
              ['status'],
              ['subscription_status'],
            ]),
      ),
      nextBillingDate: _parseDateTime(
        _firstString(payload, const [
              ['next_billing_date'],
              ['nextBillingDate'],
              ['current_period_end'],
              ['subscription', 'next_billing_date'],
            ]) ??
            _firstString(body, const [
              ['next_billing_date'],
              ['nextBillingDate'],
            ]),
      ),
      processor:
          _firstString(payload, const [
            ['processor'],
            ['payment_processor'],
            ['subscription', 'processor'],
          ]) ??
          _firstString(body, const [
            ['processor'],
            ['payment_processor'],
          ]),
      trialEndsAt: _parseDateTime(
        _firstString(payload, const [
              ['trial_ends_at'],
              ['trialEndsAt'],
              ['subscription', 'trial_ends_at'],
            ]) ??
            _firstString(body, const [
              ['trial_ends_at'],
              ['trialEndsAt'],
            ]),
      ),
      currency:
          _firstString(payload, const [
            ['currency'],
          ]) ??
          _firstString(body, const [
            ['currency'],
          ]),
      amount: _parseDouble(
        _firstValue(payload, const [
              ['amount'],
            ]) ??
            _firstValue(body, const [
              ['amount'],
            ]),
      ),
      billingInterval:
          _firstString(payload, const [
            ['billing_interval'],
          ]) ??
          _firstString(body, const [
            ['billing_interval'],
          ]),
      providerPriceId:
          _firstString(payload, const [
            ['provider_price_id'],
          ]) ??
          _firstString(body, const [
            ['provider_price_id'],
          ]),
      cancelAtPeriodEnd:
          _firstBool(payload, const [
            ['cancel_at_period_end'],
            ['cancelAtPeriodEnd'],
          ]) ??
          _firstBool(body, const [
            ['cancel_at_period_end'],
            ['cancelAtPeriodEnd'],
          ]) ??
          false,
      pendingBillingInterval:
          _firstString(payload, const [
            ['pending_billing_interval'],
            ['pendingBillingInterval'],
          ]) ??
          _firstString(body, const [
            ['pending_billing_interval'],
            ['pendingBillingInterval'],
          ]),
      pendingProviderPriceId:
          _firstString(payload, const [
            ['pending_provider_price_id'],
            ['pendingProviderPriceId'],
          ]) ??
          _firstString(body, const [
            ['pending_provider_price_id'],
            ['pendingProviderPriceId'],
          ]),
      pendingAmount: _parseDouble(
        _firstValue(payload, const [
              ['pending_amount'],
              ['pendingAmount'],
            ]) ??
            _firstValue(body, const [
              ['pending_amount'],
              ['pendingAmount'],
            ]),
      ),
      pendingCurrency:
          _firstString(payload, const [
            ['pending_currency'],
            ['pendingCurrency'],
          ]) ??
          _firstString(body, const [
            ['pending_currency'],
            ['pendingCurrency'],
          ]),
      pendingChangeEffectiveAt: _parseDateTime(
        _firstString(payload, const [
              ['pending_change_effective_at'],
              ['pendingChangeEffectiveAt'],
            ]) ??
            _firstString(body, const [
              ['pending_change_effective_at'],
              ['pendingChangeEffectiveAt'],
            ]),
      ),
      planSaved:
          _firstBool(payload, const [
            ['plan_saved'],
          ]) ??
          _firstBool(body, const [
            ['plan_saved'],
          ]) ??
          false,
      isActive:
          _firstBool(payload, const [
            ['is_active'],
          ]) ??
          _firstBool(body, const [
            ['is_active'],
          ]) ??
          false,
      redirectToHome:
          _firstBool(payload, const [
            ['redirect_to_home'],
          ]) ??
          _firstBool(body, const [
            ['redirect_to_home'],
          ]) ??
          false,
      contributorEnrolled:
          _firstBool(payload, const [
            ['contributor_enrolled'],
            ['contributorEnrolled'],
            ['subscription', 'contributor_enrolled'],
          ]) ??
          _firstBool(body, const [
            ['contributor_enrolled'],
            ['contributorEnrolled'],
          ]) ??
          false,
    );
  }

  Map<String, dynamic> _responsePayload(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return response;
  }

  String? _firstString(Map<String, dynamic> source, List<List<String>> paths) {
    for (final path in paths) {
      dynamic current = source;
      for (final key in path) {
        if (current is Map && current.containsKey(key)) {
          current = current[key];
        } else {
          current = null;
          break;
        }
      }
      if (current is String && current.trim().isNotEmpty) {
        return current.trim();
      }
    }
    return null;
  }

  bool? _firstBool(Map<String, dynamic> source, List<List<String>> paths) {
    for (final path in paths) {
      dynamic current = source;
      for (final key in path) {
        if (current is Map && current.containsKey(key)) {
          current = current[key];
        } else {
          current = null;
          break;
        }
      }
      if (current is bool) {
        return current;
      }
    }
    return null;
  }

  dynamic _firstValue(Map<String, dynamic> source, List<List<String>> paths) {
    for (final path in paths) {
      dynamic current = source;
      for (final key in path) {
        if (current is Map && current.containsKey(key)) {
          current = current[key];
        } else {
          current = null;
          break;
        }
      }
      if (current != null) {
        return current;
      }
    }
    return null;
  }

  SubscriptionTier _parseTier(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'premium' => SubscriptionTier.premium,
      'premium_plus' ||
      'premium-plus' ||
      'premiumplus' ||
      'clinician' => SubscriptionTier.premium,
      _ => SubscriptionTier.free,
    };
  }

  String _tierToApiValue(SubscriptionTier tier) {
    return switch (tier) {
      SubscriptionTier.free => 'free',
      SubscriptionTier.premium => 'premium_plus',
    };
  }

  SubscriptionStatus _parseStatus(String? raw) {
    return switch (raw?.trim().toLowerCase()) {
      'active' => SubscriptionStatus.active,
      'trialing' || 'trial' => SubscriptionStatus.trialing,
      'past_due' || 'pastdue' => SubscriptionStatus.pastDue,
      'canceled' || 'cancelled' => SubscriptionStatus.canceled,
      _ => SubscriptionStatus.none,
    };
  }

  DateTime? _parseDateTime(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  double? _parseDouble(dynamic raw) {
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw);
    }
    return null;
  }

  int? _parseInt(dynamic raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }

  Dio get dio => apiClient.dio;

  String _versionedApiUrl(String path) {
    final baseUrl = dio.options.baseUrl;
    final match = RegExp(r'^(https?://[^/]+)').firstMatch(baseUrl);
    final origin = match?.group(1);
    if (origin == null) {
      return path;
    }
    return '$origin$path';
  }

  Plan _planFromJson(Map<String, dynamic> json) {
    final priceOptions =
        (json['price_options'] is List
                ? json['price_options'] as List
                : const [])
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .map(
              (option) => PlanPriceOption(
                interval:
                    _firstString(option, const [
                      ['interval'],
                      ['billing_period'],
                    ]) ??
                    'month',
                displayPrice: _firstString(option, const [
                  ['display_price'],
                  ['price_label'],
                ]),
                provider: _firstString(option, const [
                  ['provider'],
                ]),
              ),
            )
            .toList();

    return Plan(
      id:
          _firstString(json, const [
            ['id'],
          ]) ??
          'plan',
      tier: _parseTier(
        _firstString(json, const [
          ['tier'],
          ['id'],
          ['name'],
        ]),
      ),
      name:
          _firstString(json, const [
            ['name'],
          ]) ??
          'Plan',
      priceLabel:
          _firstString(json, const [
            ['display_price'],
            ['price_label'],
          ]) ??
          '',
      description: _firstString(json, const [
        ['description'],
      ]),
      currency: _firstString(json, const [
        ['currency'],
      ]),
      currencySymbol: _firstString(json, const [
        ['currency_symbol'],
      ]),
      displayPrice:
          _firstString(json, const [
            ['display_price'],
          ]) ??
          (priceOptions.isNotEmpty ? priceOptions.first.displayPrice : null),
      billingPeriod:
          _firstString(json, const [
            ['billing_period'],
          ]) ??
          (priceOptions.isNotEmpty ? priceOptions.first.interval : null),
      provider:
          _firstString(json, const [
            ['provider'],
          ]) ??
          (priceOptions.isNotEmpty ? priceOptions.first.provider : null),
      highlighted:
          _firstBool(json, const [
            ['highlighted'],
          ]) ??
          false,
      badge: _firstString(json, const [
        ['badge'],
      ]),
      ctaLabel: _firstString(json, const [
        ['cta_label'],
      ]),
      features:
          (json['features'] is List ? json['features'] as List : const [])
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(),
      priceOptions: priceOptions,
    );
  }
}
