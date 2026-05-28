import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/parking_rule.dart';

/// Service AMD — Agence de mobilité durable de Montréal.
///
/// Charge l'asset [assets/amd_montreal.json] (12 565 emplacements de
/// parcomètres avec coordonnées GPS précises et plages horaires réelles)
/// et fournit une recherche par proximité GPS pour les rues bulk.
///
/// ## Architecture
///   Grille spatiale (cellules 0.001° ≈ 100m × 78m) pour une recherche
///   O(1) par cellule plutôt qu'un scan linéaire O(n) sur 12 k spots.
///
/// ## Usage
///   final amd   = AmdService();
///   await amd.load();
///   final rules = amd.rulesNear(lon, lat); // null si hors secteur AMD
@Deprecated(
    'Use CityParkingService instead. Will be removed after Phase 0 validation.')
class AmdService {
  static final AmdService _instance = AmdService._();
  factory AmdService() => _instance;
  AmdService._();

  // Grille spatiale : clé → indices dans [_spots]
  final Map<String, List<int>> _grid = {};
  final List<_AmdSpot> _spots = [];

  bool _loaded = false;

  // Seuil de proximité : distance² max en degrés² (~50 m à lat 45°)
  // 50 m lat ≈ 0.00045°  → 0.00045² = 2.02e-7
  // 50 m lon ≈ 0.00064°  → on utilise la distance euclidienne lat/lon brute
  static const double _thresh2 = 2.5e-7; // ≈ 56 m rayon

  // Taille de cellule de grille en degrés
  static const double _cell = 0.001;

  Future<void> load() async {
    if (_loaded) return;

    try {
      final raw = await rootBundle.loadString('assets/amd_montreal.json');
      final data = jsonDecode(raw) as List<dynamic>;

      for (final item in data) {
        final spot = _AmdSpot.fromJson(item as Map<String, dynamic>);
        final idx = _spots.length;
        _spots.add(spot);

        // Indexer dans la grille
        _grid.putIfAbsent(_cellKey(spot.lat, spot.lon), () => []).add(idx);
      }

      _loaded = true;
      debugPrint('AMD loaded: ${_spots.length} parking meter spots');
    } catch (e) {
      debugPrint('AMD load failed: $e');
      _loaded = false; // Erreur → service inactif
    }
  }

  /// Règles du parcomètre le plus proche de (lon, lat), ou null si aucun
  /// dans le rayon [_thresh2].
  ///
  /// Parcourt les 9 cellules adjacentes (rayon 1 cellule = ≈100 m),
  /// retourne les règles du spot le plus proche sous le seuil.
  List<ParkingRule>? rulesNear(double lon, double lat) {
    if (!_loaded) return null;

    final gi = (lat / _cell).floor();
    final gj = (lon / _cell).floor();

    _AmdSpot? best;
    double bestD2 = double.infinity;

    for (int di = -1; di <= 1; di++) {
      for (int dj = -1; dj <= 1; dj++) {
        final key = '${gi + di},${gj + dj}';
        final indices = _grid[key];
        if (indices == null) continue;

        for (final idx in indices) {
          final s = _spots[idx];
          final dl = s.lat - lat;
          final dx = s.lon - lon;
          final d2 = dl * dl + dx * dx;
          if (d2 < bestD2) {
            bestD2 = d2;
            best = s;
          }
        }
      }
    }

    if (best == null || bestD2 > _thresh2) return null;
    return best.rules;
  }

  static String _cellKey(double lat, double lon) =>
      '${(lat / _cell).floor()},${(lon / _cell).floor()}';

  int get spotCount => _spots.length;
  bool get isLoaded => _loaded;
}

// ── Modèle interne ──────────────────────────────────────────────────────────

class _AmdSpot {
  final double lon;
  final double lat;
  final List<ParkingRule> rules;

  const _AmdSpot({required this.lon, required this.lat, required this.rules});

  factory _AmdSpot.fromJson(Map<String, dynamic> json) {
    final rateCents = (json['c'] as num?)?.toInt() ?? 0;
    final ratePerHour = rateCents > 0 ? rateCents / 100.0 : null;

    final rules = (json['p'] as List<dynamic>).map((p) {
      final days = (p['d'] as List<dynamic>).cast<int>();
      return ParkingRule(
        type: RuleType.meter,
        days: days,
        from: p['f'] as String,
        to: p['t'] as String,
        ratePerHour: ratePerHour,
        maxMinutes: (p['m'] as num?)?.toInt(),
      );
    }).toList();

    return _AmdSpot(
      lon: (json['x'] as num).toDouble(),
      lat: (json['y'] as num).toDouble(),
      rules: rules,
    );
  }
}
