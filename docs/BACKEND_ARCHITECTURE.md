# Guardian AI — Production Backend Architecture

> Technical specification for the Guardian AI FastAPI + PostgreSQL + Redis backend.

---

## 1. System Overview

Guardian AI is an AI-powered personal safety platform designed to provide proactive trip monitoring, automated emergency workflows, multimodal risk fusion, and location-aware safety intelligence.

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter Mobile App                      │
│   (Material 3 / Riverpod / GoRouter / HTTP Client / Sensors) │
└──────────────────────────────┬──────────────────────────────┘
                               │ HTTPS / JSON / JWT
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                   FastAPI Application (v1)                  │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Middlewares: Request ID, CORS, Error Handling, Logging │ │
│  └────────────────────────────┬───────────────────────────┘ │
│                               │                             │
│  ┌───────────────┬────────────┴───┬──────────────┬────────┐ │
│  │ Auth & Users  │ Guardian Core  │ Emergency SOS│ Map/AI │ │
│  ├───────────────┼────────────────┼──────────────┼────────┤ │
│  │ Risk Fusion   │ Voice Distress │ Motion Signal│Check-In│ │
│  └───────┬───────┴────────┬───────┴──────┬───────┴────┬───┘ │
└──────────┼────────────────┼──────────────┼────────────┼─────┘
           │                │              │            │
           ▼                ▼              ▼            ▼
┌──────────────────┐ ┌──────────────┐ ┌─────────┐ ┌───────────┐
│ PostgreSQL 16    │ │ Redis Cache  │ │ External│ │ OpenAI /  │
│ (Async SQLAlchemy│ │ (Sessions,   │ │ (Twilio,│ │ Maps /    │
│  + Alembic)      │ │  Rate-limit) │ │  FCM)   │ │ Weather   │
└──────────────────┘ └──────────────┘ └─────────┘ └───────────┘
```

---

## 2. API Endpoints Map (Prefix: `/api/v1`)

| Module | Method | Path | Description |
|---|---|---|---|
| **Health** | GET | `/health` | Liveness probe |
| | GET | `/ready` | Readiness probe (DB + Providers) |
| **Auth** | POST | `/auth/register` | Create new account & issue tokens |
| | POST | `/auth/login` | Email/Password login |
| | POST | `/auth/refresh` | Refresh token rotation |
| | POST | `/auth/logout` | Revoke active refresh tokens |
| | POST | `/auth/forgot-password`| Password reset request |
| **Profile** | GET | `/profile` | Fetch user profile & safety stats |
| | PATCH | `/profile` | Update profile fields |
| **Contacts** | GET | `/contacts` | List trusted circle contacts |
| | POST | `/contacts` | Add a new trusted contact |
| | GET | `/contacts/{id}` | Get contact details |
| | PATCH | `/contacts/{id}` | Update contact |
| | DELETE | `/contacts/{id}` | Delete contact |
| **Dashboard** | GET | `/dashboard` | Aggregated dashboard state |
| **Journeys** | GET | `/journeys` | Fetch journey history |
| | GET | `/journey/{id}` | Get specific journey |
| | POST | `/journey/start` | Start tracking a journey |
| | POST | `/journey/stop/{id}` | Finish/stop journey |
| | DELETE | `/journey/{id}` | Remove journey record |
| **Guardian** | GET | `/guardian/status` | Active guardian state |
| | POST | `/guardian/start` | Activate guardian mode |
| | POST | `/guardian/stop` | Deactivate guardian mode |
| | POST | `/guardian/{id}/heartbeat`| Client device heartbeat (30s) |
| | POST | `/guardian/{id}/location` | Live GPS location update |
| **Emergency** | POST | `/emergency/sos` | Trigger SOS alert with delivery |
| | GET | `/emergency/{id}` | Check emergency status |
| | POST | `/emergency/{id}/cancel` | Cancel active emergency |
| **Map & Routes**| GET | `/map/route` | Route calculation & POIs |
| | GET | `/map/area-safety` | Neighborhood safety scores |
| **Activity** | GET | `/activity` | Aggregated activity feed |
| **Notifications**| GET | `/notifications` | List user notifications |
| | PATCH | `/notifications/{id}/read`| Mark read |
| | POST | `/notifications/read-all`| Mark all read |
| | DELETE| `/notifications/{id}` | Delete notification |
| **Achievements**| GET | `/achievements` | Badges & unlock progress |
| **Tools** | GET/POST| `/tools/fake-call` | Configure & trigger fake call |
| | GET/POST| `/tools/fake-message`| Configure & trigger fake SMS |
| **AI Layer** | POST | `/ai/chat` | AI Safety Assistant chat |
| | GET | `/ai/conversations`| Chat history list |
| | GET | `/ai/insights` | Evidence-based insights |
| **Intelligence**| POST | `/signals/motion` | Motion sensor anomaly & drop classifier |
| | POST | `/signals/voice` | Acoustic distress & keyword analyzer |
| | POST | `/risk/fuse` | Multimodal weighted risk fusion engine |
| | POST | `/safety/false-positive`| Feedback logging & baseline calibrator |
| | POST | `/safety/safe-arrival` | Destination threshold geofence check |
| | POST | `/safety/route-deviation`| Corridors cross-track distance analyzer |
| | POST | `/checkins/start` | Start timed safety check-in countdown |
| | POST | `/checkins/{id}/confirm`| Confirm safety check-in |
| | POST | `/checkins/{id}/cancel` | Cancel safety check-in |
| | GET | `/checkins` | List safety check-in records |
| | POST | `/sync/events` | Idempotent offline event batch ingestion |
| | GET | `/safety/recommendations`| Personalized safety suggestions |
| | POST | `/location/share` | Secure temporary live location session |

---

## 3. Second-Layer Intelligence Engine

### A. Multimodal Risk Fusion Engine
Deterministic weighted algorithm:
$$\text{RiskScore} = \sum w_i S_i \times C_i \times \text{Modifiers}$$

- **Signal Weights:** Voice Distress ($0.35$), Motion/Impact ($0.20$), Phone Drop ($0.25$), Route Deviation ($0.25$), Shake ($0.20$), Missed Check-in ($0.30$).
- **Synergy Multiplier:** $1.30\times$ if $\ge 2$ high-severity signals occur simultaneously.
- **Normalized Tiers:**
  - `LOW` ($< 0.35$): Passive background monitoring.
  - `MEDIUM` ($0.35 - 0.59$): In-app "Are you okay?" prompt.
  - `HIGH` ($0.60 - 0.79$): Emergency confirmation countdown + prepare trusted contact alert.
  - `CRITICAL` ($\ge 0.80$): Immediate trigger of configured emergency protocol.

### B. Voice Distress Architecture
- **Keyword Detection:** Multi-language lexicons for critical phrases ("help me", "emergency", "stop", "save me") + repetition tracking.
- **Acoustic Analyzer:** Evaluates RMS loudness energy, pitch variance instability, and speech cadence bursts.
- **Modular Provider Interface:** `VoiceDistressModel` allows plugging in ONNX or local ML models without code refactoring.

### C. False Positive Calibration & Baseline
- User confirmations ("I'm Safe") log feedback into `FalsePositiveRecord`.
- Slightly dampens personal motion sensitivity ($0.95\times$) for active users without suppressing multi-signal emergency alerts.

---

## 4. Database Schema

1. `users` & `user_profiles` — Identity, subscription, safety shield
2. `refresh_tokens` — SHA-256 hashed rotating refresh tokens
3. `trusted_contacts` — Trusted circle configuration
4. `journeys`, `journey_locations`, `journey_events` — Trip lifecycle
5. `guardian_sessions` — Active monitoring sessions and heartbeats
6. `emergency_events`, `emergency_notifications` — SOS execution and delivery logs
7. `notifications`, `device_tokens` — Alerts and FCM device bindings
8. `safety_events`, `safety_area_scores` — Local safety registry
9. `achievements`, `user_achievements` — Gamification milestones
10. `fake_calls`, `fake_messages` — De-escalation configurations
11. `ai_conversations`, `ai_messages` — Private AI chats
12. `weather_cache`, `nearby_services_cache` — Geo-cache
13. `motion_anomaly_events`, `personal_motion_profiles` — Motion telemetry and baseline
14. `voice_distress_events` — Vocal distress scores and matched keywords
15. `risk_assessments` — Fused multimodal risk assessments and audit trail
16. `false_positive_records` — User dismissal logs and learning weights
17. `safety_check_ins` — Timed solo check-ins with expiration tracker
18. `location_share_sessions` — Secure temporary live sharing tokens
19. `sync_records` — Offline batch ingestion idempotency records
