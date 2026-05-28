import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Calcwise Remote Config — centralises tous les paramètres A/B testables.
///
/// Initialiser une fois au démarrage (après Firebase.initializeApp()) :
/// ```dart
/// await CalcwiseRemoteConfig.initialize();
/// ```
///
/// Lire ensuite n'importe où :
/// ```dart
/// final price   = CalcwiseRemoteConfig.paywallPriceLabel; // '$2.99'
/// final variant = CalcwiseRemoteConfig.abPaywallVariant;  // 'control'
/// ```
///
/// ## Configuration Firebase Console
/// 1. Firebase Console → Remote Config → Add parameter
/// 2. Utiliser les clés ci-dessous comme noms de paramètre
/// 3. Publier — les changements sont actifs dans les 12h (ou au prochain foreground)
///
/// ## Paramètres A/B paywall
/// - `ab_paywall_variant` : 'control' | 'price_test_199' | 'price_test_399' | 'annual_cta'
/// - `paywall_price_label` : '\$2.99' (modifiable sans MAJ app)
/// - `free_calc_limit` : 5 (nombre de calcs gratuits avant soft paywall)
class CalcwiseRemoteConfig {
  CalcwiseRemoteConfig._();

  static bool _initialized = false;

  // ── Valeurs par défaut ─────────────────────────────────────────────────────
  static const Map<String, dynamic> _defaults = {
    'paywall_price_label':       r'$2.99',
    'paywall_cta_text':          'Unlock Premium',
    'paywall_title':             'Go Premium',
    'paywall_subtitle':          'Remove all limits',
    'paywall_feature_1':         'Unlimited calculations',
    'paywall_feature_2':         'No ads',
    'paywall_feature_3':         'PDF export & history',
    'free_calc_limit':           5,
    'rewarded_duration_minutes': 60,
    'ab_paywall_variant':        'control',
    // Variantes : 'control' | 'price_test_199' | 'price_test_399' | 'annual_cta'
  };

  /// Initialise et récupère les valeurs Remote Config.
  /// Appels multiples = no-op. Fail silencieux → defaults utilisés.
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout:         const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : const Duration(hours: 12),
      ));
      await rc.setDefaults(_defaults);
      await rc.fetchAndActivate();
      _initialized = true;
      if (kDebugMode) {
        debugPrint('[RemoteConfig] ✓ variant=$abPaywallVariant '
            'price=$paywallPriceLabel freeLimit=$freeCalcLimit');
      }
    } catch (e) {
      debugPrint('[RemoteConfig] fetch failed → using defaults: $e');
      _initialized = true; // defaults actives, sûr à utiliser
    }
  }

  static FirebaseRemoteConfig get _rc => FirebaseRemoteConfig.instance;

  // ── Paywall A/B ────────────────────────────────────────────────────────────

  /// Prix affiché dans le bouton CTA, ex: '$2.99'
  static String get paywallPriceLabel =>
      _initialized ? _rc.getString('paywall_price_label') : r'$2.99';

  /// Texte du bouton CTA, ex: 'Unlock Premium'
  static String get paywallCtaText =>
      _initialized ? _rc.getString('paywall_cta_text') : 'Unlock Premium';

  /// Titre du paywall, ex: 'Go Premium'
  static String get paywallTitle =>
      _initialized ? _rc.getString('paywall_title') : 'Go Premium';

  /// Sous-titre du paywall
  static String get paywallSubtitle =>
      _initialized ? _rc.getString('paywall_subtitle') : 'Remove all limits';

  /// Bullet feature 1
  static String get paywallFeature1 =>
      _initialized ? _rc.getString('paywall_feature_1') : 'Unlimited calculations';

  /// Bullet feature 2
  static String get paywallFeature2 =>
      _initialized ? _rc.getString('paywall_feature_2') : 'No ads';

  /// Bullet feature 3
  static String get paywallFeature3 =>
      _initialized ? _rc.getString('paywall_feature_3') : 'PDF export & history';

  // ── Freemium gates ─────────────────────────────────────────────────────────

  /// Nombre de calcs gratuits avant déclenchement du soft paywall.
  /// Défaut : 5 (correspond à MonetizationConfig.freeCalculationLimit).
  static int get freeCalcLimit =>
      _initialized ? _rc.getInt('free_calc_limit') : 5;

  /// Minutes de premium débloquées par une rewarded pub.
  static int get rewardedDurationMinutes =>
      _initialized ? _rc.getInt('rewarded_duration_minutes') : 60;

  // ── Variante A/B ───────────────────────────────────────────────────────────

  /// Variante paywall A/B pour cet utilisateur.
  /// Valeurs : 'control' | 'price_test_199' | 'price_test_399' | 'annual_cta'
  static String get abPaywallVariant =>
      _initialized ? _rc.getString('ab_paywall_variant') : 'control';

  /// True si l'utilisateur est dans le groupe contrôle.
  static bool get isControlVariant => abPaywallVariant == 'control';

  /// True si l'utilisateur est dans un groupe test de prix.
  static bool get isPriceTestVariant =>
      abPaywallVariant.startsWith('price_test_');
}
