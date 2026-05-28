#!/usr/bin/env python3
"""
test_coverage.py — Measure parking rule coverage and data quality per city.

Calculates:
  - Coverage % : rues avec au moins une règle / rues totales OSM
  - Density : nombre de règles par rue en moyenne
  - Spatial distribution : couverture uniforme ou clustérée ?
  - Inter-source agreement : % de rues avec données multi-sources
"""

import json
import sqlite3
import math
from collections import defaultdict
from pathlib import Path


def haversine_m(lat1, lon1, lat2, lon2):
    """Distance en mètres entre deux points."""
    R = 6371000  # mètres
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(math.radians(lat1))
        * math.cos(math.radians(lat2))
        * math.sin(dlon / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


class CoverageAnalyzer:
    def __init__(self, city_id, city_bbox):
        self.city_id = city_id
        self.city_bbox = city_bbox  # (lat_min, lon_min, lat_max, lon_max)
        self.data_file = Path(f'assets/data/{city_id}.json')
        self.osm_ways = {}
        self.rules_by_way = defaultdict(list)
        self.osm_ways_count = 0

    def load_city_data(self):
        """Load rules from assets/data/{cityId}.json"""
        if not self.data_file.exists():
            print(f'[{self.city_id}] Data file not found: {self.data_file}')
            return False

        try:
            with open(self.data_file, 'r', encoding='utf-8') as f:
                data = json.load(f)

            # Collect all segments (meters + cleaning)
            self.rules_by_way.clear()

            # Meters (if any)
            for meter in data.get('meters', []):
                lon, lat = meter.get('x'), meter.get('y')
                way_id = hash((round(lon, 4), round(lat, 4)))  # pseudo way ID
                self.rules_by_way[way_id].append(('meter', meter.get('c', 0)))

            # Alternating
            for alt in data.get('alternating', []):
                coords = alt.get('c', [])
                if coords:
                    mid_lon, mid_lat = coords[len(coords) // 2]
                    way_id = hash((round(mid_lon, 4), round(mid_lat, 4)))
                    self.rules_by_way[way_id].append(('alternating', alt))

            # Cleaning
            for clean in data.get('cleaning', []):
                coords = clean.get('c', [])
                if coords:
                    mid_lon, mid_lat = coords[len(coords) // 2]
                    way_id = hash((round(mid_lon, 4), round(mid_lat, 4)))
                    self.rules_by_way[way_id].append(('cleaning', clean))

            return True
        except Exception as e:
            print(f'[{self.city_id}] Error loading data: {e}')
            return False

    def estimate_osm_ways(self):
        """Estimate total OSM ways in city using Overpass (stub for now)."""
        # This would call Overpass API in reality.
        # For now, use rough estimates based on city size.
        estimates = {
            # Canada
            'capitale':    28000,  # Québec + Lévis (CityRegistry id)
            'montreal':    85000,
            'toronto':     95000,
            'quebec_city': 28000,  # alias gardé pour compatibilité
            'vancouver':   22000,  # City of Vancouver (compact)
            # USA West
            'seattle':     22000,
            'sf':          25000,
            'la':          80000,  # LA proper (not metro)
            # USA East/Midwest
            'nyc':        120000,
            'boston':      12000,
            'chicago':     40000,  # Chicago city proper
            # New quick-win cities
            'ottawa':      35000,  # Ottawa city proper
            'calgary':     50000,  # Calgary city proper
            'dc':          15000,  # DC compact
            'portland':    30000,  # Portland proper
            'philly':      45000,  # Philadelphia proper
            'denver':      35000,  # Denver proper
            'austin':      40000,  # Austin proper
        }
        self.osm_ways_count = estimates.get(self.city_id, 50000)

    def calculate_coverage(self):
        """Coverage % = ways with rules / total OSM ways."""
        if self.osm_ways_count == 0:
            return 0.0
        return (len(self.rules_by_way) / self.osm_ways_count) * 100

    def calculate_density(self):
        """Avg rules per way (among ways with data)."""
        if not self.rules_by_way:
            return 0.0
        return sum(len(rules) for rules in self.rules_by_way.values()) / len(
            self.rules_by_way
        )

    def calculate_spatial_distribution(self):
        """
        Measure spatial clustering.
        High clustering = bad (data only in downtown).
        Uniform = good.

        Returns: clustering_score (0.0=uniform, 1.0=clustered)
        """
        if len(self.rules_by_way) < 10:
            return None

        # Simple heuristic: if all rules within 2 km radius, clustering_score=1
        # Otherwise, distribute the clustering score based on variance.
        lat_min, lon_min, lat_max, lon_max = self.city_bbox

        # Sample coordinates from rules
        coords = []
        for rules in list(self.rules_by_way.values())[:100]:  # Sample 100
            if isinstance(rules[0], tuple) and len(rules[0]) > 1:
                coords.append(rules[0][1])

        if len(coords) < 2:
            return None

        # Calc center
        center_lat = sum(c[0] if isinstance(c, (list, tuple)) else 0 for c in coords) / len(coords)
        center_lon = sum(c[1] if isinstance(c, (list, tuple)) else 0 for c in coords) / len(coords)

        # Calc avg distance from center
        avg_dist = sum(
            haversine_m(center_lat, center_lon, c[0], c[1])
            if isinstance(c, (list, tuple))
            else 0
            for c in coords
        ) / len(coords)

        # Max distance for bbox
        max_dist = haversine_m(lat_min, lon_min, lat_max, lon_max)

        # Clustering score: 0 = uniform, 1 = all in one spot
        return 1.0 - min(avg_dist / max_dist, 1.0)

    def report(self):
        """Print coverage report."""
        self.load_city_data()
        self.estimate_osm_ways()

        coverage = self.calculate_coverage()
        density = self.calculate_density()
        spatial = self.calculate_spatial_distribution()

        print(f'\n[{self.city_id.upper()}] Coverage Report')
        print(f'  OSM ways (estimated): {self.osm_ways_count:,}')
        print(f'  Ways with rules: {len(self.rules_by_way):,}')
        print(f'  Coverage: {coverage:.1f}%')
        print(f'  Density (rules/way): {density:.2f}')
        if spatial is not None:
            print(f'  Clustering: {spatial:.2f} (0=uniform, 1=clustered)')
        print()

        return {
            'city': self.city_id,
            'coverage': coverage,
            'density': density,
            'clustering': spatial,
            'ways_with_rules': len(self.rules_by_way),
            'total_ways_estimate': self.osm_ways_count,
        }


def main():
    """Test coverage — IDs MUST correspondre exactement au CityRegistry Dart.
    Seules les villes dans city_registry.dart génèrent un assets/data/{id}.json
    utilisé par l'app.  Les autres fichiers (seattle, toronto, boston) existent
    dans assets/data/ mais ne sont pas encore chargés par CityParkingService.
    """
    cities = [
        # ── villes dans CityRegistry (assets/data/{id}.json chargé par l'app) ──
        ('capitale',  (46.580, -71.600, 46.960, -70.880)),   # Québec + Lévis
        ('montreal',  (45.360, -74.050, 45.730, -73.340)),
        ('vancouver', (49.200, -123.220, 49.320, -123.020)),
        ('nyc',       (40.500, -74.260, 40.930, -73.700)),
        ('la',        (33.700, -118.670, 34.340, -118.160)),
        ('chicago',   (41.640, -87.940, 42.030, -87.520)),
        ('sf',        (37.630, -122.520, 37.830, -121.980)),
        # ── villes avec données mais pas encore dans CityRegistry ─────────────
        ('seattle',   (47.490, -122.460, 47.740, -122.220)),
        ('toronto',   (43.640, -79.640, 43.855, -79.115)),
        ('boston',    (42.300, -71.180, 42.420, -70.990)),
        # ── quick-win cities (OSM defaults pipeline) ─────────────────────────
        ('ottawa',    (45.250, -76.000, 45.550, -75.500)),
        ('calgary',   (50.850, -114.300, 51.180, -113.850)),
        ('dc',        (38.800, -77.120, 38.990, -76.910)),
        ('portland',  (45.430, -122.820, 45.650, -122.450)),
        ('philly',    (39.870, -75.300, 40.140, -74.950)),
        ('denver',    (39.600, -105.100, 39.850, -104.850)),
        ('austin',    (30.180, -97.900, 30.450, -97.600)),
    ]

    results = []
    for city_id, bbox in cities:
        analyzer = CoverageAnalyzer(city_id, bbox)
        result = analyzer.report()
        results.append(result)

    # Summary table
    print('=' * 70)
    print('SUMMARY TABLE')
    print('=' * 70)
    print(
        f'{"City":<12} {"Coverage %":>12} {"Density":>10} {"Clustering":>12} {"Ways":>10}'
    )
    print('-' * 70)
    for r in results:
        clustering_str = f'{r["clustering"]:.2f}' if r['clustering'] is not None else 'N/A'
        print(
            f'{r["city"]:<12} {r["coverage"]:>11.1f}% {r["density"]:>10.2f} '
            f'{clustering_str:>12} {r["ways_with_rules"]:>10,}'
        )
    print('=' * 70)

    # Average
    avg_coverage = sum(r['coverage'] for r in results) / len(results)
    print(f'\nAverage coverage across all cities: {avg_coverage:.1f}%')


if __name__ == '__main__':
    main()
