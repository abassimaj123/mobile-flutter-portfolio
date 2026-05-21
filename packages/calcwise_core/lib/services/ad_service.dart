import 'dart:async';
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'freemium_service.dart';
import 'analytics_service.dart';
import 'review_service.dart';

/// Per-app ad unit IDs.  Create one instance and pass it to [CalcwiseAdService].
///
/// ```dart
/// const adConfig = CalcwiseAdConfig(
///   bannerAndroid:       'ca-app-pub-xxx/yyy',
///   interstitialAndroid: 'ca-app-pub-xxx/zzz',
///   rewardedAndroid:     'ca-app-pub-xxx/www',
/// );
/// ```
class CalcwiseAdConfig {
  const CalcwiseAdConfig({
    required this.bannerAndroid,
    required this.interstitialAndroid,
    required this.rewardedAndroid,
    // iOS IDs are optional — most portfolio apps are Android-only
    this.banneriOS,
    this.interstitialiOS,
    this.rewardediOS,
    this.calcThreshold    = 3,
    this.cooldownMinutes  = 5,
  });

  final String  bannerAndroid;
  final String  interstitialAndroid;
  final String  rewardedAndroid;
  final String? banneriOS;
  final String? interstitialiOS;
  final String? rewardediOS;

  /// How many user actions before an interstitial is shown.
  final int calcThreshold;
  /// Minimum minutes between two interstitials.
  final int cooldownMinutes;

  String get bannerUnit      => Platform.isIOS && banneriOS       != null ? banneriOS!       : bannerAndroid;
  String get interstitialUnit=> Platform.isIOS && interstitialiOS != null ? interstitialiOS! : interstitialAndroid;
  String get rewardedUnit    => Platform.isIOS && rewardediOS     != null ? rewardediOS!     : rewardedAndroid;

  // ── Test IDs (use during development) ─────────────────────────────────────
  static const test = CalcwiseAdConfig(
    bannerAndroid:       'ca-app-pub-3940256099942544/6300978111',
    interstitialAndroid: 'ca-app-pub-3940256099942544/1033173712',
    rewardedAndroid:     'ca-app-pub-3940256099942544/5224354917',
  );
}

/// Shared AdMob service — banner loading, interstitial throttle, rewarded flow.
///
/// Usage:
/// ```dart
/// final adService = CalcwiseAdService(
///   config:    adConfig,
///   freemium:  freemiumService,
///   analytics: analytics,
/// );
/// await adService.initialize();
/// ```
class CalcwiseAdService {
  CalcwiseAdService({
    required this.config,
    required this.freemium,
    required this.analytics,
  });

  final CalcwiseAdConfig  config;
  final CalcwiseFreemium  freemium;
  final CalcwiseAnalytics analytics;

  InterstitialAd? _inter;
  RewardedAd?     _rewarded;
  int             _actionCount   = 0;
  DateTime?       _lastInterTime;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadInter();
    _loadRewarded();
  }

  // ── Banner ────────────────────────────────────────────────────────────────

  /// Banner ad unit ID — pass directly to [BannerAd].
  String get bannerAdUnitId => config.bannerUnit;

  // ── Interstitial ──────────────────────────────────────────────────────────

  /// Call on every significant user action (calculation, tab switch, etc.)
  void onAction() {
    if (!freemium.showAds) return;
    _actionCount++;

    if (_lastInterTime != null) {
      final elapsed = DateTime.now().difference(_lastInterTime!).inMinutes;
      if (elapsed < config.cooldownMinutes) return;
    }
    if (_actionCount < config.calcThreshold) return;
    if (_inter == null) return;

    _actionCount   = 0;
    _lastInterTime = DateTime.now();
    _inter!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose(); _inter = null; _loadInter();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose(); _inter = null; _loadInter();
      },
    );
    _inter!.show();
  }

  @Deprecated('Use onAction() instead — onCalculation() will be removed in v2.0')
  void onCalculation() => onAction();

  /// Call when the user saves a calculation result.
  /// Combines [onAction] (interstitial throttle) + review request after threshold.
  void onSave() {
    onAction();
    CalcwiseReviewService.instance.requestAfterSave();
  }

  // ── Interstitial on-demand ────────────────────────────────────────────────

  /// Show an interstitial immediately (bypassing action threshold), then
  /// invoke [onDone] after dismissal or if no ad is available.
  /// Useful for "navigate after ad" patterns.
  void showInterstitialThen(void Function() onDone) {
    if (freemium.isPremium || freemium.isRewarded) { onDone(); return; }
    if (_inter == null) { onDone(); return; }
    _lastInterTime = DateTime.now();
    _actionCount   = 0;
    _inter!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose(); _inter = null; _loadInter(); onDone();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose(); _inter = null; _loadInter(); onDone();
      },
    );
    _inter!.show();
  }

  // ── Rewarded ──────────────────────────────────────────────────────────────

  bool get isRewardedReady =>
      _rewarded != null && freemium.canWatchRewarded();

  /// Shows rewarded ad. Returns `true` only if user fully watched it.
  Future<bool> showRewarded() async {
    if (_rewarded == null) return false;
    final completer = Completer<bool>();
    bool earned = false;

    _rewarded!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose(); _rewarded = null; _loadRewarded();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose(); _rewarded = null; _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    await _rewarded!.show(
      onUserEarnedReward: (_, __) {
        earned = true;
        analytics.logRewardedAdWatched();
      },
    );
    return completer.future;
  }

  // ── Private loaders ───────────────────────────────────────────────────────

  void _loadInter() {
    InterstitialAd.load(
      adUnitId: config.interstitialUnit,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded:       (a) => _inter = a,
        onAdFailedToLoad: (_) => _inter = null,
      ),
    );
  }

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: config.rewardedUnit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded:       (a) => _rewarded = a,
        onAdFailedToLoad: (_) {
          _rewarded = null;
          analytics.logRewardedAdFailed();
          debugPrint('[AdService] rewarded failed to load');
        },
      ),
    );
  }
}
