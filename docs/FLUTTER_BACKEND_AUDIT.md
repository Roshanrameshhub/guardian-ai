# Guardian AI — Flutter Frontend Backend Integration Audit

**Document Version:** 1.0.0  
**Date:** 2026-08-15  
**Scope:** Complete audit of Flutter codebase before real FastAPI backend integration.

---

## 1. Current API Base URL & Environment Configuration
- **Current State:** `ApiConstants.baseUrl` in `lib/core/constants/api_constants.dart` is an empty string `''`.
- **Behavior:** `_isDemo()` in `lib/data/repositories/repository_impl.dart` returns `true` whenever `baseUrl.isEmpty`, causing every repository to return mock data rather than hitting the network.
- **Requirement:** Implement a unified `ApiConfig` that automatically detects or configures the environment:
  - Windows Desktop / Web: `http://localhost:8000/api/v1`
  - Android Emulator: `http://10.0.2.2:8000/api/v1`
  - Physical Android / iOS (LAN): `http://<HOST_IP>:8000/api/v1` (with override support)

---

## 2. Authentication Implementation
- **Current State:** `AuthRepositoryImpl` calls `POST /auth/login` and `POST /auth/register` and calls `_api.setAuthToken(auth.accessToken)`.
- **Shortcomings:** 
  - Token is stored only in-memory in `ApiClient._authToken`.
  - On app reload, authentication is lost.
  - Refresh token (`auth.refreshToken`) is received but not stored.
  - `isAuthenticated()` in `AuthRepository` only checks in-memory `_api.hasAuthToken`.

---

## 3. Token Storage & Security
- **Current State:** In-memory variable in `ApiClient`.
- **Target Architecture:** Implement a persistent, secure `TokenStorageService` (using encrypted storage or device preferences) storing:
  - `access_token`
  - `refresh_token`
  - `user_id`
  - `token_expiry`

---

## 4. Access-Token Refresh Handling (401 Interception)
- **Current State:** `ApiClient` lacks automatic 401 interception.
- **Target Architecture:** 
  - When an authenticated request returns HTTP 401:
    1. Lock outgoing requests.
    2. Invoke `POST /api/v1/auth/refresh` with `refresh_token`.
    3. Update stored access token and `Authorization: Bearer <new_token>`.
    4. Retry the original request.
  - If refresh fails or returns 401:
    1. Clear stored tokens.
    2. Notify auth state to navigate to Login screen.
    3. Prevent infinite refresh loops.

---

## 5. API Client Implementation
- **Current File:** `lib/core/network/api_client.dart`
- **Capabilities:** Methods for `get`, `post`, `put`, `delete` with timeout handling and JSON decoding.
- **Required Enhancements:**
  - Pluggable base URL resolution via `ApiConfig`.
  - Automatic `Authorization: Bearer` injection from `TokenStorageService`.
  - 401 refresh interceptor and replay mechanism.
  - Structured `ApiException` mapping backend FastAPI error responses (`{"detail": "..."}` and `{"message": "..."}`).

---

## 6. Riverpod Providers
- **Current File:** `lib/providers/repository_providers.dart`
- **Providers Configured:**
  - `apiClientProvider`
  - `authRepositoryProvider`
  - `profileRepositoryProvider`
  - `dashboardRepositoryProvider`
  - `journeyRepositoryProvider`
  - `guardianRepositoryProvider`
  - `mapRepositoryProvider`
  - `activityRepositoryProvider`
  - `toolsRepositoryProvider`
  - `intelligenceRepositoryProvider` (Needs explicit provider declaration in `repository_providers.dart`)

---

## 7. Repository Interfaces & Implementations
- **Interfaces (`lib/domain/repositories/repositories.dart`):**
  - `AuthRepository`: `login`, `register`, `logout`, `forgotPassword`, `isAuthenticated`
  - `ProfileRepository`: `fetchProfile`, `updateProfile`, `fetchContacts`, `addContact`
  - `DashboardRepository`: `fetchDashboard`, `fetchWeather`, `fetchNearbyServices`
  - `JourneyRepository`: `fetchJourney`, `fetchJourneys`, `startJourney`, `stopJourney`
  - `GuardianRepository`: `fetchStatus`, `startGuardian`, `stopGuardian`, `triggerSos`
  - `MapRepository`: `fetchRoute`, `fetchAreaSafety`
  - `ActivityRepository`: `fetchActivity`, `fetchNotifications`, `fetchAchievements`
  - `ToolsRepository`: `fetchFakeCall`, `fetchFakeMessage`, `startFakeCall`, `startFakeMessage`
  - `IntelligenceRepository`: `sendMotionSignal`, `sendVoiceAnalysis`, `fuseRisk`, `recordFalsePositive`, `startCheckIn`, `confirmCheckIn`, `cancelCheckIn`, `fetchCheckIns`, `fetchRecommendations`
- **Implementations (`lib/data/repositories/repository_impl.dart`):**
  - All 9 repository implementations are written and wired to DTO decoders.
  - Silent `catch (_) { return MockData... }` blocks need to be replaced with proper error propagation and clean fallback behavior.

---

## 8. DTO & Entity Validation against FastAPI Schemas
| Feature | Endpoint | FastAPI Schema | Flutter DTO / Entity | Status |
|---|---|---|---|---|
| Register | `POST /auth/register` | `UserRegisterRequest` (`full_name`, `email`, `phone`, `password`) | `RegisterRequest` | Match |
| Login | `POST /auth/login` | `UserLoginRequest` (`email`, `password`, `remember_me`) | `LoginRequest` | Match |
| Token Response | `POST /auth/login` | `TokenResponse` (`access_token`, `refresh_token`, `user_id`) | `AuthResponse` | Match |
| Refresh Token | `POST /auth/refresh` | `TokenRefreshRequest` (`refresh_token`) | `TokenRefreshRequest` | Match |
| Profile | `GET /profile` | `UserProfileResponse` | `UserEntity` | Match |
| Contacts | `GET /contacts` | `list[ContactResponse]` | `List<TrustedContactEntity>` | Match |
| Dashboard | `GET /dashboard` | `DashboardResponse` | `DashboardEntity` | Match |
| Start Journey | `POST /journey/start` | `JourneyStartRequest` | `StartJourneyRequest` | Match |
| Guardian Status | `GET /guardian/status` | `GuardianStatusResponse` | `GuardianStatusEntity` | Match |
| SOS Trigger | `POST /emergency/sos` | `SosTriggerRequest` | `SosRequest` | Match |
| Motion Signal | `POST /signals/motion` | `MotionSignalRequest` | `MotionSignalRequest` | Match |
| Voice Distress | `POST /signals/voice` | `VoiceAnalysisRequest` | `VoiceAnalysisRequest` | Match |
| Risk Fusion | `POST /risk/fuse` | `RiskFusionRequest` | `RiskFusionRequest` | Match |
| Safety Check-In | `POST /checkins` | `CheckInStartRequest` | `CheckInStartRequest` | Match |
| Sync Events | `POST /sync/events` | `OfflineBatchSyncRequest` | `OfflineBatchSyncRequest` | Match |

---

## 9. Screens Audit & Real Repository Binding
1. **`LoginScreen` / `SignUpScreen` (`features/auth`):**
   - Driven by `authControllerProvider`. Ready for live backend auth.
2. **`HomeScreen` (`features/home`):**
   - Driven by `homeControllerProvider` fetching `fetchDashboard()`. Ready for live backend data.
3. **`GuardianScreen` (`features/guardian`):**
   - Driven by `guardianControllerProvider` fetching `fetchStatus()` and SOS trigger.
4. **`MapScreen` (`features/map`):**
   - Driven by `mapControllerProvider` fetching `fetchRoute()` and `fetchAreaSafety()`.
5. **`ActivityScreen` & `NotificationsScreen` (`features/activity`):**
   - Driven by `activityControllerProvider` fetching notifications and achievements.
6. **`ProfileScreen` (`features/profile`):**
   - Driven by `profileControllerProvider` fetching profile and contacts.

---

## 10. Audit Summary & Action Items
1. **Create `ApiConfig`** to dynamically handle `localhost`, Android Emulator `10.0.2.2`, and LAN IP.
2. **Implement `TokenStorageService`** and wire it into `ApiClient` for session persistence.
3. **Add 401 Refresh Interceptor** in `ApiClient`.
4. **Remove silent mock fallbacks** in `repository_impl.dart` so errors are propagated honestly to UI controllers.
5. **Expose `intelligenceRepositoryProvider`** in `repository_providers.dart`.
6. **Connect Phone Sensors & Voice Distress V1** using clean, lightweight native adapters.
7. **Verify End-to-End** with `flutter analyze` and integration tests.
