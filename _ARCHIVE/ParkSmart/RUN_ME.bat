@echo off
REM ParkSmart Phase 1: Quick Start
REM Run this to begin the ingestion pipeline

setlocal enabledelayedexpansion

echo.
echo ============================================================
echo ParkSmart Phase 1: EXECUTION MODE
echo ============================================================
echo.

REM Check Python
echo [1/5] Checking Python installation...
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found!
    echo Download from: https://www.python.org/downloads/
    pause
    exit /b 1
)
echo OK: Python found

REM Check PostgreSQL
echo [2/5] Checking PostgreSQL installation...
psql --version >nul 2>&1
if errorlevel 1 (
    echo WARNING: PostgreSQL not found
    echo Download from: https://www.postgresql.org/download/windows/
    echo.
    echo Continuing anyway...
) else (
    echo OK: PostgreSQL found
)

REM Create folders
echo [3/5] Creating data folders...
if not exist "D:\mob\ParkSmart\data\raw\seattle" mkdir "D:\mob\ParkSmart\data\raw\seattle"
if not exist "D:\mob\ParkSmart\data\raw\sf" mkdir "D:\mob\ParkSmart\data\raw\sf"
if not exist "D:\mob\ParkSmart\data\raw\nyc" mkdir "D:\mob\ParkSmart\data\raw\nyc"
if not exist "D:\mob\ParkSmart\data\raw\toronto" mkdir "D:\mob\ParkSmart\data\raw\toronto"
if not exist "D:\mob\ParkSmart\data\raw\boston" mkdir "D:\mob\ParkSmart\data\raw\boston"
if not exist "D:\mob\ParkSmart\scripts\logs" mkdir "D:\mob\ParkSmart\scripts\logs"
echo OK: Folders created

REM Install Python packages
echo [4/5] Installing Python packages...
pip install -q sqlalchemy geopandas shapely psycopg2-binary pandas requests
if errorlevel 1 (
    echo ERROR: Failed to install packages
    pause
    exit /b 1
)
echo OK: Packages installed

REM Run download preparation
echo [5/5] Preparing data download...
cd /d "D:\mob\ParkSmart"
python scripts\download_data.py
if errorlevel 1 (
    echo ERROR: Download preparation failed
    pause
    exit /b 1
)

echo.
echo ============================================================
echo SETUP COMPLETE!
echo ============================================================
echo.
echo Next steps:
echo 1. Download parking data from these portals:
echo    - Seattle: https://data-seattlegov.opendata.arcgis.com/
echo    - SF: https://data.sfgov.org/
echo    - NYC: https://data.cityofnewyork.us/
echo    - Toronto: https://open.toronto.ca/
echo    - Boston: https://data.boston.gov/
echo.
echo 2. Save files to D:\mob\ParkSmart\data\raw\{city}\
echo.
echo 3. Once data is downloaded, run:
echo    python scripts\ingest_all.py
echo.
echo 4. Then launch the app:
echo    flutter run
echo.
echo ============================================================
echo Status: Ready to ingest data
echo Log: D:\mob\ParkSmart\scripts\logs\
echo ============================================================
echo.

pause
