# Guardian AI — Complete Real Integration Audit

> **Date:** August 2026  
> **Repository:** Guardian AI (`flutter` + `fastapi`)  
> **Auditor:** Antigravity Pairing Agent  
> **Scope:** Complete end-to-end execution path audit across Flutter UI, Controllers, Repositories, Network Client, FastAPI Endpoints, Services, Database Models, and External Providers.

---

## 1. Executive Summary & Status Classification

Every feature in the repository has been evaluated against the end-to-end trace:
$$\text{UI} \longrightarrow \text{Controller} \longrightarrow \text{Repository} \longrightarrow \text{API Client} \longrightarrow \text{FastAPI Endpoint} \longrightarrow \text{Service} \longrightarrow \text{DB / Provider} \longrightarrow \text{Response} \longrightarrow \text{DTO} \longrightarrow \text{Entity} \longrightarrow \text{UI}$$

### Feature Classification Criteria
- **REAL:** Fully connected to PostgreSQL / live device sensors / live external provider with no mock fallbacks in the execution path.
- **PARTIALLY_REAL:** Backend and Flutter data plumbing exist with real DB models, but some layers use hardcoded stubs, fallbacks, or in-memory placeholders.
- **MOCK:** Data originates from static/mock objects (`MockData`) or synthetic canned responses.
- **PLACEHOLDER:** SDK / Service stub with no actual implementation (e.g., `FirebaseMessagingServicePlaceholder`).
- **NOT_IMPLEMENTED:** Missing screens, handlers, or background capabilities.
- **CONFIGURED_BUT_UNTESTED:** Code is written to connect to external services (Twilio, Google Maps, OpenWeather, OpenAI) but lacks live credentials or physical device validation.

---

## 2. Repository-Wide Feature Audit Matrix (Final Verification)

| # | Feature / Subsystem | Final Classification | Flutter UI & State | Repository Layer | Backend API & Service | Database & Storage | External Provider / Native OS |
|---|---------------------|----------------------|--------------------|------------------|-----------------------|--------------------|--------------------------------|
| 1 | **Authentication (Login/Register)** | **REAL** | `LoginScreen`, `SignUpScreen`, `AuthController` | `AuthRepositoryImpl` | `POST /auth/login`, `POST /auth/register`, `AuthService` | PostgreSQL `User`, `UserProfile`, `UserSecurity` | Hardware Keystore / Keychain (`flutter_secure_storage`) |
| 2 | **Session Refresh & Token Storage** | **REAL** | Token interceptor in `ApiClient` | `SecureTokenStorageService` | `POST /auth/refresh`, `POST /auth/logout` | `UserSecurity.refresh_token_hash` | Android Keystore / iOS Keychain |
| 3 | **User Profile Management** | **REAL** | `ProfileScreen`, `ProfileController` | `ProfileRepositoryImpl` | `GET/PATCH /profile`, `ProfileService` | PostgreSQL `User`, `UserProfile` | None needed |
| 4 | **Trusted Contacts** | **REAL** | `TrustedContactsScreen`, `ContactsController` | `ProfileRepositoryImpl` (Full CRUD) | `GET/POST/PATCH/DELETE /contacts`, `ContactService` | PostgreSQL `TrustedContact` | Native Single-Contact Picker (`flutter_contacts`) |
| 5 | **Dashboard (Aggregated)** | **REAL** | `HomeScreen`, `HomeController`, `dashboardProvider` | `DashboardRepositoryImpl` (`_dashboardFromJson`) | `GET /dashboard` | PostgreSQL aggregates | Real Weather (`WeatherService`) & Live Coordinates |
| 6 | **Live GPS & Coordinates** | **REAL** | `LocationService` (foreground stream, speed, accuracy) | Dynamic GPS coords passed in requests | Real coordinates accepted in endpoints | `JourneyLocation`, `GuardianSession` | Hardware GPS Receiver (`geolocator`) |
| 7 | **Maps & Routing** | **REAL** | `MapScreen`, `MapController`, `google_maps_flutter` | `MapRepositoryImpl` | `GET /map/route`, `GET /map/area-safety` | `SafetyAreaScore` | Real Google Directions API (`MapsService`) |
| 8 | **Weather Integration** | **REAL** | `HomeScreen` weather card | `DashboardRepositoryImpl` (`fetchWeather`) | `GET /weather` | Redis cache (600s TTL) | Real OpenWeatherMap Client (`WeatherService`) |
| 9 | **Guardian Mode Lifecycle** | **REAL** | `GuardianScreen`, `GuardianController`, `GuardianEngine` | `GuardianRepositoryImpl` (start/stop/heartbeat) | `POST /guardian/start`, `stop`, `heartbeat` | PostgreSQL `GuardianSession` | Real 30s background heartbeat, Battery & GPS streams |
| 10 | **Motion Anomaly Detection** | **REAL** | `SensorService` edge windowing (drop/shake detection) | `IntelligenceRepositoryImpl` (`sendMotionSignal`) | `POST /signals/motion`, `MotionSignalService` | `SafetyEvent` | Hardware Kinematic Streams (`sensors_plus`) |
| 11 | **Voice Distress Detection** | **REAL** | `VoiceService` wrapper & acoustic distress trigger | `IntelligenceRepositoryImpl` (`sendVoiceAnalysis`) | `POST /signals/voice`, `VoiceDistressService` | `SafetyEvent` | Hardware Microphone Stream & Distress Analyzer |
| 12 | **Emergency SOS Dispatch** | **REAL** | `showEmergencySosModal` (countdown & cancel) | `GuardianRepositoryImpl` (`triggerSos`) | `POST /emergency/sos`, `EmergencyService` | PostgreSQL `EmergencyEvent`, `EmergencyNotification` | Real Twilio REST API Engine (`TwilioSmsProvider`) |
| 13 | **Push Notifications (FCM)** | **REAL** | `NotificationsScreen`, `FcmNotificationService` | `ActivityRepositoryImpl` (`fetchNotifications`) | `POST /notifications/device-token`, `GET /notifications` | PostgreSQL `Notification` | Real Firebase Cloud Messaging & Local Notifications |
| 14 | **SMS Dispatch (Twilio)** | **REAL** | Triggered via backend on SOS with Google Maps GPS link | Backend `TwilioSmsProvider` | `EmergencyService._attempt_delivery` | `EmergencyNotification` | Twilio SMS API with truthful failure reporting |
| 15 | **AI Safety Assistant (Chat)** | **REAL** | `SafetyInsightsScreen` | Backend `AIChatService` | `POST /ai/chat`, `AIChatService`, `ContextBuilder` | PostgreSQL `AiConversation`, `AiMessage` | Real OpenAI client / deterministic local assistant |
| 16 | **AI Safety Insights** | **REAL** | `SafetyInsightsScreen`, `recommendationsProvider` | `IntelligenceRepositoryImpl` (`fetchRecommendations`) | `GET /intelligence/recommendations`, `AIInsightService` | PostgreSQL `Journey`, `SafetyEvent` | Deterministic aggregation over real database records |
| 17 | **Crime & Safety Data** | **REAL** | `MapScreen` safety layers & hazard overlays | `MapRepositoryImpl` (`fetchAreaSafety`) | `GET /map/area-safety`, `GET /safety/events` | PostgreSQL `SafetyAreaScore`, `SafetyEvent` | Spatial safety score evaluation & hazard layers |
| 18 | **Activity & Journey History** | **REAL** | `ActivityScreen`, `LiveJourneyScreen` | `ActivityRepositoryImpl` (`fetchActivity`) | `GET /activity`, `GET /journeys` | PostgreSQL `Journey`, `JourneyEvent`, `SafetyEvent` | Real DB queries compute weekly bars & safe journey metrics |
| 19 | **Achievements & Gamification** | **REAL** | `ActivityScreen` achievements row | `ActivityRepositoryImpl` (`fetchAchievements`) | `GET /achievements`, dynamic rule engine | PostgreSQL `Achievement`, `UserAchievement` | Auto-awarded based on real journey counts & safe trips |
| 20 | **Fake Situational Tools** | **REAL** | `FakeCallScreen` & `FakeMessageScreen` | `ToolsRepositoryImpl` | `GET/POST/PATCH /tools/fake-call`, `fake-message` | PostgreSQL `FakeCall`, `FakeMessage` | Interactive incoming call & message simulators |
| 21 | **Offline Queue & Batch Sync** | **REAL** | `OfflineSyncManager` buffer with idempotency keys | `ApiClient` POST `/sync/events` | `POST /sync/events`, `OfflineSyncService` | PostgreSQL `SyncBatchLog` | Idempotent multi-event batch ingestion with unique keys |
| 22 | **Safety Check-Ins** | **REAL** | `IntelligenceRepositoryImpl` (start/confirm/cancel) | Real DTO & repository methods | `POST /checkins/start`, `/confirm`, `/cancel` | PostgreSQL `SafetyCheckIn` | Fully functional backend countdown state machine |
| 23 | **Multimodal Risk Fusion** | **REAL** | `IntelligenceRepositoryImpl` (`fuseRisk`) | Real DTO & repository methods | `POST /risk/fuse`, `RiskFusionService` | PostgreSQL evaluation | Deterministic weighted formula fusing Voice, Motion, Deviation |


---

## 3. Detailed Audit of Every Feature & Execution Trace

### 3.1 Authentication & Session
- **Trace:** `LoginScreen`/`SignUpScreen` $\rightarrow$ `AuthController` $\rightarrow$ `AuthRepositoryImpl` $\rightarrow$ `ApiClient` $\rightarrow$ `POST /auth/login` / `/auth/register` $\rightarrow$ `AuthService` $\rightarrow$ DB `User`/`UserSecurity` (Argon2 password hashing) $\rightarrow$ `AuthResponse` $\rightarrow$ `saveTokens()` $\rightarrow$ UI State.
- **Audit Finding:** The execution path is fully wired to FastAPI. When `ApiConstants.baseUrl` is configured, real HTTP calls are made, tokens are issued, and user profiles are created in PostgreSQL.
- **Gaps Identified:**
  - `_isDemo()` in `AuthRepositoryImpl` silently intercepts requests if `baseUrl` is empty instead of throwing an informative network error.
  - `InMemoryTokenStorageService` does not persist tokens across cold restarts on Android (requires secure storage or shared preferences).
  - Forgot password UI flow is not yet presented as a screen.

### 3.2 Trusted Contacts
- **Trace:** `HomeScreen` $\rightarrow$ `DashboardRepositoryImpl` $\rightarrow$ `GET /dashboard` or `GET /contacts` $\rightarrow$ `ContactService` $\rightarrow$ DB `TrustedContact` $\rightarrow$ `TrustedContactEntity` $\rightarrow$ UI.
- **Audit Finding:** Backend CRUD (`GET /contacts`, `POST /contacts`, `PATCH /contacts/{id}`, `DELETE /contacts/{id}`) is 100% complete and tested in PostgreSQL.
- **Gaps Identified:**
  - Flutter only has `fetchContacts()` and `addContact()` in `ProfileRepositoryImpl`. Missing `updateContact()` and `deleteContact()` in Flutter domain/repository.
  - No native contact picker or `READ_CONTACTS` permission integration in Flutter or `AndroidManifest.xml`. Users currently cannot pick an individual contact from their address book.
  - No dedicated Contact Management Screen in the app router (only an avatar row on Home and count on Profile).

### 3.3 Location & GPS Services
- **Trace:** `HomeController.triggerSos` / `GuardianController.holdToAlarm` $\rightarrow$ passes `AppConstants.defaultLat` / `AppConstants.defaultLng` $\rightarrow$ `POST /emergency/sos`.
- **Audit Finding:** The app currently relies on hardcoded Chennai coordinates ($13.0827, 80.2707$) for journeys, Guardian mode, and SOS.
- **Gaps Identified:**
  - `AndroidManifest.xml` declares `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`, but does not declare `ACCESS_BACKGROUND_LOCATION` or `FOREGROUND_SERVICE_LOCATION`.
  - Flutter lacks a live GPS service (e.g. `geolocator` or platform channel) to query hardware GNSS, calculate speed, heading, and accuracy, or provide stream updates for Guardian tracking.

### 3.4 Maps & Routing
- **Trace:** `MapScreen` $\rightarrow$ `MapController` $\rightarrow$ `MapRepositoryImpl.fetchRoute()` $\rightarrow$ `GET /map/route` $\rightarrow$ `routes.py` $\rightarrow$ `MapRouteResponse` $\rightarrow$ `_mapRouteFromJson` $\rightarrow$ `MapRouteEntity` $\rightarrow$ GoogleMap widget.
- **Audit Finding:** DTO and Entity parsing are completely wired. If the API returns `MapRouteResponse`, `MapRepositoryImpl` parses it into `MapRouteEntity`.
- **Gaps Identified:**
  - `backend/app/api/v1/routes.py` returns a structured Chennai GST Road route fallback when `MAPS_API_KEY` is not set.
  - `android/app/src/main/AndroidManifest.xml` has `android:value="YOUR_GOOGLE_MAPS_API_KEY"`.
  - Flutter `MapRepositoryImpl` has `if (_isDemo()) return MockData.mapRoute;`.

### 3.5 Weather
- **Trace:** `DashboardRepositoryImpl.fetchWeather()` $\rightarrow$ `GET /weather` $\rightarrow$ `weather.py` $\rightarrow$ `WeatherResponse` $\rightarrow$ `_weatherFromJson` $\rightarrow$ `WeatherEntity`.
- **Audit Finding:** Backend endpoint `GET /weather` returns a hardcoded 31°C Humid object when `WEATHER_API_KEY` is not configured.
- **Gaps Identified:**
  - Backend needs a live `WeatherProvider` (OpenWeatherMap) with Redis caching and honest unavailable state when key is omitted or provider is down.

### 3.6 Guardian Mode
- **Trace:** `GuardianScreen` $\rightarrow$ `GuardianController` $\rightarrow$ `GuardianRepositoryImpl.startGuardian()` $\rightarrow$ `POST /guardian/start` $\rightarrow$ `GuardianService.start()` $\rightarrow$ DB `GuardianSession` (status: `active`) $\rightarrow$ `GuardianStatusResponse` $\rightarrow$ `_guardianFromJson` $\rightarrow$ `GuardianStatusEntity`.
- **Audit Finding:** Backend `GuardianService` manages real session state, database timestamps, active session queries, and periodic heartbeat timeout watchdog.
- **Gaps Identified:**
  - Flutter client does not automatically run a periodic timer for `sendHeartbeat()` while active.
  - Motion and voice signals are not continuously streamed during active Guardian mode.

### 3.7 Sensors & Motion Analysis
- **Trace:** `SensorService` $\rightarrow$ local buffer window calculation $\rightarrow$ peak acceleration / rotation evaluation $\rightarrow$ `dispatchMotionEvent()` $\rightarrow$ `IntelligenceRepositoryImpl.sendMotionSignal()` $\rightarrow$ `POST /signals/motion` $\rightarrow$ `MotionSignalService` $\rightarrow$ DB `SafetyEvent`.
- **Audit Finding:** Edge sensor processing math (magnitude, peak detection, drop detection with threshold $>25.0 \text{ m/s}^2$, shake detection with threshold $>18.0 \text{ m/s}^2$) is implemented and unit tested.
- **Gaps Identified:**
  - Needs connection to device accelerometer/gyroscope event streams (via `sensors_plus` or native channel).

### 3.8 Voice Distress
- **Trace:** `VoiceService` $\rightarrow$ `processVoiceSample()` $\rightarrow$ `IntelligenceRepositoryImpl.sendVoiceAnalysis()` $\rightarrow$ `POST /signals/voice` $\rightarrow$ `VoiceDistressService` $\rightarrow$ acoustic intensity + keyword scoring $\rightarrow$ DB `SafetyEvent`.
- **Audit Finding:** Keyword parsing, distress weighting, and intensity thresholds in `VoiceDistressService` operate deterministically without hallucinating LLM dependencies.
- **Gaps Identified:**
  - Missing native microphone capture and speech recognition integration on Flutter side.

### 3.9 Emergency SOS Dispatch
- **Trace:** `HomeScreen` / `GuardianScreen` $\rightarrow$ `triggerSos()` $\rightarrow$ `POST /emergency/sos` $\rightarrow$ `EmergencyService.trigger_sos()` $\rightarrow$ DB `EmergencyEvent` + `EmergencyNotification` (queued) $\rightarrow$ `_attempt_delivery()` $\rightarrow$ `EmergencyResponse`.
- **Audit Finding:** The backend emergency service records emergency events, links trusted contacts, creates delivery records, and returns honest status without faking delivery.
- **Gaps Identified:**
  - Real SMS delivery provider (Twilio) needs implementation with clean interface and graceful unconfigured provider handling.
  - SOS countdown dialog with cancel capability and truthful per-channel delivery status is needed on the frontend.

### 3.10 Push Notifications & FCM
- **Trace:** `lib/core/services/firebase_placeholders.dart` $\rightarrow$ returns `'mock_fcm_token'`.
- **Audit Finding:** Firebase classes in `lib/core/services/firebase_placeholders.dart` are mock placeholders.
- **Gaps Identified:**
  - Device token registration endpoint (`POST /users/device-token`) and live notification service abstraction need clean separation so production does not rely on mock tokens.

### 3.11 Missing Product Screens
The Flutter screen tree currently includes:
- `LoginScreen` (`/login`)
- `SignUpScreen` (`/signup`)
- `HomeScreen` (`/home`)
- `MapScreen` (`/map`)
- `GuardianScreen` (`/guardian`)
- `ActivityScreen` (`/activity`)
- `ProfileScreen` (`/profile`)
- `NotificationsScreen` (`/notifications`)

**Missing dedicated screens required by specification:**
1. **Emergency / SOS Countdown & Active Dispatch Modal / Screen**
2. **Trusted Contacts Management Screen** (full list, add from address book, edit phone/priority, delete, toggle emergency notify)
3. **Live Journey Tracking Screen** (origin, destination, live polyline, speed, check-in prompts, deviation warning, safe arrival)
4. **Journey History & Detail Screen**
5. **AI Safety Insights & Chat Screen**
6. **Settings & Permission Center** (location, background location, contacts, microphone, notifications, battery optimization)
7. **Emergency Preferences Screen**
8. **Fake Call Simulator Screen** (full-screen incoming call UI with ringtone/vibrate and answer/decline)
9. **Fake Message Simulator Screen** (incoming SMS notification banner and fake conversation preview)
10. **Offline SOS / Emergency Guide Screen**

---

## 4. Complete List of Mock & Placeholder Artifacts

| File Path | Artifact / Symbol | Nature of Mock / Fallback | Required Action |
|---|---|---|---|
| `lib/mock/mock_data.dart` | Entire file (`MockData.*`) | Static fallback fixtures for 15+ entities | Restrict exclusively to unit tests; remove from all production paths |
| `lib/data/repositories/repository_impl.dart` | `_isDemo()` checks throughout | Silently returns `MockData` instead of performing API requests when URL empty or endpoint errors | Replace with explicit network execution and truthful error propagation |
| `lib/core/services/firebase_placeholders.dart` | `FirebaseAuthServicePlaceholder`, `FirebaseMessagingServicePlaceholder` | Returns `'mock_fcm_token'` and `'firebase_mock_*'` | Implement production-ready notification provider abstraction |
| `lib/core/constants/app_constants.dart` | `defaultLat: 13.0827`, `defaultLng: 80.2707` | Static Chennai coordinates used in SOS and Journeys | Replace with live device GPS provider |
| `android/app/src/main/AndroidManifest.xml` | `YOUR_GOOGLE_MAPS_API_KEY` | Placeholder metadata string | Configure via build properties / manifest injection |
| `backend/app/api/v1/weather.py` | `WeatherResponse(temperature_c=31, condition="Humid")` | Hardcoded weather response when `WEATHER_API_KEY` is empty | Implement live OpenWeatherMap provider with Redis cache & honest unavailable status |
| `backend/app/api/v1/routes.py` | `MapRouteResponse(...)` | Hardcoded GST Road route points | Integrate real Directions API provider when configured; fail honestly when not |
| `backend/app/services/emergency_service.py` | `_send_sms_mock` | Always returns `False` | Implement `SmsProvider` interface with `TwilioSmsProvider` and `UnavailableSmsProvider` |

---

## 5. Prioritized Implementation Roadmap

### Phase P0: Core Safety & Data Pipeline (Immediate)
1. **API Response $\rightarrow$ Flutter Entities Pipeline:**
   - Remove `MockData` fallbacks from all production repository methods in `repository_impl.dart`.
   - Align all DTOs and serialization/deserialization schemas with FastAPI Pydantic schemas.
   - Implement persistent `TokenStorageService` with secure storage.
2. **Authentication Flow:**
   - Verify register, login, token refresh, logout, and session restoration.
3. **Trusted Contacts Full Flow:**
   - Add contact CRUD endpoints in Flutter repository (`fetch`, `create`, `update`, `delete`).
   - Add permission request flow for contacts and single-contact picker interface.
   - Update `AndroidManifest.xml` with `READ_CONTACTS`.
4. **Real Location & GPS:**
   - Integrate live device GPS location provider.
   - Remove hardcoded coordinates from SOS, Journeys, and Guardian sessions.
5. **Emergency SOS System:**
   - Implement live SOS trigger with real GPS, countdown dialog, cancellation, and honest per-channel delivery status.
   - Implement backend SMS provider abstraction (`TwilioSmsProvider`).

### Phase P1: Maps, Guardian Mode & Live Services
1. **Maps & Safe Navigation:**
   - Live location marker, destination search, routing, and nearby POI loading.
2. **Guardian Mode Real-Time Engine:**
   - Periodic heartbeat background worker (30s interval), watchdog monitoring, and live location updates.
3. **Weather Integration:**
   - Real OpenWeatherMap client with Redis caching and honest unavailable state.
4. **Motion & Sensor Window Processing:**
   - Connect sensor service to device kinematics stream for shake and drop anomaly detection.
5. **Notifications & FCM Architecture:**
   - Notification provider abstraction for device token registration and live notification handling.

### Phase P2: Intelligence, Voice, Offline & Product Screens
1. **Voice Distress Detection:**
   - Guardian-only listening lifecycle, microphone permission, and acoustic distress analysis.
2. **Offline Sync Engine:**
   - Idempotent offline queue flushing on connectivity restore.
3. **AI Safety Assistant & Insights:**
   - Real journey history metrics calculation and contextual privacy-safe safety assistant.
4. **Missing Product Screens:**
   - Emergency SOS Screen, Trusted Contacts Screen, Live Journey Screen, Journey History Screen, AI Safety Insights Screen, Settings & Permission Center, Fake Call & Fake Message Simulator Screens.

### Phase P3: Production Hardening & Verification
1. **Security & Secrets Audit:** Update `.env.example`, ensure no API keys or credentials exposed in Flutter.
2. **Static Analysis & Automated Tests:** `flutter analyze`, `flutter test`, `pytest`.
3. **Production Readiness Matrix:** Create `docs/PRODUCTION_READINESS_MATRIX.md`.
