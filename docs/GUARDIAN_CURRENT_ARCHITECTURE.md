# GUARDIAN AI — CURRENT ARCHITECTURE & FORENSIC AUDIT

**Date:** 2026-08-18  
**Project:** Guardian AI Personal Safety Platform  
**Scope:** Full-stack inspection of Flutter client, FastAPI backend, sensor pipelines, auth, routing, and cloud integrations.

---

## 1. System Overview

Guardian AI is a multi-tier personal safety application designed to provide proactive protection, real-time risk assessment, route watchdogging, and emergency escalation.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        FLUTTER CLIENT (Android)                       │
├────────────────────────────────────────────────────────────────────────┤
│  UI / Screens: Home, Guardian Map, Live Journey, Auth, Diagnostics     │
│  Controllers: Riverpod StateNotifiers & AsyncNotifiers                 │
│  Hardware Sensors: Geolocator (GPS), SensorsPlus (Accel/Gyro), STT     │
│  Local Services: GuardianEngine, SensorService, VoiceService           │
│  Network Layer: ApiClient (JWT Injection, 401 Auto-Refresh)            │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ HTTP / REST & FCM
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        FASTAPI BACKEND                                 │
├────────────────────────────────────────────────────────────────────────┤
│  API Routers: /auth, /dashboard, /guardian, /emergency, /journeys, etc.│
│  Engines: GuardianSafetyEngine, RiskFusionService, NearbyHelpService   │
│  External Providers: Google Routes/Directions API, Twilio SMS, FCM     │
│  AI Integrations: Gemini AI Route Explainer, Voice Distress Analyzer   │
│  Database: SQLAlchemy (Async SQLite / PostgreSQL)                      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Forensic Feature Matrix

| Feature | Flutter Implementation | Backend API | Database Model | Permissions Required | Background Capability | Current Status | Actual Runtime Test | Problems Identified | Required Fix |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **API Connectivity & Base URL** | `lib/core/config/api_config.dart` | Root FastAPI app | N/A | `INTERNET` | N/A | **Fragile** | Fails on physical phone if `API_HOST` not passed and defaults to `127.0.0.1` | Physical devices fail without adb reverse or explicit `--dart-define=API_HOST` | Enhance diagnostics to explicitly display resolved URL and connectivity breakdown |
| **Dashboard** | `lib/features/home/presentation/home_screen.dart` | `GET /api/v1/dashboard` | Users, Journeys, SafetyZones | `ACCESS_FINE_LOCATION` | Polling only | **Partial** | Displays "Dashboard Error" on generic exceptions | Errors swallowed as generic "Unexpected error" without differentiating network, auth, or server | Categorize errors (Network, Auth, Server, Timeout) and provide retry with actionable feedback |
| **JWT Authentication** | `lib/core/network/api_client.dart` | `POST /api/v1/auth/login`, `/refresh` | `User` | N/A | N/A | **Working** | Logs in, injects token, auto-refreshes on 401 | Shows "Session expired" when network is unreachable | Differentiate network failure from 401 token expiry |
| **Google OAuth** | `lib/features/auth/presentation/auth_controller.dart` | `POST /api/v1/auth/google` | `User` | `INTERNET` | N/A | **Broken** | `ApiException 10` on physical device | `google-services.json` has `"oauth_client": []`; debug SHA-1 not linked to Google Cloud OAuth client | Register debug SHA-1 in Firebase/GCP, regenerate `google-services.json`, verify serverClientId audience |
| **Hardware Accelerometer & Gyro** | `lib/core/services/sensor_service.dart` | `POST /api/v1/intelligence/motion` | `MotionAnomalyEvent` | `HIGH_SAMPLING_RATE_SENSORS` | Foreground stream | **Too Sensitive** | Magnitude > 15 m/s² immediately dispatches `shakeDetected` | Normal phone pickup or placing on table triggers movement alerts; no multi-stage validation | Implement multi-stage fall/anomaly detector (impact + rotation + stillness check + confidence) |
| **Voice Distress Monitoring** | `lib/core/services/voice_service.dart` | `POST /api/v1/intelligence/voice/analyze` | `VoiceDistressEvent` | `RECORD_AUDIO` | Stream when listening | **Unreliable** | STT stops unexpectedly or triggers on casual "help" | Single keyword triggers emergency; no continuous real-mic test in diagnostics | Multi-stage phrase confidence + Gemini context analysis + real microphone test workbench |
| **Safety Confirmation Modal** | `lib/core/widgets/safety_confirmation_dialog.dart` | `POST /api/v1/emergency/sos` | `EmergencyEvent` | N/A | N/A | **Over-aggressive** | 20s timer countdown automatically triggers SOS | Single sensor anomaly triggers countdown to full SOS | Only trigger safety dialog on verified multi-stage events; cancel without penalty |
| **Emergency SOS Dispatch** | `lib/core/widgets/sos_dialog.dart` | `POST /api/v1/emergency/sos` | `EmergencyEvent`, `EmergencyNotification` | `ACCESS_FINE_LOCATION` | Background HTTP | **Partially Truthful** | Creates DB record, attempts SMS/Push | Shows "SOS recorded in system (1 contact not notified)" if provider keys missing | Provide granular contact-by-contact delivery lifecycle (Queued, Sent, Delivered, Failed) |
| **Safe Route Planning** | `lib/features/guardian/presentation/guardian_map_controller.dart` | `POST /api/v1/guardian/route` | `SafetyZone`, `PoliceStation` | `ACCESS_FINE_LOCATION` | N/A | **Working** | Evaluates routes against safety zones with day/night scoring | Search sometimes falls back to curated coordinates if geocoding fails | Ensure searched destination (e.g., Tambaram) is strictly preserved throughout pipeline |
| **Route Deviation Watchdog** | `lib/core/services/route_deviation_detector.dart` | `POST /api/v1/intelligence/deviation` | `RouteDeviationEvent` | `ACCESS_FINE_LOCATION` | Background location stream | **Working** | Checks distance to polyline (>150m for 3 ticks) | Tightly coupled directly to emergency dialog rather than central risk engine | Route deviation feeds into central `GuardianRiskEngine` as a contextual factor |
| **Risk Scoring & Fusion** | `lib/core/services/guardian_engine.dart` | `POST /api/v1/intelligence/risk-fusion` | `RiskAssessment` | N/A | Heartbeat (30s) | **Fragmented** | Frontend calculates score independently of backend risk fusion | Scattered weights; individual sensors directly initiate emergency prompts | Centralize client & server Risk Engine with explainable factor breakdown |
| **Background Guardian Monitoring** | `lib/core/services/guardian_engine.dart` | `POST /api/v1/guardian/{id}/heartbeat` | `GuardianSession` | `FOREGROUND_SERVICE`, `ACCESS_FINE_LOCATION` | Heartbeat & location stream | **Partial** | Heartbeat fires, but OS kills background streams if app minimized | Missing Android persistent foreground notification with live status chips | Implement persistent foreground service state and notification channel |
| **System Diagnostics** | `lib/features/diagnostics/presentation/diagnostics_screen.dart` | `/health`, `/intelligence/*` | N/A | `RECORD_AUDIO`, `ACCESS_FINE_LOCATION` | N/A | **Mixed** | Tests simulate events instead of testing real sensor hardware | Hardware tests and simulation tests were intermingled | Strictly separate Real Hardware Test from Simulation Pipeline Test |

---

## 3. Detailed Forensic Analysis of Core Problems

### Problem 1: Dashboard Error Swallowing
- **Location:** `lib/features/home/presentation/home_controller.dart`, `home_screen.dart`
- **Root Cause:** When `fetchDashboard` throws an unhandled error or network failure, it displays a generic message without clear categorization (Network vs Auth vs Server 500).
- **Fix:** Structured exception handling with categorized UI states and actionable retry mechanisms.

### Problem 2: Google OAuth ApiException 10
- **Location:** `android/app/google-services.json`, Google Cloud Console
- **Root Cause:** In `android/app/google-services.json`, `"oauth_client": []` is completely empty. The debug keystore SHA-1 (`E7:87:1A:B1:7B:C7:9C:16:14:AA:07:F7:30:41:94:0F:27:83:36:DF`) is not registered as an Android OAuth Client ID in the Google Cloud / Firebase Console project `guardian-ai-505705`.
- **Fix:** Document exact GCP configuration required; update client ID and handle token exchange reliably.

### Problem 3 & 4: Sensor Over-sensitivity & Single-Sensor SOS
- **Location:** `lib/core/services/sensor_service.dart:238`
- **Root Cause:** Any acceleration peak > 15.0 m/s² (only 1.5g) triggers `shakeDetected`, immediately sending an anomaly that pops up a 20-second emergency dialog. Normal phone handling triggers this easily.
- **Fix:** Multi-stage kinematic pipeline:
  1. Acceleration threshold (> 25 m/s²)
  2. Gyroscope rotational check (> 5 rad/s)
  3. Freefall / low-gravity drop signature
  4. Post-impact inactivity (sudden stop/immobility)
  5. Multi-signal verification before escalating risk.

### Problem 5: Voice Detection Real Microphone vs Simulation
- **Location:** `lib/core/services/voice_service.dart`, `lib/features/diagnostics/presentation/diagnostics_screen.dart`
- **Root Cause:** Keyword matching triggers on single word occurrence without acoustic intensity or context validation. Diagnostics did not cleanly distinguish simulated events from real mic audio.
- **Fix:** Require phrase repetition or high AI confidence; separate simulation and real mic test workbenches.

### Problem 6: SOS Delivery Truthfulness
- **Location:** `backend/app/services/emergency_service.py:256`, `lib/core/widgets/sos_dialog.dart`
- **Root Cause:** When Twilio or FCM are not configured or fail, the UI displayed ambiguous status.
- **Fix:** Truthful delivery state machine with distinct statuses: `QUEUED`, `PROVIDER_ACCEPTED`, `DELIVERED`, `FAILED_NO_PROVIDER`, `FAILED_NETWORK`.
