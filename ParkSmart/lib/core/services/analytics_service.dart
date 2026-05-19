import 'package:calcwise_core/calcwise_core.dart';

/// Firebase Analytics wrapper for ParkSmart.
/// Common events inherited from CalcwiseAnalytics.
/// ParkSmart-specific events (map, session, parking calc, cross promo) kept here.
class AnalyticsService extends CalcwiseAnalytics {
  AnalyticsService._() : super(appName: 'ParkSmart');
  static final AnalyticsService instance = AnalyticsService._();

  // ── Map & Navigation ──────────────────────────────────────────────────────

  Future<void> logMapLoaded() => log('map_loaded');
  Future<void> logSegmentTapped() => log('segment_tapped');
  Future<void> logSearchUsed() => log('search_used');
  Future<void> logLayerToggled(String layer) =>
      log('layer_toggled', {'layer': layer});
  Future<void> logTabSwitch(int index) =>
      log('tab_switch', {'tab_index': index});
  Future<void> logCitySwitch(String cityId) =>
      log('city_switch', {'city_id': cityId});
  Future<void> logSpotSaved() => log('spot_saved');
  @override
  Future<void> logHistoryViewed() => log('history_viewed');

  // ── Session ───────────────────────────────────────────────────────────────

  Future<void> logParkingSessionStarted({int? maxMinutes}) =>
      log('session_started', {
        if (maxMinutes != null) 'max_minutes': maxMinutes,
      });

  Future<void> logParkingSessionEnded({required int durationMinutes}) =>
      log('session_ended', {'duration_minutes': durationMinutes});

  Future<void> logParkingCalculated({
    required String ruleType, // free | meter | restricted | amd | nettoyage
    required int durationMinutes,
  }) =>
      log('parking_calculated', {
        'rule_type': ruleType,
        'duration_minutes': durationMinutes,
      });

  // ── Paywall variants ──────────────────────────────────────────────────────

  Future<void> logPremiumShown() => log('premium_shown');
  Future<void> logPaywallViewed(String type) =>
      log('paywall_viewed', {'type': type});

  // ── Features ─────────────────────────────────────────────────────────────

  Future<void> logShareUsed() => log('share_used');

  Future<void> logCrossPromoTapped(String dest) =>
      log('cross_promo_tapped', {'destination': dest});

  // ── Universal events (Phase 2) ────────────────────────────────────────────

  Future<void> logScreenView(String screenName) =>
      log('screen_view', {'screen_name': screenName});
  Future<void> logOnboardingComplete() => log('onboarding_complete');
  Future<void> logOnboardingSkipped()  => log('onboarding_skipped');
  Future<void> logFirstCalculate()     => log('first_calculate');
  Future<void> logDarkModeToggled(bool enabled) =>
      log('dark_mode_toggled', {'enabled': '$enabled'});
  Future<void> logLanguageChanged(String lang) =>
      log('language_changed', {'language': lang});
  Future<void> logShareTapped()   => log('share_tapped');
  Future<void> logExportStarted() => log('export_started');
  Future<void> logUpgradeButtonTapped(String source) =>
      log('upgrade_tapped', {'source': source});
  Future<void> logFeatureGated(String feature) =>
      log('feature_gated', {'feature': feature});

  // ── ParkSmart domain events (Phase 2) ────────────────────────────────────

  Future<void> logCostEstimated()          => log('cost_estimated');
  Future<void> logMonthlyCostViewed()      => log('monthly_cost_viewed');
  Future<void> logLocationSaved()          => log('location_saved');
}
