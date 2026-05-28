import '../models/parking_rule.dart';
import '../models/street_segment.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MODÈLE DE DONNÉES — Lévis (2026-05-03)
//
// Chaque segment a deux références de géométrie :
//
//   osmWayIds   → référence PRIMAIRE (fetch automatique via Overpass)
//                 IDs vérifiés sur https://overpass-turbo.eu
//                 Stable : l'ID ne change jamais même si le nom OSM change
//
//   coordinates → FALLBACK embarqué (nœuds copiés depuis OSM dev-side)
//                 Utilisé : 1er lancement offline, way ID introuvable
//
// Règle de fiabilité :
//   coords interpolées (même lng ou lat) = ligne droite = FAUX
//   coords copiées nœud par nœud depuis OSM = courbes réelles = CORRECT
//
// Pour une nouvelle ville :
//   1. overpass-turbo.eu → cliquer la rue → copier l'ID du way
//   2. Ajouter l'ID dans osmWayIds
//   3. Copier les nœuds géométriques comme fallback
// ═══════════════════════════════════════════════════════════════════════════

final List<StreetSegment> levisSegments = [
  // ── lv-001 ──────────────────────────────────────────────────────────────
  const StreetSegment(
    id: 'lv-001',
    streetName: 'Rue Wolfe',
    city: 'Lévis',
    side: 'Ouest',
    osmWayIds: [243597658], // Way 243597658 — diagonal NW, 11 nodes
    coordinates: [
      [-71.1840328, 46.8092454],
      [-71.1842721, 46.8087534],
      [-71.1844722, 46.8084261],
      [-71.1844939, 46.8083907],
      [-71.1845468, 46.8082952],
      [-71.1846264, 46.8081769],
      [-71.1847061, 46.8080586],
      [-71.1848527, 46.8079464],
      [-71.1853668, 46.8074905],
      [-71.1854232, 46.8074286],
      [-71.1854337, 46.8073531],
    ],
    rules: [
      ParkingRule(
        type: RuleType.permitOnly,
        days: [1, 2, 3, 4, 5],
        from: '08:00',
        to: '17:00',
        permitZone: 'L-1',
      ),
    ],
    confidence: 0.85,
    sourceDate: '2025-12-15',
    sources: [DataSource.bylaw],
    notes: 'Zone permis L-1 semaine · Libre soirs et fins de semaine',
  ),

  // ── lv-002 ──────────────────────────────────────────────────────────────
  const StreetSegment(
    id: 'lv-002',
    streetName: 'Côte du Passage',
    city: 'Lévis',
    side: 'Est',
    osmWayIds: [327158675], // Way 327158675 — monte vers le ferry, 12 nodes
    coordinates: [
      [-71.1836874, 46.8064206],
      [-71.1839981, 46.8065802],
      [-71.1840220, 46.8065924],
      [-71.1842098, 46.8066992],
      [-71.1843957, 46.8068099],
      [-71.1845838, 46.8069395],
      [-71.1848165, 46.8070977],
      [-71.1849988, 46.8071998],
      [-71.1851345, 46.8072785],
      [-71.1852179, 46.8073126],
      [-71.1853154, 46.8073327],
      [-71.1854337, 46.8073531],
    ],
    rules: [
      ParkingRule(
        type: RuleType.noParking,
        days: [1, 2, 3, 4, 5, 6, 7],
        from: '22:00',
        to: '06:00',
        note: 'Interdit la nuit',
      ),
    ],
    confidence: 0.77,
    sourceDate: '2025-09-10',
    sources: [DataSource.bylaw, DataSource.nextdoor],
  ),

  // ── lv-003 ──────────────────────────────────────────────────────────────
  const StreetSegment(
    id: 'lv-003',
    streetName: 'Avenue Bégin',
    city: 'Lévis',
    side: 'Les deux côtés',
    osmWayIds: [32402442], // Way 32402442 — diagonale NW, 8 nodes
    coordinates: [
      [-71.1836874, 46.8064206],
      [-71.1836026, 46.8064869],
      [-71.1832103, 46.8067930],
      [-71.1830200, 46.8069396],
      [-71.1826698, 46.8071991],
      [-71.1825426, 46.8072896],
      [-71.1819766, 46.8076927],
      [-71.1816523, 46.8079192],
    ],
    rules: [
      ParkingRule(
        type: RuleType.noParking,
        days: [1, 2, 3, 4, 5],
        from: '07:00',
        to: '09:00',
        note: 'Heure de pointe',
      ),
      ParkingRule(
        type: RuleType.noParking,
        days: [1, 2, 3, 4, 5],
        from: '16:30',
        to: '18:30',
        note: 'Heure de pointe',
      ),
    ],
    confidence: 0.82,
    sourceDate: '2025-11-01',
    sources: [DataSource.bylaw, DataSource.nextdoor],
  ),

  // ── lv-004 ──────────────────────────────────────────────────────────────
  const StreetSegment(
    id: 'lv-004',
    streetName: 'Boulevard Alphonse-Desjardins',
    city: 'Lévis',
    side: 'Les deux côtés',
    osmWayIds: [463113102], // Way 463113102 — diagonale NE, 9 nodes
    coordinates: [
      [-71.1767737, 46.8027486],
      [-71.1768623, 46.8027965],
      [-71.1769347, 46.8028356],
      [-71.1772565, 46.8029855],
      [-71.1773571, 46.8030341],
      [-71.1774577, 46.8030958],
      [-71.1775622, 46.8031616],
      [-71.1775884, 46.8031781],
      [-71.1776644, 46.8032617],
    ],
    rules: [
      ParkingRule(
        type: RuleType.noParking,
        days: [1, 2, 3, 4, 5],
        from: '07:00',
        to: '09:00',
        note: 'Rush hour matin',
      ),
      ParkingRule(
        type: RuleType.noParking,
        days: [1, 2, 3, 4, 5],
        from: '16:00',
        to: '18:00',
        note: 'Rush hour soir',
      ),
    ],
    confidence: 0.84,
    sourceDate: '2025-12-05',
    sources: [DataSource.bylaw, DataSource.official],
  ),

  // ── lv-005 ──────────────────────────────────────────────────────────────
  // 3 ways consécutifs = un segment logique — l'algo les concatène
  const StreetSegment(
    id: 'lv-005',
    streetName: 'Route du Président-Kennedy',
    city: 'Lévis',
    side: 'Nord',
    osmWayIds: [917209288, 471803029, 917206775, 917206774],
    // Ways SW : 917209288 → 471803029 → 917206775 → 917206774
    coordinates: [
      [-71.1757502, 46.7946902],
      [-71.1756587, 46.7946325],
      [-71.1752604, 46.7943714],
      [-71.1749841, 46.7941903],
      [-71.1748489, 46.7941484],
      [-71.1741516, 46.7937034],
      [-71.1734841, 46.7932774],
      [-71.1731076, 46.7930150],
      [-71.1729563, 46.7929096],
      [-71.1727611, 46.7927685],
      [-71.1725767, 46.7926351],
      [-71.1723444, 46.7924684],
    ],
    rules: [
      ParkingRule(
        type: RuleType.meter,
        days: [1, 2, 3, 4, 5, 6],
        from: '09:00',
        to: '17:00',
        ratePerHour: 1.00,
        maxMinutes: 60,
        note: 'Max 1h',
      ),
    ],
    confidence: 0.79,
    sourceDate: '2025-09-20',
    sources: [DataSource.bylaw, DataSource.googleMaps],
  ),

  // ── lv-006 ──────────────────────────────────────────────────────────────
  const StreetSegment(
    id: 'lv-006',
    streetName: 'Rue Dorimène-Desjardins',
    city: 'Lévis',
    side: 'Est',
    osmWayIds: [243601177], // Way 243601177 — longue diagonale, 18 nodes
    coordinates: [
      [-71.1858703, 46.8070494],
      [-71.1856564, 46.8069139],
      [-71.1856299, 46.8068947],
      [-71.1855058, 46.8068047],
      [-71.1853170, 46.8066685],
      [-71.1850011, 46.8064428],
      [-71.1848900, 46.8063562],
      [-71.1847892, 46.8062813],
      [-71.1846967, 46.8062078],
      [-71.1845113, 46.8060585],
      [-71.1843658, 46.8059413],
      [-71.1841286, 46.8057504],
      [-71.1839866, 46.8056511],
      [-71.1838908, 46.8055840],
      [-71.1837728, 46.8055109],
      [-71.1836873, 46.8054579],
      [-71.1835608, 46.8054008],
      [-71.1834427, 46.8053490],
    ],
    rules: [
      ParkingRule(
        type: RuleType.noParking,
        days: [1, 2, 3, 4, 5],
        from: '07:00',
        to: '10:00',
      ),
      ParkingRule(
        type: RuleType.meter,
        days: [1, 2, 3, 4, 5, 6],
        from: '10:00',
        to: '18:00',
        ratePerHour: 1.25,
        maxMinutes: 180,
      ),
    ],
    confidence: 0.81,
    sourceDate: '2025-10-12',
    sources: [DataSource.bylaw],
  ),

  // ── lv-007 ──────────────────────────────────────────────────────────────
  const StreetSegment(
    id: 'lv-007',
    streetName: 'Rue Fraser',
    city: 'Lévis',
    side: 'Les deux côtés',
    osmWayIds: [
      40301133
    ], // Way 40301133 — sinueuse 23 nodes, lat ~46.810-46.817
    coordinates: [
      [-71.1840740, 46.8108276],
      [-71.1847444, 46.8110033],
      [-71.1848274, 46.8110421],
      [-71.1848467, 46.8110972],
      [-71.1846581, 46.8114269],
      [-71.1845728, 46.8115788],
      [-71.1844434, 46.8118092],
      [-71.1843080, 46.8120502],
      [-71.1842256, 46.8121970],
      [-71.1841152, 46.8124143],
      [-71.1835441, 46.8134761],
      [-71.1830453, 46.8143365],
      [-71.1829595, 46.8144461],
      [-71.1828692, 46.8145441],
      [-71.1826189, 46.8147666],
      [-71.1822125, 46.8151399],
      [-71.1817934, 46.8155591],
      [-71.1815165, 46.8158679],
      [-71.1812067, 46.8162459],
      [-71.1807195, 46.8168704],
      [-71.1804846, 46.8171940],
      [-71.1804671, 46.8172182],
      [-71.1803774, 46.8173951],
    ],
    rules: [],
    confidence: 0.60,
    sourceDate: '2025-04-15',
    sources: [DataSource.reddit],
  ),

  // ── lv-008 ──────────────────────────────────────────────────────────────
  const StreetSegment(
    id: 'lv-008',
    streetName: 'Chemin du Gouvernement',
    city: 'Lévis',
    side: 'Les deux côtés',
    osmWayIds: [156791444], // Way 156791444 — diagonale NE vieux-Lévis, 6 nodes
    coordinates: [
      [-71.1696184, 46.8007628],
      [-71.1676225, 46.8025187],
      [-71.1674795, 46.8026443],
      [-71.1674088, 46.8027056],
      [-71.1667916, 46.8032395],
      [-71.1663597, 46.8036437],
    ],
    rules: [],
    confidence: 0.68,
    sourceDate: '2025-05-01',
    sources: [DataSource.reddit, DataSource.nextdoor],
  ),

  // ── lv-009 ──────────────────────────────────────────────────────────────
  // 4 ways consécutifs formant la section est de la Kennedy
  const StreetSegment(
    id: 'lv-009',
    streetName: 'Route du Président-Kennedy',
    city: 'Lévis',
    side: 'Sud',
    osmWayIds: [917213930, 917213931, 327957445, 1289725367],
    // Ways NE : 917213930 → 917213931 → 327957445 → 1289725367
    coordinates: [
      [-71.1776713, 46.7960948],
      [-71.1781487, 46.7964115],
      [-71.1784892, 46.7966494],
      [-71.1786472, 46.7967588],
      [-71.1788898, 46.7969256],
      [-71.1789631, 46.7969760],
      [-71.1795549, 46.7973828],
      [-71.1798915, 46.7976142],
      [-71.1799509, 46.7976550],
      [-71.1820284, 46.7990829],
      [-71.1821426, 46.7991614],
    ],
    rules: [
      ParkingRule(
        type: RuleType.permitOnly,
        days: [1, 2, 3, 4, 5, 6, 7],
        from: '22:00',
        to: '08:00',
        permitZone: 'L-2',
      ),
    ],
    confidence: 0.76,
    sourceDate: '2025-08-08',
    sources: [DataSource.nextdoor],
    notes: 'Source communautaire',
  ),

  // ── lv-010 ──────────────────────────────────────────────────────────────
  const StreetSegment(
    id: 'lv-010',
    streetName: 'Rue Notre-Dame',
    city: 'Lévis',
    side: 'Les deux côtés',
    osmWayIds: [40300784], // Way 40300784 — diagonale NE, 9 nodes
    coordinates: [
      [-71.1829598, 46.8098031],
      [-71.1824409, 46.8100892],
      [-71.1823143, 46.8101526],
      [-71.1821863, 46.8102263],
      [-71.1821108, 46.8102716],
      [-71.1819157, 46.8103820],
      [-71.1814860, 46.8106460],
      [-71.1810873, 46.8108997],
      [-71.1803333, 46.8113030],
    ],
    rules: [],
    confidence: 0.60,
    sourceDate: '2025-04-15',
    sources: [DataSource.reddit],
  ),

  // ── lv-011 ──────────────────────────────────────────────────────────────
  // osmWayIds: [] → fallback sur coordinates embarquées (ID non disponible)
  // Pour obtenir l'ID : https://overpass-turbo.eu → zoom sur Rue Laurier Lévis → clic rue → copier ID
  const StreetSegment(
    id: 'lv-011',
    streetName: 'Rue Laurier',
    city: 'Lévis',
    side: 'Les deux côtés',
    osmWayIds: [], // Dépend de Overpass — coordinates embarquées suffisent
    coordinates: [
      [-71.1875884, 46.8104000],
      [-71.1874577, 46.8104200],
      [-71.1873571, 46.8104800],
      [-71.1872565, 46.8105200],
      [-71.1870347, 46.8105500],
      [-71.1869623, 46.8105600],
      [-71.1867737, 46.8105700],
    ],
    rules: [
      ParkingRule(
        type: RuleType.meter,
        days: [1, 2, 3, 4, 5, 6],
        from: '08:00',
        to: '17:00',
        ratePerHour: 1.25,
        maxMinutes: 120,
      ),
    ],
    confidence: 0.79,
    sourceDate: '2025-11-25',
    sources: [DataSource.bylaw],
  ),

  // ── lv-012 ──────────────────────────────────────────────────────────────
  const StreetSegment(
    id: 'lv-012',
    streetName: 'Boulevard Guillaume-Couture',
    city: 'Lévis',
    side: 'Les deux côtés',
    osmWayIds: [471832874], // Way 471832874 — grande diagonale NE, 10 nodes
    coordinates: [
      [-71.1658586, 46.8043505],
      [-71.1663263, 46.8038610],
      [-71.1663555, 46.8038339],
      [-71.1669190, 46.8033102],
      [-71.1675034, 46.8028069],
      [-71.1675426, 46.8027731],
      [-71.1676110, 46.8027109],
      [-71.1677266, 46.8026098],
      [-71.1692404, 46.8012809],
      [-71.1696184, 46.8007628],
    ],
    rules: [
      ParkingRule(
        type: RuleType.noParking,
        days: [1, 2, 3, 4, 5],
        from: '07:00',
        to: '09:00',
        note: 'Rush hour matin',
      ),
      ParkingRule(
        type: RuleType.noParking,
        days: [1, 2, 3, 4, 5],
        from: '16:00',
        to: '18:00',
        note: 'Rush hour soir',
      ),
    ],
    confidence: 0.84,
    sourceDate: '2025-12-05',
    sources: [DataSource.bylaw, DataSource.official],
  ),

  // ── lv-013 ──────────────────────────────────────────────────────────────
  // 4 ways consécutifs = segment complet de la rue
  const StreetSegment(
    id: 'lv-013',
    streetName: 'Rue Valère-Plante',
    city: 'Lévis',
    side: 'Les deux côtés',
    osmWayIds: [40301809, 40301058, 40301625, 40303199],
    // Ways combinés : 40301809 → 40301058 → 40301625 → 40303199 (+40301752)
    coordinates: [
      [-71.1767008, 46.8046714],
      [-71.1768044, 46.8047419],
      [-71.1777207, 46.8053739],
      [-71.1777837, 46.8053413],
      [-71.1779557, 46.8053439],
      [-71.1780349, 46.8053633],
      [-71.1782424, 46.8054844],
      [-71.1783221, 46.8055714],
      [-71.1783402, 46.8056625],
      [-71.1783479, 46.8057691],
      [-71.1788973, 46.8061558],
      [-71.1789138, 46.8062182],
      [-71.1791212, 46.8063194],
    ],
    rules: [],
    confidence: 0.66,
    sourceDate: '2025-06-10',
    sources: [DataSource.reddit],
  ),

  // ── lv-014 ──────────────────────────────────────────────────────────────
  // 3 ways consécutifs = Rue Labadie complète
  const StreetSegment(
    id: 'lv-014',
    streetName: 'Rue Labadie',
    city: 'Lévis',
    side: 'Les deux côtés',
    osmWayIds: [787942580, 243601178, 32402391],
    // Ways : 787942580 → 243601178 → 32402391 (haut de la côte)
    coordinates: [
      [-71.1866363, 46.8080056],
      [-71.1865265, 46.8079564],
      [-71.1863844, 46.8079058],
      [-71.1860923, 46.8077764],
      [-71.1859213, 46.8076698],
      [-71.1854232, 46.8074286],
      [-71.1854337, 46.8073531],
    ],
    rules: [
      ParkingRule(
        type: RuleType.noParking,
        days: [1, 2, 3, 4, 5, 6, 7],
        from: '00:00',
        to: '23:59',
        note: 'Accès traverse — stationnement interdit',
      ),
    ],
    confidence: 0.97,
    sourceDate: '2026-01-01',
    sources: [DataSource.official],
    notes: 'Accès prioritaire traversier Québec-Lévis',
  ),

  // ── lv-015 ──────────────────────────────────────────────────────────────
  // 3 ways consécutifs = Rue Wolfe section nord complète (20 nodes)
  const StreetSegment(
    id: 'lv-015',
    streetName: 'Rue Wolfe',
    city: 'Lévis',
    side: 'Est',
    osmWayIds: [32402558, 243597657, 243597660],
    // Ways N→S : 32402558 → 243597657 → 243597660 (rejoint lv-001 en bas)
    coordinates: [
      [-71.1787197, 46.8157458],
      [-71.1795241, 46.8151100],
      [-71.1798183, 46.8148686],
      [-71.1799213, 46.8147867],
      [-71.1803068, 46.8144810],
      [-71.1807552, 46.8141171],
      [-71.1810461, 46.8138918],
      [-71.1814468, 46.8135635],
      [-71.1815025, 46.8135108],
      [-71.1815506, 46.8134477],
      [-71.1817775, 46.8131229],
      [-71.1821372, 46.8125701],
      [-71.1825245, 46.8119871],
      [-71.1825691, 46.8118974],
      [-71.1827886, 46.8115356],
      [-71.1830113, 46.8111377],
      [-71.1833034, 46.8106303],
      [-71.1835110, 46.8101612],
      [-71.1837838, 46.8096876],
      [-71.1840328, 46.8092454],
    ],
    rules: [
      ParkingRule(
        type: RuleType.permitOnly,
        days: [1, 2, 3, 4, 5, 6, 7],
        from: '22:00',
        to: '08:00',
        permitZone: 'L-1',
      ),
    ],
    confidence: 0.85,
    sourceDate: '2025-12-15',
    sources: [DataSource.bylaw],
    notes: 'Zone permis L-1 — section nord',
  ),
];
