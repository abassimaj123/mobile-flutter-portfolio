import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';


/// Base Firebase Analytics wrapper — shared across all portfolio apps.
///
/// Each app creates its own subclass to add app-specific events:
///
/// ```dart
/// class MortgageAnalytics extends CalcwiseAnalytics {
///   MortgageAnalytics() : super(appName: 'MortgageUS');
///
///   Future<void> logComparatorUsed() => log('comparator_used');
///   Future<void> logExtraPayment()   => log('extra_payment_simulated');
/// }
/// final analytics = MortgageAnalytics();
/// ```
class CalcwiseAnalytics {
  CalcwiseAnalytics({required this.appName});

  /// Short identifier included in every event — e.g. 'MortgageUS', 'JobOfferUS'.
  final String appName;

  // late: deferred until first access — avoids Firebase.initializeApp() in tests
  // (kDebugMode = true in tests, so log() returns early and _fa is never touched)
  late final _fa = FirebaseAnalytics.instance;

  /// Enable/disable analytics collection based on build mode.
  /// Sets persistent user properties so every session is filterable by app.
  Future<void> initialize() async {
    await _fa.setAnalyticsCollectionEnabled(!kDebugMode);
    if (!kDebugMode) {
      // Persistent user properties — survive across sessions.
      // Enables audience building + cross-app filtering in Firebase console.
      await _fa.setUserProperty(name: 'app_name', value: appName);
    }
  }

  // ── Universal events (same in every app) ──────────────────────────────────

  Future<void> logAppOpen()                          => log('app_open');
  Future<void> logCalculate()                        => log('calculate');
  Future<void> logTabChanged(String tabName)         => log('tab_changed', {'tab': tabName});
  Future<void> logHistorySaved()                     => log('history_saved');
  Future<void> logHistoryViewed()                    => log('history_viewed');
  Future<void> logShareText()                        => log('share_text');
  Future<void> logLanguageChanged(String lang)       => log('language_changed', {'language': lang});
  Future<void> logPdfExported()                      => log('pdf_exported');

  // ── Paywall / monetisation ────────────────────────────────────────────────

  Future<void> logPaywallShown(String type)    => log('paywall_shown',     {'type': type});
  Future<void> logPaywallDismissed()           => log('paywall_dismissed');
  Future<void> logPurchaseStarted()            => log('purchase_started');
  Future<void> logPurchaseFailed()             => log('purchase_failed');
  Future<void> logPurchaseRestored()           => log('purchase_restored');

  Future<void> logPurchaseCompleted() async {
    await log('purchase_completed');
    await _fa.logEvent(name: 'purchase', parameters: {
      'currency': 'USD', 'app': appName,
    });
  }

  // ── Ads ───────────────────────────────────────────────────────────────────

  Future<void> logRewardedAdWatched()     => log('rewarded_ad_watched');
  Future<void> logRewardedAdFailed()      => log('rewarded_ad_failed');
  Future<void> logRewardedDailyLimit()    => log('rewarded_daily_limit_reached');
  Future<void> logBannerFailed()          => log('banner_ad_failed');

  // ── User property ─────────────────────────────────────────────────────────

  Future<void> setUserPremium(bool isPremium) =>
      _fa.setUserProperty(
        name:  'is_premium',
        value: isPremium ? 'true' : 'false',
      );

  // ── Protected helper for subclasses ──────────────────────────────────────

  Future<void> log(String name, [Map<String, Object>? params]) async {
    if (kDebugMode) {
      debugPrint('[$appName/Analytics] $name ${params ?? ''}');
      return;
    }
    await _fa.logEvent(
      name: name,
      parameters: {'app_name': appName, ...?params},
    );
  }
}
