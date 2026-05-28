#!/usr/bin/env python3
"""
cleanup_data.py
===============
Corrige les problèmes détectés par validate_data.py :

  1. Doublons exacts (même lon/lat à 5 décimales) → garde la meilleure entrée
  2. Out-of-bbox → supprime (probablement erreur de parsing)
  3. c_r_mismatch (Seattle) → c = max(r * 100) sur toutes les périodes
  4. Périodes vides ou invalides → supprime
"""
import json
from pathlib import Path

DATA_DIR = Path("assets/data")

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


def meter_quality_score(m):
    """Score : plus c'est haut, plus on garde. Préférence pour rules paid > free."""
    periods = m.get("p", [])
    if not periods:
        return 0
    score = m.get("c", 0)  # paid > free
    score += len(periods) * 10  # multi-period > single
    return score


def cleanup_city(city_id):
    path = DATA_DIR / f"{city_id}.json"
    if not path.exists():
        return
    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    meters = data.get("meters", [])
    n_before = len(meters)

    # ── 1. Fix c = max(r * 100) sur toutes les périodes ───────────────────
    c_fixed = 0
    for m in meters:
        periods = m.get("p", [])
        if not periods:
            continue
        max_rate = max((float(p.get("r", 0) or 0) for p in periods), default=0)
        if max_rate > 0:
            expected_c = int(max_rate * 100)
            current_c = m.get("c", 0)
            if abs(current_c - expected_c) > 1:
                m["c"] = expected_c
                c_fixed += 1

    # ── 2. Supprimer out-of-bbox ──────────────────────────────────────────
    bbox = CITY_BBOX.get(city_id)
    out_removed = 0
    if bbox:
        s, w, n, e = bbox
        kept = []
        for m in meters:
            x, y = m.get("x"), m.get("y")
            if x is None or y is None:
                continue
            if not (s <= y <= n and w <= x <= e):
                out_removed += 1
                continue
            kept.append(m)
        meters = kept

    # ── 3. Dédup exact (5 décimales = ~1m) — garder le meilleur ───────────
    by_key = {}
    for m in meters:
        x, y = m.get("x"), m.get("y")
        if x is None or y is None:
            continue
        key = f"{x:.5f},{y:.5f}"
        if key not in by_key or meter_quality_score(m) > meter_quality_score(by_key[key]):
            by_key[key] = m
    exact_removed = len(meters) - len(by_key)
    meters = list(by_key.values())

    # ── 4. Supprimer périodes invalides ───────────────────────────────────
    invalid_periods = 0
    for m in meters:
        good_p = []
        for p in m.get("p", []):
            f_t, t_t = p.get("f", ""), p.get("t", "")
            m_v = p.get("m", -1)
            days = p.get("d", [])
            if not f_t or not t_t or m_v < 0 or not days:
                invalid_periods += 1
                continue
            if any(d < 1 or d > 7 for d in days):
                invalid_periods += 1
                continue
            good_p.append(p)
        m["p"] = good_p
    # Remove meters with no valid periods
    meters_with_p = [m for m in meters if m.get("p")]
    no_period_removed = len(meters) - len(meters_with_p)
    meters = meters_with_p

    n_after = len(meters)
    print(f"[{city_id}] meters {n_before:,} -> {n_after:,}")
    print(f"  c fixed       : {c_fixed:,}")
    print(f"  out-of-bbox   : {out_removed:,}")
    print(f"  exact dups    : {exact_removed:,}")
    print(f"  invalid period: {invalid_periods:,}")
    print(f"  no-period     : {no_period_removed:,}")

    data["meters"] = meters
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))


def main():
    print("=" * 60)
    print("ParkSmart Data Cleanup")
    print("=" * 60)
    for city_id in CITY_BBOX.keys():
        cleanup_city(city_id)
    print("=" * 60)
    print("Done. Re-run validate_data.py to verify.")


if __name__ == "__main__":
    main()
