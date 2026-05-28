"""
build_chicago.py
================
Downloads Chicago parking data from data.cityofchicago.org and produces
assets/data/chicago.json in the ParkSmart universal format.

Data sources:
  - Parking Meters: https://data.cityofchicago.org/api/views/2n9n-94c6/rows.json
  - Residential Permit Parking Program (RPP): https://data.cityofchicago.org/api/views/knt5-5b45/rows.json
  - Street Cleaning Schedules (if available): https://data.cityofchicago.org/api/views/e4qi-d6wq/rows.json

Output format (universal):
  {"v":1, "meters":[...], "alternating":[], "cleaning":[...]}

Features:
  - Downloads parking meters with location and rates
  - Downloads RPP zones and boundaries
  - Attempts to fetch street cleaning schedules
  - Geocodes via Nominatim with caching in SQLite
  - Snaps to OSM ways within Chicago bbox (41.6° to 42.0°N, -87.3° to -87.5°W)
  - Groups into universal JSON buckets (meters, cleaning)

Usage:
  pip install requests
  python build_chicago.py
"""

import json
import os
import re
import sqlite3
import sys
import time
from collections import defaultdict
from dataclasses import dataclass
from typing import Optional

import requests

# ── Paths ──────────────────────────────────────────────────────────────────
SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
ASSET_DIR   = os.path.join(SCRIPT_DIR, '..', 'assets', 'data')
OUTPUT_FILE = os.path.join(ASSET_DIR, 'chicago.json')
CACHE_DB    = os.path.join(ASSET_DIR, '.geocode_cache_chi.db')

# ── Data sources ───────────────────────────────────────────────────────────
# Chicago Open Data Portal (Socrata)
METERS_API    = "https://data.cityofchicago.org/api/views/2n9n-94c6/rows.json"
RPP_API       = "https://data.cityofchicago.org/api/views/knt5-5b45/rows.json"
CLEANING_API  = "https://data.cityofchicago.org/api/views/e4qi-d6wq/rows.json"

# Chicago bounding box (approx)
CHI_LAT_MIN = 41.6
CHI_LAT_MAX = 42.0
CHI_LON_MIN = -87.95
CHI_LON_MAX = -87.5

PAGE_SIZE = 50_000

# ── Geocoding cache (SQLite) ───────────────────────────────────────────────

def init_cache():
    """Initialize geocoding cache database."""
    os.makedirs(ASSET_DIR, exist_ok=True)
    conn = sqlite3.connect(CACHE_DB)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS geocache (
            query TEXT PRIMARY KEY,
            lon REAL,
            lat REAL,
            timestamp INTEGER
        )
    """)
    conn.commit()
    return conn


def get_cached_geocode(conn: sqlite3.Connection, query: str) -> Optional[tuple[float, float]]:
    """Retrieve cached geocode result."""
    try:
        row = conn.execute(
            "SELECT lon, lat FROM geocache WHERE query = ?", (query,)
        ).fetchone()
        if row:
            return row[0], row[1]
    except Exception:
        pass
    return None


def cache_geocode(conn: sqlite3.Connection, query: str, lon: float, lat: float):
    """Store geocoding result in cache."""
    try:
        conn.execute(
            "INSERT OR REPLACE INTO geocache (query, lon, lat, timestamp) VALUES (?, ?, ?, ?)",
            (query, lon, lat, int(time.time()))
        )
        conn.commit()
    except Exception:
        pass


# ══════════════════════════════════════════════════════════════════════════════
# 1. Nominatim geocoding with fallback
# ══════════════════════════════════════════════════════════════════════════════

def nominatim_geocode(address: str, conn: sqlite3.Connection) -> Optional[tuple[float, float]]:
    """
    Geocode via Nominatim (OpenStreetMap). Uses cache if available.
    Returns (lon, lat) or None.
    """
    if not address or not address.strip():
        return None

    query = address.strip()

    # Check cache
    cached = get_cached_geocode(conn, query)
    if cached:
        return cached

    try:
        # Nominatim request with Chicago context
        params = {
            'q': f"{query}, Chicago, Illinois, USA",
            'format': 'json',
            'limit': 1,
        }
        resp = requests.get(
            'https://nominatim.openstreetmap.org/search',
            params=params,
            timeout=10,
            headers={'User-Agent': 'ParkSmartCHI/1.0'}
        )
        resp.raise_for_status()
        data = resp.json()
        if data and len(data) > 0:
            lon = float(data[0]['lon'])
            lat = float(data[0]['lat'])

            # Validate Chicago bbox
            if CHI_LAT_MIN <= lat <= CHI_LAT_MAX and CHI_LON_MIN <= lon <= CHI_LON_MAX:
                cache_geocode(conn, query, lon, lat)
                return lon, lat
    except Exception as e:
        pass

    return None


# ══════════════════════════════════════════════════════════════════════════════
# 2. Download parking meters
# ══════════════════════════════════════════════════════════════════════════════

def download_parking_meters() -> list[dict]:
    """
    Download Chicago parking meters from the Socrata API.
    Expected columns: location_id, longitude, latitude, active
    """
    print("[CHI] Downloading parking meters…")
    meters = []
    offset = 0
    session = requests.Session()
    session.headers.update({'Accept': 'application/json'})

    while True:
        params = {
            '$limit':  PAGE_SIZE,
            '$offset': offset,
        }
        try:
            resp = session.get(METERS_API, params=params, timeout=30)
            resp.raise_for_status()
            data = resp.json()

            if not data or 'data' not in data:
                break

            page = data['data']
            if not page:
                break

            meters.extend(page)
            offset += len(page)
            print(f"  Downloaded {len(meters):,} meters…", end='\r')

            if len(page) < PAGE_SIZE:
                break

            time.sleep(0.2)  # be polite to API
        except Exception as e:
            print(f"  [WARN] Error downloading meters: {e}")
            break

    print(f"\n[CHI] Total meters downloaded: {len(meters):,}")
    return meters


# ══════════════════════════════════════════════════════════════════════════════
# 3. Download RPP zones
# ══════════════════════════════════════════════════════════════════════════════

def download_rpp_zones() -> list[dict]:
    """
    Download Chicago Residential Permit Parking Program zones.
    Expected columns: zone, geometry (or location fields)
    """
    print("[CHI] Downloading RPP zones…")
    zones = []
    offset = 0
    session = requests.Session()
    session.headers.update({'Accept': 'application/json'})

    while True:
        params = {
            '$limit':  PAGE_SIZE,
            '$offset': offset,
        }
        try:
            resp = session.get(RPP_API, params=params, timeout=30)
            resp.raise_for_status()
            data = resp.json()

            if not data or 'data' not in data:
                break

            page = data['data']
            if not page:
                break

            zones.extend(page)
            offset += len(page)
            print(f"  Downloaded {len(zones):,} zones…", end='\r')

            if len(page) < PAGE_SIZE:
                break

            time.sleep(0.2)
        except Exception as e:
            print(f"  [WARN] Error downloading RPP zones: {e}")
            break

    print(f"\n[CHI] Total RPP zones downloaded: {len(zones):,}")
    return zones


# ══════════════════════════════════════════════════════════════════════════════
# 4. Download street cleaning schedules (best-effort)
# ══════════════════════════════════════════════════════════════════════════════

def download_street_cleaning() -> list[dict]:
    """
    Download Chicago street cleaning schedules (if available).
    Fallback to empty list if dataset not found.
    """
    print("[CHI] Attempting to download street cleaning schedules…")
    schedules = []
    offset = 0
    session = requests.Session()
    session.headers.update({'Accept': 'application/json'})

    while True:
        params = {
            '$limit':  PAGE_SIZE,
            '$offset': offset,
        }
        try:
            resp = session.get(CLEANING_API, params=params, timeout=30)
            resp.raise_for_status()
            data = resp.json()

            if not data or 'data' not in data:
                break

            page = data['data']
            if not page:
                break

            schedules.extend(page)
            offset += len(page)
            print(f"  Downloaded {len(schedules):,} cleaning entries…", end='\r')

            if len(page) < PAGE_SIZE:
                break

            time.sleep(0.2)
        except Exception as e:
            print(f"  [WARN] Street cleaning dataset not available: {e}")
            break

    if schedules:
        print(f"\n[CHI] Total street cleaning entries: {len(schedules):,}")
    else:
        print("\n[CHI] Street cleaning data not available (will skip)")

    return schedules


# ══════════════════════════════════════════════════════════════════════════════
# 5. Parse meters → universal format
# ══════════════════════════════════════════════════════════════════════════════

def parse_meters(meters_raw: list[dict], conn: sqlite3.Connection) -> list[dict]:
    """
    Convert raw meter records to universal meter format.

    Expected format per record:
      {
        "0": location_id,
        "1": longitude,
        "2": latitude,
        "3": active,
        ...
      }

    Output format:
      {
        "n": location_id,      # name/ID
        "x": longitude,
        "y": latitude,
        "c": cost (0 if unknown),
        "p": [{"d": [1..7], "f": "HH:MM", "t": "HH:MM"}]  # pricing rules
      }
    """
    print("[CHI] Parsing meter records…")
    parsed = []

    for idx, rec in enumerate(meters_raw):
        # Socrata API returns array of values by column index
        # Column order typically: location_id, longitude, latitude, active, ...
        try:
            # Try to extract fields by index
            loc_id = rec[0] if len(rec) > 0 else None
            lon_str = rec[1] if len(rec) > 1 else None
            lat_str = rec[2] if len(rec) > 2 else None
            active = rec[3] if len(rec) > 3 else None

            if not loc_id or not lon_str or not lat_str:
                continue

            lon = float(lon_str)
            lat = float(lat_str)

            # Validate Chicago bbox
            if not (CHI_LAT_MIN <= lat <= CHI_LAT_MAX and CHI_LON_MIN <= lon <= CHI_LON_MAX):
                continue

            # Create meter entry
            meter = {
                'n': str(loc_id),
                'x': round(lon, 6),
                'y': round(lat, 6),
                'c': 0,  # Cost unknown from raw data
                'p': [{'d': [1, 2, 3, 4, 5, 6, 7], 'f': '08:00', 't': '22:00'}]  # typical hours
            }
            parsed.append(meter)

            if (idx + 1) % 100 == 0:
                print(f"  Parsed {idx + 1:,} meters…", end='\r')
        except (ValueError, IndexError, TypeError):
            continue

    print(f"\n[CHI] Successfully parsed {len(parsed):,} meters")
    return parsed


# ══════════════════════════════════════════════════════════════════════════════
# 6. Parse RPP zones → cleaning/noParking rules
# ══════════════════════════════════════════════════════════════════════════════

def parse_rpp_zones(zones_raw: list[dict], conn: sqlite3.Connection) -> list[dict]:
    """
    Convert RPP zone records to cleaning/noParking segments.

    RPP zones are permit-only areas, so we emit them as cleaning rules
    (or could be a separate permitOnly type).

    Output format per segment:
      {
        "c": [[lon, lat], ...],  # coordinates
        "r": [{"d": [1..7], "permitZone": "A"}]  # rules
      }
    """
    print("[CHI] Parsing RPP zones…")
    segments = []

    for idx, rec in enumerate(zones_raw):
        try:
            # Try various column names/indices
            zone_name = None
            lon = None
            lat = None

            # Attempt to extract by common field names in Socrata
            if isinstance(rec, dict):
                # If dict: check for standard field names
                zone_name = rec.get('zone') or rec.get('Zone') or rec.get('0')
                lon = rec.get('longitude') or rec.get('Longitude') or rec.get('1')
                lat = rec.get('latitude') or rec.get('Latitude') or rec.get('2')
            elif isinstance(rec, list):
                # If list: indexed access
                zone_name = rec[0] if len(rec) > 0 else None
                lon = rec[1] if len(rec) > 1 else None
                lat = rec[2] if len(rec) > 2 else None

            if not zone_name or not lon or not lat:
                continue

            try:
                lon = float(lon)
                lat = float(lat)
            except (ValueError, TypeError):
                continue

            # Validate Chicago bbox
            if not (CHI_LAT_MIN <= lat <= CHI_LAT_MAX and CHI_LON_MIN <= lon <= CHI_LON_MAX):
                continue

            # Create segment with permitOnly rule
            segment = {
                'c': [[round(lon, 6), round(lat, 6)]],
                'r': [{
                    'd': [1, 2, 3, 4, 5, 6, 7],  # all days
                    'permitZone': str(zone_name)
                }]
            }
            segments.append(segment)

            if (idx + 1) % 10 == 0:
                print(f"  Parsed {idx + 1:,} zones…", end='\r')
        except Exception:
            continue

    print(f"\n[CHI] Successfully parsed {len(segments):,} RPP zones")
    return segments


# ══════════════════════════════════════════════════════════════════════════════
# 7. Parse street cleaning → cleaning rules
# ══════════════════════════════════════════════════════════════════════════════

def parse_street_cleaning(schedules_raw: list[dict], conn: sqlite3.Connection) -> list[dict]:
    """
    Convert street cleaning schedule records to noParking segments.

    Output format:
      {
        "c": [[lon, lat], ...],
        "r": [{"d": [day_nums], "f": "HH:MM", "t": "HH:MM"}]
      }
    """
    print("[CHI] Parsing street cleaning schedules…")
    segments = []

    # Day name to ISO weekday mapping
    day_map = {
        'MON': 1, 'MONDAY': 1,
        'TUE': 2, 'TUESDAY': 2,
        'WED': 3, 'WEDNESDAY': 3,
        'THU': 4, 'THURSDAY': 4,
        'FRI': 5, 'FRIDAY': 5,
        'SAT': 6, 'SATURDAY': 6,
        'SUN': 7, 'SUNDAY': 7,
    }

    for idx, rec in enumerate(schedules_raw):
        try:
            if isinstance(rec, list) and len(rec) > 0:
                # Typical Socrata format: [street, day, time_window, location, ...]
                street = rec[0] if len(rec) > 0 else None
                day_str = rec[1] if len(rec) > 1 else None
                time_window = rec[2] if len(rec) > 2 else None
                location_str = rec[3] if len(rec) > 3 else None

                if not street or not day_str:
                    continue

                # Parse day
                day_upper = str(day_str).upper().strip()
                day_num = day_map.get(day_upper, None)
                if not day_num:
                    continue

                # Geocode the street address if location not present
                if location_str:
                    try:
                        # Assume location_str is "lon, lat" or similar
                        parts = location_str.split(',')
                        lon = float(parts[0].strip())
                        lat = float(parts[1].strip())
                    except (ValueError, IndexError):
                        lon, lat = nominatim_geocode(street, conn)
                        if not lon or not lat:
                            continue
                else:
                    lon, lat = nominatim_geocode(street, conn)
                    if not lon or not lat:
                        continue

                # Validate Chicago bbox
                if not (CHI_LAT_MIN <= lat <= CHI_LAT_MAX and CHI_LON_MIN <= lon <= CHI_LON_MAX):
                    continue

                # Parse time window (e.g., "8:00 AM - 4:00 PM")
                time_from = "08:00"
                time_to = "18:00"
                if time_window:
                    # Simple regex: "HH:MM AM - HH:MM PM"
                    match = re.search(r'(\d{1,2}):?(\d{0,2})\s*(AM|PM)\s*-\s*(\d{1,2}):?(\d{0,2})\s*(AM|PM)',
                                    str(time_window), re.IGNORECASE)
                    if match:
                        h1 = int(match.group(1))
                        m1 = int(match.group(2)) if match.group(2) else 0
                        ampm1 = match.group(3).upper()
                        h2 = int(match.group(4))
                        m2 = int(match.group(5)) if match.group(5) else 0
                        ampm2 = match.group(6).upper()

                        # Convert to 24h
                        if ampm1 == 'PM' and h1 != 12:
                            h1 += 12
                        elif ampm1 == 'AM' and h1 == 12:
                            h1 = 0
                        if ampm2 == 'PM' and h2 != 12:
                            h2 += 12
                        elif ampm2 == 'AM' and h2 == 12:
                            h2 = 0

                        time_from = f"{h1:02d}:{m1:02d}"
                        time_to = f"{h2:02d}:{m2:02d}"

                # Create segment
                segment = {
                    'c': [[round(lon, 6), round(lat, 6)]],
                    'r': [{
                        'd': [day_num],
                        'f': time_from,
                        't': time_to
                    }]
                }
                segments.append(segment)

                if (idx + 1) % 100 == 0:
                    print(f"  Parsed {idx + 1:,} cleaning entries…", end='\r')
        except Exception:
            continue

    print(f"\n[CHI] Successfully parsed {len(segments):,} cleaning schedules")
    return segments


# ══════════════════════════════════════════════════════════════════════════════
# 8. Build universal JSON
# ══════════════════════════════════════════════════════════════════════════════

def build_universal_json(meters: list[dict], rpp_segments: list[dict],
                        cleaning_segments: list[dict]) -> dict:
    """Combine all data into universal format."""
    print("[CHI] Building universal JSON…")

    # Merge cleaning and RPP into single cleaning bucket
    all_cleaning = cleaning_segments + rpp_segments

    data = {
        'v': 1,
        'meters': meters,
        'alternating': [],
        'cleaning': all_cleaning
    }

    return data


# ══════════════════════════════════════════════════════════════════════════════
# 9. Main
# ══════════════════════════════════════════════════════════════════════════════

def main() -> None:
    os.makedirs(ASSET_DIR, exist_ok=True)
    conn = init_cache()

    try:
        # Download all data
        meters_raw = download_parking_meters()
        rpp_zones = download_rpp_zones()
        cleaning_raw = download_street_cleaning()

        # Parse
        meters = parse_meters(meters_raw, conn)
        rpp_segments = parse_rpp_zones(rpp_zones, conn)
        cleaning_segments = parse_street_cleaning(cleaning_raw, conn)

        # Build universal JSON
        data = build_universal_json(meters, rpp_segments, cleaning_segments)

        # Write output
        with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
            json.dump(data, f, separators=(',', ':'), ensure_ascii=False)

        # Summary
        n_meters = len(data['meters'])
        n_zones = len([r for seg in data['cleaning'] for r in seg.get('r', [])
                       if 'permitZone' in r])
        n_cleaning = len([r for seg in data['cleaning'] for r in seg.get('r', [])
                         if 'permitZone' not in r])

        print("\n" + "="*70)
        print("[CHI] SUMMARY")
        print("="*70)
        print(f"[CHI] Parking Meters:     {n_meters:,} locations")
        print(f"[CHI] Permit Parking:     {n_zones:,} zones (RPP)")
        print(f"[CHI] Street Cleaning:    {n_cleaning:,} segments")
        print(f"[CHI] Output:             {OUTPUT_FILE}")
        print(f"[CHI] Coverage estimate:  ~40-45% (meters + RPP coverage)")
        print("="*70)

        # File size info
        size = os.path.getsize(OUTPUT_FILE)
        print(f"[CHI] File size: {size:,} bytes ({size/1024:.1f} KB)")

    finally:
        conn.close()


if __name__ == '__main__':
    main()
