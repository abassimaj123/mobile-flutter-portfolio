// Data © OpenStreetMap contributors, ODbL license — https://www.openstreetmap.org/copyright

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/parking_rule.dart';

/// Service OSM parking:lane — une instance par ville (singleton).
///
/// Récupère les tags `parking:lane:*` via Overpass API et les convertit en
/// [ParkingRule]. Lookup O(1) par way ID — aucune grille spatiale nécessaire.
///
/// ## Cache
/// Clé : `osm_parking_v1_{cityId}` · TTL 14 jours.
///
/// ## Intégration
/// Utilisé dans `_computeStreetRules()` après [CityParkingService] et avant
/// ZoneRegistry — couverture OSM pour toutes les rues avec parking:lane.
class OsmParkingService {
  // ── Singleton par cityId ────────────────────────────────────────────────────
  static final Map<String, OsmParkingService> _instances = {};

  factory OsmParkingService(String cityId) =>
      _instances.putIfAbsent(cityId, () => OsmParkingService._(cityId));

  OsmParkingService._(this._cityId);

  final String _cityId;

  // ── État interne ────────────────────────────────────────────────────────────
  final Map<int, List<ParkingRule>> _wayRules = {};
  bool _loaded = false;

  // ── Constantes ──────────────────────────────────────────────────────────────
  static const _cachePrefix = 'osm_parking_v1_';
  static const _cacheTsPrefix = 'osm_parking_ts_v1_';
  static const _cacheTtl = Duration(days: 14);

  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.openstreetmap.fr/api/interpreter',
  ];

  static const _headers = {
    'Content-Type': 'application/x-www-form-urlencoded',
    'User-Agent':
        'ParkSmart/1.0 (Flutter mobile; OSM data; contact:parksmart@app.local)',
    'Accept': 'application/json',
  };

  // ── API publique ─────────────────────────────────────────────────────────────

  /// Charge les données parking:lane pour la ville.
  /// No-op si déjà chargé. En cas d'erreur réseau, le service reste non chargé.
  Future<void> load(String overpassBbox) async {
    if (_loaded) return;

    // Essayer le cache d'abord
    final cached = await _loadCache();
    if (cached != null) {
      _wayRules.addAll(cached);
      _loaded = true;
      debugPrint(
          'OsmParkingService($_cityId): ${_wayRules.length} ways depuis cache');
      return;
    }

    // Fetch réseau
    final raw = await _fetchOverpass(overpassBbox);
    if (raw == null) {
      debugPrint(
          'OsmParkingService($_cityId): fetch échoué — service non chargé');
      return;
    }

    try {
      final parsed = _parseResponse(raw);
      _wayRules.addAll(parsed);
      _loaded = true;
      await _saveCache(parsed);
      debugPrint(
          'OsmParkingService($_cityId): ${_wayRules.length} ways chargés (réseau)');
    } catch (e) {
      debugPrint('OsmParkingService($_cityId): parse failed: $e');
    }
  }

  /// Retourne les règles OSM pour un way ID précis, ou null si non trouvé.
  List<ParkingRule>? rulesForWayId(int wayId) {
    if (!_loaded) return null;
    return _wayRules[wayId];
  }

  bool get isLoaded => _loaded;
  int get wayCount => _wayRules.length;

  // ── Réseau ──────────────────────────────────────────────────────────────────

  Future<String?> _fetchOverpass(String bbox) async {
    final query = '[out:json][timeout:120];\n'
        '(\n'
        '  way["parking:lane:right"]($bbox);\n'
        '  way["parking:lane:left"]($bbox);\n'
        '  way["parking:lane:both"]($bbox);\n'
        ');\n'
        'out tags geom;';

    for (final url in _endpoints) {
      try {
        final resp = await http
            .post(
              Uri.parse(url),
              headers: _headers,
              body: 'data=${Uri.encodeComponent(query)}',
            )
            .timeout(const Duration(seconds: 130));

        if (resp.statusCode == 200) {
          debugPrint('OsmParking OK via $url');
          return resp.body;
        }
        debugPrint('OsmParking $url → ${resp.statusCode}');
      } catch (e) {
        debugPrint('OsmParking $url failed: $e');
      }
    }
    return null;
  }

  // ── Parsing ─────────────────────────────────────────────────────────────────

  Map<int, List<ParkingRule>> _parseResponse(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>;
    final result = <int, List<ParkingRule>>{};

    for (final el in elements) {
      final wayId = el['id'] as int;
      final tags = el['tags'] as Map<String, dynamic>?;
      if (tags == null) continue;

      final rules = _parseWayTags(tags);
      if (rules.isNotEmpty) {
        result[wayId] = rules;
      }
    }
    return result;
  }

  /// Convertit les tags parking:lane d'un way OSM en liste de [ParkingRule].
  List<ParkingRule> _parseWayTags(Map<String, dynamic> tags) {
    final rules = <ParkingRule>[];

    // Côtés à traiter selon les tags présents
    const sides = ['right', 'left', 'both'];
    for (final side in sides) {
      final laneVal = tags['parking:lane:$side'] as String?;
      if (laneVal == null) continue;

      // Valeur du tag parking:lane:side → autorisation de base
      final laneAllowed = _laneValueAllows(laneVal);

      // Aucune autorisation et pas de tag condition → règle noParking simple
      if (!laneAllowed) {
        rules.add(ParkingRule(
          type: RuleType.noParking,
          days: const [1, 2, 3, 4, 5, 6, 7],
          note: 'OSM parking:lane:$side=$laneVal',
        ));
        continue;
      }

      // Chercher les conditions numérotées d'abord (1, 2, 3…)
      // puis la condition de base (non numérotée)
      bool anyConditionParsed = false;

      for (int i = 1; i <= 5; i++) {
        final condKey = 'parking:condition:$side:$i';
        final condVal = tags[condKey] as String?;
        if (condVal == null) break;

        final rule = _buildRuleFromCondition(
          tags: tags,
          side: side,
          condVal: condVal,
          suffix: ':$i',
        );
        if (rule != null) {
          rules.add(rule);
          anyConditionParsed = true;
        }
      }

      // Condition de base (non numérotée)
      final condBase = tags['parking:condition:$side'] as String?;
      if (condBase != null) {
        final rule = _buildRuleFromCondition(
          tags: tags,
          side: side,
          condVal: condBase,
          suffix: '',
        );
        if (rule != null) {
          rules.add(rule);
          anyConditionParsed = true;
        }
      }

      // Condition par défaut (hors plage horaire explicite)
      final defaultCond = tags['parking:condition:$side:default'] as String?;
      if (defaultCond != null) {
        final ruleType = _conditionToRuleType(defaultCond);
        if (ruleType != null) {
          rules.add(ParkingRule(
            type: ruleType,
            days: const [1, 2, 3, 4, 5, 6, 7],
            note: 'OSM défaut côté $side',
          ));
          anyConditionParsed = true;
        }
      }

      // Aucune condition trouvée → parking autorisé sans restriction connue
      if (!anyConditionParsed) {
        rules.add(ParkingRule(
          type: RuleType.free,
          days: const [1, 2, 3, 4, 5, 6, 7],
          note: 'OSM parking:lane:$side=$laneVal (aucune condition)',
        ));
      }
    }

    return rules;
  }

  /// Construit une règle à partir d'une valeur de condition et ses métadonnées.
  /// [suffix] = '' pour la condition de base, ':1' pour la première numérotée, etc.
  ParkingRule? _buildRuleFromCondition({
    required Map<String, dynamic> tags,
    required String side,
    required String condVal,
    required String suffix,
  }) {
    final ruleType = _conditionToRuleType(condVal);
    if (ruleType == null) return null;

    // Plage horaire
    final interval =
        tags['parking:condition:$side$suffix:time_interval'] as String?;
    List<int> days = const [1, 2, 3, 4, 5, 6, 7];
    String? from;
    String? to;

    if (interval != null) {
      final parsed = _parseTimeInterval(interval);
      if (parsed != null) {
        days = parsed.days;
        from = parsed.from;
        to = parsed.to;
      }
    }

    // Durée max
    final maxstayRaw =
        tags['parking:condition:$side$suffix:maxstay'] as String?;
    final maxMinutes = maxstayRaw != null ? _parseMaxstay(maxstayRaw) : null;

    return ParkingRule(
      type: ruleType,
      days: days,
      from: from,
      to: to,
      maxMinutes: maxMinutes,
      note: 'OSM côté $side',
    );
  }

  // ── Interprétation des valeurs OSM ──────────────────────────────────────────

  /// true = le stationnement est a priori autorisé (position physique connue).
  bool _laneValueAllows(String val) {
    switch (val) {
      case 'no_parking':
      case 'no_stopping':
      case 'fire_lane':
      case 'no':
        return false;
      default:
        // parallel, diagonal, perpendicular, yes, marked, etc.
        return true;
    }
  }

  /// Convertit une valeur parking:condition en [RuleType], ou null si inconnu.
  RuleType? _conditionToRuleType(String val) {
    switch (val) {
      case 'no_parking':
      case 'no_stopping':
      case 'fire_lane':
        return RuleType.noParking;
      case 'ticket':
        return RuleType.meter;
      case 'residents':
        return RuleType.permitOnly;
      case 'customers':
        return RuleType.permitOrLimit;
      case 'free':
        return RuleType.free;
      case 'disc':
        return RuleType.free; // maxMinutes géré séparément
      default:
        return null;
    }
  }

  // ── Parsing des intervalles horaires OSM ────────────────────────────────────
  // Format OSM opening_hours simplifié : ex. "Mo-Fr 08:00-18:00", "Tu 07:00-09:00"
  // Cas supportés : "Mo-Fr 08:00-18:00", "Mo-Fr,Sa 09:00-21:00", "Su", "PH off"

  _TimeInterval? _parseTimeInterval(String raw) {
    // Nettoyer les espaces superflus
    final s = raw.trim();
    if (s.isEmpty || s == 'PH off' || s == '24/7') return null;

    // Séparer jours et heures : chercher le dernier bloc "HH:MM-HH:MM"
    final timeRegex = RegExp(r'(\d{1,2}:\d{2})-(\d{1,2}:\d{2})$');
    final timeMatch = timeRegex.firstMatch(s);

    String? from;
    String? to;
    String daysPart = s;

    if (timeMatch != null) {
      from = _normalizeTime(timeMatch.group(1)!);
      to = _normalizeTime(timeMatch.group(2)!);
      daysPart = s.substring(0, timeMatch.start).trim();
      // Enlever le séparateur espace entre jours et heures
      if (daysPart.endsWith(' ')) {
        daysPart = daysPart.trimRight();
      }
    }

    if (daysPart.isEmpty) {
      // Aucun jour spécifié → tous les jours
      return _TimeInterval(
        days: const [1, 2, 3, 4, 5, 6, 7],
        from: from,
        to: to,
      );
    }

    final days = _parseDays(daysPart);
    if (days.isEmpty) return null;

    return _TimeInterval(days: days, from: from, to: to);
  }

  /// "8:00" → "08:00", "18:00" → "18:00"
  String _normalizeTime(String t) {
    final parts = t.split(':');
    final h = parts[0].padLeft(2, '0');
    final m = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
    return '$h:$m';
  }

  /// Convertit une expression de jours OSM en liste d'entiers (1=Lun … 7=Dim).
  ///
  /// Exemples :
  ///   "Mo-Fr"     → [1,2,3,4,5]
  ///   "Mo-Fr,Sa"  → [1,2,3,4,5,6]
  ///   "Sa-Su"     → [6,7]
  ///   "Tu"        → [2]
  List<int> _parseDays(String expr) {
    const dayMap = {
      'Mo': 1,
      'Tu': 2,
      'We': 3,
      'Th': 4,
      'Fr': 5,
      'Sa': 6,
      'Su': 7,
    };

    final result = <int>{};

    // Plusieurs groupes séparés par virgule : "Mo-Fr,Sa"
    for (final part in expr.split(',')) {
      final p = part.trim();
      if (p.isEmpty) continue;

      if (p.contains('-')) {
        // Plage : "Mo-Fr", "Sa-Su"
        final ends = p.split('-');
        if (ends.length != 2) continue;
        final start = dayMap[ends[0].trim()];
        final end = dayMap[ends[1].trim()];
        if (start == null || end == null) continue;
        if (start <= end) {
          for (int d = start; d <= end; d++) {
            result.add(d);
          }
        } else {
          // Wrap-around possible (Sa-Mo) — peu commun mais géré
          for (int d = start; d <= 7; d++) {
            result.add(d);
          }
          for (int d = 1; d <= end; d++) {
            result.add(d);
          }
        }
      } else {
        // Jour seul : "Tu"
        final d = dayMap[p];
        if (d != null) result.add(d);
      }
    }

    final sorted = result.toList()..sort();
    return sorted;
  }

  // ── Parsing de maxstay ──────────────────────────────────────────────────────
  // Formats : "2 hours", "120", "30 min", "1 hour 30 min", "90 minutes"

  int? _parseMaxstay(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return null;

    // Nombre seul → minutes
    if (RegExp(r'^\d+$').hasMatch(s)) {
      return int.tryParse(s);
    }

    int total = 0;

    // Heures
    final hoursMatch = RegExp(r'(\d+)\s*h(?:our(?:s)?)?').firstMatch(s);
    if (hoursMatch != null) {
      total += (int.tryParse(hoursMatch.group(1)!) ?? 0) * 60;
    }

    // Minutes
    final minMatch = RegExp(r'(\d+)\s*min(?:ute(?:s)?)?').firstMatch(s);
    if (minMatch != null) {
      total += int.tryParse(minMatch.group(1)!) ?? 0;
    }

    return total > 0 ? total : null;
  }

  // ── Cache SharedPreferences ─────────────────────────────────────────────────

  Future<Map<int, List<ParkingRule>>?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tsStr = prefs.getString('$_cacheTsPrefix$_cityId');
      if (tsStr == null) return null;

      final ts = DateTime.parse(tsStr);
      if (DateTime.now().difference(ts) > _cacheTtl) {
        await prefs.remove('$_cachePrefix$_cityId');
        await prefs.remove('$_cacheTsPrefix$_cityId');
        return null;
      }

      final raw = prefs.getString('$_cachePrefix$_cityId');
      if (raw == null) return null;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) {
        final rulesList = (v as List<dynamic>)
            .map((r) => _ruleFromJson(r as Map<String, dynamic>))
            .whereType<ParkingRule>()
            .toList();
        return MapEntry(int.parse(k), rulesList);
      });
    } catch (e) {
      debugPrint('OsmParking cache load error $_cityId: $e');
      return null;
    }
  }

  Future<void> _saveCache(Map<int, List<ParkingRule>> data) async {
    if (data.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = data.map(
        (k, v) => MapEntry(k.toString(), v.map(_ruleToJson).toList()),
      );
      await prefs.setString('$_cachePrefix$_cityId', jsonEncode(encoded));
      await prefs.setString(
          '$_cacheTsPrefix$_cityId', DateTime.now().toIso8601String());
      debugPrint('OsmParking cache $_cityId sauvegardé — ${data.length} ways');
    } catch (e) {
      debugPrint('OsmParking cache save error $_cityId: $e');
    }
  }

  // ── Sérialisation ParkingRule ↔ JSON (cache uniquement) ─────────────────────

  Map<String, dynamic> _ruleToJson(ParkingRule r) => {
        't': r.type.index,
        'd': r.days,
        if (r.from != null) 'f': r.from,
        if (r.to != null) 'to': r.to,
        if (r.maxMinutes != null) 'm': r.maxMinutes,
        if (r.permitZone != null) 'pz': r.permitZone,
        if (r.ratePerHour != null) 'rh': r.ratePerHour,
        if (r.note != null) 'n': r.note,
        if (r.monthFrom != null) 'mf': r.monthFrom,
        if (r.monthTo != null) 'mt': r.monthTo,
        if (r.dayParity != null) 'dp': r.dayParity,
        if (r.monthParity != null) 'mp': r.monthParity,
        if (r.freeOnHoliday) 'fh': true,
      };

  ParkingRule? _ruleFromJson(Map<String, dynamic> j) {
    try {
      return ParkingRule(
        type: RuleType.values[j['t'] as int],
        days: (j['d'] as List<dynamic>).cast<int>(),
        from: j['f'] as String?,
        to: j['to'] as String?,
        maxMinutes: j['m'] as int?,
        permitZone: j['pz'] as String?,
        ratePerHour: (j['rh'] as num?)?.toDouble(),
        note: j['n'] as String?,
        monthFrom: j['mf'] as int?,
        monthTo: j['mt'] as int?,
        dayParity: j['dp'] as int?,
        monthParity: j['mp'] as int?,
        freeOnHoliday: (j['fh'] as bool?) ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}

// ── Modèle interne ─────────────────────────────────────────────────────────────

class _TimeInterval {
  final List<int> days;
  final String? from;
  final String? to;
  const _TimeInterval({required this.days, this.from, this.to});
}
