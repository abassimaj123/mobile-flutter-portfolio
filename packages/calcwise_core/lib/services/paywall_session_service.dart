import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Paywall session gate — shared across all Calcwise portfolio apps.
///
/// Tracks user sessions and actions to decide when to show soft vs hard paywall.
/// Sessions 1–3 : free, no interruption
/// Sessions 4–6 : soft paywall after `softActionThreshold` actions
/// Sessions 7+  : hard paywall after `hardActionThreshold` actions
///
/// Usage — instantiate once as singleton, call `recordSession` on app launch
/// and `recordAction` on every tab switch or calculation:
/// ```dart
/// final paywallSession = PaywallSessionService(appKey: 'mortgageus');
/// await paywallSession.initialize();
///
/// // On app launch:
/// await paywallSession.recordSession();
///
/// // On tab switch or calculation:
/// final trigger = await paywallSession.recordAction();
/// if (trigger == PaywallTrigger.soft)  { /* show PaywallSoft */ }
/// if (trigger == PaywallTrigger.hard)  { /* show PaywallHard */ }
/// ```
enum PaywallTrigger { none, soft, hard }

class PaywallSessionService {
  PaywallSessionService({
    required this.appKey,
    this.softActionThreshold = 5,
    this.hardActionThreshold = 4,
    this.softSessionStart    = 4,
    this.hardSessionStart    = 7,
  });

  final String appKey;

  /// Actions before soft paywall triggers (sessions 4–6).
  final int softActionThreshold;

  /// Actions before hard paywall triggers (sessions 7+).
  final int hardActionThreshold;

  /// First session where soft paywall can appear.
  final int softSessionStart;

  /// First session where hard paywall appears.
  final int hardSessionStart;

  // ── Keys ──────────────────────────────────────────────────────────────────

  late final _kSessionCount  = '${appKey}_pw_sessions';
  late final _kActionCount   = '${appKey}_pw_actions';
  late final _kShownThisSession = '${appKey}_pw_shown_session';

  // ── State ─────────────────────────────────────────────────────────────────

  late SharedPreferences _prefs;

  final sessionCountNotifier = ValueNotifier<int>(0);

  int get sessionCount => _prefs.getInt(_kSessionCount) ?? 0;
  int get actionCount  => _prefs.getInt(_kActionCount)  ?? 0;
  int get _shownInSession => _prefs.getInt(_kShownThisSession) ?? 0;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    sessionCountNotifier.value = sessionCount;
  }

  /// Call once per app launch (after initialize).
  /// Increments session counter and resets per-session action count.
  Future<void> recordSession() async {
    final newCount = sessionCount + 1;
    await _prefs.setInt(_kSessionCount, newCount);
    await _prefs.setInt(_kActionCount, 0);
    await _prefs.setInt(_kShownThisSession, 0);
    sessionCountNotifier.value = newCount;
    debugPrint('[PaywallSession] session #$newCount started');
  }

  /// Call on every tab switch or calculation.
  /// Returns [PaywallTrigger.soft] or [PaywallTrigger.hard] when threshold is reached.
  /// Returns [PaywallTrigger.none] otherwise.
  /// Only triggers once per session (no repeated interruptions in same session).
  Future<PaywallTrigger> recordAction() async {
    // Already shown this session — don't repeat
    if (_shownInSession > 0) return PaywallTrigger.none;

    // Sessions 1–3 : fully free
    if (sessionCount < softSessionStart) return PaywallTrigger.none;

    final newActions = actionCount + 1;
    await _prefs.setInt(_kActionCount, newActions);

    // Sessions 7+ : hard paywall
    if (sessionCount >= hardSessionStart &&
        newActions >= hardActionThreshold) {
      await _markShown();
      debugPrint('[PaywallSession] → HARD paywall (session $sessionCount, action $newActions)');
      return PaywallTrigger.hard;
    }

    // Sessions 4–6 : soft paywall
    if (sessionCount >= softSessionStart &&
        sessionCount < hardSessionStart &&
        newActions >= softActionThreshold) {
      await _markShown();
      debugPrint('[PaywallSession] → SOFT paywall (session $sessionCount, action $newActions)');
      return PaywallTrigger.soft;
    }

    return PaywallTrigger.none;
  }

  Future<void> _markShown() =>
      _prefs.setInt(_kShownThisSession, 1);

  // ── Debug / testing ───────────────────────────────────────────────────────

  Future<void> resetForTesting() async {
    await _prefs.remove(_kSessionCount);
    await _prefs.remove(_kActionCount);
    await _prefs.remove(_kShownThisSession);
    sessionCountNotifier.value = 0;
  }
}
