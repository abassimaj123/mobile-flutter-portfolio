# Phase 1 Launch Checklist
## 75% Coverage in 12 Weeks

---

## Week 1-2: Data Acquisition

### Week 1 Tasks

#### Monday-Tuesday: Verify Datasets
```
[ ] Visit data-seattlegov.opendata.arcgis.com
    [ ] Search "parking"
    [ ] Confirm datasets exist (blockfaces, signs, meters, cleaning)
    [ ] Download all Seattle datasets
    [ ] Save to data/raw/seattle/

[ ] Visit data.sfgov.org
    [ ] Search "parking"
    [ ] Download SF datasets
    [ ] Save to data/raw/sf/

[ ] Visit data.cityofnewyork.us
    [ ] Search parking (DOT, DSNY agencies)
    [ ] Download all NYC datasets
    [ ] Save to data/raw/nyc/
    [ ] Note: Expect 3+ separate datasets

[ ] Visit open.toronto.ca
    [ ] Search "parking"
    [ ] Download Toronto datasets
    [ ] Save to data/raw/toronto/

[ ] Visit data.boston.gov
    [ ] Search "parking"
    [ ] Download Boston datasets
    [ ] Save to data/raw/boston/

Estimated time: 3-4 hours
Status: [ ] Complete
```

#### Wednesday-Thursday: Verify Data Usability
```
[ ] Test Seattle data
    [ ] Open blockfaces.geojson in text editor
    [ ] Confirm: contains geometry + properties
    [ ] Confirm: has street_name, from/to intersection, side
    [ ] Confirm: has parking rules info

[ ] Test SF data
    [ ] Open one dataset
    [ ] Verify format (GeoJSON/CSV)
    [ ] Verify: parseable

[ ] Test NYC data
    [ ] Check all 3-4 datasets separately
    [ ] Verify: compatible format
    [ ] Note: Fragmentation expected

[ ] Test Toronto data
    [ ] Open main dataset
    [ ] Verify: format + completeness

[ ] Test Boston data
    [ ] Open main dataset
    [ ] Verify: format + completeness

Estimated time: 2-3 hours
Status: [ ] Complete
```

#### Friday: Summary & Decision
```
[ ] Count files downloaded
    [ ] Seattle: 4-5 files?
    [ ] SF: 2-3 files?
    [ ] NYC: 3-4 files?
    [ ] Toronto: 2-3 files?
    [ ] Boston: 2-3 files?

[ ] Estimate total data size
    [ ] All files combined: 250-600 MB?

[ ] Decision: Can we proceed?
    [ ] YES → Move to Week 2
    [ ] NO → Identify gaps, find alternatives

Estimated time: 1 hour
Status: [ ] Complete
```

---

### Week 2 Tasks

#### Monday-Tuesday: Setup Database
```
[ ] Install PostgreSQL
    [ ] Download from postgresql.org
    [ ] Install locally
    [ ] Test: psql --version

[ ] Install PostGIS
    [ ] brew install postgis (Mac)
    [ ] apt-get install postgresql-postgis (Linux)

[ ] Create database
    [ ] createdb parksmart_phase1
    [ ] psql parksmart_phase1
    [ ] CREATE EXTENSION postgis;

[ ] Load schema
    [ ] psql parksmart_phase1 -f DATA_SCHEMA.sql
    [ ] Verify: Tables created
    [ ] Verify: Sample data inserted

[ ] Install Python packages
    [ ] pip install sqlalchemy geopandas shapely psycopg2-binary pandas

Estimated time: 2-3 hours
Status: [ ] Complete
```

#### Wednesday-Thursday: Create Ingestion Scripts
```
[ ] Create scripts/ingest_seattle.py
    [ ] Copy template from INGEST_PLAN.md
    [ ] Update paths: data/raw/seattle/
    [ ] Update column names (inspect actual file)
    [ ] Test parsing blockfaces (run _ingest_blockfaces only)
    [ ] Fix any errors

[ ] Create scripts/ingest_sf.py
    [ ] Replicate Seattle template
    [ ] Adjust for SF data format
    [ ] Test parsing

[ ] Create scripts/ingest_nyc.py
    [ ] Handle multiple files
    [ ] Merge rules from 3-4 datasets

[ ] Create scripts/ingest_toronto.py
    [ ] Follow template

[ ] Create scripts/ingest_boston.py
    [ ] Follow template

Estimated time: 4-6 hours
Status: [ ] Complete
```

#### Friday: Integration Check
```
[ ] Create scripts/ingest_all.py
    [ ] Import all 5 ingesters
    [ ] Call each ingester.run()
    [ ] Print summary

[ ] Dry-run: Test one city
    [ ] python scripts/ingest_seattle.py
    [ ] Should see: "Loaded X segments"
    [ ] Should see: "Loaded X rules"
    [ ] Should see: "✓ Ingestion complete"

[ ] Verify database
    [ ] psql parksmart_phase1 -c "SELECT COUNT(*) FROM street_segments;"
    [ ] psql parksmart_phase1 -c "SELECT * FROM v_coverage_stats;"

Estimated time: 2-3 hours
Status: [ ] Complete
```

---

## Week 3-6: Data Preparation & Normalization

### Week 3: Ingestion (1/4)

#### Monday-Tuesday: Debug First City
```
[ ] Run Seattle ingestion
    [ ] python scripts/ingest_seattle.py
    [ ] Watch for errors
    [ ] Expected: 5000+ segments loaded
    [ ] Expected: 7000+ rules loaded

[ ] If errors:
    [ ] Check column names in raw data
    [ ] Update _parse_* methods
    [ ] Test again

Estimated time: 2-3 hours
Status: [ ] Complete
```

#### Wednesday-Friday: Ingest All Cities
```
[ ] Run SF ingestion
    [ ] python scripts/ingest_sf.py
    [ ] Verify: ~3000+ segments

[ ] Run NYC ingestion
    [ ] python scripts/ingest_nyc.py
    [ ] Verify: ~8000+ segments (fragmented)

[ ] Run Toronto ingestion
    [ ] python scripts/ingest_toronto.py
    [ ] Verify: ~2800 segments

[ ] Run Boston ingestion
    [ ] python scripts/ingest_boston.py
    [ ] Verify: ~2100 segments

Estimated time: 2-3 hours
Status: [ ] Complete
```

---

### Week 4-5: Validation & Cleanup

#### Week 4 (Monday-Friday): Run Full Validation
```
[ ] Run validation script
    [ ] python scripts/validate_data.py

[ ] Check results:
    [ ] Segments per city: expect 2000-8000 each
    [ ] Orphaned rules: expect 0
    [ ] Invalid geometries: expect 0
    [ ] Missing time data: fix if >5%

[ ] If issues found:
    [ ] Investigate specific cities
    [ ] Fix ingestion scripts
    [ ] Re-ingest affected city
    [ ] Re-validate

[ ] Record data sources
    [ ] python scripts/record_data_sources.py
    [ ] Verify: all cities listed in data_sources table

Estimated time: 4-6 hours
Status: [ ] Complete
```

#### Week 5 (Monday-Friday): Final QA
```
[ ] Run coverage report
    [ ] Query: SELECT * FROM v_coverage_stats;
    [ ] Expected output:
        seattle:    95%
        sf:         80%
        nyc:        60%
        toronto:    70%
        boston:     75%
        average:    76%

[ ] Test rule logic manually
    [ ] Pick one segment (seattle-001-right)
    [ ] Query: SELECT * FROM parking_rules WHERE segment_id = 'seattle-001-right';
    [ ] Verify: rules make sense

[ ] Document coverage gaps
    [ ] Query: SELECT * FROM v_coverage_gaps;
    [ ] Note: Which streets missing rules?
    [ ] Plan: FOIA requests for major streets (Phase 2)

Estimated time: 2-3 hours
Status: [ ] Complete
```

---

### Week 6: API Development

#### Monday-Wednesday: Build API Server
```
[ ] Create api/main.py
    [ ] Copy template from API_SPEC.md
    [ ] Implement: GET /parking/rules
    [ ] Implement: GET /segment/{segment_id}
    [ ] Implement: GET /coverage
    [ ] Implement: POST /contributions
    [ ] Implement: GET /health

[ ] Test locally
    [ ] python api/main.py
    [ ] Server should start: "Uvicorn running on 127.0.0.1:8000"
    [ ] Visit: http://localhost:8000/docs (API documentation)

Estimated time: 3-4 hours
Status: [ ] Complete
```

#### Thursday-Friday: Test API Endpoints
```
[ ] Test /parking/rules
    [ ] curl "http://localhost:8000/api/v1/parking/rules?lat=47.6&lon=-122.3"
    [ ] Should return JSON with parking rule info

[ ] Test /segment/{id}
    [ ] curl "http://localhost:8000/api/v1/segment/seattle-001-right"
    [ ] Should return all rules for that segment

[ ] Test /coverage
    [ ] curl "http://localhost:8000/api/v1/coverage"
    [ ] Should return: 76% average coverage

[ ] Test /health
    [ ] curl "http://localhost:8000/api/v1/health"
    [ ] Should return: status "ok"

[ ] Load test (basic)
    [ ] Send 100 requests in a loop
    [ ] Monitor response times
    [ ] Expected: <500ms per request

Estimated time: 2-3 hours
Status: [ ] Complete
```

---

## Week 7-8: Mobile App Integration

### Week 7 Tasks

#### Monday-Tuesday: Update ParkSmart App
```
[ ] Update pubspec.yaml
    [ ] Ensure http package included
    [ ] Update version to 0.2.0

[ ] Create api_client.dart
    [ ] class ParkingApiClient
    [ ] Method: getParkingRules(lat, lon)
    [ ] Connect to API at localhost:8000 (development)

[ ] Update map_screen.dart
    [ ] Replace old CityParkingService calls with API calls
    [ ] _onStreetTap → call getParkingRules()
    [ ] Display results in bottom sheet

[ ] Test locally
    [ ] Start API server (Week 6)
    [ ] flutter run
    [ ] Tap a street on map
    [ ] Should show parking rule from database

Estimated time: 3-4 hours
Status: [ ] Complete
```

#### Wednesday-Friday: Deploy API to Cloud
```
[ ] Choose deployment option:
    [ ] Option A: Heroku (free)
    [ ] Option B: Railway.app (free)
    [ ] Option C: Self-hosted VPS

[ ] For Heroku:
    [ ] Create Procfile
    [ ] Create requirements.txt
    [ ] git init → git commit
    [ ] heroku create parksmart-api
    [ ] heroku addons:create heroku-postgresql
    [ ] git push heroku main
    [ ] API live at: https://parksmart-api.herokuapp.com

[ ] For Railway:
    [ ] Connect GitHub repo
    [ ] Railway auto-deploys
    [ ] Set DATABASE_URL env variable

[ ] Update app to use cloud API
    [ ] Replace localhost:8000 with cloud URL
    [ ] Test: flutter run
    [ ] Should query cloud API

Estimated time: 3-4 hours
Status: [ ] Complete
```

---

### Week 8 Tasks

#### Monday-Tuesday: Build APK
```
[ ] Verify app compiles
    [ ] flutter clean
    [ ] flutter pub get
    [ ] flutter analyze --no-fatal-infos

[ ] Build release APK
    [ ] flutter build apk --release
    [ ] Output: build/app/outputs/flutter-app/release/app-release.apk
    [ ] Size: should be ~30-40 MB

[ ] Test on device
    [ ] adb install build/app/outputs/flutter-app/release/app-release.apk
    [ ] Launch app
    [ ] Test: tap street → see rules
    [ ] Test: rules from database (not hardcoded)

Estimated time: 2-3 hours
Status: [ ] Complete
```

#### Wednesday-Thursday: Build IPA
```
[ ] Build release IPA
    [ ] flutter build ios --release
    [ ] (Requires macOS or use CI/CD)

[ ] Alternative: Use GitHub Actions
    [ ] Create .github/workflows/ios-build.yml
    [ ] Push to repo → auto-builds IPA
    [ ] Download from artifacts

Estimated time: 1-2 hours (or 4+ if manual on Mac)
Status: [ ] Complete
```

#### Friday: Prepare for Launch
```
[ ] Create app store screenshots
    [ ] Screenshot 1: Map overview
    [ ] Screenshot 2: Rule detail
    [ ] Screenshot 3: Coverage message
    [ ] Screenshot 4: Community contribution
    [ ] Size: 1242x2208px (iPhone)

[ ] Write store listings
    [ ] Title: "ParkSmart"
    [ ] Subtitle: "Know Before You Park"
    [ ] Description: (see PROJECT_STATUS.md)
    [ ] Keywords: "parking, rules, seattle, sf, nyc"

Estimated time: 2-3 hours
Status: [ ] Complete
```

---

## Week 9-12: App Store Submission & Launch

### Week 9 Tasks

#### Monday-Tuesday: Google Play Setup
```
[ ] Create Google Play Developer Account
    [ ] Pay $25 one-time fee
    [ ] Visit: play.google.com/console

[ ] Create app listing
    [ ] App name: "ParkSmart"
    [ ] Category: Maps & Navigation
    [ ] Content rating: Everyone

[ ] Fill out store listing
    [ ] Short description (80 chars)
    [ ] Full description (from PROJECT_STATUS.md)
    [ ] Screenshots (4-5 from Week 8)
    [ ] Privacy policy: Create or use TermsFeed

Estimated time: 2-3 hours
Status: [ ] Complete
```

#### Wednesday-Thursday: Upload APK
```
[ ] Go to: Play Console > Your app > Release > Create release
    [ ] Upload APK (from Week 8)
    [ ] Add release notes:
        ```
        ParkSmart v0.1.0 Beta
        
        Initial release with parking rules for:
        - Seattle (95% coverage)
        - San Francisco (80% coverage)
        - New York City (60% coverage)
        - Toronto (70% coverage)
        - Boston (75% coverage)
        
        Features:
        ✓ Map-based parking rule lookup
        ✓ Real-time meter rates & schedules
        ✓ Street cleaning alerts
        ✓ Community contributions
        
        This is beta software. Coverage improving daily.
        Report incorrect rules via "Report a Rule" button.
        ```
    [ ] Review release
    [ ] Start rollout to Internal Testing

Estimated time: 1-2 hours
Status: [ ] Complete
```

#### Friday: Test Internal Build
```
[ ] Invite yourself as internal tester
    [ ] Accept invite in Play Console
    [ ] Download app from Google Play (internal test)
    [ ] Full test suite:
        [ ] App launches without crash
        [ ] Search Seattle → shows rules
        [ ] Search SF → shows rules
        [ ] Report rule → contribution submitted
        [ ] Offline mode: graceful fallback

[ ] If bugs found:
    [ ] Fix in code
    [ ] Build new APK
    [ ] Upload new version
    [ ] Re-test

Estimated time: 2-3 hours
Status: [ ] Complete
```

---

### Week 10 Tasks

#### Monday-Wednesday: App Store (iOS) Setup
```
[ ] Create Apple Developer Account
    [ ] Pay $99/year
    [ ] Visit: appstoreconnect.apple.com

[ ] Create app in App Store Connect
    [ ] App name: "ParkSmart"
    [ ] Bundle ID: com.yourcompany.parksmart
    [ ] Category: Maps

[ ] Fill out app information
    [ ] Subtitle: "Know before you park"
    [ ] Description: (same as Google Play)
    [ ] Screenshots: (from Week 8, but 1170x2532px for iPhone)
    [ ] Privacy policy

Estimated time: 2-3 hours
Status: [ ] Complete
```

#### Thursday-Friday: Upload IPA to TestFlight
```
[ ] Have IPA ready (from Week 8)
    [ ] build/ios/iphoneos/Runner.app

[ ] In App Store Connect:
    [ ] TestFlight > iOS Builds > New Build
    [ ] Upload IPA
    [ ] Wait for processing (5-10 min)
    [ ] What's new: (same release notes as Google Play)

[ ] Add internal testers
    [ ] Add yourself
    [ ] Add friends if available (optional)
    [ ] Install TestFlight app on iPhone
    [ ] Download beta build

[ ] Test on iOS
    [ ] Full test suite (same as Android)
    [ ] Report any iOS-specific bugs

[ ] Wait for Apple review (12-48 hours)

Estimated time: 2-3 hours + wait
Status: [ ] Complete
```

---

### Week 11 Tasks

#### Monday-Tuesday: Promote Android to Public
```
[ ] In Google Play Console:
    [ ] Verify internal test passed (no crashes)
    [ ] Promote: Internal Testing → Closed Beta (or Public)
    [ ] Wait for review (usually 1-3 hours)

[ ] Once approved:
    [ ] App appears in Google Play Store
    [ ] Update APK size/format if needed
    [ ] Monitor early reviews

Estimated time: 2-4 hours (+ review time)
Status: [ ] Complete
```

#### Wednesday-Friday: iOS TestFlight → App Store
```
[ ] Apple review status:
    [ ] Check: App Store Connect > Builds
    [ ] Status should be "Ready for Distribution"

[ ] Submit to App Store for review:
    [ ] App Store Connect > Version
    [ ] Review questions:
        [ ] Uses encryption? No
        [ ] Third-party APIs? Yes (Nominatim, OSM)
        [ ] Collects personal data? No
        [ ] Requires auth? No
    [ ] Submit for Review

[ ] Wait for Apple review (1-3 days)

Estimated time: 1-2 hours + review time
Status: [ ] Complete
```

---

### Week 12 Tasks

#### Monday: Both Apps Live
```
[ ] Google Play: "ParkSmart" live ✓
    [ ] URL: https://play.google.com/store/apps/details?id=com.yourcompany.parksmart

[ ] App Store: "ParkSmart" live ✓
    [ ] URL: https://apps.apple.com/us/app/parksmart/...

[ ] Monitor:
    [ ] Check ratings/reviews daily
    [ ] Respond to user feedback
    [ ] Watch crash reports (Crashlytics)
    [ ] Track download count

Estimated time: Ongoing
Status: [ ] Complete
```

#### Tuesday-Friday: Celebrate + Plan Phase 2
```
[ ] Phase 1 Complete! 🎉
    [ ] 75% coverage across 5 cities
    [ ] Both app stores live
    [ ] Database proven
    [ ] API working

[ ] Next steps (Phase 2):
    [ ] Monitor for issues
    [ ] Collect user feedback
    [ ] Prepare FOIA requests (in parallel)
    [ ] Plan Mapillary ML (Month 4-6)

[ ] Track metrics:
    [ ] Weekly downloads
    [ ] User ratings
    [ ] Crash-free rate
    [ ] Average session length

Estimated time: Ongoing
Status: [ ] Complete
```

---

## Success Metrics

### By Week 12 (Launch)

```
✓ Database: 27,575 segments, 102,341 rules
✓ Coverage: 75% average
✓ API: Live and tested (0.5s response time)
✓ Android: Live on Google Play
✓ iOS: Live on App Store
✓ Downloads: 100+ (first week)
✓ Rating: 3.5+ stars
✓ Crashes: 0% (crash-free rate)
```

### By Month 4 (Phase 2 Starts)

```
✓ Monthly active users: 1000+
✓ Community contributions: 50+
✓ FOIA requests: All 4 submitted
✓ User retention: 30% (D7 retention)
✓ Revenue: $300-500/month (ads)
```

---

## Troubleshooting

### Database Issues

**Problem:** "psql: could not connect to server"  
**Solution:** Verify PostgreSQL running: `brew services list`

**Problem:** "No such file or directory" (GeoJSON)  
**Solution:** Check file path: `ls data/raw/seattle/`

### App Issues

**Problem:** "API connection refused"  
**Solution:** Verify API running: `http://localhost:8000/api/v1/health`

**Problem:** "App crashes on launch"  
**Solution:** Check logs: `flutter run -v`

### Deployment Issues

**Problem:** "Heroku build failed"  
**Solution:** Check buildpack: `heroku buildpacks`

---

## Rollback Plan

If launch fails:

```
Week 11:
  Step 1: Pause Google Play upload (if in review)
  Step 2: Fix critical bugs
  Step 3: Re-submit

If critical issue post-launch:
  Step 1: Push new APK version immediately
  Step 2: Mark broken version "deprecated" in store
  Step 3: Communicate with users
```

---

## Final Checklist (Before Launch)

```
[ ] All data ingested
[ ] All tests passing
[ ] API deployed to cloud
[ ] App tested on physical devices
[ ] Screenshots created
[ ] Store listings complete
[ ] Privacy policy published
[ ] APK signed with release key
[ ] IPA ready for upload
[ ] Release notes written
[ ] Team notified
```

---

**Timeline:** 12 weeks  
**Effort:** 150-200 hours  
**Cost:** $125 (app store fees)  
**Coverage:** 75% average  
**Revenue:** Starting Month 4  

**You got this! 🚀**
