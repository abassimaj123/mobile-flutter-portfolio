#!/usr/bin/env python3
"""
fix_data_quality.py — Patch assets/data/*.json pour corriger les bugs de qualité.

Bugs fixed :
1. Champ `c` dans meters = CENTIMES (cents/100 = $/h via ratePerHour Flutter).
   Tous les scripts non-Montréal stockaient max_stay en minutes → taux affiché faux.
   Fix : c = int(periods[0]['r'] * 100) depuis le champ rate de la première période.

2. Chicago cleaning : manque mf=4, mt=11 (saison Avr–Nov).
   Fix : ajout mf/mt à toutes les rules de chicago.json.

3. Montreal : 3 entrées AMD avec m=0 (max_stay) → affiche "max 0 min".
   Fix : m = 30 minimum.

4. Montreal signalisation : nouvelles entrées ont c=max_stay et r=0 (gratuit/inconnu).
   Fix : c = 0 pour ces entrées (r=0 et c ≤ 240).

Note : AMD Montréal est DÉJÀ correct (c=425 = $4.25/h), on ne le touche pas.
"""

import json
from pathlib import Path

DATA_DIR = Path("assets/data")


def fix_meters_c_field(data, city_id):
    """c = rate en CENTIMES (periods[0]['r'] * 100). c=0 si r=0 (gratuit)."""
    fixed = 0
    for meter in data.get("meters", []):
        periods = meter.get("p", [])
        if not periods:
            continue
        r = float(periods[0].get("r", 0) or 0)
        rate_cents = int(r * 100)
        if meter.get("c", 0) != rate_cents:
            meter["c"] = rate_cents
            fixed += 1
    print(f"  [{city_id}] c field: {fixed}/{len(data.get('meters', []))} meters fixed")
    return fixed


def fix_chicago_cleaning_months(data):
    """Ajouter mf=4, mt=11 (Avr–Nov) à toutes les cleaning rules Chicago."""
    fixed = 0
    for seg in data.get("cleaning", []):
        for rule in seg.get("r", []):
            if "mf" not in rule:
                rule["mf"] = 4
                rule["mt"] = 11
                fixed += 1
    print(f"  [chicago] mf=4/mt=11 ajouté à {fixed} règles de nettoyage (Avr–Nov)")
    return fixed


def fix_montreal_m_zero(data):
    """Corriger les entrées AMD où m=0 → m=30 (30 min minimum)."""
    fixed = 0
    for meter in data.get("meters", []):
        for p in meter.get("p", []):
            if (p.get("m") or 1) == 0:
                p["m"] = 30
                fixed += 1
    if fixed:
        print(f"  [montreal] {fixed} périodes m=0 → m=30")
    else:
        print(f"  [montreal] Aucune période m=0 trouvée")
    return fixed


def fix_montreal_signalisation_c(data):
    """
    Entrées signalisation (ajoutées par build_montreal) :
      - r=0 (gratuit/inconnu) ET c=max_stay (≤240) → mettre c=0
    AMD originaux : c > 200 (vrais centimes) → on ne touche pas.
    """
    fixed = 0
    for m in data.get("meters", []):
        periods = m.get("p", [])
        if not periods:
            continue
        r_val = float(periods[0].get("r", 1) or 1)
        c_val = m.get("c", 0)
        # Signalisation: r==0 (gratuit) et c ≤ 240 (stocké comme max_stay minutes)
        if r_val == 0.0 and 0 < c_val <= 240:
            m["c"] = 0
            fixed += 1
    if fixed:
        print(f"  [montreal] {fixed} entrées signalisation c→0 (gratuit)")
    return fixed


def print_sample(data, city_id, n=3):
    """Afficher quelques meters pour vérification visuelle."""
    meters = data.get("meters", [])
    if not meters:
        return
    print(f"  [{city_id}] Sample (c=cents -> $/h) :")
    for m in meters[:n]:
        c = m.get("c", 0)
        p0 = m.get("p", [{}])[0]
        print(f"    c={c} = ${c/100:.2f}/h | r={p0.get('r',0)} | m={p0.get('m','?')}min | "
              f"d={p0.get('d',[])} {p0.get('f','?')}-{p0.get('t','?')}")


def main():
    print("=" * 60)
    print("ParkSmart — Data Quality Fix")
    print("=" * 60)

    # ── 1. Villes dont le champ c = max_stay (bug) ─────────────────────────
    # NE PAS inclure montreal (AMD c déjà correct en centimes)
    cities_fix_c = [
        "capitale",
        "vancouver",
        "nyc",
        "la",
        "chicago",
        "sf",
        "seattle",
        "toronto",
        "boston",
    ]

    for city_id in cities_fix_c:
        path = DATA_DIR / f"{city_id}.json"
        if not path.exists():
            print(f"\n[{city_id.upper()}] Fichier absent — ignoré")
            continue

        print(f"\n[{city_id.upper()}]")
        with open(path, encoding="utf-8") as f:
            data = json.load(f)

        n_before = sum(1 for m in data.get("meters", []) if m.get("c", 0) > 0)
        fix_meters_c_field(data, city_id)

        if city_id == "chicago":
            fix_chicago_cleaning_months(data)

        print_sample(data, city_id)

        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
        size = path.stat().st_size
        print(f"  [{city_id}] Saved ({size:,} bytes) OK")

    # ── 2. Montreal : m=0 + signalisation c ────────────────────────────────
    mtl_path = DATA_DIR / "montreal.json"
    if mtl_path.exists():
        print(f"\n[MONTREAL]")
        with open(mtl_path, encoding="utf-8") as f:
            data = json.load(f)

        fix_montreal_m_zero(data)
        fix_montreal_signalisation_c(data)
        print_sample(data, "montreal")

        with open(mtl_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
        size = mtl_path.stat().st_size
        print(f"  [montreal] Saved ({size:,} bytes) OK")
    else:
        print("\n[MONTREAL] Fichier absent — ignoré")

    print("\n" + "=" * 60)
    print("Done. Run: python scripts/test_coverage.py")
    print("=" * 60)


if __name__ == "__main__":
    main()
