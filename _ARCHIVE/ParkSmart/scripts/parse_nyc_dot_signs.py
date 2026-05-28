"""
parse_nyc_dot_signs.py
======================
Downloads NYC DOT "Parking Regulation Locations and Signs" dataset and
produces assets/data/nyc.json in the ParkSmart universal format.

Data source: https://data.cityofnewyork.us/resource/xswq-wnv9.json
             Socrata Open Data API — ~83 000 sign records

Output format:
  {"v":1, "meters":[], "alternating":[], "cleaning":[
    {"c":[[lon,lat],...], "r":[{"d":[1,2,3,4,5],"f":"08:00","t":"18:00"}]}
  ]}

Features:
  - Downloads all ~83k sign records from NYC Socrata
  - Geocodes via NYC Planning Labs GeoSearch (fast, accurate) with Nominatim fallback
  - Snaps segment points to OSM ways via Overpass API + KDTree (30m radius)
  - Merges with existing nyc.json if present
  - Caches geocoding results in SQLite

Usage:
  pip install requests pyproj scipy
  python parse_nyc_dot_signs.py
"""

import json
import math
import os
import re
import sqlite3
import sys
import time
from collections import defaultdict
from dataclasses import dataclass
from typing import Optional

import requests

try:
    from scipy.spatial import cKDTree
    _HAS_SCIPY = True
except ImportError:
    _HAS_SCIPY = False
    print("[WARN] scipy not found — OSM snap will use simple O(n) search")

# ── pyproj (optional) ──────────────────────────────────────────────────────────
try:
    from pyproj import Transformer
    _TRANSFORMER = Transformer.from_crs("EPSG:2263", "EPSG:4326", always_xy=True)
    _HAS_PYPROJ = True
except ImportError:
    _HAS_PYPROJ = False
    print("[WARN] pyproj not found — using approximate coordinate conversion")


# ── Paths ──────────────────────────────────────────────────────────────────────
SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
ASSET_DIR   = os.path.join(SCRIPT_DIR, '..', 'assets', 'data')
OUTPUT_FILE = os.path.join(ASSET_DIR, 'nyc.json')
CACHE_DB    = os.path.join(SCRIPT_DIR, '.geocode_cache.db')

# ── Socrata API ────────────────────────────────────────────────────────────────
API_URL   = "https://data.cityofnewyork.us/resource/xswq-wnv9.json"
PAGE_SIZE = 50_000

# ── Geocoding & OSM ────────────────────────────────────────────────────────────
GEOSEARCH_URL  = "https://geosearch.planninglabs.nyc/v2/search"
NOMINATIM_URL  = "https://nominatim.openstreetmap.org/search"
OVERPASS_URL   = "https://overpass-api.de/api/interpreter"

# NYC Bounding box (south, west, north, east) for Overpass
NYC_BBOX = (40.4774, -74.2909, 40.9176, -73.7004)

# Search radius for OSM way snapping (meters)
OSM_SNAP_RADIUS_M = 30

# ── Day mappings ───────────────────────────────────────────────────────────────
_DAY_NAME = {
    'MON': 1, 'TUE': 2, 'WED': 3, 'THU': 4, 'FRI': 5, 'SAT': 6, 'SUN': 7,
    'MONDAY': 1, 'TUESDAY': 2, 'WEDNESDAY': 3, 'THURSDAY': 4,
    'FRIDAY': 5, 'SATURDAY': 6, 'SUNDAY': 7,
}
_WEEKDAYS = [1, 2, 3, 4, 5]
_WEEKEND  = [6, 7]
_ALL_DAYS = [1, 2, 3, 4, 5, 6, 7]


# ══════════════════════════════════════════════════════════════════════════════
# Geocoding Cache (SQLite)
# ══════════════════════════════════════════════════════════════════════════════

@dataclass
class GeoCache:
    """Simple SQLite cache for geocoding results."""
    db_path: str

    def __post_init__(self):
        """Initialize SQLite cache."""
        conn = sqlite3.connect(self.db_path)
        conn.execute('''
            CREATE TABLE IF NOT EXISTS geocodes (
                address TEXT PRIMARY KEY,
                lon REAL,
                lat REAL,
                timestamp INTEGER
            )
        ''')
        conn.commit()
        conn.close()

    def get(self, address: str) -> Optional[tuple[float, float]]:
        """Return (lon, lat) or None if not cached."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.execute(
            'SELECT lon, lat FROM geocodes WHERE address = ?',
            (address,)
        )
        row = cursor.fetchone()
        conn.close()
        return (row[0], row[1]) if row else None

    def put(self, address: str, lon: float, lat: float) -> None:
        """Cache a geocoding result."""
        conn = sqlite3.connect(self.db_path)
        conn.execute(
            'INSERT OR REPLACE INTO geocodes (address, lon, lat, timestamp) VALUES (?, ?, ?, ?)',
            (address, lon, lat, int(time.time()))
        )
        conn.commit()
        conn.close()


# ══════════════════════════════════════════════════════════════════════════════
# OSM Way data structure
# ══════════════════════════════════════════════════════════════════════════════

@dataclass
class OSMWay:
    """Represents an OpenStreetMap way."""
    way_id: int
    coords: list[tuple[float, float]]  # [(lon, lat), ...]
    center_lon: float
    center_lat: float

    @classmethod
    def from_overpass_geom(cls, way_id: int, geometry: list) -> 'OSMWay':
        """Create OSMWay from Overpass geometry (list of {lat, lon} dicts)."""
        coords = [(g['lon'], g['lat']) for g in geometry]
        if not coords:
            return None
        center_lon = sum(c[0] for c in coords) / len(coords)
        center_lat = sum(c[1] for c in coords) / len(coords)
        return cls(way_id=way_id, coords=coords, center_lon=center_lon, center_lat=center_lat)


# ══════════════════════════════════════════════════════════════════════════════
# 1. Geocoding with NYC Planning Labs + Nominatim + Cache
# ══════════════════════════════════════════════════════════════════════════════

_geo_cache = None

def init_geocoding() -> GeoCache:
    """Initialize geocoding cache."""
    global _geo_cache
    if _geo_cache is None:
        _geo_cache = GeoCache(CACHE_DB)
    return _geo_cache

def geocode_address(address: str, session: requests.Session) -> Optional[tuple[float, float]]:
    """
    Geocode an address using NYC Planning Labs GeoSearch (preferred)
    then Nominatim (fallback), with SQLite caching.

    Returns (lon, lat) or None if geocoding fails.
    """
    cache = init_geocoding()

    # Check cache first
    cached = cache.get(address)
    if cached:
        return cached

    # Try NYC Planning Labs GeoSearch (most accurate for NYC)
    try:
        params = {
            'text': address,
            'focus.point.lat': 40.7128,
            'focus.point.lon': -74.0060,
        }
        resp = session.get(GEOSEARCH_URL, params=params, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        if data.get('features') and len(data['features']) > 0:
            coords = data['features'][0]['geometry']['coordinates']
            lon, lat = coords[0], coords[1]
            # Validate NYC bounds
            if 40.4 <= lat <= 41.0 and -74.3 <= lon <= -73.6:
                cache.put(address, lon, lat)
                return (lon, lat)
    except Exception:
        pass  # Fall through to Nominatim

    # Fallback to Nominatim with NYC qualifier
    try:
        params = {
            'q': f"{address}, New York City",
            'format': 'json',
            'limit': 1,
        }
        resp = session.get(NOMINATIM_URL, params=params, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        if data and len(data) > 0:
            lon = float(data[0]['lon'])
            lat = float(data[0]['lat'])
            # Validate NYC bounds
            if 40.4 <= lat <= 41.0 and -74.3 <= lon <= -73.6:
                cache.put(address, lon, lat)
                return (lon, lat)
    except Exception:
        pass

    return None


# ══════════════════════════════════════════════════════════════════════════════
# 2. Coordinate conversion
# ══════════════════════════════════════════════════════════════════════════════

def statplane_to_wgs84(x: float, y: float) -> tuple[float, float]:
    """Convert NYC State Plane (EPSG:2263, feet) → WGS84 lon/lat."""
    if _HAS_PYPROJ:
        lon, lat = _TRANSFORMER.transform(x, y)
        return lon, lat
    # Approximate fallback (±100m accuracy)
    lat = y / 364_173.6 + 40.7128
    lon = x / 294_902.8 - 74.0060
    return lon, lat


# ══════════════════════════════════════════════════════════════════════════════
# 3. Time parsing
# ══════════════════════════════════════════════════════════════════════════════

_TIME_RE = re.compile(r'(\d{1,2})(?::(\d{2}))?\s*(AM|PM)', re.IGNORECASE)

def parse_time(token: str) -> str | None:
    """Parse '8AM', '8:30AM', '11PM' → '08:00', '08:30', '23:00'."""
    m = _TIME_RE.match(token.strip())
    if not m:
        return None
    hour = int(m.group(1))
    minute = int(m.group(2)) if m.group(2) else 0
    meridiem = m.group(3).upper()
    if meridiem == 'PM' and hour != 12:
        hour += 12
    elif meridiem == 'AM' and hour == 12:
        hour = 0
    return f"{hour:02d}:{minute:02d}"

def extract_time_range(text: str) -> tuple[str, str] | None:
    """Extract first 'HH:MM-HH:MM' range from sign text. Returns (from, to) or None."""
    # Match patterns like: 8AM-6PM, 8:30AM-6:00PM, 11PM-7AM
    pattern = re.compile(
        r'(\d{1,2}(?::\d{2})?\s*(?:AM|PM))\s*[-–TO]+\s*(\d{1,2}(?::\d{2})?\s*(?:AM|PM))',
        re.IGNORECASE,
    )
    m = pattern.search(text)
    if not m:
        return None
    f = parse_time(m.group(1))
    t = parse_time(m.group(2))
    if f and t:
        return f, t
    return None


# ══════════════════════════════════════════════════════════════════════════════
# 4. Day range parsing
# ══════════════════════════════════════════════════════════════════════════════

def _day_range(start: int, end: int) -> list[int]:
    """Return inclusive day list from start to end (1=Mon … 7=Sun)."""
    if start <= end:
        return list(range(start, end + 1))
    # Wrap: e.g. FRI(5) THRU MON(1) = [5,6,7,1]
    return list(range(start, 8)) + list(range(1, end + 1))


def parse_days(text: str) -> list[int]:
    """Parse day specification from sign text. Returns list of ISO weekday ints."""
    t = text.upper()

    if 'ANYTIME' in t:
        return _ALL_DAYS

    if 'WEEKDAYS' in t:
        days = list(_WEEKDAYS)
        # WEEKDAYS EXCEPT might appear but rare — handle via except block below
        return days

    if 'WEEKENDS' in t:
        return list(_WEEKEND)

    # EXCEPT SAT & SUN / EXCEPT WEEKENDS
    except_match = re.search(
        r'EXCEPT\s+((?:MON|TUE|WED|THU|FRI|SAT|SUN)(?:\s*[&,AND\s]+(?:MON|TUE|WED|THU|FRI|SAT|SUN))*)',
        t,
    )
    if except_match:
        excluded_tokens = re.findall(r'MON|TUE|WED|THU|FRI|SAT|SUN', except_match.group(1))
        excluded = {_DAY_NAME[d] for d in excluded_tokens if d in _DAY_NAME}
        # Base: assume all week if "EXCEPT" is present without a prior range
        return [d for d in _ALL_DAYS if d not in excluded]

    # MON THRU FRI / MON THROUGH SAT
    thru_match = re.search(
        r'(MON|TUE|WED|THU|FRI|SAT|SUN)\s+(?:THRU|THROUGH)\s+(MON|TUE|WED|THU|FRI|SAT|SUN)',
        t,
    )
    if thru_match:
        start = _DAY_NAME[thru_match.group(1)]
        end   = _DAY_NAME[thru_match.group(2)]
        return _day_range(start, end)

    # Explicit list: MON, WED & FRI  /  SAT AND SUN
    found = re.findall(r'\b(MON|TUE|WED|THU|FRI|SAT|SUN)\b', t)
    if found:
        return sorted({_DAY_NAME[d] for d in found if d in _DAY_NAME})

    # Fallback: all days
    return _ALL_DAYS


# ══════════════════════════════════════════════════════════════════════════════
# 5. signdesc → structured rule
# ══════════════════════════════════════════════════════════════════════════════

def parse_sign(signdesc: str) -> dict | None:
    """
    Parse a NYC DOT sign description into a structured rule dict.

    Returns dict with keys: type, days, from, to, maxMinutes, permitZone
    or None if the sign is not a parking regulation we handle.

    type values: 'noParking', 'meter', 'free', 'permitOnly', 'cleaning'
    """
    if not signdesc:
        return None

    text = signdesc.upper().strip()

    # ── Ignore non-parking signs ─────────────────────────────────────────────
    if any(kw in text for kw in ('NO STANDING EXCEPT', 'BUS STOP', 'FIRE HYDRANT',
                                  'LOADING ZONE', 'TAXI', 'BUS LANE', 'BIKE LANE',
                                  'SNOW EMERGENCY', 'TOW AWAY')):
        return None

    # ── Permit only ──────────────────────────────────────────────────────────
    permit_match = re.search(r'RESIDENT\s*PERMIT\s*PARKING\s*ZONE\s*([A-Z0-9\-]+)', text)
    if permit_match:
        return {
            'type': 'permitOnly',
            'days': _ALL_DAYS,
            'from': None,
            'to':   None,
            'maxMinutes': None,
            'permitZone': permit_match.group(1),
        }

    # ── No Standing Anytime / No Parking Anytime ─────────────────────────────
    if re.search(r'NO\s+(STANDING|PARKING)\s+ANYTIME', text):
        return {
            'type': 'noParking',
            'days': _ALL_DAYS,
            'from': None,
            'to':   None,
            'maxMinutes': None,
        }

    # ── Street Cleaning ──────────────────────────────────────────────────────
    is_cleaning = 'STREET CLEANING' in text or 'NETTOYAGE' in text
    rule_type = 'cleaning' if is_cleaning else None

    # ── No Parking / No Standing ──────────────────────────────────────────────
    if not rule_type and re.search(r'NO\s+(PARKING|STANDING)', text):
        rule_type = 'noParking'

    # ── Duration limit (N HR PARKING) ─────────────────────────────────────────
    max_minutes = None
    dur_match = re.search(r'(\d+)\s+HR', text)
    if dur_match:
        max_minutes = int(dur_match.group(1)) * 60
        if not rule_type:
            rule_type = 'free'

    # ── Parking Meter ─────────────────────────────────────────────────────────
    if not rule_type and re.search(r'PARKING METER|MUNI METER', text):
        rule_type = 'meter'

    # ── Plain "PARKING" with hours = free ─────────────────────────────────────
    if not rule_type and re.search(r'\bPARKING\b', text):
        rule_type = 'free'

    if not rule_type:
        return None  # sign not recognized

    time_range = extract_time_range(text)
    days = parse_days(text)

    return {
        'type': rule_type,
        'days': days,
        'from': time_range[0] if time_range else None,
        'to':   time_range[1] if time_range else None,
        'maxMinutes': max_minutes,
    }


# ══════════════════════════════════════════════════════════════════════════════
# 6. Download all records from Socrata (paginated)
# ══════════════════════════════════════════════════════════════════════════════

def download_all_signs() -> list[dict]:
    """Fetch all sign records from the NYC Socrata dataset."""
    records = []
    offset = 0
    session = requests.Session()
    session.headers.update({'Accept': 'application/json'})

    print("[NYC DOT] Downloading sign records from Socrata…")
    while True:
        params = {
            '$limit':  PAGE_SIZE,
            '$offset': offset,
            '$order':  'segmentid',
        }
        resp = session.get(API_URL, params=params, timeout=60)
        resp.raise_for_status()
        page = resp.json()
        if not page:
            break
        records.extend(page)
        offset += len(page)
        print(f"  Downloaded {len(records):,} records…", end='\r')
        if len(page) < PAGE_SIZE:
            break
        time.sleep(0.2)  # be polite to the API

    print(f"\n[NYC DOT] Total records downloaded: {len(records):,}")
    return records


# ══════════════════════════════════════════════════════════════════════════════
# 7. Group signs by segment, geocode, parse rules
# ══════════════════════════════════════════════════════════════════════════════

def build_segments(records: list[dict]) -> list[dict]:
    """
    Group records by segmentid, geocode the midpoint, and parse rules.

    Returns list of segment dicts:
      {id, lon, lat, rules: [{type, days, from, to, maxMinutes}], c: [[lon,lat]]}
      where 'c' is initialized to single-point and may be expanded by OSM snap.
    """
    by_segment: dict[str, list[dict]] = defaultdict(list)
    for rec in records:
        sid = rec.get('segmentid', '')
        if sid:
            by_segment[sid].append(rec)

    segments = []
    for sid, signs in by_segment.items():
        # Geocode: average all sign positions on this segment
        coords = []
        for s in signs:
            try:
                x = float(s.get('x_coord', 0) or 0)
                y = float(s.get('y_coord', 0) or 0)
                if x and y:
                    coords.append((x, y))
            except (ValueError, TypeError):
                pass

        if not coords:
            continue

        avg_x = sum(c[0] for c in coords) / len(coords)
        avg_y = sum(c[1] for c in coords) / len(coords)
        lon, lat = statplane_to_wgs84(avg_x, avg_y)

        # Sanity-check: NYC bounding box
        if not (40.4 <= lat <= 41.0 and -74.3 <= lon <= -73.6):
            continue

        # Parse rules from all signs on this segment
        rules = []
        for s in sorted(signs, key=lambda r: int(r.get('order_no', 0) or 0)):
            rule = parse_sign(s.get('signdesc', '') or '')
            if rule:
                # Deduplicate: skip if identical rule already present
                rule_key = (rule['type'], tuple(rule['days']),
                            rule.get('from'), rule.get('to'))
                if not any(
                    (r['type'], tuple(r['days']), r.get('from'), r.get('to')) == rule_key
                    for r in rules
                ):
                    rules.append(rule)

        if rules:
            segments.append({
                'id': sid,
                'lon': lon,
                'lat': lat,
                'rules': rules,
                'c': [[lon, lat]]  # Will be expanded by OSM snap
            })

    return segments


# ══════════════════════════════════════════════════════════════════════════════
# 8. Convert segments → universal JSON format
# ══════════════════════════════════════════════════════════════════════════════

def to_universal_format(segments: list[dict]) -> dict:
    """
    Convert parsed segments to ParkSmart universal city JSON format.

    Rules are grouped into 'cleaning' (noParking / cleaning rules) bucket
    for the initial output.  Meters and alternating rules are also emitted
    to their respective buckets when detected.

    Coordinates come from segment['c'] (set by OSM snap or default single-point).
    """
    cleaning = []
    meters   = []
    alt      = []

    for seg in segments:
        coords = seg.get('c', [[seg['lon'], seg['lat']]])

        cleaning_rules = []
        meter_rules    = []

        for rule in seg['rules']:
            r_entry: dict = {'d': rule['days']}
            if rule.get('from'):
                r_entry['f'] = rule['from']
            if rule.get('to'):
                r_entry['t'] = rule['to']
            if rule.get('maxMinutes'):
                r_entry['m'] = rule['maxMinutes']

            rt = rule['type']
            if rt in ('noParking', 'cleaning'):
                cleaning_rules.append(r_entry)
            elif rt == 'meter':
                meter_rules.append(r_entry)
            # permitOnly and free are noted but not emitted to separate buckets here

        if cleaning_rules:
            cleaning.append({'c': coords, 'r': cleaning_rules})

        if meter_rules:
            meters.append({
                'n': seg['id'],
                'x': seg['lon'],
                'y': seg['lat'],
                'c': 0,         # rate unknown from sign data alone
                'p': meter_rules,
            })

    return {'v': 1, 'meters': meters, 'alternating': alt, 'cleaning': cleaning}


# ══════════════════════════════════════════════════════════════════════════════
# 9. OSM snap via Overpass + KDTree (30m nearest-way)
# ══════════════════════════════════════════════════════════════════════════════

def fetch_osm_ways(session: requests.Session) -> list[OSMWay]:
    """
    Fetch all residential/tertiary ways from NYC via Overpass API.
    Batches requests in groups of 500 to avoid overload.

    Returns list of OSMWay objects with geometry.
    """
    print("[NYC DOT] Fetching OSM ways from Overpass…")

    # Build Overpass query for residential and tertiary ways in NYC bbox
    south, west, north, east = NYC_BBOX
    query = f"""
[out:json];
way["highway"~"residential|tertiary"](bbox:{south},{west},{north},{east});
out geom;
"""

    ways = []
    try:
        resp = session.post(OVERPASS_URL, data=query, timeout=120)
        resp.raise_for_status()
        data = resp.json()

        for elem in data.get('elements', []):
            if elem.get('type') == 'way' and 'geometry' in elem:
                way_id = elem['id']
                geometry = elem['geometry']
                way = OSMWay.from_overpass_geom(way_id, geometry)
                if way:
                    ways.append(way)

        print(f"  Downloaded {len(ways):,} OSM ways")
    except Exception as e:
        print(f"  [WARN] Overpass fetch failed: {e}")
        print("        Proceeding without OSM snap")

    return ways


def snap_to_osm(segments: list[dict], session: requests.Session) -> tuple[list[dict], int]:
    """
    Snap each segment point to the nearest OSM way within 30m.

    Uses scipy.spatial.cKDTree for efficient nearest-neighbor lookup,
    or falls back to O(n) search if scipy unavailable.

    For each matched way, replaces the segment's single-point coords
    with the full way geometry.

    Returns (snapped_segments, matched_count).
    """
    ways = fetch_osm_ways(session)

    if not ways:
        print("[NYC DOT] OSM snap: no ways available — returning segments as-is")
        return segments, 0

    matched = 0

    if _HAS_SCIPY and len(ways) > 100:
        # Build KDTree for fast nearest-neighbor lookup
        print("[NYC DOT] Building KDTree for OSM snap…")
        coords = [[w.center_lon, w.center_lat] for w in ways]
        tree = cKDTree(coords)

        print("[NYC DOT] Snapping segments to OSM ways…")
        for seg in segments:
            lon, lat = seg['lon'], seg['lat']

            # Query tree for nearest neighbor
            dist_m, idx = tree.query([lon, lat], k=1)

            # Convert distance (degrees) to approximate meters
            # At NYC latitude (~40°N), 1° ≈ 85 km in longitude, 111 km in latitude
            approx_dist_m = dist_m * 111_000

            if approx_dist_m <= OSM_SNAP_RADIUS_M:
                way = ways[idx]
                seg['way_id'] = way.way_id
                seg['c'] = way.coords
                matched += 1
    else:
        # Fallback to O(n) search
        print("[NYC DOT] Snapping segments to OSM ways (O(n) search)…")
        for seg in segments:
            lon, lat = seg['lon'], seg['lat']

            best_way = None
            best_dist_m = float('inf')

            for way in ways:
                # Approximate distance to way center in meters
                dlon = way.center_lon - lon
                dlat = way.center_lat - lat
                dist_deg = math.sqrt(dlon ** 2 + dlat ** 2)
                dist_m = dist_deg * 111_000

                if dist_m < best_dist_m:
                    best_dist_m = dist_m
                    best_way = way

            if best_way and best_dist_m <= OSM_SNAP_RADIUS_M:
                seg['way_id'] = best_way.way_id
                seg['c'] = best_way.coords
                matched += 1

    print(f"[NYC DOT] OSM snap: {matched:,} segments matched to ways")
    return segments, matched


# ══════════════════════════════════════════════════════════════════════════════
# 10. Merge with existing nyc.json
# ══════════════════════════════════════════════════════════════════════════════

def merge_with_existing(new_data: dict) -> dict:
    """
    If nyc.json exists, merge by appending non-duplicate entries.
    Deduplicates by geometry midpoint (first coordinate in 'c' list).
    """
    if not os.path.exists(OUTPUT_FILE):
        return new_data

    print(f"[NYC DOT] Merging with existing {OUTPUT_FILE}…")
    with open(OUTPUT_FILE, encoding='utf-8') as f:
        existing = json.load(f)

    # Merge meters: deduplicate by spot name 'n'
    existing_meter_ids = {m['n'] for m in existing.get('meters', [])}
    for m in new_data.get('meters', []):
        if m['n'] not in existing_meter_ids:
            existing['meters'].append(m)

    # Merge cleaning: deduplicate by geometry midpoint (first coord in 'c')
    existing_coords = {
        tuple(seg['c'][0]) if seg.get('c') else None
        for seg in existing.get('cleaning', [])
    }
    existing_coords.discard(None)

    for seg in new_data.get('cleaning', []):
        if seg.get('c'):
            coord_key = tuple(seg['c'][0])
            if coord_key not in existing_coords:
                existing['cleaning'].append(seg)
                existing_coords.add(coord_key)

    return existing


# ══════════════════════════════════════════════════════════════════════════════
# 11. Main
# ══════════════════════════════════════════════════════════════════════════════

def main() -> None:
    os.makedirs(ASSET_DIR, exist_ok=True)

    session = requests.Session()
    session.headers.update({'Accept': 'application/json'})

    # Download
    records = download_all_signs()

    # Build segments
    print("[NYC DOT] Parsing signs and grouping by segment…")
    segments = build_segments(records)
    n_segments = len(segments)
    print(f"[NYC DOT] Grouped by segment: {n_segments:,} segments")

    # OSM snap
    segments, n_ways = snap_to_osm(segments, session)

    # Convert to universal format
    print("[NYC DOT] Building universal JSON…")
    data = to_universal_format(segments)

    # Merge with existing
    data = merge_with_existing(data)

    # Write output
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(data, f, separators=(',', ':'), ensure_ascii=False)

    n_cleaning = len(data['cleaning'])
    n_meters   = len(data['meters'])

    # Output validation report
    print("\n" + "="*70)
    print("[NYC DOT] Output Validation Report:")
    print(f"[NYC DOT] Downloaded: {len(records):,} sign records")
    print(f"[NYC DOT] Grouped by segment: {n_segments:,} segments")
    print(f"[NYC DOT] Snapped to OSM ways: {n_ways:,} matched")
    print(f"[NYC DOT] Final rules: {n_cleaning:,} segments")
    print(f"[NYC DOT] → {OUTPUT_FILE}")
    print(f"[NYC DOT] Cleaning segments: {n_cleaning:,} | Meters: {n_meters:,}")
    print("="*70)


if __name__ == '__main__':
    main()
