# Guardian AI — Real Feature Integration Test Results

## 1. Test Suite Summary

- **Backend Pytest Suite**: **40 / 40 tests PASSING (100%)**
- **Flutter Unit & Widget Tests**: **10 / 10 tests PASSING (100%)**
- **Dart Analyzer**: **0 Errors**

---

## 2. Automated Test Breakdown

### Backend Pytest Results (`pytest -v`)
| Test File | Test Cases | Status | Details |
| :--- | :--- | :--- | :--- |
| `tests/test_api.py` | 8 passed | **PASS** | Authentication, JWT validation, Profile CRUD, Contacts CRUD |
| `tests/test_fcm.py` | 2 passed | **PASS** | Firebase Admin initialization, FCM HTTP v1 dispatch payload |
| `tests/test_gemini_ai.py` | 5 passed | **PASS** | Gemini voice distress analysis, rule-based fallback, JSON output format |
| `tests/test_google_auth.py` | 3 passed | **PASS** | Google OAuth token verification and user provisioning |
| `tests/test_guardian_route.py` | 5 passed | **PASS** | Route polyline sampling, day/night risk evaluation, alternative scoring |
| `tests/test_intelligence.py` | 7 passed | **PASS** | Kinematics motion signal ingestion, speech sample analysis, edge proxy |
| `tests/test_journey_monitoring.py` | 3 passed | **PASS** | Journey start/stop lifecycle, heartbeat telemetry, safe completion |
| `tests/test_maps_service.py` | 7 passed | **PASS** | Maps API parameter validation, missing keys, Google API error handling, route parsing |

### Flutter Test Results (`flutter test`)
| Test Target | Test Cases | Status | Details |
| :--- | :--- | :--- | :--- |
| `test/api_integration_test.dart` | 9 passed | **PASS** | Base URL resolution, Token storage, Sensor kinematics classification, Offline queueing, DTO serialization (SosRequest, StartJourneyRequest, HeartbeatRequest, TrustedContactEntity) |
| `test/widget_test.dart` | 1 passed | **PASS** | Application bootstrap, Riverpod provider tree, Login screen rendering |

---

## 3. Real Integration Verification Results

| Subsystem | Real Data Verification | Hardware / API Dependency |
| :--- | :--- | :--- |
| **GPS Tracking** | High accuracy stream with 3m distance filter | Android GPS (`geolocator: ^13.0.2`) |
| **Route Deviation** | Perpendicular polyline distance calculation | `RouteDeviationDetector` (Haversine segment projection) |
| **Sensors & Kinematics** | Drop (>25 m/s²) and Shake (>18 m/s²) detection | Android Accelerometer & Gyroscope (`sensors_plus: ^6.1.1`) |
| **Voice Distress** | Keyword detection ("help", "danger", "bachao") + STT | Android Microphone & Speech Engine (`speech_to_text: ^7.0.0`) |
| **SOS Multi-Channel** | Twilio SMS + Firebase Admin FCM v1 push notification | `backend/secrets/guardian-ai-firebase-adminsdk.json` & Twilio credentials |
| **Database Persistence** | PostgreSQL user profiles, trusted contacts, journeys, safety zones | SQLAlchemy Async Engine + PostgreSQL Docker |
| **Weather & POIs** | Real coordinates forwarded to WeatherService & NearbyHelpService | OpenWeatherMap + Redis cache + Spatial SQLite/PostgreSQL |
