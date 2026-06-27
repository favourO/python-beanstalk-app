enum SubscriptionTier { free, premium }

enum SubscriptionStatus { none, active, trialing, pastDue, canceled }

enum PaywallReason {
  genericUpgrade,
  stressMonitoringPremium,
  aiChatPremium,
  ovulationShiftPremium,
}

class PlanPriceOption {
  const PlanPriceOption({
    required this.interval,
    this.displayPrice,
    this.provider,
  });

  final String interval;
  final String? displayPrice;
  final String? provider;
}

class Plan {
  const Plan({
    required this.id,
    required this.tier,
    required this.name,
    required this.priceLabel,
    this.description,
    this.currency,
    this.currencySymbol,
    this.displayPrice,
    this.billingPeriod,
    this.provider,
    this.highlighted = false,
    this.badge,
    this.ctaLabel,
    this.features = const [],
    this.priceOptions = const [],
  });

  final String id;
  final SubscriptionTier tier;
  final String name;
  final String priceLabel;
  final String? description;
  final String? currency;
  final String? currencySymbol;
  final String? displayPrice;
  final String? billingPeriod;
  final String? provider;
  final bool highlighted;
  final String? badge;
  final String? ctaLabel;
  final List<String> features;
  final List<PlanPriceOption> priceOptions;
}

class BillingPlanOffers {
  const BillingPlanOffers({
    required this.country,
    required this.supported,
    this.isFreeRegion = false,
    this.requiresPayment = true,
    required this.primaryProvider,
    required this.availableProviders,
    required this.currency,
    required this.currencySymbol,
    required this.headline,
    required this.subheadline,
    required this.plans,
  });

  final String country;
  final bool supported;
  final bool isFreeRegion;
  final bool requiresPayment;
  final String? primaryProvider;
  final List<String> availableProviders;
  final String? currency;
  final String? currencySymbol;
  final String headline;
  final String subheadline;
  final List<Plan> plans;
}

class CheckoutSession {
  const CheckoutSession({
    required this.provider,
    required this.checkoutUrl,
    this.sessionId,
    this.publicKey,
    this.customerEmail,
    this.providerProductId,
    this.providerPriceId,
    this.planId,
    this.interval,
    this.currency,
    this.amountMinor,
    this.displayPrice,
    this.txRef,
  });

  final String provider;
  final String checkoutUrl;
  final String? sessionId;
  final String? publicKey;
  final String? customerEmail;
  final String? providerProductId;
  final String? providerPriceId;
  final String? planId;
  final String? interval;
  final String? currency;
  final int? amountMinor;
  final String? displayPrice;
  final String? txRef;
}

class StripePaymentSheetSession {
  const StripePaymentSheetSession({
    required this.paymentIntentClientSecret,
    required this.customerId,
    required this.customerEphemeralKeySecret,
    required this.publishableKey,
    required this.subscriptionId,
    required this.providerProductId,
    required this.providerPriceId,
    required this.planId,
    required this.interval,
    required this.currency,
    required this.amountMinor,
    required this.displayPrice,
    this.customerEmail,
  });

  final String paymentIntentClientSecret;
  final String customerId;
  final String customerEphemeralKeySecret;
  final String publishableKey;
  final String? customerEmail;
  final String subscriptionId;
  final String providerProductId;
  final String providerPriceId;
  final String planId;
  final String interval;
  final String currency;
  final int amountMinor;
  final String displayPrice;
}

class SubscriptionSelectionResult {
  const SubscriptionSelectionResult({
    this.provider,
    required this.tier,
    this.status,
    this.selectionMade = false,
    this.planSaved = false,
    this.isActive = false,
    this.redirectToHome = false,
    this.showSubscriptionScreen = false,
    this.isFreeRegion = false,
    this.requiresPayment = true,
    this.providerConfigured = false,
    this.checkoutEndpoint,
    this.checkoutPublicKey,
    this.currency,
    this.amount,
    this.billingInterval,
    this.providerPriceId,
  });

  final String? provider;
  final SubscriptionTier tier;
  final String? status;
  final bool selectionMade;
  final bool planSaved;
  final bool isActive;
  final bool redirectToHome;
  final bool showSubscriptionScreen;
  final bool isFreeRegion;
  final bool requiresPayment;
  final bool providerConfigured;
  final String? checkoutEndpoint;
  final String? checkoutPublicKey;
  final String? currency;
  final double? amount;
  final String? billingInterval;
  final String? providerPriceId;
}

class Invoice {
  const Invoice({
    required this.id,
    required this.amountLabel,
    required this.status,
    this.itemType = 'payment',
    this.title,
    this.subtitle,
    this.actionUrl,
    this.providerInvoiceId,
    this.createdAt,
  });

  final String id;
  final String amountLabel;
  final String status;
  final String itemType;
  final String? title;
  final String? subtitle;
  final String? actionUrl;
  final String? providerInvoiceId;
  final DateTime? createdAt;
}

class SubscriptionState {
  const SubscriptionState({
    required this.tier,
    required this.status,
    this.nextBillingDate,
    this.processor,
    this.trialEndsAt,
    this.currency,
    this.amount,
    this.billingInterval,
    this.providerPriceId,
    this.cancelAtPeriodEnd = false,
    this.pendingBillingInterval,
    this.pendingProviderPriceId,
    this.pendingAmount,
    this.pendingCurrency,
    this.pendingChangeEffectiveAt,
    this.planSaved = false,
    this.isActive = false,
    this.redirectToHome = false,
    this.contributorEnrolled = false,
  });

  factory SubscriptionState.free() {
    return const SubscriptionState(
      tier: SubscriptionTier.free,
      status: SubscriptionStatus.none,
    );
  }

  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime? nextBillingDate;
  final String? processor;
  final DateTime? trialEndsAt;
  final String? currency;
  final double? amount;
  final String? billingInterval;
  final String? providerPriceId;
  final bool cancelAtPeriodEnd;
  final String? pendingBillingInterval;
  final String? pendingProviderPriceId;
  final double? pendingAmount;
  final String? pendingCurrency;
  final DateTime? pendingChangeEffectiveAt;
  final bool planSaved;
  final bool isActive;
  final bool redirectToHome;
  final bool contributorEnrolled;

  bool get isAppleSubscription => processor == 'apple_iap';

  bool get hasPaidAccess =>
      tier != SubscriptionTier.free &&
      (redirectToHome ||
          isActive ||
          status == SubscriptionStatus.active ||
          status == SubscriptionStatus.trialing);

  bool get hasManageableSubscription =>
      hasPaidAccess ||
      status == SubscriptionStatus.canceled ||
      status == SubscriptionStatus.pastDue;
}
