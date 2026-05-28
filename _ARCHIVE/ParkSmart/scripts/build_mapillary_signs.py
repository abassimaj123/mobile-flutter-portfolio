#!/usr/bin/env python3
"""
build_mapillary_signs.py
========================
Récupère les panneaux de stationnement détectés par ML depuis Mapillary
(https://www.mapillary.com/developer/api-documentation).

Mapillary a 1.5 milliard d'images de rue et un classifieur ML qui détecte les
panneaux. Endpoint `map_features` retourne les détections de panneaux avec
coordonnées GPS et classification (regulatory--parking-*, etc.).

Tier gratuit : 50 000 requêtes / mois.

Setup :
  1. Créer compte sur https://www.mapillary.com/dashboard/developers
  2. Créer une "Client App", récupérer le token (commence par MLY|...)
  3. export MAPILLARY_TOKEN="MLY|xxxxx"
  4. python scripts/build_mapillary_signs.py

Sortie : append des entries dans `assets/data/{city}.json` (clé `meters`).

Object classes ciblées :
  - regulatory--parking--g1                 (parking allowed)
  - regulatory--parking--g2                 (parking conditional)
  - regulatory--no-parking--g1              (no parking)
  - regulatory--no-parking--g2              (no parking conditional)
  - regulatory--parking-restrictions--g1    (time-limited parking)
"""
import os
import json
import sys
import time
import requests
from pathlib import Path

DATA_DIR = Path("assets/data")
TOKEN = os.environ.get("MAPILLARY_TOKEN", "")
API = "https://graph.mapillary.com"
HEADERS = {"User-Agent": "ParkSmart/1.0 (mapillary signs)"}

# Object classes à requêter (catégorie regulatory parking)
PARKING_CLASSES = [
    "regulatory--parking--g1",
    "regulatory--parking--g2",
    "regulatory--no-parking--g1",
    "regulatory--no-parking--g2",
    "regulatory--parking-restrictions--g1",
    "regulatory--no-stopping--g1",
]

# Bboxes par ville : (west, south, east, north)
CITY_BBOX = {
    "montreal":  (-73.97, 45.40, -73.45, 45.70),
    "capitale":  (-71.40, 46.75, -71.10, 46.92),
    "vancouver": (-123.27, 49.20, -123.02, 49.32),
    "toronto":   (-79.64, 43.58, -79.12, 43.86),
    "chicago":   (-87.94, 41.64, -87.52, 42.03),
    "la":        (-118.67, 33.70, -118.16, 34.34),
    "sf":        (-122.52, 37.70, -122.36, 37.83),
    "seattle":   (-122.46, 47.49, -122.22, 47.74),
    "boston":    (-71.18, 42.30, -70.99, 42.42),
    # nyc skip (sur-couvert déjà)
}


def fetch_map_features(bbox, class_filter, limit=2000):
    """
    Mapillary API : /map_features
    Filtre par object_values (liste de classes) + bbox (W,S,E,N).
    """
    if not TOKEN:
        print("ERROR: MAPILLARY_TOKEN missing")
        return []

    w, s, e, n = bbox
    params = {
        "access_token": TOKEN,
        "fields": "id,geometry,object_value,first_seen_at",
        "object_values": ",".join(class_filter),
        "bbox": f"{w},{s},{e},{n}",
        "limit": limit,
    }
    try:
        r = requests.get(f"{API}/map_features",
                         params=params, headers=HEADERS, timeout=60)
        r.raise_for_status()
        return r.json().get("data", [])
    except Exception as ex:
        print(f"  Mapillary error: {ex}")
        return []


def fetch_tiled(bbox, city, tiles=4):
    """Découpe en quadrants pour gros bbox."""
    w, s, e, n = bbox
    mid_lat = (s + n) / 2
    mid_lon = (w + e) / 2
    quads = [
        (w, s, mid_lon, mid_lat),
        (mid_lon, s, e, mid_lat),
        (w, mid_lat, mid_lon, n),
        (mid_lon, mid_lat, e, n),
    ]
    all_feats = []
    for q in quads:
        print(f"  [{city}] quadrant {q}")
        feats = fetch_map_features(q, PARKING_CLASSES)
        print(f"    {len(feats)} features")
        all_feats.extend(feats)
        time.sleep(1.0)
    return all_feats


def feature_to_meter(feat):
    """Convertit une feature Mapillary en meter entry."""
    geom = feat.get("geometry", {})
    coords = geom.get("coordinates", [])
    if not coords or len(coords) < 2:
        return None
    lon, lat = float(coords[0]), float(coords[1])

    obj = feat.get("object_value", "")
    # Heuristique : no-parking / no-stopping = c=0 + max_stay=0 (interdit)
    # parking = c=0, max_stay=120 (gratuit 2h default)
    # parking-restrictions = c=0, max_stay=60 (zone restreinte)
    if "no-parking" in obj or "no-stopping" in obj:
        c, m = 0, 0
    elif "parking-restrictions" in obj:
        c, m = 0, 60
    else:
        c, m = 0, 120

    return {
        "x": lon, "y": lat, "c": c,
        "p": [{
            "d": [1,2,3,4,5,6,7],
            "f": "00:00", "t": "23:59",
            "m": m, "r": 0,
        }],
    }


def build_city(city_id):
    bbox = CITY_BBOX.get(city_id)
    if not bbox:
        return
    path = DATA_DIR / f"{city_id}.json"
    if not path.exists():
        print(f"[{city_id}] {path} missing")
        return

    print(f"\n[{city_id.upper()}] Mapillary signs...")
    feats = fetch_tiled(bbox, city_id.upper())
    print(f"[{city_id}] {len(feats):,} features fetched")

    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    meters = data.get("meters", [])
    seen = set(f"{m['x']:.4f},{m['y']:.4f}" for m in meters)

    added = 0
    for feat in feats:
        m = feature_to_meter(feat)
        if not m:
            continue
        key = f"{m['x']:.4f},{m['y']:.4f}"
        if key in seen:
            continue
        seen.add(key)
        meters.append(m)
        added += 1

    print(f"[{city_id}] +{added:,} new sign-based meters → total {len(meters):,}")
    data["meters"] = meters
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))


def main():
    if not TOKEN:
        print("=" * 60)
        print("MAPILLARY_TOKEN environment variable not set")
        print("=" * 60)
        print("Setup:")
        print("  1. Sign up: https://www.mapillary.com/dashboard/developers")
        print("  2. Create Client App, copy access token")
        print("  3. On Windows: set MAPILLARY_TOKEN=MLY|xxxxx")
        print("     On bash:    export MAPILLARY_TOKEN='MLY|xxxxx'")
        print("  4. Re-run this script")
        sys.exit(1)

    target = sys.argv[1] if len(sys.argv) > 1 else None
    if target:
        build_city(target)
    else:
        for city_id in CITY_BBOX.keys():
            build_city(city_id)
            time.sleep(2)


if __name__ == "__main__":
    main()
