# Guardian AI — Mobile Runtime Feature & Integration Matrix

This document provides a truthful, comprehensive mapping of all frontend screens, Riverpod state controllers, backend FastAPI endpoints, device hardware integrations, and runtime execution statuses across the Guardian AI Personal Safety application.

---

## Complete Runtime Feature Matrix

| Feature | Screen | Flutter Service / Controller | Backend API Endpoint | Hardware Requirement | Runtime Verified | Status | Limitations / Platform Behavior |
| :--- | :--- | :--- | :--- | :--- | :---: | :---: | :--- |
| **Session Restoration** | `SplashScreen` | `TokenStorageService`, `ApiClient` | `GET /profile/me` | Keystore / EncryptedPrefs | ✅ | **REAL** | Verifies token validity upfront; purges expired JWTs on 401. |
| **Email Login** | `LoginScreen` | `AuthController`, `AuthRepository` | `POST /auth/login` | None (Internet) | ✅ | **REAL** | Issues JWT, securely stores tokens, surfaces descriptive 401/network errors. |
| **User Registration** | `SignUpScreen` | `AuthController`, `AuthRepository` | `POST /auth/register` | None (Internet) | ✅ | **REAL** | Validates password matching, terms agreement, and email duplicates (409). |
| **Google Sign-In** | `LoginScreen` | `GoogleSignIn`, `AuthController` | `POST /auth/google` | Google Play Services | ✅ | **REAL** | Verifies Google ID tokens via backend Google Auth API; requires SHA-1 registration in GCP. |
| **Home Command Center** | `HomeScreen` | `HomeController`, `DashboardRepository` | `GET /dashboard` | GPS Satellite / Fused | ✅ | **REAL** | Fetches live user score, nearby services, weather, active status; no fake fallback data. |
| **System Status Badges** | `GuardianSystemStatus` | `GuardianEngine`, `SensorService` | Local + `GET /health` | GPS, Accel, Gyro, Mic | ✅ | **REAL** | 11 truthful indicators (🟢 Active, 🟡 Starting, 🔴 Offline, ⚪ Standby, ⚠️ Permission, ❌ Error). |
| **Map Route Planning** | `MapScreen` | `GuardianMapController` | `POST /guardian/route`, `GET /map/route` | Google Maps SDK, GPS | ✅ | **REAL** | Google Directions / Routes API / OSRM with road-following polylines and camera bounds auto-fit. |
| **Destination Geocoding** | `DestinationSearchSheet` | `GuardianMapController` | OpenStreetMap / Nominatim | Internet | ✅ | **REAL** | Real coordinate search for any location (e.g., "Tambaram", "T. Nagar") with live search debounce. |
| **Route Alternatives** | `GuardianRouteComparisonCard` | `GuardianMapController` | `POST /guardian/route` | None | ✅ | **REAL** | Ranks `SAFER`, `FASTEST`, and `BALANCED` with safety scores, durations, and risk exposure data. |
| **Safety Zones Layer** | `MapScreen` | `GuardianMapController` | `GET /guardian/safety-zones` | None | ✅ | **REAL** | Interactive Chennai Safety Zones with risk scores, lighting, isolation, and activity factors. |
| **Police Stations Layer** | `MapScreen` | `GuardianMapController` | `GET /guardian/police-stations` | Phone Dialer Intent | ✅ | **REAL** | Official police stations with distance calculations and direct emergency dial actions. |
| **Hospitals Layer** | `MapScreen` | `GuardianMapController` | `GET /guardian/nearby-help` | External Navigation | ✅ | **REAL** | Hospital locations with emergency dial and navigation launcher intents. |
| **Transit / Metro Layer** | `MapScreen` | `GuardianMapController` | `GET /guardian/nearby-help` | None | ✅ | **REAL** | Metro and suburban railway stations rendered as toggleable safety landmarks. |
| **Traffic Layer** | `MapScreen` | `GoogleMapController` | Google Maps SDK | None | ✅ | **REAL** | Supported natively by Google Maps SDK when layer enabled. |
| **Journey Confirmation** | `JourneyConfirmationScreen` | `JourneyRepository` | None (Pre-flight) | GPS, Sensors | ✅ | **REAL** | Shows route summary, safety score, and pre-departure system checklist before starting. |
| **Live Journey Tracking** | `LiveJourneyScreen` | `GuardianEngine`, `LocationService` | `POST /journeys/start`, `POST /journeys/{id}/telemetry` | GPS High Accuracy | ✅ | **REAL** | Live tracking of current coordinate, speed, elapsed time, remaining distance, and ETA. |
| **Route Deviation Watchdog** | `LiveJourneyScreen` | `RouteDeviationDetector` | Edge Calculation | GPS Satellite | ✅ | **REAL** | Triggers 20-second warning dialog when user strays >150m from planned corridor. |
| **Stationary Watchdog** | `LiveJourneyScreen` | `GuardianEngine`, `JourneyRepository` | `POST /journeys/{id}/check-stationary` | GPS Speed Sensor | ✅ | **REAL** | Detects stationary stops >3 minutes and prompts user with safety check confirmation. |
| **Accelerometer Monitor** | `SensorService` | `SensorService` | `POST /intelligence/motion-signal` | `sensors_plus` Hardware | ✅ | **REAL** | Real 3-axis accelerometer stream ($X, Y, Z$ in $m/s^2$) with live magnitude telemetry. |
| **Gyroscope Monitor** | `SensorService` | `SensorService` | `POST /intelligence/motion-signal` | `sensors_plus` Hardware | ✅ | **REAL** | Real 3-axis gyroscope stream ($X, Y, Z$ in $rad/s$) with rotation peak monitoring. |
| **Shake Detection** | `SensorService` | `SensorService` | `POST /intelligence/motion-signal` | Accelerometer Peak | ✅ | **REAL** | Multi-axis rolling window (>15.0 $m/s^2$) with 2-second debounce and 20s warning dialog. |
| **Fall Detection** | `SensorService` | `SensorService` | `POST /intelligence/motion-signal` | Accelerometer Sequence | ✅ | **REAL** | Sequential impact candidate evaluation (>24.0 $m/s^2$ followed by low-motion rest period). |
| **Voice Distress Detection** | `VoiceService` | `VoiceService` | `POST /intelligence/voice-analysis` | Microphone / STT | ✅ | **REAL** | Continuous speech recognition for trigger words ("help", "danger", "emergency") + Gemini AI. |
| **Guardian Mode** | `GuardianScreen` | `GuardianEngine` | `POST /guardian/start`, `POST /guardian/stop` | GPS + Kinematics | ✅ | **REAL** | Standalone protection mode independent of active planned routes. |
| **Periodic Heartbeat** | `GuardianEngine` | `GuardianRepository` | `POST /guardian/{id}/heartbeat` | Battery + GPS | ✅ | **REAL** | Dispatches battery percent, GPS position, and speed every 30 seconds to server. |
| **Emergency SOS** | `SosDialog`, `SosFab` | `GuardianRepository` | `POST /emergency/sos` | GPS + Network | ✅ | **REAL** | 3-second abort countdown, GPS lock acquisition, and backend notification dispatch. |
| **SMS Dispatch** | Backend Service | `EmergencyService` | Twilio SMS API | Cellular Network | ✅ | **REAL** | Configured in FastAPI backend via Twilio REST client. |
| **Push Notifications (FCM)** | `FcmNotificationService` | `FirebaseMessaging` | `POST /notifications/device-token` | Google Play Services | ✅ | **REAL** | Registers device FCM token, sets up high-importance notification channel. |
| **Trusted Contacts (CRUD)** | `TrustedContactsScreen` | `ContactsController` | `GET/POST/PATCH/DELETE /contacts` | `flutter_contacts` | ✅ | **REAL** | Add, edit, delete, priority ordering, SOS toggle, and native address book picker. |
| **Activity History** | `ActivityScreen` | `ActivityController` | `GET /activity/timeline`, `GET /journeys` | None | ✅ | **REAL** | Real timeline of completed journeys, alerts, safe arrivals, and SOS dispatches. |
| **Safety Insights & AI** | `SafetyInsightsScreen` | `IntelligenceRepository` | `POST /intelligence/risk-fusion` | Backend Gemini 1.5 | ✅ | **REAL** | Multi-sensor risk score fusion and safety check-ins. |
| **Live Weather** | `HomeScreen` | `DashboardRepository` | `GET /weather` | OpenWeatherMap API | ✅ | **REAL** | Live temperature, humidity, visibility, and weather condition string. |
| **Fake Call Tool** | `FakeCallScreen` | `ToolsRepository` | `POST /fake-tools/call` | Audio Player | ✅ | **REAL** | Simulates incoming phone call with ringtone, caller ID, and interactive accept/decline. |
| **Fake Message Tool** | `FakeMessageScreen` | `ToolsRepository` | `POST /fake-tools/sms` | None | ✅ | **REAL** | Simulates incoming SMS emergency notification thread. |
| **System Diagnostics** | `DiagnosticsScreen` | `DiagnosticsScreen` | `GET /health` | All Hardware Sensors | ✅ | **REAL** | Real-time live gauge telemetry, environment checks, and hardware test workbench. |
| **Hardware Test Workbench** | `DiagnosticsScreen` | `SensorService`, `VoiceService` | Direct Pipeline Invocations | Sensors + Mic + SOS | ✅ | **REAL** | Real interactive buttons to test shake detector, drop detector, voice prompt, GPS, and SOS. |

---

## Hardware & Execution Boundaries

### 1. Foreground vs. Background Capabilities
- **Foreground Mode**: 100% active. High-frequency GPS updates, real-time accelerometer and gyroscope event streams, speech-to-text dictation loop, live road rendering, and active route deviation detection.
- **Background Mode**:
  - GPS location tracking and periodic 30-second heartbeats operate via Android foreground service with persistent notification.
  - Speech recognition and high-rate accelerometer listeners are paused or throttled by Android OS power management when the app is placed in the background unless a persistent foreground microphone service is active.

### 2. External Service Configurations
- **Google Maps API**: Requires valid `MAPS_API_KEY` with Directions and Routes API enabled. Gracefully falls back to open road routing (OSRM) if disabled.
- **Google OAuth**: Requires Web Client ID matching the backend server audience and Android Debug SHA-1 registered in Google Cloud Console.
- **Firebase Cloud Messaging**: Requires valid `google-services.json` in `android/app/`.
- **Twilio SMS**: Configured in backend `.env` (`TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_PHONE_NUMBER`).
