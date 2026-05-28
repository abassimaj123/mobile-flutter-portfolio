import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config.dart';
import '../services/freemium_service.dart';

class AdService {
  static final instance = AdService._();
  AdService._();

  InterstitialAd? _inter;
  RewardedAd? _rewarded;

  int _actionCount = 0;
  DateTime? _lastInterTime;

  static String get bannerId =>
      Platform.isIOS ? AdConfig.banneriOS : AdConfig.bannerAndroid;

  Future<void> initialize() async {
    if (!AdConfig.adsEnabled) return;
    await MobileAds.instance.initialize();
    _loadInter();
    _loadRewarded();
  }

  void _loadInter() {
    final id = Platform.isIOS
        ? AdConfig.interstitialiOS
        : AdConfig.interstitialAndroid;
    InterstitialAd.load(
      adUnitId: id,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (a) => _inter = a,
        onAdFailedToLoad: (_) => _inter = null,
      ),
    );
  }

  void _loadRewarded() {
    final id = Platform.isIOS ? AdConfig.rewardediOS : AdConfig.rewardedAndroid;
    RewardedAd.load(
      adUnitId: id,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (a) => _rewarded = a,
        onAdFailedToLoad: (_) => _rewarded = null,
      ),
    );
  }

  Future<void> showInterstitial() async {
    if (!AdConfig.adsEnabled || _inter == null) return;

    final now = DateTime.now();
    if (_lastInterTime != null &&
        now.difference(_lastInterTime!).inSeconds < 300) {
      return; // 5-min cooldown
    }

    _inter!.show();
    _lastInterTime = now;
    _inter = null;
    _loadInter();
  }

  Future<void> showRewarded(VoidCallback onRewarded) async {
    if (!AdConfig.adsEnabled || _rewarded == null) return;

    _rewarded!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        _rewarded = null;
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (_, __) {
        _rewarded = null;
        _loadRewarded();
      },
    );

    _rewarded!.show(onUserEarnedReward: (_, __) {
      onRewarded();
      freemiumService.activateRewarded();
    });
  }

  void trackAction() {
    _actionCount++;
    if (_actionCount % 8 == 0 && _actionCount > 0) {
      showInterstitial();
    }
  }

  void reset() {
    _actionCount = 0;
    _lastInterTime = null;
  }
}
