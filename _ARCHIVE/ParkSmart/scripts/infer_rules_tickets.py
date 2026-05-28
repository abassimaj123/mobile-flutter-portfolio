#!/usr/bin/env python3
"""
infer_rules_tickets.py
======================
Pipeline batch mensuel — ParkSmart Sprint 1

Télécharge les données de tickets de stationnement depuis les portails open-data
Socrata de NYC, Chicago, LA et SF. Géocode les adresses, snape sur les segments
OSM, agrège par fenêtre temporelle, infère les restrictions de stationnement et
produit assets/data/{cityId}.json dans le format utilisé par l'app Flutter.

Usage
-----
    python scripts/infer_rules_tickets.py --city nyc
    python scripts/infer_rules_tickets.py --city chicago
    python scripts/infer_rules_tickets.py --city all
    python scripts/infer_rules_tickets.py --city nyc --max-tickets 100000

Dépendances
-----------
    pip install requests

Le cache géocodage est stocké dans scripts/geocode_cache.db (SQLite).
Re-run mensuel : réutilise le cache, ne re-géocode que les nouvelles adresses.
"""

import argparse
import json
import math
import os
import sqlite3
import sys
import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

import requests

# ── Racine du projet ──────────────────────────────────────────────────────────
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS_DIR  = os.path.dirname(os.path.abspath(__file__))
DATA_DIR     = os.path.join(PROJECT_ROOT, "assets", "data")
CACHE_DB     = os.path.join(SCRIPTS_DIR, "geocode_cache.db")

# ── Configuration des villes ──────────────────────────────────────────────────

CITIES: Dict[str, Dict[str, Any]] = {
    "nyc": {
        "label": "NYC",
        "domain": "data.cityofnewyork.us",
        "dataset": "pvqr-7yc4",
        # Champs Socrata
        "date_field": "issue_date",
        "time_field": "violation_time",
        "code_field": "violation_code",
        "address_fields": ["house_number", "street_name"],
        "address_suffix": ", New York, NY",
        # Codes de violation pertinents (chaînes ou entiers selon dataset)
        "cleaning_codes": {
            "street_cleaning": ["14", "20", "21", "38", "46", "47", "70"],
            "time_limit":      ["17", "18", "19", "40", "42"],
            "no_parking":      ["06", "07", "08", "09", "10", "11", "45"],
            "permit_zone":     ["16", "30", "31"],
        },
        # Bbox OSM : sud,ouest,nord,est
        "bbox": "40.50,-74.26,40.93,-73.70",
        # Géocodeur NYC spécialisé (plus précis)
        "extra_geocoder": "nyc_planning",
    },
    "chicago": {
        "label": "Chicago",
        "domain": "data.cityofchicago.org",
        "dataset": "wrvz-psew",
        "date_field": "violation_date",
        "time_field": None,
        "code_field": "violation_code",
        "address_fields": ["address"],
        "address_suffix": ", Chicago, IL",
        "cleaning_codes": {
            "street_cleaning": ["0976160C", "0964150B", "0964150C", "9760"],
            "time_limit":      ["0976170F", "0976170D", "0976170H"],
            "no_parking":      ["0964150A", "0964150F", "0964150G"],
            "permit_zone":     ["0976170B", "0976170C"],
        },
        "bbox": "41.64,-87.94,42.03,-87.52",
        "extra_geocoder": None,
    },
    "la": {
        "label": "LA",
        "domain": "data.lacity.org",
        "dataset": "wjz9-h9np",
        "date_field": "issue_date",
        "time_field": "issue_time",
        "code_field": "violation_code",
        "address_fields": ["location"],
        "address_suffix": ", Los Angeles, CA",
        "cleaning_codes": {
            "street_cleaning": ["80.69BS", "80.69BC", "80.69ES", "8069"],
            "time_limit":      ["80.58A", "80.58E", "80.58D", "8058"],
            "no_parking":      ["80.65", "80.65A", "80.65B", "8065"],
            "permit_zone":     ["80.02", "88.13B", "8802"],
        },
        "bbox": "33.70,-118.67,34.34,-118.16",
        "extra_geocoder": None,
    },
    "sf": {
        "label": "SF",
        "domain": "data.sfgov.org",
        "dataset": "ab4h-6ztd",
        "date_field": "citation_issue_date",
        "time_field": "citation_issue_time",
        "code_field": "violation_code",
        "address_fields": ["street_block"],
        "address_suffix": ", San Francisco, CA",
        "cleaning_codes": {
            "street_cleaning": ["22500E", "22500I", "5204A", "225E"],
            "time_limit":      ["22500A", "40508", "22505"],
            "no_parking":      ["22500H", "22500J", "22500L"],
            "permit_zone":     ["22507", "225071", "22507B"],
        },
        "bbox": "37.63,-122.52,37.83,-121.98",
        "extra_geocoder": None,
    },
}

# Fenêtre temporelle : 3 dernières années
YEARS_BACK = 3

# Seuils d'agrégation
MIN_TICKETS_PER_BUCKET = 5     # tickets minimum par (jour, heure)
MIN_YEARS_COVERED      = 2     # le signal doit couvrir ≥ 2 années distinctes
MAX_SNAP_METERS        = 30    # distance max pour snapper sur un segment OSM

# OSM : types de voies à récupérer
OSM_WAY_TYPES = [
    "residential", "tertiary", "unclassified", "living_street",
    "secondary", "primary",
]

# ── User-Agent commun ─────────────────────────────────────────────────────────
UA = "ParkSmart/1.0 (parking-rules-pipeline; contact=parksmart@example.com)"


# ═══════════════════════════════════════════════════════════════════════════════
# Utilitaires géographiques
# ═══════════════════════════════════════════════════════════════════════════════

def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Distance en mètres entre deux points (WGS84)."""
    R = 6_371_000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))


def point_to_segment_distance(
    px: float, py: float,
    ax: float, ay: float,
    bx: float, by: float,
) -> float:
    """
    Distance (mètres) du point P au segment AB le plus proche.
    Les coordonnées sont (lon, lat) — approximation plane acceptable sur
    de courtes distances (< 5 km).
    """
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return haversine_m(py, px, ay, ax)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    cx = ax + t * dx
    cy = ay + t * dy
    return haversine_m(py, px, cy, cx)


def snap_to_ways(
    lat: float, lon: float,
    ways: List[Dict],
) -> Optional[int]:
    """
    Retourne l'OSM way_id le plus proche du point (lat, lon) dans la liste de
    ways, si la distance est ≤ MAX_SNAP_METERS. Sinon None.

    Chaque way est {"id": int, "coords": [[lon, lat], ...]}.
    """
    best_id   = None
    best_dist = MAX_SNAP_METERS + 1

    for way in ways:
        coords = way["coords"]
        for i in range(len(coords) - 1):
            ax, ay = coords[i]
            bx, by = coords[i + 1]
            dist = point_to_segment_distance(lon, lat, ax, ay, bx, by)
            if dist < best_dist:
                best_dist = dist
                best_id   = way["id"]

    return best_id if best_dist <= MAX_SNAP_METERS else None


# ═══════════════════════════════════════════════════════════════════════════════
# Cache géocodage (SQLite)
# ═══════════════════════════════════════════════════════════════════════════════

class GeocodeCache:
    """Cache SQLite simple pour les résultats de géocodage."""

    def __init__(self, db_path: str) -> None:
        self.conn = sqlite3.connect(db_path)
        self._init_schema()

    def _init_schema(self) -> None:
        self.conn.execute(
            """
            CREATE TABLE IF NOT EXISTS cache (
                address TEXT PRIMARY KEY,
                lat     REAL,
                lon     REAL,
                ts      INTEGER
            )
            """
        )
        self.conn.commit()

    def get(self, address: str) -> Optional[Tuple[float, float]]:
        row = self.conn.execute(
            "SELECT lat, lon FROM cache WHERE address = ?", (address,)
        ).fetchone()
        if row and row[0] is not None:
            return (row[0], row[1])
        return None

    def set(self, address: str, lat: Optional[float], lon: Optional[float]) -> None:
        """Stocke le résultat. lat=None/lon=None marque l'adresse comme introuvable."""
        self.conn.execute(
            "INSERT OR REPLACE INTO cache (address, lat, lon, ts) VALUES (?,?,?,?)",
            (address, lat, lon, int(time.time())),
        )
        self.conn.commit()

    def has(self, address: str) -> bool:
        return (
            self.conn.execute(
                "SELECT 1 FROM cache WHERE address = ?", (address,)
            ).fetchone()
            is not None
        )

    def close(self) -> None:
        self.conn.close()


# ═══════════════════════════════════════════════════════════════════════════════
# Session HTTP avec retry/backoff
# ═══════════════════════════════════════════════════════════════════════════════

def make_session() -> requests.Session:
    """Crée une session requests avec User-Agent standard."""
    s = requests.Session()
    s.headers.update({"User-Agent": UA})
    return s


def get_with_retry(
    session: requests.Session,
    url: str,
    params: Optional[Dict] = None,
    max_retries: int = 5,
    base_delay: float = 2.0,
    label: str = "",
) -> Optional[requests.Response]:
    """
    GET avec retry exponentiel sur 429 / 503 / timeout.
    Retourne None si toutes les tentatives échouent.
    """
    for attempt in range(max_retries):
        try:
            resp = session.get(url, params=params, timeout=60)
            if resp.status_code == 200:
                return resp
            if resp.status_code in (429, 503):
                wait = base_delay * (2 ** attempt)
                print(f"  [{label}] HTTP {resp.status_code} — retry dans {wait:.0f}s...")
                time.sleep(wait)
                continue
            print(f"  [{label}] HTTP {resp.status_code} pour {url}")
            return None
        except requests.exceptions.Timeout:
            wait = base_delay * (2 ** attempt)
            print(f"  [{label}] Timeout — retry dans {wait:.0f}s...")
            time.sleep(wait)
        except requests.exceptions.ConnectionError as exc:
            wait = base_delay * (2 ** attempt)
            print(f"  [{label}] ConnectionError ({exc}) — retry dans {wait:.0f}s...")
            time.sleep(wait)
    print(f"  [{label}] Abandon après {max_retries} tentatives pour {url}")
    return None


# ═══════════════════════════════════════════════════════════════════════════════
# Étape 1 : Téléchargement des tickets (Socrata SODA)
# ═══════════════════════════════════════════════════════════════════════════════

def build_violation_code_filter(city_cfg: Dict) -> str:
    """
    Construit le filtre $where Socrata pour les codes de violation pertinents.
    Exemples :
        violation_code in('14','20','21','38')
    """
    all_codes: List[str] = []
    for codes in city_cfg["cleaning_codes"].values():
        all_codes.extend(codes)
    # Déduplique
    unique = list(dict.fromkeys(all_codes))
    if not unique:
        return ""
    quoted = ",".join(f"'{c}'" for c in unique)
    return f"{city_cfg['code_field']} in({quoted})"


def download_tickets(
    city_id: str,
    city_cfg: Dict,
    session: requests.Session,
    max_tickets: int = 0,
) -> List[Dict]:
    """
    Télécharge les tickets de violation via l'API Socrata SODA.
    Retourne une liste de dicts bruts.

    Paramètres
    ----------
    max_tickets : limite optionnelle pour les tests (0 = pas de limite)
    """
    label  = city_cfg["label"]
    domain = city_cfg["domain"]
    dataset = city_cfg["dataset"]
    url    = f"https://{domain}/resource/{dataset}.json"

    # Filtre date : 3 dernières années
    cutoff = (datetime.now(timezone.utc) - timedelta(days=365 * YEARS_BACK)).strftime(
        "%Y-%m-%dT00:00:00"
    )
    date_filter = f"{city_cfg['date_field']} >= '{cutoff}'"

    # Filtre codes de violation
    code_filter = build_violation_code_filter(city_cfg)

    where_clause = date_filter
    if code_filter:
        where_clause += f" AND {code_filter}"

    chunk_size = 50_000
    offset     = 0
    tickets: List[Dict] = []

    print(f"[{label}] Téléchargement des tickets...")

    while True:
        # Respecter la limite de test
        if max_tickets and offset >= max_tickets:
            break

        current_limit = chunk_size
        if max_tickets and offset + chunk_size > max_tickets:
            current_limit = max_tickets - offset

        params: Dict[str, Any] = {
            "$where":  where_clause,
            "$limit":  current_limit,
            "$offset": offset,
            "$order":  f"{city_cfg['date_field']} ASC",
        }

        resp = get_with_retry(session, url, params=params, label=label)
        if resp is None:
            print(f"[{label}] Échec du téléchargement à l'offset {offset:,}")
            break

        try:
            batch = resp.json()
        except json.JSONDecodeError as exc:
            print(f"[{label}] JSON invalide : {exc}")
            break

        if not isinstance(batch, list):
            print(f"[{label}] Réponse inattendue : {type(batch)}")
            break

        tickets.extend(batch)
        fetched = len(batch)
        offset += fetched

        print(f"[{label}] Téléchargement des tickets : {offset:,}...", end="\r")

        if fetched < current_limit:
            # Dernière page
            break

        # Petite pause pour ne pas surcharger le serveur
        time.sleep(0.2)

    print(f"[{label}] {len(tickets):,} tickets téléchargés.            ")
    return tickets


# ═══════════════════════════════════════════════════════════════════════════════
# Étape 2 : Géocodage des adresses
# ═══════════════════════════════════════════════════════════════════════════════

def build_address_string(ticket: Dict, city_cfg: Dict) -> str:
    """
    Construit la chaîne d'adresse à géocoder à partir des champs du ticket.
    Ex : "123 BROADWAY, New York, NY"
    """
    fields = city_cfg["address_fields"]
    suffix = city_cfg["address_suffix"]

    parts = []
    for field in fields:
        val = ticket.get(field, "")
        if val and str(val).strip():
            parts.append(str(val).strip())

    if not parts:
        return ""

    addr = " ".join(parts)
    return f"{addr}{suffix}"


def geocode_nominatim(
    address: str,
    session: requests.Session,
    label: str = "",
) -> Optional[Tuple[float, float]]:
    """
    Géocode via l'API Nominatim OSM.
    Rate limit : 1 req/s (obligatoire selon ToS).
    Retourne (lat, lon) ou None.
    """
    url = "https://nominatim.openstreetmap.org/search"
    params = {
        "q":      address,
        "format": "json",
        "limit":  1,
    }
    time.sleep(1.0)  # Respect ToS Nominatim
    resp = get_with_retry(session, url, params=params, label=label)
    if resp is None:
        return None
    try:
        results = resp.json()
    except json.JSONDecodeError:
        return None
    if not results:
        return None
    return (float(results[0]["lat"]), float(results[0]["lon"]))


def geocode_nyc_planning(
    address: str,
    session: requests.Session,
) -> Optional[Tuple[float, float]]:
    """
    Géocode via NYC Planning Labs GeoSearch (plus précis pour NYC).
    Retourne (lat, lon) ou None.
    """
    url = "https://geosearch.planninglabs.nyc/v1/search"
    params = {"text": address, "size": 1}
    time.sleep(0.5)
    resp = get_with_retry(session, url, params=params, label="NYC-geo")
    if resp is None:
        return None
    try:
        data = resp.json()
    except json.JSONDecodeError:
        return None
    features = data.get("features", [])
    if not features:
        return None
    coords = features[0].get("geometry", {}).get("coordinates", [])
    if len(coords) < 2:
        return None
    return (float(coords[1]), float(coords[0]))  # GeoJSON : [lon, lat]


def geocode_tickets(
    city_id: str,
    city_cfg: Dict,
    tickets: List[Dict],
    cache: GeocodeCache,
    session: requests.Session,
) -> List[Dict]:
    """
    Géocode chaque ticket (si pas encore en cache).
    Ajoute les champs _lat, _lon à chaque ticket géocodé avec succès.
    Retourne la liste filtrée (tickets sans coordonnées exclus).
    """
    label    = city_cfg["label"]
    use_nyc  = city_cfg.get("extra_geocoder") == "nyc_planning"

    geocoded    = 0
    from_cache  = 0
    failed      = 0
    total       = len(tickets)
    result      = []

    print(f"[{label}] Géocodage de {total:,} tickets...")

    for i, ticket in enumerate(tickets):
        if i % 1000 == 0 and i > 0:
            print(
                f"[{label}] Géocodage : {i:,}/{total:,} "
                f"(ok={geocoded+from_cache:,} | cache={from_cache:,} | échec={failed:,})",
                end="\r",
            )

        address = build_address_string(ticket, city_cfg)
        if not address:
            failed += 1
            continue

        # Chercher dans le cache
        cached = cache.get(address)
        if cached is not None:
            ticket["_lat"], ticket["_lon"] = cached
            result.append(ticket)
            from_cache += 1
            continue

        if cache.has(address):
            # Adresse connue introuvable
            failed += 1
            continue

        # Géocodage live
        coords = None
        if use_nyc:
            coords = geocode_nyc_planning(address, session)
        if coords is None:
            coords = geocode_nominatim(address, session, label=label)

        if coords:
            cache.set(address, coords[0], coords[1])
            ticket["_lat"], ticket["_lon"] = coords
            result.append(ticket)
            geocoded += 1
        else:
            cache.set(address, None, None)  # Marque introuvable
            failed += 1

    print(
        f"[{label}] Géocodage terminé : {len(result):,} OK, {failed:,} échecs, "
        f"{from_cache:,} depuis le cache.       "
    )
    return result


# ═══════════════════════════════════════════════════════════════════════════════
# Étape 3 : Snap sur les segments OSM
# ═══════════════════════════════════════════════════════════════════════════════

def fetch_osm_ways(bbox: str, session: requests.Session, label: str = "") -> List[Dict]:
    """
    Récupère les ways OSM (residential/tertiary/etc.) dans le bbox via Overpass.
    Retourne liste de {"id": int, "coords": [[lon, lat], ...]}.
    """
    way_filter = "|".join(OSM_WAY_TYPES)
    # Format bbox Overpass : sud,ouest,nord,est (même que notre config)
    overpass_query = f"""
[out:json][timeout:180];
(
  way["highway"~"^({way_filter})$"]({bbox});
);
out geom;
"""
    url    = "https://overpass-api.de/api/interpreter"
    params = {"data": overpass_query.strip()}

    print(f"[{label}] Récupération des ways OSM (Overpass)...")
    resp = get_with_retry(session, url, params=params, label=label, base_delay=5.0)
    if resp is None:
        print(f"[{label}] Impossible de récupérer les ways OSM.")
        return []

    try:
        data = resp.json()
    except json.JSONDecodeError as exc:
        print(f"[{label}] Réponse Overpass invalide : {exc}")
        return []

    ways = []
    for elem in data.get("elements", []):
        if elem.get("type") != "way":
            continue
        geom = elem.get("geometry", [])
        if len(geom) < 2:
            continue
        coords = [[round(g["lon"], 6), round(g["lat"], 6)] for g in geom]
        ways.append({"id": elem["id"], "coords": coords})

    print(f"[{label}] {len(ways):,} ways OSM récupérés.")
    return ways


def snap_tickets_to_ways(
    tickets: List[Dict],
    ways: List[Dict],
    label: str = "",
) -> Dict[int, List[Dict]]:
    """
    Snape chaque ticket sur le way OSM le plus proche.
    Retourne un dict {way_id: [ticket, ...]}.
    """
    by_way: Dict[int, List[Dict]] = defaultdict(list)
    snapped = 0
    skipped = 0
    total   = len(tickets)

    print(f"[{label}] Snap des tickets sur les segments OSM...")

    for i, ticket in enumerate(tickets):
        if i % 10000 == 0 and i > 0:
            print(f"[{label}] Snap : {i:,}/{total:,}", end="\r")

        way_id = snap_to_ways(ticket["_lat"], ticket["_lon"], ways)
        if way_id is not None:
            by_way[way_id].append(ticket)
            snapped += 1
        else:
            skipped += 1

    print(
        f"[{label}] Snap terminé : {snapped:,} snappés sur {len(by_way):,} ways, "
        f"{skipped:,} ignorés (trop loin).        "
    )
    return dict(by_way)


# ═══════════════════════════════════════════════════════════════════════════════
# Étape 4 : Agrégation et inférence des règles
# ═══════════════════════════════════════════════════════════════════════════════

def parse_ticket_datetime(
    ticket: Dict, city_cfg: Dict
) -> Optional[Tuple[int, int, int, int]]:
    """
    Extrait (weekday 1-7, hour 0-23, month 1-12, year) d'un ticket.
    Retourne None si le parsing échoue.
    """
    date_str = ticket.get(city_cfg["date_field"], "")
    time_str = ticket.get(city_cfg["time_field"] or "", "") if city_cfg["time_field"] else ""

    if not date_str:
        return None

    try:
        # Socrata renvoie souvent ISO 8601 : "2023-04-15T00:00:00.000"
        date_part = date_str[:10]
        dt = datetime.strptime(date_part, "%Y-%m-%d")
    except ValueError:
        try:
            # Fallback MM/DD/YYYY
            dt = datetime.strptime(date_str[:10], "%m/%d/%Y")
        except ValueError:
            return None

    hour = 0
    if time_str:
        # Formats variés : "0830", "08:30", "8:30 AM"
        t = str(time_str).strip().replace(":", "")
        if "AM" in t.upper() or "PM" in t.upper():
            try:
                h = datetime.strptime(t.strip(), "%I%M%p")
                hour = h.hour
            except ValueError:
                pass
        else:
            try:
                t_clean = t[:4].zfill(4)
                hour = int(t_clean[:2])
                if not 0 <= hour <= 23:
                    hour = 0
            except (ValueError, IndexError):
                hour = 0

    weekday = dt.isoweekday()  # 1=Lun, 7=Dim
    return (weekday, hour, dt.month, dt.year)


def classify_violation(code: str, cleaning_codes: Dict[str, List[str]]) -> Optional[str]:
    """Retourne la catégorie de violation ou None si non pertinente."""
    code_norm = str(code).strip().upper()
    for category, codes in cleaning_codes.items():
        if code_norm in [c.strip().upper() for c in codes]:
            return category
    return None


def find_peak_windows(
    buckets: Dict[Tuple[int, int], Dict],
) -> List[Dict]:
    """
    Identifie les fenêtres temporelles (jour, heure) avec densité suffisante.

    buckets : {(weekday, hour): {"count": int, "years": set}}

    Règles de seuil :
    - count >= MIN_TICKETS_PER_BUCKET
    - len(years) >= MIN_YEARS_COVERED

    Fusionne les heures consécutives sur le même jour en une seule règle.
    Retourne liste de {"day": int, "hour_from": int, "hour_to": int}.
    """
    # Filtrer les buckets valides
    valid: Dict[int, List[int]] = defaultdict(list)  # weekday → [hours]
    for (wd, hr), info in buckets.items():
        if info["count"] >= MIN_TICKETS_PER_BUCKET and len(info["years"]) >= MIN_YEARS_COVERED:
            valid[wd].append(hr)

    windows = []
    for wd, hours in valid.items():
        hours_sorted = sorted(set(hours))
        if not hours_sorted:
            continue

        # Fusionner les heures consécutives
        groups: List[List[int]] = []
        current_group = [hours_sorted[0]]
        for h in hours_sorted[1:]:
            if h == current_group[-1] + 1:
                current_group.append(h)
            else:
                groups.append(current_group)
                current_group = [h]
        groups.append(current_group)

        for group in groups:
            windows.append({
                "day":       wd,
                "hour_from": group[0],
                "hour_to":   group[-1] + 1,  # exclusif → heure de fin
            })

    return windows


def detect_seasonal_pattern(months: List[int]) -> Tuple[Optional[int], Optional[int]]:
    """
    Détecte si les tickets sont concentrés dans une période saisonnière.
    Retourne (month_from, month_to) ou (None, None).
    Logique : si < 9 mois distincts représentent > 80 % des tickets,
    retourner min/max de ces mois.
    """
    if not months:
        return None, None

    total = len(months)
    from collections import Counter
    freq = Counter(months)

    # Trier par fréquence décroissante
    sorted_months = sorted(freq.items(), key=lambda x: -x[1])

    # Chercher le groupe minimal de mois consécutifs couvrant ≥ 80 %
    all_months = sorted(freq.keys())
    best_mf, best_mt = None, None

    for window_size in range(1, 10):
        for start_idx in range(len(all_months)):
            window = all_months[start_idx : start_idx + window_size]
            if len(window) < window_size:
                break
            coverage = sum(freq[m] for m in window) / total
            if coverage >= 0.80:
                if best_mf is None or window_size < (best_mt - best_mf + 1):
                    best_mf, best_mt = window[0], window[-1]
                break
        if best_mf is not None:
            break

    # N'appliquer la saisonnalité que si < 12 mois distincts (sinon année complète)
    if best_mf is not None and best_mt is not None:
        if best_mt - best_mf + 1 >= 12:
            return None, None  # Couverture annuelle complète
        return best_mf, best_mt

    return None, None


def infer_rules_for_way(
    way_id: int,
    tickets: List[Dict],
    city_cfg: Dict,
) -> List[Dict]:
    """
    Infère les règles de stationnement à partir des tickets d'un way.
    Retourne liste de règles format app Flutter.
    """
    cleaning_codes = city_cfg["cleaning_codes"]

    # Grouper par catégorie de violation
    by_category: Dict[str, List[Dict]] = defaultdict(list)
    for ticket in tickets:
        code = ticket.get(city_cfg["code_field"], "")
        cat  = classify_violation(str(code), cleaning_codes)
        if cat:
            by_category[cat].append(ticket)

    rules = []

    for category, cat_tickets in by_category.items():
        # Agréger par (weekday, hour)
        buckets: Dict[Tuple[int, int], Dict] = defaultdict(
            lambda: {"count": 0, "years": set()}
        )
        all_months = []

        for ticket in cat_tickets:
            parsed = parse_ticket_datetime(ticket, city_cfg)
            if parsed is None:
                continue
            wd, hr, mo, yr = parsed
            buckets[(wd, hr)]["count"] += 1
            buckets[(wd, hr)]["years"].add(yr)
            all_months.append(mo)

        if not buckets:
            continue

        windows = find_peak_windows(buckets)
        if not windows:
            continue

        mf, mt = detect_seasonal_pattern(all_months)

        # Regrouper les fenêtres par plage horaire identique → une règle par groupe
        # (même hour_from/hour_to sur plusieurs jours = une règle multi-jours)
        time_groups: Dict[Tuple[int, int], List[int]] = defaultdict(list)
        for w in windows:
            key = (w["hour_from"], w["hour_to"])
            time_groups[key].append(w["day"])

        for (hf, ht), days in time_groups.items():
            rule: Dict[str, Any] = {
                "d": sorted(days),
                "f": f"{hf:02d}:00",
                "t": f"{ht:02d}:00",
            }
            if mf is not None:
                rule["mf"] = mf
            if mt is not None:
                rule["mt"] = mt
            rules.append(rule)

    return rules


def infer_all_rules(
    by_way: Dict[int, List[Dict]],
    city_cfg: Dict,
    label: str = "",
) -> Dict[int, List[Dict]]:
    """
    Infère les règles pour tous les ways.
    Retourne {way_id: [rule, ...]} (ways sans règles exclus).
    """
    print(f"[{label}] Inférence des règles sur {len(by_way):,} ways...")
    result: Dict[int, List[Dict]] = {}

    for way_id, tickets in by_way.items():
        rules = infer_rules_for_way(way_id, tickets, city_cfg)
        if rules:
            result[way_id] = rules

    print(f"[{label}] {len(result):,} ways avec règles inférées.")
    return result


# ═══════════════════════════════════════════════════════════════════════════════
# Étape 5 : Récupération des géométries OSM
# ═══════════════════════════════════════════════════════════════════════════════

def fetch_way_geometries(
    way_ids: List[int],
    session: requests.Session,
    label: str = "",
) -> Dict[int, List[List[float]]]:
    """
    Récupère les géométries (liste de [lon, lat]) pour une liste d'OSM way IDs
    via Overpass. Traite par lots de 500 IDs pour éviter les timeouts.

    Retourne {way_id: [[lon, lat], ...]}.
    """
    if not way_ids:
        return {}

    BATCH = 500
    geoms: Dict[int, List[List[float]]] = {}
    total = len(way_ids)

    print(f"[{label}] Récupération des géométries pour {total:,} ways...")

    for i in range(0, total, BATCH):
        batch = way_ids[i : i + BATCH]
        ids_str = ",".join(str(wid) for wid in batch)
        query = f"[out:json][timeout:120];\nway(id:{ids_str});\nout geom;"

        url    = "https://overpass-api.de/api/interpreter"
        params = {"data": query}

        resp = get_with_retry(session, url, params=params, label=label, base_delay=5.0)
        if resp is None:
            print(f"[{label}] Échec récupération géométries batch {i//BATCH + 1}")
            continue

        try:
            data = resp.json()
        except json.JSONDecodeError:
            continue

        for elem in data.get("elements", []):
            if elem.get("type") != "way":
                continue
            geom = elem.get("geometry", [])
            if len(geom) < 2:
                continue
            coords = [[round(g["lon"], 6), round(g["lat"], 6)] for g in geom]
            geoms[elem["id"]] = coords

        print(f"[{label}] Géométries : {min(i+BATCH, total):,}/{total:,}", end="\r")
        time.sleep(1.0)  # Respecter Overpass

    print(f"[{label}] {len(geoms):,} géométries récupérées.        ")
    return geoms


# ═══════════════════════════════════════════════════════════════════════════════
# Étape 6 : Génération du JSON de sortie
# ═══════════════════════════════════════════════════════════════════════════════

def load_existing_city_data(city_id: str) -> Dict:
    """Charge le fichier existant ou retourne un squelette vide."""
    path = os.path.join(DATA_DIR, f"{city_id}.json")
    if os.path.exists(path):
        try:
            with open(path, encoding="utf-8") as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            pass
    return {"v": 1, "meters": [], "alternating": [], "cleaning": []}


def existing_segment_fingerprints(cleaning: List[Dict]) -> set:
    """
    Retourne un set d'empreintes des segments existants pour détecter les doublons.
    Empreinte = hash du point médian arrondi.
    """
    fingerprints = set()
    for seg in cleaning:
        coords = seg.get("c", [])
        if coords:
            mid = coords[len(coords) // 2]
            fp  = (round(mid[0], 4), round(mid[1], 4))
            fingerprints.add(fp)
    return fingerprints


def build_output_segments(
    way_rules: Dict[int, List[Dict]],
    way_geoms: Dict[int, List[List[float]]],
    existing_fps: set,
) -> List[Dict]:
    """
    Construit la liste de segments dans le format Flutter :
    {"c": [[lon,lat],...], "r": [{...}]}
    Exclut les segments déjà présents dans le fichier existant.
    """
    new_segments = []
    for way_id, rules in way_rules.items():
        coords = way_geoms.get(way_id)
        if not coords:
            continue

        mid = coords[len(coords) // 2]
        fp  = (round(mid[0], 4), round(mid[1], 4))
        if fp in existing_fps:
            continue  # Déjà couvert

        new_segments.append({"c": coords, "r": rules})

    return new_segments


def save_city_data(city_id: str, data: Dict) -> str:
    """Sauvegarde le JSON de la ville et retourne le chemin."""
    os.makedirs(DATA_DIR, exist_ok=True)
    path = os.path.join(DATA_DIR, f"{city_id}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    return path


# ═══════════════════════════════════════════════════════════════════════════════
# Pipeline principal pour une ville
# ═══════════════════════════════════════════════════════════════════════════════

def run_city(
    city_id: str,
    cache: GeocodeCache,
    session: requests.Session,
    max_tickets: int = 0,
) -> bool:
    """
    Exécute le pipeline complet pour une ville.
    Retourne True si succès, False si erreur fatale.
    """
    if city_id not in CITIES:
        print(f"[ERREUR] Ville inconnue : {city_id}")
        return False

    city_cfg = CITIES[city_id]
    label    = city_cfg["label"]

    print(f"\n{'='*60}")
    print(f"[{label}] Démarrage du pipeline")
    print(f"{'='*60}")

    try:
        # ── Étape 1 : Téléchargement ─────────────────────────────────────
        tickets = download_tickets(city_id, city_cfg, session, max_tickets=max_tickets)
        if not tickets:
            print(f"[{label}] Aucun ticket téléchargé — abandon.")
            return False

        # ── Étape 2 : Géocodage ──────────────────────────────────────────
        tickets_geocoded = geocode_tickets(city_id, city_cfg, tickets, cache, session)
        if not tickets_geocoded:
            print(f"[{label}] Aucun ticket géocodé — abandon.")
            return False

        # ── Étape 3 : Chargement des ways OSM + snap ─────────────────────
        ways = fetch_osm_ways(city_cfg["bbox"], session, label=label)
        if not ways:
            print(f"[{label}] Aucun way OSM récupéré — abandon.")
            return False

        by_way = snap_tickets_to_ways(tickets_geocoded, ways, label=label)
        if not by_way:
            print(f"[{label}] Aucun ticket snappé — abandon.")
            return False

        # ── Étape 4 : Inférence des règles ───────────────────────────────
        way_rules = infer_all_rules(by_way, city_cfg, label=label)
        if not way_rules:
            print(f"[{label}] Aucune règle inférée — abandon.")
            return False

        # ── Étape 5 : Géométries OSM ─────────────────────────────────────
        way_geoms = fetch_way_geometries(
            list(way_rules.keys()), session, label=label
        )

        # ── Étape 6 : Merge + sauvegarde ─────────────────────────────────
        existing = load_existing_city_data(city_id)
        existing_fps = existing_segment_fingerprints(existing.get("cleaning", []))

        new_segments = build_output_segments(way_rules, way_geoms, existing_fps)

        if not new_segments:
            print(f"[{label}] Aucun nouveau segment (tout déjà couvert).")
            # Sauvegarder quand même pour mettre à jour le timestamp
        else:
            existing["cleaning"].extend(new_segments)

        out_path = save_city_data(city_id, existing)
        size_kb  = os.path.getsize(out_path) / 1024

        print(
            f"\n[{label}] Inféré {len(new_segments):,} règles depuis "
            f"{len(tickets):,} tickets → {out_path} ({size_kb:.0f} KB)"
        )
        return True

    except KeyboardInterrupt:
        raise
    except Exception as exc:
        print(f"[{label}] ERREUR INATTENDUE : {exc}")
        import traceback
        traceback.print_exc()
        return False


# ═══════════════════════════════════════════════════════════════════════════════
# Point d'entrée
# ═══════════════════════════════════════════════════════════════════════════════

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "ParkSmart — Pipeline d'inférence de règles de stationnement\n"
            "à partir des données de tickets open-data (Socrata).\n\n"
            "Re-run mensuel recommandé."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--city",
        required=True,
        choices=list(CITIES.keys()) + ["all"],
        help="Ville à traiter (nyc, chicago, la, sf, all)",
    )
    parser.add_argument(
        "--max-tickets",
        type=int,
        default=0,
        metavar="N",
        help="Limite le nombre de tickets téléchargés (0 = pas de limite, pour tests)",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    cities_to_run = list(CITIES.keys()) if args.city == "all" else [args.city]

    print(f"ParkSmart — infer_rules_tickets.py")
    print(f"Villes : {', '.join(c.upper() for c in cities_to_run)}")
    print(f"Fenêtre : {YEARS_BACK} dernières années")
    if args.max_tickets:
        print(f"Mode test : max {args.max_tickets:,} tickets par ville")
    print(f"Cache géocodage : {CACHE_DB}")
    print()

    cache   = GeocodeCache(CACHE_DB)
    session = make_session()

    results: Dict[str, bool] = {}

    try:
        for city_id in cities_to_run:
            results[city_id] = run_city(
                city_id,
                cache   = cache,
                session = session,
                max_tickets = args.max_tickets,
            )
    except KeyboardInterrupt:
        print("\n\nInterrompu par l'utilisateur.")
    finally:
        cache.close()

    # ── Résumé final ──────────────────────────────────────────────────────────
    print(f"\n{'='*60}")
    print("Résumé")
    print(f"{'='*60}")
    for city_id, ok in results.items():
        label  = CITIES[city_id]["label"]
        status = "OK" if ok else "ERREUR"
        print(f"  [{label}] {status}")

    failures = [c for c, ok in results.items() if not ok]
    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
