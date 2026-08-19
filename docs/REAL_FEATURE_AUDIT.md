# Guardian AI — Real Feature & Data Source Audit

## 1. Executive Summary

This audit catalogs the real data sources, backend endpoints, and hardware integrations across Guardian AI. Every subsystem was inspected at code level and verified end-to-end to eliminate mock fallbacks and hardcoded placeholders.

---

## 2. Subsystem Audit Matrix

| Feature / UI Element | Visual Representation | Data Source / Integration | Audit Status | Verification Method |
| :--- | :--- | :--- | :--- | :--- |
| **Home Weather Widget** | Temperature, condition, humidity, visibility | `GET /api/v1/dashboard?lat=..&lng=..` → `WeatherService` (OpenWeatherMap API + Redis cache `weather:{lat}:{lng}`) | **REAL + VERIFIED** | Live endpoint tested; GPS coordinates forwarded dynamically from Flutter |
| **Nearby Emergency Services** | Police, Hospital, Transit tiles & distance | `GET /api/v1/dashboard?lat=..&lng=..` & `GET /api/v1/services/nearby` → `NearbyHelpService` (PostgreSQL/SQLite spatial Haversine queries against 56 police stations & POIs) | **REAL + VERIFIED** | Haversine distance calculations verified against real Chennai coordinate database |
| **Safety Score (Home & Journey)** | Numerical ring (0–100) & Safety badge | `_compute_safety_score` in `dashboard.py` (Calculated from user journey history, safe arrivals, and active Guardian zones) | **REAL + VERIFIED** | Tested dynamically with zero journeys (baseline 88) and completed safe journeys |
| **Start Safe Walk Flow** | Primary action button on Home | Navigates to `GuardianScreen` / `MapScreen` → Live GPS → Destination search → Route alternatives calculation → Start Journey API (`POST /api/v1/journeys/start`) → `LiveJourneyScreen` | **REAL + VERIFIED** | Full navigation flow wired; previous dangling active journeys safely archived in backend |
| **Route Alternatives & Evaluation** | Safer Route, Fastest Route, Balanced Route | `POST /api/v1/guardian/route` → `GuardianSafetyEngine` (150m polyline sampling, day/night risk evaluation, safety zone intersection) | **REAL + VERIFIED** | Pytest test suite `test_guardian_route.py` verified 5/5 |
| **Route Deviation Detection** | ⚠ ROUTE DEVIATION 20s countdown | `RouteDeviationDetector` in Flutter comparing live GPS against `List<LatLngPoint>` polyline (>150m for 3 consecutive GPS samples) | **REAL + VERIFIED** | Cross-track geometric algorithm implemented and tested |
| **Kinematics & Fall Detection** | ⚠ UNUSUAL MOVEMENT 20s countdown | `SensorService` consuming `sensors_plus` hardware streams (Drop >25 m/s², Shake >18 m/s² + 6 rad/s) → `POST /api/v1/intelligence/motion-signal` | **REAL + VERIFIED** | Tested in `test/api_integration_test.dart` and real sensor stream pipeline |
| **Voice Distress Protection** | 🚨 VOICE EMERGENCY TRIGGER | `VoiceService` with `speech_to_text` hardware listener + `POST /api/v1/intelligence/voice-analysis` (Gemini 2.5 Flash + acoustic proxy) | **REAL + VERIFIED** | Audio permission, STT loop, keyword filter ("help", "danger", "bachao"), and Gemini API fallback verified |
| **Live Journey Tracking** | Map, polylines, ETA, elapsed time, distance | `LiveJourneyScreen` (Continuous `LocationService` GPS stream, live distance & ETA calculation, 30s heartbeat to backend) | **REAL + VERIFIED** | Live screen with camera tracking, polyline rendering, and safe arrival stop API verified |
| **Emergency SOS Pipeline** | Immediate alert dispatch, countdown sheet | `EmergencyService` → `POST /api/v1/emergency/sos` → Twilio SMS (`twilio.rest.Client`) + Firebase Admin HTTP v1 push notifications (`firebase_admin.messaging.send`) | **REAL + VERIFIED** | Multi-channel broadcast verified with valid E.164 and FCM device token delivery |
| **Offline Sync Engine** | Offline banner & sync status | `OfflineSyncManager` (SQLite queue, exponential backoff, SHA-256 idempotency key headers) | **REAL + VERIFIED** | Verified in Flutter unit tests |
| **Fake Call & Fake Text** | Safety diversion utilities | `FakeCallScreen` and `FakeMessageScreen` (Timer-based incoming call simulation, voice audio synthesis, pre-configured safety scripts) | **REAL + VERIFIED** | Verified intentional safety diversion feature |
