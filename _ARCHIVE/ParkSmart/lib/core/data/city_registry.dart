import 'package:latlong2/latlong.dart';
import '../models/city.dart';
import 'city_defaults.dart';

/// Registre de toutes les villes supportées par ParkSmart.
///
/// ## Ajouter une ville
/// Une seule entrée ici — tout le reste (Overpass, cache, UI, GPS) s'adapte.
///
/// ## Capitale-Nationale (Québec + Lévis)
/// Une seule entrée couvre les deux rives du Saint-Laurent.
/// Le filtre admin_level=8 avec union ['Québec', 'Lévis'] garantit que seules
/// les rues de ces deux municipalités sont incluses.
/// segmentCityNames: ['Québec', 'Lévis'] → les segments mock des deux villes
/// s'affichent quand cette entrée est sélectionnée.
///
/// ## Grand Montréal
/// Montréal + Laval + Longueuil dans une seule entrée via union Overpass.
/// L'utilisateur voit "Montréal" — le fetch couvre les 3 municipalités.
class CityRegistry {
  static const List<City> supported = [
    // ── Capitale-Nationale (Québec + Lévis) ────────────────────────────────
    City(
      id: 'capitale',
      name: 'Québec',
      center: LatLng(46.7800, -71.2200),
      // Bbox couvre les deux rives : rive nord (Québec) + rive sud (Lévis)
      overpassBbox: '46.580,-71.600,46.960,-70.880',
      overpassAreaNames: ['Québec', 'Lévis'],
      segmentCityNames: ['Québec', 'Lévis'],
      defaultRules: CityDefaults.quebecRules,
      hasComprehensiveDefaults: true, // limite 2h inscrite dans R.V.Q. 1400
      defaultZoom: 12.5,
    ),

    // ── Grand Montréal (Île + Laval + Longueuil) ──────────────────────────
    City(
      id: 'montreal',
      name: 'Montréal',
      center: LatLng(45.5317, -73.6017),
      // Bbox couvre les 3 municipalités
      overpassBbox: '45.360,-74.050,45.730,-73.340',
      overpassAreaNames: ['Montréal', 'Laval', 'Longueuil'],
      segmentCityNames: ['Montréal'],
      defaultRules: CityDefaults.montrealRules,
      // true : rues hors zone connue → règle par défaut (libre + déneigement Nov-Mar).
      // La majorité des rues MTL sont libres ; les zones SRRR/parcomètre
      // sont capturées par ZoneRegistry. Gris = trop pessimiste.
      hasComprehensiveDefaults: true,
      defaultZoom: 12.0,
    ),

    // ── Vancouver (BC) ────────────────────────────────────────────────────
    City(
      id: 'vancouver',
      name: 'Vancouver',
      center: LatLng(49.2827, -123.1207),
      overpassBbox: '49.000,-123.270,49.370,-122.960',
      overpassAreaNames: ['Vancouver'],
      segmentCityNames: ['Vancouver'],
      defaultRules: CityDefaults.vancouverRules,
      // false : couverture en cours de construction via ticket inference + OSM
      hasComprehensiveDefaults: false,
      defaultZoom: 12.0,
    ),

    // ── New York City ─────────────────────────────────────────────────────
    City(
      id: 'nyc',
      name: 'New York',
      center: LatLng(40.7128, -74.0060),
      overpassBbox: '40.500,-74.260,40.930,-73.700',
      overpassAreaNames: ['New York City'],
      segmentCityNames: ['New York City'],
      defaultRules: CityDefaults.nycRules,
      hasComprehensiveDefaults: false,
      defaultZoom: 12.0,
    ),

    // ── Los Angeles ───────────────────────────────────────────────────────
    City(
      id: 'la',
      name: 'Los Angeles',
      center: LatLng(34.0522, -118.2437),
      overpassBbox: '33.700,-118.670,34.340,-118.160',
      overpassAreaNames: ['Los Angeles'],
      segmentCityNames: ['Los Angeles'],
      defaultRules: CityDefaults.laRules,
      hasComprehensiveDefaults: false,
      defaultZoom: 11.5,
    ),

    // ── Chicago ───────────────────────────────────────────────────────────
    City(
      id: 'chicago',
      name: 'Chicago',
      center: LatLng(41.8781, -87.6298),
      overpassBbox: '41.640,-87.940,42.030,-87.520',
      overpassAreaNames: ['Chicago'],
      segmentCityNames: ['Chicago'],
      defaultRules: CityDefaults.chicagoRules,
      hasComprehensiveDefaults: false,
      defaultZoom: 12.0,
    ),

    // ── San Francisco ─────────────────────────────────────────────────────
    City(
      id: 'sf',
      name: 'San Francisco',
      center: LatLng(37.7749, -122.4194),
      overpassBbox: '37.630,-122.520,37.830,-121.980',
      overpassAreaNames: ['San Francisco'],
      segmentCityNames: ['San Francisco'],
      defaultRules: CityDefaults.sfRules,
      hasComprehensiveDefaults: false,
      defaultZoom: 12.5,
    ),

    // ── Seattle ───────────────────────────────────────────────────────────
    City(
      id: 'seattle',
      name: 'Seattle',
      center: LatLng(47.6062, -122.3321),
      overpassBbox: '47.490,-122.460,47.740,-122.220',
      overpassAreaNames: ['Seattle'],
      segmentCityNames: ['Seattle'],
      defaultRules: CityDefaults.seattleRules,
      hasComprehensiveDefaults: false,
      defaultZoom: 12.0,
    ),

    // ── Toronto ───────────────────────────────────────────────────────────
    City(
      id: 'toronto',
      name: 'Toronto',
      center: LatLng(43.6532, -79.3832),
      overpassBbox: '43.580,-79.640,43.860,-79.120',
      overpassAreaNames: ['Toronto'],
      segmentCityNames: ['Toronto'],
      defaultRules: CityDefaults.torontoRules,
      hasComprehensiveDefaults: false,
      defaultZoom: 11.5,
    ),

    // ── Boston ────────────────────────────────────────────────────────────
    City(
      id: 'boston',
      name: 'Boston',
      center: LatLng(42.3601, -71.0589),
      overpassBbox: '42.300,-71.180,42.420,-70.990',
      overpassAreaNames: ['Boston'],
      segmentCityNames: ['Boston'],
      defaultRules: CityDefaults.bostonRules,
      hasComprehensiveDefaults: false,
      defaultZoom: 12.0,
    ),

    // ── Ottawa ────────────────────────────────────────────────────────────
    City(
      id: 'ottawa',
      name: 'Ottawa',
      center: LatLng(45.4215, -75.6972),
      overpassBbox: '45.250,-76.000,45.550,-75.500',
      overpassAreaNames: ['Ottawa'],
      segmentCityNames: ['Ottawa'],
      defaultRules: CityDefaults.ottawaRules,
      hasComprehensiveDefaults: false,
      defaultZoom: 12.0,
    ),

    // ── Calgary ───────────────────────────────────────────────────────────
    City(
      id: 'calgary',
      name: 'Calgary',
      center: LatLng(51.0447, -114.0719),
      overpassBbox: '50.850,-114.300,51.180,-113.850',
      overpassAreaNames: ['Calgary'],
      segmentCityNames: ['Calgary'],
      defaultRules: CityDefaults.calgaryRules,
      hasComprehensiveDefaults: false,
      defaultZoom: 11.5,
    ),

    // ── Washington DC ─────────────────────────────────────────────────────
    City(
      id: 'dc',
      name: 'Washington DC',
      center: LatLng(38.9072, -77.0369),
      overpassBbox: '38.800,-77.120,38.990,-76.910',
      overpassAreaNames: ['District of Columbia'],
      segmentCityNames: ['District of Columbia'],
      defaultRules: CityDefaults.dcRules,
      hasComprehensiveDefaults: false,
      defaultZoom: 12.0,
    ),

    // ── Portland, OR ──────────────────────────────────────────────────────
    City(
      id: 'portland',
      name: 'Portland',
      center: LatLng(45.5152, -122.6784),
      overpassBbox: '45.430,-122.820,45.650,-122.450',
      overpassAreaNames: ['Portland'],
      segmentCityNames: ['Portland'],
      defaultRules: CityDefaults.portlandRules,
      hasComprehensiveDefaults: false,
      defaultZoom: 12.0,
    ),

    // ── Philadelphia ──────────────────────────────────────────────────────
    City(
      id: 'philly',
      name: 'Philadelphia',
      center: LatLng(39.9526, -75.1652),
      overpassBbox: '39.870,-75.300,40.140,-74.950',
      overpassAreaNames: ['Philadelphia'],
      segmentCityNames: ['Philadelphia'],
      defaultRules: CityDefaults.phillyRules,
      hasComprehensiveDefaults: false,
      defaultZoom: 11.5,
    ),

    // ── Denver ────────────────────────────────────────────────────────────
    City(
      id: 'denver',
      name: 'Denver',
      center: LatLng(39.7392, -104.9903),
      overpassBbox: '39.600,-105.100,39.850,-104.850',
      overpassAreaNames: ['Denver'],
      segmentCityNames: ['Denver'],
      defaultRules: CityDefaults.denverRules,
      hasComprehensiveDefaults: false,
      defaultZoom: 12.0,
    ),

    // ── Austin ────────────────────────────────────────────────────────────
    City(
      id: 'austin',
      name: 'Austin',
      center: LatLng(30.2672, -97.7431),
      overpassBbox: '30.180,-97.900,30.450,-97.600',
      overpassAreaNames: ['Austin'],
      segmentCityNames: ['Austin'],
      defaultRules: CityDefaults.austinRules,
      hasComprehensiveDefaults: false,
      defaultZoom: 11.5,
    ),
  ];

  static City get defaultCity => supported.first;

  static City? findById(String id) => supported.cast<City?>().firstWhere(
        (c) => c?.id == id,
        orElse: () => null,
      );

  /// Ville dont le centre est le plus proche de [position].
  static City nearest(LatLng position) {
    City best = supported.first;
    double bestDist = double.infinity;
    for (final city in supported) {
      final dlat = city.center.latitude - position.latitude;
      final dlon = city.center.longitude - position.longitude;
      final d2 = dlat * dlat + dlon * dlon;
      if (d2 < bestDist) {
        bestDist = d2;
        best = city;
      }
    }
    return best;
  }
}
