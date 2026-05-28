#!/bin/bash
# ParkSmart Phase 1: Complete Setup Script
# Run this once to initialize everything

set -e  # Exit on error

echo "======================================"
echo "ParkSmart Phase 1: Setup"
echo "======================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. Create folder structure
echo -e "${YELLOW}[1/5] Creating folders...${NC}"
mkdir -p D:\mob\ParkSmart\data\raw\seattle
mkdir -p D:\mob\ParkSmart\data\raw\sf
mkdir -p D:\mob\ParkSmart\data\raw\nyc
mkdir -p D:\mob\ParkSmart\data\raw\toronto
mkdir -p D:\mob\ParkSmart\data\raw\boston
mkdir -p D:\mob\ParkSmart\data\processed
mkdir -p D:\mob\ParkSmart\scripts\logs
echo -e "${GREEN}✓ Folders created${NC}"

# 2. Check Python
echo -e "${YELLOW}[2/5] Checking Python...${NC}"
python --version
echo -e "${GREEN}✓ Python ready${NC}"

# 3. Install requirements
echo -e "${YELLOW}[3/5] Installing Python packages...${NC}"
pip install -q sqlalchemy geopandas shapely psycopg2-binary pandas requests
echo -e "${GREEN}✓ Packages installed${NC}"

# 4. Create .env file (for database credentials)
echo -e "${YELLOW}[4/5] Creating config...${NC}"
cat > D:\mob\ParkSmart\.env << 'EOF'
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=parksmart_phase1
DB_USER=postgres
DB_PASSWORD=postgres

# API Configuration
API_HOST=0.0.0.0
API_PORT=8000
API_ENV=development
EOF
echo -e "${GREEN}✓ Config created${NC}"

# 5. Summary
echo ""
echo -e "${GREEN}======================================"
echo "Setup Complete! ✓"
echo "=====================================${NC}"
echo ""
echo "Next steps:"
echo "1. Install PostgreSQL: https://www.postgresql.org/download/"
echo "2. Enable PostGIS: createdb parksmart_phase1 && psql parksmart_phase1 -c 'CREATE EXTENSION postgis;'"
echo "3. Load schema: psql parksmart_phase1 -f DATA_SCHEMA.sql"
echo "4. Download data: python scripts/download_data.py"
echo "5. Run ingestion: python scripts/ingest_all.py"
echo ""
echo "Folders ready:"
ls -la D:\mob\ParkSmart\data\raw\
echo ""
