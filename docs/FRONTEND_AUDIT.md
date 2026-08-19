# Guardian AI — Frontend Audit

> Generated: 2026-08-15 | Flutter version: 3.5+ | Project: guardian_ai v1.2.0

---

## Architecture Overview

```
lib/
├── core/                         # Framework-level code
│   ├── config/app_router.dart    # GoRouter config
│   ├── constants/                # API + app + route constants
│   ├── network/api_client.dart   # Thin HTTP wrapper
│   ├── services/                 # Firebase placeholders
│   ├── theme/                    # Material 3 dark theme
│   ├── utils/                    # Responsive helpers
│   └── widgets/                  # Shared UI components
├── data/
│   ├── datasources/              # Remote datasource stubs
│   ├── dto/api_dto.dart          # Request/Response DTOs
│   └── repositories/             # Concrete repository impls
├── domain/
│   ├── entities/entities.dart    # 16 pure Dart entity classes
│   └── repositories/             # 7 abstract repository interfaces
├── features/
│   ├── auth/                     # Login + SignUp
│   ├── home/                     # Dashboard
│   ├── guardian/                 # Guardian Mode
│   ├── map/                      # Safe Route Map
│   ├── activity/                 # Activity + Notifications
│   └── profile/                  # User Profile
├── mock/mock_data.dart           # ALL mock data (single file)
└── providers/repository_providers.dart  # Riverpod DI
```

---

## Feature Audit Table

### AUTHENTICATION

| Field | Value |
|---|---|
| **Feature** | Login |
| **Screen** | `features/auth/presentation/login_screen.dart` |
| **Controller** | `AuthController` → `authControllerProvider` |
| **Repository** | `AuthRepository` → `AuthRepositoryImpl` |
| **API Endpoint** | `POST /auth/login` |
| **Request Model** | `LoginRequest {email, password, remember_me}` |
| **Response Model** | `AuthResponse {access_token, refresh_token, user_id}` |
| **Currently Mocked?** | ✅ YES — falls back to `mock_access` token |
| **Persistent Data Needed?** | ✅ users table, refresh_tokens table |
| **External API Needed?** | ❌ No (email/password auth) |
| **Realtime Needed?** | ❌ No |
| **New Backend Required?** | ✅ YES |
| **Frontend Changes Required?** | ⚠️ Minimal — token persistence (SharedPreferences) |

| Field | Value |
|---|---|
| **Feature** | Register |
| **Screen** | `features/auth/presentation/sign_up_screen.dart` |
| **Controller** | `AuthController` |
| **Repository** | `AuthRepository` → `AuthRepositoryImpl` |
| **API Endpoint** | `POST /auth/register` |
| **Request Model** | `RegisterRequest {full_name, email, phone, password}` |
| **Response Model** | `AuthResponse` |
| **Currently Mocked?** | ✅ YES |
| **Persistent Data Needed?** | ✅ users, user_profiles |
| **External API Needed?** | ❌ No |
| **Realtime Needed?** | ❌ No |
| **New Backend Required?** | ✅ YES |
| **Frontend Changes Required?** | ❌ None |

---

### DASHBOARD

| Field | Value |
|---|---|
| **Feature** | Home Dashboard |
| **Screen** | `features/home/presentation/home_screen.dart` |
| **Controller** | `HomeController`, `dashboardProvider` (FutureProvider) |
| **Repository** | `DashboardRepository` → `DashboardRepositoryImpl` |
| **API Endpoint** | `GET /dashboard` |
| **Request Model** | None (authenticated GET) |
| **Response Model** | `DashboardEntity {userName, avatarUrl, safetyScore, safetyStatus, guardianModeActive, guardianSubtitle, recentJourney, weather, aiScanningLabel, nearbyServices, contacts}` |
| **Currently Mocked?** | ✅ YES — `MockData.dashboard` always returned |
| **Persistent Data Needed?** | ✅ Aggregated from: users, journeys, guardian_sessions, weather_cache, nearby_services_cache, trusted_contacts |
| **External API Needed?** | ⚠️ Weather (cacheable), nearby services (cacheable) |
| **Realtime Needed?** | ❌ No (poll on focus) |
| **New Backend Required?** | ✅ YES |
| **Frontend Changes Required?** | ⚠️ `DashboardDto.fromJson()` needed |

**HomeController actions:**
- `toggleGuardian(bool)` → calls `guardianRepo.start/stop`
- `startSafeWalk()` → calls `journeyRepo.startJourney`
- `fakeCall()` → calls `toolsRepo.startFakeCall`
- `fakeMessage()` → calls `toolsRepo.startFakeMessage`
- `triggerSos()` → calls `guardianRepo.triggerSos`

---

### PROFILE

| Field | Value |
|---|---|
| **Feature** | User Profile |
| **Screen** | `features/profile/presentation/profile_screen.dart` |
| **Controller** | `ProfileController`, `profileProvider` (FutureProvider) |
| **Repository** | `ProfileRepository` → `ProfileRepositoryImpl` |
| **API Endpoint** | `GET /profile`, `PATCH /profile` |
| **Request Model** | `UserEntity` (partial update) |
| **Response Model** | `UserEntity {id, name, email, phone, avatarUrl, isPremium, membershipName, nextBilling, safeTrips, trustedContactCount, appVersion, safetyShieldActive}` |
| **Currently Mocked?** | ✅ YES — calls API, ignores response, returns `MockData.user` |
| **Persistent Data Needed?** | ✅ users, user_profiles |
| **External API Needed?** | ❌ No |
| **Realtime Needed?** | ❌ No |
| **New Backend Required?** | ✅ YES |
| **Frontend Changes Required?** | ⚠️ `UserDto.fromJson()` needed |

**ProfileController actions:**
- `signOut()` → calls `authRepo.logout()`
- `setGuardianEnabled(bool)` → local state only

---

### TRUSTED CONTACTS

| Field | Value |
|---|---|
| **Feature** | Trusted Contacts |
| **Screen** | Home screen widget + Profile screen |
| **Controller** | `profileProvider` (via ProfileRepository) |
| **Repository** | `ProfileRepository.fetchContacts()`, `addContact()` |
| **API Endpoint** | `GET /contacts`, `POST /contacts` |
| **Request Model** | `TrustedContactEntity` |
| **Response Model** | `List<TrustedContactEntity> {id, name, avatarUrl, isOnline, phone}` |
| **Currently Mocked?** | ✅ YES — `MockData.contacts` always returned |
| **Persistent Data Needed?** | ✅ trusted_contacts table |
| **External API Needed?** | ❌ No |
| **Realtime Needed?** | ❌ No |
| **New Backend Required?** | ✅ YES |
| **Frontend Changes Required?** | ⚠️ `TrustedContactDto.fromJson()` needed |

---

### JOURNEYS

| Field | Value |
|---|---|
| **Feature** | Journey Tracking |
| **Screen** | Activity screen list + Home dashboard |
| **Controller** | `HomeController.startSafeWalk()` |
| **Repository** | `JourneyRepository` → `JourneyRepositoryImpl` |
| **API Endpoints** | `GET /journeys`, `GET /journey/{id}`, `POST /journey/start`, `POST /journey/stop/{id}` |
| **Request Model** | `StartJourneyRequest {origin, destination, origin_lat, origin_lng, dest_lat, dest_lng}` |
| **Response Model** | `JourneyEntity {id, title, subtitle, from, to, dateLabel, timeRange, safetyScore, isAlert, completedSafely}` |
| **Currently Mocked?** | ✅ YES — `MockData.journeys` always returned |
| **Persistent Data Needed?** | ✅ journeys, journey_locations, journey_events |
| **External API Needed?** | ❌ No |
| **Realtime Needed?** | ⚠️ WebSocket for active journey updates |
| **New Backend Required?** | ✅ YES |
| **Frontend Changes Required?** | ⚠️ `JourneyDto.fromJson()` needed |

---

### GUARDIAN MODE

| Field | Value |
|---|---|
| **Feature** | Guardian Mode |
| **Screen** | `features/guardian/presentation/guardian_screen.dart` |
| **Controller** | `GuardianController`, `guardianStatusProvider` |
| **Repository** | `GuardianRepository` → `GuardianRepositoryImpl` |
| **API Endpoints** | `POST /guardian/start`, `POST /guardian/stop`, `GET /guardian/status` |
| **Request Model** | None (authenticated POST) |
| **Response Model** | `GuardianStatusEntity {isActive, statusLabel, monitoringLabel, voiceSyncLive, voiceSyncState, batteryPercent, speedKmh, speedStatus, estimatedArrival, minutesLeft, origin, destination, progress, currentLocation, avatarUrl}` |
| **Currently Mocked?** | ✅ YES — `MockData.guardian` always returned |
| **Persistent Data Needed?** | ✅ guardian_sessions table |
| **External API Needed?** | ❌ No |
| **Realtime Needed?** | ✅ YES — WebSocket heartbeat + location updates |
| **New Backend Required?** | ✅ YES — including watchdog worker |
| **Frontend Changes Required?** | ⚠️ `GuardianStatusDto.fromJson()` + heartbeat timer |

**GuardianController actions:**
- `toggle(bool)` → start or stop guardian
- `holdToAlarm()` → trigger SOS with message "HOLD TO ALARM triggered"

---

### MAP / SAFE ROUTES

| Field | Value |
|---|---|
| **Feature** | Safe Route Map |
| **Screen** | `features/map/presentation/map_screen.dart` |
| **Controller** | `MapController`, `mapRouteProvider` |
| **Repository** | `MapRepository` → `MapRepositoryImpl` |
| **API Endpoints** | `GET /map/route?destination=X`, `GET /map/area-safety` |
| **Request Model** | `destination` query param |
| **Response Model** | `MapRouteEntity {from, to, safetyScore, safetyLabel, etaMinutes, trafficLabel, distanceKm, via, policeNearby, hospitalsNearby, metroKm, routePoints, pois, originLat, originLng, destLat, destLng}` |
| **Currently Mocked?** | ✅ YES — `MockData.mapRoute` always returned |
| **Persistent Data Needed?** | ⚠️ Cacheable route data |
| **External API Needed?** | ✅ Google Maps Directions API / OSRM |
| **Realtime Needed?** | ❌ No |
| **New Backend Required?** | ✅ YES — MapsProvider abstraction |
| **Frontend Changes Required?** | ⚠️ `MapRouteDto.fromJson()` needed |

**MapController local UI state:**
- `selectedFilter`: safeRoute / police / hospital
- `nightMode`: boolean
- `searchQuery`: string

---

### ACTIVITY + ANALYTICS

| Field | Value |
|---|---|
| **Feature** | Activity Feed |
| **Screen** | `features/activity/presentation/activity_screen.dart` |
| **Controller** | `activityProvider` (FutureProvider) |
| **Repository** | `ActivityRepository` → `ActivityRepositoryImpl` |
| **API Endpoint** | `GET /activity` |
| **Request Model** | None |
| **Response Model** | `ActivityEntity {avatarUrl, weeklyOverview, metrics, journeys, achievements, safetyEvents}` |
| **Currently Mocked?** | ✅ YES |
| **Persistent Data Needed?** | ✅ journeys, safety_events, user_achievements |
| **External API Needed?** | ❌ No |
| **Realtime Needed?** | ❌ No |
| **New Backend Required?** | ✅ YES |
| **Frontend Changes Required?** | ⚠️ `ActivityDto.fromJson()` needed |

---

### NOTIFICATIONS

| Field | Value |
|---|---|
| **Feature** | Notifications |
| **Screen** | `features/activity/presentation/notifications_screen.dart` |
| **Controller** | `notificationsProvider` (FutureProvider) |
| **Repository** | `ActivityRepository.fetchNotifications()` |
| **API Endpoint** | `GET /notifications` |
| **Request Model** | None |
| **Response Model** | `List<NotificationEntity> {id, title, body, timeLabel, isRead}` |
| **Currently Mocked?** | ✅ YES |
| **Persistent Data Needed?** | ✅ notifications table |
| **External API Needed?** | ❌ No |
| **Realtime Needed?** | ⚠️ Push notifications |
| **New Backend Required?** | ✅ YES |
| **Frontend Changes Required?** | ⚠️ `NotificationDto.fromJson()` needed |

---

### ACHIEVEMENTS

| Field | Value |
|---|---|
| **Feature** | Achievements |
| **Screen** | Activity screen section |
| **Controller** | `activityProvider` |
| **Repository** | `ActivityRepository.fetchAchievements()` |
| **API Endpoint** | `GET /achievements` |
| **Request Model** | None |
| **Response Model** | `List<AchievementEntity> {id, title, subtitle, unlocked, iconKey}` |
| **Currently Mocked?** | ✅ YES |
| **Persistent Data Needed?** | ✅ achievements, user_achievements |
| **External API Needed?** | ❌ No |
| **Realtime Needed?** | ❌ No |
| **New Backend Required?** | ✅ YES |
| **Frontend Changes Required?** | ❌ None — iconKey stays as string |

---

### WEATHER

| Field | Value |
|---|---|
| **Feature** | Weather |
| **Screen** | Home Dashboard widget |
| **Controller** | `dashboardProvider` |
| **Repository** | `DashboardRepository.fetchWeather()` |
| **API Endpoint** | `GET /weather` |
| **Request Model** | None (location from user context) |
| **Response Model** | `WeatherEntity {temperatureC, location, condition, visibilityKm}` |
| **Currently Mocked?** | ✅ YES |
| **Persistent Data Needed?** | ✅ weather_cache (TTL 10min) |
| **External API Needed?** | ✅ OpenWeatherMap / WeatherAPI |
| **Realtime Needed?** | ❌ No |
| **New Backend Required?** | ✅ YES |
| **Frontend Changes Required?** | ⚠️ `WeatherDto.fromJson()` needed |

---

### NEARBY SERVICES

| Field | Value |
|---|---|
| **Feature** | Nearby Services |
| **Screen** | Home Dashboard widget |
| **Controller** | `dashboardProvider` |
| **Repository** | `DashboardRepository.fetchNearbyServices()` |
| **API Endpoint** | `GET /services/nearby` |
| **Request Model** | None (location from context) |
| **Response Model** | `List<NearbyServiceEntity> {id, name, type, distanceKm}` |
| **Currently Mocked?** | ✅ YES |
| **Persistent Data Needed?** | ✅ nearby_services_cache |
| **External API Needed?** | ✅ Google Places / OSM Overpass |
| **Realtime Needed?** | ❌ No |
| **New Backend Required?** | ✅ YES |
| **Frontend Changes Required?** | ⚠️ `NearbyServiceDto.fromJson()` needed |

---

### EMERGENCY SOS

| Field | Value |
|---|---|
| **Feature** | SOS |
| **Screen** | Home screen FAB + Guardian screen hold-to-alarm |
| **Controller** | `HomeController.triggerSos()`, `GuardianController.holdToAlarm()` |
| **Repository** | `GuardianRepository.triggerSos()` |
| **API Endpoint** | `POST /emergency/sos` |
| **Request Model** | `SosRequest {lat, lng, message?}` |
| **Response Model** | `ApiMessageResponse {success, message}` |
| **Currently Mocked?** | ✅ YES — returns `"Emergency contacts notified (mock)"` |
| **Persistent Data Needed?** | ✅ emergency_events, emergency_notifications |
| **External API Needed?** | ⚠️ Push/SMS for real notification delivery |
| **Realtime Needed?** | ✅ WebSocket emergency status stream |
| **New Backend Required?** | ✅ YES |
| **Frontend Changes Required?** | ⚠️ Show real delivery status |

---

### FAKE TOOLS

| Field | Value |
|---|---|
| **Feature** | Fake Call / Fake Message |
| **Screen** | Home screen quick actions |
| **Controller** | `HomeController.fakeCall()`, `HomeController.fakeMessage()` |
| **Repository** | `ToolsRepository` → `ToolsRepositoryImpl` |
| **API Endpoints** | `POST /tools/fake-call`, `POST /tools/fake-message` |
| **Request Model** | None |
| **Response Model** | `ApiMessageResponse {success, message}` |
| **Currently Mocked?** | ✅ YES — no real API call for fetch, fake delay for trigger |
| **Persistent Data Needed?** | ✅ fake_calls, fake_messages tables |
| **External API Needed?** | ❌ No (Flutter handles local simulation) |
| **Realtime Needed?** | ❌ No |
| **New Backend Required?** | ✅ YES |
| **Frontend Changes Required?** | ❌ None |

---

## Mock Inventory

| File | Mock Pattern | Count |
|---|---|---|
| `AuthRepositoryImpl.login` | `ApiNotConfiguredException` → mock token | 1 |
| `AuthRepositoryImpl.register` | `ApiNotConfiguredException` → mock token | 1 |
| `ProfileRepositoryImpl.fetchProfile` | API called + ignored → `MockData.user` | 1 |
| `ProfileRepositoryImpl.updateProfile` | API called + ignored → returns user param | 1 |
| `ProfileRepositoryImpl.fetchContacts` | API called + ignored → `MockData.contacts` | 1 |
| `DashboardRepositoryImpl.fetchDashboard` | API called + ignored → `MockData.dashboard` | 1 |
| `DashboardRepositoryImpl.fetchWeather` | API called + ignored → `MockData.weather` | 1 |
| `DashboardRepositoryImpl.fetchNearbyServices` | API called + ignored → `MockData.nearbyServices` | 1 |
| `JourneyRepositoryImpl.fetchJourney` | API called + ignored → `MockData.journeys.firstWhere` | 1 |
| `JourneyRepositoryImpl.fetchJourneys` | API called + ignored → `MockData.journeys` | 1 |
| `JourneyRepositoryImpl.startJourney` | API called + ignored → `MockData.recentJourney` | 1 |
| `GuardianRepositoryImpl.fetchStatus` | API called + ignored → `MockData.guardian` | 1 |
| `GuardianRepositoryImpl.startGuardian` | API called + ignored → `MockData.guardian` | 1 |
| `GuardianRepositoryImpl.stopGuardian` | API called + ignored → inline mock entity | 1 |
| `MapRepositoryImpl.fetchRoute` | API called + ignored → `MockData.mapRoute` | 1 |
| `MapRepositoryImpl.fetchAreaSafety` | API called + ignored → `MockData.areaSafety` | 1 |
| `ActivityRepositoryImpl.fetchActivity` | API called + ignored → `MockData.activity` | 1 |
| `ActivityRepositoryImpl.fetchNotifications` | API called + ignored → `MockData.notifications` | 1 |
| `ActivityRepositoryImpl.fetchAchievements` | API called + ignored → `MockData.achievements` | 1 |
| `ToolsRepositoryImpl.fetchFakeCall` | Returns `MockData.fakeCall` directly | 1 |
| `ToolsRepositoryImpl.fetchFakeMessage` | Returns `MockData.fakeMessage` directly | 1 |

**Total: 21 mock production paths to replace**
