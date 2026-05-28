# REST API Specification
## ParkSmart Data Infrastructure

---

## Overview

**Purpose:** Provide clean REST API for parking rule queries  
**Technology:** FastAPI + uvicorn  
**Database:** PostgreSQL + PostGIS  
**Deployment:** Cloud (Heroku/Railway free tier, or self-hosted)  
**Response Format:** JSON  

---

## Core Endpoints

### 1. GET /api/v1/parking/rules

**Query parking rules for coordinates + datetime**

#### Request

```
GET /api/v1/parking/rules?lat=47.6062&lon=-122.3321&datetime=2024-05-15T14:30:00
```

#### Parameters

| Param | Type | Required | Example | Notes |
|-------|------|----------|---------|-------|
| `lat` | float | Yes | 47.6062 | Latitude (WGS84) |
| `lon` | float | Yes | -122.3321 | Longitude (WGS84) |
| `datetime` | ISO8601 | No | 2024-05-15T14:30:00 | Defaults to now |
| `city` | string | No | seattle | Filter by city |
| `threshold_m` | int | No | 50 | Search radius (meters) |

#### Response (Success: 200)

```json
{
  "success": true,
  "data": {
    "segment": {
      "id": "seattle-001-right",
      "street_name": "Pike Street",
      "from_intersection": "1st Avenue",
      "to_intersection": "2nd Avenue",
      "side": "right",
      "city": "seattle"
    },
    "can_park": true,
    "until": "18:00",
    "reason": "Metered parking allowed 2 hours max",
    "rules": [
      {
        "rule_type": "metered",
        "start_time": "08:00",
        "end_time": "18:00",
        "max_stay_minutes": 120,
        "rate_per_hour": 2.50,
        "days": ["Mon", "Tue", "Wed", "Thu", "Fri"],
        "priority": 70
      }
    ],
    "confidence": 0.95,
    "distance_meters": 12.5,
    "query_datetime": "2024-05-15T14:30:00"
  },
  "timestamp": "2024-05-15T14:30:00Z"
}
```

#### Response (No Data: 404)

```json
{
  "success": false,
  "error": "No parking data found within 50 meters",
  "data": {
    "can_park": null,
    "reason": "No segment found",
    "suggestions": [
      "Try a different location",
      "Help us by reporting parking rules"
    ]
  }
}
```

#### Response (Error: 400)

```json
{
  "success": false,
  "error": "Invalid coordinates",
  "details": "Latitude must be between -90 and 90"
}
```

---

### 2. GET /api/v1/segment/{segment_id}

**Get all rules for a specific blockface**

#### Request

```
GET /api/v1/segment/seattle-001-right
```

#### Response (200)

```json
{
  "success": true,
  "data": {
    "segment": {
      "id": "seattle-001-right",
      "street_name": "Pike Street",
      "from_intersection": "1st Avenue",
      "to_intersection": "2nd Avenue",
      "side": "right",
      "city": "seattle",
      "geometry": {
        "type": "LineString",
        "coordinates": [[-122.3, 47.6], [-122.301, 47.601]]
      },
      "confidence": 0.95,
      "source": "seattle_arcgis"
    },
    "rules": [
      {
        "id": "seattle-rule-001",
        "rule_type": "metered",
        "start_time": "08:00",
        "end_time": "18:00",
        "days": ["Mon", "Tue", "Wed", "Thu", "Fri"],
        "max_stay_minutes": 120,
        "rate_per_hour": 2.50,
        "confidence": 0.95
      },
      {
        "id": "seattle-rule-002",
        "rule_type": "street_cleaning",
        "start_time": "09:00",
        "end_time": "11:00",
        "days": ["Wed"],
        "confidence": 0.95
      }
    ],
    "street_cleaning": [
      {
        "day": "Wednesday",
        "time": "09:00",
        "duration_minutes": 120
      }
    ]
  }
}
```

---

### 3. GET /api/v1/segments

**Search for segments by street name or city**

#### Request

```
GET /api/v1/segments?city=seattle&street_name=Pike&limit=10
```

#### Parameters

| Param | Type | Example |
|-------|------|---------|
| `city` | string | seattle |
| `street_name` | string | Pike |
| `limit` | int | 10 |
| `offset` | int | 0 |

#### Response (200)

```json
{
  "success": true,
  "data": {
    "total": 24,
    "limit": 10,
    "offset": 0,
    "segments": [
      {
        "id": "seattle-001-right",
        "street_name": "Pike Street",
        "from_intersection": "1st Avenue",
        "to_intersection": "2nd Avenue",
        "side": "right",
        "rule_count": 2
      },
      {
        "id": "seattle-001-left",
        "street_name": "Pike Street",
        "from_intersection": "1st Avenue",
        "to_intersection": "2nd Avenue",
        "side": "left",
        "rule_count": 2
      }
    ]
  }
}
```

---

### 4. GET /api/v1/coverage

**Get coverage statistics**

#### Request

```
GET /api/v1/coverage
```

#### Response (200)

```json
{
  "success": true,
  "data": {
    "overall": {
      "total_segments": 27575,
      "segments_with_rules": 20812,
      "coverage_percentage": 75.5,
      "total_rules": 102341
    },
    "by_city": [
      {
        "city": "seattle",
        "total_segments": 5500,
        "segments_with_rules": 5284,
        "coverage_percentage": 96.1,
        "rule_count": 7821
      },
      {
        "city": "sf",
        "total_segments": 4050,
        "segments_with_rules": 3241,
        "coverage_percentage": 80.0,
        "rule_count": 6102
      },
      {
        "city": "nyc",
        "total_segments": 13500,
        "segments_with_rules": 8102,
        "coverage_percentage": 60.0,
        "rule_count": 43201
      },
      {
        "city": "toronto",
        "total_segments": 4000,
        "segments_with_rules": 2841,
        "coverage_percentage": 71.0,
        "rule_count": 23450
      },
      {
        "city": "boston",
        "total_segments": 2800,
        "segments_with_rules": 2107,
        "coverage_percentage": 75.2,
        "rule_count": 21767
      }
    ],
    "last_updated": "2024-05-15T00:00:00Z"
  }
}
```

---

### 5. POST /api/v1/contributions

**Submit user contribution (report parking rule)**

#### Request

```json
POST /api/v1/contributions
Content-Type: application/json

{
  "segment_id": "seattle-001-right",
  "contribution_type": "new_rule",
  "rule_type": "metered",
  "description": "2-hour meter, $2.50/hr, Mon-Fri 8am-6pm",
  "photo_url": "https://...",
  "user_id": "user-123"  // optional, anonymous if omitted
}
```

#### Parameters

| Param | Type | Required | Notes |
|-------|------|----------|-------|
| `segment_id` | string | Yes | Target blockface |
| `contribution_type` | enum | Yes | new_rule, correction, removal |
| `rule_type` | string | Yes | metered, no_parking, permit, etc |
| `description` | string | Yes | Rule details (200 char max) |
| `photo_url` | string | No | Photo of sign |
| `user_id` | string | No | Anonymous if omitted |

#### Response (201)

```json
{
  "success": true,
  "data": {
    "contribution_id": "contrib-12345",
    "status": "pending",
    "segment_id": "seattle-001-right",
    "submitted_at": "2024-05-15T14:30:00Z",
    "message": "Thanks! Your contribution is pending review."
  }
}
```

---

### 6. GET /api/v1/health

**Health check (for monitoring)**

#### Request

```
GET /api/v1/health
```

#### Response (200)

```json
{
  "status": "ok",
  "database": "connected",
  "version": "1.0.0",
  "timestamp": "2024-05-15T14:30:00Z"
}
```

---

## Error Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 201 | Created (contribution accepted) |
| 400 | Bad request (invalid params) |
| 404 | Not found (no data) |
| 429 | Too many requests (rate limited) |
| 500 | Server error |

---

## Rate Limiting

**Free Tier:**
- 100 requests/hour per IP
- 1000 requests/day per API key

**Premium Tier:**
- Unlimited requests
- Contact for details

**Response Header:**
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 87
X-RateLimit-Reset: 1715788200
```

---

## Authentication

**Free endpoints:** No auth required

**Premium endpoints:** API key required

```
GET /api/v1/parking/rules?lat=47.6&lon=-122.3&api_key=YOUR_KEY
```

---

## Implementation (FastAPI)

### Basic Server

```python
# api/main.py

from fastapi import FastAPI, Query, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, text
from datetime import datetime
from typing import Optional
import json

app = FastAPI(
    title="ParkSmart API",
    version="1.0.0",
    description="Parking rules database for North American cities"
)

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database
engine = create_engine('postgresql://user:pass@localhost:5432/parksmart_phase1')

@app.get("/api/v1/parking/rules")
async def get_parking_rules(
    lat: float = Query(...),
    lon: float = Query(...),
    datetime_str: Optional[str] = Query(None),
    city: Optional[str] = Query(None),
    threshold_m: int = Query(50)
):
    """Query parking rules for coordinates + datetime"""
    
    try:
        # Validate inputs
        if not (-90 <= lat <= 90 and -180 <= lon <= 180):
            raise HTTPException(status_code=400, detail="Invalid coordinates")
        
        # Default to now
        dt = datetime.fromisoformat(datetime_str) if datetime_str else datetime.now()
        day_of_week = dt.isoweekday()  # 1=Mon, 7=Sun
        hour = dt.hour
        minute = dt.minute
        
        with engine.connect() as conn:
            # Find nearest segment
            result = conn.execute(text("""
                SELECT * FROM find_nearest_segment(:lat, :lon, :city, :threshold)
                LIMIT 1
            """), {
                "lat": lat,
                "lon": lon,
                "city": city,
                "threshold": threshold_m
            })
            segment_row = result.fetchone()
            
            if not segment_row:
                return JSONResponse({
                    "success": False,
                    "error": "No parking data found",
                    "data": {"can_park": None}
                }, status_code=404)
            
            segment_id = segment_row[0]
            
            # Get applicable rules
            result = conn.execute(text("""
                SELECT * FROM get_applicable_rules(:segment_id, :day, :hour, :minute)
                ORDER BY priority DESC
            """), {
                "segment_id": segment_id,
                "day": day_of_week,
                "hour": hour,
                "minute": minute
            })
            
            rules = []
            can_park = True
            until_time = None
            reason = "No restrictions"
            
            for rule in result:
                rules.append({
                    "rule_type": rule[1],
                    "start_time": str(rule[2]) if rule[2] else None,
                    "end_time": str(rule[3]) if rule[3] else None,
                    "max_stay_minutes": rule[4],
                    "priority": rule[5]
                })
                
                # Check if parking is allowed
                if rule[1] == "no_stopping":
                    can_park = False
                    reason = "No stopping"
                    until_time = str(rule[3]) if rule[3] else None
                    break
                elif rule[1] == "no_parking":
                    can_park = False
                    reason = "No parking"
                    until_time = str(rule[3]) if rule[3] else None
                    break
                elif rule[1] == "metered":
                    can_park = True
                    reason = f"Metered: ${rule[4]}/hr"
                    until_time = str(rule[3]) if rule[3] else None
            
            return {
                "success": True,
                "data": {
                    "segment": {
                        "id": segment_id,
                        "street_name": segment_row[1],
                        "city": segment_row[2]
                    },
                    "can_park": can_park,
                    "until": until_time,
                    "reason": reason,
                    "rules": rules,
                    "confidence": segment_row[3],
                    "distance_meters": segment_row[4],
                    "query_datetime": dt.isoformat()
                }
            }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/v1/health")
async def health():
    """Health check"""
    return {
        "status": "ok",
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat()
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

### Run Server

```bash
cd D:\mob\ParkSmart
python api/main.py

# Server runs at http://localhost:8000
# API docs at http://localhost:8000/docs
```

---

## Testing

### cURL Examples

```bash
# Query parking rules
curl "http://localhost:8000/api/v1/parking/rules?lat=47.6062&lon=-122.3321"

# Get segment details
curl "http://localhost:8000/api/v1/segment/seattle-001-right"

# Check coverage
curl "http://localhost:8000/api/v1/coverage"

# Health check
curl "http://localhost:8000/api/v1/health"
```

### Python Client

```python
import requests

api_url = "http://localhost:8000"

response = requests.get(f"{api_url}/api/v1/parking/rules", params={
    "lat": 47.6062,
    "lon": -122.3321,
    "datetime": "2024-05-15T14:30:00"
})

result = response.json()
print(f"Can park: {result['data']['can_park']}")
print(f"Reason: {result['data']['reason']}")
```

### Dart/Flutter Client

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class ParkingApiClient {
  final String baseUrl;
  
  ParkingApiClient(this.baseUrl);
  
  Future<Map> getParkingRules(double lat, double lon) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/parking/rules')
          .replace(queryParameters: {
            'lat': lat.toString(),
            'lon': lon.toString(),
          }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load parking rules');
  }
}

// Usage
final client = ParkingApiClient('http://api.parksmart.app');
final rules = await client.getParkingRules(47.6062, -122.3321);
print(rules['data']['can_park']);
```

---

## Deployment

### Option 1: Heroku (Free Tier)

```bash
# Create Procfile
echo "web: uvicorn api.main:app --host 0.0.0.0 --port \$PORT" > Procfile

# Create requirements.txt
pip freeze > requirements.txt

# Initialize git
git init
git add .
git commit -m "Initial API"

# Deploy to Heroku
heroku create parksmart-api
heroku addons:create heroku-postgresql:hobby-dev
git push heroku main

# Access API
https://parksmart-api.herokuapp.com/api/v1/health
```

### Option 2: Railway.app

```bash
# Connect GitHub repo
# Railway auto-deploys from git

# Set environment variables
# DATABASE_URL=postgresql://...
```

### Option 3: Self-Hosted

```bash
# Install on VPS
apt-get update
apt-get install python3 postgresql

# Clone repo
git clone https://github.com/yourname/parksmart.git
cd parksmart

# Install dependencies
pip install -r requirements.txt

# Run with systemd
sudo nano /etc/systemd/system/parksmart-api.service
sudo systemctl enable parksmart-api
sudo systemctl start parksmart-api
```

---

## Monitoring

### Logs

```
uvicorn api.main:app --log-level debug
```

### Metrics

```
# Request count per endpoint
# Response times
# Error rates
# Database query times
```

### Alerts

```
- If API down > 5 min
- If error rate > 1%
- If response time > 1s
```

---

**Status:** Ready to implement (Week 8)  
**Deployment:** 1-2 hours  
**Testing:** 2-3 hours
