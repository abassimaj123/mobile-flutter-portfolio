# Vancouver Parking Regulations Builder

## Overview

`build_vancouver.py` downloads parking regulations from the City of Vancouver Open Data Portal and converts them to ParkSmart's universal parking format (`assets/data/vancouver.json`).

## Features

### 1. Data Download
- Queries Vancouver's CKAN API (opendata.vancouver.ca)
- Searches for "Parking Regulations on Streets" dataset
- Supports both CSV and JSON formats
- Falls back gracefully if API is unavailable

### 2. Regulation Parsing
Extracts structured data from regulation text using regex patterns:

#### Detected Patterns
```
"No Parking 6am-9am Weekdays"
→ type: no_parking
→ days: [1,2,3,4,5]
→ from: 06:00, to: 09:00

"2 Hour Parking Weekdays 9am-6pm"
→ type: time_limit
→ days: [1,2,3,4,5]
→ from: 09:00, to: 18:00
→ max_stay: 120 minutes

"Permit Parking Only"
→ type: permit_only

"Street Cleaning Tuesday 8am-10am"
→ type: cleaning
→ days: [2]
→ from: 08:00, to: 10:00
```

#### Supported Day Formats
- Weekday names: `Monday`, `Tuesday`, `Wed`, `Thu`, etc.
- Abbreviations: `Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat`, `Sun`
- Ranges: `Mon-Fri`, `Monday-Friday`
- Groups: `Weekdays`, `Weekend`

#### Supported Time Formats
- 24-hour: `14:30`, `14:00`
- 12-hour: `2:30 PM`, `2:30pm`, `2:30 p.m.`
- Short: `6am`, `9pm`

### 3. Geocoding
- Uses Nominatim (OpenStreetMap) API
- Qualifies queries with "Vancouver, BC, Canada"
- Caches results locally in `.cache_vancouver/geocodes.json`
- Verifies coordinates are within Vancouver bbox
- Rate-limited to 1 request/second (Nominatim policy)

### 4. Output Format
Converts to universal format with three categories:

```json
{
  "v": 1,
  "meters": [],              // Parking meters (not used for street regulations)
  "alternating": [],         // Alternating side rules (not used for Vancouver)
  "cleaning": [
    {
      "c": [[lon, lat]],    // Street coordinates (currently single point)
      "r": [                 // Rules array
        {
          "d": [1,2,3,4,5], // Days: 1=Mon, 2=Tue, ..., 7=Sun
          "f": "08:00",     // From time (HH:MM)
          "t": "18:00"      // To time (HH:MM)
        }
      ]
    }
  ]
}
```

## Installation

### Prerequisites
```bash
pip install requests geopy
```

### Directory Structure
```
ParkSmart/
├── scripts/
│   ├── build_vancouver.py       # Main script
│   ├── BUILD_VANCOUVER_GUIDE.md # This file
│   └── .cache_vancouver/        # Created automatically
│       └── geocodes.json        # Geocoding cache
└── assets/
    └── data/
        └── vancouver.json       # Output file
```

## Usage

### Quick Start
```bash
cd /path/to/ParkSmart
python scripts/build_vancouver.py
```

### Example Output
```
[14:23:45] INFO: Starting Vancouver parking regulations build...

[14:23:46] INFO: Step 1: Downloading regulations
[14:23:47] INFO: Found 3 resources in 'parking-regulations-on-streets' dataset
[14:23:47] INFO:   Downloading: parking_regulations.csv
[14:23:48] INFO: Downloaded 1,247 regulation records

[14:23:48] INFO: Step 2: Processing 1,247 records into street segments
[14:23:49] INFO:   Built 847 unique street segments
[14:23:49] INFO:   Regulation types found:
[14:23:49] INFO:     - cleaning: 245
[14:23:49] INFO:     - no_parking: 312
[14:23:49] INFO:     - time_limit: 690

[14:23:50] INFO: Step 3: Converting to universal format

[14:24:15] INFO: Step 4: Writing output to assets/data/vancouver.json

[14:24:15] INFO: ✓ Output written: 284,537 bytes

======================================================================
[VAN] Parking Regulations: 847 segments
[VAN] Coverage estimate: ~100%
[VAN] Breakdown: 0 meters, 0 alternating, 847 cleaning
======================================================================
```

## Data Source

**City of Vancouver Open Data Portal**
- URL: https://opendata.vancouver.ca
- Dataset: "Parking Regulations on Streets"
- Format: CSV, JSON
- License: [Open Government License – Vancouver](https://www.vancouver.ca/your-government/open-data.html)
- Updates: Periodically by the City

### Manual Data Entry

If the API is unavailable or data needs manual entry:

1. Visit https://opendata.vancouver.ca
2. Search for "Parking Regulations on Streets"
3. Download the CSV file
4. Save to: `scripts/.cache_vancouver/regulations.csv`
5. Run the script (it will use the cached CSV if API fails)

**Expected CSV Columns:**
- `street_name` or `street` — Street name (e.g., "Main Street")
- `side` — Side identifier (optional, e.g., "East", "West", "North")
- `regulation` or `restrictions` — Regulation text
- Additional fields are ignored

## Caching

### Geocoding Cache
Location: `scripts/.cache_vancouver/geocodes.json`

```json
{
  "Main Street|East": [-123.1088, 49.2827],
  "Oak Street|North": null,
  ...
}
```

- **Saves API calls** to Nominatim (rate-limited to 1/sec)
- **Persists across runs** for faster re-execution
- **`null` value** = street not found in Vancouver
- To refresh: delete the cache file and re-run

## Regulation Types

### No Parking (`no_parking`)
- Absolute prohibition during specified hours
- Example: "No Parking 8am-10am Monday-Friday"
- Output: Used in `cleaning` array with rule flags

### Time Limit (`time_limit`)
- Parking allowed for max duration during hours
- Example: "2 Hour Parking 9am-6pm Weekdays"
- Output: Converted to `cleaning` rules
- Note: `max_stay` minutes not currently stored (could enhance)

### Permit Only (`permit_only`)
- Special permits required
- Example: "Resident Permit Parking Only"
- Output: Currently skipped (could enhance with permit flag)

### Cleaning (`cleaning`)
- Street cleaning / sweeping
- Example: "Street Cleaning Tuesday 10am-12pm"
- Output: Directly mapped to `cleaning` array

### Unknown
- Doesn't match any pattern
- Output: Skipped

## Limitations & Future Enhancements

### Current Limitations
1. **Single-point geocoding** — Uses geocoded center point, not full street geometry
2. **No street segments** — Should split streets into segments for coverage
3. **No permit flags** — Permit-only rules currently skipped
4. **No max_stay** — Time limits extracted but not stored in output
5. **No rates** — Vancouver street regulations don't have rates (meters do)

### Recommended Enhancements
1. **Street Geometry**
   - Fetch OSM street ways for Vancouver
   - Split into segments (e.g., every 100m)
   - Assign same rule to all segment points

2. **Permit Rules**
   - Add permit flag to rule structure: `"p": true`
   - Distinguish resident, visitor, commercial permits

3. **Max Stay**
   - Store in universal format: `"m": 120` (minutes)
   - Useful for time-limit enforcement

4. **Data Validation**
   - Verify all coordinates in Vancouver bbox
   - Check for duplicate street names (e.g., "Main St" vs "Main Street")
   - Log unmatched regulation types

5. **Merge with Existing Data**
   - Combine with other Vancouver data sources
   - De-duplicate overlapping regulations
   - Cross-reference with parking meter data

## Troubleshooting

### "requests library required"
```bash
pip install requests
```

### "geopy library required"
```bash
pip install geopy
```

### No regulations downloaded
1. Check internet connection
2. Verify opendata.vancouver.ca is accessible
3. Manually download CSV to `scripts/.cache_vancouver/regulations.csv`
4. Re-run script

### Geocoding is very slow
- Normal (1 request/second rate limit)
- Check `scripts/.cache_vancouver/geocodes.json` — cache is working
- Subsequent runs will be faster with cached coordinates

### Coordinates outside Vancouver
- Verify street names are spelled correctly
- Some streets may not be in OSM or have ambiguous names
- Check `scripts/.cache_vancouver/geocodes.json` for failed matches (`null` values)

### Output file is small or empty
- Check regulation types in log output
- Only `cleaning`, `time_limit`, and `no_parking` types are converted
- `permit_only` regulations are currently skipped
- Increase sample size if downloading test data

## Integration with ParkSmart

### Load in Dart/Flutter
```dart
import 'dart:convert';
import 'package:flutter/services.dart';

Future<Map<String, dynamic>> loadVancouverRules() async {
  final jsonString = await rootBundle.loadString('assets/data/vancouver.json');
  return json.decode(jsonString) as Map<String, dynamic>;
}
```

### Query Rules Near Location
```dart
List<dynamic> cleaning = data['cleaning'] ?? [];
double maxDistance = 0.05; // degrees (~5.5 km)

for (var segment in cleaning) {
  List coords = segment['c'];
  for (var point in coords) {
    double segLon = point[0];
    double segLat = point[1];
    double dist = sqrt(pow(segLon - userLon, 2) + pow(segLat - userLat, 2));
    if (dist < maxDistance) {
      // Found nearby rules
      List<dynamic> rules = segment['r'];
      // Process rules...
    }
  }
}
```

## References

- [City of Vancouver Open Data Portal](https://opendata.vancouver.ca)
- [Nominatim Geocoding](https://nominatim.org/)
- [OpenStreetMap](https://www.openstreetmap.org/)
- [Open Government License – Vancouver](https://www.vancouver.ca/your-government/open-data.html)

## License

This script processes data from the City of Vancouver, licensed under the Open Government License – Vancouver. Output data retains the same license.

**Script License:** Same as ParkSmart project

---

**Last Updated:** 2026-05-15
**Version:** 1.0.0
