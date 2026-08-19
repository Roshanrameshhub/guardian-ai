# Guardian AI — Backend Master Feature Map

> Classification of all features for implementation priority

---

## Group A — EXISTING + MOCKED (Must convert to real backend)

These features have complete Flutter UI and repository interfaces.
All data is currently mocked. **Priority: Highest.**

| Feature | Flutter Status | Mock Source | Backend Action |
|---|---|---|---|
| Auth Login | ✅ Screen + Controller | `mock_access` token | Implement JWT auth |
| Auth Register | ✅ Screen + Controller | `mock_access` token | Implement registration |
| Auth Logout | ✅ Controller | No-op | Invalidate refresh token |
| Dashboard | ✅ Screen + FutureProvider | `MockData.dashboard` | Aggregation endpoint |
| User Profile | ✅ Screen + FutureProvider | `MockData.user` | Profile CRUD |
| Trusted Contacts | ✅ Widget + Repository | `MockData.contacts` | Contacts CRUD |
| Journey List | ✅ Activity Screen | `MockData.journeys` | Journey persistence |
| Journey Start | ✅ HomeController | `MockData.recentJourney` | Journey engine |
| Guardian Status | ✅ Screen + FutureProvider | `MockData.guardian` | Guardian session |
| Guardian Start | ✅ Toggle in UI | mock delay | Session management |
| Guardian Stop | ✅ Toggle in UI | inline mock | Session management |
| Safe Routes | ✅ Map Screen | `MockData.mapRoute` | Maps provider |
| Area Safety | ✅ Map Screen | `MockData.areaSafety` | Safety scoring |
| Activity Feed | ✅ Activity Screen | `MockData.activity` | Activity aggregation |
| Notifications | ✅ Notifications Screen | `MockData.notifications` | Notifications CRUD |
| Achievements | ✅ Activity Screen section | `MockData.achievements` | Achievement engine |
| Weather | ✅ Dashboard widget | `MockData.weather` | Weather provider |
| Nearby Services | ✅ Dashboard widget | `MockData.nearbyServices` | Services provider |
| Emergency SOS | ✅ Home + Guardian | `"notified (mock)"` | Emergency engine |
| Fake Call | ✅ Home quick actions | `MockData.fakeCall` | Tools persistence |
| Fake Message | ✅ Home quick actions | `MockData.fakeMessage` | Tools persistence |

---

## Group B — EXISTING + PARTIALLY IMPLEMENTED (Complete without redesign)

| Feature | Flutter Status | What's Missing | Action |
|---|---|---|---|
| Forgot Password | ✅ Auth controller method | Backend not implemented | Add password reset flow |
| Profile Update | ✅ `updateProfile()` method exists | Ignores API response | Wire real PATCH response |
| Add Contact | ✅ `addContact()` method exists | No-op in repo | Wire real POST |
| Stop Journey | ✅ `stopJourney()` method exists | No-op | Wire real stop endpoint |
| SOS Trigger Source | ✅ SosRequest has lat/lng | No trigger_source field | Add `trigger_source` to backend |
| Guardian Heartbeat | ❌ No client heartbeat timer | Heartbeat API missing | Add heartbeat endpoint + client timer |

---

## Group C — NEW FEATURES (Add backend support, additive only)

These are required by the product specification but have **no existing Flutter UI** beyond what's already present. The backend should be designed to support them; minimal Flutter integration hooks added.

| Feature | Flutter Exists | Backend Required | Realtime | Priority |
|---|---|---|---|---|
| Refresh Token Rotation | ❌ | ✅ `POST /auth/refresh` | ❌ | High |
| JWT Token Storage | ❌ | ✅ Server-side validation | ❌ | High |
| Guardian Watchdog | ❌ | ✅ Background worker | ❌ | High |
| Guardian Heartbeat Client | ❌ | ✅ `POST /guardian/{id}/heartbeat` | ❌ | High |
| Live Location Sharing | ❌ | ✅ Location endpoints | ✅ WS | Medium |
| Safe Arrival Detection | ❌ | ✅ Distance threshold check | ✅ WS | Medium |
| Journey Deviation Detection | ❌ | ✅ Route comparison service | ✅ WS | Medium |
| Safety Check-ins | ❌ | ✅ Check-in endpoints + worker | ❌ | Medium |
| Device Management | ❌ | ✅ `POST /devices` | ❌ | Medium |
| Offline Event Sync | ❌ | ✅ `POST /sync/events` | ❌ | Medium |
| AI Safety Assistant | ❌ | ✅ AI router + provider | ❌ | Medium |
| AI Safety Insights | ❌ | ✅ Insight generation service | ❌ | Medium |
| AI Recommendations | ❌ | ✅ Recommendation service | ❌ | Low |
| Emergency Escalation Levels | ❌ | ✅ Configurable escalation | ❌ | Low |
| Emergency Recording Metadata | ❌ | ✅ Metadata storage | ❌ | Low |
| Subscription Architecture | ❌ | ✅ Subscription model | ❌ | Low |
| Audit Logs | ❌ | ✅ audit_logs table | ❌ | Low |

---

## Group D — PLATFORM-LIMITED FEATURES (Backend support only)

The backend provides the infrastructure; the mobile OS controls the actual behavior.

| Feature | Platform Restriction | Backend Role | What We Will NOT Do |
|---|---|---|---|
| Voice SOS Trigger | iOS/Android permission required | Accept `trigger_source: "voice"` in SOS request | No server-side microphone |
| Always-on listening | OS background restriction | N/A | No surveillance server |
| Emergency camera recording | App must request camera permission | Store recording metadata + secure reference | No secret activation |
| Forced phone calls | OS controls call UI | Backend provides fake_call config | No forced call initiation |
| Forced SMS | OS controls messaging | Backend provides fake_message config | No automatic SMS sending |
| Police dispatch | Requires legal integration | Configurable escalation policy; user consent required | No automatic dispatch |
| Guaranteed route safety | No data source is perfect | Return score + confidence + data availability | No false certainty |

---

## Implementation Priority

```
PHASE 2: Backend Foundation (FastAPI + DB + Redis)
    ↓
PHASE 3: Auth + JWT (Group A: auth)
    ↓
PHASE 4: Core Data (Group A: profile, contacts, dashboard)
    ↓
PHASE 5: Safety Core (Group A: journeys, guardian, map, weather, services)
    ↓
PHASE 6: Emergency (Group A: SOS + Group B: heartbeat + Group C: watchdog)
    ↓
PHASE 7: Supporting (Group A: activity, notifications, achievements, tools)
    ↓
PHASE 8: AI Layer (Group C: AI assistant, insights, recommendations)
    ↓
PHASE 9: Flutter Integration (remove 21 mock production paths)
    ↓
PHASE 10: Documentation + Status Matrix
```

---

## Backend Technology Decisions

| Component | Technology | Reason |
|---|---|---|
| Framework | FastAPI | Async, OpenAPI-first, Python 3.12 |
| Database | PostgreSQL + asyncpg | Relational, ACID, UUID support |
| ORM | SQLAlchemy 2.x (async) | Type-safe, mature |
| Migrations | Alembic | Industry standard for SQLAlchemy |
| Cache/State | Redis | Heartbeat TTL, rate limiting, weather cache |
| Auth | JWT (HS256) + Argon2 | Industry standard |
| WebSockets | FastAPI native | Guardian realtime |
| Background Jobs | asyncio tasks + APScheduler | Watchdog, notification delivery |
| AI Provider | OpenAI (abstracted) | Swappable via AIProvider interface |
| Architecture | Modular Monolith | Simple deployment, no Kubernetes overhead |

---

## External Service Provider Abstractions

```python
class MapsProvider(ABC):
    async def get_route(self, origin, destination) -> RouteResult: ...

class WeatherProvider(ABC):
    async def get_current(self, lat, lng) -> WeatherResult: ...

class NearbyServicesProvider(ABC):
    async def get_nearby(self, lat, lng, radius) -> List[ServiceResult]: ...

class AIProvider(ABC):
    async def chat(self, messages, context) -> str: ...

class PushProvider(ABC):
    async def send(self, token, title, body, data) -> bool: ...

class SMSProvider(ABC):
    async def send(self, phone, message) -> bool: ...
```

All providers have a `MockProvider` fallback for development without credentials.
Production providers configured via environment variables.

---

## API Endpoint Map (matching Flutter `ApiConstants`)

| Flutter Constant | Path | Method | Backend Module |
|---|---|---|---|
| `login` | `/auth/login` | POST | auth.py |
| `register` | `/auth/register` | POST | auth.py |
| `logout` | `/auth/logout` | POST | auth.py |
| `refreshToken` | `/auth/refresh` | POST | auth.py |
| `forgotPassword` | `/auth/forgot-password` | POST | auth.py |
| `profile` | `/profile` | GET | profile.py |
| `updateProfile` | `/profile` | PATCH | profile.py |
| `contacts` | `/contacts` | GET, POST | contacts.py |
| `dashboard` | `/dashboard` | GET | dashboard.py |
| `safetyScore` | `/safety/score` | GET | safety.py |
| `weather` | `/weather` | GET | weather.py |
| `nearbyServices` | `/services/nearby` | GET | services.py |
| `journey` | `/journey/{id}` | GET | journeys.py |
| `startJourney` | `/journey/start` | POST | journeys.py |
| `stopJourney` | `/journey/stop/{id}` | POST | journeys.py |
| `journeys` | `/journeys` | GET | journeys.py |
| `route` | `/map/route` | GET | routes.py |
| `areaSafety` | `/map/area-safety` | GET | safety.py |
| `startGuardian` | `/guardian/start` | POST | guardian.py |
| `stopGuardian` | `/guardian/stop` | POST | guardian.py |
| `guardianStatus` | `/guardian/status` | GET | guardian.py |
| `activity` | `/activity` | GET | activity.py |
| `notifications` | `/notifications` | GET | notifications.py |
| `statistics` | `/statistics` | GET | activity.py |
| `achievements` | `/achievements` | GET | achievements.py |
| `safetyEvents` | `/safety/events` | GET | safety.py |
| `fakeCall` | `/tools/fake-call` | POST, GET | fake_tools.py |
| `fakeMessage` | `/tools/fake-message` | POST, GET | fake_tools.py |
| `sos` | `/emergency/sos` | POST | emergency.py |
| *(new)* | `/guardian/{id}/heartbeat` | POST | guardian.py |
| *(new)* | `/guardian/{id}/location` | POST | guardian.py |
| *(new)* | `/emergency/{id}/cancel` | POST | emergency.py |
| *(new)* | `/location/share` | POST | location.py |
| *(new)* | `/ai/chat` | POST | ai.py |
| *(new)* | `/ai/insights` | GET | ai.py |
| *(new)* | `/devices` | POST | devices.py |
| *(new)* | `/sync/events` | POST | sync.py |
| *(new)* | `/health` | GET | main.py |
| *(new)* | `/ready` | GET | main.py |
