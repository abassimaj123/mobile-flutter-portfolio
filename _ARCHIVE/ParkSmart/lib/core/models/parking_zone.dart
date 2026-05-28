import 'parking_rule.dart';

/// Zone géographique de stationnement avec règles homogènes.
///
/// Représente un secteur de la ville (Centre-Ville, Plateau, Vieux-Québec…)
/// où toutes les rues partagent les mêmes règles de stationnement.
///
/// ## Architecture future (BD)
///   - Table `parking_zones` : id, city_id, name, geometry (PostGIS POLYGON)
///   - Table `zone_rules`    : zone_id → parking_rule_id (many-to-many)
///   - Lookup SQL : `ST_Contains(zone.geometry, ST_Point(lon, lat))`
///   - Priorité   : zone_rule > city_default_rule
///
/// ## V1 (mock)
///   - Polygones rectangulaires approximatifs des quartiers réels
///   - Règles codées manuellement selon les règlements municipaux officiels
///   - Ray-casting O(n) pour le lookup — n ≤ 20 zones par ville
class ParkingZone {
  final String id;
  final String name;
  final List<ParkingRule> rules;

  /// Polygone fermé en coordonnées [lon, lat].
  /// Premier et dernier point identiques (convention GeoJSON).
  final List<List<double>> polygon;

  const ParkingZone({
    required this.id,
    required this.name,
    required this.rules,
    required this.polygon,
  });

  /// Ray-casting algorithm — détermine si (lon, lat) est dans le polygone.
  ///
  /// Complexité O(n), n = nombre de sommets.
  /// Fiable pour les polygones convexes ET concaves.
  bool contains(double lon, double lat) {
    bool inside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      final xi = polygon[i][0], yi = polygon[i][1];
      final xj = polygon[j][0], yj = polygon[j][1];
      if (((yi > lat) != (yj > lat)) &&
          lon < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }
}
