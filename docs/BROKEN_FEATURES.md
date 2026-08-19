# Guardian AI — Broken Features & Hardcoded Fallbacks Audit

## 1. Audit Overview

This document itemizes the issues, hardcoded values, and disconnected UI components identified during the deep-dive audit, along with their permanent fixes.

---

## 2. Itemized Resolution Log

### Issue 1: Backend Maps Route 500 Crash (`rethrow` NameError)
- **Root Cause**: `backend/app/services/maps_service.py` contained invalid Dart syntax `rethrow` within Python exception handling.
- **Fix Applied**: Replaced with standard Python exception handling, added coordinate bounds checks and destination validation, and propagated truthful Google Cloud error messages (`REQUEST_DENIED`, `ZERO_RESULTS`) as HTTP 400/503 instead of 500.
- **Status**: **RESOLVED & VERIFIED**.

### Issue 2: Hardcoded Weather on Dashboard (`31°C, Chennai, TN, Humid`)
- **Root Cause**: `backend/app/api/v1/dashboard.py` lines 125–130 returned static JSON without invoking `WeatherService`.
- **Fix Applied**: Connected `_get_weather(lat, lng)` in `dashboard.py` to `WeatherService.get_weather(lat=lat, lng=lng)` with Redis caching (`weather:{lat}:{lng}`). Updated Flutter `dashboardProvider` to pass device GPS coordinates.
- **Status**: **RESOLVED & VERIFIED**.

### Issue 3: Hardcoded Nearby Emergency Services (`Thousand Lights Metro`, `Apollo Greams Road`, `T3 Egmore`)
- **Root Cause**: `backend/app/api/v1/dashboard.py` lines 143–147 and `backend/app/api/v1/weather.py` returned static mock items instead of spatial database records.
- **Fix Applied**: Updated `_get_nearby_services(db, lat, lng)` and `GET /api/v1/services/nearby` to query `NearbyHelpService(db).get_all_nearby_help(lat, lng)` to compute real Haversine distances to nearest police stations, hospitals, and transit hubs.
- **Status**: **RESOLVED & VERIFIED**.

### Issue 4: Start Safe Walk Injected Duplicate Stale Journeys
- **Root Cause**: Home screen "Start Safe Walk" directly inserted `Trip from Current Location to Home` into PostgreSQL without user destination input or route selection, leading to duplicate orphaned active journeys.
- **Fix Applied**:
  - Re-routed Home "Start Safe Walk" to `RoutePaths.guardian` / `MapScreen` for real destination selection and route evaluation.
  - Updated `JourneyService.start_journey` to automatically complete any previous dangling active journeys before creating a new one.
- **Status**: **RESOLVED & VERIFIED**.

### Issue 5: Missing Route Deviation Engine
- **Root Cause**: `LiveJourneyScreen` did not calculate distance between the user's live GPS coordinates and planned route polylines.
- **Fix Applied**: Created `RouteDeviationDetector` with Haversine segment projection and wired it to `LiveJourneyScreen` to detect when the user moves >150m off-route.
- **Status**: **RESOLVED & VERIFIED**.

### Issue 6: Disconnected Sensor & Voice Safety Prompts
- **Root Cause**: `SensorService` (shake/drop) and `VoiceService` (speech distress) detected signals in background streams but did not present an interactive safety confirmation prompt to the user before escalating.
- **Fix Applied**: Created `showSafetyConfirmationDialog` with 20-second circular countdown timer and wired `SensorService.anomalyStream` and `VoiceService.emergencyTriggerStream` to present this dialog.
- **Status**: **RESOLVED & VERIFIED**.
