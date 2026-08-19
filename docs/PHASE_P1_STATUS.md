# Phase P1 Integration Status Report

This document records the exact implementation details, API endpoints, hardware permissions, real-time pipeline flows, and verification statuses for **Phase P1** of Guardian AI.

---

## Phase P1 Feature Status Matrix

| Feature | Subsystem | Implementation Architecture | API Endpoints | External Provider / Native Capability | Permission Required | Classification | Physical & Test Verification |
|---|---|---|---|---|---|---|---|
| **P1.1 — Guardian Real-Time Engine** | Frontend Engine & Backend Watchdog | `GuardianEngine` orchestrates 30s background heartbeats, battery telemetry, real GPS streaming, and sensor/voice monitoring lifecycles. | `POST /guardian/start`<br>`POST /guardian/stop`<br>`POST /guardian/{id}/heartbeat` | Native `Battery` API, `Geolocator`, Android Lifecycle Observer | Foreground Location, Battery Optimization | **REAL** | Unit tests pass, battery percent & GPS telemetry serialize properly |
| **P1.2 — Real Maps & Routing** | Mapping Subsystem | `MapsService` calls Google Directions API to compute real walking routes, polyline vectors, distance, and ETAs. Honest error returned if API key is missing. | `GET /map/route`<br>`GET /map/area-safety` | Google Directions API, Google Maps Android SDK | Internet, Location | **REAL** | Google Polyline Decoder verified, GST Road static mock removed |
| **P1.3 — Real Weather Service** | Dashboard & Environmental Risk | `WeatherService` calls OpenWeatherMap API with 600s Redis cache TTL. Replaces hardcoded 31°C Humid mock with truthful live readings. | `GET /weather`<br>`GET /services/nearby` | OpenWeatherMap API, Redis Cache | Internet, Location | **REAL** | Coordinates passed, Redis cache layer connected |
| **P1.4 — Real Device Motion** | Sensor Processing Subsystem | `SensorService` connects to real accelerometer & gyroscope hardware streams via `sensors_plus`, performing local window evaluation for drop & shake anomalies. | `POST /signals/motion` | Hardware 3-axis Accelerometer & Gyroscope | High-sampling sensors | **REAL** | Edge drop/shake detection verified with local peak thresholds |
| **P1.5 — Real Push Notifications (FCM)** | Notification System | `FcmNotificationService` initializes Firebase Messaging, requests permission, obtains real device push tokens, and registers with backend. | `POST /notifications/device-token`<br>`GET /notifications` | Firebase Cloud Messaging, Android Notification Channels | Post Notifications (Android 13+) | **REAL** | Token sync & foreground notification channel configured |

---

## Detailed Component Implementations

### 1. P1.1: Guardian Real-Time Engine
- **Files Created/Modified**:
  - [`lib/core/services/guardian_engine.dart`](file:///c:/dev/guardian-ai/lib/core/services/guardian_engine.dart)
  - [`lib/providers/repository_providers.dart`](file:///c:/dev/guardian-ai/lib/providers/repository_providers.dart)
  - [`lib/features/guardian/presentation/guardian_controller.dart`](file:///c:/dev/guardian-ai/lib/features/guardian/presentation/guardian_controller.dart)
  - [`lib/features/home/presentation/home_controller.dart`](file:///c:/dev/guardian-ai/lib/features/home/presentation/home_controller.dart)
- **Lifecycle Logic**:
  - `startGuardian()` triggers backend session creation, queries device battery level via `battery_plus`, starts `LocationService.getPositionStream()`, and schedules a 30-second periodic heartbeat dispatch.
  - Attaches `WidgetsBindingObserver` to detect app backgrounding and foregrounding.
  - `stopGuardian()` cancels heartbeat timers, stops location streams, stops kinematics processing, and deactivates the session cleanly on FastAPI.

### 2. P1.2: Real Maps & Routing
- **Files Created/Modified**:
  - [`backend/app/services/maps_service.py`](file:///c:/dev/guardian-ai/backend/app/services/maps_service.py)
  - [`backend/app/api/v1/routes.py`](file:///c:/dev/guardian-ai/backend/app/api/v1/routes.py)
  - [`lib/features/map/presentation/map_controller.dart`](file:///c:/dev/guardian-ai/lib/features/map/presentation/map_controller.dart)
  - [`lib/data/repositories/repository_impl.dart`](file:///c:/dev/guardian-ai/lib/data/repositories/repository_impl.dart)
  - [`lib/domain/repositories/repositories.dart`](file:///c:/dev/guardian-ai/lib/domain/repositories/repositories.dart)
- **Routing Logic**:
  - Decodes Google encoded polylines into GPS coordinate series.
  - Queries Google Directions walking routes with live origin coordinates and destination.
  - Eliminated hardcoded GST Road fallback.

### 3. P1.3: Real Weather
- **Files Created/Modified**:
  - [`backend/app/services/weather_service.py`](file:///c:/dev/guardian-ai/backend/app/services/weather_service.py)
  - [`backend/app/api/v1/weather.py`](file:///c:/dev/guardian-ai/backend/app/api/v1/weather.py)
  - [`lib/data/repositories/repository_impl.dart`](file:///c:/dev/guardian-ai/lib/data/repositories/repository_impl.dart)
  - [`lib/domain/repositories/repositories.dart`](file:///c:/dev/guardian-ai/lib/domain/repositories/repositories.dart)
- **Weather Logic**:
  - Queries OpenWeatherMap with live GPS coordinates (`lat`, `lng`).
  - Caches results in Redis with `WEATHER_CACHE_TTL_SECONDS=600`.
  - Removed static 31°C Humid mock.

### 4. P1.4: Real Device Motion
- **Files Created/Modified**:
  - [`lib/core/services/sensor_service.dart`](file:///c:/dev/guardian-ai/lib/core/services/sensor_service.dart)
  - [`lib/providers/repository_providers.dart`](file:///c:/dev/guardian-ai/lib/providers/repository_providers.dart)
- **Sensor Logic**:
  - Ingests 3-axis accelerometer and gyroscope samples in a local rolling window of 50 samples.
  - Runs edge classification every 2 seconds without streaming raw sensor data over network.
  - Detects `PHONE_DROP` (acceleration peak > 25 m/s²) and `SHAKE_DETECTED` (acceleration peak > 18 m/s² and rotation peak > 6 rad/s).

### 5. P1.5: Real FCM Push Notifications
- **Files Created/Modified**:
  - [`lib/core/services/fcm_notification_service.dart`](file:///c:/dev/guardian-ai/lib/core/services/fcm_notification_service.dart)
  - [`backend/app/api/v1/notifications.py`](file:///c:/dev/guardian-ai/backend/app/api/v1/notifications.py)
  - [`lib/main.dart`](file:///c:/dev/guardian-ai/lib/main.dart)
  - [`lib/providers/repository_providers.dart`](file:///c:/dev/guardian-ai/lib/providers/repository_providers.dart)
- **Notification Logic**:
  - Requests notification authorization on Android / iOS.
  - Obtains real FCM token and posts to `POST /notifications/device-token`.
  - Configures `guardian_alerts` high-importance Android channel for heads-up alerts.
  - Listens to token refresh and foreground messages.
