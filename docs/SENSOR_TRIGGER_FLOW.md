# Guardian AI — Sensor Trigger & Kinematics Flow

## 1. Hardware Stream Processing

The `SensorService` (`lib/core/services/sensor_service.dart`) utilizes low-level Android hardware event streams via the Flutter `sensors_plus` plugin:
- `accelerometerEventStream()`: 3-axis linear acceleration $(a_x, a_y, a_z)$ in $\text{m/s}^2$.
- `gyroscopeEventStream()`: 3-axis rotational velocity $(\omega_x, \omega_y, \omega_z)$ in $\text{rad/s}$.

---

## 2. Sliding Window Anomaly Detection

```
 [ Hardware Sensors ]
         │ (Stream of (x, y, z) at ~20-50 Hz)
         ▼
 [ Rolling 50-Sample Buffer ]
   - accel_magnitude = sqrt(ax² + ay² + az²)
   - rot_magnitude   = sqrt(ωx² + ωy² + ωz²)
         │
         ▼
 [ 2-Second Edge Analyzer Window ]
         │
         ├── Peak Acceleration > 25.0 m/s² (Severe Drop / Physical Impact)
         │       │
         │       └──► Classify PHONE_DROP
         │
         └── Peak Acceleration > 18.0 m/s² AND Rotational Velocity > 6.0 rad/s (Violent Struggle / Shake)
                 │
                 └──► Classify SHAKE_DETECTED
```

---

## 3. Anomaly Escalation Pipeline

1. **Hardware Detection**: Edge analyzer classifies `PHONE_DROP` or `SHAKE_DETECTED`.
2. **Stream Emission**: Emitted onto `SensorService.anomalyStream`.
3. **Background Signal Dispatch**: `POST /api/v1/intelligence/motion-signal` with peak acceleration, peak rotation, and confidence score (0.85–0.90).
4. **Interactive Safety Prompt**:
   - `LiveJourneyScreen` / Active screen receives anomaly event.
   - Presents `showSafetyConfirmationDialog` with title `⚠ UNUSUAL MOVEMENT DETECTED`.
   - Displays 20-second active countdown ring.
   - If user taps **[I'M SAFE]**: Dismisses dialog, logs safety confirmation, monitoring continues.
   - If user taps **[I'M IN DANGER]** or 20s expires: Immediately triggers full multi-channel SOS emergency pipeline.
