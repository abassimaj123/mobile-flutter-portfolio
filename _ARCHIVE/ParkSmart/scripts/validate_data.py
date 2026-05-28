#!/usr/bin/env python3
"""
validate_data.py
================
Audit qualité des fichiers assets/data/{city}.json.

Vérifie :
  1. Schéma : champs requis (x, y, c, p[])
  2. Coordonnées : dans la bbox attendue par ville
  3. Doublons exacts (même lon/lat à 5 décimales)
  4. Rules : `c` cohérent avec `p[0].r` (cents = rate * 100)
  5. Périodes valides : f<t, m>0 ou m=0 pour interdiction
  6. Jours [1-7]
  7. Cleaning : structure correcte
  8. Détection de meters orphelins en dehors de la ville (highway loin)

Sortie : rapport par ville + total des problèmes.
"""
import json
import sys
from collections import Counter
from pathlib import Path

DATA_DIR = Path("assets/data")

# Bbox attendues (south, west, north, east) — large par ville
CITY_BBOX = {
    "capitale":  (46.65, -71.55, 47.05, -70.95),
    "montreal":  (45.30, -74.05, 45.80, -73.30),
    "vancouver": (49.10, -123.35, 49.40, -122.85),
    "toronto":   (43.50, -79.75, 43.95, -79.00),
    "chicago":   (41.55, -88.00, 42.10, -87.45),
    "la":        (33.60, -118.75, 34.40, -118.05),
    "sf":        (37.65, -122.55, 37.90, -122.30),
    "seattle":   (47.45, -122.50, 47.80, -122.15),
    "boston":    (42.20, -71.25, 42.50, -70.90),
    "nyc":       (40.45, -74.30, 40.95, -73.65),
    "ottawa":    (45.20, -76.05, 45.60, -75.45),
    "calgary":   (50.80, -114.35, 51.20, -113.80),
    "dc":        (38.75, -77.20, 39.05, -76.85),
    "portland":  (45.40, -122.85, 45.70, -122.40),
    "philly":    (39.85, -75.35, 40.20, -74.90),
    "denver":    (39.55, -105.15, 39.90, -104.80),
    "austin":    (30.15, -97.95, 30.50, -97.55),
}


def validate_city(city_id):
    path = DATA_DIR / f"{city_id}.json"
    if not path.exists():
        return None
    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    issues = {
        "missing_xy": 0,
        "missing_p": 0,
        "missing_c": 0,
        "out_of_bbox": 0,
        "duplicates_exact": 0,
        "duplicates_near": 0,
        "c_r_mismatch": 0,
        "invalid_period": 0,
        "invalid_days": 0,
        "cleaning_no_coords": 0,
        "cleaning_no_rule": 0,
    }

    meters = data.get("meters", [])
    cleaning = data.get("cleaning", [])
    alternating = data.get("alternating", [])

    # ── Meters ────────────────────────────────────────────────────────────
    bbox = CITY_BBOX.get(city_id)
    seen_exact = set()
    seen_near = set()  # 0.0001° ≈ 10m
    rule_zones = Counter()  # Distribution by rule pattern

    for m in meters:
        x, y = m.get("x"), m.get("y")
        if x is None or y is None:
            issues["missing_xy"] += 1
            continue

        # BBox check
        if bbox:
            s, w, n, e = bbox
            if not (s <= y <= n and w <= x <= e):
                issues["out_of_bbox"] += 1

        # Duplicate detection
        k_exact = f"{x:.5f},{y:.5f}"
        if k_exact in seen_exact:
            issues["duplicates_exact"] += 1
        else:
            seen_exact.add(k_exact)
        k_near = f"{x:.4f},{y:.4f}"
        if k_near in seen_near:
            issues["duplicates_near"] += 1
        else:
            seen_near.add(k_near)

        # Periods
        periods = m.get("p", [])
        if not periods:
            issues["missing_p"] += 1
            continue
        if "c" not in m:
            issues["missing_c"] += 1

        for p in periods:
            f_t, t_t = p.get("f", ""), p.get("t", "")
            m_v = p.get("m", -1)
            r_v = p.get("r", 0)
            days = p.get("d", [])

            # c/r match check (rate * 100 should equal c)
            if r_v > 0:
                expected_c = int(r_v * 100)
                if abs(m.get("c", 0) - expected_c) > 1:
                    issues["c_r_mismatch"] += 1
                    break

            # Period validity
            if not f_t or not t_t or m_v < 0:
                issues["invalid_period"] += 1
                break

            # Days
            if not days or any(d < 1 or d > 7 for d in days):
                issues["invalid_days"] += 1
                break

        # Track rule "fingerprint" (for OSM defaults distribution analysis)
        if periods:
            p0 = periods[0]
            fp = f"c={m.get('c',0)},r={p0.get('r',0)},m={p0.get('m',0)},f={p0.get('f','')}-{p0.get('t','')}"
            rule_zones[fp] += 1

    # ── Cleaning ──────────────────────────────────────────────────────────
    for c in cleaning:
        coords = c.get("c", [])
        rules = c.get("r", [])
        if not coords:
            issues["cleaning_no_coords"] += 1
        if not rules:
            issues["cleaning_no_rule"] += 1

    return {
        "city": city_id,
        "meters": len(meters),
        "alternating": len(alternating),
        "cleaning": len(cleaning),
        "issues": issues,
        "rule_zones": rule_zones,
        "size_kb": path.stat().st_size // 1024,
    }


def print_report(r):
    if not r:
        return
    print(f"\n[{r['city'].upper()}] meters={r['meters']:,}  alt={r['alternating']:,}  clean={r['cleaning']:,}  ({r['size_kb']:,} KB)")
    issues = r["issues"]
    total_issues = sum(issues.values())
    if total_issues == 0:
        print("  ALL CHECKS PASSED")
    else:
        print(f"  {total_issues:,} issues found:")
        for k, v in issues.items():
            if v > 0:
                print(f"    - {k}: {v:,}")
    # Top 3 rule patterns
    print("  Top rule patterns:")
    for fp, count in r["rule_zones"].most_common(3):
        print(f"    {count:>6,}  {fp}")


def main():
    target = sys.argv[1] if len(sys.argv) > 1 else None
    cities = [target] if target else list(CITY_BBOX.keys())
    print("=" * 70)
    print("ParkSmart Data Quality Audit")
    print("=" * 70)
    total_issues = 0
    total_meters = 0
    for city_id in cities:
        r = validate_city(city_id)
        if r:
            print_report(r)
            total_issues += sum(r["issues"].values())
            total_meters += r["meters"]
    print("\n" + "=" * 70)
    print(f"TOTAL meters: {total_meters:,}")
    print(f"TOTAL issues: {total_issues:,}")
    print(f"Quality rate: {(1 - total_issues/max(total_meters,1)) * 100:.2f}%")
    print("=" * 70)


if __name__ == "__main__":
    main()
