"""
validate_amd.py
===============
Simule AmdService.rulesNear() directement sur amd_montreal.json.
Prend une liste d'adresses (lon, lat) connues et affiche les règles trouvées.
Permet de valider que notre JSON + algo de proximité retournent les bonnes données.
"""

import json
import math
import os

ASSET = os.path.join(os.path.dirname(__file__), '..', 'assets', 'amd_montreal.json')

# ── Reproduit exactement AmdService ─────────────────────────────────────────
THRESH2 = 2.5e-7   # ~56 m rayon
CELL    = 0.001    # taille cellule grille

def cell_key(lat, lon):
    return f"{int(lat / CELL)},{int(lon / CELL)}"

def build_grid(spots):
    grid = {}
    for idx, s in enumerate(spots):
        key = cell_key(s['y'], s['x'])
        grid.setdefault(key, []).append(idx)
    return grid

def rules_near(spots, grid, lon, lat):
    gi = int(lat / CELL)
    gj = int(lon / CELL)
    best = None
    best_d2 = float('inf')
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            key = f"{gi+di},{gj+dj}"
            for idx in grid.get(key, []):
                s = spots[idx]
                dl = s['y'] - lat
                dx = s['x'] - lon
                d2 = dl*dl + dx*dx
                if d2 < best_d2:
                    best_d2 = d2
                    best = s
    if best is None or best_d2 > THRESH2:
        return None, None
    dist_m = math.sqrt(best_d2) * 111_320  # approx degrés → mètres
    return best, dist_m

# ── Adresses test (lon, lat, description) ───────────────────────────────────
TESTS = [
    (-73.5687,  45.4989, "Rue Peel & Ste-Catherine (Ville-Marie)"),
    (-73.5731,  45.5009, "Rue Crescent & René-Lévesque (Ville-Marie)"),
    (-73.5756,  45.5082, "Rue Sherbrooke O. & Mackay (McGill)"),
    (-73.5580,  45.5243, "Rue Saint-Denis & Mont-Royal (Plateau)"),
    (-73.5791,  45.5225, "Boul. Saint-Laurent & Laurier (Mile-End)"),
    (-73.6025,  45.5341, "Ave du Parc & Fairmount (Mile-End/Outremont)"),
    (-73.5998,  45.5398, "Rue Jean-Talon O. & Querbes (Rosemont)"),
    (-73.5541,  45.5328, "Rue Beaubien E. & Fabre (Rosemont)"),
    (-73.6310,  45.4935, "Rue Queen-Mary & Côte-des-Neiges (CDN)"),
    (-73.5648,  45.5052, "Rue Ontario E. & Amherst (Centre-Sud)"),
]

JOURS = ['', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim']

def fmt_rule(p):
    jours = '+'.join(JOURS[d] for d in p['d'])
    rate  = f"  ${p['c']/100:.2f}/h" if p.get('c', 0) else ''
    return f"    {jours}  {p['f']}-{p['t']}  max {p.get('m','?')}min{rate}"

# ── Main ─────────────────────────────────────────────────────────────────────
print("Chargement AMD JSON...")
with open(ASSET, encoding='utf-8') as f:
    spots = json.load(f)
grid = build_grid(spots)
print(f"  {len(spots):,} spots charges\n")
print("=" * 65)

for lon, lat, desc in TESTS:
    spot, dist = rules_near(spots, grid, lon, lat)
    print(f"\n📍 {desc}")
    print(f"   coords: ({lon}, {lat})")
    if spot is None:
        print("   ❌ Aucun spot AMD dans rayon 56m")
        print("   → App utilisera zone_registry ou defaultRules")
    else:
        print(f"   ✅ Spot AMD trouvé : [{spot['n']}] à {dist:.1f}m")
        print(f"      coords spot : ({spot['x']}, {spot['y']})")
        tarif_cents = spot.get('c', 0)
        tarif_str = f"${tarif_cents/100:.2f}/h" if tarif_cents else "tarif non renseigné"
        print(f"      tarif       : {tarif_str}")
        print(f"      plages ({len(spot['p'])}) :")
        for p in spot['p']:
            # injecter le tarif du spot dans la règle pour affichage
            p_display = dict(p)
            p_display['c'] = tarif_cents
            print(fmt_rule(p_display))

print("\n" + "=" * 65)
