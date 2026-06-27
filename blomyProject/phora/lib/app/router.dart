import 'package:phora/app/env.dart';
import 'package:phora/core/auth/auth_providers.dart';
import 'package:phora/features/auth/domain/app_session.dart';
import 'package:phora/core/i18n/locale_controller.dart';
import 'package:phora/core/ui/paywall_helpers.dart';
import 'package:phora/features/auth/presentation/auth_screens.dart';
import 'package:phora/features/bloom/presentation/bloom_screen.dart';
import 'package:phora/features/calendar/presentation/calendar_screen.dart';
import 'package:phora/features/home/presentation/app_shell.dart';
import 'package:phora/features/home/presentation/today_screen.dart';
import 'package:phora/features/insights/presentation/insights_screen.dart';
import 'package:phora/features/growth/presentation/compare_friends_screen.dart';
import 'package:phora/features/growth/presentation/invite_earn_screen.dart';
import 'package:phora/features/growth/presentation/share_insight_screen.dart';
import 'package:phora/features/log/presentation/cervical_mucus_screen.dart';
import 'package:phora/features/log/presentation/intimacy_screen.dart';
import 'package:phora/features/log/presentation/lh_test_screen.dart';
import 'package:phora/features/log/presentation/log_screen.dart';
import 'package:phora/features/log/presentation/symptoms_screen.dart';
import 'package:phora/features/log/presentation/temperature_screen.dart';
import 'package:phora/features/log/presentation/today_log_details_screen.dart';
import 'package:phora/features/language/presentation/language_selection_screen.dart';
import 'package:phora/features/onboarding/presentation/onboarding_screen.dart';
import 'package:phora/features/onboarding/domain/onboarding_status.dart';
import 'package:phora/features/profile/presentation/profile_screen.dart';
import 'package:phora/features/profile/presentation/connected_devices_screen.dart';
import 'package:phora/features/profile/presentation/change_password_screen.dart';
import 'package:phora/features/profile/presentation/edit_profile_screen.dart';
import 'package:phora/features/profile/presentation/export_data_screen.dart';
import 'package:phora/features/profile/presentation/health_data_screen.dart';
import 'package:phora/core/i18n/l10n_extensions.dart';
import 'package:phora/features/profile/presentation/legal_web_screen.dart';
import 'package:phora/features/profile/presentation/manage_notifications_screen.dart';
import 'package:phora/features/profile/presentation/notifications_screen.dart';
import 'package:phora/features/stress/presentation/stress_screen.dart';
import 'package:phora/features/subscription/presentation/paywall_screen.dart';
import 'package:phora/features/subscription/presentation/subscription_screens.dart';
import 'package:phora/features/subscription/domain/subscription_models.dart';
import 'package:phora/features/wearables/domain/wearable_order_models.dart';
import 'package:phora/features/wearables/presentation/wearable_addon_screen.dart';
import 'package:phora/features/wearables/presentation/wearable_checkout_screen.dart';
import 'package:phora/features/wearables/presentation/wearable_delivered_screen.dart';
import 'package:phora/features/wearables/presentation/wearable_order_confirmed_screen.dart';
import 'package:phora/features/wearables/presentation/wearable_order_screen.dart';
import 'package:phora/features/wearables/presentation/wearable_tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = RouterRefreshListenable(ref);
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: kPreviewOnboarding ? '/onboarding' : '/today',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      bool needsInitialLoad<T>(AsyncValue<T> value) {
        return value.isLoading && value.valueOrNull == null;
      }

      final onboardingSeen = ref.read(onboardingSeenProvider);
      final localeState = ref.read(localeControllerProvider);
      final authSession = ref.read(authSessionProvider);
      final onboardingStatus = ref.read(onboardingStatusProvider);
      final subscriptionState = ref.read(currentSubscriptionProvider);
      final freePlanSelected = ref.read(freePlanSelectionProvider);
      final location = state.matchedLocation;
      const publicRoutes = {
        '/language',
        '/login',
        '/sign-in',
        '/verify-email',
        '/forgot-password',
        '/forgot-password/verify',
        '/forgot-password/reset',
        '/sign-up',
      };
      final isPublic = publicRoutes.contains(location);
      final isLanguageSettings = location == '/you/language';
      const paymentReturnRoutes = {
        '/billing/success',
        '/success',
        '/billing/cancel',
        '/cancel',
      };
      final isPaymentReturnRoute = paymentReturnRoutes.contains(location);
      final isOnboarding = location == '/onboarding';
      final isSplash = location == '/splash';
      final isPostSignupSetup = location == '/post-signup-setup';
      final isLastCycleLog = location == '/onboarding/last-cycle';
      if (location == '/sign-in') {
        debugPrint(
          '[AuthNav] router location=$location '
          'onboardingSeen=${onboardingSeen.valueOrNull} '
          'localeReady=${localeState.valueOrNull != null} '
          'authLoading=${authSession.isLoading} '
          'auth=${authSession.valueOrNull?.isAuthenticated}',
        );
      }

      if (needsInitialLoad(onboardingSeen) ||
          needsInitialLoad(localeState) ||
          needsInitialLoad(authSession) ||
          needsInitialLoad(freePlanSelected)) {
        if (location == '/sign-in') {
          debugPrint(
            '[AuthNav] redirecting $location -> /splash while loading',
          );
        }
        return (isSplash ||
                isPaymentReturnRoute ||
                location == '/language' ||
                location == '/today')
            ? null
            : '/splash';
      }

      final hasCompletedLanguageSelection =
          localeState.valueOrNull?.hasCompletedLanguageSelection ?? false;
      if (!hasCompletedLanguageSelection) {
        if (location == '/sign-in') {
          debugPrint('[AuthNav] redirecting $location -> /language');
        }
        return location == '/language' ? null : '/language';
      }

      if (kPreviewOnboarding) {
        return state.matchedLocation == '/onboarding' ? null : '/onboarding';
      }

      final hasSeenOnboarding = onboardingSeen.valueOrNull ?? false;
      if (!hasSeenOnboarding) {
        if (location == '/sign-in') {
          debugPrint(
            '[AuthNav] allowing public auth route before onboarding completion',
          );
        }
        return (isOnboarding || isPublic || isPostSignupSetup || isLastCycleLog)
            ? null
            : '/onboarding';
      }

      final session = authSession.valueOrNull;
      final isAuthenticated = session?.isAuthenticated ?? false;
      final onboardingState = onboardingStatus.valueOrNull;
      final onboardingStep = onboardingState?.currentStep;
      final backendShowsOnboarding = session?.showOnboardingFlow ?? false;
      final requiresPostSignupSetup =
          isAuthenticated &&
          (onboardingStep == 'post_signup_setup' ||
              (backendShowsOnboarding &&
                  !(onboardingState?.isComplete ?? false)));
      final requiresLastCycleLog = onboardingStep == 'last_cycle_log';
      final subscription =
          subscriptionState.valueOrNull ?? SubscriptionState.free();
      final backendTier = session?.subscriptionTier?.trim().toLowerCase();
      final backendSelectedFreePlan =
          (session?.subscriptionSelected ?? false) && backendTier == 'free';
      final backendRequiresSubscriptionChoice =
          (session?.showSubscriptionScreen ?? false) &&
          !(session?.subscriptionSelected ?? false) &&
          !subscription.planSaved &&
          !subscription.hasPaidAccess;
      final allowsFreeAccess =
          (freePlanSelected.valueOrNull ?? false) ||
          (subscription.planSaved &&
              subscription.tier == SubscriptionTier.free) ||
          backendSelectedFreePlan;
      final backendHasPaidAccess =
          (session?.subscriptionActive ?? false) && backendTier != 'free';
      final paymentSuccessGraceUntil = ref.read(
        paymentSuccessGraceUntilProvider,
      );
      final paymentSuccessGraceActive =
          paymentSuccessGraceUntil != null &&
          paymentSuccessGraceUntil.isAfter(DateTime.now());
      final hasRequiredSubscription =
          !isAuthenticated ||
          allowsFreeAccess ||
          subscription.hasPaidAccess ||
          backendHasPaidAccess ||
          paymentSuccessGraceActive;
      final shouldShowSubscription =
          isAuthenticated &&
          !requiresPostSignupSetup &&
          !requiresLastCycleLog &&
          !paymentSuccessGraceActive &&
          ((session?.showSubscriptionScreen ?? false) ||
              backendRequiresSubscriptionChoice) &&
          !allowsFreeAccess &&
          !subscription.planSaved &&
          !subscription.hasPaidAccess &&
          !backendHasPaidAccess;

      if (isSplash) {
        if (!isAuthenticated) {
          return '/sign-in';
        }
        if (requiresPostSignupSetup) {
          return '/post-signup-setup';
        }
        if (requiresLastCycleLog) {
          return '/onboarding/last-cycle';
        }
        return shouldShowSubscription ? '/subscription' : '/today';
      }

      if (!isAuthenticated) {
        if (isPublic) {
          if (location == '/sign-in') {
            debugPrint(
              '[AuthNav] allowing unauthenticated public route $location',
            );
          }
          return null;
        }
        return '/sign-in';
      }

      if (requiresPostSignupSetup && !isPostSignupSetup) {
        return '/post-signup-setup';
      }

      if (requiresLastCycleLog && !isLastCycleLog) {
        return '/onboarding/last-cycle';
      }

      if (!requiresPostSignupSetup &&
          !requiresLastCycleLog &&
          isPostSignupSetup) {
        return hasRequiredSubscription ? '/today' : '/subscription';
      }

      if (!requiresLastCycleLog && isLastCycleLog) {
        return hasRequiredSubscription ? '/today' : '/subscription';
      }

      if (location == '/today') {
        return null;
      }

      if (isPublic) {
        if (requiresPostSignupSetup) {
          return '/post-signup-setup';
        }
        if (location == '/sign-in') {
          debugPrint(
            '[AuthNav] authenticated public route -> ${shouldShowSubscription ? '/subscription' : '/today'}',
          );
        }
        return shouldShowSubscription ? '/subscription' : '/today';
      }

      if (isLanguageSettings) {
        return null;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/language',
        builder:
            (context, state) =>
                const LanguageSelectionScreen(settingsMode: false),
      ),
      GoRoute(path: '/login', redirect: (context, state) => '/sign-in'),
      GoRoute(path: '/dashboard', redirect: (context, state) => '/today'),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder:
            (context, state) => VerifyEmailScreen(
              email: state.uri.queryParameters['email'] ?? '',
            ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder:
            (context, state) => ForgotPasswordScreen(
              initialEmail: state.uri.queryParameters['email'] ?? '',
            ),
      ),
      GoRoute(
        path: '/forgot-password/verify',
        builder:
            (context, state) => ForgotPasswordVerifyScreen(
              email: state.uri.queryParameters['email'] ?? '',
            ),
      ),
      GoRoute(
        path: '/forgot-password/reset',
        builder:
            (context, state) => ResetPasswordScreen(
              email: state.uri.queryParameters['email'] ?? '',
            ),
      ),
      GoRoute(
        path: '/sign-up',
        builder:
            (context, state) => SignUpScreen(
              initialEmail: state.uri.queryParameters['email'],
              initialReferralCode: state.uri.queryParameters['ref'],
              referralSource: state.uri.queryParameters['source'],
              referralDeepLinkId: state.uri.queryParameters['dl'],
            ),
      ),
      GoRoute(
        path: '/post-signup-setup',
        builder: (context, state) => const PostSignupSetupScreen(),
      ),
      GoRoute(
        path: '/onboarding/last-cycle',
        builder: (context, state) => const LastCycleLogScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/today',
            builder: (context, state) => const TodayScreen(),
          ),
          GoRoute(
            path: '/cycle',
            builder: (context, state) => const CycleScreen(),
          ),
          GoRoute(
            path: '/log',
            builder: (context, state) => const TodayLogDetailsScreen(),
          ),
          GoRoute(
            path: '/log/manual',
            builder: (context, state) => const LogScreen(),
          ),
          GoRoute(
            path: '/log/cervical-mucus',
            builder: (context, state) => const CervicalMucusScreen(),
          ),
          GoRoute(
            path: '/log/intimacy',
            builder: (context, state) => const IntimacyScreen(),
          ),
          GoRoute(
            path: '/log/lh-test',
            builder: (context, state) => const LhTestScreen(),
          ),
          GoRoute(
            path: '/log/period',
            redirect: (context, state) => '/log?section=period',
          ),
          GoRoute(
            path: '/log/temperature',
            builder: (context, state) => const TemperatureScreen(),
          ),
          GoRoute(
            path: '/log/symptoms',
            builder: (context, state) => const SymptomsScreen(),
          ),
          GoRoute(
            path: '/bloom',
            builder: (context, state) => const BloomScreen(),
          ),
          GoRoute(
            path: '/insights',
            builder: (context, state) => const InsightsScreen(),
          ),
          GoRoute(path: '/you', builder: (context, state) => const YouScreen()),
          GoRoute(
            path: '/you/edit-profile',
            builder: (context, state) => const EditProfileScreen(),
          ),
          GoRoute(
            path: '/you/change-password',
            builder: (context, state) => const ChangePasswordScreen(),
          ),
          GoRoute(
            path: '/you/health-data',
            builder: (context, state) => const HealthDataScreen(),
          ),
          GoRoute(
            path: '/you/connected-devices',
            builder: (context, state) => const ConnectedDevicesScreen(),
          ),
          GoRoute(
            path: '/you/manage-subscription',
            builder: (context, state) => const SubscriptionScreen(),
          ),
          GoRoute(
            path: '/you/manage-notifications',
            builder: (context, state) => const ManageNotificationsScreen(),
          ),
          GoRoute(
            path: '/you/language',
            builder:
                (context, state) =>
                    const LanguageSelectionScreen(settingsMode: true),
          ),
          GoRoute(
            path: '/you/export-data',
            builder: (context, state) => const ExportDataScreen(),
          ),
          GoRoute(
            path: '/you/privacy-policy',
            builder:
                (context, state) => LegalWebScreen(
                  title: context.l10n.privacyPolicyLabel,
                  url: 'https://vyla.health/privacy',
                ),
          ),
          GoRoute(
            path: '/you/terms',
            builder:
                (context, state) => LegalWebScreen(
                  title: context.l10n.termsOfServiceLabel,
                  url: 'https://vyla.health/terms',
                ),
          ),
          GoRoute(
            path: '/blog',
            builder: (context, state) {
              final slug = state.uri.queryParameters['post'];
              final url =
                  slug != null && slug.isNotEmpty
                      ? 'https://vyla.health/blog?post=${Uri.encodeComponent(slug)}'
                      : 'https://vyla.health/blog';
              return LegalWebScreen(title: 'Blog', url: url);
            },
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/stress',
            builder: (context, state) => const StressScreen(),
          ),
          GoRoute(
            path: '/growth/share',
            builder: (context, state) => const ShareInsightScreen(),
          ),
          GoRoute(
            path: '/growth/compare',
            builder: (context, state) => const CompareFriendsScreen(),
          ),
          GoRoute(
            path: '/growth/compare/:friendId',
            builder:
                (context, state) => FriendComparisonDetailScreen(
                  friendId: state.pathParameters['friendId'] ?? '',
                ),
          ),
          GoRoute(
            path: '/growth/invite',
            builder: (context, state) => const InviteEarnScreen(),
          ),
          GoRoute(
            path: '/wearable/orders/:orderId',
            builder:
                (context, state) => WearableOrderDetailScreen(
                  orderId: state.pathParameters['orderId'] ?? '',
                  initialOrder: state.extra as WearableOrder?,
                ),
          ),
          GoRoute(
            path: '/wearable/orders/:orderId/tracking',
            builder:
                (context, state) => WearableTrackingScreen(
                  orderId: state.pathParameters['orderId'] ?? '',
                  initialOrder: state.extra as WearableOrder?,
                ),
          ),
          GoRoute(
            path: '/wearable/orders/:orderId/delivered',
            builder:
                (context, state) => WearableDeliveredScreen(
                  orderId: state.pathParameters['orderId'] ?? '',
                  initialOrder: state.extra as WearableOrder?,
                ),
          ),
        ],
      ),
      GoRoute(
        path: '/subscription',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/wearable/addon',
        builder: (context, state) {
          final params =
              state.extra is Map
                  ? Map<String, dynamic>.from(state.extra as Map)
                  : <String, dynamic>{};
          return WearableAddonScreen(
            country: _stringExtra(params, 'country') ?? 'GB',
            planId: _stringExtra(params, 'planId') ?? '',
            interval: _stringExtra(params, 'interval') ?? 'month',
            planName:
                _stringExtra(params, 'planDisplayName') ??
                _stringExtra(params, 'planName'),
            planDisplayPrice: _stringExtra(params, 'planDisplayPrice'),
            planCadence: _stringExtra(params, 'planCadence'),
            standalone: _boolExtra(params, 'standalone'),
          );
        },
      ),
      GoRoute(
        path: '/wearable/buy',
        builder:
            (context, state) => const WearableAddonScreen(
              country: 'GB',
              planId: '',
              interval: 'one_time',
              standalone: true,
            ),
      ),
      GoRoute(
        path: '/wearable/checkout',
        redirect:
            (context, state) =>
                state.extra is WearableCheckoutArgs
                    ? null
                    : '/wearable/order-confirmed',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! WearableCheckoutArgs) {
            return const WearableOrderConfirmedScreen();
          }
          return WearableCheckoutScreen(args: extra);
        },
      ),
      GoRoute(
        path: '/wearable/order-confirmed',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is WearableOrderConfirmedArgs) {
            return WearableOrderConfirmedScreen(
              session: extra.session,
              order: extra.order,
            );
          }
          return WearableOrderConfirmedScreen(
            session: extra is WearableCheckoutSession ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/billing/success',
        builder:
            (context, state) => BillingSuccessScreen(
              sessionId: state.uri.queryParameters['session_id'],
              providerSubscriptionId:
                  state.uri.queryParameters['provider_subscription_id'] ??
                  state.uri.queryParameters['subscription_id'],
            ),
      ),
      GoRoute(
        path: '/success',
        redirect:
            (context, state) =>
                '/billing/success${state.uri.hasQuery ? '?${state.uri.query}' : ''}',
      ),
      GoRoute(
        path: '/billing/cancel',
        builder: (context, state) => const BillingCancelScreen(),
      ),
      GoRoute(
        path: '/cancel',
        redirect:
            (context, state) =>
                '/billing/cancel${state.uri.hasQuery ? '?${state.uri.query}' : ''}',
      ),
      GoRoute(
        path: '/subscription/trial',
        builder: (context, state) => const TrialEndScreen(),
      ),
      GoRoute(
        path: '/subscription/payment-failure',
        builder: (context, state) => const PaymentFailureScreen(),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) {
          final reason = state.uri.queryParameters['reason'];
          return PaywallScreen(reason: PaywallReasonParser.parse(reason));
        },
      ),
    ],
  );
});

class RouterRefreshListenable extends ChangeNotifier {
  RouterRefreshListenable(this.ref) {
    _subscriptions = [
      ref.listen<AsyncValue<bool>>(onboardingSeenProvider, (_, __) {
        notifyListeners();
      }),
      ref.listen<AsyncValue<LocaleState>>(localeControllerProvider, (_, __) {
        notifyListeners();
      }),
      ref.listen<AsyncValue<AppSession?>>(authSessionProvider, (_, __) {
        notifyListeners();
      }),
      ref.listen<AsyncValue<OnboardingStatus>>(onboardingStatusProvider, (
        _,
        __,
      ) {
        notifyListeners();
      }),
      ref.listen<AsyncValue<SubscriptionState>>(currentSubscriptionProvider, (
        _,
        __,
      ) {
        notifyListeners();
      }),
      ref.listen<AsyncValue<bool>>(freePlanSelectionProvider, (_, __) {
        notifyListeners();
      }),
    ];
  }

  final Ref ref;
  late final List<ProviderSubscription<dynamic>> _subscriptions;

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.close();
    }
    super.dispose();
  }
}

String? _stringExtra(Map<String, dynamic> params, String key) {
  final value = params[key];
  if (value == null) return null;
  return value.toString();
}

bool _boolExtra(Map<String, dynamic> params, String key) {
  final value = params[key];
  if (value is bool) return value;
  return value?.toString().toLowerCase() == 'true';
}
