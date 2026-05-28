# ParkSmart Data Collection Strategy
## Phase 1-6: Canada Launch → US Expansion (12 Months)

---

## Executive Summary

**Objective:** Achieve 60-75% parking rule coverage across 6 North American cities.

**Constraint:** Official APIs are permanently broken/gated. Free/open data alone = max 15% coverage.

**Solution:** Hybrid data collection: FOIA requests (legal, high-confidence) + Mapillary ML OCR (fast, scalable).

**Feasibility:** ✅ YES. Cost: $2000-3500. Timeline: 12 months. Risk: Low (parallel tracks).

---

## Phase Breakdown

### Phase 1: Canada Launch (Months 1-3)
**Goal:** Release first production version with Montreal data + Toronto baseline.

**Data sources:**
- Montreal: Existing meter + alternating + cleaning rules (merged in Phase 0) = 13.6% coverage
- Toronto: Open Toronto parking data + OpenStreetMap baseline = ~20% coverage (TBD: scripts)
- Quebec City: Municipal data + OSM defaults = ~15% coverage (TBD: scripts)

**Deliverable:**
- Play Store: "ParkSmart Canada" APK
- Supported cities: Montreal (13.6%), Toronto (TBD), Quebec City (TBD)
- Store description: "Parking rules for Canadian cities. US expansion coming Q4 with FOIA + community data."

**Risks:** Toronto/Quebec City scripts may fail like US scripts. Mitigation: Build fallback demo data.

**Effort:** 2 weeks (build + Play Store submission).

---

### Phase 2: Submit FOIA Requests (Months 2-3, parallel with Phase 1)
**Goal:** Legally obtain parking sign locations and rules from 4 US cities.

**FOIA Request Strategy:**
- **Jurisdiction:** US city transportation/parking departments
- **Timeline:** 30-90 days per request
- **Cost:** $200-500 per city (photocopies, processing) × 4 = $800-2000
- **Format:** Spreadsheet (street name, address, rule type, rule text)
- **Data quality:** 95% confidence (official source)

#### FOIA Request 1: NYC DOT Parking Regulations

**Request To:** NYC Department of Transportation, Records Management
**Contact:** foia@dot.nyc.gov

**Template:**
```
Subject: FOIL Request – Parking Meter Locations and Street Parking Rules

This is a request under the Freedom of Information Law (FOIL) for:

1. Complete list of all NYC DOT-regulated parking meters with locations 
   (latitude, longitude, block, lot):
   - Meter ID
   - Street address (block/lot)
   - Parking rules (hours, rate, max stay)
   - Effective date
   Format: CSV or Excel

2. Complete list of all NYC DOT street parking regulations by street segment:
   - Street name, from/to cross streets
   - Regulation type (meter, no parking, hours-restricted, etc.)
   - Rule text (days of week, hours, max stay, resident only, etc.)
   - Effective date
   Format: CSV or Excel

3. Any parking sign inventory database with:
   - Sign location (address, latitude/longitude)
   - Sign type/regulation code
   - Installation date
   Format: CSV or Excel

Preferred format: CSV/Excel (machine-readable).
Target response date: [30 days from submission date]

Requestor: [Your Name]
Email: [Your Email]
Organization: ParkSmart Mobile App
Purpose: Public parking information app for NYC residents
```

**Expected data:** 8000-12000 metered locations + sign locations.  
**Expected coverage gain:** +35-40% (NYC total: 35-40% → 70-80%).

---

#### FOIA Request 2: SF SFMTA Parking Data

**Request To:** San Francisco Municipal Transportation Agency, FOIA
**Contact:** sfmta.foia@sfgov.org

**Template:**
```
Subject: FOIA Request – San Francisco Parking Meter and Street Parking Data

This is a request for all public parking information maintained by SFMTA:

1. Parking meter inventory:
   - Meter ID, location (address, coordinates)
   - Rate schedule (hours, rate, max stay, days)
   - Zone/district
   Format: CSV/Excel

2. Street parking regulations (all segments with rules):
   - Street name, from/to cross streets
   - Regulation type
   - Rule text (hours, days, max stay, permit types)
   - Effective date
   Format: CSV/Excel

3. Parking sweeping schedule (street cleaning):
   - Street segments
   - Sweeping day(s) of week
   - Sweeping hours
   Format: CSV/Excel

4. Any downloadable parking database or API documentation 
   (if available)

Requestor: [Your Name]
Email: [Your Email]
Organization: ParkSmart Mobile App
Purpose: Public parking information for SF residents
```

**Expected data:** 28000-35000 metered locations + cleaning schedule.  
**Expected coverage gain:** +40-45% (SF total: 40-45% → 85%+).

---

#### FOIA Request 3: LA Department of Transportation

**Request To:** Los Angeles Department of Transportation, Records Section
**Contact:** ladot.foia@lacity.org

**Template:**
```
Subject: FOIA Request – Los Angeles Parking Rules and Meter Data

This is a request for all public parking data:

1. Parking meter inventory:
   - Meter locations (address, coordinates)
   - Rate and time restrictions
   - Zone
   Format: CSV/Excel

2. Street parking regulations (curb space):
   - Street address/segment
   - Regulation type
   - Rule (hours, days, max stay, permit info)
   - Effective date
   Format: CSV/Excel

3. Parking lot data (public):
   - Address, capacity
   - Rate
   - Hours
   Format: CSV/Excel

4. Street sweeping/cleaning schedule:
   - Streets/areas
   - Sweeping day/time
   Format: CSV/Excel

Requestor: [Your Name]
Email: [Your Email]
Organization: ParkSmart Mobile App
Purpose: Public parking app for LA residents
```

**Expected data:** 8000-15000 meter locations + street cleaning schedule.  
**Expected coverage gain:** +25-35% (LA baseline low, TBD).

---

#### FOIA Request 4: Chicago Department of Transportation

**Request To:** Chicago Department of Transportation, FOIA Office
**Contact:** doft.foia@cityofchicago.org

**Template:**
```
Subject: FOIA Request – Chicago Parking Meter and Street Parking Rules

This is a request for Chicago parking data:

1. Smart Meter (meter) locations and rates:
   - Meter ID
   - Address/location (coordinates)
   - Rate schedule (hours, days, rate)
   - Zone
   Format: CSV/Excel

2. Street parking regulations (non-meter):
   - Street/block
   - Regulation type
   - Rule text (hours, days, max stay, permits)
   - Effective date
   Format: CSV/Excel

3. Residential Permit Parking (RPP) zones:
   - Zone boundaries/streets
   - Permit requirements
   Format: CSV/Excel

4. Street sweeping schedule:
   - Streets/areas
   - Sweeping day(s)/hours
   Format: CSV/Excel

Requestor: [Your Name]
Email: [Your Email]
Organization: ParkSmart Mobile App
Purpose: Public parking app
```

**Expected data:** 35000-45000 meter locations + RPP zone data.  
**Expected coverage gain:** +30-40% (Chicago total: 30-40% → 65-75%).

---

### Phase 3: Build Mapillary ML Parser (Months 3-6, parallel with FOIA wait)
**Goal:** Detect and OCR parking signs from street-level photos.

**Data source:** Mapillary (crowdsourced street imagery, 100% free)

**Pipeline:**
1. **Download imagery**: Mapillary API → all parking signs in SF, NYC, LA, Chicago
2. **Sign detection**: YOLO v5 (parking sign recognition model)
3. **OCR**: Tesseract → extract rule text from sign
4. **Geocode**: Snap sign location to OSM way
5. **Parse rule**: Normalize text → rule structure (days, hours, max stay)

**Coverage expectations:**
- SF: 55-65% (best Mapillary coverage in US)
- NYC: 40-50% (good coverage)
- LA: 35-45% (moderate coverage)
- Chicago: 30-40% (moderate coverage)

**Cost:** $800-1500 (YOLOv5 training on parking signs, Mapillary credits).

**Effort:** 6-8 weeks (including testing/validation).

**Output format:** Same JSON structure as Phase 0 (meters, alternating/cleaning combined).

---

### Phase 4: Integrate FOIA Data (Months 6-8, as data arrives)
**Goal:** Merge FOIA data into city JSON files.

**Process per city:**
1. **Receive FOIA data** (spreadsheet or PDF)
2. **Parse & geocode**: Address → latitude/longitude (Google Maps API or Nominatim)
3. **Snap to OSM**: Find nearest street way
4. **Merge with Mapillary**: De-duplicate, prefer FOIA (95% confidence)
5. **Update JSON**: Rebuild assets/data/{cityId}.json
6. **Test coverage**: Run test_coverage.py to measure improvement

**Expected coverage at end of Phase 4:**
- NYC: 70-80% (FOIA 35% + Mapillary 40% + de-dup = 70%)
- SF: 85%+ (Mapillary 60% + FOIA 40% + de-dup = 85%)
- LA: 55-65% (FOIA 30% + Mapillary 35% + de-dup = 55%)
- Chicago: 65-75% (FOIA 35% + Mapillary 35% + de-dup = 65%)

**Effort:** 2 weeks per city (4 weeks total).

---

### Phase 5: Beta Test US Version (Months 8-10)
**Goal:** Release closed-beta with community contributions enabled.

**Actions:**
1. **Build APK**: "ParkSmart US (Beta)" with 4 cities + contribution UI
2. **Distribution**: TestFlight (iOS) + Google Play internal testing
3. **Collect feedback**: Contributions via in-app form
4. **Validate data**: Community reports + expert review (city traffic engineers, transit advocates)
5. **Refine coverage**: Prioritize high-traffic areas (downtown, commercial zones)

**Expected: 10-20% coverage improvement from community contributions.**

---

### Phase 6: Launch US (Months 10-12)
**Goal:** Release public version with 65-75% coverage per city + trust layer.

**Actions:**
1. **Build final APK**: "ParkSmart US" (4 cities)
2. **App Store submission**: Both iOS + Android Play Store
3. **Marketing**: "Data verified with city governments + community"
4. **UI update**: Show "Last verified: [date]" per city

**Go-to-market message:**
```
ParkSmart — Parking Rules, Verified.
Available now: Canada (Montreal, Toronto, Quebec City)
Available now: US (New York, San Francisco, Los Angeles, Chicago)

Parking rules are updated from official city data (FOIA), 
street-level photography, and verified by our community.

Coverage: 13-85% per city (improving monthly)
```

---

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| **FOIA request denied** | Submit appeal or escalate to city council; parallel Mapillary ensures progress |
| **FOIA slow (90+ days)** | Mapillary runs in parallel; US beta launch by Phase 6 even if FOIA incomplete |
| **Mapillary coverage poor** | Use fallback: infer from street sweeping schedules + parking lot data |
| **ML OCR accuracy <80%** | Manual review by community; incentivize contributions |
| **OSM snapping errors** | KDTree snapping + manual QA by traffic engineers |

---

## Success Metrics

By end of Phase 6:

| City | Target Coverage | Real-time Accuracy | Community Trust |
|------|---|---|---|
| Montreal | 30-40% | 90%+ (updated quarterly) | High (official data) |
| Toronto | 25-35% | 85%+ | High |
| Quebec City | 20-30% | 85%+ | High |
| NYC | 70-80% | 90%+ | High (FOIA) |
| SF | 85%+ | 95%+ | Very high |
| LA | 55-65% | 85%+ | Medium-high |
| Chicago | 65-75% | 90%+ | High (FOIA) |

---

## Budget Summary

| Item | Cost | Phase |
|------|------|-------|
| FOIA requests (4 cities) | $800-2000 | 2 |
| Mapillary credits + API | $300-500 | 3 |
| YOLO training (parking signs) | $500-1000 | 3 |
| Geocoding API (Google/Nominatim) | $200-500 | 4 |
| **Total** | **$1800-4000** | — |

---

## Timeline Summary

```
Month 1-3:   ✓ Phase 1 (Canada launch) + Phase 2 FOIA (start)
Month 2-4:   ✓ Phase 2 (FOIA wait) + Phase 3 (Mapillary parser build)
Month 5-6:   ✓ Phase 3 (Mapillary completion) + Phase 4 (FOIA integration)
Month 7-8:   ✓ Phase 4 (final data merge)
Month 8-10:  ✓ Phase 5 (US beta) + community testing
Month 10-12: ✓ Phase 6 (US public launch)
```

**Parallel tracks allow overlap — full 12-month timeline is conservative.**

---

## Next Immediate Actions

1. **This week:**
   - [ ] Finalize Toronto/Quebec City data collection scripts
   - [ ] Build Canada APK (Montreal + fallback Toronto/Quebec)
   - [ ] Test on Android/iOS simulators

2. **Week 2-3:**
   - [ ] Customize + send FOIA requests to NYC, SF, LA, Chicago
   - [ ] Create Mapillary ML training dataset (parking signs)

3. **Week 4-6:**
   - [ ] Build Mapillary OCR pipeline
   - [ ] Start training YOLO v5 model

4. **Week 8+:**
   - [ ] Monitor FOIA responses, integrate as data arrives
   - [ ] Beta launch US version when Phase 4 coverage hits 50%+
