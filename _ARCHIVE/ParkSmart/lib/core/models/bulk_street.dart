/// Rue OSM chargée en masse depuis l'Overpass API.
///
/// Contrairement à [StreetSegment] (données vérifiées avec règles précises),
/// une [BulkStreet] est chargée automatiquement pour toute rue nommée dans
/// la bbox de la ville. Les règles applicables sont les règles par défaut
/// de la ville (voir [CityDefaults] via [CityRegistry.findById]).
///
/// ## Stockage JSON (compact)
/// Clés courtes pour réduire la taille dans SharedPreferences :
///   id → osmWayId  |  n → name  |  c → city  |  g → coordinates
class BulkStreet {
  final int osmWayId;
  final String name;
  final String
      city; // identifiant stable de ville : 'quebec' | 'levis' | 'montreal'

  /// Géométrie du tronçon : [[longitude, latitude], ...]
  /// Coordonnées à 5 décimales (≈ 1 m de précision, suffisant pour l'affichage).
  final List<List<double>> coordinates;

  const BulkStreet({
    required this.osmWayId,
    required this.name,
    required this.city,
    required this.coordinates,
  });

  Map<String, dynamic> toJson() => {
        'id': osmWayId,
        'n': name,
        'c': city,
        'g': coordinates,
      };

  factory BulkStreet.fromJson(Map<String, dynamic> json) => BulkStreet(
        osmWayId: json['id'] as int,
        name: json['n'] as String,
        city: json['c'] as String,
        coordinates: (json['g'] as List<dynamic>)
            .map<List<double>>((c) => List<double>.from(c as List))
            .toList(),
      );
}
