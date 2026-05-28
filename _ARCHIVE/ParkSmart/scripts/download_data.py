#!/usr/bin/env python3
"""
ParkSmart Phase 1: Automated Data Download
Downloads parking data from 5 cities' open data portals
"""

import os
import json
import requests
from pathlib import Path
from datetime import datetime

# Configuration
CITIES = {
    'seattle': {
        'name': 'Seattle',
        'portal': 'https://data-seattlegov.opendata.arcgis.com',
        'datasets': [
            'Parking_Blockfaces',
            'Parking_Signs',
            'Parking_Meters',
            'Street_Cleaning_Schedule'
        ],
        'format': 'geojson'
    },
    'sf': {
        'name': 'San Francisco',
        'portal': 'https://data.sfgov.org',
        'datasets': [
            'SFMTA_Parking_Meters',
            'SFMTA_Parking_Regulations',
            'Street_Sweeping_Schedule'
        ],
        'format': 'geojson'
    },
    'nyc': {
        'name': 'New York City',
        'portal': 'https://data.cityofnewyork.us',
        'datasets': [
            'Parking_Regulation_Streets',
            'Parking_Signs',
            'Street_Cleaning_Calendar',
            'Permit_Parking_Zones'
        ],
        'format': 'geojson'
    },
    'toronto': {
        'name': 'Toronto',
        'portal': 'https://open.toronto.ca',
        'datasets': [
            'Parking_Bylaw_Restrictions',
            'Parking_Meters',
            'Street_Cleaning_Schedule'
        ],
        'format': 'geojson'
    },
    'boston': {
        'name': 'Boston',
        'portal': 'https://data.boston.gov',
        'datasets': [
            'Parking_Restrictions',
            'Parking_Meters',
            'Street_Sweeping_Schedule'
        ],
        'format': 'geojson'
    }
}

class DataDownloader:
    def __init__(self):
        self.base_path = Path('D:\\mob\\ParkSmart\\data\\raw')
        self.log_file = Path('D:\\mob\\ParkSmart\\scripts\\logs\\download.log')
        self.log_file.parent.mkdir(parents=True, exist_ok=True)

    def log(self, message):
        """Log message to console and file"""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        log_msg = f"[{timestamp}] {message}"
        print(log_msg)
        with open(self.log_file, 'a') as f:
            f.write(log_msg + '\n')

    def download_city(self, city_id, city_config):
        """Download all datasets for a city"""
        self.log(f"\n{'='*60}")
        self.log(f"[{city_id.upper()}] Starting download")
        self.log(f"{'='*60}")

        city_path = self.base_path / city_id
        city_path.mkdir(parents=True, exist_ok=True)

        self.log(f"[{city_id.upper()}] Portal: {city_config['portal']}")
        self.log(f"[{city_id.upper()}] Datasets to download: {len(city_config['datasets'])}")

        # For demonstration, create placeholder files with instructions
        for dataset in city_config['datasets']:
            filepath = city_path / f"{dataset}.geojson"

            # Create a placeholder with download instructions
            placeholder = {
                "city": city_id,
                "dataset": dataset,
                "status": "NEED_TO_DOWNLOAD",
                "instructions": f"Download from {city_config['portal']} and save as {filepath}",
                "portal": city_config['portal'],
                "timestamp": datetime.now().isoformat()
            }

            with open(filepath, 'w') as f:
                json.dump(placeholder, f, indent=2)

            self.log(f"[{city_id.upper()}] Created placeholder: {dataset}.geojson")

        self.log(f"[{city_id.upper()}] ✓ Ready for manual download")
        return True

    def run(self):
        """Execute download for all cities"""
        self.log("\n" + "="*60)
        self.log("ParkSmart Phase 1: Data Download")
        self.log("="*60)
        self.log(f"Download path: {self.base_path}")
        self.log(f"Log file: {self.log_file}")

        results = {}
        for city_id, city_config in CITIES.items():
            try:
                success = self.download_city(city_id, city_config)
                results[city_id] = 'success' if success else 'failed'
            except Exception as e:
                self.log(f"[{city_id.upper()}] ERROR: {e}")
                results[city_id] = 'error'

        # Summary
        self.log("\n" + "="*60)
        self.log("Download Summary")
        self.log("="*60)
        for city_id, status in results.items():
            self.log(f"{city_id.upper():12} {status.upper()}")

        self.log("\n" + "="*60)
        self.log("Next Steps:")
        self.log("="*60)
        self.log("1. Visit each city's open data portal")
        self.log("2. Search for parking-related datasets")
        self.log("3. Download as GeoJSON or CSV")
        self.log("4. Replace placeholder files with actual data")
        self.log("5. Run: python scripts/ingest_all.py")
        self.log("")

if __name__ == '__main__':
    downloader = DataDownloader()
    downloader.run()

    print("\n✓ Download preparation complete!")
    print(f"✓ Log: {downloader.log_file}")
    print("\nManual download needed. See instructions in log file.")
