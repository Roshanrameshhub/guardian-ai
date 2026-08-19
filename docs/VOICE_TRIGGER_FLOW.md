# Guardian AI — Voice Distress Trigger Flow

## 1. Hardware & Audio Pipeline

Guardian AI provides continuous edge-to-cloud voice monitoring through the `VoiceService` (`lib/core/services/voice_service.dart`):

1. **Permission Check**: Verifies `RECORD_AUDIO` permission at runtime before enabling microphone listeners.
2. **STT Engine Initialization**: Initializes Android on-device Speech-to-Text (`speech_to_text: ^7.0.0`).
3. **Listen Cycle**: Runs 8-second speech capture windows with 2-second silence cutoffs.

---

## 2. Multi-Tiered Distress Recognition

```
 [ Android Microphone ]
         │ (Audio Capture)
         ▼
 [ Speech-To-Text Engine ]
         │ (Transcript String)
         ▼
 [ 1. Local Edge Keyword Matcher ]
   Keywords: "help", "emergency", "danger", "save me", "call police", "bachao", "chhod do", "help me"
         │
         ├──► MATCH DETECTED ──► Emits on emergencyTriggerStream immediately
         │
         ▼
 [ 2. Cloud AI Voice Analysis ] (POST /api/v1/intelligence/voice-analysis)
         │
         ▼
 [ Backend GeminiVoiceDistressModel / RuleBasedVoiceModel ]
   - Gemini 2.5 Flash semantic analysis
   - Intensity score & distress classification (CRITICAL / HIGH / MEDIUM / LOW)
         │
         └──► HIGH / CRITICAL ──► Emits on emergencyTriggerStream
```

---

## 3. UI Reaction & Escalation

1. When `emergencyTriggerStream` emits:
2. The UI presents `showSafetyConfirmationDialog` with title `🚨 VOICE EMERGENCY TRIGGER` and the recognized distress snippet.
3. 20-second circular countdown activates.
4. User can dismiss with **[I'M SAFE]** or confirm with **[I'M IN DANGER]**.
5. Expiry or danger confirmation immediately invokes `showEmergencySosModal` to dispatch live GPS coordinates and emergency alerts to trusted contacts and authorities.
