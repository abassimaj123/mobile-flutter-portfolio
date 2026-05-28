import 'dart:ui' show Color;
import '../models/parking_rule.dart';
import '../models/street_segment.dart';

/// 3 couleurs uniquement — logique unifiée pour toutes les villes.
///
/// ## Règle de couleur
///   🟢 free       = tu peux stationner maintenant (libre, vignette avec 2h autorisée,
///                   parcomètre hors heures payantes)
///   🔵 meter      = tu peux stationner mais tu paies (parcomètre en heures payantes)
///   🔴 restricted = tu ne peux pas stationner (SRRR sans permis, interdit explicite)
///   ⬜ noData     = pas de données → pas de ligne affichée
///
/// ## Mappage RuleType → couleur
///   noParking    active → restricted  (interdit)
///   permitOnly   active → restricted  (SRRR = interdit sans permis résidents)
///   permitOrLimit active → free       (vignette QC : 2h autorisées pour tous)
///   meter        active → meter       (parcomètre en heures payantes)
///   meter/free   inactive / aucune règle → free (libre)
enum ParkingColor { free, meter, restricted, noData }

class RuleResult {
  final ParkingColor color;
  final ParkingRule? activeRule;
  final DateTime? nextChangeTime;
  final bool hasTimeLimit;
  final String colorHex;
  final String label;

  const RuleResult({
    required this.color,
    this.activeRule,
    this.nextChangeTime,
    required this.hasTimeLimit,
    required this.colorHex,
    required this.label,
  });

  Color get colorValue {
    final hex = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

class RuleEngine {
  static const String colorFree = '#00C853'; // 🟢
  static const String colorMeter = '#1565C0'; // 🔵
  static const String colorRestricted = '#D32F2F'; // 🔴
  static const String colorNoData = '#9E9E9E'; // ⬜ (non affiché)

  // ── Évaluation segment mock complet (avec nextChange) ───────────────────

  static RuleResult evaluate(StreetSegment segment, DateTime dt) {
    if (segment.rules.isEmpty) {
      return const RuleResult(
        color: ParkingColor.free,
        hasTimeLimit: false,
        colorHex: colorFree,
        label: 'Stationnement libre',
      );
    }
    final match = _findActive(segment.rules, dt);
    final result = _toResult(match);
    return RuleResult(
      color: result.color,
      activeRule: result.activeRule,
      nextChangeTime: nextChange(segment, dt),
      hasTimeLimit: result.hasTimeLimit,
      colorHex: result.colorHex,
      label: result.label,
    );
  }

  /// Prochain changement de couleur dans les 24 prochaines heures.
  static DateTime? nextChange(StreetSegment segment, DateTime dt) {
    if (segment.rules.isEmpty) return null;
    final current = _colorOnly(segment.rules, dt);
    DateTime check = dt.add(const Duration(minutes: 1));
    final limit = dt.add(const Duration(hours: 24));
    while (check.isBefore(limit)) {
      if (_colorOnly(segment.rules, check) != current) return check;
      check = check.add(const Duration(minutes: 1));
    }
    return null;
  }

  // ── Évaluation règles brutes (bulk streets, city defaults) ──────────────

  static RuleResult evaluateRules(List<ParkingRule> rules, DateTime dt) {
    if (rules.isEmpty) {
      return const RuleResult(
        color: ParkingColor.free,
        hasTimeLimit: false,
        colorHex: colorFree,
        label: 'Stationnement libre',
      );
    }
    return _toResult(_findActive(rules, dt));
  }

  // ── Logique centrale ────────────────────────────────────────────────────

  static _Match _findActive(List<ParkingRule> rules, DateTime dt) {
    ParkingRule? noParking;
    ParkingRule? permit; // permitOnly  → restricted
    ParkingRule? limited; // permitOrLimit → free (2h autorisé)
    ParkingRule? meter;
    ParkingRule? free;

    for (final r in rules) {
      if (!r.appliesAt(dt)) continue;
      switch (r.type) {
        case RuleType.noParking:
          noParking ??= r;
        case RuleType.permitOnly:
          permit ??= r;
        case RuleType.permitOrLimit:
          limited ??= r;
        case RuleType.meter:
          meter ??= r;
        case RuleType.free:
          free ??= r;
      }
    }
    return _Match(
        noParking: noParking,
        permit: permit,
        limited: limited,
        meter: meter,
        free: free);
  }

  static RuleResult _toResult(_Match m) {
    // Interdit : no-parking explicite OU SRRR (interdit sans permis résidents)
    if (m.noParking != null) {
      return RuleResult(
        color: ParkingColor.restricted,
        activeRule: m.noParking,
        hasTimeLimit: false,
        colorHex: colorRestricted,
        label: 'Stationnement interdit',
      );
    }
    if (m.permit != null) {
      return RuleResult(
        color: ParkingColor.restricted,
        activeRule: m.permit,
        hasTimeLimit: false,
        colorHex: colorRestricted,
        label: 'Permis résidents requis',
      );
    }
    // Parcomètre en heures payantes
    if (m.meter != null) {
      return RuleResult(
        color: ParkingColor.meter,
        activeRule: m.meter,
        hasTimeLimit: m.meter!.maxMinutes != null,
        colorHex: colorMeter,
        label: 'Parcomètre',
      );
    }
    // Vignette QC avec 2h autorisées → libre (vert)
    if (m.limited != null) {
      return RuleResult(
        color: ParkingColor.free,
        activeRule: m.limited,
        hasTimeLimit: true,
        colorHex: colorFree,
        label: '2h max · Libre sans vignette',
      );
    }
    // Règle free explicite ou aucune règle active → libre
    return RuleResult(
      color: ParkingColor.free,
      activeRule: m.free,
      hasTimeLimit: (m.free?.maxMinutes ?? 0) > 0,
      colorHex: colorFree,
      label: 'Stationnement libre',
    );
  }

  static ParkingColor _colorOnly(List<ParkingRule> rules, DateTime dt) =>
      _toResult(_findActive(rules, dt)).color;

  static String colorHexForColor(ParkingColor color) {
    switch (color) {
      case ParkingColor.free:
        return colorFree;
      case ParkingColor.meter:
        return colorMeter;
      case ParkingColor.restricted:
        return colorRestricted;
      case ParkingColor.noData:
        return colorNoData;
    }
  }
}

class _Match {
  final ParkingRule? noParking;
  final ParkingRule? permit;
  final ParkingRule? limited;
  final ParkingRule? meter;
  final ParkingRule? free;
  const _Match(
      {this.noParking, this.permit, this.limited, this.meter, this.free});
}
