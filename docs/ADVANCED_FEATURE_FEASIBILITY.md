# Guardian AI — Advanced Feature Feasibility Gate

> Comprehensive evaluation and classification of the Second-Layer Safety Intelligence Feature Set.

---

## 1. Feasibility Evaluation Matrix

| Feature | Code | Feasibility | Implementation Strategy | Open Source / Native | Complexity | Decision |
|---|---|---|---|---|---|---|
| **Motion-Based Distress Detection** | A | High | Windowed peak acceleration, rotation, sudden stop detector on mobile → derived event to backend | Yes (Native Accelerometer & Gyroscope) | Low-Medium | **IMPLEMENT NOW** |
| **Voice Distress Detection** | B | High | Lightweight keyword detection + repetition + energy/pitch acoustic analyzer + pluggable model interface | Yes (Python stdlib / numpy / librosa hook) | Medium | **IMPLEMENT LIGHTWEIGHT VERSION** |
| **Multimodal Risk Fusion** | C | High | Deterministic weighted multi-signal engine (`LOW`, `MEDIUM`, `HIGH`, `CRITICAL`) with transparent explainability | Yes (Rule-based deterministic engine) | Medium | **IMPLEMENT NOW** |
| **False Positive Analysis** | D | High | Logging user dismissals ("I'm Safe"), false alarm analytics, confidence calibration without alert suppression | Yes (PostgreSQL + Async Service) | Medium | **IMPLEMENT NOW** |
| **Safe Arrival Detection** | E | High | Distance threshold geo-calculation to destination coordinates + notification dispatch | Yes (Haversine distance math) | Low | **IMPLEMENT NOW** |
| **Journey Deviation Detection** | F | High | Polyline cross-track distance corridor check (`NORMAL`, `MINOR`, `SIGNIFICANT`, `CONFIRMED`, `EMERGENCY`) | Yes (Geometric vector analysis) | Medium | **IMPLEMENT NOW** |
| **Safety Check-In System** | G | High | Timed countdown sessions with start, reminder, confirm, cancel, and watchdog escalation | Yes (PostgreSQL + Watchdog Worker) | Low-Medium | **IMPLEMENT NOW** |
| **Shake-to-SOS** | H | High | Multi-shake acceleration spike threshold detector triggering SOS API with source tag | Yes (Local sensor windowing) | Low | **IMPLEMENT NOW** |
| **Phone Drop Detection** | I | High | Freefall/impact acceleration spike followed by sudden angular stabilization | Yes (Local sensor classifier) | Low-Medium | **IMPLEMENT NOW** |
| **Personalized Motion Baseline** | J | High | Aggregate statistics (walking/running/vehicle normal ranges) stored in DB to modulate confidence | Yes (DB Aggregate profile) | Medium | **IMPLEMENT NOW** |
| **Live Location Sharing** | K | High | Secure temporary token-based location sessions with automatic expiration | Yes (UUID + Expiry Tokens) | Low-Medium | **IMPLEMENT NOW** |
| **Offline Safety Event Sync** | L | High | Idempotent batch ingestion endpoint (`POST /api/v1/sync/events`) for offline queues | Yes (UUID Idempotency deduplication) | Medium | **IMPLEMENT NOW** |
| **Emergency Escalation Logic** | M | High | Configurable multi-tier escalation pipeline with audit trail for each stage | Yes (State-machine service) | Medium | **IMPLEMENT NOW** |
| **AI Safety Insights** | N | High | Evidence-based pattern summaries derived strictly from user journey & safety event records | Yes (Aggregated SQL + ContextBuilder) | Low-Medium | **IMPLEMENT NOW** |
| **Personalized Safety Recommendations** | O | High | Deterministic rule engine recommending proactive actions based on historical patterns | Yes (Deterministic pattern matcher) | Low | **IMPLEMENT NOW** |
| **AI Conversation Context** | P | High | Privacy-preserving context builder extracting non-identifying aggregated statistics | Yes (ContextBuilder abstraction) | Low-Medium | **IMPLEMENT NOW** |
| **Privacy-Aware AI Processing** | Q | High | Zero raw audio/GPS persistence without user consent; minimal aggregation | Yes (Architecture policy) | Low | **IMPLEMENT NOW** |

---

## 2. Detailed Technical Decisions & Rationale

### A. Motion Distress, Shake, and Phone Drop (A, H, I, J)
- **Architecture:** Raw continuous sensor streaming to the cloud drains battery and creates network overhead. Instead, sensor windows are processed locally (or submitted as compact feature vectors) into `MotionSignalService`.
- **Classification Rules:**
  - *Shake-to-SOS:* 3+ rapid acceleration directional reversals within 1.5 seconds above 2.5g.
  - *Phone Drop:* Sudden low-g freefall phase (<0.3g) followed by high-impact spike (>3.0g) and rotational stabilization.
  - *Motion Anomaly:* Sustained high acceleration + rotation variance during Guardian Mode.
- **Personalized Baseline:** Maintains typical motion variance for the user. If the user frequently runs or works out, confidence of motion-only distress is adjusted down by 15-20% without suppressing critical multi-signal alerts.

### B. Voice Distress Detection (B)
- **Feasibility Rationale:** Heavy neural speech-emotion models (e.g. 500MB+ Wav2Vec2 fine-tunes) require heavy GPU/CPU overhead for realtime audio streaming. 
- **Solution — Modular V1 Architecture:**
  - `keyword_detector.py`: Scans transcripts/text for distress lexicons ("help", "emergency", "stop", "someone please") with multi-language and repetition weighting.
  - `acoustic_analyzer.py`: Analyzes audio window metrics: RMS energy (loudness/shouting), pitch inflection proxy, speaking rate, and breath/pause indicators.
  - `model_provider.py`: Clean `VoiceDistressModel` interface allowing plug-and-play addition of local ONNX or PyTorch emotion models in the future without changing the service interface.
- **Privacy Rule:** Audio snippets are ephemeral in memory during feature extraction; no raw audio is saved unless emergency recording is explicitly triggered with user authorization.

### C. Multimodal Risk Fusion Engine (C, M)
- **Deterministic Weighted Algorithm:**
  $$\text{Risk} = w_{\text{voice}} S_{\text{voice}} + w_{\text{motion}} S_{\text{motion}} + w_{\text{dev}} S_{\text{dev}} + w_{\text{guardian}} S_{\text{guardian}} + w_{\text{env}} S_{\text{env}}$$
- **Tiers:**
  - `LOW` ($< 0.40$): Passive monitoring; no user disruption.
  - `MEDIUM` ($0.40 - 0.69$): Non-intrusive prompt ("Are you okay?").
  - `HIGH` ($0.70 - 0.85$): Emergency confirmation countdown + prepare trusted contact alert.
  - `CRITICAL` ($> 0.85$): Immediate trigger of configured emergency protocol.

### D. False Positive Learning (D)
- Users can dismiss alerts by confirming "I'm Safe" or tagging "False Alarm".
- Records outcome in `FalsePositiveRecord`.
- Slightly tunes personal motion sensitivity while strictly preventing total alert suppression.

### E. Safe Arrival & Journey Deviation (E, F)
- Safe arrival uses 50-meter geo-fencing against journey destination coordinates.
- Route deviation calculates perpendicular distance from the planned polyline. Deviations are categorized into `NORMAL` (<50m), `MINOR` (50-200m), `SIGNIFICANT` (200-500m), `CONFIRMED` (>500m), and `EMERGENCY` (significant deviation + sudden stop or distress signal).

### F. Safety Check-Ins (G)
- Timed safety sessions (e.g. 15, 30, 60 minutes) for solo activities.
- Background watchdog checks for expired check-ins and prompts user or escalates to trusted contacts upon grace period expiration.
