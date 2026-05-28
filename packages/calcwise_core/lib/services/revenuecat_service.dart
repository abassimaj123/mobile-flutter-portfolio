import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Calcwise RevenueCat service — paywall A/B experiments + purchase management.
///
/// ## Setup (one-time, per-app)
/// 1. Create account at https://www.revenuecat.com
/// 2. Add your app → get Android + iOS SDK keys
/// 3. Call from main() after Firebase.initializeApp():
///    ```dart
///    await CalcwiseRevenueCat.initialize(
///      androidKey: 'appl_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX',
///      iosKey:     'appl_YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY',
///    );
///    ```
/// 4. Create Entitlement "premium" in RC dashboard, link to your product.
/// 5. (Optional) Create Experiment in RC Dashboard → Experiments:
///    - Control: existing paywall
///    - Treatment: new variant
///    - Metric: conversion rate
///
/// ## Usage
/// ```dart
/// // Vérifier premium
/// final isPremium = await CalcwiseRevenueCat.checkPremiumStatus();
///
/// // Acheter
/// final success = await CalcwiseRevenueCat.purchaseProduct('premium_upgrade');
///
/// // Restaurer
/// await CalcwiseRevenueCat.restorePurchases();
/// ```
class CalcwiseRevenueCat {
  CalcwiseRevenueCat._();

  static bool _initialized = false;

  /// Initialize RevenueCat SDK. Call once at app startup, after Firebase.
  ///
  /// [androidKey] — Android public SDK key from RC dashboard.
  /// [iosKey]     — iOS public SDK key from RC dashboard.
  /// [appUserId]  — optional, defaults to RC anonymous ID.
  static Future<void> initialize({
    required String androidKey,
    required String iosKey,
    String? appUserId,
  }) async {
    if (_initialized) return;
    if (kDebugMode) {
      await Purchases.setLogLevel(LogLevel.debug);
    } else {
      await Purchases.setLogLevel(LogLevel.warn);
    }
    try {
      final apiKey = Platform.isAndroid ? androidKey : iosKey;
      final config = PurchasesConfiguration(apiKey)..appUserID = appUserId;
      await Purchases.configure(config);
      _initialized = true;
      debugPrint('[RevenueCat] ✓ Initialized (${Platform.isAndroid ? "Android" : "iOS"})');
    } catch (e) {
      debugPrint('[RevenueCat] Initialization failed: $e');
    }
  }

  /// Fetch the current offering assigned to this user (may be A/B variant).
  ///
  /// Returns null if RC not initialized or on error — caller falls back to
  /// default paywall.
  static Future<RcOffering?> fetchCurrentOffering() async {
    if (!_initialized) return null;
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return null;
      return RcOffering(
        identifier: current.identifier,
        packages: current.availablePackages.map((p) => RcPackage(
          identifier:  p.identifier,
          priceString: p.storeProduct.priceString,
          productId:   p.storeProduct.identifier,
        )).toList(),
      );
    } catch (e) {
      debugPrint('[RevenueCat] fetchCurrentOffering error: $e');
      return null;
    }
  }

  /// Purchase by product identifier (e.g. 'premium_upgrade').
  ///
  /// Returns true on success. Handles user cancellation gracefully.
  static Future<bool> purchaseProduct(String productId) async {
    if (!_initialized) return false;
    try {
      final offerings = await Purchases.getOfferings();
      final pkg = offerings.current?.availablePackages
          .where((p) => p.storeProduct.identifier == productId)
          .firstOrNull;
      if (pkg == null) {
        debugPrint('[RevenueCat] Product not found: $productId');
        return false;
      }
      final info = await Purchases.purchasePackage(pkg);
      return info.entitlements.active.containsKey('premium');
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('[RevenueCat] Purchase cancelled by user');
      } else {
        debugPrint('[RevenueCat] Purchase error: $e');
      }
      return false;
    } catch (e) {
      debugPrint('[RevenueCat] purchaseProduct error: $e');
      return false;
    }
  }

  /// Restore previous purchases for this user.
  ///
  /// Returns true if premium entitlement is active after restore.
  static Future<bool> restorePurchases() async {
    if (!_initialized) return false;
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey('premium');
    } catch (e) {
      debugPrint('[RevenueCat] restorePurchases error: $e');
      return false;
    }
  }

  /// Check if current user has an active premium entitlement.
  ///
  /// Call after purchase and on app resume to sync local freemium state.
  static Future<bool> checkPremiumStatus() async {
    if (!_initialized) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey('premium');
    } catch (e) {
      debugPrint('[RevenueCat] checkPremiumStatus error: $e');
      return false;
    }
  }

  /// True if SDK is initialized.
  static bool get isInitialized => _initialized;
}

// ── Data classes ─────────────────────────────────────────────────────────────

class RcOffering {
  final String identifier;
  final List<RcPackage> packages;
  const RcOffering({required this.identifier, required this.packages});
}

class RcPackage {
  final String identifier;
  final String priceString;
  final String productId;
  const RcPackage({
    required this.identifier,
    required this.priceString,
    required this.productId,
  });
}
