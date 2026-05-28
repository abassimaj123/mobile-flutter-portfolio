import 'package:latlong2/latlong.dart';
import 'parking_rule.dart';

/// Ville (ou région) supportée par ParkSmart.
/// Ajouter une ville = ajouter une entrée dans [CityRegistry] uniquement.
class City {
  final String id; // identifiant stable : 'capitale', 'montreal'
  final String name; // nom affiché : 'Québec', 'Montréal'
  final LatLng center; // centre carte au chargement
  final double defaultZoom;

  /// Bbox géographique pré-filtre : 'latMin,lonMin,latMax,lonMax'.
  /// Doit couvrir toutes les zones de [overpassAreaNames].
  final String overpassBbox;

  /// Noms OSM des frontières administratives (admin_level=8).
  ///
  /// - Liste vide   → bbox seule (fallback)
  /// - 1 élément    → filtre simple par municipalité
  /// - N éléments   → union des N municipalités dans une seule requête
  ///   (ex: ['Montréal', 'Laval', 'Longueuil'] → Grand Montréal)
  final List<String> overpassAreaNames;

  /// Noms de ville stockés dans les [StreetSegment] mock qui appartiennent
  /// à cette entrée de registre.
  ///
  /// Permet de regrouper plusieurs municipalités sous une seule City :
  ///   - 'capitale' → segmentCityNames: ['Québec', 'Lévis']
  ///   - 'montreal' → segmentCityNames: ['Montréal']
  ///
  /// Par défaut = [name] (cas simple : une ville = un nom de segment).
  final List<String> segmentCityNames;

  final List<ParkingRule> defaultRules;

  /// true  → les règles par défaut s'appliquent à toute la ville (ex: limite 2h
  ///          Québec/Lévis inscrite dans les règlements municipaux).
  ///          Les rues hors zone connue affichent la couleur réelle.
  ///
  /// false → les règles par défaut sont minimales (ex: Montréal = déneigement
  ///          seulement). Les rues hors zone connue affichent noData (gris)
  ///          pour être honnêtes sur l'absence de données par rue.
  final bool hasComprehensiveDefaults;

  const City({
    required this.id,
    required this.name,
    required this.center,
    required this.overpassBbox,
    required this.defaultRules,
    this.overpassAreaNames = const [],
    this.segmentCityNames = const [],
    this.hasComprehensiveDefaults = false,
    this.defaultZoom = 14.5,
  });

  /// Noms de segment effectifs : [segmentCityNames] si non vide, sinon [name].
  List<String> get effectiveSegmentCityNames =>
      segmentCityNames.isNotEmpty ? segmentCityNames : [name];
}
