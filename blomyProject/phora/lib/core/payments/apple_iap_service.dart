import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

const kAppleProductMonthly = 'com.vyla.health.premium.monthly';
const kAppleProductAnnual = 'com.vyla.health.premium.annual';
const _kProductIds = {kAppleProductMonthly, kAppleProductAnnual};

class AppleIAPCanceledException implements Exception {
  const AppleIAPCanceledException();
}

class AppleIAPService {
  AppleIAPService._();
  static final AppleIAPService instance = AppleIAPService._();

  List<ProductDetails> _products = [];
  StreamSubscription<List<PurchaseDetails>>? _sub;
  Completer<PurchaseDetails>? _pending;
  Future<void>? _initializing;
  bool _available = false;

  Future<void> initialize() {
    if (!Platform.isIOS) return Future<void>.value();
    return _initializing ??= _initialize();
  }

  Future<void> ensureInitialized() => initialize();

  Future<void> _initialize() async {
    try {
      _sub ??= InAppPurchase.instance.purchaseStream.listen(
        _onPurchaseUpdates,
        onError: (Object error) {
          _pending?.completeError(error);
          _pending = null;
        },
      );
      _available = await InAppPurchase.instance.isAvailable();
      if (_available) {
        await _loadProducts();
      }
    } on PlatformException {
      _available = false;
      await _sub?.cancel();
      _sub = null;
    } catch (_) {
      _available = false;
      await _sub?.cancel();
      _sub = null;
    }
  }

  Future<void> _loadProducts() async {
    if (!_available) return;
    final response = await InAppPurchase.instance.queryProductDetails(
      _kProductIds,
    );
    _products = response.productDetails;
  }

  Future<void> refreshProducts() async {
    await ensureInitialized();
    await _loadProducts();
  }

  List<ProductDetails> get products => List.unmodifiable(_products);

  ProductDetails? productForInterval(String interval) {
    final id =
        interval == 'year' ? kAppleProductAnnual : kAppleProductMonthly;
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<PurchaseDetails> purchase(ProductDetails product) async {
    await ensureInitialized();
    if (!_available || _sub == null) {
      throw StateError('App Store purchases are not available.');
    }
    if (_pending != null && !_pending!.isCompleted) {
      return _pending!.future;
    }
    _pending = Completer<PurchaseDetails>();
    InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    return _pending!.future;
  }

  Future<void> restorePurchases() async {
    await ensureInitialized();
    if (!_available || _sub == null) {
      throw StateError('App Store purchases are not available.');
    }
    return InAppPurchase.instance.restorePurchases();
  }

  void _onPurchaseUpdates(List<PurchaseDetails> updates) {
    for (final purchase in updates) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.pendingCompletePurchase) {
            InAppPurchase.instance.completePurchase(purchase);
          }
          _pending?.complete(purchase);
          _pending = null;
        case PurchaseStatus.error:
          _pending?.completeError(
            purchase.error ?? Exception('Purchase failed'),
          );
          _pending = null;
        case PurchaseStatus.canceled:
          _pending?.completeError(const AppleIAPCanceledException());
          _pending = null;
        case PurchaseStatus.pending:
          break;
      }
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
