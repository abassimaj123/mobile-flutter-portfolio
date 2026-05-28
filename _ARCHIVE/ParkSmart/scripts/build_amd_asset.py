"""
build_amd_asset.py
==================
Prétraitement des données AMD (Agence de mobilité durable) de Montréal.

Jointure : Places → EmplacementReglementation → Reglementations
                  → ReglementationPeriode → Periodes

Sortie : assets/amd_montreal.json
  Tableau de spots parcomètre actifs avec coordonnées précises et
  plages horaires structurées, prêt à être consommé par ParkSmart.

Format de sortie compact (1 spot = 1 entrée) :
  {
    "n": "A024",        -- ID emplacement
    "x": -73.5867,      -- longitude
    "y":  45.4918,      -- latitude
    "c":  425,          -- tarif en cents/h (425 = $4.25/h)
    "p": [              -- plages actives
      {"d":[1,2,3,4,5], "f":"09:00", "t":"21:00", "m":120},
      ...
    ]
  }
"""

import csv
import json
import os
import sys
from collections import defaultdict

# ── Chemins ────────────────────────────────────────────────────────────────────
SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
DATA_DIR     = os.path.join(SCRIPT_DIR, 'amd_data')
ASSET_DIR    = os.path.join(SCRIPT_DIR, '..', 'assets')
OUTPUT_FILE  = os.path.join(ASSET_DIR, 'amd_montreal.json')

def load_csv(filename, encoding='latin-1'):
    path = os.path.join(DATA_DIR, filename)
    with open(path, encoding=encoding, errors='replace') as f:
        return list(csv.DictReader(f))

# ── 1. Périodes : nID → {from, to, days} ──────────────────────────────────────
print("Chargement Periodes...")
periodes = {}
for row in load_csv('Periodes.csv'):
    days = []
    for i, key in enumerate(['bLun','bMar','bMer','bJeu','bVen','bSam','bDim'], 1):
        if row.get(key, '0').strip() == '1':
            days.append(i)
    if days:
        periodes[row['nID'].strip()] = {
            'f': row['dtHeureDebut'].strip()[:5],
            't': row['dtHeureFin'].strip()[:5],
            'd': days,
        }

print(f"  {len(periodes)} périodes chargées")

# ── 2. Réglementations : Name → maxMins ───────────────────────────────────────
print("Chargement Reglementations...")
regls_max = {}
for row in load_csv('Reglementations.csv'):
    try:
        max_h = float(row['maxHeures'].strip()) if row.get('maxHeures','').strip() else 2.0
    except ValueError:
        max_h = 2.0
    regls_max[row['Name'].strip()] = max(int(max_h * 60), 30)

print(f"  {len(regls_max)} réglementations chargées")

# ── 3. ReglementationPeriode : sCode → [noPeriode, ...] ────────────────────────
print("Chargement ReglementationPeriode...")
regl_to_periods = defaultdict(list)
for row in load_csv('ReglementationPeriode.csv'):
    regl_to_periods[row['sCode'].strip()].append(row['noPeriode'].strip())

print(f"  {len(regl_to_periods)} codes réglementation liés à des périodes")

# ── 4. EmplacementReglementation : sNoEmplacement → [codes] ────────────────────
print("Chargement EmplacementReglementation...")
place_to_regls = defaultdict(list)
for row in load_csv('EmplacementReglementation.csv'):
    place_to_regls[row['sNoEmplacement'].strip()].append(row['sCodeAutocollant'].strip())

print(f"  {len(place_to_regls)} emplacements avec réglementations")

# ── 5. Places : buildout complet ───────────────────────────────────────────────
print("Chargement Places et construction de l'asset...")
output     = []
skipped_inactive = 0
skipped_no_coord = 0
skipped_no_period = 0
seen_coords  = {}  # dédupliquer les spots co-localisés (A024/A025 même borne)

for row in load_csv('Places.csv'):
    # Seulement les spots actifs (sStatut = '1')
    if row.get('sStatut', '').strip() != '1':
        skipped_inactive += 1
        continue

    place_id = row['sNoPlace'].strip()

    try:
        lon = round(float(row['nLongitude']), 6)
        lat = round(float(row['nLatitude']), 6)
    except (ValueError, KeyError):
        skipped_no_coord += 1
        continue

    # Tarif horaire en cents (425 = $4.25/h). 0 si non renseigné.
    try:
        rate_cents = int(float(row.get('nTarifHoraire', '0').strip() or '0'))
    except ValueError:
        rate_cents = 0

    # ── Construire les plages horaires ──────────────────────────────────────
    periods    = []
    seen_pids  = set()

    for regl_code in place_to_regls.get(place_id, []):
        max_mins = regls_max.get(regl_code, 120)

        for period_id in regl_to_periods.get(regl_code, []):
            if period_id in seen_pids:
                continue
            seen_pids.add(period_id)

            p = periodes.get(period_id)
            if p and p['d']:
                periods.append({
                    'd': p['d'],
                    'f': p['f'],
                    't': p['t'],
                    'm': max_mins,
                })

    if not periods:
        skipped_no_period += 1
        continue

    # Dédupliquer les spots co-localisés (même borne → même coordonnées)
    coord_key = (lon, lat)
    if coord_key in seen_coords:
        # Fusionner les plages si le tarif est différent (rare)
        existing = seen_coords[coord_key]
        for p in periods:
            if p not in output[existing]['p']:
                output[existing]['p'].append(p)
        continue

    seen_coords[coord_key] = len(output)
    output.append({
        'n': place_id,
        'x': lon,
        'y': lat,
        'c': rate_cents,
        'p': periods,
    })

# ── 6. Écriture ────────────────────────────────────────────────────────────────
os.makedirs(ASSET_DIR, exist_ok=True)
with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
    json.dump(output, f, separators=(',', ':'), ensure_ascii=False)

size_kb = os.path.getsize(OUTPUT_FILE) / 1024
size_mb = size_kb / 1024

print()
print("=" * 55)
print(f"  Spots actifs exportes    : {len(output):>7,}")
print(f"  Spots inactifs ignores   : {skipped_inactive:>7,}")
print(f"  Spots sans coordonnees   : {skipped_no_coord:>7,}")
print(f"  Spots sans plages        : {skipped_no_period:>7,}")
print(f"  Taille fichier JSON      : {size_kb:>7.1f} KB  ({size_mb:.2f} MB)")
print(f"  Fichier : {OUTPUT_FILE}")
print("=" * 55)

# ── Aperçu : premiers spots ────────────────────────────────────────────────────
print("\nAperçu (3 premiers spots) :")
for spot in output[:3]:
    print(f"  [{spot['n']}] ({spot['x']}, {spot['y']}) {spot['c']}¢/h")
    for p in spot['p'][:2]:
        jours = ['Lun','Mar','Mer','Jeu','Ven','Sam','Dim']
        dstr = '+'.join(jours[d-1] for d in p['d'])
        print(f"    {dstr}  {p['f']}-{p['t']}  max {p['m']}min")

# Stats horaires
print("\nDistribution des heures de fermeture (top 10) :")
from collections import Counter
end_times = Counter()
for spot in output:
    for p in spot['p']:
        end_times[p['t']] += 1
for t, n in end_times.most_common(10):
    print(f"  {t}  -> {n:,} plages")
