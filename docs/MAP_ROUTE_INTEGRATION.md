# Guardian AI — Map & Route Integration Architecture

## 1. Overview

Guardian AI implements a multi-tiered routing and safety engine that combines live Google Cloud Directions API polylines with localized risk zone databases.

---

## 2. Google Maps / Directions API Flow

```
 Flutter Client (Origin Lat/Lng + Destination)
         │
         ▼
 FastAPI Backend (/api/v1/map/route or /api/v1/guardian/route)
         │
         ▼
 MapsService (Python backend/app/services/maps_service.py)
         │
         ├── Checks MAPS_API_KEY environment configuration
         │
         ▼
 Google Cloud Directions API Request:
 https://maps.googleapis.com/maps/api/directions/json?origin={lat},{lng}&destination={dest}&alternatives=true&mode=walking&key={MAPS_API_KEY}
         │
         ├── Propagates truthful status:
         │   ├── OK (200) → Parses overview_polyline, steps, distance_meters, duration_seconds
         │   ├── ZERO_RESULTS (400) → Truthful error: "No walking route found between these locations"
         │   ├── REQUEST_DENIED / OVER_QUERY_LIMIT (503) → Truthful Google Cloud API status propagation
         │
         ▼
 GuardianSafetyEngine (Safety Risk Evaluator)
```

---

## 3. Safety Scoring Algorithm

When routes are evaluated in `backend/app/services/guardian_safety_engine.py`:

1. **Polyline Sampling**: The encoded overview polyline is decoded into LatLng points and sampled every 150 meters along the traversal path.
2. **Spatial Risk Zone Intersect**:
   - Compares each sampled point against the 56 Chennai `safety_zones` database.
   - Computes Haversine distance $d$ to zone center.
   - If $d \le \text{radius\_meters}$, accumulates base zone risk weight.
3. **Day / Night Time Factor**:
   - Evaluates current time in Indian Standard Time (IST, UTC+5:30).
   - If between 19:00 and 06:00, applies night risk multipliers to poorly lit zones.
4. **Emergency Proximity Bonus**:
   - Calculates distance to nearest operating police station and hospital.
   - Applies safety bonus if route stays within 500m of police patrol corridors.
5. **Alternative Roles**:
   - **Safer Route**: Maximizes safety score (diverts around high-risk zones).
   - **Fastest Route**: Minimizes duration in minutes.
   - **Balanced Route**: Optimal trade-off between time and safety.
