#!/usr/bin/env python3
"""
densify_low_coverage.py
=======================
Densification ciblée des villes <50% de couverture après build_osm_defaults.py.

Ajoute des layers supplémentaires :
  1. `highway=service` (allées, accès parking, dessertes locales)
  2. `highway=*_link` (bretelles, rampes)
  3. `highway=living_street|pedestrian` (zones résidentielles partagées)

Cible : Vancouver, Capitale, Toronto (sous 50% après pass principal).
"""
import json
import sys
import time
import requests
from pathlib import Path

DATA_DIR = Path("assets/data")
OVERPASS = "https://overpass-api.de/api/interpreter"
HEADERS = {"User-Agent": "ParkSmart/1.0 (densify)"}
REQUEST_DELAY = 1.0
DEDUP_PRECISION = 3

# Bboxes ÉLARGIES pour couvrir banlieues
CITY_TARGETS = {
    "vancouver": {
        "bbox": (49.18, -123.30, 49.35, -122.95),  # élargi : Burnaby ouest
        "tiles": 4,
    },
    "capitale": {
        "bbox": (46.72, -71.45, 46.95, -71.05),   # élargi : tout l'agglomération
        "tiles": 4,
    },
    "toronto": {
        "bbox": (43.55, -79.70, 43.90, -79.05),   # élargi : Scarborough/Etobicoke
        "tiles": 9,
    },
}

# Règle générique pour ways de desserte/résidentielle élargie
DENSIFY_RULE = {
    "c": 0, "m": 120, "r": 0.0,
    "f": "08:00", "t": "18:00", "d": [1,2,3,4,5],
}


def fetch_ways(bbox, label):
    s, w, n, e = bbox
    query = f"""[out:json][timeout:180];
(
  way["highway"~"^(service|residential_link|tertiary_link|secondary_link|living_street|pedestrian|track|unclassified)$"]
     ["access"!~"^(no|private)$"]
     ["service"!~"^(driveway|parking_aisle|emergency_access)$"]
     ({s},{w},{n},{e});
);
out center;"""
    try:
        r = requests.post(OVERPASS, data={"data": query}, headers=HEADERS, timeout=200)
        r.raise_for_status()
        return r.json().get("elements", [])
    except Exception as e:
        print(f"  [{label}] error: {e}")
        return []


def tiled(bbox, label, tiles=4):
    s, w, n, e = bbox
    if tiles == 9:
        lat_steps = [s, s + (n-s)/3, s + 2*(n-s)/3, n]
        lon_steps = [w, w + (e-w)/3, w + 2*(e-w)/3, e]
    else:
        mid_lat = (s + n) / 2
        mid_lon = (w + e) / 2
        lat_steps = [s, mid_lat, n]
        lon_steps = [w, mid_lon, e]

    all_ways = []
    q = 0
    for i in range(len(lat_steps) - 1):
        for j in range(len(lon_steps) - 1):
            q += 1
            bb = (lat_steps[i], lon_steps[j], lat_steps[i+1], lon_steps[j+1])
            print(f"  [{label}] q{q}: {bb}")
            ways = fetch_ways(bb, label)
            print(f"    {len(ways):,} ways")
            all_ways.extend(ways)
            time.sleep(REQUEST_DELAY)
    return all_ways


def densify(city_id):
    cfg = CITY_TARGETS.get(city_id)
    if not cfg:
        return
    path = DATA_DIR / f"{city_id}.json"
    if not path.exists():
        return
    print(f"\n[{city_id.upper()}] Densifying...")

    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    meters = data.get("meters", [])
    base_n = len(meters)

    seen = set()
    for m in meters:
        try:
            seen.add(f"{m['x']:.{DEDUP_PRECISION}f},{m['y']:.{DEDUP_PRECISION}f}")
        except (KeyError, TypeError):
            continue

    ways = tiled(cfg["bbox"], city_id.upper(), tiles=cfg.get("tiles", 4))

    added = 0
    for el in ways:
        c = el.get("center", {})
        lon = c.get("lon"); lat = c.get("lat")
        if lon is None or lat is None:
            continue
        key = f"{lon:.{DEDUP_PRECISION}f},{lat:.{DEDUP_PRECISION}f}"
        if key in seen:
            continue
        seen.add(key)
        meters.append({
            "x": float(lon), "y": float(lat), "c": DENSIFY_RULE["c"],
            "p": [{
                "d": DENSIFY_RULE["d"], "f": DENSIFY_RULE["f"],
                "t": DENSIFY_RULE["t"], "m": DENSIFY_RULE["m"],
                "r": DENSIFY_RULE["r"],
            }],
        })
        added += 1

    print(f"[{city_id}] +{added:,} densified (total {base_n:,} -> {len(meters):,})")
    data["meters"] = meters
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else None
    if target:
        densify(target)
    else:
        for cid in CITY_TARGETS:
            densify(cid)


if __name__ == "__main__":
    main()
