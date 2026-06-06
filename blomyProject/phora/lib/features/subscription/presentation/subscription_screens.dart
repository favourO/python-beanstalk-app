import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phora/core/api/api_error_mapper.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/core/location/device_location_country_service.dart';
import 'package:phora/core/payments/payment_country_catalog.dart';
import 'package:phora/core/ui/app_dimensions.dart';
import 'package:phora/core/ui/app_theme.dart';
import 'package:phora/core/ui/phora_loading.dart';
import 'package:phora/features/auth/presentation/auth_ui.dart';
import 'package:phora/features/subscription/data/subscription_repository.dart';
import 'package:phora/features/subscription/domain/subscription_models.dart';
import 'package:phora/features/wearables/domain/wearable_order_models.dart';
import 'package:phora/features/wearables/providers/wearable_order_providers.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;
import 'package:url_launcher/url_launcher.dart';

final billingCountryProvider = FutureProvider<String>((ref) async {
  final signals = await ref.watch(billingCountrySignalsProvider.future);
  return signals.country;
});

final billingCountrySignalsProvider = FutureProvider<PricingCountrySignals>((
  ref,
) async {
  final storedCountry =
      await ref.read(appPreferencesProvider).getBillingCountry();
  final locationService = DeviceLocationCountryService();
  final deviceLocaleCountryCode = locationService.deviceLocaleCountryCode();
  final localeCountry = supportedCountryFromLocale(
    WidgetsBinding.instance.platformDispatcher.locale,
  );
  final deviceLocationCountryCode =
      await locationService.deviceLocationCountryCode();
  final locationCountry = supportedCountryNameFromCode(
    deviceLocationCountryCode,
  );

  // Stored billing country (user's explicit signup choice) takes priority over
  // GPS detection, which reflects the testing device location rather than the
  // user's actual country.
  final country =
      (storedCountry != null && storedCountry.isNotEmpty)
          ? storedCountry
          : (locationCountry ?? localeCountry ?? 'United Kingdom');

  return PricingCountrySignals(
    country: country,
    deviceLocaleCountry: deviceLocaleCountryCode,
    deviceLocationCountry: deviceLocationCountryCode,
  );
});

final subscriptionPlansProvider = FutureProvider<BillingPlanOffers>((
  ref,
) async {
  final signals = await ref.watch(billingCountrySignalsProvider.future);
  return ref
      .watch(subscriptionRepositoryProvider)
      .getPlanOffersWithSignals(signals: signals);
});

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  static const _planAccent = Color(0xFFFF6B2F);
  static const _planAccentSoft = Color(0xFFFFF0E8);

  SubscriptionTier? _selectedTier;
  final Map<String, String> _selectedIntervals = <String, String>{};
  bool _isLaunchingCheckout = false;
  String? _launchingPlanId;
  bool _isCancelingSubscription = false;
  bool _isRestartingSubscription = false;
  bool _isSwitchingInterval = false;
  bool _addWearableDuringCheckout = false;
  Timer? _wearableOrdersRefreshTimer;

  @override
  void initState() {
    super.initState();
    _wearableOrdersRefreshTimer = Timer.periodic(const Duration(seconds: 25), (
      _,
    ) {
      if (!mounted) return;
      ref.invalidate(myWearableOrdersProvider);
    });
  }

  @override
  void dispose() {
    _wearableOrdersRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subscription =
        ref.watch(currentSubscriptionProvider).valueOrNull ??
        SubscriptionState.free();
    final isManageable = subscription.hasManageableSubscription;
    final planOffers =
        isManageable ? null : ref.watch(subscriptionPlansProvider);
    final billingCountry =
        isManageable
            ? null
            : (ref.watch(billingCountryProvider).valueOrNull ??
                'United Kingdom');
    final wearableAvailability =
        billingCountry == null
            ? null
            : ref.watch(wearableAvailabilityProvider(billingCountry));
    final wearableOrders = ref.watch(myWearableOrdersProvider).valueOrNull;
    final activeWearableOrder = _activeWearableOrder(wearableOrders);

    return Scaffold(
      body: DecoratedBox(
        decoration:
            subscription.hasManageableSubscription
                ? BoxDecoration(
                  color: isDark ? colors.bg : const Color(0xFFFFFBF7),
                )
                : authBackgroundDecoration(context),
        child: SafeArea(
          child:
              subscription.hasManageableSubscription
                  ? _PremiumManagementContent(
                    subscription: subscription,
                    activeWearableOrder: activeWearableOrder,
                    isCancelingSubscription: _isCancelingSubscription,
                    isRestartingSubscription: _isRestartingSubscription,
                    isSwitchingInterval: _isSwitchingInterval,
                    onBack: () => context.go('/you'),
                    onRestartSubscription:
                        _isRestartingSubscription
                            ? null
                            : () => _restartSubscription(context),
                    onSwitchToMonthly:
                        _isSwitchingInterval
                            ? null
                            : () => _switchSubscriptionInterval(
                              context,
                              targetInterval: 'month',
                            ),
                    onSwitchToAnnual:
                        _isSwitchingInterval
                            ? null
                            : () => _switchSubscriptionInterval(
                              context,
                              targetInterval: 'year',
                            ),
                    onCancelScheduledChange:
                        _isSwitchingInterval
                            ? null
                            : () => _cancelScheduledSubscriptionIntervalChange(
                              context,
                            ),
                    onBillingHistory: () => _showBillingHistorySheet(context),
                    onSubscriptionHelp:
                        () => _showSubscriptionHelpSheet(context),
                    onManageSubscription:
                        _isCancelingSubscription
                            ? null
                            : () => _showCancelSubscriptionDialog(context),
                  )
                  : planOffers!.when(
                    loading:
                        () => PhoraLoadingView(
                          message: context.l10n.subscriptionLoadingPlans,
                        ),
                    error:
                        (error, stackTrace) => Center(
                          child: Padding(
                            padding: EdgeInsets.all(dims.scaleWidth(24)),
                            child: Text(
                              error is ApiFailure
                                  ? error.message
                                  : error.toString(),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: colors.textSecondary),
                            ),
                          ),
                        ),
                    data: (offers) {
                      final plansByTier = {
                        for (final plan in offers.plans) plan.tier: plan,
                      };
                      final choices = _planChoicesFor(
                        context,
                        offers,
                        plansByTier,
                      );
                      final selectedChoice = _selectedChoiceFor(
                        choices,
                        subscription,
                      );
                      return _ChoosePlanContent(
                        offers: offers,
                        choices: choices,
                        selectedChoice: selectedChoice,
                        subscription: subscription,
                        isLaunchingCheckout: _isLaunchingCheckout,
                        launchingPlanId: _launchingPlanId,
                        isCancelingSubscription: _isCancelingSubscription,
                        onBack: () => _handleBack(context),
                        onChoiceSelected: (choice) {
                          if (_isLaunchingCheckout) return;
                          _selectChoice(choice);
                        },
                        onContinue:
                            offers.supported && selectedChoice != null
                                ? () => _startCheckoutForChoice(
                                  context,
                                  offers: offers,
                                  choice: selectedChoice,
                                  addWearable: _addWearableDuringCheckout,
                                )
                                : null,
                        addWearable: _addWearableDuringCheckout,
                        wearableAvailability: wearableAvailability?.valueOrNull,
                        isWearableLoading:
                            wearableAvailability?.isLoading ?? false,
                        onAddWearableChanged:
                            _isLaunchingCheckout
                                ? null
                                : (value) {
                                  setState(() {
                                    _addWearableDuringCheckout = value;
                                  });
                                },
                        onCancelSubscription:
                            (_isLaunchingCheckout || _isCancelingSubscription)
                                ? null
                                : () => _showCancelSubscriptionDialog(context),
                      );
                    },
                  ),
        ),
      ),
    );
  }

  Future<void> _startCheckout(
    BuildContext context, {
    required BillingPlanOffers offers,
    required Plan plan,
    required bool addWearable,
  }) async {
    final repository = ref.read(subscriptionRepositoryProvider);
    setState(() {
      _isLaunchingCheckout = true;
      _launchingPlanId = plan.id;
    });
    try {
      if (plan.tier == SubscriptionTier.free) {
        await repository.saveSubscriptionSelection(tier: SubscriptionTier.free);
        await ref.read(freePlanSelectionProvider.notifier).selectFreePlan();
        await ref.read(currentSubscriptionProvider.notifier).selectFreePlan();
        if (!context.mounted) return;
        context.go('/today');
        return;
      }

      final interval = _selectedIntervalForPlan(plan);
      final countrySignals = await ref.read(
        billingCountrySignalsProvider.future,
      );
      final selection = await repository.saveSubscriptionSelection(
        tier: plan.tier,
        interval: interval,
        country: offers.country,
        signals: countrySignals,
      );
      if (selection.provider?.trim().toLowerCase() == 'africa_free_launch' ||
          (selection.isActive && !selection.requiresPayment)) {
        await ref.read(currentSubscriptionProvider.notifier).refresh();
        if (!context.mounted) return;
        context.go('/today');
        return;
      }
      final provider =
          (selection.provider ?? '').trim().toLowerCase().isNotEmpty
              ? (selection.provider ?? '').trim().toLowerCase()
              : (offers.primaryProvider ?? '').trim().toLowerCase();
      final fallbackProvider = offers.availableProviders
          .map((value) => value.trim().toLowerCase())
          .firstWhere((value) => value == 'stripe', orElse: () => '');
      final checkoutProvider =
          provider.isNotEmpty ? provider : fallbackProvider;
      if (checkoutProvider.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.subscriptionPaymentsUnavailable)),
        );
        return;
      }

      if (checkoutProvider != 'stripe') {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.subscriptionPaymentsUnavailable)),
        );
        return;
      }

      if (plan.tier == SubscriptionTier.premium && addWearable) {
        if (!context.mounted) return;
        context.push(
          '/wearable/addon',
          extra: {
            'country': offers.country,
            'planId': plan.id,
            'interval': interval,
            'planName': plan.name,
            'planDisplayName':
                interval == 'year' ? 'Premium Annual' : 'Premium Monthly',
            'planDisplayPrice': _priceLabelFor(
              plan,
              _priceOptionFor(plan, interval),
            ),
            'planCadence': interval == 'year' ? '/ year' : '/ month',
          },
        );
        return;
      }

      final session = await repository.createStripePaymentSheetSession(
        country: offers.country,
        planId: plan.id,
        interval: interval,
        signals: countrySignals,
      );
      if (!context.mounted) return;
      await _presentStripePaymentSheet(
        context,
        repository: repository,
        session: session,
      );
    } on stripe.StripeException catch (error) {
      if (error.error.code == stripe.FailureCode.Canceled) {
        return;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.error.localizedMessage ??
                error.error.message ??
                context.l10n.subscriptionUnableToOpenCheckout,
          ),
        ),
      );
    } catch (error) {
      if (_isAuthTokenFailure(error)) {
        await ref.read(authSessionProvider.notifier).clearSession();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.sessionExpiredSignInAgain)),
        );
        context.go('/sign-in');
        return;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is ApiFailure ? error.message : error.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLaunchingCheckout = false;
          _launchingPlanId = null;
        });
      }
    }
  }

  Future<void> _presentStripePaymentSheet(
    BuildContext context, {
    required SubscriptionRepository repository,
    required StripePaymentSheetSession session,
  }) async {
    final paymentSheetStyle =
        Theme.of(context).brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light;
    stripe.Stripe.publishableKey = session.publishableKey;
    stripe.Stripe.urlScheme = 'vyla';
    stripe.Stripe.setReturnUrlSchemeOnAndroid = true;
    await stripe.Stripe.instance.applySettings();

    final customerEmail = session.customerEmail;
    await stripe.Stripe.instance.initPaymentSheet(
      paymentSheetParameters: stripe.SetupPaymentSheetParameters(
        paymentIntentClientSecret: session.paymentIntentClientSecret,
        customerId: session.customerId,
        customerEphemeralKeySecret: session.customerEphemeralKeySecret,
        merchantDisplayName: 'Vyla',
        primaryButtonLabel:
            session.displayPrice.isEmpty ? null : 'Pay ${session.displayPrice}',
        returnURL:
            'vyla://billing/success?provider_subscription_id='
            '${Uri.encodeQueryComponent(session.subscriptionId)}',
        style: paymentSheetStyle,
        billingDetails:
            customerEmail == null || customerEmail.isEmpty
                ? null
                : stripe.BillingDetails(email: customerEmail),
      ),
    );
    await stripe.Stripe.instance.presentPaymentSheet();
    if (!mounted) return;
    final nextState = await repository.syncStripePaymentSheetSubscription(
      subscriptionId: session.subscriptionId,
    );
    if (!mounted) return;
    ref
        .read(currentSubscriptionProvider.notifier)
        .setSubscriptionState(nextState);
    if (!context.mounted) return;
    context.go(
      '/billing/success?provider_subscription_id='
      '${Uri.encodeQueryComponent(session.subscriptionId)}',
    );
  }

  Future<void> _switchSubscriptionInterval(
    BuildContext context, {
    required String targetInterval,
  }) async {
    setState(() => _isSwitchingInterval = true);
    try {
      final country = await ref.read(billingCountryProvider.future);
      final nextState = await ref
          .read(subscriptionRepositoryProvider)
          .changeSubscriptionInterval(
            country: country,
            interval: targetInterval,
          );
      ref
          .read(currentSubscriptionProvider.notifier)
          .setSubscriptionState(nextState);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targetInterval == 'month'
                ? 'Your plan will switch to monthly at the end of this billing period.'
                : 'Your plan will switch to annual at the end of this billing period.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is ApiFailure ? error.message : error.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSwitchingInterval = false);
      }
    }
  }

  Future<void> _cancelScheduledSubscriptionIntervalChange(
    BuildContext context,
  ) async {
    setState(() => _isSwitchingInterval = true);
    try {
      final nextState =
          await ref
              .read(subscriptionRepositoryProvider)
              .cancelScheduledSubscriptionIntervalChange();
      ref
          .read(currentSubscriptionProvider.notifier)
          .setSubscriptionState(nextState);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.scheduledPlanChangeCanceled)),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is ApiFailure ? error.message : error.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSwitchingInterval = false);
      }
    }
  }

  Future<void> _restartSubscription(BuildContext context) async {
    setState(() => _isRestartingSubscription = true);
    try {
      final nextState =
          await ref.read(subscriptionRepositoryProvider).restartSubscription();
      ref
          .read(currentSubscriptionProvider.notifier)
          .setSubscriptionState(nextState);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.subscriptionRenewalRestarted)),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is ApiFailure ? error.message : error.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRestartingSubscription = false);
      }
    }
  }

  Future<void> _showBillingHistorySheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => _BillingHistorySheet(
            invoicesFuture:
                ref.read(subscriptionRepositoryProvider).getInvoices(),
          ),
    );
  }

  Future<void> _showSubscriptionHelpSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const _SubscriptionHelpSheet(),
    );
  }

  String _selectedIntervalForPlan(Plan plan) {
    final selected = _selectedIntervals[plan.id];
    final availableIntervals =
        plan.priceOptions
            .map((option) => option.interval)
            .where((value) => value.isNotEmpty)
            .toSet();
    if (selected != null && availableIntervals.contains(selected)) {
      return selected;
    }
    if ((plan.billingPeriod?.isNotEmpty ?? false)) {
      return plan.billingPeriod!;
    }
    if (availableIntervals.contains('month')) {
      return 'month';
    }
    return plan.priceOptions.isNotEmpty
        ? plan.priceOptions.first.interval
        : 'month';
  }

  List<_PlanChoice> _planChoicesFor(
    BuildContext context,
    BillingPlanOffers offers,
    Map<SubscriptionTier, Plan> plansByTier,
  ) {
    final choices = <_PlanChoice>[];
    final freePlan = plansByTier[SubscriptionTier.free];
    final premiumPlan = plansByTier[SubscriptionTier.premium];

    if (freePlan != null) {
      choices.add(
        _PlanChoice(
          plan: freePlan,
          interval: 'free',
          title: 'Free',
          description:
              freePlan.description?.trim().isNotEmpty == true
                  ? freePlan.description!.trim()
                  : 'Everything you need to get started.',
          price: _freePriceLabel(offers, freePlan),
          cadence: '/ month',
          icon: Icons.eco_outlined,
          iconBackground: const Color(0xFFE3F4EB),
          iconColor: const Color(0xFF17814F),
        ),
      );
    }

    if (premiumPlan != null) {
      final monthly =
          _priceOptionFor(premiumPlan, 'month') ??
          (premiumPlan.priceOptions.isNotEmpty
              ? premiumPlan.priceOptions.first
              : null);
      final yearly = _priceOptionFor(premiumPlan, 'year');

      if (monthly != null) {
        choices.add(
          _PlanChoice(
            plan: premiumPlan,
            interval: monthly.interval.isEmpty ? 'month' : monthly.interval,
            title: '1 Month',
            description: 'Flexible and cancel anytime.',
            price: _priceLabelFor(premiumPlan, monthly),
            cadence: '/ month',
            icon: Icons.workspace_premium_outlined,
            iconBackground: _planAccentSoft,
            iconColor: _planAccent,
          ),
        );
      }

      if (yearly != null) {
        choices.add(
          _PlanChoice(
            plan: premiumPlan,
            interval: yearly.interval,
            title: '12 Months',
            description: 'Best value for your long-term health.',
            price: _priceLabelFor(premiumPlan, yearly),
            cadence: '/ year',
            icon: Icons.emoji_events_outlined,
            iconBackground: _planAccentSoft,
            iconColor: _planAccent,
            badge: 'Best value',
            savingsLabel: _yearlySavingsLabel(context, premiumPlan),
          ),
        );
      }

      if (monthly == null && yearly == null) {
        choices.add(
          _PlanChoice(
            plan: premiumPlan,
            interval: premiumPlan.billingPeriod ?? 'month',
            title: premiumPlan.name,
            description:
                premiumPlan.description?.trim().isNotEmpty == true
                    ? premiumPlan.description!.trim()
                    : 'Flexible and cancel anytime.',
            price: _priceLabelFor(premiumPlan, null),
            cadence: _cadenceLabel(context, premiumPlan.billingPeriod ?? ''),
            icon: Icons.workspace_premium_outlined,
            iconBackground: _planAccentSoft,
            iconColor: _planAccent,
            badge:
                premiumPlan.badge?.trim().isNotEmpty == true
                    ? premiumPlan.badge!.trim()
                    : null,
          ),
        );
      }
    }

    return choices;
  }

  _PlanChoice? _selectedChoiceFor(
    List<_PlanChoice> choices,
    SubscriptionState subscription,
  ) {
    if (choices.isEmpty) return null;

    if (_selectedTier != null) {
      final selectedTier = _selectedTier!;
      if (selectedTier == SubscriptionTier.free) {
        return choices
                .where((choice) => choice.plan.tier == SubscriptionTier.free)
                .firstOrNull ??
            choices.first;
      }

      final matchingPlans = choices.where(
        (choice) => choice.plan.tier == selectedTier,
      );
      final selectedInterval =
          matchingPlans.isNotEmpty
              ? _selectedIntervals[matchingPlans.first.plan.id]
              : null;
      if (selectedInterval != null) {
        final intervalMatch =
            matchingPlans
                .where((choice) => choice.interval == selectedInterval)
                .firstOrNull;
        if (intervalMatch != null) return intervalMatch;
      }
      return matchingPlans.firstOrNull ?? choices.first;
    }

    if (subscription.hasPaidAccess) {
      final interval = subscription.billingInterval;
      final paidChoices = choices.where(
        (choice) => choice.plan.tier == subscription.tier,
      );
      if (interval != null && interval.isNotEmpty) {
        final intervalMatch =
            paidChoices
                .where((choice) => choice.interval == interval)
                .firstOrNull;
        if (intervalMatch != null) return intervalMatch;
      }
      return paidChoices.firstOrNull ?? choices.first;
    }

    return choices.where((choice) => choice.interval == 'year').firstOrNull ??
        choices.where((choice) => choice.interval == 'month').firstOrNull ??
        choices.first;
  }

  void _selectChoice(_PlanChoice choice) {
    setState(() {
      _selectedTier = choice.plan.tier;
      if (choice.plan.tier != SubscriptionTier.free) {
        _selectedIntervals[choice.plan.id] = choice.interval;
      }
    });
  }

  Future<void> _startCheckoutForChoice(
    BuildContext context, {
    required BillingPlanOffers offers,
    required _PlanChoice choice,
    required bool addWearable,
  }) async {
    if (_isLaunchingCheckout) return;
    setState(() {
      _selectedTier = choice.plan.tier;
      if (choice.plan.tier != SubscriptionTier.free) {
        _selectedIntervals[choice.plan.id] = choice.interval;
      }
    });
    await _startCheckout(
      context,
      offers: offers,
      plan: choice.plan,
      addWearable: choice.plan.tier == SubscriptionTier.premium && addWearable,
    );
  }

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }
    final matchedLocation = GoRouterState.of(context).matchedLocation;
    context.go(matchedLocation.startsWith('/you') ? '/you' : '/today');
  }

  bool _isAuthTokenFailure(Object error) {
    if (error is UnauthorizedFailure) {
      return true;
    }
    if (error is ApiFailure) {
      final message = error.message.toLowerCase();
      return message.contains('invalid token') ||
          message.contains('expired token') ||
          message.contains('session expired');
    }
    final message = error.toString().toLowerCase();
    return message.contains('invalid token') ||
        message.contains('expired token') ||
        message.contains('session expired');
  }

  Future<void> _showCancelSubscriptionDialog(BuildContext context) async {
    final subscription =
        ref.read(currentSubscriptionProvider).valueOrNull ??
        SubscriptionState.free();

    String? monthlyPriceLabel;
    String? annualPriceLabel;
    final plans = ref.read(subscriptionPlansProvider).valueOrNull;
    if (plans != null) {
      try {
        final premiumPlan = plans.plans.firstWhere(
          (p) => p.tier == SubscriptionTier.premium,
        );
        final monthlyOption = premiumPlan.priceOptions.firstWhere(
          (o) => o.interval.trim().toLowerCase() == 'month',
          orElse: () => premiumPlan.priceOptions.first,
        );
        final label = _priceLabelFor(premiumPlan, monthlyOption);
        if (label.isNotEmpty) monthlyPriceLabel = '$label / mo';
        final annualOption = premiumPlan.priceOptions.firstWhere((o) {
          final interval = o.interval.trim().toLowerCase();
          return interval == 'year' ||
              interval == 'annual' ||
              interval == 'yearly';
        }, orElse: () => premiumPlan.priceOptions.first);
        final annualLabel = _priceLabelFor(premiumPlan, annualOption);
        if (annualLabel.isNotEmpty) annualPriceLabel = '$annualLabel / yr';
      } catch (_) {}
    }

    final action = await showModalBottomSheet<_CancelSheetAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _CancelSubscriptionSheet(
            subscription: subscription,
            monthlyPriceLabel: monthlyPriceLabel,
            annualPriceLabel: annualPriceLabel,
          ),
    );

    if (!context.mounted || action == null) return;

    if (action == _CancelSheetAction.switchToMonthly) {
      await _switchSubscriptionInterval(context, targetInterval: 'month');
      return;
    }

    if (action == _CancelSheetAction.switchToAnnual) {
      await _switchSubscriptionInterval(context, targetInterval: 'year');
      return;
    }

    if (action == _CancelSheetAction.keep) return;

    setState(() => _isCancelingSubscription = true);
    try {
      final nextState =
          await ref.read(subscriptionRepositoryProvider).cancelSubscription();
      ref
          .read(currentSubscriptionProvider.notifier)
          .setSubscriptionState(nextState);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.subscriptionCanceled)),
      );
    } catch (error) {
      if (_isAuthTokenFailure(error)) {
        await ref.read(authSessionProvider.notifier).clearSession();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.sessionExpiredSignInAgain)),
        );
        context.go('/sign-in');
        return;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is ApiFailure ? error.message : error.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCancelingSubscription = false);
      }
    }
  }
}

class _PlanChoice {
  const _PlanChoice({
    required this.plan,
    required this.interval,
    required this.title,
    required this.description,
    required this.price,
    required this.cadence,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    this.badge,
    this.savingsLabel,
  });

  final Plan plan;
  final String interval;
  final String title;
  final String description;
  final String price;
  final String cadence;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String? badge;
  final String? savingsLabel;

  bool get isFree => plan.tier == SubscriptionTier.free;
}

class _ChoosePlanContent extends StatefulWidget {
  const _ChoosePlanContent({
    required this.offers,
    required this.choices,
    required this.selectedChoice,
    required this.subscription,
    required this.isLaunchingCheckout,
    required this.launchingPlanId,
    required this.isCancelingSubscription,
    required this.onBack,
    required this.onChoiceSelected,
    required this.onContinue,
    required this.addWearable,
    required this.wearableAvailability,
    required this.isWearableLoading,
    required this.onAddWearableChanged,
    required this.onCancelSubscription,
  });

  final BillingPlanOffers offers;
  final List<_PlanChoice> choices;
  final _PlanChoice? selectedChoice;
  final SubscriptionState subscription;
  final bool isLaunchingCheckout;
  final String? launchingPlanId;
  final bool isCancelingSubscription;
  final VoidCallback onBack;
  final ValueChanged<_PlanChoice> onChoiceSelected;
  final VoidCallback? onContinue;
  final bool addWearable;
  final WearableAvailability? wearableAvailability;
  final bool isWearableLoading;
  final ValueChanged<bool>? onAddWearableChanged;
  final VoidCallback? onCancelSubscription;

  @override
  State<_ChoosePlanContent> createState() => _ChoosePlanContentState();
}

class _ChoosePlanContentState extends State<_ChoosePlanContent>
    with SingleTickerProviderStateMixin {
  late int _tabIndex;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _tabIndex = _indexForChoice(widget.selectedChoice);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void didUpdateWidget(_ChoosePlanContent old) {
    super.didUpdateWidget(old);
    if (old.selectedChoice != widget.selectedChoice) {
      final idx = _indexForChoice(widget.selectedChoice);
      if (idx != _tabIndex) setState(() => _tabIndex = idx);
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  int _indexForChoice(_PlanChoice? choice) {
    if (choice == null || widget.choices.isEmpty) return 0;
    final i = widget.choices.indexOf(choice);
    return i < 0 ? 0 : i;
  }

  _PlanChoice? get _current =>
      widget.choices.isEmpty
          ? null
          : widget.choices[_tabIndex.clamp(0, widget.choices.length - 1)];

  void _selectTab(int index) {
    if (index == _tabIndex || index >= widget.choices.length) return;
    widget.onChoiceSelected(widget.choices[index]);
    _fadeCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() => _tabIndex = index);
      _fadeCtrl.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 720;
    if (isDesktop) return _buildDesktop(context);
    return _buildScrollable(context, padH: 24);
  }

  Widget _buildDesktop(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 44,
          child: _PlanImagePanel(
            tabIndex: _tabIndex,
            choice: _current,
            fadeAnim: _fadeAnim,
          ),
        ),
        Expanded(flex: 56, child: _buildScrollable(context, padH: 36)),
      ],
    );
  }

  Widget _buildScrollable(BuildContext context, {required double padH}) {
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = _current;
    final isLoading =
        widget.isLaunchingCheckout &&
        current != null &&
        widget.launchingPlanId == current.plan.id;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(padH)),
      child: Column(
        children: [
          SizedBox(height: dims.scaleSpace(8)),
          _ChoosePlanTopBar(onBack: widget.onBack),
          SizedBox(height: dims.scaleSpace(8)),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(bottom: dims.scaleSpace(20)),
              children: [
                if (!widget.offers.supported)
                  _UnsupportedPricingCard(
                    message: context.l10n.subscriptionPricingUnavailable,
                  )
                else ...[
                  _PlanTabSwitcher(
                    choices: widget.choices,
                    tabIndex: _tabIndex,
                    onTabSelected: _selectTab,
                  ),
                  SizedBox(height: dims.scaleSpace(16)),
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: _TabPlanDetailCard(
                      choice: current,
                      isLoading: isLoading,
                      onContinue: widget.onContinue,
                    ),
                  ),
                  SizedBox(height: dims.scaleSpace(14)),
                  _WearableIncludedCard(
                    selected: widget.addWearable,
                    availability: widget.wearableAvailability,
                    isLoading: widget.isWearableLoading,
                    enabled:
                        current?.isFree != true &&
                        (widget.wearableAvailability?.available ?? false),
                    onChanged: widget.onAddWearableChanged,
                  ),
                  if (current?.isFree == true) ...[
                    SizedBox(height: dims.scaleSpace(12)),
                    _PremiumNudgeCard(
                      onTap: () => _selectTab(_premiumIndex('month')),
                    ),
                  ],
                  if (current?.isFree != true &&
                      current?.interval == 'month') ...[
                    SizedBox(height: dims.scaleSpace(10)),
                    const _PlanDividerLabel(label: 'OR'),
                  ],
                  SizedBox(height: dims.scaleSpace(12)),
                  const _HealthSyncCard(),
                  if (current?.isFree != true &&
                      current?.interval == 'month') ...[
                    SizedBox(height: dims.scaleSpace(12)),
                    _AnnualNudgeCard(
                      onTap: () => _selectTab(_premiumIndex('year')),
                    ),
                  ],
                  SizedBox(height: dims.scaleSpace(12)),
                  const _SubscriptionSafetyBadges(),
                  SizedBox(height: dims.scaleSpace(12)),
                  const _SubscriptionFooterLinks(),
                  if (widget.subscription.hasPaidAccess) ...[
                    SizedBox(height: dims.scaleSpace(14)),
                    _SubscriptionManagementCard(
                      subscription: widget.subscription,
                      onCancel:
                          widget.isCancelingSubscription
                              ? null
                              : widget.onCancelSubscription,
                    ),
                  ],
                ],
                if (isDark) SizedBox(height: dims.scaleSpace(2)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _premiumIndex(String interval) {
    final index = widget.choices.indexWhere((choice) {
      return !choice.isFree && choice.interval == interval;
    });
    return index < 0 ? _tabIndex : index;
  }
}

class _PremiumManagementContent extends StatelessWidget {
  const _PremiumManagementContent({
    required this.subscription,
    required this.activeWearableOrder,
    required this.isCancelingSubscription,
    required this.isRestartingSubscription,
    required this.isSwitchingInterval,
    required this.onBack,
    required this.onRestartSubscription,
    required this.onSwitchToMonthly,
    required this.onSwitchToAnnual,
    required this.onCancelScheduledChange,
    required this.onBillingHistory,
    required this.onSubscriptionHelp,
    required this.onManageSubscription,
  });

  final SubscriptionState subscription;
  final WearableOrder? activeWearableOrder;
  final bool isCancelingSubscription;
  final bool isRestartingSubscription;
  final bool isSwitchingInterval;
  final VoidCallback onBack;
  final VoidCallback? onRestartSubscription;
  final VoidCallback? onSwitchToMonthly;
  final VoidCallback? onSwitchToAnnual;
  final VoidCallback? onCancelScheduledChange;
  final VoidCallback onBillingHistory;
  final VoidCallback onSubscriptionHelp;
  final VoidCallback? onManageSubscription;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            dims.scaleWidth(20),
            dims.scaleSpace(12),
            dims.scaleWidth(20),
            0,
          ),
          child: _PremiumManagementTopBar(onBack: onBack),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              dims.scaleWidth(20),
              dims.scaleSpace(22),
              dims.scaleWidth(20),
              dims.scaleSpace(28),
            ),
            children: [
              _CurrentPremiumPlanCard(subscription: subscription),
              SizedBox(height: dims.scaleSpace(14)),
              if (subscription.cancelAtPeriodEnd)
                _CanceledSubscriptionCard(
                  subscription: subscription,
                  isLoading: isRestartingSubscription,
                  onRestartSubscription: onRestartSubscription,
                )
              else
                _SavingsCalloutCard(
                  subscription: subscription,
                  isLoading: isSwitchingInterval,
                  onSwitchToMonthly: onSwitchToMonthly,
                  onSwitchToAnnual: onSwitchToAnnual,
                  onCancelScheduledChange: onCancelScheduledChange,
                ),
              SizedBox(height: dims.scaleSpace(14)),
              const _IncludedCard(),
              SizedBox(height: dims.scaleSpace(14)),
              _WearableInsightCard(order: activeWearableOrder),
              SizedBox(height: dims.scaleSpace(14)),
              _NeedHelpCard(
                isLoading: isCancelingSubscription,
                onBillingHistory: onBillingHistory,
                onSubscriptionHelp: onSubscriptionHelp,
                onCancelSubscription:
                    subscription.cancelAtPeriodEnd
                        ? null
                        : onManageSubscription,
              ),
              SizedBox(height: dims.scaleSpace(20)),
              const _ManagementSafetyBadges(),
              if (isDark) SizedBox(height: dims.scaleSpace(2)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumManagementTopBar extends StatelessWidget {
  const _PremiumManagementTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? colors.textPrimary : const Color(0xFF2D170F);
    final secondary = isDark ? colors.textSecondary : const Color(0xFF7F6357);

    return SizedBox(
      height: dims.scaleSpace(88),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: _ManagementBackButton(onTap: onBack),
          ),
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: dims.scaleSpace(4)),
                Text(
                  context.l10n.manageSubscriptionLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: dims.scaleText(24),
                    height: 1,
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.w500,
                    color: primary,
                  ),
                ),
                SizedBox(height: dims.scaleSpace(7)),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: dims.scaleWidth(44),
                  ),
                  child: Text(
                    'View your plan details and manage\nyour subscription.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: dims.scaleText(11.5),
                      height: 1.4,
                      color: secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementBackButton extends StatelessWidget {
  const _ManagementBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? colors.bgElevated : const Color(0xFFFFF5EF),
      borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
        onTap: onTap,
        child: Container(
          width: dims.scaleWidth(44),
          height: dims.scaleWidth(44),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
            border: Border.all(
              color: isDark ? colors.border : const Color(0xFFF2E6DE),
            ),
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            size: dims.scaleText(20),
            color: isDark ? colors.textPrimary : const Color(0xFF3B2A23),
          ),
        ),
      ),
    );
  }
}

class _CurrentPremiumPlanCard extends StatelessWidget {
  const _CurrentPremiumPlanCard({required this.subscription});

  final SubscriptionState subscription;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingChange = _hasPendingPlanChange(subscription);
    final planLabel = _managementPlanLabel(subscription);
    final price = _managementPrice(subscription);
    final cadence = _managementCadence(subscription.billingInterval);
    final nextDate = _formatManagementDate(subscription.nextBillingDate);
    final pendingDate = _formatManagementDate(
      subscription.pendingChangeEffectiveAt,
    );
    return _PremiumCard(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(16),
        dims.scaleSpace(14),
        dims.scaleWidth(16),
        dims.scaleSpace(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Current Plan',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: dims.scaleText(10),
              fontWeight: FontWeight.w500,
              color: isDark ? colors.textTertiary : const Color(0xFF8F766A),
            ),
          ),
          SizedBox(height: dims.scaleSpace(10)),
          Row(
            children: [
              Container(
                width: dims.scaleWidth(50),
                height: dims.scaleWidth(50),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF9B5F), Color(0xFFFF6B2F)],
                  ),
                ),
                child: Icon(
                  Icons.workspace_premium_outlined,
                  color: Colors.white,
                  size: dims.scaleText(26),
                ),
              ),
              SizedBox(width: dims.scaleWidth(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planLabel,
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: dims.scaleText(14),
                        height: 1.08,
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.w600,
                        color:
                            isDark
                                ? colors.textPrimary
                                : const Color(0xFF2F1C14),
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(5)),
                    Text.rich(
                      TextSpan(
                        text: price,
                        style: const TextStyle(color: Color(0xFFFF6B2F)),
                        children: [
                          TextSpan(
                            text: '  $cadence',
                            style: TextStyle(
                              color:
                                  isDark
                                      ? colors.textPrimary
                                      : const Color(0xFF2F1C14),
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: dims.scaleText(13),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(7)),
                    Align(
                      alignment: Alignment.centerLeft,
                      child:
                          subscription.cancelAtPeriodEnd
                              ? const _CancelingPill()
                              : const _PremiumPackageBadge(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(12)),
          const _PremiumInsetDivider(fullWidth: true),
          _BillingDetailTile(
            icon: Icons.calendar_today_outlined,
            title: 'Renews',
            trailing: nextDate,
          ),
          if (pendingChange) ...[
            const _PremiumInsetDivider(fullWidth: true),
            _BillingDetailTile(
              icon: Icons.schedule_rounded,
              title: 'Plan change',
              trailing:
                  '${_managementPlanLabelForInterval(subscription.pendingBillingInterval)} starts $pendingDate',
            ),
          ],
          const _PremiumInsetDivider(fullWidth: true),
          const _BillingDetailTile(
            icon: Icons.credit_card_rounded,
            title: 'Payment method',
            trailing: 'Visa •••• 4242',
            hasChevron: true,
          ),
        ],
      ),
    );
  }
}

class _SavingsCalloutCard extends StatelessWidget {
  const _SavingsCalloutCard({
    required this.subscription,
    required this.isLoading,
    required this.onSwitchToMonthly,
    required this.onSwitchToAnnual,
    required this.onCancelScheduledChange,
  });

  final SubscriptionState subscription;
  final bool isLoading;
  final VoidCallback? onSwitchToMonthly;
  final VoidCallback? onSwitchToAnnual;
  final VoidCallback? onCancelScheduledChange;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMonthly = _isMonthlyInterval(subscription.billingInterval);
    final pendingChange = _hasPendingPlanChange(subscription);
    final pendingLabel = _managementPlanLabelForInterval(
      subscription.pendingBillingInterval,
    );
    final pendingDate = _formatManagementDate(
      subscription.pendingChangeEffectiveAt,
    );
    final title =
        pendingChange
            ? '${_managementPlanLabel(subscription)} active'
            : isMonthly
            ? 'Save with Annual'
            : 'Save with Annual';
    final subtitle =
        pendingChange
            ? 'Your current subscription remains active. $pendingLabel starts on $pendingDate.'
            : isMonthly
            ? 'Switch to annual billing and save 27% compared to monthly.'
            : "You're saving 27% compared to monthly billing.";
    final buttonLabel =
        isLoading
            ? 'Switching...'
            : pendingChange
            ? 'Cancel Scheduled change'
            : isMonthly
            ? 'Switch to Annual'
            : 'Switch to Monthly';
    final onPressed =
        isLoading
            ? null
            : pendingChange
            ? onCancelScheduledChange
            : isMonthly
            ? onSwitchToAnnual
            : onSwitchToMonthly;

    return _PremiumCard(
      backgroundColor:
          isDark ? null : const Color(0xFFFFF3ED).withValues(alpha: 0.92),
      padding: EdgeInsets.all(dims.scaleWidth(16)),
      child: Row(
        children: [
          const _ManagementIconBadge(icon: Icons.local_offer_outlined),
          SizedBox(width: dims.scaleWidth(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(12),
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF2F1C14),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(3)),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(10),
                    height: 1.35,
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF8C5A42),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: dims.scaleWidth(10)),
          OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFF8A4C)),
              foregroundColor: const Color(0xFFFF6B2F),
              padding: EdgeInsets.symmetric(
                horizontal: dims.scaleWidth(16),
                vertical: dims.scaleSpace(11),
              ),
              minimumSize: Size(dims.scaleWidth(134), dims.scaleHeight(42)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
              ),
            ),
            child: Text(
              buttonLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: dims.scaleText(10.5),
                fontWeight: FontWeight.w700,
                color:
                    onPressed == null
                        ? const Color(0xFFB89A8F)
                        : const Color(0xFFFF6B2F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CanceledSubscriptionCard extends StatelessWidget {
  const _CanceledSubscriptionCard({
    required this.subscription,
    required this.isLoading,
    required this.onRestartSubscription,
  });

  final SubscriptionState subscription;
  final bool isLoading;
  final VoidCallback? onRestartSubscription;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expiry = subscription.nextBillingDate;
    final expiryLabel =
        expiry == null
            ? 'Premium access remains active until your current period ends.'
            : 'Expires in ${_expiryDistanceLabel(expiry)} on ${_formatManagementDate(expiry)}.';

    return _PremiumCard(
      backgroundColor:
          isDark ? null : const Color(0xFFFFF3ED).withValues(alpha: 0.92),
      padding: EdgeInsets.all(dims.scaleWidth(16)),
      child: Row(
        children: [
          const _ManagementIconBadge(icon: Icons.refresh_rounded),
          SizedBox(width: dims.scaleWidth(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Restart your subscription',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(12),
                    fontWeight: FontWeight.w700,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF2F1C14),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(3)),
                Text(
                  expiryLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(10),
                    height: 1.35,
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF8C5A42),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: dims.scaleWidth(10)),
          OutlinedButton(
            onPressed: isLoading ? null : onRestartSubscription,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFF8A4C)),
              foregroundColor: const Color(0xFFFF6B2F),
              padding: EdgeInsets.symmetric(
                horizontal: dims.scaleWidth(16),
                vertical: dims.scaleSpace(11),
              ),
              minimumSize: Size(dims.scaleWidth(104), dims.scaleHeight(42)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
              ),
            ),
            child: Text(
              isLoading ? 'Restarting...' : 'Restart',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: dims.scaleText(10.5),
                fontWeight: FontWeight.w700,
                color:
                    isLoading
                        ? const Color(0xFFB89A8F)
                        : const Color(0xFFFF6B2F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncludedCard extends StatelessWidget {
  const _IncludedCard();

  static const _items = [
    'AI-powered cycle insights',
    'Advanced reports',
    'Vyla Wear integration',
    'Priority support',
    'Personalized predictions',
    'Vyla wearable compatible',
  ];

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _PremiumCard(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(16),
        dims.scaleSpace(14),
        dims.scaleWidth(16),
        dims.scaleSpace(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's included",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: dims.scaleText(12),
              fontWeight: FontWeight.w700,
              color: isDark ? colors.textPrimary : const Color(0xFF2F1C14),
            ),
          ),
          SizedBox(height: dims.scaleSpace(14)),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth =
                  (constraints.maxWidth - dims.scaleWidth(12)) / 2;
              return Wrap(
                spacing: dims.scaleWidth(12),
                runSpacing: dims.scaleSpace(12),
                children: [
                  for (final item in _items)
                    SizedBox(
                      width: itemWidth,
                      child: _IncludedItem(label: item),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _IncludedItem extends StatelessWidget {
  const _IncludedItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: dims.scaleText(16),
          color: _SubscriptionScreenState._planAccent,
        ),
        SizedBox(width: dims.scaleWidth(8)),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: dims.scaleText(10),
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: isDark ? colors.textSecondary : const Color(0xFF2F1C14),
            ),
          ),
        ),
      ],
    );
  }
}

class _WearableInsightCard extends StatelessWidget {
  const _WearableInsightCard({required this.order});

  final WearableOrder? order;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentOrder = order;
    final hasOrder = currentOrder != null;
    final isDelivered = currentOrder?.isDelivered == true;
    final title = currentOrder?.wearableName ?? 'Get a wearable';
    final String subtitle;
    final VoidCallback? onTap;
    if (currentOrder == null) {
      subtitle =
          'Track temperature, HRV, sleep and recovery for even deeper insights.';
      onTap = () => context.push('/wearable/buy');
    } else if (isDelivered) {
      final completedAt = currentOrder.deliveredAt ?? currentOrder.updatedAt;
      subtitle =
          'Order completed at ${DateFormat('d MMM yyyy').format(completedAt.toLocal())}.';
      onTap = null;
    } else {
      subtitle =
          '${currentOrder.orderNumber.isEmpty ? 'Your order' : currentOrder.orderNumber} is ${_wearableOrderStatusLabel(currentOrder.fulfillmentStatus).toLowerCase()}.';
      onTap =
          () => context.push(
            '/wearable/orders/${currentOrder.id}',
            extra: currentOrder,
          );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        onTap: onTap,
        child: _PremiumCard(
          padding: EdgeInsets.fromLTRB(
            dims.scaleWidth(14),
            dims.scaleSpace(8),
            dims.scaleWidth(14),
            dims.scaleSpace(8),
          ),
          child: Row(
            children: [
              Container(
                width: dims.scaleWidth(58),
                height: dims.scaleWidth(58),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? colors.bgSurface : const Color(0xFFFFEFE7),
                ),
                child: Icon(
                  isDelivered
                      ? Icons.check_circle_outline_rounded
                      : hasOrder
                      ? Icons.local_shipping_outlined
                      : Icons.watch_outlined,
                  size: dims.scaleText(30),
                  color:
                      isDelivered
                          ? const Color(0xFF2E7D32)
                          : _SubscriptionScreenState._planAccent,
                ),
              ),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: dims.scaleWidth(8),
                      runSpacing: dims.scaleSpace(4),
                      children: [
                        Text(
                          title,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontSize: dims.scaleText(12),
                            fontFamily: 'Georgia',
                            fontWeight: FontWeight.w600,
                            color:
                                isDark
                                    ? colors.textPrimary
                                    : const Color(0xFF2D170F),
                          ),
                        ),
                        if (currentOrder == null)
                          _OptionalPill()
                        else
                          _WearableOrderPill(
                            label:
                                isDelivered
                                    ? 'Completed'
                                    : _wearableOrderStatusLabel(
                                      currentOrder.fulfillmentStatus,
                                    ),
                            isCompleted: isDelivered,
                          ),
                      ],
                    ),
                    SizedBox(height: dims.scaleSpace(6)),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: dims.scaleText(10),
                        height: 1.35,
                        color:
                            isDark
                                ? colors.textSecondary
                                : const Color(0xFF86736A),
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(8)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentOrder == null
                              ? 'Order wearable'
                              : isDelivered
                              ? 'Order completed'
                              : 'View order',
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(
                            fontSize: dims.scaleText(10.5),
                            fontWeight: FontWeight.w700,
                            color:
                                isDelivered
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFFF6B2F),
                          ),
                        ),
                        if (!isDelivered) ...[
                          SizedBox(width: dims.scaleWidth(4)),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: dims.scaleText(17),
                            color: _SubscriptionScreenState._planAccent,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: dims.scaleWidth(8)),
              _ManagementIconBadge(
                icon:
                    isDelivered
                        ? Icons.check_rounded
                        : hasOrder
                        ? Icons.receipt_long_outlined
                        : Icons.card_giftcard_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WearableOrderPill extends StatelessWidget {
  const _WearableOrderPill({required this.label, required this.isCompleted});

  final String label;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(7),
        vertical: dims.scaleSpace(3),
      ),
      decoration: BoxDecoration(
        color:
            isCompleted
                ? (isDark
                    ? const Color(0xFF2E8C3D).withValues(alpha: 0.18)
                    : const Color(0xFFEAF7EA))
                : (isDark
                    ? const Color(0xFFFF6B2F).withValues(alpha: 0.16)
                    : const Color(0xFFFFEFE8)),
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
        border: Border.all(
          color:
              isCompleted
                  ? const Color(0xFF2E8C3D).withValues(alpha: 0.36)
                  : const Color(0xFFFF6B2F).withValues(alpha: 0.32),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: dims.scaleText(7.5),
          fontWeight: FontWeight.w800,
          color:
              isCompleted
                  ? (isDark ? colors.accentSuccess : const Color(0xFF2E7D32))
                  : const Color(0xFFFF6B2F),
        ),
      ),
    );
  }
}

class _OptionalPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(7),
        vertical: dims.scaleSpace(3),
      ),
      decoration: BoxDecoration(
        color:
            isDark
                ? const Color(0xFFFF6B2F).withValues(alpha: 0.16)
                : const Color(0xFFFFEFE8),
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
        border: Border.all(
          color: const Color(0xFFFF6B2F).withValues(alpha: 0.28),
          width: 0.8,
        ),
      ),
      child: Text(
        'Optional',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: dims.scaleText(7.5),
          fontWeight: FontWeight.w800,
          color: const Color(0xFFFF6B2F),
        ),
      ),
    );
  }
}

class _PremiumPackageBadge extends StatelessWidget {
  const _PremiumPackageBadge();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(9),
        vertical: dims.scaleSpace(4),
      ),
      decoration: BoxDecoration(
        color:
            isDark
                ? const Color(0xFFFF6B2F).withValues(alpha: 0.16)
                : const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
        border: Border.all(
          color:
              isDark
                  ? const Color(0xFFFF6B2F).withValues(alpha: 0.32)
                  : const Color(0xFFFFD0B8),
          width: 0.8,
        ),
      ),
      child: Text(
        'Premium Package',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: dims.scaleText(8.5),
          fontWeight: FontWeight.w700,
          color: const Color(0xFFFF6B2F),
        ),
      ),
    );
  }
}

class _CancelingPill extends StatelessWidget {
  const _CancelingPill();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(11),
        vertical: dims.scaleSpace(5),
      ),
      decoration: BoxDecoration(
        color:
            isDark
                ? const Color(0xFFFF6B2F).withValues(alpha: 0.16)
                : const Color(0xFFFFEFE8),
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
        border: Border.all(
          color: const Color(0xFFFF6B2F).withValues(alpha: 0.32),
          width: 0.8,
        ),
      ),
      child: Text(
        'Canceled',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: dims.scaleText(9.5),
          fontWeight: FontWeight.w800,
          color: const Color(0xFFFF6B2F),
        ),
      ),
    );
  }
}

class _BillingDetailTile extends StatelessWidget {
  const _BillingDetailTile({
    required this.icon,
    required this.title,
    required this.trailing,
    this.hasChevron = false,
  });

  final IconData icon;
  final String title;
  final String trailing;
  final bool hasChevron;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(16),
        vertical: dims.scaleSpace(10),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: dims.scaleText(15),
            color: isDark ? colors.textSecondary : const Color(0xFF9B614B),
          ),
          SizedBox(width: dims.scaleWidth(12)),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: dims.scaleText(11.5),
                fontWeight: FontWeight.w600,
                color: isDark ? colors.textPrimary : const Color(0xFF251915),
              ),
            ),
          ),
          SizedBox(width: dims.scaleWidth(8)),
          Flexible(
            child: Text(
              trailing,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: dims.scaleText(10),
                fontWeight: FontWeight.w500,
                color: isDark ? colors.textSecondary : const Color(0xFF8C5A42),
              ),
            ),
          ),
          if (hasChevron) ...[
            SizedBox(width: dims.scaleWidth(4)),
            Icon(
              Icons.chevron_right_rounded,
              size: dims.scaleText(18),
              color: isDark ? colors.textTertiary : const Color(0xFF9B614B),
            ),
          ],
        ],
      ),
    );
  }
}

class _NeedHelpCard extends StatelessWidget {
  const _NeedHelpCard({
    required this.isLoading,
    required this.onBillingHistory,
    required this.onSubscriptionHelp,
    required this.onCancelSubscription,
  });

  final bool isLoading;
  final VoidCallback onBillingHistory;
  final VoidCallback onSubscriptionHelp;
  final VoidCallback? onCancelSubscription;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _PremiumCard(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(16),
        dims.scaleSpace(14),
        dims.scaleWidth(16),
        dims.scaleSpace(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Need help?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: dims.scaleText(12),
              fontWeight: FontWeight.w700,
              color: isDark ? colors.textPrimary : const Color(0xFF2F1C14),
            ),
          ),
          SizedBox(height: dims.scaleSpace(8)),
          _ManagementActionRow(
            icon: Icons.history_rounded,
            title: 'Billing history',
            subtitle: 'View your past payments and invoices',
            onTap: onBillingHistory,
          ),
          const _PremiumInsetDivider(),
          _ManagementActionRow(
            icon: Icons.help_outline_rounded,
            title: 'Subscription help',
            subtitle: 'Learn more about managing your subscription',
            onTap: onSubscriptionHelp,
          ),
          const _PremiumInsetDivider(),
          _ManagementActionRow(
            icon: Icons.logout_rounded,
            title: isLoading ? 'Canceling subscription' : 'Cancel subscription',
            subtitle:
                'Cancel your subscription at the end of your billing period',
            destructive: true,
            onTap: isLoading ? null : onCancelSubscription,
          ),
        ],
      ),
    );
  }
}

class _ManagementActionRow extends StatelessWidget {
  const _ManagementActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.destructive = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor =
        destructive ? const Color(0xFFF06F63) : const Color(0xFFB56A4C);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(10)),
          child: Row(
            children: [
              Icon(icon, size: dims.scaleText(20), color: iconColor),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: dims.scaleText(12),
                        fontWeight: FontWeight.w700,
                        color:
                            destructive
                                ? const Color(0xFFF06F63)
                                : isDark
                                ? colors.textPrimary
                                : const Color(0xFF2F1C14),
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(2)),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: dims.scaleText(10),
                        height: 1.35,
                        color:
                            isDark
                                ? colors.textSecondary
                                : const Color(0xFF86736A),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: dims.scaleText(20),
                color: isDark ? colors.textTertiary : const Color(0xFF9B8A81),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillingHistorySheet extends StatelessWidget {
  const _BillingHistorySheet({required this.invoicesFuture});

  final Future<List<Invoice>> invoicesFuture;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _ManagementBottomSheet(
      title: 'Billing history',
      child: FutureBuilder<List<Invoice>>(
        future: invoicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(28)),
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(18)),
              child: Text(
                snapshot.error.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: dims.scaleText(12),
                  color: colors.textSecondary,
                ),
              ),
            );
          }
          final invoices = snapshot.data ?? const <Invoice>[];
          if (invoices.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(18)),
              child: Text(
                'No invoices are available yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: dims.scaleText(12),
                  color:
                      isDark ? colors.textSecondary : const Color(0xFF86736A),
                ),
              ),
            );
          }
          return Column(
            children: [
              for (var index = 0; index < invoices.length; index += 1) ...[
                _InvoiceHistoryRow(invoice: invoices[index]),
                if (index != invoices.length - 1) const _PremiumInsetDivider(),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InvoiceHistoryRow extends StatelessWidget {
  const _InvoiceHistoryRow({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateLabel =
        invoice.createdAt == null
            ? 'Invoice'
            : _formatManagementDate(invoice.createdAt);
    final isEvent = invoice.itemType == 'event';
    final title =
        invoice.title?.trim().isNotEmpty == true
            ? invoice.title!.trim()
            : dateLabel;
    final subtitle =
        invoice.subtitle?.trim().isNotEmpty == true
            ? invoice.subtitle!.trim()
            : invoice.status.isEmpty
            ? 'Invoice'
            : invoice.status;
    final actionUrl =
        invoice.actionUrl?.trim().isNotEmpty == true
            ? invoice.actionUrl!.trim()
            : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(12)),
        onTap:
            actionUrl == null
                ? null
                : () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.push(actionUrl);
                },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(10)),
          child: Row(
            children: [
              Icon(
                isEvent
                    ? Icons.event_note_outlined
                    : Icons.receipt_long_outlined,
                size: dims.scaleText(20),
                color:
                    isEvent ? const Color(0xFF2E8C6B) : const Color(0xFFB56A4C),
              ),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: dims.scaleText(12),
                        fontWeight: FontWeight.w700,
                        color:
                            isDark
                                ? colors.textPrimary
                                : const Color(0xFF2F1C14),
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(2)),
                    Text(
                      isEvent ? '$dateLabel · $subtitle' : subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: dims.scaleText(10),
                        color:
                            isDark
                                ? colors.textSecondary
                                : const Color(0xFF86736A),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                invoice.amountLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: dims.scaleText(12),
                  fontWeight: FontWeight.w700,
                  color:
                      isEvent
                          ? const Color(0xFF2E8C6B)
                          : isDark
                          ? colors.textPrimary
                          : const Color(0xFF2F1C14),
                ),
              ),
              if (actionUrl != null) ...[
                SizedBox(width: dims.scaleWidth(8)),
                Text(
                  'View order',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: dims.scaleText(9),
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFF6B35),
                  ),
                ),
                SizedBox(width: dims.scaleWidth(3)),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: dims.scaleText(10),
                  color: const Color(0xFFFF6B35),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionHelpSheet extends StatelessWidget {
  const _SubscriptionHelpSheet();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _ManagementBottomSheet(
      title: 'Subscription help',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly switches are scheduled through Stripe and take effect at the end of your current paid period. Canceling stops renewal, but Premium access stays active until that period ends.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: dims.scaleText(12),
              height: 1.45,
              color: isDark ? colors.textSecondary : const Color(0xFF86736A),
            ),
          ),
          SizedBox(height: dims.scaleSpace(16)),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed:
                  () => launchUrl(Uri.parse('mailto:support@vyla.health')),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFFF8A4C)),
                foregroundColor: const Color(0xFFFF6B2F),
                padding: EdgeInsets.symmetric(vertical: dims.scaleSpace(13)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
                ),
              ),
              child: Text(
                'Contact support',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: dims.scaleText(11),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFF6B2F),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementBottomSheet extends StatelessWidget {
  const _ManagementBottomSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          dims.scaleWidth(20),
          dims.scaleSpace(18),
          dims.scaleWidth(20),
          dims.scaleSpace(28),
        ),
        decoration: BoxDecoration(
          color: isDark ? colors.bgElevated : const Color(0xFFFFFBF7),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(dims.scaleRadius(28)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: dims.scaleText(18),
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.w500,
                      color:
                          isDark ? colors.textPrimary : const Color(0xFF2D170F),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SizedBox(height: dims.scaleSpace(12)),
            Flexible(child: SingleChildScrollView(child: child)),
          ],
        ),
      ),
    );
  }
}

enum _CancelSheetAction { switchToMonthly, switchToAnnual, keep, proceedCancel }

class _CancelSubscriptionSheet extends StatelessWidget {
  const _CancelSubscriptionSheet({
    required this.subscription,
    this.monthlyPriceLabel,
    this.annualPriceLabel,
  });

  final SubscriptionState subscription;
  final String? monthlyPriceLabel;
  final String? annualPriceLabel;

  bool get _isAnnual {
    final i = (subscription.billingInterval ?? '').trim().toLowerCase();
    return i == 'year' || i == 'annual' || i == 'yearly';
  }

  bool get _isMonthly => _isMonthlyInterval(subscription.billingInterval);

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingChange = _hasPendingPlanChange(subscription);
    final pendingLabel = _managementPlanLabelForInterval(
      subscription.pendingBillingInterval,
    );
    final pendingDate = _formatManagementDate(
      subscription.pendingChangeEffectiveAt,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(20),
        dims.scaleSpace(20),
        dims.scaleWidth(20),
        dims.scaleSpace(32),
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.bgElevated : const Color(0xFFFFFBF7),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(dims.scaleRadius(28)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: dims.scaleWidth(54),
            height: dims.scaleHeight(5),
            decoration: BoxDecoration(
              color: isDark ? colors.border : const Color(0xFFB9B0AA),
              borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
            ),
          ),
          SizedBox(height: dims.scaleSpace(12)),
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _CancelSheetCloseButton(
                  onTap:
                      () => Navigator.of(context).pop(_CancelSheetAction.keep),
                ),
              ),
              Text(
                'Cancel Subscription?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: dims.scaleText(19),
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w600,
                  color: isDark ? colors.textPrimary : const Color(0xFF2D170F),
                ),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(10)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(24)),
            child: Text(
              "We're sorry to see you go. You'll lose access to Premium features at the end of your billing period.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: dims.scaleText(11.5),
                height: 1.45,
                color: isDark ? colors.textSecondary : const Color(0xFF7F6357),
              ),
            ),
          ),
          SizedBox(height: dims.scaleSpace(20)),
          if (pendingChange)
            _CancelOptionCard(
              borderColor: const Color(0xFFFFCDBA),
              child: _CancelOptionRow(
                icon: Icons.schedule_rounded,
                iconColor: const Color(0xFFFF6B2F),
                iconBackground: const Color(0xFFFFEEE6),
                title: 'Scheduled change',
                subtitle: '$pendingLabel starts on $pendingDate.',
                trailingLabel: 'Scheduled',
                onTap: () => Navigator.of(context).pop(_CancelSheetAction.keep),
              ),
            )
          else if (_isAnnual)
            _CancelOptionCard(
              borderColor: const Color(0xFFFFCDBA),
              child: _CancelOptionRow(
                icon: Icons.sync_rounded,
                iconColor: const Color(0xFFFF6B2F),
                iconBackground: const Color(0xFFFFEEE6),
                title: 'Switch to Monthly',
                subtitle:
                    'Keep your Premium features and switch to monthly billing.',
                trailingLabel: monthlyPriceLabel,
                onTap:
                    () => Navigator.of(
                      context,
                    ).pop(_CancelSheetAction.switchToMonthly),
              ),
            )
          else if (_isMonthly)
            _CancelOptionCard(
              borderColor: const Color(0xFFFFCDBA),
              child: _CancelOptionRow(
                icon: Icons.local_offer_outlined,
                iconColor: const Color(0xFFFF6B2F),
                iconBackground: const Color(0xFFFFEEE6),
                title: 'Switch to Annual',
                subtitle:
                    'Save 27% compared to monthly and keep Premium active.',
                trailingLabel: annualPriceLabel,
                onTap:
                    () => Navigator.of(
                      context,
                    ).pop(_CancelSheetAction.switchToAnnual),
              ),
            ),
          SizedBox(height: dims.scaleSpace(10)),
          _CancelOptionCard(
            borderColor: const Color(0xFFCFE8D3),
            child: _CancelOptionRow(
              icon: Icons.check_rounded,
              iconColor: Colors.white,
              iconBackground: const Color(0xFF3A9847),
              title: 'Keep My Subscription',
              subtitle:
                  "No changes will be made. You'll continue with your current plan.",
              recommended: true,
              onTap: () => Navigator.of(context).pop(_CancelSheetAction.keep),
            ),
          ),
          SizedBox(height: dims.scaleSpace(10)),
          _CancelOptionCard(
            borderColor: const Color(0xFFFFC8C8),
            child: _CancelOptionRow(
              icon: Icons.close_rounded,
              iconColor: Colors.white,
              iconBackground: const Color(0xFFF05A56),
              title: 'Proceed to Cancel',
              subtitle:
                  'Cancel your subscription and lose access at the end of your billing period.',
              destructive: true,
              onTap:
                  () => Navigator.of(
                    context,
                  ).pop(_CancelSheetAction.proceedCancel),
            ),
          ),
          SizedBox(height: dims.scaleSpace(18)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: dims.scaleText(13),
                color: isDark ? colors.textTertiary : const Color(0xFFB09080),
              ),
              SizedBox(width: dims.scaleWidth(6)),
              Flexible(
                child: Text(
                  'You can change your plan or renew anytime.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(10.5),
                    color:
                        isDark ? colors.textTertiary : const Color(0xFFB09080),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CancelOptionCard extends StatelessWidget {
  const _CancelOptionCard({required this.child, required this.borderColor});

  final Widget child;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
        border: Border.all(
          color: isDark ? colors.border : borderColor,
          width: 0.9,
        ),
      ),
      child: child,
    );
  }
}

class _CancelSheetCloseButton extends StatelessWidget {
  const _CancelSheetCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
        onTap: onTap,
        child: Container(
          width: dims.scaleWidth(36),
          height: dims.scaleWidth(36),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? colors.border : const Color(0xFFF2E6DE),
            ),
          ),
          child: Icon(
            Icons.close_rounded,
            size: dims.scaleText(18),
            color: isDark ? colors.textPrimary : const Color(0xFF3B2A23),
          ),
        ),
      ),
    );
  }
}

class _CancelOptionRow extends StatelessWidget {
  const _CancelOptionRow({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingLabel,
    this.recommended = false,
    this.destructive = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailingLabel;
  final bool recommended;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor =
        destructive
            ? const Color(0xFFF06F63)
            : isDark
            ? colors.textPrimary
            : const Color(0xFF2F1C14);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(dims.scaleRadius(12)),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dims.scaleWidth(14),
            vertical: dims.scaleSpace(16),
          ),
          child: Row(
            children: [
              Container(
                width: dims.scaleWidth(38),
                height: dims.scaleWidth(38),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? iconColor.withValues(alpha: 0.16)
                          : iconBackground,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isDark
                            ? iconColor.withValues(alpha: 0.28)
                            : Colors.transparent,
                  ),
                ),
                child: Icon(icon, size: dims.scaleText(19), color: iconColor),
              ),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: dims.scaleText(12.5),
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(2)),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: dims.scaleText(10),
                        height: 1.35,
                        color:
                            isDark
                                ? colors.textSecondary
                                : const Color(0xFF86736A),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: dims.scaleWidth(8)),
              if (trailingLabel != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: dims.scaleWidth(8),
                    vertical: dims.scaleSpace(4),
                  ),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? const Color(0xFFFF6B2F).withValues(alpha: 0.16)
                            : const Color(0xFFFFF0E8),
                    borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
                    border: Border.all(
                      color:
                          isDark
                              ? const Color(0xFFFF6B2F).withValues(alpha: 0.32)
                              : const Color(0xFFFFD0B8),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    trailingLabel!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: dims.scaleText(9),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFF6B2F),
                    ),
                  ),
                )
              else if (recommended)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: dims.scaleWidth(8),
                    vertical: dims.scaleSpace(4),
                  ),
                  decoration: BoxDecoration(
                    color:
                        recommended
                            ? (isDark
                                ? const Color(
                                  0xFF2E8C3D,
                                ).withValues(alpha: 0.18)
                                : const Color(0xFFEAF7EC))
                            : (isDark
                                ? const Color(
                                  0xFFFF6B2F,
                                ).withValues(alpha: 0.16)
                                : const Color(0xFFFFF0E8)),
                    borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
                    border: Border.all(
                      color:
                          recommended
                              ? const Color(0xFF2E8C3D).withValues(alpha: 0.34)
                              : const Color(0xFFFF6B2F).withValues(alpha: 0.32),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    'Recommended',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: dims.scaleText(9),
                      fontWeight: FontWeight.w700,
                      color:
                          isDark
                              ? colors.accentSuccess
                              : const Color(0xFF2E8C3D),
                    ),
                  ),
                ),
              SizedBox(width: dims.scaleWidth(4)),
              Icon(
                Icons.chevron_right_rounded,
                size: dims.scaleText(20),
                color:
                    destructive
                        ? const Color(0xFFF06F63)
                        : recommended
                        ? const Color(0xFF2E8C3D)
                        : isDark
                        ? colors.textTertiary
                        : const Color(0xFF9B8A81),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagementSafetyBadges extends StatelessWidget {
  const _ManagementSafetyBadges();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    const items = [
      _SafetyBadge(
        Icons.lock_outline_rounded,
        'Your subscription is secure and encrypted.',
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < items.length; index += 1) ...[
          Flexible(child: _SafetyBadgeView(items[index])),
          if (index != items.length - 1)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(12)),
              child: SizedBox(
                height: dims.scaleHeight(18),
                child: const VerticalDivider(color: Color(0xFFE8CFC3)),
              ),
            ),
        ],
      ],
    );
  }
}

class _SafetyBadge {
  const _SafetyBadge(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _SafetyBadgeView extends StatelessWidget {
  const _SafetyBadgeView(this.badge);

  final _SafetyBadge badge;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          badge.icon,
          size: dims.scaleText(16),
          color: isDark ? colors.textSecondary : const Color(0xFF9B614B),
        ),
        SizedBox(width: dims.scaleWidth(7)),
        Flexible(
          child: Text(
            badge.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: dims.scaleText(8.7),
              fontWeight: FontWeight.w600,
              color: isDark ? colors.textSecondary : const Color(0xFF9B614B),
            ),
          ),
        ),
      ],
    );
  }
}

class _ManagementIconBadge extends StatelessWidget {
  const _ManagementIconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: dims.scaleWidth(40),
      height: dims.scaleWidth(40),
      decoration: BoxDecoration(
        color: isDark ? colors.bgSurface : const Color(0xFFFFF8F4),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF3DED2),
        ),
      ),
      child: Icon(
        icon,
        size: dims.scaleText(21),
        color: _SubscriptionScreenState._planAccent,
      ),
    );
  }
}

class _PremiumInsetDivider extends StatelessWidget {
  const _PremiumInsetDivider({this.fullWidth = false});

  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(left: fullWidth ? 0 : dims.scaleWidth(32)),
      child: Divider(
        height: 1,
        color:
            isDark
                ? colors.border.withValues(alpha: 0.55)
                : const Color(0x1ACD8D6E),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({
    required this.child,
    required this.padding,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            (isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.88)),
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF0E1D7),
        ),
        boxShadow:
            isDark
                ? null
                : const [
                  BoxShadow(
                    color: Color(0x0FC78862),
                    blurRadius: 32,
                    offset: Offset(0, 12),
                  ),
                ],
      ),
      child: child,
    );
  }
}

class _ChoosePlanTopBar extends StatelessWidget {
  const _ChoosePlanTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? colors.textPrimary : const Color(0xFF2D170F);
    final secondary = isDark ? colors.textSecondary : const Color(0xFF8C5A42);

    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: _CircleIconButton(
            icon: Icons.close_rounded,
            onTap: onBack,
            iconColor: isDark ? colors.textSecondary : const Color(0xFF8C5A42),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: dims.scaleWidth(42)),
          child: Column(
            children: [
              Text(
                'Choose your plan',
                textAlign: TextAlign.center,
                style: AppTheme.screenHeaderStyle(
                  context,
                  dims,
                  color: primary,
                )?.copyWith(fontSize: dims.scaleText(28)),
              ),
              SizedBox(height: dims.scaleSpace(8)),
              Text(
                'Unlock deeper insights, connect your health\ndata and live in sync with your cycle.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: dims.scaleText(12),
                  height: 1.38,
                  color: secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.iconColor,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      elevation: isDark ? 0 : 4,
      shadowColor: const Color(0xFFC78862).withValues(alpha: 0.16),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: dims.scaleWidth(44),
          height: dims.scaleWidth(44),
          child: Icon(icon, size: dims.scaleText(26), color: iconColor),
        ),
      ),
    );
  }
}

// ─── Plan Tab Switcher ────────────────────────────────────────────────────────

class _PlanTabSwitcher extends StatelessWidget {
  const _PlanTabSwitcher({
    required this.choices,
    required this.tabIndex,
    required this.onTabSelected,
  });

  final List<_PlanChoice> choices;
  final int tabIndex;
  final ValueChanged<int> onTabSelected;

  String _label(int i) {
    if (i >= choices.length) return '';
    final c = choices[i];
    if (c.isFree) return 'Free';
    if (c.interval == 'year') return 'Annual';
    return 'Monthly';
  }

  IconData _icon(int i) {
    if (i >= choices.length) return Icons.card_giftcard_rounded;
    final c = choices[i];
    if (c.isFree) return Icons.card_giftcard_rounded;
    if (c.interval == 'year') return Icons.workspace_premium_outlined;
    return Icons.calendar_month_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(top: dims.scaleSpace(15)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: dims.scaleHeight(58),
            padding: EdgeInsets.all(dims.scaleWidth(4)),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? colors.bgElevated
                      : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
              border: Border.all(
                color: isDark ? colors.border : const Color(0xFFF0E1D7),
              ),
              boxShadow:
                  isDark
                      ? null
                      : [
                        BoxShadow(
                          color: const Color(
                            0xFFC78862,
                          ).withValues(alpha: 0.10),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
            ),
            child: Row(
              children: [
                for (int i = 0; i < choices.length; i++)
                  Expanded(
                    child: _PlanTab(
                      label: _label(i),
                      icon: _icon(i),
                      isSelected: tabIndex == i,
                      onTap: () => onTabSelected(i),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: -dims.scaleSpace(15),
            right: dims.scaleWidth(36),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: dims.scaleWidth(14),
                vertical: dims.scaleSpace(6),
              ),
              decoration: BoxDecoration(
                color: isDark ? colors.bgElevated : const Color(0xFFFFFBF8),
                borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
                border: Border.all(color: const Color(0xFFFFD8C8)),
              ),
              child: Text(
                'Best value',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: dims.scaleText(8),
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: _SubscriptionScreenState._planAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanTab extends StatelessWidget {
  const _PlanTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        margin: isSelected ? const EdgeInsets.only(top: 3) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: isSelected ? _SubscriptionScreenState._planAccentSoft : null,
          borderRadius: BorderRadius.circular(dims.scaleRadius(10)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: dims.scaleText(17),
              color:
                  isSelected
                      ? _SubscriptionScreenState._planAccent
                      : isDark
                      ? colors.textSecondary
                      : const Color(0xFF9B614B),
            ),
            SizedBox(width: dims.scaleWidth(8)),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: dims.scaleText(10.5),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0,
                color:
                    isSelected
                        ? _SubscriptionScreenState._planAccent
                        : isDark
                        ? colors.textSecondary
                        : const Color(0xFF8C5A42),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab Plan Detail Card ─────────────────────────────────────────────────────

class _TabPlanDetailCard extends StatelessWidget {
  const _TabPlanDetailCard({
    required this.choice,
    required this.isLoading,
    required this.onContinue,
  });

  final _PlanChoice? choice;
  final bool isLoading;
  final VoidCallback? onContinue;

  static const _freeFeatures = [
    (
      'Cycle & period tracking',
      'Track your periods, symptoms and cycle phases.',
    ),
    (
      'Basic insights & reminders',
      'Get simple insights and helpful reminders.',
    ),
    ('Calendars & logging', 'Log your moods, symptoms and daily notes.'),
    ('Community support', 'Access to articles and community resources.'),
  ];

  static const _monthlyFeatures = [
    ('AI-powered cycle insights', ''),
    ('Vyla Wear integration', ''),
    ('Personalized predictions', ''),
    ('Advanced reports', ''),
    ('Priority support', ''),
    ('Vyla wearable compatible', ''),
  ];

  static const _annualFeatures = [
    ('AI-powered cycle insights', ''),
    ('Vyla Wear integration', ''),
    ('Personalized predictions', ''),
    ('Advanced reports', ''),
    ('Priority support', ''),
    ('Vyla wearable compatible', ''),
  ];

  List<(String, String)> _features(_PlanChoice c) {
    if (c.isFree) return _freeFeatures;
    if (c.interval == 'year') return _annualFeatures;
    return _monthlyFeatures;
  }

  @override
  Widget build(BuildContext context) {
    if (choice == null) return const SizedBox.shrink();
    final c = choice!;
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFree = c.isFree;
    final isAnnual = c.interval == 'year';

    final accentOrange = _SubscriptionScreenState._planAccent;
    final borderColor =
        isDark
            ? colors.border
            : const Color(0xFFFFD9C8).withValues(alpha: 0.72);
    final price = isFree ? '£0' : c.price;
    final cadence = isFree ? '/ forever' : c.cadence;
    final planTitle =
        isFree
            ? 'Free'
            : isAnnual
            ? 'Premium Annual'
            : 'Premium Monthly';
    final subtitle =
        isFree
            ? 'Perfect for getting started.'
            : isAnnual
            ? _monthlyEquivalent(c.price)
            : 'Cancel anytime.';
    final ctaLabel =
        isFree
            ? 'Continue with Free'
            : isAnnual
            ? 'Choose Annual'
            : 'Choose Monthly';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(18),
        dims.scaleSpace(16),
        dims.scaleWidth(18),
        dims.scaleSpace(16),
      ),
      decoration: BoxDecoration(
        color:
            isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
        border: Border.all(color: borderColor),
        boxShadow:
            isDark
                ? null
                : [
                  BoxShadow(
                    color: const Color(0xFFC78862).withValues(alpha: 0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 16),
                  ),
                ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isAnnual)
            _PlanPill(
              icon: Icons.local_offer_outlined,
              label: c.savingsLabel ?? "YOU'RE SAVING 27%",
            )
          else if (!isFree)
            const _PlanPill(label: 'FLEXIBLE CHOICE'),
          if (isAnnual || !isFree) SizedBox(height: dims.scaleSpace(14)),
          if (isFree) ...[
            Container(
              width: dims.scaleWidth(48),
              height: dims.scaleWidth(48),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF0E8),
              ),
              child: Icon(
                Icons.card_giftcard_rounded,
                size: dims.scaleText(26),
                color: accentOrange,
              ),
            ),
            SizedBox(height: dims.scaleSpace(10)),
          ],
          Text(
            planTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: dims.scaleText(isFree ? 21 : 18),
              height: 1,
              fontFamily: 'Georgia',
              fontWeight: FontWeight.w600,
              color: isDark ? colors.textPrimary : const Color(0xFF10212A),
            ),
          ),
          SizedBox(height: dims.scaleSpace(8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: dims.scaleText(isFree ? 21 : 30),
                  height: 0.94,
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w700,
                  color: isDark ? colors.textPrimary : const Color(0xFF10212A),
                ),
              ),
              SizedBox(width: dims.scaleWidth(6)),
              Padding(
                padding: EdgeInsets.only(bottom: dims.scaleSpace(4)),
                child: Text(
                  cadence,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(isFree ? 9 : 12),
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF10212A),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(8)),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: dims.scaleText(10),
              height: 1.25,
              color: isDark ? colors.textSecondary : const Color(0xFF74635B),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              dims.scaleWidth(36),
              dims.scaleSpace(16),
              dims.scaleWidth(36),
              dims.scaleSpace(14),
            ),
            child: Divider(
              height: 1,
              color:
                  isDark
                      ? colors.border.withValues(alpha: 0.45)
                      : const Color(0xFFF1E4DC),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              dims.scaleWidth(34),
              0,
              dims.scaleWidth(34),
              dims.scaleSpace(14),
            ),
            child: Column(
              children: [
                for (final f in _features(c))
                  Padding(
                    padding: EdgeInsets.only(bottom: dims.scaleSpace(12)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: dims.scaleWidth(24),
                          height: dims.scaleWidth(24),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFFF0E8),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: dims.scaleText(15),
                            color: accentOrange,
                          ),
                        ),
                        SizedBox(width: dims.scaleWidth(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      f.$1,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.copyWith(
                                        fontSize: dims.scaleText(10.2),
                                        height: 1.25,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            isDark
                                                ? colors.textPrimary
                                                : const Color(0xFF26323D),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (f.$2.isNotEmpty) ...[
                                SizedBox(height: dims.scaleSpace(3)),
                                Text(
                                  f.$2,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    fontSize: dims.scaleText(8.4),
                                    height: 1.25,
                                    color:
                                        isDark
                                            ? colors.textSecondary
                                            : const Color(0xFF74635B),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _PlanActionButton(
            label: ctaLabel,
            outline: isFree,
            isLoading: isLoading,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

class _PlanPill extends StatelessWidget {
  const _PlanPill({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(12),
        vertical: dims.scaleSpace(5),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: dims.scaleText(12),
              color: _SubscriptionScreenState._planAccent,
            ),
            SizedBox(width: dims.scaleWidth(4)),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: dims.scaleText(8),
              height: 1,
              fontWeight: FontWeight.w800,
              color: _SubscriptionScreenState._planAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanActionButton extends StatelessWidget {
  const _PlanActionButton({
    required this.label,
    required this.outline,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool outline;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final radius = BorderRadius.circular(dims.scaleRadius(999));

    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(dims.scaleHeight(50)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: _SubscriptionScreenState._planAccentSoft,
        disabledBackgroundColor: _SubscriptionScreenState._planAccentSoft
            .withValues(alpha: 0.55),
        foregroundColor: _SubscriptionScreenState._planAccent,
        disabledForegroundColor: _SubscriptionScreenState._planAccent
            .withValues(alpha: 0.45),
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: _SubscriptionScreenState._planAccent.withValues(alpha: 0.35),
          ),
        ),
      ),
      child:
          isLoading
              ? _CheckoutButtonProgress(emphasize: !outline)
              : Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: dims.scaleText(13),
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: _SubscriptionScreenState._planAccent,
                ),
              ),
    );
  }
}

String _monthlyEquivalent(String annualPrice) {
  final annual = _numericPriceValue(annualPrice);
  if (annual == null || annual <= 0) {
    return '£2.92 per month';
  }
  final symbol =
      annualPrice.trim().startsWith('\$')
          ? '\$'
          : annualPrice.trim().startsWith('€')
          ? '€'
          : '£';
  return '$symbol${(annual / 12).toStringAsFixed(2)} per month';
}

// ─── Desktop Image Panel ──────────────────────────────────────────────────────

class _PlanImagePanel extends StatelessWidget {
  const _PlanImagePanel({
    required this.tabIndex,
    required this.choice,
    required this.fadeAnim,
  });

  final int tabIndex;
  final _PlanChoice? choice;
  final Animation<double> fadeAnim;

  static const _imagePaths = [
    'assets/images/plan.png',
    'assets/images/plan2.png',
    'assets/images/plan3.png',
  ];

  static const _accentColors = [
    Color(0xFF17814F),
    Color(0xFFFF6B2F),
    Color(0xFFFF4118),
  ];

  static const _fallbackGradients = [
    [Color(0xFF1A6B42), Color(0xFF0A3D25)],
    [Color(0xFFFF7D45), Color(0xFFAD3408)],
    [Color(0xFFFF5229), Color(0xFF8B2000)],
  ];

  @override
  Widget build(BuildContext context) {
    final idx = tabIndex.clamp(0, _imagePaths.length - 1);
    final accent = _accentColors[idx];
    final dims = context.dims;
    final c = choice;

    return FadeTransition(
      opacity: fadeAnim,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image with gradient fallback
            Image.asset(
              _imagePaths[idx],
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder:
                  (_, __, ___) => _PlanImageFallback(
                    tabIndex: idx,
                    gradients: _fallbackGradients,
                    accent: accent,
                  ),
            ),
            // Scrim — dark gradient from bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 260,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0.0, 0.55, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.78),
                      Colors.black.withValues(alpha: 0.32),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Top subtle vignette
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Plan info overlay at bottom
            if (c != null)
              Positioned(
                bottom: 40,
                left: 36,
                right: 36,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Plan badge chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.36),
                        ),
                      ),
                      child: Text(
                        c.title.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Tagline
                    Text(
                      c.description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        height: 1.38,
                        fontFamily: 'Georgia',
                        shadows: [
                          Shadow(color: Color(0x66000000), blurRadius: 10),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Price row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          c.price,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            height: 0.95,
                            fontFamily: 'Georgia',
                            shadows: [
                              Shadow(color: Color(0x88000000), blurRadius: 12),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            c.cadence,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 13,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            // App logo watermark top-left
            Positioned(
              top: 28,
              left: 28,
              child: Image.asset(
                'assets/icons/phora_logo.png',
                width: dims.scaleWidth(32),
                filterQuality: FilterQuality.high,
                color: Colors.white.withValues(alpha: 0.9),
                colorBlendMode: BlendMode.srcATop,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanImageFallback extends StatelessWidget {
  const _PlanImageFallback({
    required this.tabIndex,
    required this.gradients,
    required this.accent,
  });

  final int tabIndex;
  final List<List<Color>> gradients;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final grad = gradients[tabIndex.clamp(0, gradients.length - 1)];
    final dims = context.dims;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: grad,
        ),
      ),
      child: Stack(
        children: [
          // Large decorative circle – top right
          Positioned(
            top: -80,
            right: -50,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Medium circle – left middle
          Positioned(
            top: 160,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          // Small circle – lower right
          Positioned(
            bottom: 200,
            right: 40,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          // Centered logo
          Center(
            child: Image.asset(
              'assets/icons/phora_logo.png',
              width: dims.scaleWidth(80),
              filterQuality: FilterQuality.high,
              color: Colors.white.withValues(alpha: 0.45),
              colorBlendMode: BlendMode.srcATop,
              errorBuilder:
                  (_, __, ___) => Icon(
                    Icons.favorite_rounded,
                    size: dims.scaleText(64),
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WearableIncludedCard extends StatelessWidget {
  const _WearableIncludedCard({
    required this.selected,
    required this.availability,
    required this.isLoading,
    required this.enabled,
    required this.onChanged,
  });

  final bool selected;
  final WearableAvailability? availability;
  final bool isLoading;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayPrice =
        isLoading ? 'Loading...' : availability?.displayPrice ?? 'Unavailable';
    final stockLabel =
        isLoading
            ? 'Checking stock'
            : availability == null
            ? 'Wearable info unavailable'
            : availability!.isCountryBlocked
            ? 'Not available in your country yet'
            : availability!.available
            ? availability!.lowStock
                ? 'Low stock'
                : 'In stock'
            : 'Out of stock';

    return GestureDetector(
      onTap: enabled && onChanged != null ? () => onChanged!(!selected) : null,
      child: _SoftPanel(
        padding: EdgeInsets.fromLTRB(
          dims.scaleWidth(18),
          dims.scaleSpace(12),
          dims.scaleWidth(18),
          dims.scaleSpace(12),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: dims.scaleWidth(48),
                  height: dims.scaleWidth(48),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? colors.bgSurface : const Color(0xFFFFEFE7),
                  ),
                  child: Icon(
                    Icons.watch_outlined,
                    size: dims.scaleText(25),
                    color: _SubscriptionScreenState._planAccent,
                  ),
                ),
                SizedBox(width: dims.scaleWidth(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Add Vyla Wearable',
                              style: Theme.of(
                                context,
                              ).textTheme.displaySmall?.copyWith(
                                fontSize: dims.scaleText(15),
                                height: 1.05,
                                fontFamily: 'Georgia',
                                fontWeight: FontWeight.w600,
                                color:
                                    isDark
                                        ? colors.textPrimary
                                        : const Color(0xFF2D170F),
                              ),
                            ),
                          ),
                          SizedBox(width: dims.scaleWidth(8)),
                          _OptionalPill(),
                        ],
                      ),
                      SizedBox(height: dims.scaleSpace(6)),
                      Text(
                        'Track temperature, HRV, sleep and\nrecovery for even deeper insights.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: dims.scaleText(9),
                          height: 1.26,
                          color:
                              isDark
                                  ? colors.textSecondary
                                  : const Color(0xFF74635B),
                        ),
                      ),
                      SizedBox(height: dims.scaleSpace(7)),
                      Text(
                        stockLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: dims.scaleText(8),
                          fontWeight: FontWeight.w700,
                          color:
                              availability?.available == true
                                  ? const Color(0xFF218849)
                                  : const Color(0xFFC34E37),
                        ),
                      ),
                      SizedBox(height: dims.scaleSpace(7)),
                      Row(
                        children: [
                          Flexible(
                            flex: 0,
                            child: Text(
                              displayPrice,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                fontSize: dims.scaleText(15),
                                height: 1,
                                fontWeight: FontWeight.w800,
                                color: _SubscriptionScreenState._planAccent,
                              ),
                            ),
                          ),
                          SizedBox(width: dims.scaleWidth(8)),
                          Flexible(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: dims.scaleWidth(8),
                                vertical: dims.scaleSpace(4),
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8EDE7),
                                borderRadius: BorderRadius.circular(
                                  dims.scaleRadius(999),
                                ),
                              ),
                              child: Text(
                                'One-time purchase',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).textTheme.labelSmall?.copyWith(
                                  fontSize: dims.scaleText(7),
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF8C5A42),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: dims.scaleWidth(8)),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: dims.scaleWidth(24),
                  height: dims.scaleWidth(24),
                  decoration: BoxDecoration(
                    color:
                        selected && enabled
                            ? _SubscriptionScreenState._planAccent
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(dims.scaleRadius(6)),
                    border: Border.all(
                      color:
                          enabled
                              ? _SubscriptionScreenState._planAccent
                              : const Color(0xFFD9C8BF),
                      width: 1.3,
                    ),
                  ),
                  child:
                      selected && enabled
                          ? Icon(
                            Icons.check_rounded,
                            size: dims.scaleText(18),
                            color: Colors.white,
                          )
                          : null,
                ),
              ],
            ),
            SizedBox(height: dims.scaleSpace(10)),
            Row(
              children: [
                const Expanded(
                  child: _WearableMetric(
                    icon: Icons.thermostat,
                    label: 'Temperature',
                  ),
                ),
                const Expanded(
                  child: _WearableMetric(
                    icon: Icons.favorite_border_rounded,
                    label: 'HRV',
                  ),
                ),
                const Expanded(
                  child: _WearableMetric(
                    icon: Icons.nightlight_round,
                    label: 'Sleep',
                  ),
                ),
                const Expanded(
                  child: _WearableMetric(
                    icon: Icons.bolt_outlined,
                    label: 'Recovery',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WearableMetric extends StatelessWidget {
  const _WearableMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: dims.scaleText(17),
          color: _SubscriptionScreenState._planAccent,
        ),
        SizedBox(width: dims.scaleWidth(5)),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: dims.scaleText(7.5),
              height: 1,
              fontWeight: FontWeight.w700,
              color: isDark ? colors.textPrimary : const Color(0xFF26323D),
            ),
          ),
        ),
      ],
    );
  }
}

class _HealthSyncCard extends StatelessWidget {
  const _HealthSyncCard();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SoftPanel(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(18),
        dims.scaleSpace(14),
        dims.scaleWidth(18),
        dims.scaleSpace(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.watch_rounded),
          SizedBox(width: dims.scaleWidth(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Works with Vyla Wear',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(10),
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF26323D),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(4)),
                Text(
                  'Sync your health data securely for more accurate\ninsights and predictions.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(8.5),
                    height: 1.25,
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF74635B),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock_outline_rounded,
            size: dims.scaleText(22),
            color: const Color(0xFF9B614B),
          ),
        ],
      ),
    );
  }
}

class _PremiumNudgeCard extends StatelessWidget {
  const _PremiumNudgeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PlanNudgeCard(
      icon: Icons.auto_awesome_rounded,
      title: 'Go Premium for deeper insights',
      subtitle:
          'Unlock AI-powered predictions, Vyla Wear\nintegration, advanced reports and priority support.',
      buttonLabel: 'See Premium',
      onTap: onTap,
    );
  }
}

class _AnnualNudgeCard extends StatelessWidget {
  const _AnnualNudgeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PlanNudgeCard(
      icon: Icons.auto_awesome_rounded,
      title: 'Go Annual and save 27%',
      subtitle: 'Get the best value and enjoy all Premium\nbenefits for less.',
      buttonLabel: 'See Annual Plan',
      onTap: onTap,
    );
  }
}

class _PlanNudgeCard extends StatelessWidget {
  const _PlanNudgeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _SoftPanel(
      padding: EdgeInsets.fromLTRB(
        dims.scaleWidth(18),
        dims.scaleSpace(14),
        dims.scaleWidth(18),
        dims.scaleSpace(14),
      ),
      child: Row(
        children: [
          Container(
            width: dims.scaleWidth(46),
            height: dims.scaleWidth(46),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFF0E8),
              border: Border.all(color: const Color(0xFFFFD8C8)),
            ),
            child: Icon(
              icon,
              color: _SubscriptionScreenState._planAccent,
              size: dims.scaleText(22),
            ),
          ),
          SizedBox(width: dims.scaleWidth(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(9.5),
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF5A382C),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(4)),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: dims.scaleText(7.8),
                    height: 1.25,
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF8C5A42),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: dims.scaleWidth(12)),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              minimumSize: Size(dims.scaleWidth(110), dims.scaleHeight(38)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: _SubscriptionScreenState._planAccent,
              side: const BorderSide(
                color: _SubscriptionScreenState._planAccent,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
              ),
            ),
            child: Text(
              buttonLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: dims.scaleText(8),
                height: 1,
                fontWeight: FontWeight.w800,
                color: _SubscriptionScreenState._planAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanDividerLabel extends StatelessWidget {
  const _PlanDividerLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFEFD7CB))),
        Container(
          margin: EdgeInsets.symmetric(horizontal: dims.scaleWidth(10)),
          padding: EdgeInsets.symmetric(
            horizontal: dims.scaleWidth(12),
            vertical: dims.scaleSpace(5),
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF8),
            borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
            border: Border.all(color: const Color(0xFFEFD7CB)),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: dims.scaleText(8),
              height: 1,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8C5A42),
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFEFD7CB))),
      ],
    );
  }
}

class _SubscriptionSafetyBadges extends StatelessWidget {
  const _SubscriptionSafetyBadges();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dims.scaleWidth(14),
        vertical: dims.scaleSpace(12),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F2),
        borderRadius: BorderRadius.circular(dims.scaleRadius(14)),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _SafetyBadgeView(
              _SafetyBadge(Icons.lock_outline_rounded, 'Secure payments'),
            ),
          ),
          Expanded(
            child: _SafetyBadgeView(
              _SafetyBadge(Icons.sync_rounded, 'Cancel anytime'),
            ),
          ),
          Expanded(
            child: _SafetyBadgeView(
              _SafetyBadge(Icons.verified_user_outlined, 'No hidden fees'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionFooterLinks extends StatelessWidget {
  const _SubscriptionFooterLinks();

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: dims.scaleText(8),
      height: 1,
      color: isDark ? colors.textTertiary : const Color(0xFFA67560),
    );

    final linkStyle = style?.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: isDark ? colors.textTertiary : const Color(0xFFA67560),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: dims.scaleSpace(8),
      children: [
        Text('By continuing, you agree to our ', style: style),
        GestureDetector(
          onTap: () => launchUrl(Uri.parse('https://vyla.health/terms')),
          child: Text(context.l10n.termsOfServiceLabel, style: linkStyle),
        ),
        Text(' and ', style: style),
        GestureDetector(
          onTap: () => launchUrl(Uri.parse('https://vyla.health/privacy')),
          child: Text(context.l10n.privacyPolicyTitleLabel, style: linkStyle),
        ),
        Text('.', style: style),
      ],
    );
  }
}

class _SoftPanel extends StatelessWidget {
  const _SoftPanel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(dims.scaleRadius(15)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF0E1D7),
        ),
        boxShadow:
            isDark
                ? null
                : [
                  BoxShadow(
                    color: const Color(0xFFC78862).withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
      ),
      child: child,
    );
  }
}

PlanPriceOption? _priceOptionFor(Plan plan, String interval) {
  return plan.priceOptions
      .where((option) => option.interval == interval)
      .firstOrNull;
}

String _priceLabelFor(Plan plan, PlanPriceOption? option) {
  final optionPrice = option?.displayPrice?.trim();
  if (optionPrice != null && optionPrice.isNotEmpty) {
    return optionPrice;
  }
  final displayPrice = plan.displayPrice?.trim();
  if (displayPrice != null && displayPrice.isNotEmpty) {
    return displayPrice;
  }
  return plan.priceLabel;
}

String _freePriceLabel(BillingPlanOffers offers, Plan plan) {
  final displayPrice = plan.displayPrice?.trim();
  if (displayPrice != null && displayPrice.isNotEmpty) {
    return displayPrice;
  }
  final priceLabel = plan.priceLabel.trim();
  if (priceLabel.contains('0')) {
    return priceLabel;
  }
  final symbol = plan.currencySymbol ?? offers.currencySymbol ?? '';
  return symbol.isEmpty ? '0' : '${symbol}0';
}

String _managementPlanLabel(SubscriptionState subscription) {
  return _managementPlanLabelForInterval(subscription.billingInterval);
}

String _managementPlanLabelForInterval(String? intervalValue) {
  final interval = (intervalValue ?? '').trim().toLowerCase();
  return switch (interval) {
    'year' || 'annual' || 'yearly' => 'Premium Annual',
    'month' || 'monthly' => 'Premium Monthly',
    _ => 'Premium',
  };
}

String _managementPrice(SubscriptionState subscription) {
  final amount = subscription.amount;
  if (amount == null) {
    return switch ((subscription.currency ?? '').trim().toUpperCase()) {
      'USD' => '\$35.00',
      'EUR' => '€35.00',
      _ => '£35.00',
    };
  }
  return '${_currencySymbol(subscription.currency)}${amount.toStringAsFixed(2)}';
}

bool _isMonthlyInterval(String? interval) {
  final value = (interval ?? '').trim().toLowerCase();
  return value == 'month' || value == 'monthly';
}

bool _hasPendingPlanChange(SubscriptionState subscription) {
  if ((subscription.pendingBillingInterval ?? '').trim().isEmpty) {
    return false;
  }
  final effectiveAt = subscription.pendingChangeEffectiveAt;
  if (effectiveAt == null) {
    return false;
  }
  return effectiveAt.toLocal().isAfter(DateTime.now());
}

String _currencySymbol(String? currency) {
  return switch ((currency ?? '').trim().toUpperCase()) {
    'GBP' => '£',
    'USD' => '\$',
    'EUR' => '€',
    'NGN' => '₦',
    _ => '',
  };
}

String _managementCadence(String? interval) {
  return switch ((interval ?? '').trim().toLowerCase()) {
    'month' || 'monthly' => '/ month',
    _ => '/ year',
  };
}

String _formatManagementDate(DateTime? date) {
  if (date == null) {
    return '21 May 2026';
  }
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _expiryDistanceLabel(DateTime expiresAt) {
  final now = DateTime.now();
  final localExpiry = expiresAt.toLocal();
  if (!localExpiry.isAfter(now)) {
    return 'less than a day';
  }
  final days = localExpiry.difference(now).inDays;
  if (days >= 60) {
    final months = (days / 30).round();
    return '$months months';
  }
  if (days >= 30) {
    return '1 month';
  }
  if (days >= 2) {
    return '$days days';
  }
  if (days == 1) {
    return '1 day';
  }
  return 'less than a day';
}

String _cadenceLabel(BuildContext context, String interval) {
  return switch (interval) {
    'year' => '/ ${context.l10n.subscriptionYearLabelShort}',
    'month' => '/ ${context.l10n.subscriptionMonthLabelShort}',
    _ => interval.isEmpty ? '' : '/ $interval',
  };
}

String _yearlySavingsLabel(BuildContext context, Plan plan) {
  final monthly = _priceOptionFor(plan, 'month');
  final yearly = _priceOptionFor(plan, 'year');
  if (monthly == null || yearly == null) {
    return context.l10n.subscriptionSaveYearly;
  }
  final monthlyValue = _numericPriceValue(monthly.displayPrice);
  final yearlyValue = _numericPriceValue(yearly.displayPrice);
  if (monthlyValue == null || yearlyValue == null || monthlyValue <= 0) {
    return context.l10n.subscriptionSaveYearly;
  }
  final discount = ((1 - ((yearlyValue / 12) / monthlyValue)) * 100).round();
  if (discount <= 0) {
    return context.l10n.subscriptionSaveYearly;
  }
  return context.l10n.subscriptionSavePercent(discount);
}

double? _numericPriceValue(String? label) {
  if (label == null || label.isEmpty) return null;
  final cleaned = label.replaceAll(RegExp(r'[^0-9,\\.]'), '');
  if (cleaned.isEmpty) return null;
  if (cleaned.contains(',') && cleaned.contains('.')) {
    return double.tryParse(cleaned.replaceAll('.', '').replaceAll(',', '.'));
  }
  if (cleaned.contains(',')) {
    return double.tryParse(cleaned.replaceAll(',', '.'));
  }
  return double.tryParse(cleaned);
}

class _CheckoutButtonProgress extends StatefulWidget {
  const _CheckoutButtonProgress({required this.emphasize});

  final bool emphasize;

  @override
  State<_CheckoutButtonProgress> createState() =>
      _CheckoutButtonProgressState();
}

class _CheckoutButtonProgressState extends State<_CheckoutButtonProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final trackColor =
        widget.emphasize ? Colors.white.withValues(alpha: 0.28) : colors.border;
    final fillColor =
        widget.emphasize ? Colors.white : _SubscriptionScreenState._planAccent;
    final barWidth = dims.scaleWidth(96, min: 0.9, max: 1.25);
    final barHeight = dims.scaleHeight(5, min: 0.9, max: 1.2);

    return SizedBox(
      width: barWidth,
      height: dims.scaleHeight(22, min: 0.9, max: 1.2),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(dims.scaleRadius(999)),
          child: DecoratedBox(
            decoration: BoxDecoration(color: trackColor),
            child: SizedBox(
              width: barWidth,
              height: barHeight,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final alignment = Alignment(-1 + (_controller.value * 2), 0);
                  return Align(alignment: alignment, child: child);
                },
                child: FractionallySizedBox(
                  widthFactor: 0.36,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: fillColor),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnsupportedPricingCard extends StatelessWidget {
  const _UnsupportedPricingCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(17)),
      decoration: BoxDecoration(
        color:
            isDark
                ? colors.bgCard.withValues(alpha: 0.96)
                : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(dims.scaleRadius(23)),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontSize: dims.scaleText(13),
          fontWeight: FontWeight.w400,
          height: 1.4,
          color: colors.textSecondary,
        ),
      ),
    );
  }
}

class _SubscriptionManagementCard extends StatelessWidget {
  const _SubscriptionManagementCard({
    required this.subscription,
    required this.onCancel,
  });

  final SubscriptionState subscription;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(20)),
      decoration: BoxDecoration(
        color:
            isDark
                ? colors.bgCard.withValues(alpha: 0.96)
                : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(dims.scaleRadius(24)),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.manageSubscriptionLabel,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: dims.scaleText(20),
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: dims.scaleSpace(8)),
          Text(
            _managementSummary(context, subscription),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: dims.scaleText(15),
              color: colors.textSecondary,
            ),
          ),
          SizedBox(height: dims.scaleSpace(16)),
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(dims.scaleHeight(50)),
              side: BorderSide(
                color: colors.accentDanger.withValues(alpha: 0.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
              ),
            ),
            child: Text(
              context.l10n.subscriptionCancelAction,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: dims.scaleText(16),
                fontWeight: FontWeight.w700,
                color: colors.accentDanger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _managementSummary(
    BuildContext context,
    SubscriptionState subscription,
  ) {
    final interval = subscription.billingInterval;
    final amount = subscription.amount;
    final currency = subscription.currency ?? '';

    if (amount != null && interval != null && currency.isNotEmpty) {
      return context.l10n.subscriptionManagementRenews(
        _planLabel(context, subscription.tier),
        '$amount $currency',
        interval,
      );
    }
    return context.l10n.subscriptionManagementActive(
      _planLabel(context, subscription.tier),
    );
  }

  String _planLabel(BuildContext context, SubscriptionTier tier) {
    return switch (tier) {
      SubscriptionTier.free => context.l10n.planFreeLabel,
      SubscriptionTier.premium => context.l10n.planPremiumLabel,
    };
  }
}

class TrialEndScreen extends StatelessWidget {
  const TrialEndScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SubscriptionStateScaffold(
      title: context.l10n.subscriptionTrialEndingTitle,
      body: context.l10n.subscriptionTrialEndingBody,
    );
  }
}

class PaymentFailureScreen extends StatelessWidget {
  const PaymentFailureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SubscriptionStateScaffold(
      title: context.l10n.subscriptionPaymentIssueTitle,
      body: context.l10n.subscriptionPaymentIssueBody,
    );
  }
}

class BillingSuccessScreen extends ConsumerStatefulWidget {
  const BillingSuccessScreen({
    super.key,
    this.sessionId,
    this.providerSubscriptionId,
  });

  final String? sessionId;
  final String? providerSubscriptionId;

  @override
  ConsumerState<BillingSuccessScreen> createState() =>
      _BillingSuccessScreenState();
}

class _BillingSuccessScreenState extends ConsumerState<BillingSuccessScreen> {
  bool _handled = false;
  bool _isFinishing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_handled || !mounted) return;
      _handled = true;
      unawaited(_completePayment());
    });
  }

  Future<void> _completePayment() async {
    ref.read(paymentSuccessGraceUntilProvider.notifier).state = DateTime.now()
        .add(const Duration(minutes: 2));
    final providerSubscriptionId = widget.providerSubscriptionId?.trim();
    try {
      if (providerSubscriptionId != null && providerSubscriptionId.isNotEmpty) {
        final nextState = await ref
            .read(subscriptionRepositoryProvider)
            .syncStripePaymentSheetSubscription(
              subscriptionId: providerSubscriptionId,
            );
        if (!mounted) return;
        ref
            .read(currentSubscriptionProvider.notifier)
            .setSubscriptionState(nextState);
      } else if ((widget.sessionId?.trim().isNotEmpty ?? false)) {
        await ref.read(currentSubscriptionProvider.notifier).refresh();
      }
    } catch (_) {
      if (!mounted) return;
    }
    if (!mounted) return;
    setState(() => _isFinishing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinishing) {
      return Scaffold(
        body: Center(
          child: PhoraLoadingView(
            message: context.l10n.subscriptionFinishingPayment,
          ),
        ),
      );
    }

    final subscription =
        ref.watch(currentSubscriptionProvider).valueOrNull ??
        SubscriptionState(
          tier: SubscriptionTier.premium,
          status: SubscriptionStatus.active,
          isActive: true,
          billingInterval: 'year',
        );
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final planLabel = _managementPlanLabel(subscription);
    final price = _managementPrice(subscription);
    final cadence = _managementCadence(subscription.billingInterval);
    final renewalDate = _formatManagementDate(
      subscription.nextBillingDate ??
          DateTime.now().add(
            (subscription.billingInterval ?? '').toLowerCase().startsWith(
                  'month',
                )
                ? const Duration(days: 30)
                : const Duration(days: 365),
          ),
    );

    return Scaffold(
      backgroundColor: isDark ? colors.bg : const Color(0xFFFFFBF7),
      body: DecoratedBox(
        decoration: authBackgroundDecoration(context),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              dims.scaleWidth(24),
              dims.scaleSpace(28),
              dims.scaleWidth(24),
              dims.scaleSpace(20),
            ),
            child: Column(
              children: [
                Container(
                  width: dims.scaleWidth(78),
                  height: dims.scaleWidth(78),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF7A3D),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF7A3D).withValues(alpha: 0.25),
                        blurRadius: 34,
                        spreadRadius: 12,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: dims.scaleText(52),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(20)),
                Text(
                  'Payment successful!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: dims.scaleText(16),
                    fontWeight: FontWeight.w800,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF10232B),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(10)),
                Text(
                  'Welcome to Vyla Premium.\nYou now have access to all Premium features.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: dims.scaleText(12),
                    height: 1.35,
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF765B50),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(20)),
                _PaymentSuccessPlanCard(
                  planLabel: planLabel,
                  price: price,
                  cadence: cadence,
                  renewalDate: renewalDate,
                ),
                SizedBox(height: dims.scaleSpace(18)),
                _PaymentSuccessInfoTile(
                  icon: Icons.watch_rounded,
                  title: 'Vyla Wear compatible',
                  body:
                      'Connect Vyla Wear to sync wellness data securely for deeper insights.',
                  trailingIcon: Icons.check_rounded,
                ),
                SizedBox(height: dims.scaleSpace(14)),
                _PaymentSuccessInfoTile(
                  icon: Icons.watch_rounded,
                  title: 'Vyla Wearable',
                  body: 'Track temperature, HRV, sleep and recovery.',
                  trailingIcon: Icons.card_giftcard_rounded,
                ),
                SizedBox(height: dims.scaleSpace(28)),
                SizedBox(
                  width: double.infinity,
                  height: dims.scaleHeight(58),
                  child: FilledButton.icon(
                    onPressed: () => context.go('/today'),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B2F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          dims.scaleRadius(18),
                        ),
                      ),
                    ),
                    label: Text(
                      'Continue to Homepage',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: dims.scaleText(12),
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(18)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: dims.scaleText(16),
                      color:
                          isDark
                              ? colors.textSecondary
                              : const Color(0xFF806457),
                    ),
                    SizedBox(width: dims.scaleWidth(6)),
                    Text(
                      'Your payment was processed securely.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: dims.scaleText(13),
                        color:
                            isDark
                                ? colors.textSecondary
                                : const Color(0xFF806457),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentSuccessPlanCard extends StatelessWidget {
  const _PaymentSuccessPlanCard({
    required this.planLabel,
    required this.price,
    required this.cadence,
    required this.renewalDate,
  });

  final String planLabel;
  final String price;
  final String cadence;
  final String renewalDate;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const features = [
      'AI-powered cycle insights',
      'Vyla Wear integration',
      'Personalized predictions',
      'Advanced reports',
      'Priority support',
      'Vyla wearable compatible',
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(22)),
      decoration: BoxDecoration(
        color:
            isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(dims.scaleRadius(20)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF4D8C9),
        ),
        boxShadow:
            isDark
                ? null
                : [
                  BoxShadow(
                    color: const Color(0xFFC87954).withValues(alpha: 0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Plan',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: dims.scaleText(11),
              fontWeight: FontWeight.w700,
              color: isDark ? colors.textSecondary : const Color(0xFF7C5A4D),
            ),
          ),
          SizedBox(height: dims.scaleSpace(16)),
          Row(
            children: [
              Container(
                width: dims.scaleWidth(56),
                height: dims.scaleWidth(56),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFF6B2F),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: dims.scaleText(18),
                ),
              ),
              SizedBox(width: dims.scaleWidth(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planLabel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: dims.scaleText(18),
                        fontWeight: FontWeight.w600,
                        color:
                            isDark
                                ? colors.textPrimary
                                : const Color(0xFF10232B),
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(4)),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: price,
                            style: TextStyle(
                              color: const Color(0xFFFF6B2F),
                              fontSize: dims.scaleText(18),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: ' $cadence',
                            style: TextStyle(
                              color:
                                  isDark
                                      ? colors.textSecondary
                                      : const Color(0xFF503C35),
                              fontSize: dims.scaleText(15),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: dims.scaleSpace(4)),
                    Text(
                      'Renews on $renewalDate',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: dims.scaleText(13),
                        color:
                            isDark
                                ? colors.textSecondary
                                : const Color(0xFF765B50),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: dims.scaleSpace(18)),
          Divider(color: isDark ? colors.border : const Color(0xFFF3D8C9)),
          SizedBox(height: dims.scaleSpace(12)),
          for (final feature in features) ...[
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: dims.scaleText(14),
                  color: const Color(0xFFFF6B2F),
                ),
                SizedBox(width: dims.scaleWidth(12)),
                Expanded(
                  child: Text(
                    feature,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: dims.scaleText(15.5),
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? colors.textPrimary : const Color(0xFF10232B),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: dims.scaleSpace(10)),
          ],
        ],
      ),
    );
  }
}

class _PaymentSuccessInfoTile extends StatelessWidget {
  const _PaymentSuccessInfoTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.trailingIcon,
  });

  final IconData icon;
  final String title;
  final String body;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    final colors = context.phora.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(dims.scaleWidth(18)),
      decoration: BoxDecoration(
        color: isDark ? colors.bgElevated : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(dims.scaleRadius(18)),
        border: Border.all(
          color: isDark ? colors.border : const Color(0xFFF4D8C9),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: dims.scaleWidth(58),
            height: dims.scaleWidth(58),
            decoration: BoxDecoration(
              color: isDark ? colors.bg : const Color(0xFFFFF5EF),
              borderRadius: BorderRadius.circular(dims.scaleRadius(16)),
            ),
            child: Icon(icon, color: const Color(0xFFFF4D76), size: 20),
          ),
          SizedBox(width: dims.scaleWidth(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: dims.scaleText(12.5),
                    fontWeight: FontWeight.w800,
                    color:
                        isDark ? colors.textPrimary : const Color(0xFF10232B),
                  ),
                ),
                SizedBox(height: dims.scaleSpace(4)),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: dims.scaleText(11),
                    height: 1.35,
                    color:
                        isDark ? colors.textSecondary : const Color(0xFF765B50),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: dims.scaleWidth(8)),
          Icon(trailingIcon, color: const Color(0xFFFF6B2F), size: 16),
        ],
      ),
    );
  }
}

class BillingCancelScreen extends StatelessWidget {
  const BillingCancelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.subscriptionCheckoutCanceledTitle),
      ),
      body: Padding(
        padding: EdgeInsets.all(dims.scaleWidth(24)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.subscriptionCheckoutCanceledBody,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: dims.scaleSpace(16)),
              FilledButton(
                onPressed: () => context.go('/subscription'),
                child: Text(context.l10n.subscriptionBackToPlans),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionStateScaffold extends StatelessWidget {
  const _SubscriptionStateScaffold({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final dims = context.dims;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: EdgeInsets.all(dims.scaleWidth(24)),
        child: Text(
          body,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontSize: dims.scaleText(16)),
        ),
      ),
    );
  }
}

WearableOrder? _activeWearableOrder(List<WearableOrder>? orders) {
  if (orders == null || orders.isEmpty) {
    return null;
  }
  WearableOrder? latestCompleted;
  for (final order in orders) {
    final status = order.fulfillmentStatus.toLowerCase();
    if (status == 'cancelled' || status == 'canceled') {
      continue;
    }
    if (status != 'delivered') {
      return order;
    }
    latestCompleted ??= order;
  }
  return latestCompleted;
}

String _wearableOrderStatusLabel(String status) {
  final normalized = status.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) {
    return 'In progress';
  }
  return normalized
      .split(RegExp(r'\s+'))
      .map(
        (word) =>
            word.isEmpty
                ? word
                : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}
