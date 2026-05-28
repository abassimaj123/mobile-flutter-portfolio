"""
gen_alternating_segments.py
===========================
Interroge Overpass API pour toutes les rues résidentielles du
Plateau-Mont-Royal, Rosemont et Mile-End qui ont typiquement
le stationnement alterné par mois.
Génère mock_data_montreal.dart avec les segments Dart.
"""
import urllib.request
import json, math, sys, io, re, os

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

OVERPASS = "https://overpass-api.de/api/interpreter"

# Zones avec stationnement alterne par mois (Montreal)
ZONES = [
    ("Plateau-Mont-Royal",   45.510, -73.610, 45.552, -73.548),
    ("Rosemont",             45.530, -73.600, 45.562, -73.540),
    ("Mile-End",             45.518, -73.630, 45.552, -73.575),
    ("Villeray",             45.540, -73.630, 45.570, -73.575),
    ("Centre-Sud",           45.508, -73.572, 45.533, -73.540),
]

def overpass_query(s, w, n, e):
    return f"""[out:json][timeout:25];
(way["highway"~"^(residential|tertiary|living_street)$"]["name"]({s},{w},{n},{e}););
out geom;"""

def fetch(query):
    data = urllib.request.urlencode({"data": query}).encode()
    req  = urllib.request.Request(OVERPASS, data=data,
               headers={"User-Agent":"ParkSmart/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())

def dart_coords(nodes, max_pts=8):
    """Sous-echantillonne les noeuds et retourne la chaine Dart."""
    step = max(1, len(nodes) // max_pts)
    pts  = nodes[::step]
    if nodes[-1] not in pts:
        pts.append(nodes[-1])
    lines = [f"        [{n['lon']:.6f}, {n['lat']:.6f}]" for n in pts]
    return ",\n".join(lines)

seen_names = {}   # name -> count (pour unicite des IDs)
segments   = []

for zone_name, s, w, n, e in ZONES:
    print(f"  Requete Overpass: {zone_name}...")
    try:
        result = fetch(overpass_query(s, w, n, e))
    except Exception as ex:
        print(f"    ERREUR: {ex}")
        continue

    ways = result.get("elements", [])
    print(f"    {len(ways)} rues trouvees")

    for way in ways:
        name = way.get("tags", {}).get("name", "").strip()
        if not name:
            continue
        nodes = way.get("geometry", [])
        if len(nodes) < 2:
            continue

        way_id = way["id"]
        slug   = re.sub(r"[^a-z0-9]", "-", name.lower())
        seen_names[slug] = seen_names.get(slug, 0) + 1
        seg_id = f"mtl-alt-{slug}-{seen_names[slug]}"

        coords_str = dart_coords(nodes)

        seg = f"""  // {zone_name}
  StreetSegment(
    id: '{seg_id}',
    streetName: '{name.replace("'", "\'")}',
    city: 'Montreal',
    side: 'Les deux cotes',
    osmWayIds: [{way_id}],
    coordinates: [
{coords_str},
    ],
    rules: _altMois,
    confidence: 0.80,
    sourceDate: '2026-01-01',
    sources: [DataSource.bylaw],
    notes: 'Stationnement alterne par mois',
  ),"""
        segments.append(seg)

OUT = os.path.join(os.path.dirname(__file__), '..', 'lib', 'core', 'data',
                   'mock_data_montreal.dart')

header = """import '../models/parking_rule.dart';
import '../models/street_segment.dart';

// AUTO-GENERATED — scripts/gen_alternating_segments.py
// Segments stationnement alterne par mois — Montreal
// cote pair : interdit les mois impairs (Jan Mar Mai Jul Sep Nov)
// cote impair : interdit les mois pairs (Fev Avr Jun Aou Oct Dec)

// Regles communes a toutes les rues alternes par mois
const List<ParkingRule> _altMois = [
  ParkingRule(
    type: RuleType.noParking,
    days: [1, 2, 3, 4, 5, 6, 7],
    monthParity: 1,
    note: 'Cote pair - interdit les mois impairs (Jan Mar Mai Jul Sep Nov)',
  ),
  ParkingRule(
    type: RuleType.noParking,
    days: [1, 2, 3, 4, 5, 6, 7],
    monthParity: 0,
    note: 'Cote impair - interdit les mois pairs (Fev Avr Jun Aou Oct Dec)',
  ),
];

final List<StreetSegment> montrealSegments = [
"""

footer = "];\n"

with open(OUT, 'w', encoding='utf-8') as f:
    f.write(header)
    f.write("\n".join(segments))
    f.write("\n" + footer)

print(f"\n=> {len(segments)} segments generes -> {OUT}")
