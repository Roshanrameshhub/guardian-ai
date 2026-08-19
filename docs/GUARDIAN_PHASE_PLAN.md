# GUARDIAN AI — PHASE-BY-PHASE IMPLEMENTATION PLAN

**Date:** 2026-08-18  
**Rules:**  
- Never implement Phase N until Phase N-1 is verified.  
- After every phase:  
  1. Run `flutter analyze`  
  2. Run `flutter test`  
  3. Run backend `pytest`  
  4. Verify existing functionality has not regressed  
  5. Verify on the physical Android device  
  6. Show exactly what was changed  
  7. Show exactly what was tested  
  8. Stop and report the result before proceeding to the next phase  

---

## Phase Roadmap Overview

### Phase 0: Forensic Audit & Architecture Baseline *(Completed)*
- Full code inspection across Flutter (`lib/`, `android/`, `pubspec.yaml`) and FastAPI (`backend/app/`, `backend/tests/`).
- Documented `docs/GUARDIAN_CURRENT_ARCHITECTURE.md` and `docs/GUARDIAN_PHASE_PLAN.md`.

---

### Phase 1: Network + Dashboard + Auth Truth
- **Goal:** Robust LAN networking, structured error categorization, and Google OAuth diagnosis.
- **Tasks:**
  1. Configurable `API_HOST` resolution in `api_config.dart` with visible diagnostics endpoint status.
  2. Differentiate `NETWORK_ERROR`, `AUTH_ERROR`, `PERMISSION_ERROR`, `SERVER_ERROR`, `TIMEOUT` in `ApiClient` and `home_screen.dart`.
  3. Prevent false "Session expired" banners when network connection fails.
  4. Google OAuth: Document Google Cloud SHA-1 registration requirement and fix ApiException 10 handling.

---

### Phase 2: Sensor Foundation (`SafetySensorManager`)
- **Goal:** Centralized sensor state management without direct coupling to SOS triggers.
- **Tasks:**
  1. Create `SafetySensorManager` managing GPS, Accelerometer, Gyroscope, Voice, and Device Motion State.
  2. Expose `status`, `permission`, `availability`, `lastUpdate`, `rawValues`, `filteredValues`, `confidence`, and `eventClassification` for each sensor.

---

### Phase 3: Multi-Stage Motion & Fall Detection
- **Goal:** Eliminate false positive fall/shake alerts from normal device handling (picking up, placing on table).
- **Tasks:**
  1. Multi-stage kinematic pipeline: (1) Anomaly -> (2) Acceleration Magnitude -> (3) Gyroscope Rotation -> (4) Temporal Pattern -> (5) Post-Impact Immobility -> (6) GPS state -> (7) Confidence calculation.
  2. Suspected Fall prompt with 20s countdown and cancellation options ("I'M OK", "CANCEL", "SEND SOS"). No direct automatic SOS on single sensor peak.

---

### Phase 4: Real Voice Distress Detection Pipeline
- **Goal:** Continuous microphone listening with high-confidence keyword & acoustic distress analysis.
- **Tasks:**
  1. Distinguish between simulated test events and real microphone audio events.
  2. Recognize distress phrases (`help`, `help me`, `danger`, `emergency`, `save me`, `someone help`, `guardian`, `call police`).
  3. Require phrase confidence + context before dispatching to Risk Engine.

---

### Phase 5: Android Background Safety & Foreground Services
- **Goal:** Ensure safety events trigger even when the screen is locked or app is minimized.
- **Tasks:**
  1. Foreground service notification with live status indicators (`Guardian Active`, GPS, Motion, Gyro, Voice, Risk Engine).
  2. Contextual permission requests and honest degraded status if permissions are revoked.

---

### Phase 6 & 7: Central Guardian Risk Engine & Contextual Scoring
- **Goal:** Centralize risk calculation across all independent signals with transparent mathematical weighting.
- **Tasks:**
  1. Create `GuardianRiskEngine` scoring [0–100]: Low (0–24), Guarded (25–49), Elevated (50–69), High (70–84), Critical (85–100).
  2. Contextual factors: Location crime dataset, Route safety score, Route deviation, Weather conditions, Timing/ETA delay, Motion anomalies, Fall candidate pattern, Voice distress, Crowd/Metro proximity, Emergency services availability.

---

### Phase 8: Risk Score UI & Explainability
- **Goal:** Enable user to see live breakdown of why the safety score changed.
- **Tasks:**
  1. Live component breakdown (Location Risk, Route Risk, Weather Risk, Motion Risk, Voice Risk, Timing Risk, Deviation Risk).
  2. Real-time change banners explaining risk deltas (e.g., `"Route deviation detected +12"`, `"Distress voice detected +30"`).

---

### Phase 9, 10, 11: Journey Watchdog, Real Route Deviation & Navigation Map
- **Goal:** End-to-end journey navigation with real searched destinations (e.g. Tambaram) and Google Directions polylines.
- **Tasks:**
  1. Dynamic search preserving exact chosen location without silent fallback.
  2. Render alternative routes (Safer, Fastest, Balanced) with Google Directions / Routes API.
  3. Live corridor deviation alerts with actions: `RETURN TO ROUTE`, `CONTINUE ANYWAY`, `RECALCULATE SAFER ROUTE`.

---

### Phase 12: Safe Arrival & Delay Risk Watchdog
- **Goal:** Gradual delay escalation and geofenced safe arrival confirmation.
- **Tasks:**
  1. Compare ETA vs actual progress; add incremental risk for unexplained stops.
  2. Arrival detection (< 80m radius) prompting: `"Have you arrived safely?"` -> `YES, I'M SAFE` / `NOT YET`.

---

### Phase 13, 14, 15, 16: Multi-Signal SOS Escalation, Policy, Cooldown & Cancellation
- **Goal:** Automatic SOS requiring multi-signal critical conditions with cooldown and zero-penalty cancellation.
- **Tasks:**
  1. Create `RiskPolicy` requiring at least 2 independent critical signals OR high-confidence fall + no response before auto-escalation.
  2. Configurable 5-minute SOS cooldown preventing loop storms.
  3. Full false-positive cancellation feedback loop recording user cancellations safely.

---

### Phase 17 & 18: Truthful External Notifications & Trusted Contact Delivery Lifecycle
- **Goal:** External notifications via FCM/Local notifications with truthful delivery statuses.
- **Tasks:**
  1. Notifications for Fall Detected, Voice Distress, Route Deviation, High Risk, SOS Sent/Failed.
  2. Per-contact delivery lifecycle states: `QUEUED`, `NOTIFICATION_REQUESTED`, `PROVIDER_ACCEPTED`, `DELIVERED`, `FAILED`.

---

### Phase 19, 20, 21: Guardian Live Status UI, Truthful Diagnostics Workbench & Contextual Permissions
- **Goal:** Comprehensive subsystem indicators and distinct Real Hardware vs Simulation tests.
- **Tasks:**
  1. Live status chips: `ACTIVE`, `INACTIVE`, `PERMISSION_REQUIRED`, `ERROR`, `DEGRADED`.
  2. Diagnostics screen: Real hardware testing for Shake, Fall pipeline, Microphone STT, GPS lock, Risk Engine, FCM notifications.
  3. Contextual on-demand permission prompts.

---

### Phase 22, 23, 24, 25: Explainable Safety Score, End-to-End Scenarios, Regression Suite & Documentation
- **Goal:** Replace static baseline values, test 15 real-world scenarios, and document runtime operations.
- **Tasks:**
  1. Create `docs/GUARDIAN_REAL_FEATURE_MATRIX.md`, `docs/GUARDIAN_RISK_ENGINE.md`, `docs/GUARDIAN_TESTING_GUIDE.md`.
  2. Validate full regression test suite (Flutter analyze, Flutter test, pytest).
