import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bulk_street.dart';
import '../models/city.dart';

/// Fetches real road geometries from OpenStreetMap Overpass API.
///
/// ## Architecture
///
/// Ancienne approche (nom de rue → géométrie) :
///   - Matching par nom instable (accents, abréviations, plusieurs ways par nom)
///   - Retourne le PLUS LONG tronçon → pas forcément le bon
///   - Résultat : lignes flottantes, mauvaise section affichée
///
/// Nouvelle approche (OSM way ID → géométrie) :
///   - ID entier stable et unique par tronçon OSM
///   - Requête exacte : `way(id:123,456); out geom;`
///   - Résultat garanti : le bon tronçon, les bons nœuds, les vraies courbes
///
/// ## Workflow nouvelle ville
///   1. Ouvrir https://overpass-turbo.eu ou JOSM
///   2. Cliquer le tronçon voulu → copier son ID (ex: 243597658)
///   3. Mettre cet ID dans `osmWayIds` du StreetSegment
///   4. Premier lancement de l'app → fetch auto, cache 7 jours
///
/// Le cache est indexé par way ID (Map<int, coords>), pas par nom.
/// Changement de nom de rue dans OSM ? Aucun impact. L'ID ne change jamais.
class OverpassService {
  /// Endpoints Overpass tentés dans l'ordre — fallback si 4xx/5xx/timeout.
  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.openstreetmap.fr/api/interpreter',
  ];

  static const _cacheKey = 'osm_ways_v1'; // indexé par way ID
  static const _cacheTsKey = 'osm_ways_ts_v1';
  static const _cacheTtl = Duration(days: 7); // géométrie stable, TTL long

  /// Headers communs — User-Agent requis par certains serveurs Overpass.
  static const _headers = {
    'Content-Type': 'application/x-www-form-urlencoded',
    'User-Agent':
        'ParkSmart/1.0 (Flutter mobile; OSM data; contact:parksmart@app.local)',
    'Accept': 'application/json',
  };

  // ── API publique ───────────────────────────────────────────────────────────

  /// Retourne la géométrie pour un ensemble d'IDs OSM.
  /// Charge depuis le cache d'abord — réseau seulement pour les IDs manquants.
  static Future<Map<int, List<List<double>>>> fetchByIds(Set<int> ids) async {
    if (ids.isEmpty) return {};

    final cached = await _loadCache();

    // IDs déjà dans le cache
    final hit = <int, List<List<double>>>{};
    final miss = <int>{};
    for (final id in ids) {
      final g = cached[id];
      if (g != null) {
        hit[id] = g;
      } else {
        miss.add(id);
      }
    }

    if (miss.isEmpty) {
      debugPrint('Overpass: ${hit.length} ways depuis cache (0 réseau)');
      return hit;
    }

    // Fetch only the missing IDs
    final fetched = await _fetchIds(miss);
    await _mergeAndSaveCache(fetched);

    debugPrint('Overpass: ${hit.length} cache + ${fetched.length} réseau '
        '(${miss.length - fetched.length} introuvables)');
    return {...hit, ...fetched};
  }

  // ── Réseau ────────────────────────────────────────────────────────────────

  static Future<Map<int, List<List<double>>>> _fetchIds(Set<int> ids) async {
    final idStr = ids.join(',');
    final query = '[out:json][timeout:30]; way(id:$idStr); out geom;';

    final body = await _postWithFallback(query, const Duration(seconds: 35));
    if (body == null) return {};

    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final elements = data['elements'] as List<dynamic>;
      final result = <int, List<List<double>>>{};

      for (final el in elements) {
        final wayId = el['id'] as int;
        final geom = el['geometry'] as List<dynamic>?;
        if (geom == null || geom.length < 2) continue;

        result[wayId] = geom
            .map<List<double>>((n) => [
                  (n['lon'] as num).toDouble(),
                  (n['lat'] as num).toDouble(),
                ])
            .toList();
      }
      return result;
    } catch (e) {
      debugPrint('Overpass parse failed: $e');
      return {};
    }
  }

  /// POST la [query] sur les endpoints dans l'ordre ; retourne le body du
  /// premier succès (200), ou null si tous échouent.
  static Future<String?> _postWithFallback(
      String query, Duration timeout) async {
    for (final url in _endpoints) {
      try {
        final resp = await http
            .post(
              Uri.parse(url),
              headers: _headers,
              body: 'data=${Uri.encodeComponent(query)}',
            )
            .timeout(timeout);

        if (resp.statusCode == 200) {
          debugPrint('Overpass OK via $url');
          return resp.body;
        }
        debugPrint('Overpass $url → ${resp.statusCode}');
      } catch (e) {
        debugPrint('Overpass $url failed: $e');
      }
    }
    return null;
  }

  // ── Cache SharedPreferences ───────────────────────────────────────────────

  static Future<Map<int, List<List<double>>>> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tsStr = prefs.getString(_cacheTsKey);
      if (tsStr != null) {
        final ts = DateTime.parse(tsStr);
        if (DateTime.now().difference(ts) > _cacheTtl) {
          // Cache expiré — vider proprement
          await prefs.remove(_cacheKey);
          await prefs.remove(_cacheTsKey);
          return {};
        }
      }

      final raw = prefs.getString(_cacheKey);
      if (raw == null) return {};

      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) {
        final coords = (v as List)
            .map<List<double>>((c) => List<double>.from(c as List))
            .toList();
        return MapEntry(int.parse(k), coords);
      });
    } catch (e) {
      debugPrint('Cache load error: $e');
      return {};
    }
  }

  static Future<void> _mergeAndSaveCache(
      Map<int, List<List<double>>> newData) async {
    if (newData.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = await _loadCache();
      final merged = {...existing, ...newData};

      // Clés stringifiées pour JSON
      final encoded = merged.map((k, v) => MapEntry(k.toString(), v));
      await prefs.setString(_cacheKey, jsonEncode(encoded));
      await prefs.setString(_cacheTsKey, DateTime.now().toIso8601String());
      debugPrint('Overpass: cache mis à jour — ${merged.length} ways');
    } catch (e) {
      debugPrint('Cache save error: $e');
    }
  }

  // ── Bulk streets ──────────────────────────────────────────────────────────

  /// Cache namespace pour les rues en masse (séparé du cache de segments).
  /// v5 : city IDs remappés (quebec+levis → capitale, laval+longueuil → montreal).
  static const _bulkCachePrefix = 'osm_bulk_ways_v5_';
  static const _bulkTsPrefix = 'osm_bulk_ts_v5_';
  static const _bulkCacheTtl = Duration(days: 30); // géométrie stable

  /// Construit la requête Overpass pour une ville ou région.
  ///
  /// - 0 area  → bbox seule (fallback)
  /// - 1 area  → filtre admin_level=8 sur la municipalité
  /// - N areas → union des N municipalités (ex: Grand Montréal)
  ///
  /// La bbox est toujours incluse comme pré-filtre géographique côté serveur.
  static String _buildBulkQuery(City city) {
    const hw =
        r'"highway"~"^(residential|tertiary|unclassified|living_street)$"';
    const acc = r'["name"]["access"!="private"]["access"!="no"]';
    final box = city.overpassBbox;

    final areas = city.overpassAreaNames;

    if (areas.isEmpty) {
      // Fallback : bbox uniquement
      return '[out:json][timeout:90];\n'
          'way[$hw]$acc($box);\n'
          'out geom;';
    }

    if (areas.length == 1) {
      // Filtre simple par frontière municipale + bbox
      final n = areas.first;
      return '[out:json][timeout:120];\n'
          'area["name"="$n"]["boundary"="administrative"'
          ']["admin_level"="8"]->.a;\n'
          'way[$hw]$acc(area.a)($box);\n'
          'out geom;';
    }

    // Union de N municipalités → une seule requête, une seule réponse
    // Chaque area reçoit un alias lettre : .a, .b, .c …
    final buf = StringBuffer('[out:json][timeout:180];\n');
    for (int i = 0; i < areas.length; i++) {
      final alias = String.fromCharCode('a'.codeUnitAt(0) + i);
      buf.write('area["name"="${areas[i]}"]["boundary"="administrative"'
          ']["admin_level"="8"]->.$alias;\n');
    }
    buf.write('(\n');
    for (int i = 0; i < areas.length; i++) {
      final alias = String.fromCharCode('a'.codeUnitAt(0) + i);
      buf.write('  way[$hw]$acc(area.$alias)($box);\n');
    }
    buf.write(');\nout geom;');
    return buf.toString();
  }

  /// Charge les rues avec zones de stationnement probables pour une ville.
  ///
  /// ## Filtre highway
  /// On retient uniquement les rues où le stationnement sur rue est la norme :
  ///   - residential    : rues résidentielles            (≤ 50 km/h)
  ///   - tertiary       : collectrices locales           (≤ 50 km/h)
  ///   - unclassified   : voies locales non classifiées  (≤ 50 km/h)
  ///   - living_street  : rues partagées piétons/autos   (≤ 20 km/h)
  ///
  /// Exclus intentionnellement :
  ///   - primary / secondary : artères 60-90 km/h, stationnement rare/interdit
  ///   - trunk / motorway    : voies rapides, stationnement impossible
  ///   - service             : entrées privées, parkings, ruelles
  ///
  /// ## Résultat
  /// Mis en cache 30 jours dans SharedPreferences.
  /// En cas d'erreur réseau → [] (app fonctionnelle sans).
  static Future<List<BulkStreet>> fetchBulkStreets(City city) async {
    // ── Cache hit ? ──────────────────────────────────────────────────────
    final cached = await _loadBulkCache(city.id);
    if (cached != null) return cached;

    // ── Fetch réseau ─────────────────────────────────────────────────────
    final query = _buildBulkQuery(city);
    // Union query (N villes) = plus lente → timeout plus long
    final timeout = city.overpassAreaNames.length > 1
        ? const Duration(seconds: 190)
        : city.overpassAreaNames.isNotEmpty
            ? const Duration(seconds: 130)
            : const Duration(seconds: 100);

    final body = await _postWithFallback(query, timeout);
    if (body == null) {
      debugPrint('Bulk fetch ${city.id}: tous les endpoints ont échoué');
      return [];
    }

    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final elements = data['elements'] as List<dynamic>;
      final result = <BulkStreet>[];

      for (final el in elements) {
        final id = el['id'] as int;
        final tags = el['tags'] as Map<String, dynamic>?;
        if (tags == null) continue;

        // Préférer le nom français si disponible
        final name = (tags['name:fr'] ?? tags['name']) as String?;
        if (name == null || name.isEmpty) continue;

        final geom = el['geometry'] as List<dynamic>?;
        if (geom == null || geom.length < 2) continue;

        result.add(BulkStreet(
          osmWayId: id,
          name: name,
          city: city.id, // identifiant stable ('quebec', 'levis', 'montreal')
          // Arrondi à 5 décimales ≈ 1 m — réduit la taille JSON ~30 %
          coordinates: geom.map<List<double>>((n) {
            final lon = (n['lon'] as num).toDouble();
            final lat = (n['lat'] as num).toDouble();
            return [
              double.parse(lon.toStringAsFixed(5)),
              double.parse(lat.toStringAsFixed(5)),
            ];
          }).toList(),
        ));
      }

      debugPrint('Bulk ${city.id}: ${result.length} rues chargées');
      await _saveBulkCache(city.id, result);
      return result;
    } catch (e) {
      debugPrint('Bulk fetch ${city.id} failed: $e');
      return [];
    }
  }

  static Future<List<BulkStreet>?> _loadBulkCache(String cityId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tsStr = prefs.getString('$_bulkTsPrefix$cityId');
      if (tsStr == null) return null;

      final ts = DateTime.parse(tsStr);
      if (DateTime.now().difference(ts) > _bulkCacheTtl) {
        // Cache expiré
        await prefs.remove('$_bulkCachePrefix$cityId');
        await prefs.remove('$_bulkTsPrefix$cityId');
        return null;
      }

      final raw = prefs.getString('$_bulkCachePrefix$cityId');
      if (raw == null) return null;

      final list = jsonDecode(raw) as List<dynamic>;
      final streets = list
          .map((e) => BulkStreet.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('Bulk $cityId: ${streets.length} rues depuis cache');
      return streets;
    } catch (e) {
      debugPrint('Bulk cache load error $cityId: $e');
      return null;
    }
  }

  static Future<void> _saveBulkCache(
      String cityId, List<BulkStreet> streets) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(streets.map((s) => s.toJson()).toList());
      await prefs.setString('$_bulkCachePrefix$cityId', encoded);
      await prefs.setString(
          '$_bulkTsPrefix$cityId', DateTime.now().toIso8601String());
      debugPrint('Bulk cache $cityId sauvegardé — ${streets.length} rues');
    } catch (e) {
      debugPrint('Bulk cache save error $cityId: $e');
    }
  }

  // ── Cache management ──────────────────────────────────────────────────────

  /// Efface le cache des segments (utile pour debug ou forcer un re-fetch).
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTsKey);
  }

  /// Efface le cache bulk pour une ville (via city.id) ou toutes si null.
  static Future<void> clearBulkCache([String? cityId]) async {
    final prefs = await SharedPreferences.getInstance();
    if (cityId != null) {
      await prefs.remove('$_bulkCachePrefix$cityId');
      await prefs.remove('$_bulkTsPrefix$cityId');
    } else {
      // Effacer toutes les clés v3 bulk connues
      final keys = prefs.getKeys().where(
            (k) =>
                k.startsWith(_bulkCachePrefix) || k.startsWith(_bulkTsPrefix),
          );
      for (final k in keys) {
        await prefs.remove(k);
      }
    }
  }
}
