#!/usr/bin/env python3
"""
gen_nettoyage_segments.py
=========================
Génère assets/nettoyage_montreal.json à partir des données ouvertes
de la Ville de Montréal — Calendrier de nettoyage des rues.

Source : https://donnees.montreal.ca/dataset/nettoyage-rue
Format sortie : JSON compact utilisé par NettoyageService (Dart)

Usage
-----
    python3 scripts/gen_nettoyage_segments.py

Prérequis : pip install requests (ou urllib standard inclus)

Le fichier généré va dans assets/nettoyage_montreal.json.
Ajouter l'asset dans pubspec.yaml si pas encore présent :
    assets:
      - assets/nettoyage_montreal.json
"""

import json
import sys
import os
import io
import urllib.request
import urllib.parse

# ── stdout UTF-8 (Windows cp1252 safe) ──────────────────────────────────────
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

# ── Config ───────────────────────────────────────────────────────────────────

# API données ouvertes Montréal (CKAN / GeoJSON)
# Dataset UUID : calendrier de nettoyage des rues
GEOJSON_URL = (
    'https://donnees.montreal.ca/dataset/'
    '9a5d53a9-a685-44ed-80b9-3bb3c9ea5f9f/'
    'resource/d51b3e06-6e6c-4c3e-aa6e-d1a00bed625e/'
    'download/nettoyage-rue.geojson'
)

# Répertoire racine du projet Flutter (parent de scripts/)
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_PATH     = os.path.join(PROJECT_ROOT, 'assets', 'nettoyage_montreal.json')

# Mapping jours français → int (1=Lun … 7=Dim)
_JOUR_MAP = {
    'lundi': 1, 'lun': 1,
    'mardi': 2, 'mar': 2,
    'mercredi': 3, 'mer': 3,
    'jeudi': 4, 'jeu': 4,
    'vendredi': 5, 'ven': 5,
    'samedi': 6, 'sam': 6,
    'dimanche': 7, 'dim': 7,
}

# Mapping mois → int
_MOIS_MAP = {
    'janvier': 1, 'jan': 1,
    'fevrier': 2, 'fev': 2, 'février': 2,
    'mars': 3, 'mar': 3,
    'avril': 4, 'avr': 4,
    'mai': 5,
    'juin': 6,
    'juillet': 7, 'jul': 7,
    'aout': 8, 'aou': 8, 'août': 8,
    'septembre': 9, 'sep': 9,
    'octobre': 10, 'oct': 10,
    'novembre': 11, 'nov': 11,
    'decembre': 12, 'dec': 12, 'décembre': 12,
}

# ── Fonctions utilitaires ─────────────────────────────────────────────────────

def parse_time(t):
    """Normalise '7h', '07h30', '7:00' → 'HH:MM'."""
    if not t:
        return None
    t = str(t).strip().lower().replace('h', ':').replace(' ', '')
    if ':' not in t:
        t += ':00'
    parts = t.split(':')
    h = parts[0].zfill(2)
    m = (parts[1] if len(parts) > 1 else '00').ljust(2, '0')[:2]
    return f'{h}:{m}'

def parse_days(raw):
    """'lundi, mercredi' ou 'lundi au vendredi' → [1, 3] ou [1,2,3,4,5]."""
    if not raw:
        return list(range(1, 8))
    raw = str(raw).lower().strip()

    # 'x au y' → plage
    if ' au ' in raw:
        parts = raw.split(' au ')
        start = _JOUR_MAP.get(parts[0].strip())
        end   = _JOUR_MAP.get(parts[1].strip())
        if start and end:
            return list(range(start, end + 1))

    # liste séparée par virgule/point-virgule
    days = []
    for token in raw.replace(';', ',').split(','):
        token = token.strip()
        d = _JOUR_MAP.get(token)
        if d:
            days.append(d)
    return days if days else list(range(1, 8))

def parse_month(raw):
    """'avril' → 4, '04' → 4, None si invalide."""
    if not raw:
        return None
    raw = str(raw).strip().lower()
    if raw.isdigit():
        v = int(raw)
        return v if 1 <= v <= 12 else None
    return _MOIS_MAP.get(raw)

def parse_parity(raw):
    """'pair' → 0, 'impair' → 1, None sinon."""
    if not raw:
        return None
    raw = str(raw).lower().strip()
    if 'impair' in raw:
        return 1
    if 'pair' in raw:
        return 0
    return None

def coords_from_geometry(geom):
    """Extrait liste [[lon, lat], ...] depuis geometry GeoJSON."""
    gtype = geom.get('type', '')
    coords = geom.get('coordinates', [])
    if gtype == 'LineString':
        return [[round(c[0], 6), round(c[1], 6)] for c in coords]
    if gtype == 'MultiLineString':
        # Prendre la plus longue sous-ligne
        longest = max(coords, key=len)
        return [[round(c[0], 6), round(c[1], 6)] for c in longest]
    if gtype == 'Point':
        return [[round(coords[0], 6), round(coords[1], 6)]]
    return []

def midpoint(coords):
    """Point médian d'une polyline."""
    if not coords:
        return None
    mid = coords[len(coords) // 2]
    return mid

# ── Téléchargement ────────────────────────────────────────────────────────────

def download_geojson():
    print(f'Telechargement: {GEOJSON_URL}')
    req = urllib.request.Request(GEOJSON_URL, headers={'User-Agent': 'ParkSmart/1.0'})
    with urllib.request.urlopen(req, timeout=60) as r:
        raw = r.read().decode('utf-8')
    data = json.loads(raw)
    print(f'  {len(data["features"])} features')
    return data

# ── Traitement ────────────────────────────────────────────────────────────────

def process(geojson):
    features = geojson.get('features', [])
    segments = []
    seen_ways = set()
    skipped   = 0

    for feat in features:
        props = feat.get('properties') or {}
        geom  = feat.get('geometry')   or {}

        # ── Coordonnées ──────────────────────────────────────────────────
        coords = coords_from_geometry(geom)
        if len(coords) < 1:
            skipped += 1
            continue

        # ── Champs clés (les noms varient selon version du dataset) ──────
        # Essayer plusieurs variantes de noms de colonnes connues
        name = (
            props.get('rue_nom_complet') or
            props.get('rue_nom') or
            props.get('NUE_NOM_COMPLET') or
            props.get('rue') or
            'Rue inconnue'
        )

        # way_id synthétique (hash sur nom + midpoint) — les données MTL
        # nettoyage n'incluent pas d'OSM ID
        mid = midpoint(coords)
        way_id = abs(hash(f'{name}_{mid}')) % (10**9)

        # Éviter doublons stricts
        if way_id in seen_ways:
            continue
        seen_ways.add(way_id)

        # ── Arrondissement / zone ────────────────────────────────────────
        zone = (
            props.get('arrondissement') or
            props.get('arrond') or
            props.get('ARRONDISSEMENT') or
            'Montréal'
        )

        # ── Côté ─────────────────────────────────────────────────────────
        side_raw = (
            props.get('cote') or
            props.get('COTE') or
            props.get('cote_rue') or
            ''
        )
        parity = parse_parity(side_raw)
        side_label = (
            'Côté pair'   if parity == 0 else
            'Côté impair' if parity == 1 else
            'Les deux côtés'
        )

        # ── Horaire ──────────────────────────────────────────────────────
        from_time = parse_time(
            props.get('hre_debut') or props.get('hor_deb') or
            props.get('heure_debut') or props.get('HRE_DEBUT') or '07:00'
        )
        to_time = parse_time(
            props.get('hre_fin') or props.get('hor_fin') or
            props.get('heure_fin') or props.get('HRE_FIN') or '12:00'
        )
        if not from_time:
            from_time = '07:00'
        if not to_time:
            to_time = '12:00'

        # ── Jours ─────────────────────────────────────────────────────────
        days_raw = (
            props.get('jrs_sem') or props.get('jour') or
            props.get('JOUR') or props.get('jours') or ''
        )
        days = parse_days(days_raw)
        if not days:
            days = [1, 2, 3, 4, 5, 6, 7]

        # ── Période (mois) ────────────────────────────────────────────────
        month_from = parse_month(
            props.get('per_deb') or props.get('mois_debut') or
            props.get('MOIS_DEBUT') or props.get('periode_debut')
        )
        month_to = parse_month(
            props.get('per_fin') or props.get('mois_fin') or
            props.get('MOIS_FIN') or props.get('periode_fin')
        )

        # ── Règle ─────────────────────────────────────────────────────────
        rule = {'d': days, 'f': from_time, 't': to_time}
        if month_from:
            rule['mf'] = month_from
        if month_to:
            rule['mt'] = month_to
        if parity is not None:
            rule['dp'] = parity

        segment = {
            'n': name,
            'w': way_id,
            'z': zone,
            's': side_label,
            'c': coords,
            'r': [rule],
        }
        segments.append(segment)

    print(f'  Segments valides : {len(segments)} | Ignores : {skipped}')
    return segments

# ── Fallback : données de démonstration ───────────────────────────────────────
# Utilisées si le téléchargement échoue — quelques rues représentatives

DEMO_SEGMENTS = [
    # Plateau — rue Marquette côté impair : Lun 7h-12h, avr-mai
    {'n': 'Rue Marquette', 'w': 100000001, 'z': 'Plateau-Mont-Royal',
     's': 'Côté impair',
     'c': [[-73.5768, 45.5285], [-73.5768, 45.5260]],
     'r': [{'d': [1], 'f': '07:00', 't': '12:00', 'mf': 4, 'mt': 5, 'dp': 1}]},
    # Plateau — rue Marquette côté pair : Mar 7h-12h, avr-mai
    {'n': 'Rue Marquette', 'w': 100000002, 'z': 'Plateau-Mont-Royal',
     's': 'Côté pair',
     'c': [[-73.5770, 45.5285], [-73.5770, 45.5260]],
     'r': [{'d': [2], 'f': '07:00', 't': '12:00', 'mf': 4, 'mt': 5, 'dp': 0}]},
    # Rosemont — rue Masson côté impair : Mer 7h-12h, avr-mai
    {'n': 'Rue Masson', 'w': 100000003, 'z': 'Rosemont-Petite-Patrie',
     's': 'Côté impair',
     'c': [[-73.5710, 45.5435], [-73.5620, 45.5435]],
     'r': [{'d': [3], 'f': '07:00', 't': '12:00', 'mf': 4, 'mt': 5, 'dp': 1}]},
    # Mile-End — avenue Laurier côté pair : Jeu 7h-12h, avr-mai
    {'n': 'Avenue Laurier Ouest', 'w': 100000004, 'z': 'Mile-End',
     's': 'Côté pair',
     'c': [[-73.5980, 45.5285], [-73.5880, 45.5285]],
     'r': [{'d': [4], 'f': '07:00', 't': '12:00', 'mf': 4, 'mt': 5, 'dp': 0}]},
    # Villeray — rue Jarry côté impair : Ven 7h-12h, avr-mai
    {'n': 'Rue Jarry Est', 'w': 100000005, 'z': 'Villeray',
     's': 'Côté impair',
     'c': [[-73.5820, 45.5498], [-73.5720, 45.5498]],
     'r': [{'d': [5], 'f': '07:00', 't': '12:00', 'mf': 4, 'mt': 5, 'dp': 1}]},
]

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    os.makedirs(os.path.join(PROJECT_ROOT, 'assets'), exist_ok=True)

    segments = []
    try:
        geojson  = download_geojson()
        segments = process(geojson)
    except Exception as exc:
        print(f'Erreur telechargement : {exc}')
        print('Utilisation des donnees de demonstration (5 segments)...')
        segments = DEMO_SEGMENTS

    if not segments:
        print('Aucun segment — utilisation demo')
        segments = DEMO_SEGMENTS

    with open(OUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(segments, f, ensure_ascii=False, separators=(',', ':'))

    size_kb = os.path.getsize(OUT_PATH) / 1024
    print(f'Ecrit : {OUT_PATH}')
    print(f'  {len(segments)} segments · {size_kb:.1f} KB')

if __name__ == '__main__':
    main()
