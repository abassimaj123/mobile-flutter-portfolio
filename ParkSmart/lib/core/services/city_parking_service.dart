import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/parking_rule.dart';

/// Service de données de stationnement générique — une instance par ville.
///
/// Charge `assets/data/{cityId}.json` qui regroupe trois couches de données :
///   • `meters`      — parcomètres GPS (ex. AMD Montréal)
///   • `alternating` — rues à alternance pair/impair
///   • `cleaning`    — nettoyage des rues (restrictions horaires)
///
/// ## Ajout d'une nouvelle ville
/// 1. Créer `assets/data/{cityId}.json` (via script Python dans scripts/)
/// 2. Ajouter la ville dans [CityRegistry]
/// C'est tout — aucune modification Flutter nécessaire.
///
/// ## Architecture spatiale
/// Grille 0.001° (~100 m) pour recherche O(1) par cellule.
/// Deux grilles séparées :
///   - parcomètres  : seuil 56 m (précision GPS AMD)
///   - segments     : seuil 80 m (largeur typique d'un bloc)
class CityParkingService {
  // ── Singleton par cityId ────────────────────────────────────────────────────
  static final Map<String, CityParkingService> _instances = {};

  factory CityParkingService(String cityId) =>
      _instances.putIfAbsent(cityId, () => CityParkingService._(cityId));

  CityParkingService._(this.cityId);

  final String cityId;

  // ── Grille parcomètres (points) ────────────────────────────────────────────
  final Map<String, List<int>> _meterGrid = {};
  final List<_MeterSpot> _meters = [];

  // ── Grille segments (polylignes : alternance + nettoyage) ──────────────────
  final Map<String, List<int>> _segGrid = {};
  final List<_ParkSeg> _segs = [];

  bool _loaded = false;

  static const double _cell = 0.001;
  static const double _meterThresh2 = 2.5e-7; // ~56 m — copié de AmdService
  static const double _segThresh2 =
      5.0e-7; // ~80 m — copié de AlternatingService

  // Règles alternance fixes (identiques dans toutes les villes qui ont ce type)
  static const List<ParkingRule> _altRules = [
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

  // ── Chargement ─────────────────────────────────────────────────────────────

  /// Charge le fichier `assets/data/{cityId}.json`.
  /// No-op si déjà chargé. Silencieux si le fichier est absent (ville sans data).
  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/data/$cityId.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;

      _parseMeters(data['meters'] as List? ?? []);
      _parseAlternating(data['alternating'] as List? ?? []);
      _parseCleaning(data['cleaning'] as List? ?? []);

      _loaded = true;
      debugPrint('CityParkingService($cityId): '
          '${_meters.length} meters · ${_segs.length} segments');
    } catch (e) {
      // Fichier absent = ville sans données spécifiques → ZoneRegistry + défauts
      debugPrint('CityParkingService($cityId): no data file ($e)');
    }
  }

  // ── Requête proximité ──────────────────────────────────────────────────────

  /// Retourne les règles de la source la plus proche de (lon, lat).
  /// Priorité : parcomètres > alternance/nettoyage.
  /// Retourne null si le service n'est pas chargé ou rien dans le rayon.
  List<ParkingRule>? rulesNear(double lon, double lat) {
    if (!_loaded) return null;
    return _meterRulesNear(lon, lat) ?? _segRulesNear(lon, lat);
  }

  bool get isLoaded => _loaded;
  int get meterCount => _meters.length;
  int get segmentCount => _segs.length;

  // ── Parsing ────────────────────────────────────────────────────────────────

  void _parseMeters(List<dynamic> data) {
    for (final item in data) {
      final j = item as Map<String, dynamic>;
      final lon = (j['x'] as num).toDouble();
      final lat = (j['y'] as num).toDouble();
      final cents = (j['c'] as num?)?.toInt() ?? 0;
      final rate = cents > 0 ? cents / 100.0 : null;

      final rules = (j['p'] as List<dynamic>).map((p) {
        final pm = p as Map<String, dynamic>;
        return ParkingRule(
          type: RuleType.meter,
          days: (pm['d'] as List<dynamic>).cast<int>(),
          from: pm['f'] as String,
          to: pm['t'] as String,
          ratePerHour: rate,
          maxMinutes: (pm['m'] as num?)?.toInt(),
        );
      }).toList();

      final idx = _meters.length;
      _meters.add(_MeterSpot(lon: lon, lat: lat, rules: rules));
      _indexPoint(_meterGrid, lat, lon, idx);
    }
  }

  void _parseAlternating(List<dynamic> data) {
    for (final item in data) {
      final j = item as Map<String, dynamic>;
      final coords = _parseCoords(j['c'] as List<dynamic>);

      final idx = _segs.length;
      _segs.add(_ParkSeg(rules: _altRules, coords: coords));
      for (final pt in coords) {
        _indexPoint(_segGrid, pt[1], pt[0], idx);
      }
    }
  }

  void _parseCleaning(List<dynamic> data) {
    for (final item in data) {
      final j = item as Map<String, dynamic>;
      final coords = _parseCoords(j['c'] as List<dynamic>);

      final rules = (j['r'] as List<dynamic>).map((r) {
        final rm = r as Map<String, dynamic>;
        return ParkingRule(
          type: RuleType.noParking,
          days: (rm['d'] as List<dynamic>).cast<int>(),
          from: rm['f'] as String,
          to: rm['t'] as String,
          monthFrom: rm['mf'] as int?,
          monthTo: rm['mt'] as int?,
          dayParity: rm['dp'] as int?,
          note: 'Nettoyage des rues — stationnement interdit',
        );
      }).toList();

      final idx = _segs.length;
      _segs.add(_ParkSeg(rules: rules, coords: coords));
      for (final pt in coords) {
        _indexPoint(_segGrid, pt[1], pt[0], idx);
      }
    }
  }

  // ── Helpers spatiaux ───────────────────────────────────────────────────────

  void _indexPoint(
      Map<String, List<int>> grid, double lat, double lon, int idx) {
    final key = '${(lat / _cell).floor()},${(lon / _cell).floor()}';
    grid.putIfAbsent(key, () => []).add(idx);
  }

  List<ParkingRule>? _meterRulesNear(double lon, double lat) {
    final gi = (lat / _cell).floor();
    final gj = (lon / _cell).floor();
    int? bestIdx;
    double bestD2 = double.infinity;

    for (int di = -1; di <= 1; di++) {
      for (int dj = -1; dj <= 1; dj++) {
        final key = '${gi + di},${gj + dj}';
        for (final idx in _meterGrid[key] ?? <int>[]) {
          final m = _meters[idx];
          final dl = m.lat - lat;
          final dx = m.lon - lon;
          final d2 = dl * dl + dx * dx;
          if (d2 < bestD2) {
            bestD2 = d2;
            bestIdx = idx;
          }
        }
      }
    }

    if (bestIdx == null || bestD2 > _meterThresh2) return null;
    return _meters[bestIdx].rules;
  }

  List<ParkingRule>? _segRulesNear(double lon, double lat) {
    final gi = (lat / _cell).floor();
    final gj = (lon / _cell).floor();
    int? bestIdx;
    double bestD2 = double.infinity;

    for (int di = -1; di <= 1; di++) {
      for (int dj = -1; dj <= 1; dj++) {
        final key = '${gi + di},${gj + dj}';
        for (final idx in _segGrid[key] ?? <int>[]) {
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

    if (bestIdx == null || bestD2 > _segThresh2) return null;
    return _segs[bestIdx].rules;
  }

  static List<List<double>> _parseCoords(List<dynamic> raw) => raw
      .map((p) =>
          (p as List<dynamic>).map((v) => (v as num).toDouble()).toList())
      .toList();
}

// ── Modèles internes ──────────────────────────────────────────────────────────

class _MeterSpot {
  final double lon, lat;
  final List<ParkingRule> rules;
  const _MeterSpot({required this.lon, required this.lat, required this.rules});
}

class _ParkSeg {
  final List<ParkingRule> rules;
  final List<List<double>> coords;
  const _ParkSeg({required this.rules, required this.coords});
}
