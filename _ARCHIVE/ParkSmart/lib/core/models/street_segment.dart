import 'parking_rule.dart';

enum DataSource { official, bylaw, reddit, nextdoor, googleMaps, validated }

extension DataSourceLabel on DataSource {
  String get label {
    switch (this) {
      case DataSource.official:
        return 'Officiel';
      case DataSource.bylaw:
        return 'Règlement';
      case DataSource.reddit:
        return 'Reddit';
      case DataSource.nextdoor:
        return 'Nextdoor';
      case DataSource.googleMaps:
        return 'Google Maps';
      case DataSource.validated:
        return 'Validé';
    }
  }

  String get icon {
    switch (this) {
      case DataSource.official:
        return '🏛️';
      case DataSource.bylaw:
        return '📜';
      case DataSource.reddit:
        return '👥';
      case DataSource.nextdoor:
        return '🏘️';
      case DataSource.googleMaps:
        return '🗺️';
      case DataSource.validated:
        return '✓';
    }
  }
}

class StreetSegment {
  final String id;
  final String streetName;
  final String city; // "Québec" or "Lévis"
  final String side; // "Nord", "Sud", "Est", "Ouest", "Les deux côtés"

  /// Identifiants OSM uniques du/des tronçon(s) de route.
  ///
  /// Référence primaire pour la géométrie — stable, exact, sans ambiguïté de nom.
  /// Plusieurs IDs = ways consécutifs qui forment un seul segment logique.
  ///
  /// Workflow nouvelle ville :
  ///   1. Ouvrir overpass-turbo.eu ou JOSM
  ///   2. Cliquer la rue → noter l'ID du way
  ///   3. Mettre ici → l'app fetch la géométrie exacte au 1er lancement
  ///
  /// Si vide → fallback sur [coordinates] (coords embarquées en dur).
  final List<int> osmWayIds;

  /// Géométrie de secours (fallback) ou override manuel.
  /// Utilisé quand [osmWayIds] est vide ou que le fetch réseau échoue.
  /// Format : [[longitude, latitude], ...]
  final List<List<double>> coordinates;

  final List<ParkingRule> rules;
  final double confidence; // 0.0 to 1.0
  final String sourceDate; // "2026-02-01"
  final List<DataSource> sources;
  final String? notes;

  const StreetSegment({
    required this.id,
    required this.streetName,
    required this.city,
    required this.side,
    this.osmWayIds = const [],
    required this.coordinates,
    required this.rules,
    required this.confidence,
    required this.sourceDate,
    required this.sources,
    this.notes,
  });
}
