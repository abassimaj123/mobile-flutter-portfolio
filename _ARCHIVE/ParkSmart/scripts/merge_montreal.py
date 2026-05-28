"""
merge_montreal.py — Phase 0 migration
Fusionne les 3 assets Montréal dans le format universel assets/data/{cityId}.json

Usage (depuis la racine du projet) :
    python scripts/merge_montreal.py
"""
import json
import os

BASE = 'assets'
OUT  = os.path.join('assets', 'data')
os.makedirs(OUT, exist_ok=True)

amd  = json.load(open(os.path.join(BASE, 'amd_montreal.json'),         encoding='utf-8'))
alt  = json.load(open(os.path.join(BASE, 'alternating_montreal.json'), encoding='utf-8'))
nett = json.load(open(os.path.join(BASE, 'nettoyage_montreal.json'),   encoding='utf-8'))

result = {
    "v":           1,
    "meters":      amd,
    "alternating": alt,
    "cleaning":    nett,
}

out_path = os.path.join(OUT, 'montreal.json')
with open(out_path, 'w', encoding='utf-8') as f:
    json.dump(result, f, ensure_ascii=False, separators=(',', ':'))

size = os.path.getsize(out_path)
print(f"OK {out_path}: {size:,} bytes")
print(f"   meters:      {len(amd):,}  spots")
print(f"   alternating: {len(alt):,}  segments")
print(f"   cleaning:    {len(nett):,} segments")
