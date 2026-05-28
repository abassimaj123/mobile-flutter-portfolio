# Phase 1: Canada Launch Checklist
## ParkSmart v0.1.0-beta.1 (May-July 2026)

---

## Executive Summary

**Target:** Launch "ParkSmart Canada" to Google Play Store (Android) + Apple App Store (iOS)  
**Scope:** 3 cities (Montreal, Toronto, Quebec City)  
**Current Status:** 13.6% coverage (Montreal) + placeholder data (Toronto, Quebec City)  
**Timeline:** 2-3 weeks  
**Effort:** 40-50 hours  

---

## Phase 1 Objectives

- ✅ Montreal: Launch with existing 13.6% coverage + OsmParkingService fallback
- ✅ Toronto: Placeholder structure (0% data, fallback rules apply)
- ✅ Quebec City: Placeholder structure (0% data, fallback rules apply)
- ✅ Build APK (Android release)
- ✅ Build IPA (iOS release)
- ✅ Submit to app stores
- ✅ Begin FOIA request submission (parallel track)
- ✅ Enable community contributions via in-app form

**Not included in Phase 1:**
- ❌ US cities (Vancouver, NYC, SF, LA, Chicago) — marked "Coming Soon"
- ❌ Mapillary ML parser — builds in Phases 3-4
- ❌ Real Toronto/Quebec data — requires API integration or FOIA

---

## Checklist Items

### Week 1: Code & Build Prep

#### 1.1 Update App Version & Metadata

- [ ] **pubspec.yaml**: Update version to `0.1.0-beta.1`
  ```yaml
  version: 0.1.0-beta.1+1
  ```

- [ ] **pubspec.yaml**: Update app name/description
  ```yaml
  name: ParkSmart
  description: "Know before you park. Parking rules for Canadian cities."
  ```

- [ ] **lib/main.dart**: Update app title
  ```dart
  title: "ParkSmart Canada"
  ```

- [ ] **android/app/build.gradle**: Update versionCode to 1
  ```gradle
  versionCode 1
  versionName "0.1.0-beta.1"
  ```

- [ ] **ios/Runner/Info.plist**: Update CFBundleShortVersionString
  ```xml
  <key>CFBundleShortVersionString</key>
  <string>0.1.0-beta.1</string>
  ```

**Estimated time:** 30 minutes

---

#### 1.2 Update App Store Metadata

Create marketing copy for app stores:

- [ ] **App Title:** "ParkSmart Canada" (max 50 chars)
- [ ] **Subtitle:** "Parking Rules. Real Time." (max 30 chars for iOS)
- [ ] **Description (short):** 
  ```
  Know before you park.

  ParkSmart shows you parking rules in real-time:
  - Meter rates & maximum stay
  - Odd/even alternating parking
  - Street cleaning schedules
  - Time-limited parking restrictions

  Available in: Montreal, Toronto, Quebec City
  Coming soon: Major US cities

  Tap a street to see today's rules. Plan ahead, avoid tickets.
  ```

- [ ] **Description (long, Google Play):**
  ```
  PARKING RULES, SIMPLIFIED
  
  ParkSmart shows you parking regulations in real-time. 
  Stop guessing. Stop getting tickets.

  WHAT'S INCLUDED
  ✓ Meter locations and rates
  ✓ Odd/even alternating parking
  ✓ Street cleaning schedules
  ✓ Time-limited parking zones
  ✓ Permit parking areas
  
  CURRENT CITIES
  • Montreal (13% coverage — growing daily)
  • Toronto (launching with community data)
  • Quebec City (launching with community data)
  
  COMING SOON
  • New York City
  • San Francisco
  • Los Angeles
  • Chicago

  HOW IT WORKS
  1. Open the map and find a street
  2. Tap the street to see today's rules
  3. See parking restrictions, meter rates, cleaning schedules
  4. Report missing or incorrect rules via the app
  
  ABOUT THE DATA
  ParkSmart combines:
  - Official city parking data (FOIA requests)
  - OpenStreetMap parking information
  - Community contributions
  
  Our goal: Accurate, up-to-date parking rules for every street.

  PRIVACY
  - No location tracking
  - No personal data collected
  - Data stored locally on your device
  
  FEEDBACK
  Found incorrect parking info? Tap "Report a Rule" in the app.
  Help us improve!

  VERSION 0.1.0 BETA
  Early access. Data coverage improving daily.
  Send feedback to: [YOUR EMAIL]
  ```

- [ ] **Promotional Text:**
  ```
  Beta launch: Try ParkSmart in Montreal, Toronto, Quebec City. 
  Report rules to help us expand to US cities.
  ```

- [ ] **Keywords:** "parking, rules, montreal, toronto, canada, street parking, parking meter, no parking, street cleaning"

**Estimated time:** 1 hour

---

#### 1.3 Create App Store Screenshots

Need 2-5 screenshots for each app store:

**Screenshot 1: App Overview**
- Map view of Montreal
- Show street colors (blue = OK, red = no parking, etc.)
- Text: "Know before you park"

**Screenshot 2: Street Details**
- Open street rule detail for a Montreal street
- Show: meter rate, max stay, hours, cleaning schedule
- Text: "Tap any street to see the rules"

**Screenshot 3: Contribution Feature**
- Show "Signaler une règle" (Report Rule) button in bottom sheet
- Text: "Help us improve — report incorrect or missing rules"

**Screenshot 4: Multi-City**
- Show city selector or multiple cities
- Text: "Montreal, Toronto, Quebec City. Coming: New York, San Francisco, LA, Chicago"

**Screenshot 5: Coverage**
- Show coverage metrics or legend
- Text: "Data updated daily from city officials + community"

**Tools:** Figma, Adobe XD, or Canva to create mockups

**Estimated time:** 2-3 hours (or hire on Fiverr: $50-100)

---

#### 1.4 Verify Code Compiles

```bash
cd D:\mob\ParkSmart

# Run flutter analyze
flutter analyze --no-fatal-infos

# Expected: 5 pre-existing issues (non-critical)
# Should see: 0 new errors

# Run flutter build (dry run)
flutter build apk --dry-run
```

- [ ] `flutter analyze` returns 0 new errors
- [ ] `flutter build apk --dry-run` succeeds

**Estimated time:** 10 minutes

---

### Week 2: Build & Test

#### 2.1 Build Android APK (Release)

```bash
cd D:\mob\ParkSmart

# Create keystore (one-time)
# keytool -genkey -v -keystore upload-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload-key

# Build APK
flutter build apk --release

# Output: build/app/outputs/flutter-app/release/app-release.apk
```

- [ ] APK builds without errors
- [ ] APK is signed with your release keystore
- [ ] APK size < 50 MB (Flutter + assets typical: 30-40 MB)

**Location:** `build/app/outputs/flutter-app/release/app-release.apk`

**Estimated time:** 15 minutes (build) + 10 minutes (testing)

---

#### 2.2 Test Android APK on Device

```bash
# Connect Android device via USB
# Enable Developer Mode: Settings > About > Build Number (tap 7x) > Enable USB Debugging

adb install build/app/outputs/flutter-app/release/app-release.apk

# Or use Flutter
flutter install
```

**Test cases:**
- [ ] App launches without crash
- [ ] Map loads with Montreal data visible
- [ ] Tap a street → see rule details
- [ ] Tap "Signaler une règle" → open contribution form
- [ ] Fill contribution form → data saved
- [ ] Switch to Toronto → shows placeholder message
- [ ] Switch to Quebec City → shows placeholder message
- [ ] Switch to US cities → shows "Coming Soon"

**Estimated time:** 20 minutes

---

#### 2.3 Build iOS IPA (Release)

```bash
# Requires macOS + Xcode
# On Windows: Use GitHub Actions CI/CD or hire Mac developer

# If you have access to Mac:
cd ios
pod install
cd ..
flutter build ios --release

# Output: build/ios/iphoneos/Runner.app
```

**Alternative:** Use cloud CI/CD:
- GitHub Actions: Build iOS on macOS runner (free, 20 min build time)
- EAS Build (Expo): $7 per build, Supports Flutter

**Estimated time:** 30 minutes (if on Mac) or 2-3 hours (if using CI/CD)

---

#### 2.4 Test iOS IPA on Device

**Option A (With Mac):**
```bash
xcode-select --install
flutter install -d <device-id>
```

**Option B (Without Mac):**
- Use TestFlight (Apple's beta testing platform)
- Upload IPA to TestFlight → invite testers
- Testers see app in TestFlight app (takes ~2-4 hours for review)

**Test cases:** Same as Android (2.2)

**Estimated time:** 20 minutes (with Mac) or 4 hours (TestFlight review)

---

### Week 2-3: App Store Submission

#### 3.1 Create Google Play Developer Account

- [ ] Go to: https://play.google.com/console
- [ ] Sign in with Google account (abassimaj@gmail.com)
- [ ] Pay $25 one-time developer registration fee
- [ ] Create first app listing

**Estimated time:** 30 minutes (1st time) or 5 minutes (if already set up)

---

#### 3.2 Create Google Play App Listing

In Google Play Console:

- [ ] **App name:** "ParkSmart Canada"
- [ ] **Default language:** English
- [ ] **App category:** Maps & Navigation
- [ ] **Content rating:** Everyone (no age restrictions)

**Estimated time:** 10 minutes

---

#### 3.3 Fill Out Google Play Listing Details

**In Google Play Console > Your app > Store listing:**

- [ ] **Short description** (80 chars): "Parking rules in real-time for Montreal, Toronto, Quebec City"
- [ ] **Full description**: (from 1.2 above)
- [ ] **Screenshots** (4-5, from 1.3 above)
- [ ] **Feature graphic** (1024x500px): App icon + "ParkSmart Canada" text
- [ ] **App icon** (512x512px): Use your app logo
- [ ] **Content rating questionnaire:**
  - [ ] No sexual content
  - [ ] No violence
  - [ ] No profanity
  - [ ] No drug/alcohol references
  - [ ] No personal information collection
  - [ ] Submit → should get "Everyone" rating

- [ ] **Privacy policy URL:** https://[your-domain.com/privacy] (create this page if needed, or use a privacy policy generator like TermsFeed)

- [ ] **Email address for support:** your@email.com

- [ ] **Website:** https://[your-website.com] (or leave blank for beta)

**Estimated time:** 1-2 hours

---

#### 3.4 Upload APK to Google Play Console

- [ ] Go to: **Release > Internal testing > Create new release**
- [ ] Upload APK (from 2.1)
- [ ] Review prompt: "Android 5.0+ required, release notes, etc."
- [ ] **Release notes:** 
  ```
  ParkSmart v0.1.0 Beta

  NEW:
  - Map view with parking rules
  - Meter rates and schedules
  - Street cleaning info
  - Odd/even alternating parking

  CITIES:
  - Montreal (13% coverage)
  - Toronto (placeholder)
  - Quebec City (placeholder)
  - US coming soon

  BETA:
  Help us improve by reporting rules via "Signaler une règle"
  ```
- [ ] Click "Review release" then "Start rollout to Internal testing"

**Estimated time:** 15 minutes

---

#### 3.5 Test Internal Testing Track

- [ ] Invite yourself as internal tester
- [ ] Accept invite via email link
- [ ] Download app from Google Play (internal testing version)
- [ ] Run full test suite (same as 2.2)
- [ ] If all pass: Promote to "Closed beta" (50-100 testers)
- [ ] If all pass after 1 week: Promote to "Production" (public release)

**Estimated time:** 1 hour (initial test) + 7 days (waiting for feedback)

---

#### 3.6 Create App Store (iOS) Listing

**On Mac or via Apple Developer Portal:**

- [ ] Go to: https://appstoreconnect.apple.com
- [ ] Create new app:
  - [ ] **Name:** "ParkSmart Canada"
  - [ ] **Bundle ID:** com.yourcompany.parksmart (e.g., com.abassimaj.parksmart)
  - [ ] **SKU:** parksmart-ca-001
  - [ ] **Primary category:** Maps
  - [ ] **Secondary category:** (optional)

- [ ] Fill in app information:
  - [ ] **Subtitle (iOS only):** "Know before you park"
  - [ ] **Description**: (from 1.2 above)
  - [ ] **Keyword**s: parking, montreal, toronto, rules, meter
  - [ ] **Support URL:** your@email.com
  - [ ] **Privacy policy URL:** (create or leave blank for beta)
  - [ ] **Screenshots** (5, from 1.3)
  - [ ] **App preview video** (optional, skip for beta)
  - [ ] **App icon** (1024x1024px)

**Estimated time:** 1 hour

---

#### 3.7 Upload IPA to TestFlight

- [ ] Build IPA (from 2.3)
- [ ] In App Store Connect: **TestFlight > iOS Builds > New Version**
- [ ] Upload IPA (takes 5-10 min for processing)
- [ ] **Build details:**
  - [ ] Whats' new: (same release notes as 3.4)
  - [ ] Add testers (invite yourself + trusted friends)

- [ ] **Wait for Apple review** (typically 12-24 hours)
- [ ] When approved, testers can download from TestFlight app

**Estimated time:** 30 minutes (upload) + 24 hours (review)

---

#### 3.8 Submit to App Store (Production)

After TestFlight is stable (1 week minimum):

- [ ] In App Store Connect: **Version > Submit for Review**
- [ ] Answer submission questions:
  - [ ] "Does your app use encryption?" → No (unless you add end-to-end encryption later)
  - [ ] "Does your app use third-party SDKs?" → Yes (Flutter, Nominatim, OSM)
  - [ ] "Does your app collect user data?" → No (local only)
  - [ ] "Does your app require user authentication?" → No
  - [ ] **Age rating:** Everyone

- [ ] **Pricing:** Free
- [ ] **Submit** → Apple reviews (1-3 days)

**Estimated time:** 30 minutes (submission) + 3 days (review)

---

### Parallel Track: FOIA Requests (Week 2-3)

#### 4.1 Prepare FOIA Requests

- [ ] Read `scripts/foia/README.md`
- [ ] Customize all 4 request templates:
  - [ ] Replace [YOUR NAME], [YOUR EMAIL], [YOUR PHONE], [DATE]
  - [ ] NYC_DOT_FOIL_Request.txt
  - [ ] SF_SFMTA_FOIA_Request.txt
  - [ ] LA_DOT_FOIA_Request.txt
  - [ ] Chicago_DOT_FOIA_Request.txt

**Estimated time:** 30 minutes

---

#### 4.2 Send FOIA Requests

- [ ] **NYC:** Email to foia@dot.nyc.gov (subject: [FOIL Request] Parking Data)
- [ ] **SF:** Email to sfmta.foia@sfgov.org (subject: [CPRA Request] Parking Data)
- [ ] **LA:** Email to ladot.foia@lacity.org (subject: [FOIA Request] Parking Data)
- [ ] **Chicago:** Email to doft.foia@cityofchicago.org (subject: [FOIA Request] Parking Data)

- [ ] Keep copy of email confirmations
- [ ] Create tracking spreadsheet:
  ```
  City | Date Sent | Expected Response | Status
  NYC | 2026-05-20 | 2026-06-19 | Pending
  SF | 2026-05-20 | 2026-05-30 | Pending
  LA | 2026-05-20 | 2026-06-09 | Pending
  Chicago | 2026-05-20 | 2026-06-10 | Pending
  ```

**Estimated time:** 30 minutes

---

## Timeline Summary

```
Week 1:
  Mon-Tue: Code prep (version, metadata, screenshots)
  Wed-Thu: Build APK + test on device
  Fri: Build IPA (or set up CI/CD)

Week 2:
  Mon-Tue: Create Google Play listing + upload APK
  Wed-Thu: Create App Store listing + upload IPA
  Fri: Send FOIA requests (parallel)

Week 3:
  Mon-Tue: Monitor app store reviews
  Wed-Thu: Fix any critical issues
  Fri: Promote to public release (both stores)

Post-launch (ongoing):
  - Monitor app store reviews/ratings
  - Respond to community contributions
  - Track FOIA request responses
  - Plan Phase 2 (Mapillary + FOIA integration)
```

---

## Success Criteria for Phase 1

By end of Week 3:

- ✅ "ParkSmart Canada" live on Google Play Store
- ✅ "ParkSmart Canada" live on App Store
- ✅ 100+ downloads in first week (target for Canadian market)
- ✅ Average rating: 3.5+ stars (expected: 3.5-4.5 due to limited data)
- ✅ All 4 FOIA requests submitted
- ✅ At least 50 community contributions collected
- ✅ Zero critical crashes (monitor Crashlytics)

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| App review rejected | Ask for feedback, resubmit. Usually takes 2-3 days per cycle |
| Low downloads | Promote on Reddit (/r/montreal, /r/toronto, /r/quebec), Twitter, local Facebook groups |
| Low ratings (due to incomplete data) | Set expectations clearly: "Beta — data improving" in description. Enable contributions. |
| FOIA requests denied | Appeal or escalate. Parallel Mapillary work continues. |
| Critical bug found | Submit hotfix: v0.1.1-beta.2 (expedited review) |

---

## Budget for Phase 1

| Item | Cost | Notes |
|------|------|-------|
| Google Play Developer Account | $25 | One-time |
| App Store Account (iOS) | $99 | Annual |
| Screenshots/design (Fiverr) | $100 | Optional, DIY saves cost |
| FOIA requests | $0 | Request fee waiver |
| **Total** | **$124-224** | Minimal |

---

## What's NOT in Phase 1

❌ US cities (launch with "Coming Soon")  
❌ Real Toronto/Quebec data (placeholder only)  
❌ Mapillary ML parser  
❌ FOIA data integration (wait for responses)  
❌ Analytics tracking  
❌ Premium subscription  
❌ Social sharing features  

---

## Next Steps After Phase 1 (Weeks 4-12)

1. **Phase 2:** Monitor FOIA requests, integrate data as it arrives
2. **Phase 3:** Build Mapillary ML parking sign OCR
3. **Phase 4:** Merge FOIA + Mapillary data into app
4. **Phase 5:** Beta test US cities with community feedback
5. **Phase 6:** Public launch of US version with 65-75% coverage

---

## Questions?

**For app store issues:** Check `[city]_store_help.md` files (create as needed)  
**For FOIA issues:** See `scripts/foia/README.md`  
**For code issues:** Run `flutter analyze` and fix errors

**Contact:** abassimaj@gmail.com (for pull requests, bug reports, etc.)

---

**Status:** Ready to execute Phase 1 immediately.

**Last updated:** 2026-05-15  
**Expected completion:** 2026-06-07 (3 weeks)
