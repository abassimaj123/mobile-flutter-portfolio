#!/usr/bin/env python3
"""
validate_montreal_output.py
===========================
Validates the output of build_montreal_complete.py

Usage:
    python3 scripts/validate_montreal_output.py [path/to/montreal.json]

Default: assets/data/montreal.json
"""

import json
import sys
import os
from pathlib import Path

def validate_segment(seg, seg_type='cleaning', idx=0):
    """Validate a single segment structure."""
    errors = []

    # Required fields
    required = {'c'}  # coordinates always required
    missing = required - set(seg.keys())
    if missing:
        errors.append(f"  [{seg_type}[{idx}]] Missing required fields: {missing}")

    # Validate coordinates
    coords = seg.get('c', [])
    if not isinstance(coords, list):
        errors.append(f"  [{seg_type}[{idx}]] 'c' must be array, got {type(coords)}")
    elif len(coords) > 0:
        for i, coord in enumerate(coords):
            if not isinstance(coord, list) or len(coord) != 2:
                errors.append(f"  [{seg_type}[{idx}].c[{i}]] Invalid coordinate: {coord}")
            else:
                lon, lat = coord
                if not (-180 <= lon <= 180):
                    errors.append(f"  [{seg_type}[{idx}].c[{i}]] Longitude out of range: {lon}")
                if not (-90 <= lat <= 90):
                    errors.append(f"  [{seg_type}[{idx}].c[{i}]] Latitude out of range: {lat}")

    # Validate cleaning rules if present
    if seg_type == 'cleaning' and 'r' in seg:
        rules = seg.get('r', [])
        if not isinstance(rules, list):
            errors.append(f"  [{seg_type}[{idx}]] 'r' must be array")
        else:
            for ri, rule in enumerate(rules):
                if not isinstance(rule, dict):
                    errors.append(f"  [{seg_type}[{idx}]].r[{ri}]] Rule must be dict")
                    continue

                # Validate days
                if 'd' in rule:
                    days = rule['d']
                    if not isinstance(days, list):
                        errors.append(f"  [{seg_type}[{idx}]].r[{ri}]].d must be array")
                    else:
                        for d in days:
                            if not isinstance(d, int) or not (1 <= d <= 7):
                                errors.append(f"  [{seg_type}[{idx}]].r[{ri}]].d contains invalid day: {d}")

                # Validate times
                for tkey in ['f', 't']:
                    if tkey in rule:
                        t = rule[tkey]
                        if not isinstance(t, str) or ':' not in t:
                            errors.append(f"  [{seg_type}[{idx}]].r[{ri}]].{tkey} invalid format: {t}")
                        else:
                            try:
                                h, m = t.split(':')
                                if not (0 <= int(h) <= 23 and 0 <= int(m) <= 59):
                                    errors.append(f"  [{seg_type}[{idx}]].r[{ri}]].{tkey} out of range: {t}")
                            except:
                                errors.append(f"  [{seg_type}[{idx}]].r[{ri}]].{tkey} not HH:MM: {t}")

                # Validate months
                for mkey in ['mf', 'mt']:
                    if mkey in rule:
                        m = rule[mkey]
                        if not isinstance(m, int) or not (1 <= m <= 12):
                            errors.append(f"  [{seg_type}[{idx}]].r[{ri}]].{mkey} out of range (1-12): {m}")

                # Validate parity
                if 'dp' in rule:
                    p = rule['dp']
                    if p not in (0, 1):
                        errors.append(f"  [{seg_type}[{idx}]].r[{ri}]].dp must be 0 or 1: {p}")

    return errors

def main():
    path = sys.argv[1] if len(sys.argv) > 1 else 'assets/data/montreal.json'

    if not os.path.exists(path):
        print(f"ERROR: File not found: {path}")
        sys.exit(1)

    print(f"Validating: {path}")
    print()

    try:
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"ERROR: Could not parse JSON: {e}")
        sys.exit(1)

    errors = []
    warnings = []

    # Validate structure
    if not isinstance(data, dict):
        print(f"ERROR: Root must be object")
        sys.exit(1)

    # Version
    if 'v' not in data:
        errors.append("Missing 'v' (version)")
    else:
        v = data['v']
        if not isinstance(v, int):
            errors.append(f"'v' must be integer: {v}")
        elif v != 1:
            warnings.append(f"'v' = {v}, expected 1")

    # Meters
    meters = data.get('meters', [])
    if not isinstance(meters, list):
        errors.append("'meters' must be array")
    else:
        print(f"✓ meters: {len(meters):,} spots")
        if len(meters) == 0:
            warnings.append("'meters' is empty")

    # Alternating
    alternating = data.get('alternating', [])
    if not isinstance(alternating, list):
        errors.append("'alternating' must be array")
    else:
        print(f"✓ alternating: {len(alternating):,} segments")
        if len(alternating) == 0:
            warnings.append("'alternating' is empty")

    # Cleaning
    cleaning = data.get('cleaning', [])
    if not isinstance(cleaning, list):
        errors.append("'cleaning' must be array")
    else:
        print(f"✓ cleaning: {len(cleaning):,} segments")
        if len(cleaning) == 0:
            warnings.append("'cleaning' is empty")

        # Sample validation (validate first 10, last 10)
        sample_indices = list(range(0, min(10, len(cleaning)))) + list(range(max(10, len(cleaning) - 10), len(cleaning)))
        sample_indices = sorted(set(sample_indices))

        for idx in sample_indices:
            seg_errors = validate_segment(cleaning[idx], 'cleaning', idx)
            errors.extend(seg_errors)

    # File size
    size = os.path.getsize(path)
    size_mb = size / (1024 * 1024)
    print(f"✓ File size: {size:,} bytes ({size_mb:.2f} MB)")

    # Summary
    print()
    if errors:
        print(f"❌ ERRORS ({len(errors)}):")
        for err in errors[:20]:  # Show first 20
            print(f"  {err}")
        if len(errors) > 20:
            print(f"  ... and {len(errors) - 20} more")
        print()
        sys.exit(1)
    else:
        print(f"✓ All validations passed!")

    if warnings:
        print(f"⚠ Warnings ({len(warnings)}):")
        for warn in warnings:
            print(f"  {warn}")
        print()

    sys.exit(0)

if __name__ == '__main__':
    main()
