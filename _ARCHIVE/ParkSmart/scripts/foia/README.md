# FOIA Request Templates for ParkSmart Data Collection

## Overview

This folder contains ready-to-send FOIA (Freedom of Information Act) request templates for obtaining parking data from four major US cities. These requests are designed to legally obtain high-confidence parking rule data for the ParkSmart application.

---

## Files in This Folder

1. **NYC_DOT_FOIL_Request.txt**
   - New York City Department of Transportation
   - Requests: Meter locations, street parking regulations, sign inventory
   - Expected data: 8,000-12,000 metered locations
   - Expected coverage improvement: +35-40%
   - Processing time: 30-60 days

2. **SF_SFMTA_FOIA_Request.txt**
   - San Francisco Municipal Transportation Agency
   - Requests: Meter inventory, street regulations, sweeping schedule
   - Expected data: 28,000-35,000 metered locations + cleaning schedule
   - Expected coverage improvement: +40-45%
   - Processing time: 10-30 days (CPRA faster than FOIL)

3. **LA_DOT_FOIA_Request.txt**
   - Los Angeles Department of Transportation
   - Requests: Meter inventory, street rules, sweeping schedule
   - Expected data: 8,000-15,000 meter locations + cleaning schedule
   - Expected coverage improvement: +25-35%
   - Processing time: 20-60 days

4. **Chicago_DOT_FOIA_Request.txt**
   - City of Chicago Department of Transportation
   - Requests: Smart meter locations, street parking, RPP zones, cleaning schedule
   - Expected data: 35,000-45,000 meter locations + zone data
   - Expected coverage improvement: +30-40%
   - Processing time: 20-60 days (Illinois FOIA)

---

## How to Use These Templates

### Step 1: Customize Your Information

Each template has placeholder fields in [brackets]. Fill in:

```
[YOUR NAME]
[YOUR EMAIL]
[YOUR PHONE]
[YOUR ADDRESS]
[DATE]
```

Replace these with your actual contact information. Use a personal email (not a corporate/business email if possible — government agencies are sometimes more responsive to individual requests).

### Step 2: Choose Your Submission Method

Each city has different submission preferences:

| City | Email | Mail | Method |
|------|-------|------|--------|
| **NYC** | foia@dot.nyc.gov | 55 Water St, 4th Floor, NY 10041 | Email preferred |
| **SF** | sfmta.foia@sfgov.org | 250 S Van Ness Ave, SF, CA | Email preferred |
| **LA** | ladot.foia@lacity.org | 100 S Main St #600, LA, CA | Email preferred |
| **Chicago** | doft.foia@cityofchicago.org | 121 N LaSalle #209, Chicago, IL | Email preferred |

**Recommendation:** Email is faster, leaves a timestamp, and doesn't require physical postage.

### Step 3: Submit the Request

For **email submission:**
1. Copy the template text into a new email
2. Replace all [BRACKETED] placeholders with your info
3. Use the subject line specified in each template
4. Send to the email address listed

**Example email subject:**
```
[FOIL Request] Parking Meter Locations and Street Parking Rules
```

For **mail submission** (if email fails):
1. Print the template
2. Sign and date it
3. Mail to the address in the template
4. Keep a copy for your records

### Step 4: Track Your Request

After submission:
- Save the email confirmation (has timestamp and auto-reply if applicable)
- Note the date you submitted
- Expected response time: 10-60 days (varies by jurisdiction)
- Create a tracking spreadsheet:

```
City | Date Submitted | Expected Response | Status | Response Date | Notes
-----|---|---|---|---|---
NYC | 2026-05-15 | 2026-06-14 | Pending | — | Sent to foia@dot.nyc.gov
SF | 2026-05-15 | 2026-05-25 | Pending | — | CPRA faster
LA | 2026-05-15 | 2026-06-04 | Pending | — | —
Chicago | 2026-05-15 | 2026-06-05 | Pending | — | —
```

### Step 5: When Data Arrives

When a city responds with data:
1. Save the file(s) to: `scripts/foia/responses/{city_name}/{date}/`
2. Note file format (CSV, Excel, PDF, etc.)
3. Create a parsing script: `scripts/build_{city}.py` (if not already created)
4. Geocode addresses to latitude/longitude (use Nominatim or Google Maps)
5. Snap to OSM ways (use scipy.spatial.KDTree + Overpass ways)
6. Merge with existing `assets/data/{city}.json`
7. Run `test_coverage.py` to measure improvement

Example folder structure:
```
scripts/foia/
├── NYC_DOT_FOIL_Request.txt
├── SF_SFMTA_FOIA_Request.txt
├── LA_DOT_FOIA_Request.txt
├── Chicago_DOT_FOIA_Request.txt
└── responses/
    ├── nyc/
    │   └── 2026-06-14/
    │       ├── parking_meters.csv
    │       └── street_regulations.xlsx
    ├── sf/
    │   └── 2026-05-25/
    │       └── sfmta_parking_data.json
    └── ...
```

---

## Legal Notes

- **FOIL (New York)**: 5 business days to acknowledge, 20-21 days to respond. Can request 30-day extension.
- **CPRA (California)**: 10 days to acknowledge, 20 days to respond (California is faster).
- **Illinois FOIA**: 5 business days to acknowledge, 21 days to respond.
- **FOIA Appeals**: Each jurisdiction has an appeal process if your request is denied. See templates for appeal contacts.

---

## What Happens If You Get Denied

If a city denies your request:

1. **Request reason:** They must explain why (privacy, proprietary info, doesn't exist, etc.)
2. **Appeal rights:** You have right to appeal (usually 20-30 days)
3. **Common reasons for denial:**
   - "Data does not exist" → But parking meters exist physically, data must exist
   - "Proprietary" → Public parking data should not be proprietary
   - "Personal information" → Request aggregated data only (no personal driver info)
4. **Escalation:**
   - NYC: NYC Comptroller's Office
   - SF: SF Sunshine Ordinance Task Force
   - LA: City Records Officer
   - Chicago: Cook County State's Attorney

**Note:** Most denials can be appealed. Parking data is almost always public information.

---

## Timeline for Data Collection

```
Week 1-3:   Submit all 4 FOIA requests (May 15-30)
            ↓
Month 2-3:  SF responds (CPRA ~10 days) → early June
            NYC responds (FOIL ~30 days) → mid-June
            ↓
Month 3-4:  LA responds (FOIA ~30 days) → mid-June
            Chicago responds (Illinois FOIA ~30 days) → mid-June
            ↓
Month 4-6:  Parse, geocode, snap to OSM, merge with existing data
            Rebuild assets/data/{city}.json
            Run test_coverage.py to validate improvement
            ↓
Month 6-8:  Integrate into app, prepare US beta launch
```

---

## Additional Resources

### For Questions About FOIA:

- **NYC FOIL:** https://www1.nyc.gov/site/cfo/foil/file-a-foia-request.page
- **SF CPRA:** https://www.sfgov.org/cpra-request
- **LA FOIA:** https://lafoil.lacity.gov/
- **Illinois FOIA:** https://cyberdriveillinois.com/departments/index/public_records/foia.html

### Tools for Geocoding & OSM Snapping:

- **Nominatim** (free): https://nominatim.org/
- **Google Maps Geocoding API** (free tier available): https://developers.google.com/maps/documentation/geocoding
- **Overpass** (free): https://overpass-turbo.eu/ (for getting OSM ways)
- **scipy.spatial.KDTree**: Built into Python, used for nearest-neighbor snapping

---

## Cost

- **FOIA fees:** $200-500 per city (photocopies, processing) = $800-2000 total
- **Most jurisdictions:** Waive fees for public benefit requests (mention in your request)
- **ParkSmart:** Free, public benefit → good chance of fee waiver

---

## Success Metrics

By end of Phase 2 (Month 3):
- All 4 cities should have submitted initial responses
- Combined: ~80,000-120,000 parking locations
- Combined with Mapillary (Phase 3): 70-80% coverage per city

---

## Questions?

If a city doesn't respond or gives you trouble:
1. Call their FOIA office directly (phone number usually in their response/on website)
2. File appeal through proper channels
3. Contact local news outlets (FOIA delays are newsworthy, especially for public benefit projects)
4. Meanwhile, continue with Mapillary/Phase 3 data collection (runs in parallel)

Good luck! 🚗📍
