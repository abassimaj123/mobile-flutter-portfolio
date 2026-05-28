import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_contribution.dart';

/// Singleton service — stores contributions locally in SharedPreferences.
/// No backend sync in this sprint (Layer 3 unverified contributions).
class ContributionService {
  ContributionService._();
  static final ContributionService _instance = ContributionService._();
  factory ContributionService() => _instance;

  static const String _kStorageKey = 'contributions_v1';

  /// Persist a new contribution locally.
  Future<void> submit(UserContribution c) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await _loadAll(prefs);
    existing.add(c);
    await _saveAll(prefs, existing);
  }

  /// Return all contributions with [ContributionStatus.pending].
  Future<List<UserContribution>> getPending() async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _loadAll(prefs);
    return all.where((c) => c.status == ContributionStatus.pending).toList();
  }

  /// Return the count of pending contributions.
  Future<int> getPendingCount() async {
    final pending = await getPending();
    return pending.length;
  }

  /// Return all stored contributions regardless of status.
  Future<List<UserContribution>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    return _loadAll(prefs);
  }

  /// Update the status of a contribution by id (e.g. after remote sync).
  Future<void> updateStatus(String id, ContributionStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _loadAll(prefs);
    final updated = all.map((c) {
      if (c.id == id) return c.copyWith(status: status);
      return c;
    }).toList();
    await _saveAll(prefs, updated);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<List<UserContribution>> _loadAll(SharedPreferences prefs) async {
    final raw = prefs.getString(_kStorageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => UserContribution.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAll(
    SharedPreferences prefs,
    List<UserContribution> items,
  ) async {
    final encoded = json.encode(items.map((c) => c.toJson()).toList());
    await prefs.setString(_kStorageKey, encoded);
  }
}
