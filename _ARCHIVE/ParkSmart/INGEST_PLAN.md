# Ingestion Plan: Data → Database
## Normalize 5 cities to blockface model

---

## Overview

**Goal:** Convert raw GIS data (GeoJSON, Shapefile, CSV) into normalized blockface parking rules.

**Process:**
1. Read source file (GeoJSON/Shapefile/CSV)
2. Parse blockface/segment information
3. Extract parking rules
4. Normalize to schema
5. Write to PostgreSQL database

**Timeline:** Weeks 3-6 (4 weeks)

---

## Phase 1: Set Up Database (Week 3, Day 1-2)

### Install Requirements

```bash
# PostgreSQL + PostGIS
brew install postgresql postgis  # Mac
sudo apt-get install postgresql postgis  # Linux
# Windows: Download from postgresql.org

# Python packages
pip install sqlalchemy geopandas shapely psycopg2-binary pandas
```

### Initialize Database

```bash
# Create database
createdb parksmart_phase1

# Connect and enable PostGIS
psql parksmart_phase1

# In psql shell:
CREATE EXTENSION postgis;
\i DATA_SCHEMA.sql
\q
```

### Verify Setup

```bash
psql parksmart_phase1 -c "SELECT * FROM cities;"
psql parksmart_phase1 -c "SELECT * FROM v_coverage_stats;"
```

**Status:** Database ready ✓

---

## Phase 2: Create Ingestion Scripts (Week 3-4)

### Template Structure

```python
# scripts/ingest_seattle.py

import json
import geopandas as gpd
import pandas as pd
from sqlalchemy import create_engine
from datetime import datetime

class SeattleIngester:
    def __init__(self):
        self.engine = create_engine('postgresql://user:password@localhost:5432/parksmart_phase1')
        self.city_id = 'seattle'

    def ingest_blockfaces(self):
        """Load blockface segments"""
        print("[Seattle] Loading blockfaces...")
        gdf = gpd.read_file('data/raw/seattle/Parking_Blockfaces.geojson')
        
        # Parse each feature
        segments = []
        for idx, row in gdf.iterrows():
            segment = {
                'id': f"seattle-{idx:04d}-{row['side']}",
                'city_id': 'seattle',
                'street_name': row['street_name'],
                'from_intersection': row['from_street'],
                'to_intersection': row['to_street'],
                'side': row['side'],  # 'left', 'right', 'both'
                'geometry': row['geometry'],
                'source': 'seattle_arcgis',
                'confidence': 0.95,
                'last_updated': datetime.now(),
                'raw_data': row.to_dict()
            }
            segments.append(segment)
        
        # Write to database
        df = pd.DataFrame(segments)
        df.to_sql('street_segments', self.engine, index=False, if_exists='append')
        print(f"[Seattle] Loaded {len(segments)} segments")
        return segments

    def ingest_parking_rules(self):
        """Extract and load parking rules"""
        print("[Seattle] Extracting parking rules...")
        
        # Read rules CSV/GeoJSON
        rules_data = pd.read_csv('data/raw/seattle/Parking_Rules.csv')
        
        rules = []
        for idx, row in rules_data.iterrows():
            rule = {
                'id': f"seattle-rule-{idx:05d}",
                'segment_id': f"seattle-{row['segment_id']}-{row['side']}",
                'rule_type': self._parse_rule_type(row['regulation']),  # 'metered', 'no_parking', etc
                'days_of_week': self._parse_days(row.get('days', None)),
                'start_time': row.get('start_time'),
                'end_time': row.get('end_time'),
                'max_stay_minutes': self._parse_duration(row.get('max_stay', None)),
                'rate_per_hour': row.get('rate'),
                'priority': self._calc_priority(row['rule_type']),
                'source': 'seattle_arcgis',
                'confidence': 0.95,
                'last_updated': datetime.now(),
                'raw_data': row.to_dict()
            }
            rules.append(rule)
        
        # Write to database
        df = pd.DataFrame(rules)
        df.to_sql('parking_rules', self.engine, index=False, if_exists='append')
        print(f"[Seattle] Loaded {len(rules)} parking rules")
        return rules

    def ingest_street_cleaning(self):
        """Load street cleaning schedules"""
        print("[Seattle] Loading street cleaning schedules...")
        
        cleaning_data = pd.read_csv('data/raw/seattle/Street_Cleaning_Schedule.csv')
        
        cleaning = []
        for idx, row in cleaning_data.iterrows():
            clean = {
                'id': f"seattle-clean-{idx:05d}",
                'segment_id': f"seattle-{row['segment_id']}-both",
                'cleaning_day_of_week': self._day_to_int(row['cleaning_day']),  # 1-7
                'cleaning_start_time': row['cleaning_time'],
                'cleaning_duration_minutes': 120,  # typical
                'source': 'seattle_arcgis',
                'confidence': 0.90,
                'last_updated': datetime.now()
            }
            cleaning.append(clean)
        
        df = pd.DataFrame(cleaning)
        df.to_sql('street_cleaning', self.engine, index=False, if_exists='append')
        print(f"[Seattle] Loaded {len(cleaning)} street cleaning rules")
        return cleaning

    # Helper methods
    def _parse_rule_type(self, regulation_text):
        """Convert regulation text to rule type"""
        text = regulation_text.lower()
        if 'no parking' in text:
            return 'no_parking'
        elif 'no stopping' in text:
            return 'no_stopping'
        elif 'meter' in text or '$' in text:
            return 'metered'
        elif 'permit' in text:
            return 'permit'
        elif 'cleaning' in text or 'sweep' in text:
            return 'street_cleaning'
        else:
            return 'other'

    def _parse_days(self, days_str):
        """Convert 'Mon-Fri' to ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']"""
        if not days_str:
            return None
        # Handle "Mon-Fri", "Sat,Sun", etc
        days_map = {'Mon': 1, 'Tue': 2, 'Wed': 3, 'Thu': 4, 'Fri': 5, 'Sat': 6, 'Sun': 7}
        # Implement range expansion
        return [d.strip() for d in days_str.split(',')]

    def _parse_duration(self, duration_str):
        """Convert '2 hours' to 120 minutes"""
        if not duration_str:
            return None
        # Handle "2h", "2 hours", "120 min", etc
        if 'h' in duration_str.lower():
            hours = float(duration_str.lower().replace('hours', '').replace('h', '').strip())
            return int(hours * 60)
        elif 'min' in duration_str.lower():
            return int(duration_str.lower().replace('min', '').strip())
        return None

    def _calc_priority(self, rule_type):
        """Higher priority = applied first"""
        priority_map = {
            'no_stopping': 100,
            'no_parking': 90,
            'street_cleaning': 80,
            'metered': 70,
            'permit': 60,
            'other': 50
        }
        return priority_map.get(rule_type, 50)

    def _day_to_int(self, day_name):
        """Mon → 1, Tue → 2, ..., Sun → 7"""
        day_map = {'Mon': 1, 'Tue': 2, 'Wed': 3, 'Thu': 4, 'Fri': 5, 'Sat': 6, 'Sun': 7}
        return day_map.get(day_name, 1)

    def run(self):
        """Execute full ingestion"""
        print("\n=== Seattle Ingestion ===")
        try:
            self.ingest_blockfaces()
            self.ingest_parking_rules()
            self.ingest_street_cleaning()
            print("[Seattle] ✓ Ingestion complete")
        except Exception as e:
            print(f"[Seattle] ✗ Error: {e}")

if __name__ == '__main__':
    ingester = SeattleIngester()
    ingester.run()
```

### Create Similar Scripts for Other Cities

Replicate the above template for:
- `scripts/ingest_sf.py`
- `scripts/ingest_nyc.py`
- `scripts/ingest_toronto.py`
- `scripts/ingest_boston.py`

**Main differences per city:**
- File paths (data/raw/{city}/...)
- Column names (each city uses different names)
- Rule parsing logic (different regulation formats)
- Priority tuning

---

## Phase 3: Run Ingestion (Week 5)

### Master Ingestion Script

```python
# scripts/ingest_all.py

from ingest_seattle import SeattleIngester
from ingest_sf import SFIngester
from ingest_nyc import NYCIngester
from ingest_toronto import TorontoIngester
from ingest_boston import BostonIngester

def main():
    ingesters = [
        SeattleIngester(),
        SFIngester(),
        NYCIngester(),
        TorontoIngester(),
        BostonIngester()
    ]

    print("Starting ingestion of 5 cities...\n")
    
    for ingester in ingesters:
        try:
            ingester.run()
        except Exception as e:
            print(f"[{ingester.city_id}] Failed: {e}")
    
    print("\n=== Ingestion Summary ===")
    # Query coverage stats
    # ...

if __name__ == '__main__':
    main()
```

### Run

```bash
cd D:\mob\ParkSmart
python scripts/ingest_all.py
```

**Expected output:**
```
Starting ingestion of 5 cities...

=== Seattle Ingestion ===
[Seattle] Loading blockfaces...
[Seattle] Loaded 5284 segments
[Seattle] Extracting parking rules...
[Seattle] Loaded 7821 parking rules
[Seattle] Loading street cleaning schedules...
[Seattle] Loaded 1342 street cleaning rules
[Seattle] ✓ Ingestion complete

=== San Francisco Ingestion ===
...

=== Coverage Report ===
Seattle:    95% (5284 / 5500 segments)
SF:         80% (3241 / 4050 segments)
NYC:        60% (8102 / 13500 segments)
Toronto:    70% (2841 / 4000 segments)
Boston:     75% (2107 / 2800 segments)
Average:    76% coverage
```

---

## Phase 4: Validation & QA (Week 5-6)

### Validation Checks

```python
# scripts/validate_data.py

from sqlalchemy import create_engine, text

engine = create_engine('postgresql://user:password@localhost:5432/parksmart_phase1')

def validate():
    with engine.connect() as conn:
        
        # 1. Check segment count
        result = conn.execute(text("SELECT city_id, COUNT(*) FROM street_segments GROUP BY city_id"))
        print("Segments per city:")
        for city_id, count in result:
            print(f"  {city_id}: {count}")
        
        # 2. Check for orphaned rules
        result = conn.execute(text(
            "SELECT COUNT(*) FROM parking_rules WHERE segment_id NOT IN (SELECT id FROM street_segments)"
        ))
        orphaned = result.scalar()
        print(f"\nOrphaned rules: {orphaned}")
        if orphaned > 0:
            print("  WARNING: Some rules point to non-existent segments")
        
        # 3. Check rule types distribution
        result = conn.execute(text(
            "SELECT rule_type, COUNT(*) FROM parking_rules GROUP BY rule_type ORDER BY COUNT(*) DESC"
        ))
        print("\nRule types distribution:")
        for rule_type, count in result:
            print(f"  {rule_type}: {count}")
        
        # 4. Check for missing time data
        result = conn.execute(text(
            "SELECT COUNT(*) FROM parking_rules WHERE start_time IS NULL AND rule_type IN ('metered', 'no_parking')"
        ))
        missing = result.scalar()
        print(f"\nRules missing time data: {missing}")
        
        # 5. Check geometry validity
        result = conn.execute(text(
            "SELECT COUNT(*) FROM street_segments WHERE NOT ST_IsValid(geometry)"
        ))
        invalid_geom = result.scalar()
        print(f"Invalid geometries: {invalid_geom}")

if __name__ == '__main__':
    validate()
```

### Run Validation

```bash
python scripts/validate_data.py
```

**Expected output:**
```
Segments per city:
  seattle: 5284
  sf: 3241
  nyc: 8102
  toronto: 2841
  boston: 2107

Orphaned rules: 0

Rule types distribution:
  metered: 8921
  no_parking: 7234
  street_cleaning: 5102
  permit: 2341
  no_stopping: 1203

Rules missing time data: 0

Invalid geometries: 0
```

---

## Phase 5: Create Data Source Records (Week 6)

### Track Data Provenance

```python
# scripts/record_data_sources.py

from datetime import date
from sqlalchemy import create_engine, text
import json

engine = create_engine('postgresql://user:password@localhost:5432/parksmart_phase1')

sources = [
    {
        'id': 'seattle_arcgis',
        'city_id': 'seattle',
        'source_name': 'Seattle ArcGIS Open Data',
        'source_type': 'geojson',
        'url': 'https://data-seattlegov.opendata.arcgis.com/',
        'download_date': date.today(),
        'file_path': 'data/raw/seattle/',
        'record_count': 5284,
        'coverage_percentage': 95.0,
        'data_quality_score': 95,
        'notes': 'Authoritative blockface data from Seattle DoT'
    },
    # ... repeat for other cities
]

with engine.connect() as conn:
    for source in sources:
        conn.execute(text("""
            INSERT INTO data_sources (
                id, city_id, source_name, source_type, url,
                download_date, file_path, record_count, coverage_percentage,
                data_quality_score, notes
            ) VALUES (
                :id, :city_id, :source_name, :source_type, :url,
                :download_date, :file_path, :record_count, :coverage_percentage,
                :data_quality_score, :notes
            )
        """), source)
    conn.commit()

print("Data sources recorded ✓")
```

---

## Common Issues & Solutions

### Issue 1: Geometry Parsing Fails
**Symptom:** "Invalid WKT format"

**Solution:**
```python
from shapely.geometry import shape

# Convert GeoJSON geometry to shapely
geom = shape(geojson_feature['geometry'])
# Convert to WKT for database
wkt = geom.wkt
```

### Issue 2: Column Names Don't Match
**Symptom:** "KeyError: 'parking_type'"

**Solution:**
```python
# Print actual column names
print(gdf.columns.tolist())

# Map source columns to schema
column_map = {
    'STREET_NAME': 'street_name',  # source → schema
    'FROM_ST': 'from_intersection',
    'REGULATION_TEXT': 'regulation',
}

# Rename before processing
gdf = gdf.rename(columns=column_map)
```

### Issue 3: Time Format Parsing
**Symptom:** "Invalid time format"

**Solution:**
```python
from datetime import datetime, time

def parse_time(time_str):
    if not time_str:
        return None
    try:
        # Try ISO format
        return datetime.strptime(time_str, '%H:%M').time()
    except:
        try:
            # Try 12-hour format
            return datetime.strptime(time_str, '%I:%M %p').time()
        except:
            return None
```

### Issue 4: Duplicate Segments
**Symptom:** Unique constraint violation

**Solution:**
```python
# Deduplicate before insert
df = df.drop_duplicates(subset=['city_id', 'street_name', 'from_intersection', 'to_intersection', 'side'])
```

---

## Success Checklist (Week 6)

```
[ ] Database initialized (PostgreSQL + PostGIS)
[ ] Schema loaded (DATA_SCHEMA.sql)
[ ] 5 ingestion scripts created
[ ] All 5 cities ingested successfully
[ ] Coverage report shows 75%+ average
[ ] No orphaned rules
[ ] No invalid geometries
[ ] Data sources recorded
[ ] Validation tests pass

Result: ~30,000 segments + 100,000+ rules in database
Coverage: Seattle 95%, SF 80%, NYC 60%, Toronto 70%, Boston 75%
Quality: High confidence data ready for API
```

---

## Next Steps

Once ingestion is complete:
1. Move to API_SPEC.md (REST API endpoints)
2. Build can_park() logic
3. Deploy API
4. Connect mobile app
