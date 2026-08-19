# Guardian AI — Frontend & Backend Integration Status

> Comprehensive verification report of the end-to-end integration between Flutter and FastAPI.

---

## 1. System Integration Verification

```text
Flutter Mobile Client (Material 3 / Riverpod)
     │
     ├── DTO Serialization (lib/data/dto/api_dto.dart)
     ├── API Routes (lib/core/constants/api_constants.dart)
     └── Repository Impl (lib/data/repositories/repository_impl.dart)
          │
          ▼ [HTTPS JSON Requests]
FastAPI Application (/api/v1/*)
     │
     ├── Auth & Profiles (auth.py, profile.py)
     ├── Journeys & Map (journeys.py, routes.py)
     ├── Guardian & SOS (guardian.py, emergency.py)
     ├── Activity & Notifications (activity.py, notifications.py)
     ├── AI Safety Assistant (ai.py)
     └── Safety Intelligence (intelligence.py)
          │
          ▼ [Async SQLAlchemy 2.x & Asyncpg]
PostgreSQL 16 & Redis 7
```

---

## 2. End-to-End Flow Audits

### A. Authentication & Session Security
- **Endpoints:** `POST /api/v1/auth/register`, `POST /api/v1/auth/login`, `POST /api/v1/auth/refresh`, `POST /api/v1/auth/logout`.
- **Flow:** User credentials hashed via Argon2id. Client stores access & refresh tokens in secure session. Rotating refresh tokens are tracked via SHA-256 hashes in database.

### B. Guardian Mode & Real-Time Watchdog
- **Endpoints:** `POST /api/v1/guardian/start`, `POST /api/v1/guardian/stop`, `POST /api/v1/guardian/{id}/heartbeat`.
- **Flow:** Starts active monitoring session. Heartbeat is emitted by mobile client every 30s. Background watchdog marks session as stale if heartbeats stop for >120s, generating in-app alerts and informational notifications to trusted contacts.

### C. Multimodal Risk Fusion & Signals
- **Endpoints:** `POST /api/v1/signals/motion`, `POST /api/v1/signals/voice`, `POST /api/v1/risk/fuse`.
- **Flow:** Mobile detects motion anomalies / voice distress locally and sends compact descriptors. Risk fusion engine performs weighted deterministic evaluation into normalized tiers (`LOW`, `MEDIUM`, `HIGH`, `CRITICAL`) with transparent explainability.

### D. Safety Check-Ins & Automated Escalation
- **Endpoints:** `POST /api/v1/checkins/start`, `POST /api/v1/checkins/{id}/confirm`, `POST /api/v1/checkins/{id}/cancel`, `GET /api/v1/checkins`.
- **Flow:** User starts timed check-in for solo activities. User can confirm or cancel at any time. If timer elapses without response, watchdog generates a missed check-in safety event.

### E. Safe Arrival & Journey Deviation
- **Endpoints:** `POST /api/v1/safety/safe-arrival`, `POST /api/v1/safety/route-deviation`.
- **Flow:** Geofence checks destination coordinates within 50m threshold to confirm safe trip completion. Cross-track vector distance evaluates deviations from scheduled route corridors.

### F. Offline Event Sync
- **Endpoints:** `POST /api/v1/sync/events`.
- **Flow:** Mobile device queues safety events while network connectivity is unavailable. When reconnected, events are flushed in batch with idempotency key deduplication.

---

## 3. Preservation of Flutter Architecture

1. **Material 3 Design & Glassmorphism:** All existing screens, widgets, pink/purple accent palettes, and animations remain untouched.
2. **Riverpod State Management:** StateNotifier providers and FutureProviders seamlessly receive live DTO data from repository implementations.
3. **Demo / Preview Mode:** Setting `ApiConstants.baseUrl = ''` enables instant zero-config UI preview with safe mock data. Supplying a live URL (`http://10.0.2.2:8000/api/v1` or production host) seamlessly connects to live backend databases.
