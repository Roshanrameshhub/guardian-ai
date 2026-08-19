# Guardian AI — Journey Monitoring & Deviation Flow

## 1. Journey Lifecycle Architecture

```
  [ Start Safe Walk ]
          │
          ▼
  1. GPS Location Acquisition (Geolocator High Accuracy)
          │
          ▼
  2. Route Planning & Evaluation (POST /api/v1/guardian/route)
          │
          ▼
  3. User Selects Route & Confirms (Safer / Fastest / Balanced)
          │
          ▼
  4. Backend Journey Created (POST /api/v1/journeys/start)
     - Archives any dangling previous active journeys
     - Stores origin/dest coordinates, polyline, and start timestamp
          │
          ▼
  5. Guardian Engine Activated
     ├── Live GPS stream (distanceFilter: 3m)
     ├── 30s Heartbeat telemetry to backend (POST /api/v1/guardian/heartbeat)
     ├── Continuous Route Deviation Detector
     ├── Accelerometer/Gyroscope motion monitoring
     └── Background Voice Distress Listener
          │
          ▼
  6. Live Journey Screen (Live Camera Follow, Polyline, Dynamic ETA & Distance)
          │
          ├── [ IF DEVIATION > 150m for 3 GPS updates ] ──► 20s Safety Confirmation Prompt
          │                                                    ├── [I'M SAFE] → Resume tracking
          │                                                    └── [I'M IN DANGER] or Timeout → SOS Emergency
          │
          ▼
  7. Safe Arrival Confirmation (POST /api/v1/journeys/{id}/stop)
     - Journey marked completed safely
     - Trusted circle notified of safe arrival
     - Guardian mode safely disarmed
```

---

## 2. Route Deviation Geometric Detector

The detector (`lib/core/services/route_deviation_detector.dart`) computes the shortest perpendicular distance between the user's live GPS point $P$ and each polyline line segment $V \to W$:

$$t = \max\left(0, \min\left(1, \frac{(P - V) \cdot (W - V)}{|W - V|^2}\right)\right)$$
$$\text{Projection} = V + t(W - V)$$
$$\text{Distance} = \text{Haversine}(P, \text{Projection})$$

- **Threshold**: 150 meters.
- **Debounce**: Requires 3 consecutive anomalous GPS updates (to avoid transient GPS multipath bounce).
- **Escalation**: Triggers `showSafetyConfirmationDialog` with 20s countdown.
