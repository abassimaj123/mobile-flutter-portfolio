#!/usr/bin/env python3
"""
test_montreal_pipeline.py
=========================
Test suite for the Montreal data pipeline.

Tests without external dependencies (uses local test fixtures).

Usage:
    python3 scripts/test_montreal_pipeline.py
"""

import sys
import json
from pathlib import Path
from typing import Dict, List

# Add scripts dir to path for imports
sys.path.insert(0, str(Path(__file__).parent))

# ──────────────────────────────────────────────────────────────────────────────
# Test Fixtures
# ──────────────────────────────────────────────────────────────────────────────

SAMPLE_CLEANING_GEOJSON = {
    "type": "FeatureCollection",
    "features": [
        {
            "type": "Feature",
            "properties": {
                "rue_nom_complet": "Rue Marquette",
                "arrondissement": "Plateau-Mont-Royal",
                "cote": "impair",
                "hre_debut": "07:00",
                "hre_fin": "12:00",
                "jrs_sem": "lundi",
                "per_deb": "avril",
                "per_fin": "mai"
            },
            "geometry": {
                "type": "LineString",
                "coordinates": [[-73.5768, 45.5285], [-73.5768, 45.5260], [-73.5768, 45.5245]]
            }
        },
        {
            "type": "Feature",
            "properties": {
                "rue_nom_complet": "Rue Masson",
                "arrondissement": "Rosemont-Petite-Patrie",
                "cote": "pair",
                "hre_debut": "08:00",
                "hre_fin": "13:00",
                "jrs_sem": "mercredi, vendredi",
                "per_deb": None,
                "per_fin": None
            },
            "geometry": {
                "type": "LineString",
                "coordinates": [[-73.5710, 45.5435], [-73.5650, 45.5435], [-73.5620, 45.5435]]
            }
        }
    ]
}

SAMPLE_SRRR_GEOJSON = {
    "type": "FeatureCollection",
    "features": [
        {
            "type": "Feature",
            "properties": {
                "nom_secteur": "Zone de Plateau-Mont-Royal",
                "type_permis": "Residential",
                "restriction_desc": "Permis résident requis lun-ven 09h-20h"
            },
            "geometry": {
                "type": "Polygon",
                "coordinates": [[
                    [-73.5750, 45.5270],
                    [-73.5750, 45.5300],
                    [-73.5700, 45.5300],
                    [-73.5700, 45.5270],
                    [-73.5750, 45.5270]
                ]]
            }
        }
    ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Test Helper Functions
# ──────────────────────────────────────────────────────────────────────────────

def test_parse_time():
    """Test time parsing utility."""
    from build_montreal_complete import parse_time

    tests = [
        ('7h', '07:00'),
        ('07:00', '07:00'),
        ('7:30', '07:30'),
        ('7h30', '07:30'),
        ('13:45', '13:45'),
        ('', None),
        (None, None),
    ]

    for input_val, expected in tests:
        result = parse_time(input_val)
        assert result == expected, f"parse_time({input_val!r}) = {result!r}, expected {expected!r}"
        print(f"  ✓ parse_time({input_val!r}) = {result!r}")

    print("✓ parse_time tests passed")

def test_parse_days():
    """Test day parsing utility."""
    from build_montreal_complete import parse_days

    tests = [
        ('lundi', [1]),
        ('lundi, mercredi', [1, 3]),
        ('lundi au vendredi', [1, 2, 3, 4, 5]),
        ('', list(range(1, 8))),
    ]

    for input_val, expected in tests:
        result = parse_days(input_val)
        assert result == expected, f"parse_days({input_val!r}) = {result!r}, expected {expected!r}"
        print(f"  ✓ parse_days({input_val!r}) = {result!r}")

    print("✓ parse_days tests passed")

def test_parse_month():
    """Test month parsing utility."""
    from build_montreal_complete import parse_month

    tests = [
        ('avril', 4),
        ('4', 4),
        ('mai', 5),
        ('decembre', 12),
        ('', None),
    ]

    for input_val, expected in tests:
        result = parse_month(input_val)
        assert result == expected, f"parse_month({input_val!r}) = {result!r}, expected {expected!r}"
        print(f"  ✓ parse_month({input_val!r}) = {result!r}")

    print("✓ parse_month tests passed")

def test_parse_parity():
    """Test parity parsing utility."""
    from build_montreal_complete import parse_parity

    tests = [
        ('pair', 0),
        ('côté pair', 0),
        ('impair', 1),
        ('côté impair', 1),
        ('', None),
    ]

    for input_val, expected in tests:
        result = parse_parity(input_val)
        assert result == expected, f"parse_parity({input_val!r}) = {result!r}, expected {expected!r}"
        print(f"  ✓ parse_parity({input_val!r}) = {result!r}")

    print("✓ parse_parity tests passed")

def test_coords_from_geometry():
    """Test geometry extraction."""
    from build_montreal_complete import coords_from_geometry

    # LineString
    geom = {
        "type": "LineString",
        "coordinates": [[-73.5768, 45.5285], [-73.5768, 45.5260]]
    }
    result = coords_from_geometry(geom)
    assert len(result) == 2
    assert result[0][0] == -73.5768
    print(f"  ✓ LineString extraction: {len(result)} points")

    # Polygon
    geom = {
        "type": "Polygon",
        "coordinates": [[[-73.5750, 45.5270], [-73.5700, 45.5300], [-73.5750, 45.5270]]]
    }
    result = coords_from_geometry(geom)
    assert len(result) > 0
    print(f"  ✓ Polygon extraction: {len(result)} points")

    print("✓ coords_from_geometry tests passed")

def test_midpoint():
    """Test midpoint calculation."""
    from build_montreal_complete import midpoint

    coords = [[-73.5768, 45.5285], [-73.5768, 45.5260], [-73.5768, 45.5245]]
    mid = midpoint(coords)
    assert mid == coords[1]  # Middle point
    print(f"  ✓ midpoint([...3 coords...]) = {mid}")

    print("✓ midpoint tests passed")

def test_geom_hash():
    """Test geometry hashing for deduplication."""
    from build_montreal_complete import geom_hash

    coords1 = [[-73.5768, 45.5285], [-73.5768, 45.5260]]
    hash1 = geom_hash(coords1)
    assert hash1 is not None
    assert len(hash1) == 12
    print(f"  ✓ geom_hash(coords) = {hash1}")

    # Same coords should hash to same value
    coords2 = [[-73.5768, 45.5285], [-73.5768, 45.5260]]
    hash2 = geom_hash(coords2)
    assert hash1 == hash2
    print(f"  ✓ Same coords → same hash")

    print("✓ geom_hash tests passed")

def test_process_cleaning_geojson():
    """Test cleaning GeoJSON processing."""
    from build_montreal_complete import process_cleaning_geojson

    segments, count = process_cleaning_geojson(SAMPLE_CLEANING_GEOJSON)

    assert len(segments) == 2
    assert count == 2

    seg1 = segments[0]
    assert seg1['n'] == 'Rue Marquette'
    assert seg1['z'] == 'Plateau-Mont-Royal'
    assert seg1['s'] == 'Côté impair'
    assert 'c' in seg1
    assert 'r' in seg1
    assert len(seg1['r']) > 0

    rule1 = seg1['r'][0]
    assert rule1['d'] == [1]  # lundi → 1
    assert rule1['f'] == '07:00'
    assert rule1['t'] == '12:00'
    assert rule1['mf'] == 4  # avril
    assert rule1['mt'] == 5  # mai
    assert rule1['dp'] == 1  # impair

    print(f"  ✓ Processed {len(segments)} cleaning segments")
    print(f"  ✓ Segment 1: {seg1['n']} ({seg1['z']}) - {seg1['s']}")
    print(f"  ✓ Rule 1: days={rule1['d']}, time={rule1['f']}-{rule1['t']}, months={rule1['mf']}-{rule1['mt']}")

    print("✓ process_cleaning_geojson tests passed")

def test_process_srrr_geojson():
    """Test SRRR GeoJSON processing."""
    from build_montreal_complete import process_srrr_geojson

    segments, zone_count = process_srrr_geojson(SAMPLE_SRRR_GEOJSON)

    assert len(segments) == 1
    assert zone_count == 1

    seg = segments[0]
    assert seg['n'] == 'Zone de Plateau-Mont-Royal'
    assert seg['z'] == 'Residential'
    assert 'c' in seg

    print(f"  ✓ Processed {zone_count} SRRR zones")
    print(f"  ✓ Zone: {seg['n']} (type={seg['z']})")

    print("✓ process_srrr_geojson tests passed")

def test_merge_structure():
    """Test that merge creates proper structure."""
    from build_montreal_complete import merge_with_existing
    import tempfile
    import os

    # Mock existing file
    existing_data = {
        "v": 1,
        "meters": [{"x": 1}],
        "alternating": [{"y": 2}],
        "cleaning": [
            {
                "n": "Rue Existante",
                "c": [[-73.5700, 45.5200], [-73.5700, 45.5210]],
                "r": [{"d": [1], "f": "07:00", "t": "12:00"}]
            }
        ]
    }

    new_cleaning = [
        {
            "n": "Rue Nouvelle",
            "c": [[-73.5768, 45.5285], [-73.5768, 45.5260]],
            "r": [{"d": [2], "f": "08:00", "t": "13:00"}]
        }
    ]

    new_srrr = []

    # Create temp file
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        temp_path = f.name
        json.dump(existing_data, f)

    try:
        # Mock the existing path
        import build_montreal_complete as bmc
        original_path = bmc.EXISTING_PATH
        bmc.EXISTING_PATH = temp_path

        merged = merge_with_existing(new_srrr, new_cleaning)

        # Verify structure
        assert 'v' in merged
        assert merged['v'] == 1
        assert 'meters' in merged
        assert len(merged['meters']) == 1
        assert 'alternating' in merged
        assert len(merged['alternating']) == 1
        assert 'cleaning' in merged
        # Should have both existing and new (not deduplicated in this test)
        assert len(merged['cleaning']) >= 1

        print(f"  ✓ Merged structure valid: v={merged['v']}")
        print(f"  ✓ Preserved meters: {len(merged['meters'])}")
        print(f"  ✓ Preserved alternating: {len(merged['alternating'])}")
        print(f"  ✓ Merged cleaning: {len(merged['cleaning'])}")

        bmc.EXISTING_PATH = original_path
    finally:
        os.unlink(temp_path)

    print("✓ merge_with_existing tests passed")

# ──────────────────────────────────────────────────────────────────────────────
# Main Test Runner
# ──────────────────────────────────────────────────────────────────────────────

def main():
    print("=" * 80)
    print("Montreal Data Pipeline — Test Suite")
    print("=" * 80)
    print()

    tests = [
        ("parse_time", test_parse_time),
        ("parse_days", test_parse_days),
        ("parse_month", test_parse_month),
        ("parse_parity", test_parse_parity),
        ("coords_from_geometry", test_coords_from_geometry),
        ("midpoint", test_midpoint),
        ("geom_hash", test_geom_hash),
        ("process_cleaning_geojson", test_process_cleaning_geojson),
        ("process_srrr_geojson", test_process_srrr_geojson),
        ("merge_with_existing", test_merge_structure),
    ]

    passed = 0
    failed = 0

    for test_name, test_func in tests:
        try:
            print(f"\n[{test_name}]")
            test_func()
            passed += 1
        except Exception as e:
            print(f"✗ FAILED: {e}")
            import traceback
            traceback.print_exc()
            failed += 1

    print()
    print("=" * 80)
    print(f"Results: {passed} passed, {failed} failed")
    print("=" * 80)

    return 0 if failed == 0 else 1

if __name__ == '__main__':
    sys.exit(main())
