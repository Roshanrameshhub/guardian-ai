# Guardian AI — SOS Delivery & Multi-Channel Pipeline

## 1. High-Priority Emergency Pipeline

When an SOS event is triggered (manually, via fall/shake anomaly, route deviation timeout, or voice distress):

```
 [ SOS Triggered ] (Flutter App)
         │
         ▼
 [ 1. High-Precision GPS Acquisition ]
   - LocationService gets fresh coordinates within 3 seconds
   - Generates live Google Maps pin link: https://maps.google.com/?q={lat},{lng}
         │
         ▼
 [ 2. Backend SOS Dispatch ] (POST /api/v1/emergency/sos)
   Payload: { lat, lng, trigger_source, battery_pct, notes }
         │
         ▼
 [ 3. Backend Emergency Service ] (backend/app/services/emergency_service.py)
   - Fetches user's configured Trusted Contacts from PostgreSQL
   - Formats emergency SMS & push notification message
         │
         ├─────────────────────────────────────────┐
         ▼                                         ▼
 [ 4. Twilio SMS Pipeline ]              [ 5. Firebase Cloud Messaging (FCM v1) ]
   - Reads TWILIO_ACCOUNT_SID,             - Uses Google Firebase Admin SDK
     TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER   (credentials.Certificate)
   - Validates E.164 phone format          - Sends FCM HTTP v1 push notifications
   - Sends real SMS to each contact          to contact device tokens:
   - Records delivery SID & status           firebase_admin.messaging.send(...)
         │                                         │
         └─────────────────────────────────────────┘
         │
         ▼
 [ 6. Truthful Delivery Response ]
   - Returns per-contact delivery status (SMS: SENT / FAILED, FCM: SENT / FAILED)
   - Real-time updates displayed in Flutter SOS modal
```

---

## 2. Emergency Message Format

```text
EMERGENCY ALERT from Guardian AI!
[User Name] needs immediate assistance.
Location: https://maps.google.com/?q=13.0827,80.2707
Trigger: Unusual Movement Detected
Battery: 78%
Time: 2026-08-16 18:30:00 IST
```

---

## 3. Reliability & Offline Safety

- **Offline Persistence**: If network is unavailable at trigger time, `OfflineSyncManager` stores the SOS event in SQLite with idempotency key and retries every 5 seconds until network is restored.
- **Direct Phone Dialing**: The SOS modal provides immediate one-tap calling to local emergency dispatch (112 / 100) and primary contact.
