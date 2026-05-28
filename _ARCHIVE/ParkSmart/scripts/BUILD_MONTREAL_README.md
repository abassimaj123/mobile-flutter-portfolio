# Montreal Data Pipeline: build_montreal_complete.py

## Overview

`build_montreal_complete.py` is a comprehensive data pipeline that:

1. **Downloads SRRR** (Secteurs de stationnement réservé aux résidents)
   - Resident permit parking zone boundaries from Montreal open data
   - Zone IDs, names, permit types, and restrictions
   - Source: `donnees.montreal.ca` CKAN API

2. **Downloads Street Cleaning Schedule** (Calendrier de nettoyage des rues)
   - Complete city-wide street cleaning schedule with all segments
   - Street geometry, cleaning days/times, borough information
   - Direct GeoJSON download from Montreal open data

3. **Converts to Universal Format**
   - Transforms both datasets to `assets/data/montreal.json` structure:
   ```json
   {
     "v": 1,
     "meters": [...existing AMD data...],
     "alternating": [...existing alternating parking...],
     "cleaning": [
       {
         "n": "street name",
         "z": "borough",
         "c": [[lon,lat],[lon,lat],...],
         "r": [{"d":[1],"f":"07:00","t":"12:00","mf":4,"mt":5}]
       }
     ]
   }
   ```

4. **Merges with Existing Data**
   - Preserves existing `meters` and `alternating` segments
   - Deduplicates cleaning segments by geometry midpoint hash
   - Gracefully handles missing data with fallback demo datasets

## Usage

From ParkSmart project root:

```bash
python3 scripts/build_montreal_complete.py
```

**Dependencies:**
- Python 3.7+
- `requests` (optional; falls back to `urllib` if not installed)

## Output Example

```
================================================================================
Montreal Data Pipeline — SRRR + Street Cleaning
================================================================================

[SRRR] Searching Montreal open data...
  Found: Secteurs de stationnement réservé aux résidents
  Downloading: https://donnees.montreal.ca/...
  Segments: 24 | Skipped: 2

[SRRR] Total zones: 24

[CLEANING] Downloading street cleaning schedule...
  URL: https://donnees.montreal.ca/...
  Segments: 4200 | Skipped: 15

[CLEANING] Total streets: 4200

[MERGE] Merged with existing montreal.json
  Existing cleaning segments: 2500
  New cleaning segments: 4200
  Deduplicated total: 6123

================================================================================
[MTL] SRRR: 24 zones
[MTL] Street cleaning: 4200 segments
[MTL] Total: 12565 meters + 4700+ segments cleaning

✓ Output: assets/data/montreal.json
  Size: 3,654,321 bytes
================================================================================
```

## Data Format Reference

### Cleaning Segment Structure
```python
{
    "n": "Rue Marquette",              # Street name (name)
    "z": "Plateau-Mont-Royal",         # Zone/borough (zone)
    "s": "Côté impair",                # Side label (side)
    "c": [[-73.5768, 45.5285], ...],   # Coordinates (coordinates)
    "r": [                              # Rules array
        {
            "d": [1, 3, 5],             # Days (1=Mon, 7=Sun)
            "f": "07:00",               # From time
            "t": "12:00",               # To time
            "mf": 4,                    # Month from (optional)
            "mt": 5,                    # Month to (optional)
            "dp": 1                     # Day parity: 0=even, 1=odd (optional)
        }
    ]
}
```

### SRRR Segment Structure
```python
{
    "n": "Zone de Plateau-Mont-Royal", # Zone name
    "z": "Residential",                # Permit type/zone type
    "c": [[-73.5750, 45.5270], ...],   # Zone boundary coordinates
    "d": "Permis résident..."          # Description/restriction (optional)
}
```

## Features

### Graceful Fallbacks
- **No internet:** Uses embedded demo data
- **API changes:** Searches multiple field name variants
- **Malformed data:** Skips invalid segments, continues processing
- **Missing Montreal dataset:** Falls back to demo zones

### Deduplication
- Geometry-based deduplication using midpoint hash (4-decimal precision ≈ 10m)
- Prevents duplicate streets from multiple imports
- Preserves existing data while intelligently merging new datasets

### Data Validation
- Validates time formats (HH:MM)
- Validates day names (French, 1-7)
- Validates month names (French, 1-12)
- Handles null/missing fields gracefully

### UTF-8 Safe
- Windows-compatible output (cp1252 → UTF-8)
- Proper French character handling (é, è, ê, à, etc.)

## Integration with ParkSmart

The generated `assets/data/montreal.json` is used by:

1. **ParkingSensor** service (Dart)
   - Load schedules in background service
   - Calculate next cleaning time

2. **NettoyageService** (Dart)
   - Query restrictions by location
   - Display user-facing cleaning info

3. **Analytics & Reporting**
   - Monitor street coverage
   - Validate data quality

## Updating Data

Run this script quarterly to:
- Fetch latest Montreal open data
- Catch new streets/zones
- Update cleaning schedules

```bash
# Recommended: monthly or quarterly
python3 scripts/build_montreal_complete.py

# Validate output
wc -c assets/data/montreal.json
jq '.cleaning | length' assets/data/montreal.json
```

## Troubleshooting

### "Could not download" warning
- Check internet connection
- Verify Montreal open data API is accessible
- Script falls back to demo data automatically

### Incorrect field names
- Montreal datasets may rename columns
- Script tries 10+ variants per field
- Add more variants to `_JOUR_MAP`, `_MOIS_MAP`, field extraction

### Large file size
- ~3.6 MB is normal for complete Montreal dataset
- Compress with `gzip` for distribution if needed

### Deduplication not working
- Check geometry hash precision (currently 4 decimals = ~10m)
- Increase/decrease precision in `geom_hash()` function

## Related Scripts

- `gen_nettoyage_segments.py` — Legacy street cleaning importer (phase 1)
- `gen_alternating_segments.py` — Alternating parking parser
- `build_amd_asset.py` — AMD parking meter importer
- `merge_montreal.py` — Phase 0 merger (3-file → single JSON)

## API Documentation

### Montreal Open Data CKAN URLs

**Search SRRR zones:**
```
https://donnees.montreal.ca/api/3/action/package_search?q=Secteurs+stationnement
```

**Direct cleaning GeoJSON:**
```
https://donnees.montreal.ca/dataset/9a5d53a9-a685-44ed-80b9-3bb3c9ea5f9f/resource/d51b3e06-6e6c-4c3e-aa6e-d1a00bed625e/download/nettoyage-rue.geojson
```

**CKAN API base:**
```
https://donnees.montreal.ca/api/3/action
```

## Future Enhancements

- [ ] Stream-process large GeoJSON (reduce memory for 1M+ features)
- [ ] Add SRRR permit type extraction (resident, commercial, visitor)
- [ ] Export to tiles (PMTiles) for map visualization
- [ ] Validate against OpenStreetMap coverage
- [ ] Add incremental sync (only fetch deltas)
- [ ] Export time-series (track changes over months)

## License

Same as ParkSmart project.
