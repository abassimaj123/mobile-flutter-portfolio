import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/parking_rule.dart';
import '../models/street_segment.dart';

/// Service de nettoyage des rues — Montréal.
///
/// Charge [assets/nettoyage_montreal.json] généré par
/// [scripts/gen_nettoyage_segments.py] à partir des données ouvertes
/// de la Ville de Montréal (calendrier nettoyage des rues).
///
/// ## Règle
///   Chaque segment indique le côté (pair/impair), les jours et les heures
///   de nettoyage. Stationnement interdit PENDANT ces plages.
///
/// ## Source
///   https://donnees.montreal.ca/dataset/nettoyage-rue
///   Données ouvertes MTL · Mise à jour annuelle
@Deprecated(
    'Use CityParkingService instead. Will be removed after Phase 0 validation.')
class NettoyageService {
  static final NettoyageService _instance = NettoyageService._();
  factory NettoyageService() => _instance;
  NettoyageService._();

  final Map<String, List<int>> _grid = {};
  final List<_NettSeg> _segs = [];
  bool _loaded = false;

  // Grille 0.001° (~100 m), seuil ~80 m
  static const double _cell = 0.001;
  static const double _thresh2 = 5.0e-7;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/nettoyage_montreal.json');
      final data = jsonDecode(raw) as List<dynamic>;

      for (final item in data) {
        final seg = _NettSeg.fromJson(item as Map<String, dynamic>);
        final idx = _segs.length;
        _segs.add(seg);
        for (final pt in seg.coords) {
          _grid.putIfAbsent(_cellKey(pt[1], pt[0]), () => []).add(idx);
        }
      }
      _loaded = true;
    } catch (_) {
      // Asset absent ou vide → service inactif, pas d'erreur fatale
      _loaded = false;
    }
  }

  /// Segment de nettoyage le plus proche de (lon, lat), ou null si > 80 m
  /// ou si l'asset n'est pas encore chargé.
  StreetSegment? segmentNear(double lon, double lat) {
    if (!_loaded) return null;

    final gi = (lat / _cell).floor();
    final gj = (lon / _cell).floor();

    int? bestIdx;
    double bestD2 = double.infinity;

    for (int di = -1; di <= 1; di++) {
      for (int dj = -1; dj <= 1; dj++) {
        final key = '${gi + di},${gj + dj}';
        for (final idx in _grid[key] ?? <int>[]) {
          final seg = _segs[idx];
          for (final pt in seg.coords) {
            final dl = pt[1] - lat;
            final dx = pt[0] - lon;
            final d2 = dl * dl + dx * dx;
            if (d2 < bestD2) {
              bestD2 = d2;
              bestIdx = idx;
            }
          }
        }
      }
    }

    if (bestIdx == null || bestD2 > _thresh2) return null;
    return _segs[bestIdx].toSegment();
  }

  static String _cellKey(double lat, double lon) =>
      '${(lat / _cell).floor()},${(lon / _cell).floor()}';

  int get segmentCount => _segs.length;
  bool get isLoaded => _loaded;
}

// ── Modèle interne ─────────────────────────────────────────────────────────

class _NettSeg {
  final String name;
  final int wayId;
  final String zone;
  final String side; // 'pair' | 'impair' | 'les deux'
  final List<List<double>> coords;
  final List<_NettRule> rules;

  const _NettSeg({
    required this.name,
    required this.wayId,
    required this.zone,
    required this.side,
    required this.coords,
    required this.rules,
  });

  factory _NettSeg.fromJson(Map<String, dynamic> j) => _NettSeg(
        name: j['n'] as String,
        wayId: j['w'] as int,
        zone: j['z'] as String,
        side: j['s'] as String,
        coords: (j['c'] as List<dynamic>)
            .map((p) =>
                (p as List<dynamic>).map((v) => (v as num).toDouble()).toList())
            .toList(),
        rules: (j['r'] as List<dynamic>)
            .map((r) => _NettRule.fromJson(r as Map<String, dynamic>))
            .toList(),
      );

  StreetSegment toSegment() => StreetSegment(
        id: 'nett-$wayId',
        streetName: name,
        city: 'Montreal',
        side: side,
        osmWayIds: [wayId],
        coordinates: coords,
        rules: rules.map((r) => r.toParkingRule()).toList(),
        confidence: 0.85,
        sourceDate: '2026-01-01',
        sources: [DataSource.bylaw],
        notes: 'Nettoyage des rues — $zone ($side)',
      );
}

class _NettRule {
  final List<int> days; // 1=Lun … 7=Dim
  final String from; // 'HH:MM'
  final String to; // 'HH:MM'
  final int? monthFrom;
  final int? monthTo;
  final int? dayParity; // 0=pair 1=impair null=tous

  const _NettRule({
    required this.days,
    required this.from,
    required this.to,
    this.monthFrom,
    this.monthTo,
    this.dayParity,
  });

  factory _NettRule.fromJson(Map<String, dynamic> j) => _NettRule(
        days: (j['d'] as List<dynamic>).map((v) => v as int).toList(),
        from: j['f'] as String,
        to: j['t'] as String,
        monthFrom: j['mf'] as int?,
        monthTo: j['mt'] as int?,
        dayParity: j['dp'] as int?,
      );

  ParkingRule toParkingRule() => ParkingRule(
        type: RuleType.noParking,
        days: days,
        from: from,
        to: to,
        monthFrom: monthFrom,
        monthTo: monthTo,
        dayParity: dayParity,
        note: 'Nettoyage des rues — interdit stationnement',
      );
}
