import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/parking_rule.dart';
import '../models/street_segment.dart';

/// Service de stationnement alterné par mois — Montréal.
///
/// Charge [assets/alternating_montreal.json] (529 rues résidentielles
/// Plateau, Rosemont, Mile-End, Villeray, Centre-Sud) et expose
/// [segmentNear] pour retrouver le segment alterné le plus proche.
///
/// ## Règle universelle pour ces rues
///   Mois impairs (Jan, Mar, Mai, Jul, Sep, Nov) → côté pair INTERDIT
///   Mois pairs  (Fév, Avr, Jun, Aoû, Oct, Déc) → côté impair INTERDIT
@Deprecated(
    'Use CityParkingService instead. Will be removed after Phase 0 validation.')
class AlternatingService {
  static final AlternatingService _instance = AlternatingService._();
  factory AlternatingService() => _instance;
  AlternatingService._();

  final Map<String, List<int>> _grid = {};
  final List<_AltSegment> _segs = [];
  bool _loaded = false;

  // Grille 0.001° (~100 m), seuil de proximité ~80 m
  static const double _cell = 0.001;
  static const double _thresh2 = 5.0e-7; // ~80 m

  // Règles communes à tous les segments alternés
  static const List<ParkingRule> _rules = [
    ParkingRule(
      type: RuleType.noParking,
      days: [1, 2, 3, 4, 5, 6, 7],
      monthParity: 1,
      note: 'Côté pair — interdit les mois impairs (Jan Mar Mai Jul Sep Nov)',
    ),
    ParkingRule(
      type: RuleType.noParking,
      days: [1, 2, 3, 4, 5, 6, 7],
      monthParity: 0,
      note: 'Côté impair — interdit les mois pairs (Fév Avr Jun Aoû Oct Déc)',
    ),
  ];

  Future<void> load() async {
    if (_loaded) return;

    try {
      final raw =
          await rootBundle.loadString('assets/alternating_montreal.json');
      final data = jsonDecode(raw) as List<dynamic>;

      for (final item in data) {
        final seg = _AltSegment.fromJson(item as Map<String, dynamic>);
        final idx = _segs.length;
        _segs.add(seg);

        // Indexer chaque point de la polyligne dans la grille
        for (final pt in seg.coords) {
          _grid.putIfAbsent(_cellKey(pt[1], pt[0]), () => []).add(idx);
        }
      }
      _loaded = true;
      debugPrint(
          'Alternating loaded: ${_segs.length} residential alternating streets');
    } catch (e) {
      debugPrint('Alternating load failed: $e');
      _loaded = false;
    }
  }

  /// Segment alterné le plus proche de (lon, lat), ou null si > 80 m.
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

class _AltSegment {
  final String name;
  final int wayId;
  final String zone;
  final List<List<double>> coords; // [[lon, lat], ...]

  const _AltSegment({
    required this.name,
    required this.wayId,
    required this.zone,
    required this.coords,
  });

  factory _AltSegment.fromJson(Map<String, dynamic> json) => _AltSegment(
        name: json['n'] as String,
        wayId: json['w'] as int,
        zone: json['z'] as String,
        coords: (json['c'] as List<dynamic>)
            .map((p) =>
                (p as List<dynamic>).map((v) => (v as num).toDouble()).toList())
            .toList(),
      );

  StreetSegment toSegment() => StreetSegment(
        id: 'alt-$wayId',
        streetName: name,
        city: 'Montreal',
        side: 'Les deux côtés',
        osmWayIds: [wayId],
        coordinates: coords,
        rules: AlternatingService._rules,
        confidence: 0.80,
        sourceDate: '2026-01-01',
        sources: [DataSource.bylaw],
        notes: 'Stationnement alterné par mois — $zone',
      );
}
