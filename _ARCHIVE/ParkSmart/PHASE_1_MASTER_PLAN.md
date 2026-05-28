# Phase 1: Master Plan
## 75% Coverage Infrastructure in 12 Weeks

---

## Executive Summary

**Objective:** Build production-ready parking rules database + mobile app  
**Scope:** 5 cities (Seattle, SF, NYC, Toronto, Boston)  
**Timeline:** 12 weeks (3 months)  
**Cost:** $0-125 (just app store fees)  
**Coverage Target:** 75% average (currently available in open data)  
**Revenue Start:** Month 4 (ads + B2B API)  

---

## The 5 Core Documents

### 1. 📊 PROJECT_PHASE_1_DATA.md
**What:** Where to get parking data for 5 cities  
**Contains:**
- Seattle data sources (95% available)
- SF data sources (80% available)
- NYC data sources (60% available)
- Toronto data sources (70% available)
- Boston data sources (75% available)
- Download instructions for each
- Expected file formats and sizes

**Action:** Week 1 - Download all raw data  
**Owner:** You (4-6 hours)

---

### 2. 🗄️ DATA_SCHEMA.sql
**What:** PostgreSQL database structure  
**Contains:**
- street_segments table (blockfaces)
- parking_rules table (all rules)
- street_cleaning schedules
- user contributions
- views for coverage analysis
- functions for rule queries

**Action:** Week 2 - Load schema into PostgreSQL  
**Owner:** You (30 min setup, 2-3 hours testing)

---

### 3. 🔄 INGEST_PLAN.md
**What:** How to convert raw data into normalized database  
**Contains:**
- Step-by-step ingestion pipeline
- Python scripts (template provided)
- Data validation & QA process
- Troubleshooting guide
- Coverage report generation

**Action:** Weeks 3-6 - Run ingestion for all 5 cities  
**Owner:** You (2-4 weeks coding)  
**Output:** ~30,000 blockface segments + 100,000+ rules in database

---

### 4. 🌐 API_SPEC.md
**What:** REST API for parking rule queries  
**Contains:**
- 6 core endpoints:
  - `GET /parking/rules` (main query)
  - `GET /segment/{id}` (segment details)
  - `GET /segments` (search)
  - `GET /coverage` (statistics)
  - `POST /contributions` (community reports)
  - `GET /health` (monitoring)
- FastAPI implementation (code provided)
- Deployment instructions
- Testing examples

**Action:** Week 6-8 - Build & deploy API  
**Owner:** You (4-6 hours coding)  
**Output:** Live REST API (http://api.parksmart.app)

---

### 5. ✅ LAUNCH_CHECKLIST_PHASE_1.md
**What:** Week-by-week execution plan  
**Contains:**
- Week 1-2: Data acquisition (4-8 hours)
- Week 3-6: Data ingestion (4 weeks)
- Week 7-8: Mobile app integration (6-8 hours)
- Week 9-12: App store submission & launch (8-12 hours)
- Success metrics
- Troubleshooting guide

**Action:** Weeks 1-12 - Follow checklist step-by-step  
**Owner:** You (150-200 hours total)  
**Output:** Live on both Google Play + App Store

---

## Quick Start (Do This First)

### Today (Week 1, Day 1):
```
1. Read this document (10 min)
2. Skim PROJECT_PHASE_1_DATA.md (5 min)
3. Skim LAUNCH_CHECKLIST_PHASE_1.md (10 min)
4. Start Week 1 tasks (PROJECT_PHASE_1_DATA.md)
   [ ] Visit Seattle open data portal
   [ ] Download 4-5 datasets
   [ ] Verify files parse correctly
```

**Time: 30 min + 4 hours of downloading**

---

## 12-Week Timeline At A Glance

```
WEEK 1-2:  Data Acquisition
           ├─ Download 5 cities' open data
           ├─ Verify data quality
           └─ Setup PostgreSQL + PostGIS

WEEK 3-6:  Data Normalization
           ├─ Create 5 ingestion scripts
           ├─ Normalize to blockface model
           ├─ Validate coverage (76%)
           └─ Record data provenance

WEEK 7-8:  API Development
           ├─ Build REST API (FastAPI)
           ├─ Deploy to cloud (Heroku/Railway)
           ├─ Connect mobile app
           └─ Load test

WEEK 9:    Google Play Submission
           ├─ Create store listing
           ├─ Upload APK
           ├─ Internal testing
           └─ Wait for approval

WEEK 10:   App Store (iOS) Submission
           ├─ Create app in App Store Connect
           ├─ Upload IPA to TestFlight
           ├─ Internal testing
           └─ Submit for review

WEEK 11:   Promotion
           ├─ Promote Android to public
           ├─ Promote iOS from TestFlight
           └─ Monitor early users

WEEK 12:   Launch Complete + Plan Phase 2
           ├─ 75% coverage live
           ├─ Both stores live
           ├─ First downloads coming in
           └─ Start FOIA requests for Phase 2
```

---

## Key Metrics

### By Week 12 (Launch)

| Metric | Target |
|--------|--------|
| **Coverage** | 75% average (Seattle 95%, SF 80%, NYC 60%, Toronto 70%, Boston 75%) |
| **Database Size** | 27,575 segments, 102,341 rules |
| **API Response Time** | <500ms (avg) |
| **App Downloads (Week 1)** | 100+ |
| **User Rating** | 3.5+ stars |
| **Crash-Free Rate** | >99% |

### By Month 4 (Phase 2 Starts)

| Metric | Target |
|--------|--------|
| **Monthly Active Users** | 1000+ |
| **Community Contributions** | 50+ |
| **Revenue** | $300-500/month (ads) |
| **FOIA Status** | All 4 requests submitted |
| **User Retention (D7)** | 30%+ |

---

## Budget Breakdown

| Item | Cost | When |
|------|------|------|
| Google Play Developer | $25 | Week 9 |
| Apple Developer | $99 | Week 10 |
| Database (free tier) | $0 | Week 2 |
| API Hosting (free tier) | $0 | Week 8 |
| **TOTAL** | **$124** | — |

**No expenses for 12 months of operation!**

---

## Success Factors

✅ **You have all the data** (free, public)  
✅ **You have the architecture** (Phase 0 complete)  
✅ **You have the plan** (detailed, step-by-step)  
✅ **You have the time** (no rush)  
✅ **You have the skills** (Flutter, Python, SQL)  

**Only thing missing:** Action

---

## What Happens After Week 12?

### Phase 2: Expand & Monetize (Months 4-12)

Once Phase 1 ships with 75% coverage:

```
Parallel Track 1: FOIA Data
├─ FOIA requests already in motion (from Month 2)
├─ Responses arrive (June-July)
├─ Integrate: +20% coverage per city
└─ Result: 85-90% coverage by Month 8

Parallel Track 2: Mapillary ML
├─ Build parking sign detection (Months 4-6)
├─ OCR signs from street photos
├─ Add: +5-10% coverage
└─ Result: 90-95% coverage by Month 9

Parallel Track 3: Revenue
├─ Launch ads (Month 4)
├─ Sell B2B API to fleet companies (Month 5)
├─ Premium mobile subscription (Month 6)
└─ Revenue: $5K-20K/month by Year 2
```

---

## How to Use These Documents

### Reading Order
1. **This file** (PHASE_1_MASTER_PLAN.md) ← You are here
2. **LAUNCH_CHECKLIST_PHASE_1.md** (understand timeline)
3. **PROJECT_PHASE_1_DATA.md** (download data)
4. **DATA_SCHEMA.sql** (understand database)
5. **INGEST_PLAN.md** (understand ingestion)
6. **API_SPEC.md** (understand API)

### Doing Order
1. Week 1: Follow LAUNCH_CHECKLIST_PHASE_1.md → Week 1 section
2. Week 2: Follow → Week 2 section
3. Week 3-6: Follow INGEST_PLAN.md
4. Week 7-8: Follow LAUNCH_CHECKLIST_PHASE_1.md → Week 7-8 section
5. Week 9-12: Follow LAUNCH_CHECKLIST_PHASE_1.md → Week 9-12 section

---

## Decision: Go or No-Go?

### Go Criteria (You're Ready If):
- ✅ You have 200 hours over next 12 weeks (~4 hours/week)
- ✅ You have PostgreSQL + Python skills
- ✅ You want to build data infrastructure (not just mobile app)
- ✅ You're OK with $0 initial cost
- ✅ You're OK with 75% coverage (not 100%)

### No-Go Criteria (Pause If):
- ❌ You need to ship in <6 weeks
- ❌ You need 95%+ coverage immediately
- ❌ You don't have time for database work
- ❌ You only want mobile app development

---

## Your Move

### Option A: Start Week 1 Immediately
```
Today: Download data (4 hours)
Next week: Setup database (3 hours)
Follow 12-week checklist
Result: Live app by Week 12
```

### Option B: Review First
```
Today: Read all 5 documents (4-5 hours)
Tomorrow: Make go/no-go decision
Week 1+: Start if go
```

### Option C: Hire Help
```
If 200 hours is too much:
├─ Hire Python dev for ingestion (Weeks 3-6)
├─ Hire Flutter dev for app (Weeks 7-8)
├─ You supervise + coordinate
Result: Same timeline, shared effort
```

---

## Support

### If You Get Stuck

| Problem | Document | Section |
|---------|----------|---------|
| Can't find data | PROJECT_PHASE_1_DATA.md | Each city section |
| Schema errors | DATA_SCHEMA.sql | Setup instructions |
| Ingestion fails | INGEST_PLAN.md | Common issues |
| API not working | API_SPEC.md | Testing section |
| App crashes | LAUNCH_CHECKLIST.md | Troubleshooting |

---

## The Ask

**Commit to Week 1 of this plan:**

```
[ ] Week 1: Download data + verify (4-6 hours)
[ ] Week 2: Setup database (3-4 hours)

If Week 1-2 goes well → Commit to full 12 weeks
If Week 1-2 hits blockers → Pause and reassess
```

**That's it. No commitment to all 12 weeks. Just commit to 2 weeks.**

---

## Final Thought

You said:
> "Je ne suis pas presser pour publier app. Je veux des résultats convaincants."
> (I'm not in a rush. I want convincing results.)

This plan gives you exactly that:

- **Convincing results:** 75% coverage across 5 real cities
- **No rush:** 12 weeks of structured work
- **Production quality:** Real database, real API, tested app
- **Low risk:** Free data, free infrastructure, only $125 app fees
- **Revenue ready:** Months 4-12 revenue kicks in

---

## Summary

| Item | Status |
|------|--------|
| **Data** | ✅ Available (free, public) |
| **Architecture** | ✅ Designed (5 docs) |
| **Code** | ✅ Templates provided |
| **Timeline** | ✅ Detailed (12-week plan) |
| **Budget** | ✅ Minimal ($125) |
| **Decision** | ⏳ Your call |

---

## Next Step

**Pick one:**

A) **Go:** Start Week 1 tasks today (PROJECT_PHASE_1_DATA.md)  
B) **Review:** Read all 5 docs first (4-5 hours)  
C) **Decide Later:** Come back tomorrow

**Time to decide: 5 seconds**  
**Time to start: 30 minutes**  
**Time to launch: 12 weeks**

---

**Good luck. You got this.** 🚀

---

*Last updated: 2026-05-15*  
*Status: Ready to execute*  
*Next milestone: Week 1 complete (data downloaded)*
