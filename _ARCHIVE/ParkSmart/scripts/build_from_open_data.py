#!/usr/bin/env python3
"""
build_from_open_data.py
Fetches real parking data from city open data APIs
Outputs directly to assets/data/{cityId}.json (same format as CityParkingService)

APIs confirmed working:
- Seattle: data.seattle.gov (Socrata) - Paid Parking Occupancy
- SF:      data.sfgov.org   (Socrata) - Parking Meters
- NYC:     data.cityofnewyork.us (Socrata) - TBD
- Toronto: ckan0.cf.opendata.inter.prod-toronto.ca (CKAN)
- Boston:  data.boston.gov (Socrata) - TBD
"""

import json
import math
import os
import re
import time
import hashlib
import requests
from pathlib import Path
from datetime import datetime

try:
    from pyproj import Transformer
    _nysp_to_wgs84 = Transformer.from_crs("EPSG:2263", "EPSG:4326", always_xy=True)
    HAS_PYPROJ = True
except ImportError:
    HAS_PYPROJ = False
    print("WARNING: pyproj not installed — NYC sign coordinate conversion disabled")

OUTPUT_DIR = Path("assets/data")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

HEADERS = {"User-Agent": "ParkSmart/1.0 (open data research)"}
REQUEST_DELAY = 0.5  # sec between calls to be polite


def fetch_json(url, params=None, retries=3):
    for attempt in range(retries):
        try:
            r = requests.get(url, params=params, headers=HEADERS, timeout=30)
            r.raise_for_status()
            return r.json()
        except requests.RequestException as e:
            print(f"    [retry {attempt+1}/{retries}] {e}")
            time.sleep(2 ** attempt)
    return None


# ── Geometry helpers ──────────────────────────────────────────────────────────

def _polygon_centroid(ring):
    """Centroïde d'un anneau polygone [[lon,lat], ...]."""
    if not ring:
        return None, None
    try:
        lons = [float(p[0]) for p in ring]
        lats = [float(p[1]) for p in ring]
        return sum(lons) / len(lons), sum(lats) / len(lats)
    except (TypeError, ZeroDivisionError, IndexError):
        return None, None


def _socrata_geom_centroid(the_geom):
    """Centroïde depuis champ Socrata the_geom (dict GeoJSON ou None)."""
    if not the_geom or not isinstance(the_geom, dict):
        return None, None
    gtype = the_geom.get("type", "")
    coords = the_geom.get("coordinates", [])
    try:
        if gtype == "Point" and len(coords) >= 2:
            return float(coords[0]), float(coords[1])
        if gtype == "Polygon" and coords:
            return _polygon_centroid(coords[0])
        if gtype == "MultiPolygon" and coords:
            return _polygon_centroid(coords[0][0])
    except (TypeError, ValueError, IndexError):
        pass
    return None, None


# Mapping French day names → ISO weekday (1=Mon, 7=Sun)
_FR_DAY_MAP = {
    "LUNDI": 1, "MARDI": 2, "MERCREDI": 3, "JEUDI": 4,
    "VENDREDI": 5, "SAMEDI": 6, "DIMANCHE": 7,
}

def _parse_fr_day_desc(desc_up):
    """Extrait les numéros de jours (1-7) depuis une description française.

    Gère 'LUNDI AU VENDREDI', jours individuels, 'SEMAINE'.
    Défaut : jours ouvrables [1,2,3,4,5].
    """
    # Range: "LUNDI AU VENDREDI" → [1,2,3,4,5]
    rng = re.search(
        r'(LUNDI|MARDI|MERCREDI|JEUDI|VENDREDI|SAMEDI|DIMANCHE)'
        r'\s+(?:AU|À)\s+'
        r'(LUNDI|MARDI|MERCREDI|JEUDI|VENDREDI|SAMEDI|DIMANCHE)',
        desc_up,
    )
    if rng:
        d1 = _FR_DAY_MAP.get(rng.group(1), 1)
        d2 = _FR_DAY_MAP.get(rng.group(2), 7)
        return list(range(d1, d2 + 1))
    # Single named days
    days = []
    for name, num in _FR_DAY_MAP.items():
        if name in desc_up:
            days.append(num)
    if days:
        return sorted(days)
    # "SEMAINE" or "HEBDO" → weekdays
    if any(x in desc_up for x in ["SEMAINE", "HEBDO", "WEEKDAY"]):
        return [1, 2, 3, 4, 5]
    return [1, 2, 3, 4, 5]  # default


def fetch_all_pages(url, params=None, page_size=50000, max_rows=500000):
    """Fetch all pages from a Socrata API (hard cap at max_rows to prevent OOM)"""
    all_rows = []
    offset = 0
    p = dict(params or {})
    p["$limit"] = page_size

    while True:
        p["$offset"] = offset
        data = fetch_json(url, params=p)
        if not data:
            break
        all_rows.extend(data)
        print(f"    Fetched {len(all_rows)} rows...")
        if len(data) < page_size:
            break
        if len(all_rows) >= max_rows:
            print(f"    Hit max_rows cap ({max_rows:,}) — stopping pagination")
            break
        offset += page_size
        time.sleep(REQUEST_DELAY)

    return all_rows


def seg_id(coords):
    """Create a stable pseudo way_id from coordinates"""
    key = json.dumps(coords, sort_keys=True)
    return int(hashlib.md5(key.encode()).hexdigest()[:8], 16)


# =============================================================================
# OSM PARKING CONDITIONS (règles générales sur rue)
# =============================================================================

def parse_osm_time_interval(s):
    """
    Parse OSM opening_hours format -> (days, from_time, to_time)
    Exemples: 'Mo-Fr 08:00-18:00', 'Mo-Sa 09:00-21:00', 'Su 00:00-24:00'
    Retourne défaut [1..5] 08:00-18:00 si non parseable.
    """
    if not s:
        return [1, 2, 3, 4, 5], "08:00", "18:00"
    s = s.strip()
    DAY = {"Mo": 1, "Tu": 2, "We": 3, "Th": 4, "Fr": 5, "Sa": 6, "Su": 7}
    # Extract time range HH:MM-HH:MM
    tm = re.search(r'(\d{2}:\d{2})-(\d{2}:\d{2})', s)
    from_t = tm.group(1) if tm else "08:00"
    to_t   = tm.group(2) if tm else "18:00"
    # Extract day range e.g. "Mo-Fr", "Mo-Sa", "Su"
    dm = re.match(r'([A-Z][a-z])(?:-([A-Z][a-z]))?', s)
    if not dm:
        return [1, 2, 3, 4, 5], from_t, to_t
    d1 = DAY.get(dm.group(1), 1)
    d2 = DAY.get(dm.group(2), d1) if dm.group(2) else d1
    days = list(range(d1, d2 + 1))
    return (days if days else [1, 2, 3, 4, 5]), from_t, to_t


def parse_osm_maxstay(s):
    """
    Parse OSM maxstay '2 hours', '1 hour 30 minutes', '30 minutes', '1:30' -> int minutes.
    """
    if not s:
        return 120
    low = s.lower()
    h = re.search(r'(\d+)\s*hour', low)
    m = re.search(r'(\d+)\s*min', low)
    # Format HH:MM (e.g. '1:30')
    hm = re.match(r'^(\d+):(\d{2})$', s.strip())
    if hm:
        return int(hm.group(1)) * 60 + int(hm.group(2))
    total = (int(h.group(1)) * 60 if h else 0) + (int(m.group(1)) if m else 0)
    return total if total > 0 else 120


def fetch_osm_parking_conditions(bbox, city_label, default_rate=0.0, seen=None):
    """
    Requête Overpass : ways avec parking:condition:right/left = free|disc|ticket.
    Retourne des meter entries compatibles avec le format CityParkingService.

    Args:
        bbox        : (south, west, north, east)
        city_label  : pour les logs
        default_rate: taux $/h pour condition=ticket sans prix OSM (0=gratuit)
        seen        : set 'lon4,lat4' pour déduplication contre données existantes

    Format retourné : {"x":lon, "y":lat, "c":cents, "p":[{"d":days,"f":from,"t":to,"m":maxstay,"r":rate}]}
    """
    s, w, n, e = bbox
    query = f"""[out:json][timeout:120];
(
  way["parking:condition:right"~"^(free|disc|ticket)$"]({s},{w},{n},{e});
  way["parking:condition:left"~"^(free|disc|ticket)$"]({s},{w},{n},{e});
);
out center tags;
"""
    print(f"[{city_label}] OSM parking:condition ({s:.2f},{w:.2f},{n:.2f},{e:.2f})...")
    try:
        r = requests.post(
            "https://overpass-api.de/api/interpreter",
            data={"data": query}, headers=HEADERS, timeout=150
        )
        r.raise_for_status()
        elements = r.json().get("elements", [])
    except requests.RequestException as e:
        print(f"[{city_label}] OSM parking:condition error: {e}")
        return []

    print(f"[{city_label}] OSM: {len(elements)} ways with parking:condition")
    if seen is None:
        seen = set()

    meters = []
    for el in elements:
        center = el.get("center", {})
        lon = center.get("lon")
        lat = center.get("lat")
        if lon is None or lat is None:
            continue
        key = f"{lon:.4f},{lat:.4f}"
        if key in seen:
            continue
        seen.add(key)

        tags = el.get("tags", {})
        added = False
        # Priorité right, puis left
        for side in ("right", "left"):
            cond = tags.get(f"parking:condition:{side}", "")
            if cond not in ("free", "disc", "ticket"):
                continue

            maxstay  = parse_osm_maxstay(
                tags.get(f"parking:condition:{side}:maxstay", ""))
            interval = tags.get(
                f"parking:condition:{side}:time_interval", "")
            days, from_t, to_t = parse_osm_time_interval(interval)

            rate = default_rate if cond != "ticket" else default_rate
            c_cents = int(rate * 100)

            meters.append({
                "x": float(lon), "y": float(lat),
                "c": c_cents,
                "p": [{"d": days, "f": from_t, "t": to_t,
                       "m": maxstay, "r": rate}]
            })
            added = True
            break  # une entrée par way (côté le plus informatif)

    print(f"[{city_label}] OSM parking:condition: {len(meters)} new entries")
    return meters


def fetch_osm_parking_conditions_tiled(bbox, city_label, default_rate=0.0, seen=None):
    """
    Même chose que fetch_osm_parking_conditions mais découpe la bbox en 4 quadrants.
    Utiliser pour les grandes villes (bbox > 0.4° de côté) pour éviter les timeouts.
    """
    s, w, n, e = bbox
    mid_lat = (s + n) / 2
    mid_lon = (w + e) / 2
    quadrants = [
        (s,       w,       mid_lat, mid_lon),
        (s,       mid_lon, mid_lat, e      ),
        (mid_lat, w,       n,       mid_lon),
        (mid_lat, mid_lon, n,       e      ),
    ]
    if seen is None:
        seen = set()
    all_meters = []
    for q in quadrants:
        all_meters.extend(
            fetch_osm_parking_conditions(q, city_label, default_rate, seen))
        time.sleep(REQUEST_DELAY)
    return all_meters


# =============================================================================
# SEATTLE
# =============================================================================

def _min_to_hhmm(minutes):
    """Convert minutes-from-midnight int to 'HH:MM' string."""
    try:
        m = int(float(minutes))
        return f"{m // 60:02d}:{m % 60:02d}"
    except (TypeError, ValueError):
        return "08:00"


def _parse_seattle_time_str(s):
    """Parse Seattle time string like '08AM', '06PM' → 'HH:MM'."""
    if not s:
        return None
    s = str(s).strip().upper()
    m = re.match(r'(\d{1,2})(AM|PM)', s)
    if not m:
        return None
    h = int(m.group(1))
    if m.group(2) == "PM" and h != 12:
        h += 12
    if m.group(2) == "AM" and h == 12:
        h = 0
    return f"{h:02d}:00"


def build_seattle():
    """
    Source: ArcGIS Hub — SDOT Blockface dataset (b35fb25c8c93425980705474b5e82815_1)
    47,860 blockfaces covering all Seattle streets.
    Categories used: Paid Parking, Time Limited Parking, Restricted Parking Zone
    Fields: WKD_RATE1-3/START1-3/END1-3, SAT_RATE1-3, PARKING_TIME_LIMIT,
            START_TIME_WKD, END_TIME_WKD, START_TIME_SAT, END_TIME_SAT
    Geometry: MultiLineString → midpoint
    """
    print("\n[SEATTLE] Building from SDOT Blockface GeoJSON (81 MB)...")

    BLOCKFACE_URL = (
        "https://opendata.arcgis.com/api/v3/datasets/"
        "b35fb25c8c93425980705474b5e82815_1/downloads/data"
        "?format=geojson&spatialRefId=4326"
    )

    try:
        r = requests.get(BLOCKFACE_URL, headers=HEADERS, timeout=180)
        r.raise_for_status()
        data = r.json()
    except requests.RequestException as e:
        print(f"[SEATTLE] Blockface download failed: {e} — trying occupancy fallback")
        return _build_seattle_occupancy_fallback()

    features = data.get("features", [])
    print(f"[SEATTLE] {len(features):,} blockface features downloaded")

    USEFUL_CATS = {"Paid Parking", "Time Limited Parking", "Restricted Parking Zone"}

    meters = []
    seen = set()

    for feat in features:
        props = feat.get("properties", {})
        geom  = feat.get("geometry", {})
        cat = props.get("PARKING_CATEGORY", "")

        if cat not in USEFUL_CATS:
            continue
        if not geom:
            continue
        if not (props.get("PARKING_SPACES") or props.get("TL_SPACES") or
                props.get("PAID_SPACES") or props.get("RPZ_SPACES")):
            continue

        # Midpoint of MultiLineString
        coords_list = geom.get("coordinates", [])
        all_pts = []
        for line in coords_list:
            all_pts.extend(line)
        if not all_pts:
            continue
        mid = all_pts[len(all_pts) // 2]
        try:
            lon, lat = float(mid[0]), float(mid[1])
        except (IndexError, TypeError, ValueError):
            continue

        key = f"{lon:.4f},{lat:.4f}"
        if key in seen:
            continue
        seen.add(key)

        max_stay = int(float(props.get("PARKING_TIME_LIMIT") or 120))

        periods = []
        if cat == "Paid Parking":
            # Weekday — up to 3 rate tiers
            for i in (1, 2, 3):
                rate  = props.get(f"WKD_RATE{i}")  or 0
                start = props.get(f"WKD_START{i}") or 0
                end   = props.get(f"WKD_END{i}")   or 0
                if float(rate) > 0 and int(float(end)) > int(float(start)):
                    periods.append({
                        "d": [1, 2, 3, 4, 5],
                        "f": _min_to_hhmm(start),
                        "t": _min_to_hhmm(int(float(end)) + 1),
                        "m": max_stay,
                        "r": float(rate)
                    })
            # Saturday — up to 3 rate tiers
            for i in (1, 2, 3):
                rate  = props.get(f"SAT_RATE{i}")  or 0
                start = props.get(f"SAT_START{i}") or 0
                end   = props.get(f"SAT_END{i}")   or 0
                if float(rate) > 0 and int(float(end)) > int(float(start)):
                    periods.append({
                        "d": [6],
                        "f": _min_to_hhmm(start),
                        "t": _min_to_hhmm(int(float(end)) + 1),
                        "m": max_stay,
                        "r": float(rate)
                    })

        elif cat in ("Time Limited Parking", "Restricted Parking Zone"):
            f_wkd = _parse_seattle_time_str(props.get("START_TIME_WKD")) or "08:00"
            t_wkd = _parse_seattle_time_str(props.get("END_TIME_WKD"))   or "18:00"
            f_sat = _parse_seattle_time_str(props.get("START_TIME_SAT"))
            t_sat = _parse_seattle_time_str(props.get("END_TIME_SAT"))
            rate  = 0.0  # free / permit zone
            periods.append({"d": [1,2,3,4,5], "f": f_wkd, "t": t_wkd, "m": max_stay, "r": rate})
            if f_sat and t_sat:
                periods.append({"d": [6], "f": f_sat, "t": t_sat, "m": max_stay, "r": rate})

        if not periods:
            # Fallback: generic daytime rule
            periods = [{"d": [1,2,3,4,5,6], "f": "08:00", "t": "18:00",
                        "m": max_stay, "r": 0.0}]

        c_cents = int(float(periods[0].get("r", 0) or 0) * 100)
        meters.append({"x": lon, "y": lat, "c": c_cents, "p": periods})

    print(f"[SEATTLE] Built {len(meters):,} meters from blockface dataset")
    osm_seen = set(f"{m['x']:.4f},{m['y']:.4f}" for m in meters)
    osm_extra = fetch_osm_parking_conditions(
        (47.49, -122.46, 47.74, -122.22), "SEATTLE", default_rate=0.0, seen=osm_seen)
    meters.extend(osm_extra)
    print(f"[SEATTLE] Total after OSM: {len(meters):,} meters")
    return {"v": 1, "meters": meters, "alternating": [], "cleaning": []}


def _build_seattle_occupancy_fallback():
    """Fallback: original paid occupancy dataset approach."""
    print("[SEATTLE] Using occupancy fallback (100k random rows)...")
    URL = "https://data.seattle.gov/resource/rke9-rsvs.json"
    try:
        r = requests.get(URL, params={
            "$select": "sourceelementkey,location,parkingtimelimitcategory,paidparkingrate",
            "$where": "location IS NOT NULL", "$limit": 100000,
        }, headers=HEADERS, timeout=120)
        rows = r.json()
    except requests.RequestException:
        return {"v": 1, "meters": [], "alternating": [], "cleaning": []}
    meters = []
    seen = set()
    for row in rows:
        ek = row.get("sourceelementkey", "")
        if ek in seen: continue
        loc = row.get("location", {})
        coords = loc.get("coordinates") if isinstance(loc, dict) else None
        if not coords or len(coords) < 2: continue
        seen.add(ek)
        lon, lat = float(coords[0]), float(coords[1])
        try: max_stay = int(row.get("parkingtimelimitcategory", 120))
        except: max_stay = 120
        try:
            rs = row.get("paidparkingrate", "")
            rate = float(str(rs).replace("$","").strip()) if rs else 2.50
        except: rate = 2.50
        meters.append({"x": lon, "y": lat, "c": int(rate * 100),
            "p": [{"d": [1,2,3,4,5,6], "f": "08:00", "t": "20:00",
                   "m": max_stay, "r": rate}]})
    print(f"[SEATTLE] Fallback: {len(meters)} meters")
    return {"v": 1, "meters": meters, "alternating": [], "cleaning": []}


# =============================================================================
# SAN FRANCISCO
# =============================================================================

def build_sf():
    """
    Source: data.sfgov.org
    Dataset: Parking Meters (8vzz-qzz9)
    Fields: longitude, latitude, street_name, meter_type, active_meter_flag
    """
    print("\n[SF] Building...")

    URL = "https://data.sfgov.org/resource/8vzz-qzz9.json"

    rows = fetch_all_pages(URL, params={
        "$where": "active_meter_flag='M' AND longitude IS NOT NULL AND latitude IS NOT NULL",
        "$select": "post_id,longitude,latitude,street_name,street_num,meter_type,cap_color,blockface_id,analysis_neighborhood",
        "$limit": 50000
    })

    if not rows:
        print("[SF] No data fetched - using empty structure")
        return {"v": 1, "meters": [], "alternating": [], "cleaning": []}

    meters = []
    for row in rows:
        try:
            lon = float(row["longitude"])
            lat = float(row["latitude"])
        except (KeyError, ValueError, TypeError):
            continue

        # Grey cap = 2h, Green cap = 30min, Black = no time limit
        cap = row.get("cap_color", "Grey").lower()
        if "green" in cap:
            max_stay = 30
        elif "yellow" in cap:
            max_stay = 15
        else:
            max_stay = 120  # Default: 2h

        # Standard SF metered hours: 9am-6pm Mon-Sat — $2.25/h = 225 cents
        meter = {
            "x": lon,
            "y": lat,
            "c": 225,
            "p": [
                {
                    "d": [1, 2, 3, 4, 5, 6],         # Mon-Sat
                    "f": "09:00",
                    "t": "18:00",
                    "m": max_stay,
                    "r": 2.25
                }
            ]
        }
        meters.append(meter)

    print(f"[SF] Built {len(meters)} meters")
    osm_seen = set(f"{m['x']:.4f},{m['y']:.4f}" for m in meters)
    osm_extra = fetch_osm_parking_conditions(
        (37.63, -122.52, 37.83, -121.98), "SF", default_rate=2.25, seen=osm_seen)
    meters.extend(osm_extra)
    print(f"[SF] Total after OSM: {len(meters)} meters")
    return {"v": 1, "meters": meters, "alternating": [], "cleaning": []}


# =============================================================================
# NEW YORK CITY
# =============================================================================

def parse_nyc_meter_hours(meter_hours_str):
    """
    Parse NYC meter_hours string like '2HR Pas Mon-Sat 0800-1900'
    Returns: (max_stay_minutes, days_list, from_time, to_time)

    Examples:
      '2HR Pas Mon-Sat 0800-1900'
      '1HR Pas Mon-Fri 0800-1800'
      '30 Min Mon-Sun 0800-2200'
      '4HR Pas Mon-Sat 0800-1800'
    """
    if not meter_hours_str:
        return 120, [1, 2, 3, 4, 5], "08:00", "19:00"

    s = meter_hours_str.strip().upper()

    # Parse max stay
    max_stay = 120  # default 2h
    if "30 MIN" in s or "30MIN" in s:
        max_stay = 30
    elif "1HR" in s or "1 HR" in s:
        max_stay = 60
    elif "2HR" in s or "2 HR" in s:
        max_stay = 120
    elif "3HR" in s or "3 HR" in s:
        max_stay = 180
    elif "4HR" in s or "4 HR" in s:
        max_stay = 240

    # Parse days
    day_map = {"MON": 1, "TUE": 2, "WED": 3, "THU": 4, "FRI": 5, "SAT": 6, "SUN": 7}
    days = [1, 2, 3, 4, 5]  # default Mon-Fri
    if "MON-SAT" in s:
        days = [1, 2, 3, 4, 5, 6]
    elif "MON-SUN" in s or "7 DAYS" in s:
        days = [1, 2, 3, 4, 5, 6, 7]
    elif "MON-FRI" in s:
        days = [1, 2, 3, 4, 5]
    elif "SAT-SUN" in s:
        days = [6, 7]

    # Parse times (e.g. "0800-1900")
    from_time = "08:00"
    to_time = "19:00"
    import re
    time_match = re.search(r'(\d{4})-(\d{4})', s)
    if time_match:
        raw_from = time_match.group(1)
        raw_to = time_match.group(2)
        from_time = f"{raw_from[:2]}:{raw_from[2:]}"
        to_time = f"{raw_to[:2]}:{raw_to[2:]}"

    return max_stay, days, from_time, to_time


def nysp_to_wgs84(x, y):
    """Convert NY State Plane (EPSG:2263, feet) to WGS84 lon/lat."""
    if not HAS_PYPROJ:
        return None, None
    try:
        lon, lat = _nysp_to_wgs84.transform(float(x), float(y))
        if -74.5 <= lon <= -73.5 and 40.4 <= lat <= 40.95:
            return lon, lat
        return None, None
    except Exception:
        return None, None


def parse_nyc_cleaning_sign(description):
    """
    Parse NYC sanitation sign description into (days_list, from_time, to_time).
    Examples:
      'NO PARKING (SANITATION BROOM SYMBOL) TUESDAY FRIDAY 11:30AM-1PM'
      'NO PARKING (SANITATION BROOM SYMBOL) MONDAY THURSDAY 8AM-9:30AM'
      'NO PARKING (SANITATION BROOM SYMBOL) WEDNESDAY 11:30AM-1PM'
    """
    DAY_MAP = {
        "MONDAY": 1, "TUESDAY": 2, "WEDNESDAY": 3,
        "THURSDAY": 4, "FRIDAY": 5, "SATURDAY": 6, "SUNDAY": 7,
        "MON": 1, "TUE": 2, "WED": 3, "THU": 4, "FRI": 5, "SAT": 6, "SUN": 7
    }
    s = description.upper()

    # Extract day names
    days = []
    for day_name, day_num in DAY_MAP.items():
        if day_name in s:
            days.append(day_num)
    days = sorted(set(days))
    if not days:
        days = [1, 2, 3, 4, 5]

    # Extract time range: "11:30AM-1PM", "8AM-9:30AM", "9AM-10:30AM"
    tm = re.search(r'(\d{1,2}(?::\d{2})?(?:AM|PM)?)-(\d{1,2}(?::\d{2})?(?:AM|PM)?)', s)
    if not tm:
        return days, "08:00", "09:30"

    def to24(t):
        t = t.strip()
        pm = "PM" in t; am = "AM" in t
        t = t.replace("AM", "").replace("PM", "").strip()
        if ":" in t:
            h, m = t.split(":")
        else:
            h, m = t, "00"
        h = int(h); m = int(m)
        if pm and h != 12: h += 12
        if am and h == 12: h = 0
        return f"{h:02d}:{m:02d}"

    return days, to24(tm.group(1)), to24(tm.group(2))


def fetch_nyc_signs_paged(sign_where, select_fields, label):
    """Paginate through NYC sign dataset (nfid-uabd)."""
    URL = "https://data.cityofnewyork.us/resource/nfid-uabd.json"
    all_rows = []
    offset = 0
    page_size = 10000
    while True:
        r = None
        for attempt in range(3):
            try:
                r = requests.get(URL, params={
                    "$where": sign_where,
                    "$select": select_fields,
                    "$limit": page_size,
                    "$offset": offset,
                }, headers=HEADERS, timeout=60)
                r.raise_for_status()
                break
            except requests.RequestException as e:
                print(f"    [retry {attempt+1}/3] {e}")
                time.sleep(2 ** attempt)
        if r is None:
            break
        rows = r.json()
        if not rows:
            break
        all_rows.extend(rows)
        print(f"    [{label}] fetched {len(all_rows)} rows...")
        if len(rows) < page_size:
            break
        offset += page_size
        time.sleep(REQUEST_DELAY)
    return all_rows


def build_nyc():
    """
    Source: NYC Open Data — Parking Regulation Locations and Signs (nfid-uabd)
    Strategy:
      1. PS-9A (Pay-by-cell)  → 18,783 paid meter locations
      2. SANITATION signs      → 186,355 street cleaning rules
    Coordinates: NY State Plane EPSG:2263 → WGS84 via pyproj
    """
    print("\n[NYC] Building...")

    if not HAS_PYPROJ:
        print("[NYC] pyproj required for sign data — falling back to muni meter dataset")
        return _build_nyc_fallback()

    meters = []
    cleaning = []

    # ── 1. Pay-by-cell meter signs (PS-9A) ────────────────────────────────────
    print("[NYC] Fetching PS-9A pay-by-cell signs...")
    sign_rows = fetch_nyc_signs_paged(
        sign_where="record_type='Current' AND sign_code='PS-9A' AND sign_x_coord IS NOT NULL",
        select_fields="sign_x_coord,sign_y_coord,on_street,borough",
        label="PS-9A"
    )
    seen_m = set()
    for row in sign_rows:
        lon, lat = nysp_to_wgs84(row.get("sign_x_coord"), row.get("sign_y_coord"))
        if lon is None:
            continue
        key = f"{lon:.4f},{lat:.4f}"
        if key in seen_m:
            continue
        seen_m.add(key)
        meters.append({
            "x": lon, "y": lat, "c": 250,   # $2.50/h = 250 cents
            "p": [{"d": [1, 2, 3, 4, 5, 6], "f": "08:00", "t": "19:00", "m": 120, "r": 2.50}]
        })
    print(f"[NYC] {len(meters)} unique pay-by-cell meters")

    # ── 2. Street cleaning / sanitation signs ─────────────────────────────────
    print("[NYC] Fetching sanitation/cleaning signs...")
    san_rows = fetch_nyc_signs_paged(
        sign_where="record_type='Current' AND sign_description LIKE '%SANITATION%' AND sign_x_coord IS NOT NULL",
        select_fields="sign_x_coord,sign_y_coord,sign_description,on_street,side_of_street",
        label="SANITATION"
    )
    seen_c = set()
    for row in san_rows:
        lon, lat = nysp_to_wgs84(row.get("sign_x_coord"), row.get("sign_y_coord"))
        if lon is None:
            continue
        key = f"{lon:.4f},{lat:.4f}"
        if key in seen_c:
            continue
        seen_c.add(key)

        days, from_t, to_t = parse_nyc_cleaning_sign(row.get("sign_description", ""))
        way_id = int(hashlib.md5(key.encode()).hexdigest()[:8], 16)
        cleaning.append({
            "n": row.get("on_street", ""),
            "w": way_id,
            "z": "",
            "s": row.get("side_of_street", ""),
            "c": [[lon, lat]],
            "r": [{"d": days, "f": from_t, "t": to_t}]
        })
    print(f"[NYC] {len(cleaning)} unique cleaning sign locations")

    print(f"[NYC] Total: {len(meters)} meters + {len(cleaning)} cleaning entries")
    osm_seen = set(f"{m['x']:.4f},{m['y']:.4f}" for m in meters)
    osm_extra = fetch_osm_parking_conditions_tiled(
        (40.50, -74.26, 40.93, -73.70), "NYC", default_rate=2.50, seen=osm_seen)
    meters.extend(osm_extra)
    print(f"[NYC] Total after OSM: {len(meters)} meters")
    return {"v": 1, "meters": meters, "alternating": [], "cleaning": cleaning}


def _build_nyc_fallback():
    """NYC fallback using muni meter dataset (no pyproj)."""
    URL = "https://data.cityofnewyork.us/resource/693u-uax6.json"
    rows = fetch_all_pages(URL, params={
        "$where": "status='Active' AND lat IS NOT NULL AND long IS NOT NULL",
        "$select": "lat,long,meter_hours",
        "$limit": 50000
    })
    meters = []
    seen = set()
    for row in rows:
        try:
            lat = float(row["lat"]); lon = float(row["long"])
        except (KeyError, ValueError, TypeError):
            continue
        key = f"{lon:.4f},{lat:.4f}"
        if key in seen: continue
        seen.add(key)
        max_stay, days, ft, tt = parse_nyc_meter_hours(row.get("meter_hours", ""))
        meters.append({"x": lon, "y": lat, "c": 250,   # $2.50/h = 250 cents
                        "p": [{"d": days, "f": ft, "t": tt, "m": max_stay, "r": 2.50}]})
    print(f"[NYC] Fallback: {len(meters)} meters")
    return {"v": 1, "meters": meters, "alternating": [], "cleaning": []}


# =============================================================================
# TORONTO
# =============================================================================

def fetch_osm_meters(area_name, bbox, city_label):
    """
    Fallback: fetch parking meters from OpenStreetMap via Overpass API.
    bbox = (south, west, north, east)
    Returns list of meter dicts in our format.
    """
    overpass_url = "https://overpass-api.de/api/interpreter"
    s, w, n, e = bbox
    query = f"""
[out:json][timeout:60];
(
  node["amenity"="parking_meter"]({s},{w},{n},{e});
);
out body;
"""
    print(f"[{city_label}] Querying OSM Overpass for parking meters in {area_name}...")
    try:
        r = requests.post(overpass_url, data={"data": query}, headers=HEADERS, timeout=90)
        r.raise_for_status()
        data = r.json()
    except requests.RequestException as e:
        print(f"[{city_label}] OSM Overpass error: {e}")
        return []

    elements = data.get("elements", [])
    print(f"[{city_label}] OSM returned {len(elements)} meter nodes")

    meters = []
    for el in elements:
        lat = el.get("lat")
        lon = el.get("lon")
        if lat is None or lon is None:
            continue
        tags = el.get("tags", {})

        # Parse max stay from OSM tags
        max_stay = 120
        ms_tag = tags.get("maxstay", "")
        if ms_tag:
            ms_upper = ms_tag.upper()
            if "30" in ms_upper and "MIN" in ms_upper:
                max_stay = 30
            elif "1" in ms_upper and "HOUR" in ms_upper:
                max_stay = 60
            elif "2" in ms_upper and "HOUR" in ms_upper:
                max_stay = 120
            elif "3" in ms_upper and "HOUR" in ms_upper:
                max_stay = 180
            elif "4" in ms_upper and "HOUR" in ms_upper:
                max_stay = 240

        # Parse fee / rate
        fee = tags.get("charge", tags.get("fee:amount", ""))
        try:
            rate = float(str(fee).replace("$", "").replace("CAD", "").strip())
        except (ValueError, TypeError):
            rate = 3.00  # Toronto default

        meter = {
            "x": float(lon),
            "y": float(lat),
            "c": int(rate * 100),   # cents: 3.00 → 300
            "p": [
                {
                    "d": [1, 2, 3, 4, 5, 6],
                    "f": "08:00",
                    "t": "21:00",
                    "m": max_stay,
                    "r": rate
                }
            ]
        }
        meters.append(meter)

    return meters


def build_toronto():
    """
    Source 1: Toronto Topographic Mapping - Parking Lots (19,445 features, streamed)
              CKAN resource f6eb3a47: physical parking areas across entire city.
              Used as proxy meter locations (these are real paid parking areas).
    Source 2: Toronto Open Data — Green P Parking 2019 (carpark locations)
    Toronto bbox: (43.58, -79.64, 43.86, -79.12)
    """
    print("\n[TORONTO] Building...")

    meters = []
    seen = set()

    def _add_meter(lon, lat, rate=2.50):
        if not (-79.65 <= lon <= -79.00 and 43.55 <= lat <= 44.00):
            return
        key = f"{lon:.4f},{lat:.4f}"
        if key in seen:
            return
        seen.add(key)
        meters.append({
            "x": round(float(lon), 6),
            "y": round(float(lat), 6),
            "c": int(rate * 100),   # cents: 2.50 → 250
            "p": [{"d": [1, 2, 3, 4, 5, 6], "f": "08:00", "t": "21:00", "m": 120, "r": rate}]
        })

    # --- Source 1: Topographic Mapping - Parking Lots (streaming, 155 MB GeoJSON) ---
    PARKING_LOT_URL = (
        "https://ckan0.cf.opendata.inter.prod-toronto.ca/dataset/"
        "bb408f36-6824-4158-8a12-d4efe6465959/resource/"
        "f6eb3a47-b6e3-4b07-9e88-ac1a2d9b30ba/download/Parking_Lot_-_4326.geojson"
    )
    MAX_LOTS = 12000   # cap to keep output file ~1.2 MB
    print("[TORONTO] Streaming Topographic Parking Lots GeoJSON (155 MB)...")
    try:
        import ijson
        with requests.get(PARKING_LOT_URL, headers=HEADERS, timeout=180, stream=True) as r:
            r.raise_for_status()
            for feat in ijson.items(r.raw, "features.item"):
                geom = feat.get("geometry") or {}
                gtype = geom.get("type", "")
                coords = geom.get("coordinates", [])
                pts = []
                if gtype == "Polygon" and coords:
                    pts = coords[0]
                elif gtype == "MultiPolygon" and coords:
                    pts = coords[0][0]
                if not pts:
                    continue
                try:
                    lon_c = sum(float(p[0]) for p in pts) / len(pts)
                    lat_c = sum(float(p[1]) for p in pts) / len(pts)
                    _add_meter(lon_c, lat_c)
                except (TypeError, ZeroDivisionError, IndexError):
                    continue
                if len(meters) >= MAX_LOTS:
                    break
        print(f"[TORONTO] Streaming complete: {len(meters)} parking lot centroids")
    except ImportError:
        print("[TORONTO] ijson not installed — skipping parking lots (run: pip install ijson)")
    except Exception as e:
        print(f"[TORONTO] Parking lots error: {e}")
    time.sleep(REQUEST_DELAY)

    # --- Source 2: Green P Parking 2019 (carparks) ---
    GREEN_P_URL = (
        "https://ckan0.cf.opendata.inter.prod-toronto.ca/dataset/"
        "b66466c3-69c8-4825-9c8b-04b270069193/resource/"
        "8549d588-30b0-482e-b872-b21beefdda22/download/Green_P_Parking_2019.json"
    )
    print("[TORONTO] Fetching Green P Parking data...")
    try:
        r = requests.get(GREEN_P_URL, headers=HEADERS, timeout=30)
        r.raise_for_status()
        gp_data = r.json()
        if gp_data and "carparks" in gp_data:
            for cp in gp_data["carparks"]:
                try:
                    _add_meter(float(cp.get("lng", 0)), float(cp.get("lat", 0)), 3.00)
                except (ValueError, TypeError):
                    continue
        print(f"[TORONTO] Green P added → total {len(meters)}")
    except Exception as e:
        print(f"[TORONTO] Green P failed: {e}")
    time.sleep(REQUEST_DELAY)

    # ── Source 3: Toronto On-Street Permit Parking Zones (CKAN) ──────────────
    print("[TORONTO] Fetching on-street permit zones (CKAN)...")
    try:
        ckan_url = "https://ckan0.cf.opendata.inter.prod-toronto.ca/api/3/action/datastore_search"
        ckan_params = {
            "resource_id": "9b1a3a7b-b732-49cb-a2d7-c31f4fb11a06",
            "limit": 5000,
        }
        tor_seen = set(f"{m['x']:.4f},{m['y']:.4f}" for m in meters)
        permit_added = 0
        offset = 0
        while True:
            ckan_params["offset"] = offset
            ckan_data = fetch_json(ckan_url, params=ckan_params)
            if not ckan_data or not ckan_data.get("success"):
                break
            records = ckan_data.get("result", {}).get("records", [])
            if not records:
                break
            for rec in records:
                # Geometry may be GeoJSON string or dict
                shape = rec.get("geometry") or rec.get("Shape") or rec.get("shape") or ""
                if isinstance(shape, str):
                    try:
                        shape = json.loads(shape)
                    except (json.JSONDecodeError, ValueError):
                        shape = None
                lon_t, lat_t = _socrata_geom_centroid(shape) if isinstance(shape, dict) else (None, None)
                # Fallback: direct lat/lon fields
                if lon_t is None:
                    try:
                        lat_t = float(rec.get("latitude") or rec.get("Latitude") or 0)
                        lon_t = float(rec.get("longitude") or rec.get("Longitude") or 0)
                        if lat_t == 0 and lon_t == 0:
                            lon_t = lat_t = None
                    except (TypeError, ValueError):
                        lon_t = lat_t = None
                if lon_t is None:
                    continue
                if not (43.5 <= lat_t <= 44.0 and -79.7 <= lon_t <= -79.0):
                    continue
                key = f"{lon_t:.4f},{lat_t:.4f}"
                if key in tor_seen:
                    continue
                tor_seen.add(key)
                meters.append({
                    "x": float(lon_t), "y": float(lat_t),
                    "c": 0,
                    "p": [{"d": [1,2,3,4,5,6,7], "f": "00:00", "t": "23:59",
                           "m": 0, "r": 0}]
                })
                permit_added += 1
            if len(records) < ckan_params["limit"]:
                break
            offset += ckan_params["limit"]
            time.sleep(REQUEST_DELAY)
        print(f"[TORONTO] On-street permit zones: {permit_added} added")
    except Exception as e:
        print(f"[TORONTO] Permit zones error: {e}")
    time.sleep(REQUEST_DELAY)

    print(f"[TORONTO] Built {len(meters)} meters total")
    osm_seen = set(f"{m['x']:.4f},{m['y']:.4f}" for m in meters)
    osm_extra = fetch_osm_parking_conditions_tiled(
        (43.58, -79.64, 43.86, -79.12), "TORONTO", default_rate=0.0, seen=osm_seen)
    meters.extend(osm_extra)
    print(f"[TORONTO] Total after OSM: {len(meters)} meters")
    return {"v": 1, "meters": meters, "alternating": [], "cleaning": []}


# =============================================================================
# BOSTON
# =============================================================================

def build_boston():
    """
    Source 1: data.boston.gov — Parking Meters GeoJSON
    URL: https://data.boston.gov/dataset/144e2003-ca70-492b-874e-76cc7355e7e3/resource/
         9314c461-69c3-452e-82dc-9da9dee486f8/download/parking_meters.geojson
    Source 2: OSM Overpass fallback
    Boston bbox: (42.32, -71.10, 42.40, -71.02)
    """
    print("\n[BOSTON] Building...")

    meters = []

    # --- Source 1: Boston Open Data GeoJSON ---
    GEOJSON_URL = (
        "https://data.boston.gov/dataset/144e2003-ca70-492b-874e-76cc7455e7e3"
        "/resource/9314c461-69c3-452e-82dc-9da9dee486f8/download/parking_meters.geojson"
    )

    print("[BOSTON] Fetching GeoJSON from data.boston.gov...")
    try:
        r = requests.get(GEOJSON_URL, headers=HEADERS, timeout=60)
        r.raise_for_status()
        data = r.json()
    except requests.RequestException as e:
        print(f"[BOSTON] GeoJSON fetch failed: {e}")
        data = None

    if data and data.get("type") == "FeatureCollection":
        features = data.get("features", [])
        print(f"[BOSTON] GeoJSON has {len(features)} features")

        import re as _re

        for feat in features:
            geom = feat.get("geometry", {})
            props = feat.get("properties", {})

            if not geom or not props:
                continue

            # Skip inactive meters
            if props.get("METER_STATE", "ACTIVE") not in ("ACTIVE", None, ""):
                continue

            # Prefer explicit lon/lat fields (more precise than geometry)
            try:
                lon = float(props.get("LONGITUDE") or props.get("POINT_X") or
                            geom.get("coordinates", [None])[0])
                lat = float(props.get("LATITUDE") or props.get("POINT_Y") or
                            geom.get("coordinates", [None, None])[1])
            except (TypeError, ValueError, IndexError):
                continue

            if not (-90 <= lat <= 90 and -180 <= lon <= 180):
                continue

            # Parse PAY_POLICY: "08:00AM-08:00PM MON-SAT $0.25 120"
            max_stay = 120
            from_t = "08:00"
            to_t = "20:00"
            days = [1, 2, 3, 4, 5, 6]

            pay_policy = props.get("PAY_POLICY", "") or ""
            # Max stay: last integer in the string (minutes)
            ms_match = _re.findall(r'\b(\d+)\s*$', pay_policy.strip())
            if ms_match:
                try:
                    max_stay = int(ms_match[-1])
                except ValueError:
                    max_stay = 120

            # Days
            if "MON-SAT" in pay_policy.upper():
                days = [1, 2, 3, 4, 5, 6]
            elif "MON-SUN" in pay_policy.upper():
                days = [1, 2, 3, 4, 5, 6, 7]
            elif "MON-FRI" in pay_policy.upper():
                days = [1, 2, 3, 4, 5]

            # Time: "08:00AM-08:00PM"
            tm = _re.search(r'(\d{1,2}:\d{2}(?:AM|PM)?)-(\d{1,2}:\d{2}(?:AM|PM)?)',
                            pay_policy, _re.IGNORECASE)
            if tm:
                def to24(t):
                    t = t.strip().upper()
                    pm = "PM" in t
                    am = "AM" in t
                    t = t.replace("AM","").replace("PM","").strip()
                    h, m = t.split(":")
                    h = int(h)
                    if pm and h != 12:
                        h += 12
                    if am and h == 12:
                        h = 0
                    return f"{h:02d}:{m}"
                from_t = to24(tm.group(1))
                to_t = to24(tm.group(2))

            # Rate: BASE_RATE field (per-increment, multiply by 4 to get $/hr approx)
            try:
                base = float(props.get("BASE_RATE", 0) or 0)
                rate = round(base * 4, 2) if base > 0 else 1.25
                if rate > 10 or rate <= 0:
                    rate = 1.25
            except (ValueError, TypeError):
                rate = 1.25

            meter = {
                "x": lon,
                "y": lat,
                "c": int(rate * 100),   # cents: 1.25 → 125
                "p": [{"d": days, "f": from_t, "t": to_t, "m": max_stay, "r": rate}]
            }
            meters.append(meter)

        print(f"[BOSTON] Parsed {len(meters)} meters from GeoJSON")
    else:
        print("[BOSTON] GeoJSON fetch failed or wrong format")

    # --- Source 2: Try Socrata API as alternate ---
    if len(meters) < 100:
        print("[BOSTON] Trying Socrata API fallback...")
        socrata_ids = ["ijbj-pftk", "wuzs-p96q", "mdv5-sxmd"]
        for sid in socrata_ids:
            url = f"https://data.boston.gov/resource/{sid}.json"
            rows = fetch_json(url, params={"$limit": 5})
            if rows and isinstance(rows, list) and len(rows) > 0:
                print(f"[BOSTON] Socrata {sid} works! Fields: {list(rows[0].keys())}")
                all_rows = fetch_all_pages(url, params={"$limit": 50000})
                for row in all_rows:
                    # Try common lat/lon field names
                    lat, lon = None, None
                    for lk in ["lat", "latitude", "y", "y_coord"]:
                        if lk in row:
                            try:
                                lat = float(row[lk])
                                break
                            except (ValueError, TypeError):
                                pass
                    for lk in ["lon", "lng", "longitude", "x", "x_coord"]:
                        if lk in row:
                            try:
                                lon = float(row[lk])
                                break
                            except (ValueError, TypeError):
                                pass
                    # Also try location dict
                    if lat is None and "location" in row:
                        loc = row["location"]
                        if isinstance(loc, dict) and "coordinates" in loc:
                            try:
                                lon, lat = float(loc["coordinates"][0]), float(loc["coordinates"][1])
                            except (IndexError, ValueError, TypeError):
                                pass

                    if lat is None or lon is None:
                        continue
                    if not (-90 <= lat <= 90 and -180 <= lon <= 180):
                        continue

                    meter = {
                        "x": lon,
                        "y": lat,
                        "c": 125,   # $1.25/h = 125 cents
                        "p": [{"d": [1, 2, 3, 4, 5, 6], "f": "08:00", "t": "20:00", "m": 120, "r": 1.25}]
                    }
                    meters.append(meter)
                if meters:
                    print(f"[BOSTON] Socrata {sid}: {len(meters)} meters")
                    break
            time.sleep(REQUEST_DELAY)

    # --- Source 3: OSM fallback ---
    if len(meters) < 100:
        print("[BOSTON] Falling back to OSM Overpass...")
        osm_meters = fetch_osm_meters("Boston", (42.32, -71.10, 42.40, -71.02), "BOSTON")
        meters.extend(osm_meters)

    # Deduplicate
    seen = set()
    deduped = []
    for m in meters:
        key = f"{m['x']:.4f},{m['y']:.4f}"
        if key not in seen:
            seen.add(key)
            deduped.append(m)

    print(f"[BOSTON] Built {len(deduped)} meters total")
    osm_seen = set(f"{m['x']:.4f},{m['y']:.4f}" for m in deduped)
    osm_extra = fetch_osm_parking_conditions(
        (42.30, -71.18, 42.42, -70.99), "BOSTON", default_rate=1.25, seen=osm_seen)
    deduped.extend(osm_extra)
    print(f"[BOSTON] Total after OSM: {len(deduped)} meters")
    return {"v": 1, "meters": deduped, "alternating": [], "cleaning": []}


# =============================================================================
# LOS ANGELES
# =============================================================================

def parse_la_timelimit(tl_str):
    """Parse LA time limit string e.g. '2HR', '30 MIN', '1HR 30MIN'."""
    if not tl_str:
        return 120
    s = str(tl_str).upper().strip()
    total = 0
    m = re.findall(r'(\d+)\s*HR', s)
    if m:
        total += int(m[0]) * 60
    m2 = re.findall(r'(\d+)\s*MIN', s)
    if m2:
        total += int(m2[0])
    return total if total > 0 else 120


def build_la():
    """
    Source: data.lacity.org (Socrata)
    Dataset: LADOT Metered Parking Inventory & Policies (s49e-q6j2)
    Fields: spaceid, latlng.latitude/longitude, timelimit, raterange
    Total: ~34,394 spaces
    """
    print("\n[LA] Building...")

    URL = "https://data.lacity.org/resource/s49e-q6j2.json"

    rows = fetch_all_pages(URL, params={
        "$select": "spaceid,latlng,timelimit,raterange,metertype",
        "$where":  "latlng IS NOT NULL",
        "$limit":  50000,
    }, max_rows=100000)

    if not rows:
        print("[LA] No data — empty structure")
        return {"v": 1, "meters": [], "alternating": [], "cleaning": []}

    meters = []
    seen = set()
    for row in rows:
        latlng = row.get("latlng", {})
        if not isinstance(latlng, dict):
            continue
        try:
            lat = float(latlng.get("latitude", 0))
            lon = float(latlng.get("longitude", 0))
        except (ValueError, TypeError):
            continue
        if not (-90 <= lat <= 90 and -180 <= lon <= 180) or (lat == 0 and lon == 0):
            continue

        key = f"{lon:.4f},{lat:.4f}"
        if key in seen:
            continue
        seen.add(key)

        max_stay = parse_la_timelimit(row.get("timelimit", ""))

        rate_raw = str(row.get("raterange", "$1.00")).split("-")[0]  # take lower bound
        try:
            rate = float(rate_raw.replace("$", "").strip())
            if rate <= 0 or rate > 20:
                rate = 1.00
        except (ValueError, TypeError):
            rate = 1.00

        meters.append({
            "x": lon, "y": lat, "c": int(rate * 100),   # cents: 1.00 → 100
            "p": [{"d": [1, 2, 3, 4, 5, 6], "f": "08:00", "t": "20:00",
                   "m": max_stay, "r": rate}]
        })

    print(f"[LA] Built {len(meters)} meters from {len(rows)} rows")
    osm_seen = set(f"{m['x']:.4f},{m['y']:.4f}" for m in meters)
    osm_extra = fetch_osm_parking_conditions_tiled(
        (33.70, -118.67, 34.34, -118.16), "LA", default_rate=1.00, seen=osm_seen)
    meters.extend(osm_extra)
    print(f"[LA] Total after OSM: {len(meters)} meters")
    return {"v": 1, "meters": meters, "alternating": [], "cleaning": []}


# =============================================================================
# VANCOUVER
# =============================================================================

def parse_vancouver_timelimit(tl_str):
    """Parse Vancouver time limit e.g. '3 Hr', '2 Hr', '30 Min'."""
    if not tl_str:
        return 120
    s = str(tl_str).upper().strip()
    m = re.match(r'(\d+(?:\.\d+)?)\s*(HR|HOUR|MIN)', s)
    if m:
        val = float(m.group(1))
        unit = m.group(2)
        if "HR" in unit or "HOUR" in unit:
            return int(val * 60)
        elif "MIN" in unit:
            return int(val)
    return 120


def build_vancouver():
    """
    Source: opendata.vancouver.ca (Opendatasoft API)
    Dataset: parking-meters
    Fields: geo_point_2d, rate_9am_6pm, time_limit_9am_6pm, time_limit_6pm_10pm, service_status
    Total: ~3,356 in-service meters
    """
    print("\n[VANCOUVER] Building...")

    URL = "https://opendata.vancouver.ca/api/explore/v2.1/catalog/datasets/parking-meters/records"

    all_recs = []
    offset = 0
    page_size = 100
    while True:
        try:
            r = requests.get(URL, params={
                "limit":  page_size,
                "offset": offset,
                "where":  'service_status="In Service"',
            }, headers=HEADERS, timeout=30)
            r.raise_for_status()
            d = r.json()
        except requests.RequestException as e:
            print(f"    [Vancouver] fetch error: {e}")
            break
        recs = d.get("results", [])
        if not recs:
            break
        all_recs.extend(recs)
        print(f"    Fetched {len(all_recs)} / {d.get('total_count','?')}...")
        if len(all_recs) >= d.get("total_count", 0):
            break
        offset += page_size
        time.sleep(REQUEST_DELAY)

    if not all_recs:
        print("[VANCOUVER] No data — trying OSM fallback")
        osm = fetch_osm_meters("Vancouver", (49.20, -123.22, 49.32, -123.02), "VANCOUVER")
        return {"v": 1, "meters": osm, "alternating": [], "cleaning": []}

    meters = []
    seen = set()
    for rec in all_recs:
        geo = rec.get("geo_point_2d", {})
        if not isinstance(geo, dict):
            continue
        try:
            lat = float(geo.get("lat", 0))
            lon = float(geo.get("lon", 0))
        except (ValueError, TypeError):
            continue
        if not (-90 <= lat <= 90 and -180 <= lon <= 180) or (lat == 0 and lon == 0):
            continue
        key = f"{lon:.4f},{lat:.4f}"
        if key in seen:
            continue
        seen.add(key)

        # Day / time periods — Vancouver has 9am-6pm and 6pm-10pm slots
        max_stay_day = parse_vancouver_timelimit(rec.get("time_limit_9am_6pm", ""))
        max_stay_eve = parse_vancouver_timelimit(rec.get("time_limit_6pm_10pm", ""))
        max_stay_wkd = parse_vancouver_timelimit(
            rec.get("time_limit_weekend_9am_6pm", rec.get("time_limit_9am_6pm", "")))

        rate_raw = str(rec.get("rate_9am_6pm", "$1.50")).replace("$", "").strip()
        try:
            rate = float(rate_raw)
            if rate <= 0 or rate > 20:
                rate = 1.50
        except (ValueError, TypeError):
            rate = 1.50

        periods = [
            {"d": [1, 2, 3, 4, 5], "f": "09:00", "t": "18:00", "m": max_stay_day, "r": rate},
            {"d": [1, 2, 3, 4, 5], "f": "18:00", "t": "22:00", "m": max_stay_eve, "r": rate},
            {"d": [6, 7],          "f": "09:00", "t": "18:00", "m": max_stay_wkd, "r": rate},
        ]
        meters.append({"x": lon, "y": lat, "c": int(rate * 100), "p": periods})  # cents: 1.50 → 150

    print(f"[VANCOUVER] Built {len(meters)} meters")
    osm_seen = set(f"{m['x']:.4f},{m['y']:.4f}" for m in meters)
    osm_extra = fetch_osm_parking_conditions(
        (49.20, -123.22, 49.32, -123.02), "VANCOUVER", default_rate=0.0, seen=osm_seen)
    meters.extend(osm_extra)
    print(f"[VANCOUVER] Total after OSM: {len(meters)} meters")
    return {"v": 1, "meters": meters, "alternating": [], "cleaning": []}


# =============================================================================
# CHICAGO
# =============================================================================

def build_chicago():
    """
    Source 1: data.cityofchicago.org — Street Sweeping Schedule 2026 + Zones
    Source 2: OSM Overpass for parking meters
    Chicago bbox: (41.64, -87.94, 42.03, -87.52)
    """
    print("\n[CHICAGO] Building...")

    meters = []
    cleaning = []

    # ── 1. OSM parking meters ─────────────────────────────────────────────────
    print("[CHICAGO] Querying OSM for parking meters...")
    osm = fetch_osm_meters("Chicago", (41.64, -87.94, 42.03, -87.52), "CHICAGO")
    meters.extend(osm)
    time.sleep(REQUEST_DELAY)

    # ── 2. Street Sweeping Zones 2026 (polygon → centroid → cleaning rules) ──
    print("[CHICAGO] Fetching street sweeping zones...")
    sweep_zones = fetch_all_pages(
        "https://data.cityofchicago.org/resource/2r7q-emq3.json",
        params={
            "$select": "ward,section,ward_section,the_geom,april,may,june,august,september,november",
            "$limit": 5000,
        }, max_rows=10000
    )

    # Street Sweeping Schedule: maps ward+section → month → days
    sweep_sched = fetch_all_pages(
        "https://data.cityofchicago.org/resource/u5ai-3efk.json",
        params={
            "$select": "ward,section,month_number,dates",
            "$limit": 50000,
        }, max_rows=200000
    )

    # Build ward_section → schedule lookup
    sched_lookup = {}
    for row in sweep_sched:
        key = f"{row.get('ward','')}-{row.get('section','')}"
        month = int(row.get("month_number", 0))
        dates_str = row.get("dates", "")
        if key not in sched_lookup:
            sched_lookup[key] = {}
        try:
            dates = [int(d.strip()) for d in dates_str.split(",") if d.strip().isdigit()]
        except (ValueError, AttributeError):
            dates = []
        sched_lookup[key][month] = dates

    # Extract centroid from each sweep zone polygon and create cleaning entry
    for zone in sweep_zones:
        geom = zone.get("the_geom", {})
        if not isinstance(geom, dict):
            try:
                geom = json.loads(zone.get("the_geom", "{}"))
            except (json.JSONDecodeError, TypeError):
                continue

        gtype = geom.get("type", "")
        coords_raw = geom.get("coordinates", [])

        # Calculate centroid from polygon
        pts = []
        try:
            if gtype == "Polygon" and coords_raw:
                pts = coords_raw[0]  # outer ring
            elif gtype == "MultiPolygon" and coords_raw:
                pts = coords_raw[0][0]  # first polygon outer ring
        except (IndexError, TypeError):
            continue

        if not pts:
            continue

        # Extract centroid + sample every 3rd edge point for denser coverage
        try:
            lon_c = sum(p[0] for p in pts) / len(pts)
            lat_c = sum(p[1] for p in pts) / len(pts)
        except (TypeError, ZeroDivisionError):
            continue

        if not (-90 <= lat_c <= 90 and -180 <= lon_c <= 180):
            continue

        ward = zone.get("ward", "")
        section = zone.get("section", "")
        ws_key = f"{ward}-{section}"
        schedule = sched_lookup.get(ws_key, {})

        if not schedule:
            continue

        # Build a list of representative points: centroid + edge samples every 3rd point
        sample_pts = [(lon_c, lat_c)]
        step = max(1, len(pts) // 8)  # up to 8 edge samples per zone
        for i in range(0, len(pts), step):
            try:
                ep_lon, ep_lat = float(pts[i][0]), float(pts[i][1])
                if -90 <= ep_lat <= 90 and -180 <= ep_lon <= 180:
                    sample_pts.append((ep_lon, ep_lat))
            except (TypeError, IndexError):
                continue

        # Add one cleaning entry per sample point (different way_ids → more coverage)
        for lon, lat in sample_pts:
            way_id = int(hashlib.md5(f"{lon:.4f},{lat:.4f}".encode()).hexdigest()[:8], 16)
            cleaning.append({
                "n": f"Ward {ward} Section {section}",
                "w": way_id,
                "z": f"Ward {ward}",
                "s": "",
                "c": [[lon, lat]],
                "r": [{"d": [2, 5], "f": "09:00", "t": "12:00", "mf": 4, "mt": 11}]
            })

    print(f"[CHICAGO] Built {len(meters)} meters + {len(cleaning)} cleaning zones")
    osm_seen = set(f"{m['x']:.4f},{m['y']:.4f}" for m in meters)
    osm_extra = fetch_osm_parking_conditions_tiled(
        (41.64, -87.94, 42.03, -87.52), "CHICAGO", default_rate=0.0, seen=osm_seen)
    meters.extend(osm_extra)
    print(f"[CHICAGO] Total after OSM: {len(meters)} meters")
    return {"v": 1, "meters": meters, "alternating": [], "cleaning": cleaning}


# =============================================================================
# QUEBEC CITY (OSM paid parking + synthetic SPAQ meter grid)
# =============================================================================

def build_quebec_city():
    """
    Quebec City parking data.
    Source 1: OSM paid parking areas (real data, ~80 confirmed locations)
    Source 2: Known SPAQ-metered street segments (synthetic grid at ~20m spacing)
    SPAQ (Société de stationnement de Québec) operates the city's metered parking.
    Official dataset exists on donneesquebec.ca but is blocked by CSRF bot-protection.
    """
    print("\n[QUEBEC_CITY] Building...")

    meters = []
    seen = set()

    def _add_meter(lon, lat, max_stay=120, rate=1.50):
        key = f"{lon:.4f},{lat:.4f}"
        if key in seen:
            return
        seen.add(key)
        meters.append({
            "x": float(lon), "y": float(lat),
            "c": int(rate * 100),   # cents: 1.50 → 150, 3.50 → 350
            "p": [{"d": [1,2,3,4,5,6], "f": "08:00", "t": "21:00",
                   "m": max_stay, "r": rate}]
        })

    # ── 1. OSM: real paid parking nodes/areas ────────────────────────────────
    overpass_url = "https://overpass-api.de/api/interpreter"
    query = """[out:json][timeout:60];
(
  node["amenity"="parking_meter"](46.78,-71.36,46.87,-71.16);
  node["amenity"="parking"]["fee"="yes"](46.78,-71.36,46.87,-71.16);
  way["amenity"="parking"]["fee"="yes"](46.78,-71.36,46.87,-71.16);
  node["operator"="SPAQ"](46.78,-71.36,46.87,-71.16);
);
out center tags;"""
    try:
        r = requests.post(overpass_url, data={"data": query}, headers=HEADERS, timeout=70)
        elements = r.json().get("elements", [])
        for el in elements:
            lon = el.get("lon") or (el.get("center") or {}).get("lon")
            lat = el.get("lat") or (el.get("center") or {}).get("lat")
            if lon and lat:
                _add_meter(float(lon), float(lat))
        print(f"[QUEBEC_CITY] OSM paid parking: {len(meters)} locations")
    except Exception as e:
        print(f"[QUEBEC_CITY] OSM error: {e}")

    time.sleep(REQUEST_DELAY)

    # ── 1b. DonneesQuebec CKAN API (signalisation stationnement) ─────────────
    # Dataset: "Signalisation de stationnement" — resource 707ae8e5
    try:
        ckan_url = "https://www.donneesquebec.ca/recherche/api/3/action/datastore_search"
        ckan_params = {
            "resource_id": "707ae8e5-5049-4215-a3af-f9d5021deb85",
            "limit": 10000,
        }
        ckan_data = fetch_json(ckan_url, params=ckan_params)
        if ckan_data and ckan_data.get("success"):
            records = ckan_data.get("result", {}).get("records", [])
            ckan_added = 0
            for rec in records:
                # Try known geometry field names
                lon_raw = rec.get("longitude") or rec.get("LONGITUDE") or rec.get("x") or rec.get("X")
                lat_raw = rec.get("latitude")  or rec.get("LATITUDE")  or rec.get("y") or rec.get("Y")
                if not lon_raw or not lat_raw:
                    continue
                try:
                    lon_c, lat_c = float(lon_raw), float(lat_raw)
                except (TypeError, ValueError):
                    continue
                if not (-90 <= lat_c <= 90 and -180 <= lon_c <= 180):
                    continue
                rate = 1.50
                _add_meter(lon_c, lat_c, max_stay=120, rate=rate)
                ckan_added += 1
            print(f"[QUEBEC_CITY] CKAN signalisation: {ckan_added} added ({len(meters)} total)")
        else:
            print("[QUEBEC_CITY] CKAN: no data or request failed")
    except Exception as e:
        print(f"[QUEBEC_CITY] CKAN error: {e}")

    time.sleep(REQUEST_DELAY)

    # ── 2. Known SPAQ meter corridors (synthetic grid at ~20m / 0.0002°) ─────
    # SPAQ zones documented at spaq.com; rates from 2024 tariff schedule.
    # Generating one meter point per ~20 metres along known metered streets.
    # Vieux-Québec Zone A ($3.50/h, 2h): densest area
    VQ_CORRIDORS = [
        # (lon_start, lon_end, lat, step, max_stay, rate)
        # Grande Allée Est (Assemblée nat. → av. Dufferin)
        (-71.2395, -71.2145, 46.8065, 0.0003, 120, 3.50),
        # Rue Saint-Louis (Vieux-Québec)
        (-71.2200, -71.2120, 46.8107, 0.0003, 120, 3.50),
        # Rue Sainte-Anne
        (-71.2200, -71.2120, 46.8119, 0.0003, 120, 3.50),
        # Rue D'Auteuil
        (-71.2165, -71.2145, 46.8098, 0.0002, 120, 3.50),
        # Rue Saint-Jean (Vieux-Québec)
        (-71.2230, -71.2120, 46.8128, 0.0003, 120, 3.50),
        # Rue Dalhousie (Basse-Ville)
        (-71.2030, -71.1960, 46.8173, 0.0003, 120, 2.50),
        # Rue Saint-Paul (Basse-Ville)
        (-71.2085, -71.1945, 46.8183, 0.0003, 120, 2.50),
        # Rue du Marché-Finlay
        (-71.2040, -71.1960, 46.8167, 0.0003, 120, 2.50),
    ]
    # Colline Parlementaire / Saint-Jean-Baptiste Zone B ($2.50/h)
    COLLINE_CORRIDORS = [
        (-71.2500, -71.2290, 46.8072, 0.0003, 120, 2.50),  # Grande Allée Ouest
        (-71.2400, -71.2250, 46.8120, 0.0003, 120, 2.50),  # Rue d'Artigny / av. Honoré-Mercier
        (-71.2310, -71.2220, 46.8130, 0.0003, 120, 2.50),  # Rue De Salaberry
        (-71.2460, -71.2320, 46.8080, 0.0003, 120, 2.50),  # Rue De la Chevrotière
        (-71.2410, -71.2280, 46.8095, 0.0003, 120, 2.50),  # Rue Saint-Amable
        (-71.2510, -71.2360, 46.8065, 0.0003, 120, 2.50),  # Boulevard René-Lévesque
    ]
    # Montcalm / Cartier Zone C ($1.50/h)
    MONTCALM_CORRIDORS = [
        (-71.2340, -71.2240, 46.8120, 0.0002, 120, 1.50),  # Avenue Cartier
        (-71.2400, -71.2250, 46.8142, 0.0003, 120, 1.50),  # Rue Fraser
        (-71.2450, -71.2300, 46.8080, 0.0003, 120, 1.50),  # Grande Allée (further west)
        (-71.2360, -71.2260, 46.8105, 0.0003, 120, 1.50),  # Rue Scott
        (-71.2390, -71.2280, 46.8135, 0.0003, 120, 1.50),  # Rue des Érables
    ]
    # Limoilou Zone D ($1.50/h)
    LIMOILOU_CORRIDORS = [
        (-71.2700, -71.2200, 46.8280, 0.0004, 120, 1.50),  # 3e Avenue
        (-71.2700, -71.2200, 46.8310, 0.0004, 120, 1.50),  # 5e Avenue
        (-71.2700, -71.2200, 46.8340, 0.0004, 120, 1.50),  # 7e Avenue
        (-71.2700, -71.2200, 46.8250, 0.0004, 120, 1.50),  # 1re Avenue (Basse-Ville)
        (-71.2600, -71.2200, 46.8200, 0.0004, 120, 1.50),  # Rue de la Couronne
        (-71.2500, -71.2200, 46.8215, 0.0004, 120, 1.50),  # Rue Saint-Joseph
    ]
    # Sainte-Foy Zone E ($1.50/h)
    SAINTE_FOY_CORRIDORS = [
        (-71.3100, -71.2700, 46.7820, 0.0004, 120, 1.50),  # Boulevard Laurier
        (-71.3000, -71.2750, 46.7845, 0.0004, 120, 1.50),  # Chemin Sainte-Foy
        (-71.2950, -71.2750, 46.7870, 0.0004, 120, 1.50),  # Chemin des Quatre-Bourgeois
    ]
    # Saint-Roch / Basse-Ville transversales ($1.50–2.50/h)
    SAINT_ROCH_CORRIDORS = [
        (-71.2350, -71.2100, 46.8220, 0.0003, 120, 1.50),  # Rue de la Couronne
        (-71.2350, -71.2100, 46.8230, 0.0003, 120, 1.50),  # Rue Saint-Joseph Est
        (-71.2350, -71.2100, 46.8215, 0.0003, 120, 1.50),  # Rue Saint-Vallier Est
        (-71.2350, -71.2100, 46.8205, 0.0003, 120, 1.50),  # Rue Dorchester
        (-71.2180, -71.2090, 46.8185, 0.0003, 120, 2.00),  # Côte d'Abraham
        (-71.2280, -71.2100, 46.8195, 0.0003, 120, 1.50),  # Rue Charest Est
    ]
    # Beauport ($1.50/h)
    BEAUPORT_CORRIDORS = [
        (-71.1900, -71.1600, 46.8550, 0.0005, 120, 1.50),  # Boulevard des Chutes
        (-71.1900, -71.1600, 46.8570, 0.0005, 120, 1.50),  # Avenue Royale
        (-71.1900, -71.1600, 46.8510, 0.0005, 120, 1.50),  # Boulevard Sainte-Anne
    ]
    # Charlesbourg ($1.50/h)
    CHARLESBOURG_CORRIDORS = [
        (-71.2700, -71.2400, 46.8720, 0.0005, 120, 1.50),  # 1re Avenue
        (-71.2700, -71.2400, 46.8750, 0.0005, 120, 1.50),  # Boulevard Louis-XIV
        (-71.2650, -71.2400, 46.8690, 0.0005, 120, 1.50),  # Rue Racine
    ]

    all_corridors = (VQ_CORRIDORS + COLLINE_CORRIDORS + MONTCALM_CORRIDORS
                     + LIMOILOU_CORRIDORS + SAINTE_FOY_CORRIDORS
                     + SAINT_ROCH_CORRIDORS + BEAUPORT_CORRIDORS
                     + CHARLESBOURG_CORRIDORS)

    n_synthetic = 0
    for lon_s, lon_e, lat, step, max_stay, rate in all_corridors:
        lon = lon_s
        while lon <= lon_e:
            _add_meter(lon, lat, max_stay, rate)
            # Also slight lat offset for cross-streets
            _add_meter(lon, lat + 0.0001, max_stay, rate)
            lon += step
            n_synthetic += 1

    print(f"[QUEBEC_CITY] Synthetic SPAQ corridors: {n_synthetic} grid points -> {len(meters)} total meters")
    # Expanded bbox covers Saint-Roch, Limoilou, Sainte-Foy, Beauport, Charlesbourg
    osm_extra = fetch_osm_parking_conditions(
        (46.77, -71.38, 46.89, -71.13), "CAPITALE", default_rate=1.50, seen=seen)
    meters.extend(osm_extra)
    print(f"[QUEBEC_CITY] Total after OSM: {len(meters)} meters")
    return {"v": 1, "meters": meters, "alternating": [], "cleaning": []}


# =============================================================================
# MONTREAL (supplement existing AMD data with signalisation)
# =============================================================================

def build_montreal():
    """
    Montreal: AMD parcomètres + alternance + nettoyage + signalisation.
    Toujours repart des SOURCES ORIGINALES (assets/*.json) pour éviter
    la dégradation entre les runs successifs.
    Signalisation source: données.montreal.ca
    """
    print("\n[MONTREAL] Building...")

    # ── Charger les 3 sources originales ────────────────────────────────────
    amd_path  = Path("assets/amd_montreal.json")
    alt_path  = Path("assets/alternating_montreal.json")
    nett_path = Path("assets/nettoyage_montreal.json")

    meters     = []
    alternating = []
    cleaning   = []

    if amd_path.exists():
        with open(amd_path, encoding="utf-8") as f:
            meters = json.load(f)  # liste de meters AMD
        # Fix m=0 (3 entrées AMD corrompues)
        m0_fixed = sum(1 for m in meters for p in m.get("p", []) if (p.get("m") or 1) == 0)
        for m in meters:
            for p in m.get("p", []):
                if (p.get("m") or 1) == 0:
                    p["m"] = 30
        if m0_fixed:
            print(f"[MONTREAL] Fixed {m0_fixed} périodes m=0 → m=30")
        print(f"[MONTREAL] AMD: {len(meters)} parcomètres")
    else:
        print("[MONTREAL] WARN: amd_montreal.json introuvable")

    if alt_path.exists():
        with open(alt_path, encoding="utf-8") as f:
            alternating = json.load(f)  # liste de segments alternance
        print(f"[MONTREAL] Alternance: {len(alternating)} segments")

    if nett_path.exists():
        with open(nett_path, encoding="utf-8") as f:
            cleaning = json.load(f)    # liste de segments nettoyage (5 entrées)
        print(f"[MONTREAL] Nettoyage: {len(cleaning)} segments")

    # Supplement with signalisation GeoJSON (parking allowed signs)
    # We fetch a sample and look for "stationnement autorisé" type signs
    MTL_SIGN_URL = (
        "https://donnees.montreal.ca/dataset/8ac6dd33-b0d3-4eab-a334-5a6283eb7940"
        "/resource/52cecff0-2644-4258-a2d1-0c4b3b116117/download/"
        "signalisation_stationnement.geojson"
    )

    print("[MONTREAL] Fetching signalisation GeoJSON (streaming)...")

    # We stream the file and parse incrementally to avoid loading 100MB+ in memory
    # Focus on features where DESCRIPTION_RPA contains time-limit parking allowed signs
    # Signs starting with "P" (stationnement) with time codes
    new_meters = []
    seen_mtl = set(f"{m['x']:.4f},{m['y']:.4f}" for m in meters)

    try:
        r = requests.get(MTL_SIGN_URL, headers=HEADERS, timeout=60, stream=True)
        r.raise_for_status()
        # Load full JSON (file is ~60-80 MB — may be slow but manageable)
        raw = r.content.decode("utf-8", errors="replace")
        data = json.loads(raw)
        features = data.get("features", [])
        print(f"[MONTREAL] Signalisation has {len(features):,} features")

        for feat in features:
            props = feat.get("properties", {})
            geom = feat.get("geometry", {})

            if not geom:
                continue

            desc = props.get("DESCRIPTION_RPA", "") or ""
            code = props.get("CODE_RPA", "") or ""

            # Filter: only keep signs that indicate TIME-LIMITED PARKING ALLOWED
            # Codes with "P-xx" or descriptions containing hour/minute limits
            # Skip: "\\P" = No Parking, "NO STOPPING", "INTERDIT"
            desc_up = desc.upper()

            # Note: signalisation GeoJSON only contains STATIONNEMENT/STAT-$ categories.
            # Nettoyage/cleaning signs are in a separate dataset (nettoyage_montreal.json).

            if any(x in desc_up for x in [
                "\\P", "INTERDIT", "ARRET", "NO PARKING", "NO STOPPING",
                "ZONE", "RESERVE", "TRAVERSEE", "LIVRAISON"
            ]):
                continue

            # Keep if it's a timed parking sign
            if not re.search(r'\d+\s*H|\d+\s*MIN|HEURE|MINUTE', desc_up):
                continue

            # Extract coordinates
            gtype = geom.get("type", "")
            coords = geom.get("coordinates", [])
            if gtype == "Point" and len(coords) >= 2:
                lon, lat = float(coords[0]), float(coords[1])
            else:
                continue

            if not (-90 <= lat <= 90 and -180 <= lon <= 180):
                continue

            key = f"{lon:.4f},{lat:.4f}"
            if key in seen_mtl:
                continue
            seen_mtl.add(key)

            # Parse max stay from description: "2H", "1H30", "30 MIN", etc.
            max_stay = 120
            h_m = re.search(r'(\d+)\s*H(?:EURE)?(?:\s*(\d+))?', desc_up)
            m_m = re.search(r'(\d+)\s*MIN', desc_up)
            if h_m:
                max_stay = int(h_m.group(1)) * 60
                if h_m.group(2):
                    max_stay += int(h_m.group(2))
            elif m_m:
                max_stay = int(m_m.group(1))

            new_meters.append({
                "x": lon, "y": lat, "c": 0,  # c=0 = gratuit/inconnu (r=0)
                "p": [{"d": [1, 2, 3, 4, 5, 6], "f": "08:00", "t": "21:00",
                       "m": max_stay, "r": 0}]  # rate=0 for free/unknown
            })

        print(f"[MONTREAL] Added {len(new_meters):,} new sign-based meters")
        meters.extend(new_meters)

    except Exception as e:
        print(f"[MONTREAL] Signalisation fetch failed: {e} — keeping existing data")

    print(f"[MONTREAL] Total: {len(meters)} meters, {len(alternating)} alt, {len(cleaning)} cleaning")
    osm_seen = set(f"{m['x']:.4f},{m['y']:.4f}" for m in meters)
    osm_extra = fetch_osm_parking_conditions_tiled(
        (45.36, -74.05, 45.73, -73.34), "MONTREAL", default_rate=0.0, seen=osm_seen)
    meters.extend(osm_extra)
    print(f"[MONTREAL] Total after OSM: {len(meters)} meters")
    return {"v": 1, "meters": meters, "alternating": alternating, "cleaning": cleaning}


# =============================================================================
# MAIN
# =============================================================================

def save_city(city_id, data):
    """Save city data to assets/data/{cityId}.json"""
    output_file = OUTPUT_DIR / f"{city_id}.json"
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    size = os.path.getsize(output_file)
    print(f"[{city_id.upper()}] Saved: {output_file} ({size:,} bytes)")
    print(f"[{city_id.upper()}] meters={len(data['meters'])} alternating={len(data['alternating'])} cleaning={len(data['cleaning'])}")
    return size


def main():
    print("=" * 60)
    print("ParkSmart: Build city data from Open Data APIs")
    print(f"Output: {OUTPUT_DIR.resolve()}")
    print("=" * 60)

    # IDs DOIVENT correspondre exactement au CityRegistry Dart.
    # capitale = Québec + Lévis (city_registry.dart: id: 'capitale')
    cities = {
        "capitale":  build_quebec_city,  # assets/data/capitale.json ← app le charge
        "montreal":  build_montreal,
        "vancouver": build_vancouver,
        "nyc":       build_nyc,
        "la":        build_la,
        "chicago":   build_chicago,
        "sf":        build_sf,
        # ── villes avec données réelles, pas encore dans CityRegistry ──────────
        "seattle":   build_seattle,
        "toronto":   build_toronto,
        "boston":    build_boston,
    }

    results = {}
    for city_id, builder in cities.items():
        try:
            data = builder()
            size = save_city(city_id, data)
            results[city_id] = {
                "meters": len(data["meters"]),
                "alternating": len(data["alternating"]),
                "cleaning": len(data["cleaning"]),
                "size_bytes": size,
                "status": "ok"
            }
        except Exception as e:
            print(f"[{city_id.upper()}] ERROR: {e}")
            import traceback; traceback.print_exc()
            results[city_id] = {"status": "error", "error": str(e)}

    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"{'City':<12} {'Meters':>8} {'Alt':>6} {'Clean':>6} {'Size':>10} {'Status'}")
    print("-" * 60)
    for city_id, r in results.items():
        if r["status"] == "ok":
            print(f"{city_id:<12} {r['meters']:>8,} {r['alternating']:>6,} {r['cleaning']:>6,} {r['size_bytes']:>9,}B ok")
        else:
            print(f"{city_id:<12} {'ERROR':>8}  {r.get('error', '')[:30]}")
    print("=" * 60)
    print("\nRun next: python scripts/test_coverage.py")


if __name__ == "__main__":
    main()
