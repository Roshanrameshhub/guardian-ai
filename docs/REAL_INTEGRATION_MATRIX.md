# Guardian AI — Real Integration Matrix

## End-to-End Architecture Trace

This matrix traces every feature across all layers:
`UI → Screen/Widget → Riverpod Provider/Controller → Repository → API Client → FastAPI Endpoint → Backend Service → Database/Hardware → Response → State → UI`.

---

```
                                      END-TO-END DATA FLOW
                                      
 [ Flutter UI Screen ]  ◄──────── StateNotifier / AsyncValue ────────► [ Riverpod Provider ]
          │                                                                      │
          ▼                                                                      ▼
 [ Domain Repository ]  ◄──────── Entity & Data Models ───────────────► [ RepositoryImpl ]
          │                                                                      │
          ▼                                                                      ▼
 [ Dio HTTP / WebSocket ] ◄────── Bearer Auth & Idempotency Key ───────► [ FastAPI Endpoint ]
          │                                                                      │
          ▼                                                                      ▼
 [ Database / Redis ]   ◄─────── SQLAlchemy Async / Redis Cache ──────► [ Backend Service / Hardware ]
```

---

## Detailed Pipeline Tracing

### 1. Dashboard & Home Screen Data Pipeline
1. **UI**: `HomeScreen` (`lib/features/home/presentation/home_screen.dart`).
2. **Provider**: `dashboardProvider` (`lib/features/home/presentation/home_controller.dart`).
3. **Location**: Acquires current GPS coordinates via `LocationService.getCurrentPosition()`.
4. **Repository**: `DashboardRepositoryImpl.fetchDashboard(lat: lat, lng: lng)` (`lib/data/repositories/repository_impl.dart`).
5. **API Client**: `GET /api/v1/dashboard?lat=...&lng=...` with Bearer JWT header.
6. **FastAPI Endpoint**: `get_dashboard()` in `backend/app/api/v1/dashboard.py`.
7. **Backend Services**:
   - `WeatherService.get_weather(lat, lng)` (queries Redis cache `weather:{lat}:{lng}` or OpenWeatherMap API).
   - `NearbyHelpService.get_all_nearby_help(lat, lng)` (executes Haversine spatial SQL query across `police_stations` and `safety_zones`).
   - `_compute_safety_score(user_id, db)` (computes safety ratio from PostgreSQL `journeys`).
8. **Response**: `DashboardResponse` JSON.
9. **Flutter State**: `DashboardEntity` emitted to `dashboardProvider` → UI updates Weather, Score, Services, Contacts.

---

### 2. Route Planning & Safe Navigation Pipeline
1. **UI**: `GuardianScreen` (`lib/features/guardian/presentation/guardian_screen.dart`).
2. **Controller**: `GuardianMapController.planRouteTo(destination, destLat, destLng)` (`lib/features/guardian/presentation/guardian_map_controller.dart`).
3. **Repository**: `GuardianRepositoryImpl.evaluateRoutePlan(...)` (`lib/data/repositories/repository_impl.dart`).
4. **API Client**: `POST /api/v1/guardian/route` with origin/destination coordinates and day/night flag.
5. **FastAPI Endpoint**: `plan_safe_route()` in `backend/app/api/v1/guardian.py`.
6. **Backend Service**: `GuardianSafetyEngine.evaluate_route()`:
   - Queries Google Directions API (`MapsService.get_directions`) for primary + alternative polylines.
   - Samples polylines every 150m.
   - Cross-references 56 Chennai safety zones with day/night multipliers (19:00–06:00 IST).
   - Produces scored alternatives (`Safer Route`, `Fastest Route`, `Balanced Route`).
7. **Flutter State**: `GuardianRoutePlanEntity` rendered in `GuardianRouteComparisonCard`.
8. **Navigation Start**: User taps **Start Navigation** → `POST /api/v1/journeys/start` creates active DB journey, starts `GuardianEngine`, and opens `LiveJourneyScreen`.

---

### 3. Active Journey Real-Time Tracking & Route Deviation Pipeline
1. **UI**: `LiveJourneyScreen` (`lib/features/journey/presentation/live_journey_screen.dart`).
2. **Hardware Stream**: `LocationService.getPositionStream(highAccuracy, distanceFilter: 3m)`.
3. **Deviation Evaluation**: `RouteDeviationDetector.distanceToPolyline(currentPos, routePoints)`.
4. **Deviation Trigger**: If distance > 150m for 3 consecutive GPS samples → triggers `showSafetyConfirmationDialog` (20s countdown prompt).
5. **Heartbeat Stream**: `GuardianEngine` dispatches `POST /api/v1/guardian/heartbeat` every 30s with live GPS coordinates, battery level, and network status.
6. **Journey Completion**: User taps **Confirm Safe Arrival** → `POST /api/v1/journeys/{id}/stop` marks journey completed safely, notifies circle, and navigates home.

---

### 4. Sensor Kinematics Anomaly Pipeline
1. **Hardware Stream**: `SensorService` listening to `accelerometerEventStream()` and `gyroscopeEventStream()`.
2. **Edge Feature Window**: Rolling 50-sample buffer evaluated every 2 seconds.
3. **Anomaly Classification**:
   - Severe Fall / Drop: Peak acceleration > 25.0 m/s².
   - Violent Shake: Peak acceleration > 18.0 m/s² and rotation > 6.0 rad/s.
4. **Trigger Flow**:
   - Emits on `SensorService.anomalyStream`.
   - Sends background signal: `POST /api/v1/intelligence/motion-signal`.
   - Surfaces `showSafetyConfirmationDialog(title: "⚠ UNUSUAL MOVEMENT DETECTED")` with 20s live countdown.

---

### 5. Voice Distress Protection Pipeline
1. **Hardware Stream**: `VoiceService` initialized with Android `speech_to_text` engine after `RECORD_AUDIO` permission.
2. **Continuous Audio Loop**: 8-second listen cycles with 2-second silence detector.
3. **Distress Analysis**:
   - Local keyword filter: `help`, `emergency`, `danger`, `save me`, `call police`, `bachao`, `chhod do`.
   - Backend dispatch: `POST /api/v1/intelligence/voice-analysis` evaluated by `GeminiVoiceDistressModel`.
4. **Trigger Flow**:
   - If keyword or High/Critical urgency returned → surfaces `showSafetyConfirmationDialog(title: "🚨 VOICE EMERGENCY TRIGGER")`.
