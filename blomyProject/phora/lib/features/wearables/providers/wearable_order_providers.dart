import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phora/core/api/api_client.dart';
import 'package:phora/features/wearables/data/wearable_order_repository.dart';
import 'package:phora/features/wearables/domain/wearable_order_models.dart';

final wearableOrderRepositoryProvider = Provider<WearableOrderRepository>((
  ref,
) {
  return WearableOrderRepository(ref.watch(apiClientProvider));
});

final wearableAvailabilityProvider =
    FutureProvider.autoDispose.family<WearableAvailability, String>((
      ref,
      country,
    ) {
      return ref
          .watch(wearableOrderRepositoryProvider)
          .checkAvailability(country: country);
    });

final myWearableOrdersProvider =
    FutureProvider.autoDispose<List<WearableOrder>>((ref) {
      return ref.watch(wearableOrderRepositoryProvider).getMyOrders();
    });

final wearableOrderProvider = FutureProvider.autoDispose
    .family<WearableOrder, String>((ref, orderId) {
      return ref.watch(wearableOrderRepositoryProvider).getOrder(orderId);
    });

final wearableOrderTrackingProvider = FutureProvider.autoDispose
    .family<WearableOrder, String>((ref, orderId) {
      return ref
          .watch(wearableOrderRepositoryProvider)
          .getOrderTracking(orderId);
    });

// ── Checkout state ─────────────────────────────────────────────────────────────

class WearableCheckoutInput {
  const WearableCheckoutInput({
    required this.country,
    required this.planId,
    required this.interval,
    required this.wearableSku,
    required this.shippingAddress,
    this.standalone = false,
  });

  final String country;
  final String planId;
  final String interval;
  final String wearableSku;
  final ShippingAddress shippingAddress;
  final bool standalone;
}

class WearableCheckoutState {
  const WearableCheckoutState({
    this.isLoading = false,
    this.session,
    this.error,
  });

  final bool isLoading;
  final WearableCheckoutSession? session;
  final String? error;

  WearableCheckoutState copyWith({
    bool? isLoading,
    WearableCheckoutSession? session,
    String? error,
  }) => WearableCheckoutState(
    isLoading: isLoading ?? this.isLoading,
    session: session ?? this.session,
    error: error ?? this.error,
  );
}

class WearableCheckoutNotifier
    extends AutoDisposeNotifier<WearableCheckoutState> {
  @override
  WearableCheckoutState build() => const WearableCheckoutState();

  Future<WearableCheckoutSession?> createCheckout(
    WearableCheckoutInput input,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(wearableOrderRepositoryProvider);
      final session = await repo.createAddonCheckout(
        country: input.country,
        planId: input.planId,
        interval: input.interval,
        wearableSku: input.wearableSku,
        shippingAddress: input.shippingAddress,
        standalone: input.standalone,
      );
      state = state.copyWith(isLoading: false, session: session);
      return session;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  void reset() => state = const WearableCheckoutState();
}

final wearableCheckoutProvider = AutoDisposeNotifierProvider<
  WearableCheckoutNotifier,
  WearableCheckoutState
>(WearableCheckoutNotifier.new);
