#!/usr/bin/env python3
"""
build_quebec_city.py — Quebec City parking data collection

Data sources:
  1. Ville de Québec: "Stationnement - Réglementation" (Street parking rules)
  2. Ville de Québec: Open data portal (https://www.donneesquebec.ca/)
  3. OpenStreetMap: parking:lane tags (fallback)

Coverage target: 15-25% (street segments with known rules)
Zones: Vieux-Québec, Saint-Sauveur, Saint-Jean-Baptiste, Montcalm, etc.
"""

import json
import os
from pathlib import Path

def build_quebec_city_data():
    """Build Quebec City parking data from available sources."""

    output_dir = Path("assets/data")
    output_dir.mkdir(parents=True, exist_ok=True)
    output_file = output_dir / "quebec_city.json"

    # Quebec City parking data structure
    quebec_data = {
        "v": 1,
        "meters": [],
        "alternating": [],
        "cleaning": []
    }

    # Quebec City has complex parking rules:
    # - No parking at meters (mostly free parking with time limits)
    # - Time-limited parking on many streets (2h, 3h, 4h limits)
    # - Residential zones with permit requirements
    # - Street cleaning restrictions (alternating side parking)
    # - Winter parking ban (November 15 - April 15)

    # NOTE: Quebec City data requires:
    # - Ville de Québec open data API / CSV export
    # - Address geocoding (Nominatim works well with Quebec City addresses)
    # - OSM way snapping

    # STREET PARKING RULES (Time-limited)
    # Most Quebec City streets: 2-4 hour time limits
    # Typically: 9 AM - 5 PM, Mon-Fri (commercial zones)
    # Some streets: No parking 7 AM - 9 AM (rush hour)

    # STREET CLEANING (Alternating sides)
    # Quebec City requires parking on alternate sides for street cleaning
    # Typically: cleaning on specific days (schedule varies by district)

    # WINTER PARKING BAN (Seasonal)
    # Quebec City has winter parking restrictions:
    # - Ban May 1 - Sept 15: Odd/even alternating
    # - No Ban Sept 16 - April 30: Free parking (with time limits)
    # - Emergency ban Nov 15 - April 15: All parking banned certain hours

    print("[QUEBEC_CITY] Generating Quebec City parking data structure...")

    # Example alternating rule (winter odd/even parking):
    # quebec_data["alternating"].append({
    #     "n": "Rue de la Fabrique",
    #     "w": 123456789,  # OSM way ID
    #     "z": "Vieux-Québec",
    #     "c": [[-71.2066, 46.8140], [-71.2070, 46.8145]],  # coordinates
    #     # Monthparity: 1=odd days, 2=even days
    #     # May 1 (month 5, day 1) = start of odd/even season
    # })

    # For Phase 1, use baseline fallback
    # Real data requires:
    # 1. Ville de Québec open data download
    # 2. CSV/Excel parsing
    # 3. Address geocoding
    # 4. OSM way snapping

    print(f"[QUEBEC_CITY] OK Output: {output_file}")

    # Write output
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(quebec_data, f, ensure_ascii=False, separators=(",", ":"))

    file_size = os.path.getsize(output_file)
    print(f"[QUEBEC_CITY] Size: {file_size:,} bytes")
    print(f"[QUEBEC_CITY] Meters: {len(quebec_data['meters'])}")
    print(f"[QUEBEC_CITY] Alternating: {len(quebec_data['alternating'])}")
    print(f"[QUEBEC_CITY] Cleaning: {len(quebec_data['cleaning'])}")
    print("[QUEBEC_CITY] NOTE: Real data requires Ville de Quebec API integration")
    print("[QUEBEC_CITY] Data sources:")
    print("  - Ville de Québec Open Data: https://www.donneesquebec.ca/")
    print("  - Stationnement: https://www.ville.quebec.qc.ca/citoyens/stationnement/")
    print("[QUEBEC_CITY] Special rules:")
    print("  - Odd/even alternating (May 1 - Sept 15)")
    print("  - Time-limited parking 2-4h (most streets)")
    print("  - Winter ban (Nov 15 - April 15)")
    print("  - Street cleaning alternating sides")


if __name__ == "__main__":
    build_quebec_city_data()
