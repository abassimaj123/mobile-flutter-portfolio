import 'package:flutter/foundation.dart' show kReleaseMode;

/// AdMob unit IDs for JobOfferUS.
/// BEFORE RELEASE: replace XXXXXXXXXX with real unit IDs from AdMob console.
class AdConfig {
  static const adsEnabled = true;

  // Android IDs
  static const bannerAndroid = kReleaseMode
      ? 'ca-app-pub-5379540026739666/XXXXXXXXXX'
      : 'ca-app-pub-3940256099942544/6300978111'; // test
  static const interstitialAndroid = kReleaseMode
      ? 'ca-app-pub-5379540026739666/XXXXXXXXXX'
      : 'ca-app-pub-3940256099942544/1033173712'; // test
  static const rewardedAndroid = kReleaseMode
      ? 'ca-app-pub-5379540026739666/XXXXXXXXXX'
      : 'ca-app-pub-3940256099942544/5224354917'; // test

  // iOS IDs — TODO: iOS Phase 2
  static const banneriOS = kReleaseMode
      ? 'ca-app-pub-5379540026739666/XXXXXXXXXX'
      : 'ca-app-pub-3940256099942544/2934735716'; // test
  static const interstitialiOS = kReleaseMode
      ? 'ca-app-pub-5379540026739666/XXXXXXXXXX'
      : 'ca-app-pub-3940256099942544/4411468910'; // test
  static const rewardediOS = kReleaseMode
      ? 'ca-app-pub-5379540026739666/XXXXXXXXXX'
      : 'ca-app-pub-3940256099942544/1712485313'; // test

  static const calcThreshold = 3;
  static const cooldownMinutes = 5;
}
