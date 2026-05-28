import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared freemium logic — premium state, rewarded-ad sessions, calc gate.
///
/// Usage — instantiate once as a global singleton in each app:
/// ```dart
/// final freemiumService = CalcwiseFreemium(appKey: 'jobofferus');
/// ```
/// The [appKey] is used to namespace SharedPreferences keys so multiple
/// apps on the same device never collide.
class CalcwiseFreemium {
  CalcwiseFreemium({
    required this.appKey,
    this.rewardedDurationMinutes = 60,
    this.maxRewardedPerDay       = 3,
    this.freeCalculationLimit    = 5,
  });

  /// Short lowercase app identifier — used as SharedPreferences key prefix.
  final String appKey;
  final int rewardedDurationMinutes;
  final int maxRewardedPerDay;
  final int freeCalculationLimit;

  // ── Keys ──────────────────────────────────────────────────────────────────

  late final _kPremium      = '${appKey}_premium';
  late final _kRewardedExp  = '${appKey}_rewarded_exp';
  late final _kRewardedDay  = '${appKey}_rewarded_day';
  late final _kRewardedCnt  = '${appKey}_rewarded_count';
  late final _kCalcCount    = '${appKey}_calc_count';

  // ── State ─────────────────────────────────────────────────────────────────

  SharedPreferences? _prefs;
  bool _initialized = false;

  final isPremiumNotifier     = ValueNotifier<bool>(false);
  final isRewardedNotifier    = ValueNotifier<bool>(false);
  /// Combines isPremium + isRewarded. Use this for feature gates so rewarded
  /// users (60 min window) get the same access as permanent premium users.
  final hasFullAccessNotifier = ValueNotifier<bool>(false);

  bool get isPremium     => isPremiumNotifier.value;
  bool get isRewarded    { if (_initialized) _refreshRewarded(); return isRewardedNotifier.value; }
  bool get hasFullAccess => isPremium || isRewarded;
  bool get showAds       => !hasFullAccess;

  void _syncHasFullAccess() {
    hasFullAccessNotifier.value = isPremiumNotifier.value || isRewardedNotifier.value;
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
    isPremiumNotifier.value = _prefs!.getBool(_kPremium) ?? false;
    _refreshRewarded();
    _syncHasFullAccess();
    // Keep hasFullAccessNotifier in sync with both sources
    isPremiumNotifier.addListener(_syncHasFullAccess);
    isRewardedNotifier.addListener(_syncHasFullAccess);
    // Background timer — revert isRewarded when window closes
    Timer.periodic(const Duration(seconds: 30), (_) => _refreshRewarded());
  }

  // ── Premium ───────────────────────────────────────────────────────────────

  Future<void> activatePremium() async {
    await _prefs!.setBool(_kPremium, true);
    isPremiumNotifier.value = true;
  }

  @visibleForTesting
  void debugUnlockPremium() {
    if (kDebugMode) activatePremium();
  }

  // ── Rewarded session ──────────────────────────────────────────────────────

  bool canWatchRewarded() {
    if (isPremium || isRewarded) return false;
    return _todayCount() < maxRewardedPerDay;
  }

  Future<void> activateRewarded() async {
    if (!canWatchRewarded()) return;
    final exp = DateTime.now()
        .add(Duration(minutes: rewardedDurationMinutes))
        .toIso8601String();
    await _prefs!.setString(_kRewardedExp, exp);
    await _prefs!.setInt(_kRewardedDay, _todayKey());
    await _prefs!.setInt(_kRewardedCnt, _todayCount() + 1);
    isRewardedNotifier.value = true;
    _scheduleExpiry();
  }

  Duration? get rewardedRemaining {
    _refreshRewarded();
    if (!isRewardedNotifier.value) return null;
    final s = _prefs?.getString(_kRewardedExp);
    if (s == null) return null;
    final r = DateTime.parse(s).difference(DateTime.now());
    return r.isNegative ? null : r;
  }

  void _refreshRewarded() {
    if (_prefs == null) return;
    final s = _prefs!.getString(_kRewardedExp);
    isRewardedNotifier.value =
        s != null && DateTime.now().isBefore(DateTime.parse(s));
  }

  void _scheduleExpiry() {
    final s = _prefs?.getString(_kRewardedExp);
    if (s == null) return;
    final remaining = DateTime.parse(s).difference(DateTime.now());
    if (remaining.isNegative) { _refreshRewarded(); return; }
    Future.delayed(remaining, _refreshRewarded);
  }

  int _todayKey() {
    final n = DateTime.now();
    return n.year * 10000 + n.month * 100 + n.day;
  }

  int _todayCount() {
    if (_prefs?.getInt(_kRewardedDay) != _todayKey()) return 0;
    return _prefs?.getInt(_kRewardedCnt) ?? 0;
  }

  // ── Calculation gate ──────────────────────────────────────────────────────

  int get calcCount => _prefs?.getInt(_kCalcCount) ?? 0;

  bool get showSoftGate =>
      !hasFullAccess && calcCount >= freeCalculationLimit;

  Future<int> incrementCalcCount() async {
    final n = calcCount + 1;
    await _prefs?.setInt(_kCalcCount, n);
    return n;
  }

  Future<void> resetCalcCount() async =>
      await _prefs?.setInt(_kCalcCount, 0);

  // ── History limit ─────────────────────────────────────────────────────────

  /// Number of history entries the user can store.
  /// Free tier uses [freeCalculationLimit] as the cap (same value, distinct concept).
  int get historyLimit => hasFullAccess ? 999999 : freeCalculationLimit;
}
