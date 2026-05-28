# Phase 1: Data Inventory & Sources
## 5 Cities, 75% Coverage, 3 Months

---

## Seattle (Target: 95%)

### Why Seattle?
- ✅ Mature open data program
- ✅ Blockface-level parking data published
- ✅ Multiple datasets (meters + signs + sweeping)
- ✅ Good for reference implementation

### Primary Sources

#### 1. Seattle Blockface Parking Data
**URL:** https://data-seattlegov.opendata.arcgis.com/  
**Search:** "parking blockface" or "curb"

**Expected Files:**
- `Parking_Blockfaces.geojson` or `.shp`
- `Parking_Signs_Inventory.geojson`
- `Parking_Meter_Locations.geojson`
- `Street_Cleaning_Schedule.csv`

**What it contains:**
```json
{
  "type": "Feature",
  "geometry": {
    "type": "LineString",
    "coordinates": [[-122.3, 47.6], [-122.3, 47.61]]
  },
  "properties": {
    "segment_id": "seattle-001-right",
    "street_name": "Pike Street",
    "from_intersection": "1st Avenue",
    "to_intersection": "2nd Avenue",
    "side": "right",
    "parking_type": "metered",
    "max_stay_hours": 2,
    "rate_per_hour": 2.50
  }
}
```

**Download Instructions:**
1. Go to https://data-seattlegov.opendata.arcgis.com/
2. Search "parking"
3. Filter by "GeoJSON" or "Shapefile"
4. Click each dataset → Download
5. Save to: `data/raw/seattle/`

**Expected Size:** 50-200 MB total

#### 2. OpenStreetMap (Backup)
**URL:** https://overpass-turbo.eu/

**Query:**
```
[bbox:47.6,-122.3,47.7,-122.2];
(
  way["parking:lane:right"];
  way["parking:lane:left"];
  way["parking:condition"];
);
out geom;
```

**What it provides:**
- Parking lane restrictions (complement official data)
- Days/hours restrictions (if tagged)
- Fallback for missing segments

---

## San Francisco (Target: 80%)

### Why SF?
- ✅ SFMTA published parking data
- ✅ Comprehensive sweeping schedule
- ✅ Meter data available
- ✅ Good coverage downtown

### Primary Sources

#### 1. SFMTA Parking Data
**URL:** https://data.sfgov.org/

**Search Terms:**
- "parking meters"
- "parking regulations"
- "street sweeping"

**Expected Files:**
- `SFMTA_Parking_Meters.geojson`
- `SFMTA_Parking_Regulations.csv`
- `Street_Sweeping_Schedule.geojson`

**What it contains:**
```csv
street_segment, regulation_type, start_time, end_time, days, max_duration_hours
"Market St (1st-2nd)", "metered", "08:00", "22:00", "Mon-Sun", 2
"Valencia St (16th-17th)", "no_parking", "07:00", "09:00", "Tue,Fri", null
```

**Download Instructions:**
1. Go to https://data.sfgov.org/
2. Search "parking"
3. For each dataset: Export → GeoJSON/CSV
4. Save to: `data/raw/sf/`

**Expected Size:** 30-100 MB

#### 2. Alternative: SFMTA Official Site
**URL:** https://www.sfmta.com/

- May have PDFs or spreadsheets
- Less structured than open data
- Use as reference if data.sfgov.org incomplete

#### 3. OpenStreetMap
**Same query as Seattle** (parking:lane tags for SF)

---

## New York City (Target: 60%)

### Why NYC?
- ✅ Largest market
- ✅ Data exists but fragmented
- ✅ Multiple agencies (DOT, DSNY, Finance)
- ✅ Will use FOIA to fill gaps later

### Primary Sources

#### 1. NYC Open Data Portal
**URL:** https://data.cityofnewyork.us/

**Search Terms:**
- "parking regulations"
- "parking signs"
- "parking meters"
- "street cleaning"

**Expected Datasets:**
- `Parking_Regulation_Streets.geojson` (DOT)
- `Parking_Signs_Inventory.csv` (DOT)
- `Street_Cleaning_Calendar.csv` (DSNY)
- `Permit_Parking_Zones.geojson` (Finance)

**What it contains:**
```csv
BLOCKFACE_ID, street, from_street, to_street, side, regulation_summary, effective_date
1001, "Main St", "1st Ave", "2nd Ave", "south", "NO PARKING 7AM-10AM MON-FRI", "2023-01-01"
```

**Download Instructions:**
1. Go to https://data.cityofnewyork.us/
2. Search "parking" + filter by agency (DOT, DSNY)
3. Export → GeoJSON/CSV
4. Save to: `data/raw/nyc/`

**Expected Size:** 50-200 MB (fragmented across 3-4 datasets)

#### 2. Note on Fragmentation
NYC data is split across:
- **DOT** → parking meters, signs, restrictions
- **DSNY** → street cleaning schedule
- **Finance** → permit parking zones

**You'll need to merge these separately.**

#### 3. OpenStreetMap
**Same query as Seattle**

---

## Toronto (Target: 70%)

### Why Toronto?
- ✅ Open data portal (open.toronto.ca)
- ✅ Published parking bylaw data
- ✅ Street cleaning schedules available
- ✅ Good for Canadian market

### Primary Sources

#### 1. Open Toronto Portal
**URL:** https://open.toronto.ca/

**Search Terms:**
- "parking"
- "parking bylaw"
- "street cleaning"
- "residential permit"

**Expected Datasets:**
- `Parking_Bylaw_Restrictions.geojson`
- `Parking_Meters.csv`
- `Street_Cleaning_Schedule.geojson`
- `Residential_Permit_Parking_Zones.shp`

**What it contains:**
```json
{
  "street": "Yonge Street",
  "segment": "College St to Dundas St",
  "side": "east",
  "restriction": "No parking 7am-9am Mon-Fri",
  "exceptions": "Permit holders OK",
  "source": "City of Toronto By-Law"
}
```

**Download Instructions:**
1. Go to https://open.toronto.ca/
2. Search "parking"
3. Download each dataset (usually CSV or GeoJSON)
4. Save to: `data/raw/toronto/`

**Expected Size:** 20-80 MB

#### 2. OpenStreetMap
**Same query as Seattle** (good coverage in Toronto)

---

## Boston (Target: 75%)

### Why Boston?
- ✅ Data.boston.gov portal
- ✅ Published GIS datasets
- ✅ Parking restrictions available
- ✅ Reasonable coverage

### Primary Sources

#### 1. City of Boston Open Data
**URL:** https://data.boston.gov/

**Search Terms:**
- "parking"
- "street cleaning"
- "curb"

**Expected Datasets:**
- `Parking_Restrictions.geojson`
- `Parking_Meters.csv`
- `Street_Sweeping_Schedule.csv`

**What it contains:**
```csv
segment_id, street, regulation, hours, days, max_stay_minutes
"boston-001", "Tremont St", "metered", "08:00-18:00", "Mon-Fri", 120
```

**Download Instructions:**
1. Go to https://data.boston.gov/
2. Search "parking"
3. Export → GeoJSON/CSV
4. Save to: `data/raw/boston/`

**Expected Size:** 15-50 MB

#### 2. MasGIS (State-Level)
**URL:** https://www.mass.gov/

- Supplementary state GIS data
- May have regional parking data

---

## Data Format Inventory

### Expected File Types

| City | Format | Size | Status |
|------|--------|------|--------|
| Seattle | GeoJSON + Shapefile | 100-200 MB | ✓ Download now |
| SF | GeoJSON + CSV | 50-100 MB | ✓ Download now |
| NYC | GeoJSON + CSV (fragmented) | 50-200 MB | ✓ Download now |
| Toronto | GeoJSON + CSV | 20-80 MB | ✓ Download now |
| Boston | GeoJSON + CSV | 15-50 MB | ✓ Download now |

**Total Expected:** 250-630 MB

---

## Parsing Requirements

### GeoJSON
```python
import json
with open('parking.geojson') as f:
    data = json.load(f)
    for feature in data['features']:
        geometry = feature['geometry']
        properties = feature['properties']
```

### Shapefile
```python
import geopandas as gpd
gdf = gpd.read_file('parking.shp')
gdf.to_file('parking.geojson', driver='GeoJSON')
```

### CSV
```python
import pandas as pd
df = pd.read_csv('parking.csv')
# Geocode addresses if needed
```

---

## Coverage Validation

After downloading, validate:

### Completeness Check
```
Seattle:
  [ ] Blockfaces: 5000+ segments?
  [ ] Meters: 1000+ locations?
  [ ] Sweeping: 100+ streets?

SF:
  [ ] Blockfaces: 2000+ segments?
  [ ] Meters: 500+ locations?

NYC:
  [ ] Blockfaces: 3000+ segments?
  [ ] Fragmentation: 3+ separate datasets?

Toronto:
  [ ] Blockfaces: 1000+ segments?
  [ ] Coverage: Downtown dense?

Boston:
  [ ] Blockfaces: 800+ segments?
  [ ] Parking data: At least 500 rules?
```

### Usability Check
```
For each city:
  [ ] Can we extract: street name?
  [ ] Can we extract: from/to intersection?
  [ ] Can we extract: side (left/right)?
  [ ] Can we extract: parking rule type?
  [ ] Can we extract: time restrictions?
```

---

## Fallback Data (If Missing)

If a city's data is incomplete:

### Option 1: OpenStreetMap
- Parking:lane tags (right/left/both)
- Conditional restrictions (if tagged well)
- Usually covers 30-50% of streets

### Option 2: Socrata API
- Some cities use Socrata for open data
- Query via API instead of download
- Example: NYC, LA, Chicago use Socrata

### Option 3: FOIA Requests (Later)
- If open data insufficient
- Legal fallback for official data
- Part of Phase 2 (month 4+)

---

## Folder Structure

```
data/
├── raw/
│   ├── seattle/
│   │   ├── Parking_Blockfaces.geojson
│   │   ├── Parking_Signs_Inventory.geojson
│   │   ├── Parking_Meter_Locations.geojson
│   │   └── Street_Cleaning_Schedule.csv
│   ├── sf/
│   │   ├── SFMTA_Parking_Meters.geojson
│   │   ├── SFMTA_Parking_Regulations.csv
│   │   └── Street_Sweeping_Schedule.geojson
│   ├── nyc/
│   │   ├── Parking_Regulation_Streets.geojson
│   │   ├── Parking_Signs_Inventory.csv
│   │   ├── Street_Cleaning_Calendar.csv
│   │   └── Permit_Parking_Zones.geojson
│   ├── toronto/
│   │   ├── Parking_Bylaw_Restrictions.geojson
│   │   ├── Parking_Meters.csv
│   │   └── Street_Cleaning_Schedule.geojson
│   └── boston/
│       ├── Parking_Restrictions.geojson
│       ├── Parking_Meters.csv
│       └── Street_Sweeping_Schedule.csv
├── processed/
│   ├── seattle.db
│   ├── sf.db
│   ├── nyc.db
│   ├── toronto.db
│   └── boston.db
└── README.md (version control, source URLs, timestamps)
```

---

## Verification Checklist

### Before Starting Ingestion

```
SEATTLE:
[ ] All 4 datasets downloaded
[ ] Files parse without errors
[ ] Blockfaces: 5000+ segments
[ ] Coverage: Downtown + neighborhoods

SF:
[ ] All datasets downloaded
[ ] No duplicate segments
[ ] Coverage: Mission, SOMA, Tenderloin

NYC:
[ ] Datasets from 3 agencies obtained
[ ] Note which agency owns which data
[ ] Coverage: Manhattan (dense), outer boroughs (sparse)

TORONTO:
[ ] Datasets downloaded
[ ] Ward coverage: Downtown + suburbs
[ ] Coverage: Downtown excellent, suburbs OK

BOSTON:
[ ] All datasets downloaded
[ ] Coverage: Back Bay, Beacon Hill, Downtown
```

---

## Next Steps

1. **Week 1, Day 1:** Visit each open data portal
2. **Week 1, Day 2-3:** Download all datasets
3. **Week 1, Day 4-5:** Validate files + check completeness
4. **Week 2:** Start ingestion (DATA_SCHEMA.sql + INGEST_PLAN.md)

---

## Key Contacts (If Data Problems)

| City | Contact | Email | Alternative |
|------|---------|-------|-------------|
| Seattle | Chief Data Officer | data.request@seattle.gov | data-seattlegov.opendata.arcgis.com |
| SF | SFMTA Open Data | sfmta@sfmuni.com | data.sfgov.org |
| NYC | NYC DoIT | help@data.cityofnewyork.us | data.cityofnewyork.us/support |
| Toronto | Open Data Team | open@toronto.ca | open.toronto.ca/contact |
| Boston | Analytics Team | analytics@boston.gov | data.boston.gov |

**If dataset is outdated or broken, contact them directly.**

---

**Status:** Ready to download (Week 1)  
**Estimated time:** 4-6 hours  
**Difficulty:** Easy (just clicking + downloading)
