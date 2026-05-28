#!/usr/bin/env python3
"""
build_toronto.py — Toronto parking data collection

Data sources:
  1. Toronto Open Data: "Parking Meters" (City of Toronto)
  2. Toronto Open Data: "Parking Bylaw Restrictions by Ward" (City of Toronto)
  3. OpenStreetMap: parking:lane tags (fallback)

Coverage target: 20-30% (street segments with known parking rules)
"""

import json
import os
from pathlib import Path

def build_toronto_data():
    """Build Toronto parking data from available sources."""

    output_dir = Path("assets/data")
    output_dir.mkdir(parents=True, exist_ok=True)
    output_file = output_dir / "toronto.json"

    # Toronto parking data structure
    toronto_data = {
        "v": 1,
        "meters": [],
        "alternating": [],
        "cleaning": []
    }

    # NOTE: Toronto Open Data APIs are available but require:
    # - CKAN API authentication (optional)
    # - Nominatim/Google geocoding for address → lat/lon
    # - OSM snapping for addresses → ways

    # For now, include placeholder data + structure
    # This will be populated when:
    # 1. Toronto Open Data API is called
    # 2. Addresses are geocoded
    # 3. Data is snapped to OSM ways

    # METER DATA (Toronto Parking Authority)
    # Expected sources: toronto.ca/open-data
    # - Parking meter locations
    # - Rate by zone
    # - Operating hours (typically 8 AM - 10 PM, Mon-Sun)
    # Once API is live, data will be fetched here

    # Example structure (will be populated):
    # toronto_data["meters"] = [
    #     {
    #         "x": -79.3866,      # longitude
    #         "y": 43.6629,       # latitude
    #         "c": 150,           # min stay (minutes) - typical: 150 (2.5h)
    #         "p": [
    #             {
    #                 "d": [1,2,3,4,5,6,7],  # days (Mon-Sun)
    #                 "f": "08:00",          # from
    #                 "t": "22:00",          # to
    #                 "m": 150               # max stay (minutes)
    #             }
    #         ]
    #     }
    # ]

    # ALTERNATING STREET PARKING (Odd/Even)
    # Toronto has limited alternating parking compared to Montreal
    # Some areas have seasonal restrictions (winter ban, etc.)

    # STREET CLEANING (Alternating use schedule)
    # Toronto Street Cleaning schedule from open data
    # Typically: restrict parking 2 hours per week for street cleaning

    # For Phase 1, use baseline fallback
    # Real data requires:
    # 1. Toronto Open Data portal integration
    # 2. Address geocoding pipeline
    # 3. OSM way snapping

    print("[TORONTO] Generating Toronto parking data structure...")

    # Write output
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(toronto_data, f, ensure_ascii=False, separators=(",", ":"))

    file_size = os.path.getsize(output_file)
    print(f"[TORONTO] OK Output: {output_file}")
    print(f"[TORONTO] Size: {file_size:,} bytes")
    print(f"[TORONTO] Meters: {len(toronto_data['meters'])}")
    print(f"[TORONTO] Alternating: {len(toronto_data['alternating'])}")
    print(f"[TORONTO] Cleaning: {len(toronto_data['cleaning'])}")
    print("[TORONTO] NOTE: Real data requires Toronto Open Data API integration")
    print("[TORONTO] Data sources:")
    print("  - Toronto Parking Meters: https://open.toronto.ca/dataset/parking-meters/")
    print("  - Parking Restrictions: https://open.toronto.ca/dataset/parking-bylaw-restrictions-by-ward/")


if __name__ == "__main__":
    build_toronto_data()
