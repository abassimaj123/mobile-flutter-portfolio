#!/usr/bin/env python3
"""
build_montreal_complete.py
===========================
Complete Montreal data pipeline: downloads SRRR (resident permit zones) + street cleaning
schedule from Montreal open data, converts to universal format, and merges with existing
montreal.json if present.

Sources:
  - SRRR: "Secteurs de stationnement réservé aux résidents" (permit parking zones)
  - Cleaning: "Calendrier de nettoyage des rues" (street cleaning schedule)

Output: assets/data/montreal.json (with deduplication by geometry midpoint)

Usage
-----
    python3 scripts/build_montreal_complete.py

Dependencies: requests library (or urllib standard library)
"""

import json
import sys
import os
import io
import hashlib
from typing import Dict, List, Tuple, Any
from urllib.parse import urlencode

# ──────────────────────────────────────────────────────────────────────────────
# UTF-8 stdout (Windows cp1252 safe)
# ──────────────────────────────────────────────────────────────────────────────
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

# Try requests first, fall back to urllib
try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False
    import urllib.request
    import urllib.error

# ──────────────────────────────────────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────────────────────────────────────

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(PROJECT_ROOT, 'assets', 'data')
OUT_PATH = os.path.join(OUT_DIR, 'montreal.json')
EXISTING_PATH = OUT_PATH

os.makedirs(OUT_DIR, exist_ok=True)

# Montreal open data API (CKAN)
CKAN_API_BASE = 'https://donnees.montreal.ca/api/3/action'

# Dataset IDs and resource IDs (from donnees.montreal.ca)
# These are the actual CKAN dataset/resource UUIDs
SRRR_DATASET_SEARCH = 'Secteurs de stationnement réservé'  # Search term
CLEANING_DATASET_SEARCH = 'nettoyage-rue'  # Dataset ID or search term

# Known direct GeoJSON URLs (if available)
CLEANING_GEOJSON_URL = (
    'https://donnees.montreal.ca/dataset/'
    '9a5d53a9-a685-44ed-80b9-3bb3c9ea5f9f/'
    'resource/d51b3e06-6e6c-4c3e-aa6e-d1a00bed625e/'
    'download/nettoyage-rue.geojson'
)

# Day mapping (French → 1-7)
_JOUR_MAP = {
    'lundi': 1, 'lun': 1,
    'mardi': 2, 'mar': 2,
    'mercredi': 3, 'mer': 3,
    'jeudi': 4, 'jeu': 4,
    'vendredi': 5, 'ven': 5,
    'samedi': 6, 'sam': 6,
    'dimanche': 7, 'dim': 7,
}

# Month mapping (French → 1-12)
_MOIS_MAP = {
    'janvier': 1, 'jan': 1,
    'fevrier': 2, 'fev': 2, 'février': 2,
    'mars': 3,
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

# ──────────────────────────────────────────────────────────────────────────────
# HTTP Utilities
# ──────────────────────────────────────────────────────────────────────────────

def http_get(url: str, timeout: int = 60) -> str:
    """Download URL content as UTF-8 string."""
    try:
        if HAS_REQUESTS:
            resp = requests.get(url, timeout=timeout, headers={'User-Agent': 'ParkSmart/1.0'})
            resp.raise_for_status()
            return resp.text
        else:
            req = urllib.request.Request(url, headers={'User-Agent': 'ParkSmart/1.0'})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read().decode('utf-8')
    except Exception as e:
        print(f"  ERROR downloading {url}: {e}")
        return None

# ──────────────────────────────────────────────────────────────────────────────
# Parsing Utilities
# ──────────────────────────────────────────────────────────────────────────────

def parse_time(t: str) -> str:
    """Normalizes '7h', '07h30', '7:00' → 'HH:MM'."""
    if not t:
        return None
    t = str(t).strip().lower().replace('h', ':').replace(' ', '')
    if ':' not in t:
        t += ':00'
    parts = t.split(':')
    h = parts[0].zfill(2)
    m = (parts[1] if len(parts) > 1 else '00').ljust(2, '0')[:2]
    try:
        h_int = int(h)
        m_int = int(m)
        if 0 <= h_int <= 23 and 0 <= m_int <= 59:
            return f'{h}:{m}'
    except:
        pass
    return None

def parse_days(raw: str) -> List[int]:
    """'lundi, mercredi' or 'lundi au vendredi' → [1, 3] or [1,2,3,4,5]."""
    if not raw:
        return list(range(1, 8))
    raw = str(raw).lower().strip()

    # 'x au y' → range
    if ' au ' in raw:
        parts = raw.split(' au ')
        start = _JOUR_MAP.get(parts[0].strip())
        end = _JOUR_MAP.get(parts[1].strip())
        if start and end:
            return list(range(start, end + 1))

    # CSV list
    days = []
    for token in raw.replace(';', ',').split(','):
        token = token.strip()
        d = _JOUR_MAP.get(token)
        if d:
            days.append(d)
    return days if days else list(range(1, 8))

def parse_month(raw: str) -> int:
    """'avril' → 4, '04' → 4, None if invalid."""
    if not raw:
        return None
    raw = str(raw).strip().lower()
    if raw.isdigit():
        v = int(raw)
        return v if 1 <= v <= 12 else None
    return _MOIS_MAP.get(raw)

def parse_parity(raw: str) -> int:
    """'pair' → 0, 'impair' → 1, None otherwise."""
    if not raw:
        return None
    raw = str(raw).lower().strip()
    if 'impair' in raw:
        return 1
    if 'pair' in raw:
        return 0
    return None

def coords_from_geometry(geom: Dict) -> List[List[float]]:
    """Extract [[lon, lat], ...] from GeoJSON geometry."""
    if not geom:
        return []
    gtype = geom.get('type', '')
    coords = geom.get('coordinates', [])

    if gtype == 'LineString':
        return [[round(c[0], 6), round(c[1], 6)] for c in coords]
    elif gtype == 'MultiLineString':
        # Take longest sub-line
        if coords:
            longest = max(coords, key=len) if coords else []
            return [[round(c[0], 6), round(c[1], 6)] for c in longest]
    elif gtype == 'Point':
        return [[round(coords[0], 6), round(coords[1], 6)]]
    elif gtype == 'Polygon':
        # Exterior ring only
        if coords and coords[0]:
            return [[round(c[0], 6), round(c[1], 6)] for c in coords[0]]
    return []

def midpoint(coords: List[List[float]]) -> List[float]:
    """Median point of a polyline."""
    if not coords or len(coords) == 0:
        return None
    return coords[len(coords) // 2]

def geom_hash(coords: List[List[float]]) -> str:
    """Hash geometry by median point for deduplication."""
    mid = midpoint(coords)
    if not mid:
        return None
    # Round to 4 decimal places (≈ 10m precision)
    key = f'{mid[0]:.4f},{mid[1]:.4f}'
    return hashlib.md5(key.encode()).hexdigest()[:12]

# ──────────────────────────────────────────────────────────────────────────────
# SRRR (Permit Parking Zones)
# ──────────────────────────────────────────────────────────────────────────────

def download_srrr() -> Tuple[List[Dict], int]:
    """
    Download SRRR (Secteurs de stationnement réservé aux résidents).

    Searches CKAN API for permit parking datasets. If found, parses GeoJSON.
    Returns list of zone segments and total zone count.
    """
    print('\n[SRRR] Searching Montreal open data...')

    # Try to find SRRR dataset via CKAN search
    search_url = f'{CKAN_API_BASE}/package_search'
    params = {'q': SRRR_DATASET_SEARCH, 'rows': 10}
    try:
        if HAS_REQUESTS:
            url = f'{search_url}?{urlencode(params)}'
        else:
            url = f'{search_url}?{urlencode(params)}'

        raw = http_get(url)
        if not raw:
            print('  WARNING: Could not search CKAN API, using fallback SRRR data')
            return generate_srrr_fallback(), 0

        data = json.loads(raw)
        results = data.get('result', {}).get('results', [])

        if not results:
            print('  WARNING: No SRRR dataset found in CKAN, using fallback')
            return generate_srrr_fallback(), 0

        # Try to find GeoJSON resource in first result
        pkg = results[0]
        resources = pkg.get('resources', [])
        geojson_url = None

        for res in resources:
            url_res = res.get('url', '')
            fmt = res.get('format', '').lower()
            if 'geojson' in fmt or url_res.endswith('.geojson'):
                geojson_url = url_res
                break

        if not geojson_url:
            print('  WARNING: No GeoJSON found in SRRR dataset, using fallback')
            return generate_srrr_fallback(), 0

        print(f'  Found: {pkg.get("title", "Unknown")}')
        print(f'  Downloading: {geojson_url}')

        raw_geojson = http_get(geojson_url)
        if not raw_geojson:
            print('  ERROR: Could not download SRRR GeoJSON')
            return generate_srrr_fallback(), 0

        geojson = json.loads(raw_geojson)
        return process_srrr_geojson(geojson)

    except Exception as e:
        print(f'  ERROR: {e}')
        print('  Using fallback SRRR data')
        return generate_srrr_fallback(), 0

def process_srrr_geojson(geojson: Dict) -> Tuple[List[Dict], int]:
    """Convert SRRR GeoJSON to segment format."""
    features = geojson.get('features', [])
    segments = []
    zone_count = 0
    skipped = 0
    seen_geoms = set()

    for feat in features:
        props = feat.get('properties') or {}
        geom = feat.get('geometry') or {}

        coords = coords_from_geometry(geom)
        if len(coords) < 1:
            skipped += 1
            continue

        # Deduplicate by geometry hash
        ghash = geom_hash(coords)
        if ghash in seen_geoms:
            continue
        seen_geoms.add(ghash)

        # Extract fields (field names vary)
        zone_id = (
            props.get('zone_id') or
            props.get('id_secteur') or
            props.get('ZONE_ID') or
            str(zone_count + 1)
        )

        zone_name = (
            props.get('zone_name') or
            props.get('nom_secteur') or
            props.get('name') or
            props.get('NOM_SECTEUR') or
            f'Zone {zone_id}'
        )

        permit_type = (
            props.get('permit_type') or
            props.get('type_permis') or
            props.get('TYPE_PERMIS') or
            'Residential'
        )

        restriction = (
            props.get('restriction') or
            props.get('restriction_desc') or
            props.get('RESTRICTION') or
            ''
        )

        # Build segment
        segment = {
            'n': f'{zone_name}',  # name
            'z': permit_type,      # zone/type
            'c': coords,           # coordinates
        }

        if restriction:
            segment['d'] = restriction  # description/restriction

        segments.append(segment)
        zone_count += 1

    print(f'  Segments: {len(segments)} | Skipped: {skipped}')
    return segments, zone_count

def generate_srrr_fallback() -> List[Dict]:
    """Fallback SRRR data (demo zones)."""
    return [
        {
            'n': 'Zone de Plateau-Mont-Royal',
            'z': 'Residential',
            'c': [[-73.5750, 45.5270], [-73.5750, 45.5300]],
            'd': 'Permis résident requis lun-ven 09h-20h'
        },
        {
            'n': 'Zone de Rosemont',
            'z': 'Residential',
            'c': [[-73.5650, 45.5350], [-73.5650, 45.5380]],
            'd': 'Permis résident requis lun-ven 09h-20h'
        },
        {
            'n': 'Zone du Quartier Latin',
            'z': 'Residential',
            'c': [[-73.5600, 45.5050], [-73.5600, 45.5080]],
            'd': 'Permis résident requis lun-ven 09h-20h'
        },
    ]

# ──────────────────────────────────────────────────────────────────────────────
# Street Cleaning Schedule
# ──────────────────────────────────────────────────────────────────────────────

def download_cleaning() -> Tuple[List[Dict], int]:
    """
    Download street cleaning schedule (Calendrier de nettoyage des rues).

    Returns list of segment dicts with cleaning rules.
    """
    print('\n[CLEANING] Downloading street cleaning schedule...')
    print(f'  URL: {CLEANING_GEOJSON_URL}')

    raw = http_get(CLEANING_GEOJSON_URL, timeout=120)
    if not raw:
        print('  ERROR: Could not download, using fallback data')
        return generate_cleaning_fallback(), 0

    try:
        geojson = json.loads(raw)
        return process_cleaning_geojson(geojson)
    except Exception as e:
        print(f'  ERROR: {e}')
        print('  Using fallback data')
        return generate_cleaning_fallback(), 0

def process_cleaning_geojson(geojson: Dict) -> Tuple[List[Dict], int]:
    """Convert cleaning GeoJSON to segment format."""
    features = geojson.get('features', [])
    segments = []
    skipped = 0
    seen_geoms = set()

    for feat in features:
        props = feat.get('properties') or {}
        geom = feat.get('geometry') or {}

        coords = coords_from_geometry(geom)
        if len(coords) < 1:
            skipped += 1
            continue

        # Deduplicate by geometry hash
        ghash = geom_hash(coords)
        if ghash in seen_geoms:
            continue
        seen_geoms.add(ghash)

        # Parse street info
        name = (
            props.get('rue_nom_complet') or
            props.get('rue_nom') or
            props.get('NUE_NOM_COMPLET') or
            props.get('rue') or
            'Rue inconnue'
        )

        zone = (
            props.get('arrondissement') or
            props.get('arrond') or
            props.get('ARRONDISSEMENT') or
            'Montréal'
        )

        # Parse schedule
        from_time = parse_time(
            props.get('hre_debut') or props.get('hor_deb') or
            props.get('heure_debut') or props.get('HRE_DEBUT') or '07:00'
        ) or '07:00'

        to_time = parse_time(
            props.get('hre_fin') or props.get('hor_fin') or
            props.get('heure_fin') or props.get('HRE_FIN') or '12:00'
        ) or '12:00'

        days_raw = (
            props.get('jrs_sem') or props.get('jour') or
            props.get('JOUR') or props.get('jours') or ''
        )
        days = parse_days(days_raw)

        side_raw = (
            props.get('cote') or props.get('COTE') or
            props.get('cote_rue') or ''
        )
        parity = parse_parity(side_raw)

        month_from = parse_month(
            props.get('per_deb') or props.get('mois_debut') or
            props.get('MOIS_DEBUT') or props.get('periode_debut')
        )
        month_to = parse_month(
            props.get('per_fin') or props.get('mois_fin') or
            props.get('MOIS_FIN') or props.get('periode_fin')
        )

        # Build rule
        rule = {'d': days, 'f': from_time, 't': to_time}
        if month_from:
            rule['mf'] = month_from
        if month_to:
            rule['mt'] = month_to
        if parity is not None:
            rule['dp'] = parity

        side_label = (
            'Côté pair' if parity == 0 else
            'Côté impair' if parity == 1 else
            'Les deux côtés'
        )

        segment = {
            'n': name,
            'z': zone,
            's': side_label,
            'c': coords,
            'r': [rule],
        }
        segments.append(segment)

    print(f'  Segments: {len(segments)} | Skipped: {skipped}')
    return segments, len(segments)

def generate_cleaning_fallback() -> List[Dict]:
    """Fallback cleaning data (demo streets)."""
    return [
        {
            'n': 'Rue Marquette',
            'z': 'Plateau-Mont-Royal',
            's': 'Côté impair',
            'c': [[-73.5768, 45.5285], [-73.5768, 45.5260]],
            'r': [{'d': [1], 'f': '07:00', 't': '12:00', 'mf': 4, 'mt': 5, 'dp': 1}]
        },
        {
            'n': 'Rue Marquette',
            'z': 'Plateau-Mont-Royal',
            's': 'Côté pair',
            'c': [[-73.5770, 45.5285], [-73.5770, 45.5260]],
            'r': [{'d': [2], 'f': '07:00', 't': '12:00', 'mf': 4, 'mt': 5, 'dp': 0}]
        },
        {
            'n': 'Rue Masson',
            'z': 'Rosemont-Petite-Patrie',
            's': 'Côté impair',
            'c': [[-73.5710, 45.5435], [-73.5620, 45.5435]],
            'r': [{'d': [3], 'f': '07:00', 't': '12:00', 'mf': 4, 'mt': 5, 'dp': 1}]
        },
    ]

# ──────────────────────────────────────────────────────────────────────────────
# Merge & Deduplicate
# ──────────────────────────────────────────────────────────────────────────────

def merge_with_existing(srrr_segs: List[Dict], cleaning_segs: List[Dict]) -> Dict:
    """
    Merge new data with existing montreal.json if present.
    Deduplicate by geometry hash.
    """
    result = {
        'v': 1,
        'meters': [],
        'alternating': [],
        'cleaning': cleaning_segs,
    }

    # Load existing data if present
    if os.path.exists(EXISTING_PATH):
        try:
            with open(EXISTING_PATH, 'r', encoding='utf-8') as f:
                existing = json.load(f)

            # Preserve existing meters and alternating
            result['meters'] = existing.get('meters', [])
            result['alternating'] = existing.get('alternating', [])

            # Merge cleaning with deduplication
            existing_cleaning = existing.get('cleaning', [])
            seen_geoms = set()

            for seg in existing_cleaning:
                coords = seg.get('c', [])
                ghash = geom_hash(coords)
                if ghash and ghash not in seen_geoms:
                    seen_geoms.add(ghash)

            # Add new cleaning segments
            for seg in cleaning_segs:
                coords = seg.get('c', [])
                ghash = geom_hash(coords)
                if not ghash or ghash not in seen_geoms:
                    result['cleaning'].append(seg)
                    if ghash:
                        seen_geoms.add(ghash)

            print(f'\n[MERGE] Merged with existing montreal.json')
            print(f'  Existing cleaning segments: {len(existing_cleaning)}')
            print(f'  New cleaning segments: {len(cleaning_segs)}')
            print(f'  Deduplicated total: {len(result["cleaning"])}')

        except Exception as e:
            print(f'\n[MERGE] ERROR reading existing file: {e}')
            print(f'  Using new data only')
            result['cleaning'] = cleaning_segs
    else:
        print(f'\n[MERGE] No existing montreal.json found, creating new')
        result['cleaning'] = cleaning_segs

    return result

# ──────────────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────────────

def main():
    print('=' * 80)
    print('Montreal Data Pipeline — SRRR + Street Cleaning')
    print('=' * 80)

    # Download SRRR
    srrr_segs, srrr_count = download_srrr()
    print(f'\n[SRRR] Total zones: {srrr_count}')

    # Download cleaning
    cleaning_segs, cleaning_count = download_cleaning()
    print(f'[CLEANING] Total streets: {cleaning_count}')

    # Merge with existing
    merged = merge_with_existing(srrr_segs, cleaning_segs)

    # Write output
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(merged, f, ensure_ascii=False, separators=(',', ':'))

    size = os.path.getsize(OUT_PATH)

    print('\n' + '=' * 80)
    print(f'[MTL] SRRR: {srrr_count} zones')
    print(f'[MTL] Street cleaning: {len(cleaning_segs)} segments')
    print(f'[MTL] Total: {len(merged["meters"])} meters + {len(merged["alternating"])} alternating + {len(merged["cleaning"])} cleaning')
    print(f'\n✓ Output: {OUT_PATH}')
    print(f'  Size: {size:,} bytes')
    print('=' * 80)

if __name__ == '__main__':
    main()
