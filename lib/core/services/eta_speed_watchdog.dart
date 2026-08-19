import '../utils/dev_log.dart';
import 'stationary_detector.dart';

/// Speed anomaly classifications.
enum SpeedAnomalyType {
  none,
  unexpectedSpeeding, // e.g. Walking mode travelling at vehicle speed (> 25 km/h for > 30s)
  collisionSuspected,  // e.g. Driving mode with abrupt deceleration spike > 20 m/s² and sudden stop
}

/// Evaluation report from ETA & speed anomaly checks.
class EtaSpeedReport {
  const EtaSpeedReport({
    required this.isOverdue,
    required this.overdueMinutes,
    required this.expectedArrival,
    required this.speedAnomaly,
    required this.currentSpeedKmh,
    required this.travelMode,
    this.promptMessage,
  });

  final bool isOverdue;
  final int overdueMinutes;
  final DateTime expectedArrival;
  final SpeedAnomalyType speedAnomaly;
  final double currentSpeedKmh;
  final TravelMode travelMode;
  final String? promptMessage;
}

/// Watchdog monitoring journey ETA deadlines and kinematic speed anomalies.
class EtaSpeedWatchdog {
  EtaSpeedWatchdog({
    required this.travelMode,
    DateTime? initialExpectedArrival,
    this.onEtaOverdue,
    this.onSpeedAnomaly,
  }) : expectedArrival = initialExpectedArrival ?? DateTime.now().add(const Duration(minutes: 15));

  TravelMode travelMode;
  DateTime expectedArrival;
  void Function(int overdueMinutes, String prompt)? onEtaOverdue;
  void Function(SpeedAnomalyType type, String details)? onSpeedAnomaly;

  DateTime? _speedingStartTime;
  bool _overdueAlertFired = false;
  bool _speedAnomalyAlertFired = false;
  double _lastSpeedKmh = 0.0;

  int get overdueToleranceMinutes => travelMode == TravelMode.driving ? 10 : 5;

  /// Extend ETA by user-specified additional minutes.
  void extendEta(int additionalMinutes) {
    expectedArrival = expectedArrival.add(Duration(minutes: additionalMinutes));
    _overdueAlertFired = false;
    DevLog.log('ETA_WATCHDOG', 'ETA extended by $additionalMinutes min. New ETA: $expectedArrival');
  }

  /// Process live telemetry snapshot for ETA and speed anomalies.
  EtaSpeedReport processTelemetry({
    required double currentSpeedKmh,
    double decelerationPeak = 0.0,
    DateTime? sampleTime,
  }) {
    final now = sampleTime ?? DateTime.now();

    // 1. Evaluate Overdue ETA
    final diffMinutes = now.difference(expectedArrival).inMinutes;
    final isOverdue = diffMinutes >= overdueToleranceMinutes;
    String? etaPrompt;

    if (isOverdue) {
      etaPrompt = 'Your journey is taking longer than expected. Need more time or assistance?';
      if (!_overdueAlertFired) {
        _overdueAlertFired = true;
        DevLog.log('ETA_WATCHDOG', 'Journey is overdue by $diffMinutes minutes (tolerance=$overdueToleranceMinutes min).');
        if (onEtaOverdue != null) {
          onEtaOverdue!(diffMinutes, etaPrompt);
        }
      }
    }

    // 2. Evaluate Speed Anomalies
    SpeedAnomalyType detectedAnomaly = SpeedAnomalyType.none;

    if (travelMode == TravelMode.walking) {
      // Walking mode exceeding vehicle speed (> 25 km/h)
      if (currentSpeedKmh > 25.0) {
        _speedingStartTime ??= now;
        final durationSecs = now.difference(_speedingStartTime!).inSeconds;
        if (durationSecs >= 30) {
          detectedAnomaly = SpeedAnomalyType.unexpectedSpeeding;
          if (!_speedAnomalyAlertFired) {
            _speedAnomalyAlertFired = true;
            DevLog.log(
              'ETA_WATCHDOG',
              'Speed anomaly: User walking at ${currentSpeedKmh.toStringAsFixed(1)} km/h for ${durationSecs}s.',
            );
            if (onSpeedAnomaly != null) {
              onSpeedAnomaly!(
                SpeedAnomalyType.unexpectedSpeeding,
                'Unexpected vehicle speed while on foot (${currentSpeedKmh.toStringAsFixed(0)} km/h)',
              );
            }
          }
        }
      } else {
        _speedingStartTime = null;
      }
    } else if (travelMode == TravelMode.driving) {
      // Sudden deceleration spike > 20 m/s² and drop from high speed to < 2 km/h
      if (_lastSpeedKmh > 30.0 && currentSpeedKmh < 2.0 && decelerationPeak > 20.0) {
        detectedAnomaly = SpeedAnomalyType.collisionSuspected;
        if (!_speedAnomalyAlertFired) {
          _speedAnomalyAlertFired = true;
          DevLog.log(
            'ETA_WATCHDOG',
            'Collision anomaly: Drop from ${_lastSpeedKmh.toStringAsFixed(1)} to ${currentSpeedKmh.toStringAsFixed(1)} km/h with decel=${decelerationPeak.toStringAsFixed(1)} m/s².',
          );
          if (onSpeedAnomaly != null) {
            onSpeedAnomaly!(
              SpeedAnomalyType.collisionSuspected,
              'Sudden high-impact vehicle stop detected',
            );
          }
        }
      }
    }

    _lastSpeedKmh = currentSpeedKmh;

    return EtaSpeedReport(
      isOverdue: isOverdue,
      overdueMinutes: diffMinutes > 0 ? diffMinutes : 0,
      expectedArrival: expectedArrival,
      speedAnomaly: detectedAnomaly,
      currentSpeedKmh: currentSpeedKmh,
      travelMode: travelMode,
      promptMessage: etaPrompt,
    );
  }

  void reset() {
    _speedingStartTime = null;
    _overdueAlertFired = false;
    _speedAnomalyAlertFired = false;
    _lastSpeedKmh = 0.0;
  }
}
