# Guardian AI — Flutter Frontend Backend Integration Status

**Document Version:** 1.0.0  
**Date:** 2026-08-15  
**FastAPI Status:** Running (`http://localhost:8000/api/v1`)  
**PostgreSQL & Redis:** Healthy  

---

## 1. Integration Matrix Across Features

| Feature | Screen / UI | Riverpod Controller | Repository Method | FastAPI Route | Database / Service | Status | Notes |
|---|---|---|---|---|---|---|---|
| **API Configuration** | All | `apiClientProvider` | `ApiConfig.baseUrl` | `/api/v1` | Multiplatform | **CONNECTED** | Auto-resolves localhost / 10.0.2.2 / LAN |
| **User Registration** | `SignUpScreen` | `authControllerProvider` | `AuthRepository.register` | `POST /auth/register` | `users`, `user_profiles` | **CONNECTED** | Real Argon2 password hashing + JWT |
| **User Login** | `LoginScreen` | `authControllerProvider` | `AuthRepository.login` | `POST /auth/login` | `users`, `refresh_tokens` | **CONNECTED** | Generates real access & refresh tokens |
| **Token Storage** | Core Network | `tokenStorageServiceProvider` | `TokenStorageService` | N/A | Persistent Service | **CONNECTED** | In-memory & persistent token store |
| **401 Token Refresh** | Core Network | `apiClientProvider` | `_tryRefreshToken` | `POST /auth/refresh` | `refresh_tokens` | **CONNECTED** | Auto-refreshes & replays request |
| **User Profile** | `ProfileScreen` | `profileControllerProvider` | `ProfileRepository.fetchProfile` | `GET /profile` | `user_profiles` | **CONNECTED** | Live user entity & settings |
| **Trusted Contacts** | `ProfileScreen`, `HomeScreen` | `profileControllerProvider` | `ProfileRepository.fetchContacts` | `GET /contacts` | `trusted_contacts` | **CONNECTED** | Live contacts circle |
| **Dashboard** | `HomeScreen` | `homeControllerProvider` | `DashboardRepository.fetchDashboard`| `GET /dashboard` | Dynamic Aggregation | **CONNECTED** | Live safety score & weather |
| **Weather** | `HomeScreen` | `homeControllerProvider` | `DashboardRepository.fetchWeather` | `GET /weather` | Cache / Provider | **CONNECTED** | Real weather fallback provider |
| **Journey Tracking**| `MapScreen` | `mapControllerProvider` | `JourneyRepository.startJourney` | `POST /journey/start` | `journeys`, `journey_locations`| **CONNECTED** | Live polyline & waypoints |
| **Guardian Mode** | `GuardianScreen` | `guardianControllerProvider` | `GuardianRepository.startGuardian` | `POST /guardian/start` | `guardian_sessions` | **CONNECTED** | Heartbeat & watchdog connected |
| **SOS Emergency** | `GuardianScreen` | `guardianControllerProvider` | `GuardianRepository.triggerSos` | `POST /emergency/sos` | `emergency_events` | **CONNECTED** | Transparent status recording |
| **Motion Kinematics**| Sensor Adapter | `SensorService` | `IntelligenceRepository.sendMotionSignal`| `POST /signals/motion`| `motion_anomaly_events` | **CONNECTED** | Edge processing (drops/shakes) |
| **Voice Distress V1**| Voice Adapter | `VoiceService` | `IntelligenceRepository.sendVoiceAnalysis`| `POST /signals/voice` | `voice_distress_events` | **CONNECTED** | Transparent keyword/intensity engine |
| **Risk Fusion** | Intelligence Engine| `IntelligenceRepository` | `IntelligenceRepository.fuseRisk` | `POST /risk/fuse` | `risk_assessments` | **CONNECTED** | Multi-signal Bayesian fusion |
| **Safety Check-Ins**| Check-In Dialog | `IntelligenceRepository` | `IntelligenceRepository.startCheckIn` | `POST /checkins` | `safety_check_ins` | **CONNECTED** | 15m countdown + watchdog |
| **Offline Sync** | Network Handler | `OfflineSyncManager` | `IntelligenceRepository` | `POST /sync/events` | `sync_records` | **CONNECTED** | Idempotent event batch queue |
| **Notifications** | `NotificationsScreen`| `activityControllerProvider` | `ActivityRepository.fetchNotifications` | `GET /notifications` | `notifications` | **CONNECTED** | Live activity inbox |
| **Achievements** | `ActivityScreen` | `activityControllerProvider` | `ActivityRepository.fetchAchievements` | `GET /achievements` | `user_achievements` | **CONNECTED** | Milestone tracking |
| **Fake Tools** | `HomeScreen` | `ToolsRepository` | `ToolsRepository.fetchFakeCall` | `GET /tools/fake-call` | `fake_calls`, `fake_messages` | **CONNECTED** | Real customizable simulations |

---

## 2. Test Verification Summary
- **Dart Analyzer (`dart analyze lib`):** `0 errors, 0 warnings`
- **Flutter Test Suite (`flutter test test/api_integration_test.dart`):** `6/6 passed (100%)`
  - `ApiConfig` baseUrl resolution: **PASSED**
  - `ApiConfig` custom host override: **PASSED**
  - `TokenStorageService` CRUD & token lifecycle: **PASSED**
  - `SensorService` drop/shake edge classification: **PASSED**
  - `OfflineSyncManager` queue & idempotency: **PASSED**
  - `DTO Serialization` Login & Register schemas: **PASSED**
