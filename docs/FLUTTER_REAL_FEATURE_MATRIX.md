# Guardian AI — Full Frontend Feature Integration Matrix

This document provides the exhaustive, verified architecture matrix for all 23 subsystems of the Guardian AI application, tracing each feature end-to-end from the Flutter UI layer to the FastAPI backend.

---

## Complete Subsystem Mapping Matrix

| # | Subsystem | Flutter Screen / Widget | Controller / Provider | Repository Method | ApiClient Method | Backend Endpoint & Router | DTO Schemas (Req / Res) | Error Handling & Diagnostics | Verification Status |
|---|-----------|-------------------------|-----------------------|-------------------|------------------|---------------------------|-------------------------|------------------------------|---------------------|
| 1 | **Authentication (Email/Password)** | `LoginScreen`, `RegisterScreen` (`lib/features/auth/`) | `authControllerProvider` (`AuthController`) | `AuthRepositoryImpl.login`, `register` | `ApiClient.post` | `POST /api/v1/auth/login`, `POST /api/v1/auth/register` (`auth.py`) | `LoginRequest`, `RegisterRequest` $\to$ `AuthResponse` | `AuthException` (401), `ApiException` (422), `DevLog.auth` | **REAL + VERIFIED** |
| 2 | **Google OAuth** | `LoginScreen` (`GoogleSignInButton`) | `authControllerProvider.signInWithGoogle` | `AuthRepositoryImpl.loginWithGoogle` | `ApiClient.post` | `POST /api/v1/auth/google` (`auth.py`) | `GoogleLoginRequest` $\to$ `AuthResponse` | Native account picker, token verification, `DevLog.auth` | **REAL + VERIFIED** |
| 3 | **Secure Token Persistence** | `SplashScreen`, `AppRouter` (`lib/core/config/`) | `tokenStorageServiceProvider` (`SecureTokenStorageService`) | `TokenStorageService.saveTokens`, `getAccessToken` | Direct Secure Storage / InMemory fallback | N/A (Client Security) | `accessToken`, `refreshToken`, `userId` | In-memory fallback if Keychain/Keystore unavailable | **REAL + VERIFIED** |
| 4 | **User Profile Management** | `ProfileScreen` (`lib/features/profile/`) | `profileProvider` (`ProfileRepositoryImpl`) | `ProfileRepositoryImpl.fetchProfile`, `updateProfile` | `ApiClient.get`, `ApiClient.patch` | `GET /api/v1/profile`, `PATCH /api/v1/profile` (`profile.py`) | `UserEntity` $\to$ `UserResponse` | Typed null-safe deserialization, `DevLog.log` | **REAL + VERIFIED** |
| 5 | **Trusted Contacts CRUD** | `TrustedContactsScreen` (`lib/features/profile/`) | `contactsControllerProvider`, `trustedContactsProvider` | `ContactRepositoryImpl.fetchContacts`, `createContact`, `deleteContact` | `ApiClient.get`, `ApiClient.post`, `ApiClient.delete` | `GET /api/v1/contacts`, `POST /api/v1/contacts`, `DELETE /api/v1/contacts/{id}` (`contacts.py`) | `TrustedContactEntity` $\to$ `ContactResponse` | Native contact picker permission, `DevLog.contact` | **REAL + VERIFIED** |
| 6 | **Home Command Center Dashboard** | `HomeScreen` (`lib/features/home/`) | `dashboardProvider`, `homeControllerProvider` | `DashboardRepositoryImpl.fetchDashboard` | `ApiClient.get` | `GET /api/v1/dashboard` (`dashboard.py`) | Query: `lat`, `lng` $\to$ `DashboardResponse` | Granular `NetworkException`, `AuthException`, `DevLog.home` | **REAL + VERIFIED** |
| 7 | **Safety Score Ring & Diagnostics** | `SafetyScoreRing`, `DebugDiagnosticsOverlay` | `dashboardProvider`, `LocationService` | `DashboardRepositoryImpl.fetchDashboard` | `ApiClient.get` | `GET /api/v1/dashboard`, `GET /api/v1/safety/score` (`dashboard.py`, `safety.py`) | `DashboardResponse`, `SafetyScoreResponse` | Live FPS, hardware telemetry, HTTP endpoint status | **REAL + VERIFIED** |
| 8 | **Google Maps Safety Planning** | `MapScreen` (`lib/features/map/`) | `guardianMapControllerProvider` (`GuardianMapController`) | `GuardianRepositoryImpl.calculateSafeRoute` | `ApiClient.post` | `POST /api/v1/guardian/route` (`guardian.py`, `maps_service.py`) | `GuardianRoutePlanRequest` $\to$ `GuardianRoutePlanResponse` | 3 Route alternatives (*Safer*, *Fastest*, *Balanced*), `DevLog.route` | **REAL + VERIFIED** |
| 9 | **Auto-Framing Camera Bounds** | `MapScreen._fitRouteBounds` | `guardianMapControllerProvider` | N/A (Maps Projection) | Native Map SDK | N/A | `LatLngBounds` computation | Post-frame callback auto-zoom with padding | **REAL + VERIFIED** |
| 10 | **Chennai Safety Zones Layer** | `MapScreen` (56 Polygons/Circles) | `guardianMapControllerProvider` | `GuardianRepositoryImpl.fetchSafetyZones` | `ApiClient.get` | `GET /api/v1/guardian/safety-zones` (`guardian.py`) | `SafetyZoneResponse` list | Color-coded risk levels, interactive detail sheet | **REAL + VERIFIED** |
| 11 | **Police Stations & POI Help** | `MapScreen`, `PoliceStationDetailSheet` | `guardianMapControllerProvider` | `GuardianRepositoryImpl.fetchPoliceStations`, `fetchNearbyHelp` | `ApiClient.get` | `GET /api/v1/guardian/police-stations`, `GET /api/v1/guardian/nearby-help` (`guardian.py`) | `PoliceStationResponse`, `NearbyHelpResponse` | Distance sort, one-touch emergency dialer | **REAL + VERIFIED** |
| 12 | **Journey Confirmation Pre-Trip** | `JourneyConfirmationScreen` (`lib/features/journey/`) | `journeyRepositoryProvider` | `JourneyRepositoryImpl.startJourney` | `ApiClient.post` | `POST /api/v1/journey/start` (`journeys.py`) | `StartJourneyRequest` $\to$ `JourneyResponse` | Protection checklist validation before DB creation | **REAL + VERIFIED** |
| 13 | **Live Journey Telemetry & Map** | `LiveJourneyScreen` (`lib/features/journey/`) | `locationServiceProvider`, `JourneyRepositoryImpl` | `JourneyRepositoryImpl.stopJourney` | `ApiClient.post` | `POST /api/v1/journey/stop` (`journeys.py`) | `StopJourneyRequest` $\to$ `JourneyResponse` | GPS speed ($\text{km/h}$), accuracy ($\pm X\text{m}$), ETA | **REAL + VERIFIED** |
| 14 | **Route Corridor Deviation Watchdog** | `LiveJourneyScreen`, `RouteDeviationDetector` | `RouteDeviationDetector` ($\text{threshold}=150\text{m}$) | `JourneyRepositoryImpl.sendStationaryCheck` | `ApiClient.post` | `POST /api/v1/safety/route-deviation` (`safety.py`) | `RouteDeviationRequest` $\to$ `ApiMessageResponse` | 3-point confirmation before safety prompt modal | **REAL + VERIFIED** |
| 15 | **Stationary / Sudden Stop Watchdog** | `LiveJourneyScreen` | Timer Watchdog ($\text{speed}<0.8\text{ km/h}$, $t=180\text{s}$) | `JourneyRepositoryImpl.sendStationaryCheck` | `ApiClient.post` | `POST /api/v1/journey/stationary-check` (`journeys.py`) | `StationaryCheckRequest` $\to$ `ApiMessageResponse` | Interactive confirmation dialog ("Are you safe?") | **REAL + VERIFIED** |
| 16 | **Accelerometer & Gyroscope Sensors** | `SensorService`, `LiveJourneyScreen` | `sensorServiceProvider` | `IntelligenceRepositoryImpl.reportMotionSignal` | `ApiClient.post` | `POST /api/v1/signals/motion` (`intelligence.py`) | `MotionSignalRequest` $\to$ `SignalResponse` | Fall / shake spike triggers 20s SOS countdown | **REAL + VERIFIED** |
| 17 | **Voice Distress STT Detection** | `VoiceService`, `LiveJourneyScreen` | `voiceServiceProvider` | `IntelligenceRepositoryImpl.reportVoiceSignal` | `ApiClient.post` | `POST /api/v1/signals/voice` (`intelligence.py`) | `VoiceSignalRequest` $\to$ `SignalResponse` | Keywords (*help*, *danger*, *guardian*) trigger prompt | **REAL + VERIFIED** |
| 18 | **Guardian Mode & Heartbeat** | `GuardianScreen`, `GuardianEngine` | `guardianEngineProvider`, `guardianStatusProvider` | `GuardianRepositoryImpl.startGuardian`, `stopGuardian`, `sendHeartbeat` | `ApiClient.post` | `POST /api/v1/guardian/start`, `POST /api/v1/guardian/stop`, `POST /api/v1/guardian/{session_id}/heartbeat` (`guardian.py`) | `HeartbeatRequest` $\to$ `GuardianStatusResponse` | 30s background ticker with kinematics reporting | **REAL + VERIFIED** |
| 19 | **Global Emergency SOS Lifecycle** | `SosFab`, `EmergencySosModal`, `SosCountdownOverlay` | `guardianRepositoryProvider` | `GuardianRepositoryImpl.triggerSos` | `ApiClient.post` | `POST /api/v1/emergency/sos` (`emergency.py`) | `SosRequest` $\to$ `EmergencyAlertResponse` | 3s countdown, GPS lock, Twilio SMS & FCM dispatch | **REAL + VERIFIED** |
| 20 | **Live Weather Integration** | `HomeScreen` (`WeatherCard`) | `dashboardProvider` | `DashboardRepositoryImpl.fetchWeather` | `ApiClient.get` | `GET /api/v1/weather` (`weather.py`) | Query: `lat`, `lng` $\to$ `WeatherResponse` | OpenWeatherMap live query with location fallback | **REAL + VERIFIED** |
| 21 | **AI Safety Insights (Gemini)** | `SafetyInsightsScreen` (`lib/features/ai/`) | `aiInsightsProvider` | `IntelligenceRepositoryImpl.fetchInsights` | `ApiClient.get` | `GET /api/v1/ai/insights` (`ai.py`) | `AiInsightsResponse` | Real Gemini 2.5 Flash safety analysis | **REAL + VERIFIED** |
| 22 | **Activity History & Metrics** | `ActivityScreen` (`lib/features/activity/`) | `activityProvider`, `activityRepositoryProvider` | `ActivityRepositoryImpl.fetchActivity` | `ApiClient.get` | `GET /api/v1/activity` (`activity.py`) | `ActivityResponse` | Aggregated weekly overview, safe walks, achievements | **REAL + VERIFIED** |
| 23 | **Fake Tools (Call / Message)** | `HomeScreen` (Quick Actions) | `toolsRepositoryProvider` | `ToolsRepositoryImpl.startFakeCall`, `startFakeMessage` | `ApiClient.post` | `POST /api/v1/fake-tools/call`, `POST /api/v1/fake-tools/message` (`fake_tools.py`) | `FakeToolResponse` | Immediate discreet exit mechanism | **REAL + VERIFIED** |

---

## Architectural Data Flow

```
[Flutter UI Screen]
       │
       ▼ (Riverpod StateNotifier / FutureProvider)
[Controller Layer]
       │
       ▼ (Domain Repository Interface)
[Repository Implementation]
       │
       ▼ (JSON Serialization / Deserialization + DevLog)
[ApiClient (Network Client)]
       │
       ▼ (HTTP GET / POST / PATCH / DELETE with Bearer JWT)
[FastAPI REST Router]
       │
       ▼ (Core Service Layer & Watchdogs)
[PostgreSQL + Redis + Google Maps API + Twilio + Gemini]
```
