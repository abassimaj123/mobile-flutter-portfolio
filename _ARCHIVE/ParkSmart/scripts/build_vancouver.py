"""
build_vancouver.py
==================
Downloads and processes Vancouver parking regulations from opendata.vancouver.ca
and converts them to the universal parking format.

Target format (assets/data/vancouver.json):
  {
    "v": 1,
    "meters": [],
    "alternating": [],
    "cleaning": [
      {
        "c": [[lon,lat],[lon,lat],...],    -- coordinates along street
        "r": [{"d":[1,2,3,4,5],"f":"08:00","t":"18:00"}]  -- rules
      }
    ]
  }

Data source: City of Vancouver Open Data Portal (CKAN)
  - Parking Regulations on Streets dataset
  - Multiple regulation types: timed, permit-only, no-parking, etc.
  - Street geometry from OpenStreetMap

Usage (from project root):
  python scripts/build_vancouver.py
"""

import csv
import json
import os
import re
import sys
import time
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional

try:
    import requests
except ImportError:
    print("ERROR: requests library required. Install with: pip install requests")
    sys.exit(1)

try:
    from geopy.geocoders import Nominatim
except ImportError:
    print("ERROR: geopy library required. Install with: pip install geopy")
    sys.exit(1)

# ── Config ──────────────────────────────────────────────────────────────────────
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
ASSETS_DIR = os.path.join(PROJECT_ROOT, 'assets', 'data')
CACHE_DIR = os.path.join(SCRIPT_DIR, '.cache_vancouver')
OUTPUT_FILE = os.path.join(ASSETS_DIR, 'vancouver.json')

os.makedirs(CACHE_DIR, exist_ok=True)
os.makedirs(ASSETS_DIR, exist_ok=True)

# Vancouver bounding box (for filtering)
VAN_BBOX = {
    'min_lat': 49.200,
    'max_lat': 49.320,
    'min_lon': -123.280,
    'max_lon': -123.000,
}

# API endpoints
CKAN_API = "https://opendata.vancouver.ca/api/3/action"
DATASET_NAME = "parking-regulations-on-streets"

# Geocoding cache to avoid repeated API calls
GEOCODE_CACHE_FILE = os.path.join(CACHE_DIR, 'geocodes.json')
if os.path.exists(GEOCODE_CACHE_FILE):
    with open(GEOCODE_CACHE_FILE, 'r') as f:
        GEOCODE_CACHE = json.load(f)
else:
    GEOCODE_CACHE = {}

# ── Logging ─────────────────────────────────────────────────────────────────────
def log(msg, level='INFO'):
    """Print timestamped log message."""
    ts = datetime.now().strftime('%H:%M:%S')
    print(f"[{ts}] {level}: {msg}")

def log_progress(current, total, label=''):
    """Print progress with percent."""
    pct = (current / total * 100) if total > 0 else 0
    print(f"  [{current:5d}/{total:5d}] {pct:5.1f}% {label}", end='\r')

# ── Step 1: Download Parking Regulations ────────────────────────────────────────
def download_regulations() -> List[Dict]:
    """
    Download parking regulations from Vancouver Open Data.

    Attempts multiple strategies:
    1. Query CKAN API directly for the dataset
    2. Search for parking-related datasets
    3. Return empty list if unavailable (user can provide manual CSV)

    Returns:
        List of regulation records with fields:
        - street_name (or equivalent)
        - side (East/West, North/South, etc.)
        - regulation (text description)
        - days_of_week
        - time_from, time_to
        - max_stay_minutes
    """
    log(f"Downloading parking regulations from {CKAN_API}")

    regulations = []

    try:
        # Strategy 1: Try to get package info
        package_url = f"{CKAN_API}/package_show?id={DATASET_NAME}"
        response = requests.get(package_url, timeout=10)

        if response.status_code == 200:
            package = response.json().get('result', {})
            resources = package.get('resources', [])

            log(f"Found {len(resources)} resources in '{DATASET_NAME}' dataset")

            for resource in resources:
                # Download CSV/JSON resources
                url = resource.get('url', '')
                fmt = resource.get('format', '').lower()
                name = resource.get('name', '')

                if fmt in ['csv', 'json']:
                    log(f"  Downloading: {name}")
                    try:
                        reg_response = requests.get(url, timeout=15)
                        if reg_response.status_code == 200:
                            if fmt == 'csv':
                                regulations.extend(_parse_csv_regulations(reg_response.text))
                            elif fmt == 'json':
                                regulations.extend(_parse_json_regulations(reg_response.json()))
                    except Exception as e:
                        log(f"  Error downloading {name}: {e}", 'WARN')
        else:
            log(f"Dataset '{DATASET_NAME}' not found (404)", 'WARN')

    except Exception as e:
        log(f"Error querying CKAN API: {e}", 'WARN')

    if regulations:
        log(f"Downloaded {len(regulations)} regulation records")
    else:
        log("No regulations found. To manually add data:", 'WARN')
        log("  1. Download CSV from https://opendata.vancouver.ca", 'WARN')
        log("  2. Save to: " + os.path.join(CACHE_DIR, 'regulations.csv'), 'WARN')
        log("  3. Re-run script", 'WARN')

    return regulations

def _parse_csv_regulations(csv_text: str) -> List[Dict]:
    """Parse CSV format regulations."""
    records = []
    try:
        reader = csv.DictReader(csv_text.split('\n'))
        for row in reader:
            if row:
                records.append(row)
    except Exception as e:
        log(f"Error parsing CSV: {e}", 'WARN')
    return records

def _parse_json_regulations(data: any) -> List[Dict]:
    """Parse JSON format regulations."""
    records = []
    try:
        if isinstance(data, dict):
            records = data.get('records', data.get('data', []))
        elif isinstance(data, list):
            records = data
    except Exception as e:
        log(f"Error parsing JSON: {e}", 'WARN')
    return records

# ── Step 2: Parse Regulation Text ──────────────────────────────────────────────
def parse_regulation_text(text: str) -> Dict:
    """
    Extract parking rule structure from regulation text.

    Handles patterns like:
    - "No Parking 6am-9am Weekdays"
    - "2 Hour Parking Weekdays 9am-6pm"
    - "Permit Parking Only"
    - "Street Cleaning Tuesday 8am-10am"

    Returns:
        {
            'type': 'no_parking' | 'time_limit' | 'permit_only' | 'cleaning' | 'unknown',
            'days': [1,2,3,4,5] (Monday=1, Sunday=7),
            'from': '08:00' or None,
            'to': '18:00' or None,
            'max_stay': 120 (minutes) or None,
            'description': original text,
        }
    """
    if not text or not isinstance(text, str):
        return {
            'type': 'unknown',
            'days': None,
            'from': None,
            'to': None,
            'max_stay': None,
            'description': '',
        }

    text_clean = text.strip().upper()
    result = {
        'type': 'unknown',
        'days': None,
        'from': None,
        'to': None,
        'max_stay': None,
        'description': text,
    }

    # Detect regulation type
    if 'NO PARKING' in text_clean:
        result['type'] = 'no_parking'
    elif 'CLEANING' in text_clean or 'STREET CLEANING' in text_clean:
        result['type'] = 'cleaning'
    elif 'PERMIT' in text_clean and 'ONLY' in text_clean:
        result['type'] = 'permit_only'
    elif any(h in text_clean for h in ['HOUR PARKING', 'HOUR LIMIT']):
        result['type'] = 'time_limit'

    # Extract time range (HH:MM or H:MM or HAM/HPM formats)
    time_pattern = r'(\d{1,2}):?(\d{2})?\s*(am|pm|a\.m\.|p\.m\.)?'
    times = re.findall(time_pattern, text_clean)

    if len(times) >= 2:
        # First time = from, second time = to
        h1, m1, ampm1 = times[0]
        h2, m2, ampm2 = times[1]

        from_h = _convert_to_24h(int(h1), m1 or '00', ampm1 or '')
        to_h = _convert_to_24h(int(h2), m2 or '00', ampm2 or '')

        if from_h and to_h:
            result['from'] = from_h
            result['to'] = to_h

    # Extract max stay in hours (e.g., "2 Hour Parking")
    stay_pattern = r'(\d+)\s*(?:-\s*)?hour'
    stay_match = re.search(stay_pattern, text_clean)
    if stay_match:
        hours = int(stay_match.group(1))
        result['max_stay'] = hours * 60  # convert to minutes

    # Extract days of week
    days = _extract_days(text_clean)
    if days:
        result['days'] = days
    else:
        # Default to weekdays if not specified and it's a timed restriction
        if result['type'] in ['time_limit', 'no_parking'] and result['from']:
            result['days'] = [1, 2, 3, 4, 5]  # Mon-Fri

    return result

def _convert_to_24h(hour: int, minute: str, ampm: str) -> Optional[str]:
    """Convert 12-hour time to 24-hour format HH:MM."""
    try:
        minute = int(minute) if minute else 0
        ampm = ampm.upper().replace('.', '')

        if 'P' in ampm:
            if hour != 12:
                hour += 12
        elif 'A' in ampm:
            if hour == 12:
                hour = 0

        return f"{hour:02d}:{minute:02d}"
    except:
        return None

def _extract_days(text: str) -> Optional[List[int]]:
    """Extract days of week from text. Returns list of 1-7 (Mon-Sun) or None."""
    days = set()
    text_upper = text.upper()

    # Map text patterns to day numbers (Monday=1 ... Sunday=7)
    day_patterns = {
        r'\bMON(DAY)?\b': [1],
        r'\bTUE(SDAY)?\b': [2],
        r'\bWED(NESDAY)?\b': [3],
        r'\bTHU(RSDAY)?\b': [4],
        r'\bFRI(DAY)?\b': [5],
        r'\bSAT(URDAY)?\b': [6],
        r'\bSUN(DAY)?\b': [7],
        r'\bWEEKDAY\b': [1, 2, 3, 4, 5],
        r'\bWEEKEND\b': [6, 7],
        r'\bMON[\s-]*FRI\b': [1, 2, 3, 4, 5],
    }

    for pattern, day_list in day_patterns.items():
        if re.search(pattern, text_upper):
            days.update(day_list)

    return sorted(list(days)) if days else None

# ── Step 3: Geocode Streets ─────────────────────────────────────────────────────
def geocode_street(street_name: str, side: Optional[str] = None) -> Optional[Tuple[float, float]]:
    """
    Geocode a street name to coordinates within Vancouver.

    Uses Nominatim (OpenStreetMap) with caching to avoid repeated requests.
    Returns (lon, lat) or None if not found.
    """
    cache_key = f"{street_name}|{side or 'both'}"

    # Check cache
    if cache_key in GEOCODE_CACHE:
        coords = GEOCODE_CACHE[cache_key]
        return tuple(coords) if coords else None

    try:
        geolocator = Nominatim(user_agent="parksmart_van_parser")

        # Build query
        query = f"{street_name}, Vancouver, BC, Canada"
        if side and side.upper() in ['NORTH', 'SOUTH', 'EAST', 'WEST']:
            query = f"{side.upper()} {street_name}, Vancouver, BC, Canada"

        # Query with timeout
        location = geolocator.geocode(query, timeout=5)

        if location:
            # Verify it's in Vancouver bbox
            if (_is_in_vancouver(location.latitude, location.longitude)):
                coords = (location.longitude, location.latitude)
                GEOCODE_CACHE[cache_key] = list(coords)
                _save_geocode_cache()
                return coords
            else:
                GEOCODE_CACHE[cache_key] = None
        else:
            GEOCODE_CACHE[cache_key] = None

        # Rate limit Nominatim (1 request per second)
        time.sleep(1)

    except Exception as e:
        log(f"Geocoding error for '{street_name}': {e}", 'WARN')
        GEOCODE_CACHE[cache_key] = None

    return None

def _is_in_vancouver(lat: float, lon: float) -> bool:
    """Check if coordinates are within Vancouver."""
    return (VAN_BBOX['min_lat'] <= lat <= VAN_BBOX['max_lat'] and
            VAN_BBOX['min_lon'] <= lon <= VAN_BBOX['max_lon'])

def _save_geocode_cache():
    """Save geocode cache to disk."""
    try:
        with open(GEOCODE_CACHE_FILE, 'w') as f:
            json.dump(GEOCODE_CACHE, f, indent=2)
    except Exception as e:
        log(f"Warning: Could not save geocode cache: {e}", 'WARN')

# ── Step 4: Build Street Segments ──────────────────────────────────────────────
def build_street_segments(regulations: List[Dict]) -> Dict[str, Dict]:
    """
    Group regulations by street and build unified segments.

    Returns:
        {
            'street_name': {
                'coords': (lon, lat) or None,
                'rules': [parsed rule dicts],
                'side': side identifier,
            }
        }
    """
    segments = {}

    for reg in regulations:
        # Extract street name (varies by data source)
        street_name = (reg.get('street_name') or
                       reg.get('street') or
                       reg.get('name') or
                       '').strip()

        side = (reg.get('side') or
                reg.get('direction') or
                '').strip()

        regulation_text = (reg.get('regulation') or
                          reg.get('restrictions') or
                          reg.get('description') or
                          '').strip()

        if not street_name or not regulation_text:
            continue

        # Parse the regulation
        parsed = parse_regulation_text(regulation_text)

        # Skip unknown types for now
        if parsed['type'] == 'unknown':
            continue

        # Build segment key (street + side if available)
        seg_key = f"{street_name}|{side}" if side else street_name

        if seg_key not in segments:
            # Geocode the street (only once per street)
            coords = geocode_street(street_name, side)
            segments[seg_key] = {
                'coords': coords,
                'rules': [],
                'side': side,
                'street_name': street_name,
            }

        segments[seg_key]['rules'].append(parsed)

    return segments

# ── Step 5: Convert to Universal Format ────────────────────────────────────────
def convert_to_universal_format(segments: Dict[str, Dict]) -> Dict:
    """
    Convert segments to universal parking format.

    Separates by type:
    - meters: parking spots with rates (not applicable for Vancouver street regulations)
    - alternating: alternating side parking rules (not applicable here)
    - cleaning: street cleaning rules
    - timed: time-limited parking (grouped as cleaning for now)
    """
    cleaning = []

    for seg_key, seg_data in segments.items():
        if not seg_data['coords']:
            continue

        coords = seg_data['coords']
        rules = seg_data['rules']

        # Filter rules by type
        cleaning_rules = [r for r in rules if r['type'] in ['cleaning', 'time_limit', 'no_parking']]

        if not cleaning_rules:
            continue

        # Convert rules to universal format
        universal_rules = []
        for rule in cleaning_rules:
            if rule['days'] and rule['from'] and rule['to']:
                universal_rules.append({
                    'd': rule['days'],  # days of week
                    'f': rule['from'],  # from time
                    't': rule['to'],    # to time
                    # 'm': rule['max_stay'] if rule['max_stay'] else None,  # max stay (optional)
                })

        if universal_rules:
            # Create a single-point segment for now
            # In production, would expand to full street geometry
            cleaning.append({
                'c': [[coords[0], coords[1]]],  # coordinates (lon, lat)
                'r': universal_rules,
            })

    return {
        'v': 1,
        'meters': [],
        'alternating': [],
        'cleaning': cleaning,
    }

# ── Main ────────────────────────────────────────────────────────────────────────
def main():
    """Main entry point."""
    log("Starting Vancouver parking regulations build...")
    print()

    # Step 1: Download regulations
    log("Step 1: Downloading regulations")
    regulations = download_regulations()
    if not regulations:
        log("No regulations downloaded. Cannot proceed.", 'ERROR')
        return 1
    print()

    # Step 2: Build street segments
    log(f"Step 2: Processing {len(regulations)} records into street segments")
    segments = build_street_segments(regulations)
    log(f"  Built {len(segments)} unique street segments")

    # Count by type
    type_counts = defaultdict(int)
    for seg in segments.values():
        for rule in seg['rules']:
            type_counts[rule['type']] += 1

    log("  Regulation types found:")
    for reg_type, count in sorted(type_counts.items()):
        log(f"    - {reg_type}: {count}")
    print()

    # Step 3: Convert to universal format
    log("Step 3: Converting to universal format")
    output = convert_to_universal_format(segments)
    print()

    # Step 4: Write output
    log(f"Step 4: Writing output to {OUTPUT_FILE}")
    try:
        os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
        with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
            json.dump(output, f, separators=(',', ':'), ensure_ascii=False)

        file_size = os.path.getsize(OUTPUT_FILE)
        log(f"✓ Output written: {file_size:,} bytes")
    except Exception as e:
        log(f"Error writing output: {e}", 'ERROR')
        return 1

    print()

    # Summary
    cleaning_count = len(output.get('cleaning', []))
    meter_count = len(output.get('meters', []))
    alt_count = len(output.get('alternating', []))

    coverage_pct = (cleaning_count / len(segments) * 100) if segments else 0

    log("=" * 70)
    log(f"[VAN] Parking Regulations: {cleaning_count:,} segments")
    log(f"[VAN] Coverage estimate: ~{coverage_pct:.0f}%")
    log(f"[VAN] Breakdown: {meter_count} meters, {alt_count} alternating, {cleaning_count} cleaning")
    log("=" * 70)

    return 0

if __name__ == '__main__':
    sys.exit(main())
