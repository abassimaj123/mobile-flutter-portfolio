import '../models/parking_zone.dart';
import '../models/parking_rule.dart';

/// Zones de stationnement géographiques par ville.
///
/// ## Principe — couche complémentaire
///   Seules les zones avec règles UNIFORMES et CERTAINES sont déclarées ici.
///   Elles complètent les [BulkStreet] qui n'ont pas de [StreetSegment] précis.
///
///   Priorité dans la liste : zones précises en premier → [findZone] retourne
///   le premier match, donc un parcomètre l'emporte sur une vignette si les
///   polygones se chevauchent dans le centre-ville.
///
/// ## Types de zones
///   🔵 Meter   : secteurs avec parcomètres actifs (centre-ville, commercial)
///   🔴 Permit  : SRRR Montréal (interdit sans vignette résidents)
///   🟢 Limited : Vignette Québec (2h sans vignette, illimité avec)
///
/// ## Ce qui n'est PAS ici
///   → Segments précis (rue par rue) : géré par les mocks
///   → Déneigement : conditionnel (panneau clignotant), non affichable
class ZoneRegistry {
  // ════════════════════════════════════════════════════════════════
  // RÈGLES — Parcomètres
  // ════════════════════════════════════════════════════════════════

  // ════════════════════════════════════════════════════════════════
  // RÈGLES — Heures de pointe (artères Montréal, Lun-Ven)
  // Source : règlement RCA 12-018 et arrêtés locaux d'arrondissement
  // ════════════════════════════════════════════════════════════════

  // Matin 7h-9h et soir 16h-18h — Lun-Ven — artères principales MTL
  static const _rushAM = ParkingRule(
    type: RuleType.noParking,
    days: [1, 2, 3, 4, 5],
    from: '07:00',
    to: '09:00',
    note: 'Heure de pointe — interdit stationnement (7h-9h Lun-Ven)',
  );
  static const _rushPM = ParkingRule(
    type: RuleType.noParking,
    days: [1, 2, 3, 4, 5],
    from: '16:00',
    to: '18:00',
    note: 'Heure de pointe — interdit stationnement (16h-18h Lun-Ven)',
  );

  // ════════════════════════════════════════════════════════════════
  // RÈGLES — Parcomètres (freeOnHoliday = true sur tous)
  // ════════════════════════════════════════════════════════════════

  // Vieux-Québec / Grande-Allée / Haute-Ville : Lun-Sam 9h-18h, 2.00$/h, max 2h
  static const _meterVieuxQC = ParkingRule(
    type: RuleType.meter,
    days: [1, 2, 3, 4, 5, 6],
    from: '09:00',
    to: '18:00',
    ratePerHour: 2.00,
    maxMinutes: 120,
    freeOnHoliday: true,
    note:
        'Parcomètre — 2,00 \$/h · Max 2h (Lun-Sam 9h-18h · gratuit jours fériés)',
  );

  // Limoilou commercial (3e et 4e ave) : Lun-Sam 9h-18h, 1.50$/h, max 2h
  static const _meterLimoilou = ParkingRule(
    type: RuleType.meter,
    days: [1, 2, 3, 4, 5, 6],
    from: '09:00',
    to: '18:00',
    ratePerHour: 1.50,
    maxMinutes: 120,
    freeOnHoliday: true,
    note:
        'Parcomètre — 1,50 \$/h · Max 2h (Lun-Sam 9h-18h · gratuit jours fériés)',
  );

  // Vieux-Lévis (rue Racine, Saint-Joseph) : Lun-Sam 9h-17h, 1.00$/h, max 2h
  static const _meterVieuxLevis = ParkingRule(
    type: RuleType.meter,
    days: [1, 2, 3, 4, 5, 6],
    from: '09:00',
    to: '17:00',
    ratePerHour: 1.00,
    maxMinutes: 120,
    freeOnHoliday: true,
    note:
        'Parcomètre — 1,00 \$/h · Max 2h (Lun-Sam 9h-17h · gratuit jours fériés)',
  );

  // Montréal Ville-Marie (centre-ville) — horaires étendus depuis nov. 2023
  // Lun-Ven : 8h-23h · Sam : 9h-23h · Dim : 13h-18h · 4,25$/h · max 5h
  static const _meterVilleMarieWeek = ParkingRule(
    type: RuleType.meter,
    days: [1, 2, 3, 4, 5],
    from: '08:00',
    to: '23:00',
    ratePerHour: 4.25,
    maxMinutes: 300,
    freeOnHoliday: true,
    note:
        'Parcomètre — 4,25 \$/h · Max 5h (Lun-Ven 8h-23h · gratuit jours fériés)',
  );

  static const _meterVilleMarieSat = ParkingRule(
    type: RuleType.meter,
    days: [6],
    from: '09:00',
    to: '23:00',
    ratePerHour: 4.25,
    maxMinutes: 300,
    freeOnHoliday: true,
    note: 'Parcomètre — 4,25 \$/h · Max 5h (Sam 9h-23h · gratuit jours fériés)',
  );

  static const _meterVilleMarieDim = ParkingRule(
    type: RuleType.meter,
    days: [7],
    from: '13:00',
    to: '18:00',
    ratePerHour: 4.25,
    maxMinutes: 300,
    freeOnHoliday: true,
    note:
        'Parcomètre — 4,25 \$/h · Max 5h (Dim 13h-18h · gratuit jours fériés)',
  );

  // Montréal avenue du Parc / Milton Park : Lun-Ven 9h-21h, Sam 9h-18h, 2.50$/h
  static const _meterParcMilton = ParkingRule(
    type: RuleType.meter,
    days: [1, 2, 3, 4, 5, 6],
    from: '09:00',
    to: '21:00',
    ratePerHour: 2.50,
    maxMinutes: 120,
    freeOnHoliday: true,
    note:
        'Parcomètre — 2,50 \$/h · Max 2h (Lun-Sam 9h-21h · gratuit jours fériés)',
  );

  // Montréal Rosemont commercial / Petite-Italie : Lun-Sam 9h-18h, 2.00$/h
  static const _meterRosemont = ParkingRule(
    type: RuleType.meter,
    days: [1, 2, 3, 4, 5, 6],
    from: '09:00',
    to: '18:00',
    ratePerHour: 2.00,
    maxMinutes: 120,
    freeOnHoliday: true,
    note:
        'Parcomètre — 2,00 \$/h · Max 2h (Lun-Sam 9h-18h · gratuit jours fériés)',
  );

  // ════════════════════════════════════════════════════════════════
  // RÈGLES — SRRR Montréal
  // ════════════════════════════════════════════════════════════════

  // Zone 75 Plateau : SRRR 7j/7, 9h-23h (source : horaire officiel arrondissement)
  static const _permitPlateau = ParkingRule(
    type: RuleType.permitOnly,
    days: [1, 2, 3, 4, 5, 6, 7],
    from: '09:00',
    to: '23:00',
    permitZone: 'Plateau-Mont-Royal',
    note: 'SRRR — interdit sans vignette (tous les jours 9h-23h)',
  );

  // Mile-End : SRRR Lun-Sam 9h-23h (même arrondissement que Plateau)
  static const _permitMileEnd = ParkingRule(
    type: RuleType.permitOnly,
    days: [1, 2, 3, 4, 5, 6],
    from: '09:00',
    to: '23:00',
    permitZone: 'Mile-End',
    note: 'SRRR — interdit sans vignette (Lun-Sam 9h-23h)',
  );

  static const _permitCDN = ParkingRule(
    type: RuleType.permitOnly,
    days: [1, 2, 3, 4, 5],
    from: '08:00',
    to: '18:00',
    permitZone: 'CDN-NDG-Outremont',
    note: 'SRRR — interdit sans vignette (Lun-Ven 8h-18h)',
  );

  // ════════════════════════════════════════════════════════════════
  // RÈGLES — Vignette Québec
  // ════════════════════════════════════════════════════════════════

  static const _permitQC = ParkingRule(
    type: RuleType.permitOrLimit,
    days: [1, 2, 3, 4, 5],
    from: '07:00',
    to: '18:00',
    maxMinutes: 120,
    permitZone: 'Québec-Vignette',
    note: '2h max sans vignette — illimité avec vignette (Lun-Ven 7h-18h)',
  );

  // ════════════════════════════════════════════════════════════════
  // API PUBLIQUE
  // ════════════════════════════════════════════════════════════════

  static List<ParkingZone> forCity(String cityId) =>
      _byCity[cityId] ?? const [];

  /// Première zone contenant (lon, lat), ou null si hors zone connue.
  ///
  /// Ordre de priorité : la liste met les zones précises (parcomètre) en premier,
  /// donc un secteur centre-ville retourne le parcomètre avant la vignette.
  static ParkingZone? findZone(String cityId, double lon, double lat) {
    for (final zone in forCity(cityId)) {
      if (zone.contains(lon, lat)) return zone;
    }
    return null;
  }

  /// Retourne les règles CUMULÉES de TOUTES les zones contenant (lon, lat).
  ///
  /// Permet de combiner plusieurs couches sur la même rue :
  ///   ex. artère → [rushAM, rushPM, permitPlateau] (heures de pointe + SRRR)
  ///
  /// Liste vide = aucune zone connue → appliquer les règles par défaut de la ville.
  static List<ParkingRule> findAllZones(String cityId, double lon, double lat) {
    final result = <ParkingRule>[];
    for (final zone in forCity(cityId)) {
      if (zone.contains(lon, lat)) {
        result.addAll(zone.rules);
      }
    }
    return result;
  }

  static final Map<String, List<ParkingZone>> _byCity = {
    'capitale': _capitaleZones,
    'montreal': _montrealZones,
  };

  // ════════════════════════════════════════════════════════════════
  // ZONES — Capitale-Nationale (Québec + Lévis)
  // Ordre : parcomètres en premier → victoire sur vignette si chevauchement
  // ════════════════════════════════════════════════════════════════

  static final List<ParkingZone> _capitaleZones = [
    // ── Parcomètres Vieux-Québec / Grande-Allée / Haute-Ville ────────────────
    // Secteur intra-muros + boulevard Grande-Allée : tarif centre-ville
    ParkingZone(
      id: 'qc_meter_vieux',
      name: 'Vieux-Québec & Grande-Allée',
      rules: [_meterVieuxQC],
      polygon: _rect(-71.241, 46.798, -71.196, 46.814),
    ),

    // ── Parcomètres Limoilou commercial ─────────────────────────────────────
    // 3e et 4e avenue, Dufferin-Montmorency
    ParkingZone(
      id: 'qc_meter_limoilou',
      name: 'Limoilou — secteur commercial',
      rules: [_meterLimoilou],
      polygon: _rect(-71.222, 46.819, -71.188, 46.840),
    ),

    // ── Parcomètres Vieux-Lévis ──────────────────────────────────────────────
    // Rue Racine, Saint-Joseph, secteur historique Lévis
    ParkingZone(
      id: 'lv_meter_vieux',
      name: 'Vieux-Lévis',
      rules: [_meterVieuxLevis],
      polygon: _rect(-71.200, 46.798, -71.162, 46.816),
    ),

    // ── Zones vignette résidentielles ────────────────────────────────────────
    // (après les parcomètres → s'appliquent aux rues résidentielles)

    ParkingZone(
      id: 'qc_montcalm',
      name: 'Montcalm',
      rules: [_permitQC],
      polygon: _rect(-71.260, 46.793, -71.218, 46.820),
    ),

    ParkingZone(
      id: 'qc_st_jean_baptiste',
      name: 'Saint-Jean-Baptiste',
      rules: [_permitQC],
      polygon: _rect(-71.242, 46.810, -71.200, 46.838),
    ),

    ParkingZone(
      id: 'qc_limoilou',
      name: 'Limoilou',
      rules: [_permitQC],
      polygon: _rect(-71.225, 46.816, -71.175, 46.852),
    ),

    ParkingZone(
      id: 'qc_st_sacrement',
      name: 'Saint-Sacrement',
      rules: [_permitQC],
      polygon: _rect(-71.278, 46.780, -71.240, 46.808),
    ),
  ];

  // ════════════════════════════════════════════════════════════════
  // ZONES — Grand Montréal
  // Ordre : parcomètres en premier → victoire sur SRRR si chevauchement
  // ════════════════════════════════════════════════════════════════

  static final List<ParkingZone> _montrealZones = [
    // ══════════════════════════════════════════════════════════════════════════
    // ARTÈRES — Heures de pointe (couloirs étroits, priorité max → listés en 1er)
    // Ces zones sont intentionnellement ÉTROITES (~150 m de large) pour ne
    // couvrir que l'artère elle-même, pas les rues résidentielles adjacentes.
    // findAllZones() cumule ces règles avec SRRR/parcomètre si les deux matchent.
    // Sources : règlement RCA 12-018 + signalisation en place
    // ══════════════════════════════════════════════════════════════════════════

    // ── Rue Sherbrooke Est (Plateau / HoMa) ─────────────────────────────────
    // Interdit stationnement 7h-9h et 16h-18h Lun-Ven
    ParkingZone(
      id: 'mtl_rush_sherbrooke',
      name: 'Rue Sherbrooke Est — heure de pointe',
      rules: [_rushAM, _rushPM],
      polygon: _rect(-73.620, 45.518, -73.530, 45.528),
    ),

    // ── Boulevard Saint-Laurent (The Main, entre Sherbrooke et Jean-Talon) ──
    ParkingZone(
      id: 'mtl_rush_stlaurent',
      name: 'Boul. Saint-Laurent — heure de pointe',
      rules: [_rushAM, _rushPM],
      polygon: _rect(-73.576, 45.498, -73.566, 45.558),
    ),

    // ── Boulevard René-Lévesque (centre-ville est) ───────────────────────────
    ParkingZone(
      id: 'mtl_rush_renelev',
      name: 'Boul. René-Lévesque — heure de pointe',
      rules: [_rushAM, _rushPM],
      polygon: _rect(-73.590, 45.506, -73.530, 45.514),
    ),

    // ── Avenue du Parc (entre Sherbrooke et Van Horne) ───────────────────────
    ParkingZone(
      id: 'mtl_rush_parc',
      name: 'Avenue du Parc — heure de pointe',
      rules: [_rushAM, _rushPM],
      polygon: _rect(-73.616, 45.505, -73.604, 45.555),
    ),

    // ── Avenue Papineau (entre Notre-Dame et Rosemont) ───────────────────────
    ParkingZone(
      id: 'mtl_rush_papineau',
      name: 'Avenue Papineau — heure de pointe',
      rules: [_rushAM, _rushPM],
      polygon: _rect(-73.568, 45.510, -73.555, 45.558),
    ),

    // ── Rue Saint-Denis (entre Sherbrooke et Jean-Talon) ────────────────────
    ParkingZone(
      id: 'mtl_rush_stdenis',
      name: 'Rue Saint-Denis — heure de pointe',
      rules: [_rushAM, _rushPM],
      polygon: _rect(-73.574, 45.508, -73.562, 45.556),
    ),

    // ── Avenue Côte-des-Neiges (entre Sherbrooke et Queen-Mary) ─────────────
    ParkingZone(
      id: 'mtl_rush_cdn',
      name: 'Avenue Côte-des-Neiges — heure de pointe',
      rules: [_rushAM, _rushPM],
      polygon: _rect(-73.618, 45.478, -73.604, 45.520),
    ),

    // ══════════════════════════════════════════════════════════════════════════
    // PARCOMÈTRES
    // ══════════════════════════════════════════════════════════════════════════

    // ── Parcomètres Ville-Marie (centre-ville) ───────────────────────────────
    // Sainte-Catherine, René-Lévesque, McGill, rue Peel, etc.
    // Horaires étendus depuis nov. 2023 : Lun-Ven 8h-23h, Sam 9h-23h, Dim 13h-18h
    ParkingZone(
      id: 'mtl_meter_villemarie',
      name: 'Ville-Marie — centre-ville',
      rules: [_meterVilleMarieWeek, _meterVilleMarieSat, _meterVilleMarieDim],
      polygon: _rect(-73.582, 45.490, -73.538, 45.514),
    ),

    // ── Parcomètres avenue du Parc / Milton-Park ────────────────────────────
    // Secteur McGill / avenue du Parc, hors SRRR Plateau
    ParkingZone(
      id: 'mtl_meter_parc_milton',
      name: 'Avenue du Parc & Milton-Park',
      rules: [_meterParcMilton],
      polygon: _rect(-73.610, 45.508, -73.580, 45.526),
    ),

    // ── Parcomètres Rosemont commercial / Petite-Italie ─────────────────────
    // Boulevard Saint-Laurent nord, Jean-Talon, Beaubien
    ParkingZone(
      id: 'mtl_meter_rosemont_comm',
      name: 'Rosemont commercial & Petite-Italie',
      rules: [_meterRosemont],
      polygon: _rect(-73.620, 45.530, -73.566, 45.552),
    ),

    // ── Zones SRRR (résidentielles) ──────────────────────────────────────────
    // (après parcomètres → rues résidentielles sans meter)

    ParkingZone(
      id: 'mtl_plateau',
      name: 'Plateau-Mont-Royal',
      rules: [_permitPlateau],
      polygon: _rect(-73.608, 45.510, -73.548, 45.548),
    ),

    ParkingZone(
      id: 'mtl_mile_end',
      name: 'Mile-End',
      rules: [_permitMileEnd],
      polygon: _rect(-73.625, 45.522, -73.558, 45.548),
    ),

    ParkingZone(
      id: 'mtl_cdn',
      name: 'Côte-des-Neiges',
      rules: [_permitCDN],
      polygon: _rect(-73.668, 45.478, -73.588, 45.530),
    ),

    ParkingZone(
      id: 'mtl_ndg',
      name: 'Notre-Dame-de-Grâce',
      rules: [_permitCDN],
      polygon: _rect(-73.705, 45.445, -73.618, 45.485),
    ),

    ParkingZone(
      id: 'mtl_outremont',
      name: 'Outremont',
      rules: [_permitCDN],
      polygon: _rect(-73.628, 45.508, -73.592, 45.532),
    ),

    ParkingZone(
      id: 'mtl_rosemont',
      name: 'Rosemont–Petite-Patrie',
      rules: [_permitCDN],
      polygon: _rect(-73.588, 45.528, -73.542, 45.560),
    ),
  ];

  // ════════════════════════════════════════════════════════════════
  // HELPER GÉOMÉTRIQUE
  // ════════════════════════════════════════════════════════════════

  static List<List<double>> _rect(
          double lonW, double latS, double lonE, double latN) =>
      [
        [lonW, latS],
        [lonE, latS],
        [lonE, latN],
        [lonW, latN],
        [lonW, latS],
      ];
}
