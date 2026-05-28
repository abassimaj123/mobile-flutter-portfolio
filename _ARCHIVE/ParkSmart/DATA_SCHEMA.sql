-- ParkSmart Phase 1: Database Schema
-- 75% Coverage: Seattle, SF, NYC, Toronto, Boston
-- Blockface-level parking rules

-- =====================================================
-- TABLES
-- =====================================================

-- 1. CITIES
CREATE TABLE cities (
  id TEXT PRIMARY KEY,           -- 'seattle', 'sf', 'nyc', 'toronto', 'boston'
  name TEXT NOT NULL,
  country TEXT,
  bbox POLYGON,                  -- bounding box for queries
  osm_area_name TEXT,            -- for Overpass queries
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. STREET SEGMENTS (Blockfaces)
CREATE TABLE street_segments (
  id TEXT PRIMARY KEY,           -- 'seattle-001-right'
  city_id TEXT NOT NULL,
  street_name TEXT NOT NULL,
  from_intersection TEXT,
  to_intersection TEXT,
  side TEXT,                     -- 'left', 'right', 'both'
  geometry GEOMETRY(LINESTRING, 4326),
  length_meters FLOAT,
  source TEXT,                   -- 'seattle_arcgis', 'sf_sfmta', 'osm', etc
  confidence FLOAT,              -- 0.0 to 1.0 (how confident we are in this segment)
  last_updated TIMESTAMP,
  raw_data JSONB,                -- original source data

  FOREIGN KEY (city_id) REFERENCES cities(id),
  UNIQUE(city_id, street_name, from_intersection, to_intersection, side)
);

-- 3. PARKING RULES
CREATE TABLE parking_rules (
  id TEXT PRIMARY KEY,           -- 'rule-001'
  segment_id TEXT NOT NULL,
  rule_type TEXT NOT NULL,       -- 'no_parking', 'no_stopping', 'metered', 'permit', 'street_cleaning', 'loading', 'ev_only', 'handicap'

  -- Time restrictions
  days_of_week TEXT[],           -- ['Mon', 'Tue', 'Wed', ...] or null for daily
  start_time TIME,               -- '08:00'
  end_time TIME,                 -- '18:00'

  -- Duration limits
  max_stay_minutes INT,          -- null if unlimited
  min_stay_minutes INT,          -- null if no minimum

  -- Special attributes
  permit_zone TEXT,              -- for permit parking
  rate_per_hour FLOAT,           -- for metered parking
  rate_currency TEXT DEFAULT 'USD',
  handicap_only BOOLEAN DEFAULT FALSE,
  ev_only BOOLEAN DEFAULT FALSE,
  loading_only BOOLEAN DEFAULT FALSE,

  -- Metadata
  priority INT,                  -- higher number = higher priority (applied first)
  source TEXT,                   -- 'seattle_arcgis', 'sf_socrata', etc
  confidence FLOAT,              -- 0.0 to 1.0 (how confident we are in this rule)
  season TEXT,                   -- 'year_round', 'winter', 'summer', etc
  effective_date DATE,
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  raw_data JSONB,                -- original source data

  FOREIGN KEY (segment_id) REFERENCES street_segments(id) ON DELETE CASCADE
);

-- 4. STREET CLEANING SCHEDULES
CREATE TABLE street_cleaning (
  id TEXT PRIMARY KEY,
  segment_id TEXT NOT NULL,
  cleaning_day_of_week INT,     -- 1=Monday, 2=Tuesday, ..., 7=Sunday
  cleaning_start_time TIME,
  cleaning_duration_minutes INT, -- typically 120-180 minutes
  season TEXT,                   -- 'year_round', 'summer', etc
  source TEXT,
  confidence FLOAT,
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (segment_id) REFERENCES street_segments(id) ON DELETE CASCADE
);

-- 5. CONTRIBUTIONS (Community data)
CREATE TABLE user_contributions (
  id TEXT PRIMARY KEY,
  segment_id TEXT NOT NULL,
  contribution_type TEXT,        -- 'new_rule', 'correction', 'removal'
  rule_type TEXT,
  description TEXT,
  submitted_by_user_id TEXT,
  submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  status TEXT DEFAULT 'pending',  -- 'pending', 'verified', 'rejected'
  verified_by_moderator_id TEXT,
  verified_at TIMESTAMP,
  photo_url TEXT,

  FOREIGN KEY (segment_id) REFERENCES street_segments(id)
);

-- 6. DATA SOURCES (Track all sources)
CREATE TABLE data_sources (
  id TEXT PRIMARY KEY,
  city_id TEXT NOT NULL,
  source_name TEXT,              -- 'seattle_arcgis', 'sf_sfmta', etc
  source_type TEXT,              -- 'geojson', 'shapefile', 'csv', 'api', 'osm'
  url TEXT,
  description TEXT,
  download_date DATE,
  file_path TEXT,                -- where we saved it locally
  record_count INT,
  coverage_percentage FLOAT,     -- estimated % of city covered
  data_quality_score FLOAT,      -- 0-100 (how good is the data)
  notes TEXT,

  FOREIGN KEY (city_id) REFERENCES cities(id)
);

-- 7. AUDIT LOG (Track all changes)
CREATE TABLE audit_log (
  id SERIAL PRIMARY KEY,
  action TEXT,                   -- 'INSERT', 'UPDATE', 'DELETE'
  table_name TEXT,
  record_id TEXT,
  old_value JSONB,
  new_value JSONB,
  changed_by TEXT,
  changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- INDEXES (For query performance)
-- =====================================================

CREATE INDEX idx_street_segments_city ON street_segments(city_id);
CREATE INDEX idx_street_segments_name ON street_segments(street_name);
CREATE INDEX idx_street_segments_geometry ON street_segments USING GIST(geometry);

CREATE INDEX idx_parking_rules_segment ON parking_rules(segment_id);
CREATE INDEX idx_parking_rules_type ON parking_rules(rule_type);
CREATE INDEX idx_parking_rules_days ON parking_rules(days_of_week);

CREATE INDEX idx_street_cleaning_segment ON street_cleaning(segment_id);
CREATE INDEX idx_street_cleaning_day ON street_cleaning(cleaning_day_of_week);

CREATE INDEX idx_contributions_segment ON user_contributions(segment_id);
CREATE INDEX idx_contributions_status ON user_contributions(status);

-- =====================================================
-- VIEWS (For common queries)
-- =====================================================

-- View: Current parking rules for a segment
CREATE OR REPLACE VIEW v_current_rules AS
SELECT
  ss.id as segment_id,
  ss.street_name,
  ss.from_intersection,
  ss.to_intersection,
  ss.side,
  pr.rule_type,
  pr.days_of_week,
  pr.start_time,
  pr.end_time,
  pr.max_stay_minutes,
  pr.rate_per_hour,
  pr.priority
FROM street_segments ss
LEFT JOIN parking_rules pr ON ss.id = pr.segment_id
WHERE pr.last_updated = (SELECT MAX(last_updated) FROM parking_rules WHERE segment_id = ss.id);

-- View: Segments with no rules (gaps in coverage)
CREATE OR REPLACE VIEW v_coverage_gaps AS
SELECT
  ss.id,
  ss.city_id,
  ss.street_name,
  ss.from_intersection,
  ss.to_intersection,
  COUNT(pr.id) as rule_count
FROM street_segments ss
LEFT JOIN parking_rules pr ON ss.id = pr.segment_id
GROUP BY ss.id, ss.city_id, ss.street_name, ss.from_intersection, ss.to_intersection
HAVING COUNT(pr.id) = 0;

-- View: Coverage statistics
CREATE OR REPLACE VIEW v_coverage_stats AS
SELECT
  c.id,
  c.name,
  COUNT(DISTINCT ss.id) as total_segments,
  COUNT(DISTINCT CASE WHEN pr.id IS NOT NULL THEN ss.id END) as segments_with_rules,
  ROUND(100.0 * COUNT(DISTINCT CASE WHEN pr.id IS NOT NULL THEN ss.id END) / COUNT(DISTINCT ss.id), 1) as coverage_percentage
FROM cities c
LEFT JOIN street_segments ss ON c.id = ss.city_id
LEFT JOIN parking_rules pr ON ss.id = pr.segment_id
GROUP BY c.id, c.name;

-- =====================================================
-- SAMPLE DATA
-- =====================================================

INSERT INTO cities (id, name, country) VALUES
('seattle', 'Seattle', 'USA'),
('sf', 'San Francisco', 'USA'),
('nyc', 'New York City', 'USA'),
('toronto', 'Toronto', 'Canada'),
('boston', 'Boston', 'USA');

-- Example segment (will be populated during ingestion)
INSERT INTO street_segments (id, city_id, street_name, from_intersection, to_intersection, side, source, confidence) VALUES
('seattle-001-right', 'seattle', 'Pike Street', '1st Avenue', '2nd Avenue', 'right', 'seattle_arcgis', 0.95);

-- Example rules for that segment
INSERT INTO parking_rules (id, segment_id, rule_type, days_of_week, start_time, end_time, max_stay_minutes, rate_per_hour, priority, source, confidence) VALUES
('rule-001', 'seattle-001-right', 'metered', ARRAY['Mon','Tue','Wed','Thu','Fri'], '08:00', '18:00', 120, 2.50, 100, 'seattle_arcgis', 0.95),
('rule-002', 'seattle-001-right', 'street_cleaning', ARRAY['Wed'], '09:00', '11:00', NULL, NULL, 90, 'seattle_arcgis', 0.95);

-- =====================================================
-- FUNCTIONS
-- =====================================================

-- Function: Find nearest segment to coordinates
CREATE OR REPLACE FUNCTION find_nearest_segment(
  p_lat FLOAT,
  p_lon FLOAT,
  p_city_id TEXT DEFAULT NULL,
  p_threshold_meters INT DEFAULT 50
)
RETURNS TABLE (
  segment_id TEXT,
  street_name TEXT,
  distance_meters FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    ss.id,
    ss.street_name,
    ST_Distance(ss.geometry, ST_SetSRID(ST_MakePoint(p_lon, p_lat), 4326))::numeric * 111000 as distance_m
  FROM street_segments ss
  WHERE (p_city_id IS NULL OR ss.city_id = p_city_id)
    AND ST_DWithin(ss.geometry, ST_SetSRID(ST_MakePoint(p_lon, p_lat), 4326), p_threshold_meters / 111000.0)
  ORDER BY distance_m
  LIMIT 5;
END;
$$ LANGUAGE plpgsql;

-- Function: Get applicable rules for datetime
CREATE OR REPLACE FUNCTION get_applicable_rules(
  p_segment_id TEXT,
  p_day_of_week INT,  -- 1=Mon, 2=Tue, ..., 7=Sun
  p_hour INT,
  p_minute INT
)
RETURNS TABLE (
  rule_id TEXT,
  rule_type TEXT,
  start_time TIME,
  end_time TIME,
  max_stay_minutes INT,
  priority INT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    pr.id,
    pr.rule_type,
    pr.start_time,
    pr.end_time,
    pr.max_stay_minutes,
    pr.priority
  FROM parking_rules pr
  WHERE pr.segment_id = p_segment_id
    AND (
      pr.days_of_week IS NULL
      OR pr.days_of_week[p_day_of_week] IS NOT NULL
    )
    AND (
      pr.start_time IS NULL
      OR (pr.start_time <= CAST(p_hour || ':' || p_minute AS TIME) AND CAST(p_hour || ':' || p_minute AS TIME) < pr.end_time)
    )
  ORDER BY pr.priority DESC;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- SETUP INSTRUCTIONS
-- =====================================================
/*
1. Install PostgreSQL (https://www.postgresql.org/download/)
2. Create database:
   createdb parksmart_phase1

3. Install PostGIS:
   sudo apt-get install postgresql-13-postgis  (Linux)
   brew install postgis (Mac)

4. Enable PostGIS:
   psql parksmart_phase1 -c "CREATE EXTENSION postgis;"

5. Load this schema:
   psql parksmart_phase1 -f DATA_SCHEMA.sql

6. Verify:
   psql parksmart_phase1 -c "SELECT * FROM cities;"
   psql parksmart_phase1 -c "SELECT * FROM v_coverage_stats;"
*/

-- =====================================================
-- PYTHON CONNECTION
-- =====================================================
/*
from sqlalchemy import create_engine
import geopandas as gpd

engine = create_engine('postgresql://user:password@localhost:5432/parksmart_phase1')

# Load GeoJSON to database
gdf = gpd.read_file('seattle_blockfaces.geojson')
gdf.to_postgis('street_segments', engine, index=False, if_exists='append')

# Query from database
result = gpd.read_postgis('SELECT * FROM street_segments WHERE city_id = %s', engine, params=('seattle',))
*/
