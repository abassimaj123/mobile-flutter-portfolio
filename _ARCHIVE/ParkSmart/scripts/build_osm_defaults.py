#!/usr/bin/env python3
"""
build_osm_defaults.py
=====================
Génère des règles de stationnement PAR DÉFAUT à partir des ways OSM (highway=*).

Stratégie (équivalent SpotAngels) :
  1. Récupérer tous les ways OSM `highway=residential|tertiary|secondary` par ville
  2. Calculer le centre de chaque way
  3. Skip si un meter existe déjà à proximité (grille 80m)
  4. Classifier le centre selon des polygones de zone (downtown/résidentiel)
  5. Appliquer la règle par défaut de la zone (parcomètre payant, 2h gratuit, etc.)
  6. Ajouter au fichier `assets/data/{city}.json`

Impact attendu : couverture moyenne 40% → 70%+.

Usage :
  python scripts/build_osm_defaults.py            # toutes les villes
  python scripts/build_osm_defaults.py montreal   # une seule
"""
import json
import sys
import time
import hashlib
import requests
from pathlib import Path

DATA_DIR = Path("assets/data")
OVERPASS = "https://overpass-api.de/api/interpreter"
HEADERS = {"User-Agent": "ParkSmart/1.0 (osm-defaults builder)"}
REQUEST_DELAY = 1.0

# Grille de dédup : 0.001° ≈ 80m (≈ un pâté de maison)
DEDUP_PRECISION = 3  # decimals → 0.001°

# =============================================================================
# CONFIGURATION PAR VILLE
# =============================================================================
# Format : (south, west, north, east) pour bbox + polygones downtown
# Règles : c=cents, m=max_stay min, r=rate $/h, d=jours, f/t=heures
#
# Trois zones génériques :
#   - downtown      : centre-ville payant
#   - commercial    : artères commerciales (limite courte, parfois payant)
#   - residential   : 2h gratuit par défaut
#
# Si un centre n'est dans aucun polygone → règle "residential" par défaut.

DEFAULT_RULES = {
    "downtown":    {"c": 250, "m": 120, "r": 2.50, "f": "09:00", "t": "21:00", "d": [1,2,3,4,5,6]},
    "commercial":  {"c": 150, "m":  60, "r": 1.50, "f": "09:00", "t": "18:00", "d": [1,2,3,4,5]},
    "residential": {"c":   0, "m": 120, "r": 0.00, "f": "08:00", "t": "18:00", "d": [1,2,3,4,5]},
}

# Polygones définis par (lon_min, lat_min, lon_max, lat_max) en bbox simple.
# Pour des zones complexes, on liste plusieurs bboxes adjacentes.
CITY_CONFIG = {
    # ─── MONTRÉAL ─────────────────────────────────────────────────────────
    "montreal": {
        "bbox": (45.40, -73.97, 45.70, -73.45),
        "downtown": [
            ((-73.585, 45.495), (-73.555, 45.515)),  # Centre-Ville / Quartier des Spectacles
            ((-73.580, 45.505), (-73.560, 45.520)),  # Vieux-Montréal
        ],
        "commercial": [
            ((-73.620, 45.515), (-73.580, 45.540)),  # Plateau / Mile End
            ((-73.585, 45.518), (-73.555, 45.532)),  # Quartier latin
            ((-73.640, 45.450), (-73.615, 45.470)),  # NDG / Monkland
        ],
        "rules": DEFAULT_RULES,
        "tiles": 4,
    },

    # ─── CAPITALE (Québec) ────────────────────────────────────────────────
    "capitale": {
        "bbox": (46.75, -71.40, 46.92, -71.10),
        "downtown": [
            ((-71.225, 46.806), (-71.205, 46.820)),  # Vieux-Québec haute-ville
            ((-71.215, 46.810), (-71.195, 46.825)),  # Vieux-Québec basse-ville
            ((-71.250, 46.802), (-71.225, 46.815)),  # Colline Parlementaire
        ],
        "commercial": [
            ((-71.240, 46.808), (-71.215, 46.822)),  # Saint-Jean-Baptiste / Montcalm
            ((-71.235, 46.820), (-71.215, 46.832)),  # Saint-Roch
            ((-71.310, 46.778), (-71.270, 46.795)),  # Sainte-Foy commercial
        ],
        "rules": {
            **DEFAULT_RULES,
            "downtown":   {"c": 350, "m": 120, "r": 3.50, "f": "09:00", "t": "21:00", "d": [1,2,3,4,5,6]},
            "commercial": {"c": 200, "m": 120, "r": 2.00, "f": "09:00", "t": "18:00", "d": [1,2,3,4,5,6]},
        },
        "tiles": 2,
    },

    # ─── VANCOUVER ────────────────────────────────────────────────────────
    "vancouver": {
        "bbox": (49.20, -123.27, 49.32, -123.02),
        "downtown": [
            ((-123.135, 49.275), (-123.105, 49.295)),  # Downtown / West End / Yaletown
            ((-123.115, 49.265), (-123.085, 49.285)),  # Gastown / Chinatown
        ],
        "commercial": [
            ((-123.175, 49.255), (-123.135, 49.275)),  # Kitsilano / W 4th
            ((-123.105, 49.255), (-123.075, 49.275)),  # Mount Pleasant
            ((-123.085, 49.250), (-123.055, 49.270)),  # Commercial Drive
            ((-123.165, 49.235), (-123.135, 49.255)),  # Marpole
        ],
        "rules": {
            **DEFAULT_RULES,
            "downtown":   {"c": 350, "m":  60, "r": 3.50, "f": "08:00", "t": "22:00", "d": [1,2,3,4,5,6,7]},
            "commercial": {"c": 200, "m": 120, "r": 2.00, "f": "09:00", "t": "20:00", "d": [1,2,3,4,5,6]},
        },
        "tiles": 2,
    },

    # ─── TORONTO ──────────────────────────────────────────────────────────
    "toronto": {
        "bbox": (43.58, -79.64, 43.86, -79.12),
        "downtown": [
            ((-79.395, 43.640), (-79.365, 43.665)),  # Financial District / King-Bay
            ((-79.395, 43.655), (-79.370, 43.675)),  # Yonge-Dundas / Eaton Centre
        ],
        "commercial": [
            ((-79.430, 43.640), (-79.395, 43.660)),  # King West / Entertainment
            ((-79.425, 43.665), (-79.395, 43.685)),  # Annex / Bloor West
            ((-79.395, 43.660), (-79.370, 43.680)),  # Yonge corridor
            ((-79.355, 43.665), (-79.335, 43.685)),  # Riverdale / Danforth
            ((-79.425, 43.640), (-79.405, 43.655)),  # Liberty Village
        ],
        "rules": {
            **DEFAULT_RULES,
            "downtown":   {"c": 400, "m": 180, "r": 4.00, "f": "08:00", "t": "21:00", "d": [1,2,3,4,5,6]},
            "commercial": {"c": 250, "m": 180, "r": 2.50, "f": "09:00", "t": "21:00", "d": [1,2,3,4,5,6]},
        },
        "tiles": 4,
    },

    # ─── CHICAGO ──────────────────────────────────────────────────────────
    "chicago": {
        "bbox": (41.64, -87.94, 42.03, -87.52),
        "downtown": [
            ((-87.640, 41.875), (-87.620, 41.895)),  # The Loop
            ((-87.645, 41.890), (-87.620, 41.910)),  # River North
        ],
        "commercial": [
            ((-87.665, 41.900), (-87.635, 41.925)),  # Lincoln Park / Old Town
            ((-87.665, 41.870), (-87.640, 41.890)),  # West Loop / Greektown
            ((-87.660, 41.925), (-87.640, 41.950)),  # Lakeview / Wrigleyville
        ],
        "rules": {
            **DEFAULT_RULES,
            "downtown":   {"c": 700, "m":  60, "r": 7.00, "f": "08:00", "t": "21:00", "d": [1,2,3,4,5,6,7]},
            "commercial": {"c": 250, "m": 120, "r": 2.50, "f": "08:00", "t": "21:00", "d": [1,2,3,4,5,6]},
        },
        "tiles": 4,
    },

    # ─── NEW YORK (déjà 135% → skip pour éviter sur-couverture) ───────────
    # "nyc": SKIP

    # ─── LOS ANGELES ──────────────────────────────────────────────────────
    "la": {
        "bbox": (33.70, -118.67, 34.34, -118.16),
        "downtown": [
            ((-118.265, 34.040), (-118.235, 34.060)),  # DTLA core
            ((-118.265, 34.030), (-118.240, 34.050)),  # Financial District
        ],
        "commercial": [
            ((-118.350, 34.090), (-118.310, 34.110)),  # Hollywood
            ((-118.395, 34.060), (-118.355, 34.080)),  # West Hollywood
            ((-118.490, 34.000), (-118.460, 34.020)),  # Santa Monica
            ((-118.405, 33.985), (-118.375, 34.005)),  # Culver City / Venice
            ((-118.300, 34.075), (-118.270, 34.100)),  # Echo Park / Silver Lake
        ],
        "rules": {
            **DEFAULT_RULES,
            "downtown":   {"c": 250, "m": 120, "r": 2.50, "f": "08:00", "t": "20:00", "d": [1,2,3,4,5,6]},
            "commercial": {"c": 150, "m": 120, "r": 1.50, "f": "08:00", "t": "20:00", "d": [1,2,3,4,5,6]},
        },
        "tiles": 6,
    },

    # ─── SAN FRANCISCO ────────────────────────────────────────────────────
    "sf": {
        "bbox": (37.70, -122.52, 37.83, -122.36),
        "downtown": [
            ((-122.420, 37.785), (-122.395, 37.800)),  # Financial District / SoMa
            ((-122.420, 37.775), (-122.395, 37.790)),  # SoMa
        ],
        "commercial": [
            ((-122.435, 37.755), (-122.405, 37.775)),  # Mission
            ((-122.450, 37.770), (-122.420, 37.790)),  # Hayes Valley / Civic Center
            ((-122.450, 37.785), (-122.420, 37.805)),  # Russian Hill / North Beach
            ((-122.470, 37.775), (-122.440, 37.795)),  # Pacific Heights
        ],
        "rules": {
            **DEFAULT_RULES,
            "downtown":   {"c": 400, "m": 240, "r": 4.00, "f": "07:00", "t": "22:00", "d": [1,2,3,4,5,6]},
            "commercial": {"c": 225, "m": 180, "r": 2.25, "f": "09:00", "t": "18:00", "d": [1,2,3,4,5,6]},
        },
        "tiles": 2,
    },

    # ─── SEATTLE ──────────────────────────────────────────────────────────
    "seattle": {
        "bbox": (47.49, -122.46, 47.74, -122.22),
        "downtown": [
            ((-122.345, 47.600), (-122.325, 47.620)),  # Downtown
            ((-122.345, 47.610), (-122.325, 47.625)),  # Belltown
        ],
        "commercial": [
            ((-122.330, 47.615), (-122.305, 47.635)),  # Capitol Hill
            ((-122.355, 47.655), (-122.330, 47.675)),  # Fremont / Wallingford
            ((-122.385, 47.665), (-122.360, 47.685)),  # Ballard
            ((-122.320, 47.575), (-122.295, 47.595)),  # Beacon Hill / Mt Baker
        ],
        "rules": {
            **DEFAULT_RULES,
            "downtown":   {"c": 500, "m": 120, "r": 5.00, "f": "08:00", "t": "20:00", "d": [1,2,3,4,5,6]},
            "commercial": {"c": 200, "m": 120, "r": 2.00, "f": "08:00", "t": "20:00", "d": [1,2,3,4,5,6]},
        },
        "tiles": 4,
    },

    # ─── BOSTON ───────────────────────────────────────────────────────────
    "boston": {
        "bbox": (42.30, -71.18, 42.42, -70.99),
        "downtown": [
            ((-71.070, 42.350), (-71.050, 42.365)),  # Downtown / Financial District
            ((-71.080, 42.345), (-71.060, 42.360)),  # Back Bay / Beacon Hill
        ],
        "commercial": [
            ((-71.110, 42.345), (-71.085, 42.360)),  # Allston / Brighton
            ((-71.105, 42.370), (-71.080, 42.390)),  # Cambridge (proxy)
            ((-71.075, 42.330), (-71.050, 42.350)),  # South End / Roxbury
        ],
        "rules": {
            **DEFAULT_RULES,
            "downtown":   {"c": 375, "m": 120, "r": 3.75, "f": "08:00", "t": "20:00", "d": [1,2,3,4,5,6]},
            "commercial": {"c": 175, "m": 120, "r": 1.75, "f": "08:00", "t": "20:00", "d": [1,2,3,4,5,6]},
        },
        "tiles": 2,
    },

    # ─── OTTAWA (capitale fédérale, marché bilingue) ──────────────────────
    "ottawa": {
        "bbox": (45.25, -76.00, 45.55, -75.50),
        "downtown": [
            ((-75.720, 45.415), (-75.685, 45.430)),  # Centretown / Parliament
            ((-75.705, 45.420), (-75.680, 45.435)),  # ByWard Market
        ],
        "commercial": [
            ((-75.745, 45.395), (-75.710, 45.415)),  # Glebe / Bank St
            ((-75.690, 45.430), (-75.665, 45.450)),  # Lowertown / Vanier
            ((-75.745, 45.425), (-75.715, 45.445)),  # Hintonburg / Wellington W
        ],
        "rules": {
            **DEFAULT_RULES,
            "downtown":   {"c": 350, "m": 180, "r": 3.50, "f": "08:00", "t": "20:30", "d": [1,2,3,4,5,6]},
            "commercial": {"c": 200, "m": 180, "r": 2.00, "f": "08:00", "t": "18:00", "d": [1,2,3,4,5,6]},
        },
        "tiles": 4,
    },

    # ─── CALGARY ──────────────────────────────────────────────────────────
    "calgary": {
        "bbox": (50.85, -114.30, 51.18, -113.85),
        "downtown": [
            ((-114.085, 51.040), (-114.055, 51.060)),  # Downtown Commercial Core
            ((-114.075, 51.045), (-114.050, 51.055)),  # Beltline
        ],
        "commercial": [
            ((-114.105, 51.030), (-114.075, 51.050)),  # Kensington / Hillhurst
            ((-114.075, 51.030), (-114.050, 51.050)),  # Mission / 17th Ave
            ((-114.050, 51.030), (-114.025, 51.050)),  # Inglewood
        ],
        "rules": {
            **DEFAULT_RULES,
            "downtown":   {"c": 500, "m": 120, "r": 5.00, "f": "07:00", "t": "18:00", "d": [1,2,3,4,5]},
            "commercial": {"c": 300, "m": 120, "r": 3.00, "f": "09:00", "t": "18:00", "d": [1,2,3,4,5,6]},
        },
        "tiles": 4,
    },

    # ─── WASHINGTON DC ────────────────────────────────────────────────────
    "dc": {
        "bbox": (38.80, -77.12, 38.99, -76.91),
        "downtown": [
            ((-77.045, 38.895), (-77.020, 38.910)),  # Downtown / Penn Quarter
            ((-77.045, 38.900), (-77.020, 38.915)),  # Mt Vernon Square
            ((-77.045, 38.890), (-77.020, 38.905)),  # Federal Triangle
        ],
        "commercial": [
            ((-77.045, 38.910), (-77.015, 38.930)),  # Logan Circle / U Street
            ((-77.045, 38.890), (-77.015, 38.905)),  # Foggy Bottom
            ((-77.090, 38.905), (-77.065, 38.925)),  # Georgetown
            ((-77.000, 38.875), (-76.970, 38.895)),  # Capitol Hill
        ],
        "rules": {
            **DEFAULT_RULES,
            "downtown":   {"c": 230, "m": 120, "r": 2.30, "f": "07:00", "t": "22:00", "d": [1,2,3,4,5,6]},
            "commercial": {"c": 200, "m": 120, "r": 2.00, "f": "07:00", "t": "20:30", "d": [1,2,3,4,5,6]},
        },
        "tiles": 4,
    },

    # ─── PORTLAND, OR ─────────────────────────────────────────────────────
    "portland": {
        "bbox": (45.43, -122.82, 45.65, -122.45),
        "downtown": [
            ((-122.685, 45.515), (-122.665, 45.530)),  # Downtown
            ((-122.685, 45.520), (-122.670, 45.535)),  # Pearl District
        ],
        "commercial": [
            ((-122.665, 45.515), (-122.640, 45.535)),  # Lloyd / Inner NE
            ((-122.650, 45.510), (-122.625, 45.530)),  # Central Eastside / Buckman
            ((-122.690, 45.480), (-122.665, 45.500)),  # SW / Multnomah
            ((-122.665, 45.555), (-122.640, 45.575)),  # Mississippi / N Williams
        ],
        "rules": {
            **DEFAULT_RULES,
            "downtown":   {"c": 200, "m": 180, "r": 2.00, "f": "08:00", "t": "19:00", "d": [1,2,3,4,5,6]},
            "commercial": {"c": 160, "m": 180, "r": 1.60, "f": "08:00", "t": "19:00", "d": [1,2,3,4,5,6]},
        },
        "tiles": 4,
    },

    # ─── PHILADELPHIA ─────────────────────────────────────────────────────
    "philly": {
        "bbox": (39.87, -75.30, 40.14, -74.95),
        "downtown": [
            ((-75.175, 39.945), (-75.145, 39.960)),  # Center City East
            ((-75.180, 39.948), (-75.155, 39.965)),  # Old City / Independence
            ((-75.180, 39.945), (-75.160, 39.960)),  # Rittenhouse / Logan Square
        ],
        "commercial": [
            ((-75.215, 39.945), (-75.180, 39.965)),  # University City
            ((-75.155, 39.930), (-75.130, 39.950)),  # Northern Liberties / Fishtown
            ((-75.185, 39.930), (-75.155, 39.945)),  # South Street / Bella Vista
            ((-75.160, 39.960), (-75.135, 39.980)),  # Fairmount
        ],
        "rules": {
            **DEFAULT_RULES,
            "downtown":   {"c": 300, "m": 120, "r": 3.00, "f": "08:00", "t": "20:00", "d": [1,2,3,4,5,6]},
            "commercial": {"c": 200, "m": 120, "r": 2.00, "f": "08:00", "t": "20:00", "d": [1,2,3,4,5,6]},
        },
        "tiles": 4,
    },

    # ─── DENVER ───────────────────────────────────────────────────────────
    "denver": {
        "bbox": (39.60, -105.10, 39.85, -104.85),
        "downtown": [
            ((-105.005, 39.740), (-104.985, 39.755)),  # Downtown / CBD
            ((-105.000, 39.745), (-104.975, 39.760)),  # LoDo / Union Station
        ],
        "commercial": [
            ((-105.000, 39.730), (-104.975, 39.745)),  # Capitol Hill / Cap Hill
            ((-104.985, 39.745), (-104.960, 39.765)),  # RiNo / Five Points
            ((-105.020, 39.715), (-104.990, 39.735)),  # Wash Park / Cherry Creek
        ],
        "rules": {
            **DEFAULT_RULES,
            "downtown":   {"c": 200, "m": 120, "r": 2.00, "f": "08:00", "t": "22:00", "d": [1,2,3,4,5,6]},
            "commercial": {"c": 100, "m": 120, "r": 1.00, "f": "08:00", "t": "18:00", "d": [1,2,3,4,5,6]},
        },
        "tiles": 4,
    },

    # ─── AUSTIN ───────────────────────────────────────────────────────────
    "austin": {
        "bbox": (30.18, -97.90, 30.45, -97.60),
        "downtown": [
            ((-97.755, 30.260), (-97.730, 30.275)),  # Downtown / 6th
            ((-97.760, 30.265), (-97.735, 30.280)),  # Warehouse District
        ],
        "commercial": [
            ((-97.750, 30.280), (-97.720, 30.305)),  # UT Austin / West Campus
            ((-97.745, 30.245), (-97.720, 30.265)),  # SoCo / Bouldin Creek
            ((-97.730, 30.265), (-97.700, 30.285)),  # East Austin
        ],
        "rules": {
            **DEFAULT_RULES,
            "downtown":   {"c": 200, "m": 180, "r": 2.00, "f": "08:00", "t": "00:00", "d": [1,2,3,4,5,6,7]},
            "commercial": {"c": 150, "m": 180, "r": 1.50, "f": "08:00", "t": "20:00", "d": [1,2,3,4,5,6]},
        },
        "tiles": 4,
    },
}


# =============================================================================
# OVERPASS
# =============================================================================

def fetch_osm_ways(bbox, city_label):
    """Récupère les centres des ways highway=residential|tertiary|secondary."""
    s, w, n, e = bbox
    query = f"""[out:json][timeout:180];
(
  way["highway"~"^(residential|tertiary|secondary|unclassified)$"]
     ["access"!~"^(no|private)$"]
     ({s},{w},{n},{e});
);
out center;"""
    try:
        r = requests.post(OVERPASS, data={"data": query}, headers=HEADERS, timeout=200)
        r.raise_for_status()
        elements = r.json().get("elements", [])
        print(f"    [{city_label}] {len(elements):,} ways")
        return elements
    except Exception as e:
        print(f"    [{city_label}] OSM error: {e}")
        return []


def fetch_osm_ways_tiled(bbox, city_label, tiles=4):
    """Découpe la bbox en quadrants pour éviter les timeouts."""
    if tiles <= 1:
        return fetch_osm_ways(bbox, city_label)

    s, w, n, e = bbox
    # tiles = nombre total de quadrants (4, 6 ou 9)
    if tiles == 6:
        # 3×2 grid
        lat_steps = [s, s + (n-s)/2, n]
        lon_steps = [w, w + (e-w)/3, w + 2*(e-w)/3, e]
    elif tiles == 9:
        # 3×3 grid
        lat_steps = [s, s + (n-s)/3, s + 2*(n-s)/3, n]
        lon_steps = [w, w + (e-w)/3, w + 2*(e-w)/3, e]
    else:  # 4 quadrants
        mid_lat = (s + n) / 2
        mid_lon = (w + e) / 2
        lat_steps = [s, mid_lat, n]
        lon_steps = [w, mid_lon, e]

    all_ways = []
    quad_n = 0
    for i in range(len(lat_steps) - 1):
        for j in range(len(lon_steps) - 1):
            quad_n += 1
            q = (lat_steps[i], lon_steps[j], lat_steps[i+1], lon_steps[j+1])
            print(f"  [{city_label}] quadrant {quad_n}/{tiles} ({q[0]:.3f},{q[1]:.3f},{q[2]:.3f},{q[3]:.3f})")
            all_ways.extend(fetch_osm_ways(q, city_label))
            time.sleep(REQUEST_DELAY)
    return all_ways


# =============================================================================
# CLASSIFICATION GÉOGRAPHIQUE
# =============================================================================

def point_in_bboxes(lon, lat, bboxes):
    """True si (lon, lat) tombe dans au moins une bbox."""
    for (lon_min, lat_min), (lon_max, lat_max) in bboxes:
        if lon_min <= lon <= lon_max and lat_min <= lat <= lat_max:
            return True
    return False


def classify_zone(lon, lat, config):
    """Retourne 'downtown' | 'commercial' | 'residential'."""
    if point_in_bboxes(lon, lat, config.get("downtown", [])):
        return "downtown"
    if point_in_bboxes(lon, lat, config.get("commercial", [])):
        return "commercial"
    return "residential"


# =============================================================================
# BUILDER PRINCIPAL
# =============================================================================

def build_city(city_id):
    config = CITY_CONFIG.get(city_id)
    if not config:
        print(f"[{city_id}] no config, skip")
        return

    path = DATA_DIR / f"{city_id}.json"
    if not path.exists():
        print(f"[{city_id}] {path} missing, skip")
        return

    print(f"\n[{city_id.upper()}] Building OSM defaults...")

    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    meters = data.get("meters", [])
    base_count = len(meters)

    # Grille de dédup : on saute tout way OSM dont le centre est à <80m d'un meter existant
    seen = set()
    for m in meters:
        try:
            key = f"{m['x']:.{DEDUP_PRECISION}f},{m['y']:.{DEDUP_PRECISION}f}"
            seen.add(key)
        except (KeyError, TypeError):
            continue

    # Fetch OSM ways
    ways = fetch_osm_ways_tiled(
        config["bbox"], city_id.upper(), tiles=config.get("tiles", 4)
    )

    # Génération
    added_by_zone = {"downtown": 0, "commercial": 0, "residential": 0}
    for el in ways:
        center = el.get("center", {})
        lon = center.get("lon")
        lat = center.get("lat")
        if lon is None or lat is None:
            continue

        key = f"{lon:.{DEDUP_PRECISION}f},{lat:.{DEDUP_PRECISION}f}"
        if key in seen:
            continue
        seen.add(key)

        zone = classify_zone(lon, lat, config)
        # Skip residential dans certains cas si on veut moins de bruit ?
        # Pour l'instant on garde — c'est ce qui couvre le plus.

        rule = config["rules"][zone]
        meters.append({
            "x": float(lon), "y": float(lat),
            "c": rule["c"],
            "p": [{
                "d": rule["d"],
                "f": rule["f"],
                "t": rule["t"],
                "m": rule["m"],
                "r": rule["r"],
            }],
        })
        added_by_zone[zone] += 1

    added_total = sum(added_by_zone.values())
    print(f"[{city_id}] +{added_total:,} OSM defaults "
          f"(downtown={added_by_zone['downtown']:,}, "
          f"commercial={added_by_zone['commercial']:,}, "
          f"residential={added_by_zone['residential']:,})")
    print(f"[{city_id}] Total meters: {base_count:,} -> {len(meters):,}")

    data["meters"] = meters
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))

    size_kb = path.stat().st_size / 1024
    print(f"[{city_id}] Saved: {path.name} ({size_kb:,.0f} KB)")


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else None
    if target:
        build_city(target)
    else:
        for city_id in CITY_CONFIG.keys():
            build_city(city_id)
    print("\nDONE — run `python scripts/test_coverage.py` to verify.")


if __name__ == "__main__":
    main()
