import 'package:calcwise_core/calcwise_core.dart';

/// Firebase Analytics wrapper for JobOfferUS.
/// Common events inherited from CalcwiseAnalytics.
/// JobOfferUS-specific events (offer comparison, theme, salary buckets) kept here.
class AnalyticsService extends CalcwiseAnalytics {
  AnalyticsService._() : super(appName: 'JobOfferUS');
  static final AnalyticsService instance = AnalyticsService._();

  // ── Calculator (job-offer specific) ──────────────────────────────────────

  Future<void> logOfferComparison({
    required double salary1,
    required double salary2,
    required String location,
  }) =>
      log('offer_comparison', {
        'salary_bucket_1': _salaryBucket(salary1),
        'salary_bucket_2': _salaryBucket(salary2),
        'location': location,
      });

  Future<void> logOfferCompared() => log('offer_compared');
  Future<void> logOfferSaved() => log('offer_saved');
  Future<void> logOfferExported() => log('offer_exported');

  // ── Canonical taxonomy (MortgageUS reference) ────────────────────────────

  Future<void> logCalculationCompleted({Map<String, Object>? params}) =>
      log('calculation_completed', params);
  Future<void> logResultSaved() => log('result_saved');
  Future<void> logResultShared() => log('result_shared');
  Future<void> logPdfExportedEvent() => log('pdf_exported');
  Future<void> logPaywallViewed(String trigger) =>
      log('paywall_viewed', {'trigger': trigger});
  Future<void> logPaywallConverted(String source) =>
      log('paywall_converted', {'source': source});

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<void> logThemeChanged(String theme) =>
      log('theme_changed', {'theme': theme});

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _salaryBucket(double salary) {
    if (salary < 50000) return '<50k';
    if (salary < 75000) return '50-75k';
    if (salary < 100000) return '75-100k';
    if (salary < 150000) return '100-150k';
    return '>150k';
  }
}
