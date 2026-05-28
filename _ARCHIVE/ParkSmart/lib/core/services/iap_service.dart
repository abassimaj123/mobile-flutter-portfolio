/// IAP service — re-exports CalcwiseIAP from library with app-specific configuration.
library;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:calcwise_core/calcwise_core.dart';
import 'freemium_service.dart';

export 'package:calcwise_core/services/iap_service.dart' show iapErrorNotifier;

class IAPService {
  IAPService._();
  static final instance = IAPService._();

  static const productId = 'premium_upgrade';

  late final CalcwiseIAP _iap;

  ValueNotifier<String?> get localizedPrice => _iap.localizedPrice;

  Future<void> initialize() async {
    _iap = CalcwiseIAP(
      productId: productId,
      freemium: freemiumService,
      analytics: CalcwiseAnalytics(appName: 'parksmart'),
    );
    await _iap.initialize();
  }

  Future<void> buy() => _iap.buy();
  Future<void> restore() => _iap.restore();
  void dispose() => _iap.dispose();
}
