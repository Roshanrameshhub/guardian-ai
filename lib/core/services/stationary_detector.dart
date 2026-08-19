import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/dev_log.dart';
import 'route_deviation_detector.dart';

/// Travel mode governing stationary check-in thresholds.
enum TravelMode {
  walking, // 3 minutes threshold
  transit, // 5 minutes threshold (bus stop buffer)
  driving, // 8 minutes threshold (traffic jam buffer)
}

/// Evaluation report from multi-sensor stationary analysis.
class StationaryReport {
  const StationaryReport({
    required this.isStationary,
    required this.stationarySeconds,
    required this.isThresholdBreached,
    required this.thresholdSeconds,
    required this.travelMode,
    required this.displacementMeters,
    required this.accelVariance,
    required this.gpsSpeedKmh,
    required this.promptMessage,
  });

  final bool isStationary;
  final int stationarySeconds;
  final bool isThresholdBreached;
  final int thresholdSeconds;
  final TravelMode travelMode;
  final double displacementMeters;
  final double accelVariance;
  final double gpsSpeedKmh;
  final String? promptMessage;
}

/// Multi-sensor Stationary Detector with strict jitter rejection & mode thresholds.
///
/// Stationary criteria:
/// 1. GPS speed < 1.0 km/h
/// 2. AND GPS displacement < 20.0 meters over evaluation window (rejects GPS jitter)
/// 3. AND Accelerometer variance < 0.5 m/s² (phone is still)
///
/// Time thresholds:
/// - Walking: 3 minutes (180s)
/// - Transit: 5 minutes (300s)
/// - Driving: 8 minutes (480s)
class StationaryDetector {
  StationaryDetector({
    this.travelMode = TravelMode.walking,
    this.onStationaryBreach,
  });

  TravelMode travelMode;
  void Function(int stationaryMinutes, String promptMessage)? onStationaryBreach;

  LatLng? _stationaryAnchorPosition;
  DateTime? _stationaryStartTime;
  bool _breachPromptFired = false;
  final List<double> _recentAccelMagnitudes = [];

  int get thresholdSeconds {
    switch (travelMode) {
      case TravelMode.walking:
        return 180; // 3 minutes
      case TravelMode.transit:
        return 300; // 5 minutes
      case TravelMode.driving:
        return 480; // 8 minutes
    }
  }

  int get thresholdMinutes => thresholdSeconds ~/ 60;

  /// Process real-time sensor & GPS telemetry to evaluate stationary status.
  StationaryReport processTelemetry({
    required LatLng position,
    required double gpsSpeedKmh,
    required List<double> recentAccelSamples,
    DateTime? sampleTime,
  }) {
    final now = sampleTime ?? DateTime.now();

    // 1. Calculate accelerometer variance
    double accelVariance = 0.0;
    if (recentAccelSamples.isNotEmpty) {
      final mean = recentAccelSamples.reduce((a, b) => a + b) / recentAccelSamples.length;
      final sumSq = recentAccelSamples.fold<double>(0.0, (acc, val) => acc + (val - mean) * (val - mean));
      accelVariance = sumSq / recentAccelSamples.length;
    }

    // 2. Calculate GPS displacement relative to stationary anchor
    _stationaryAnchorPosition ??= position;
    final displacement = RouteDeviationDetector.distanceBetweenMeters(
      _stationaryAnchorPosition!,
      position,
    );

    // 3. Multi-sensor stationary conditions:
    // - GPS speed < 1.0 km/h
    // - GPS displacement < 20.0m (filters GPS jitter)
    // - Accel variance < 0.5 m/s²
    final isSpeedStationary = gpsSpeedKmh < 1.0;
    final isGpsDisplacementStationary = displacement < 20.0;
    final isAccelStill = accelVariance < 0.5;

    final isStationary = isSpeedStationary && isGpsDisplacementStationary && isAccelStill;

    int stationarySecs = 0;
    bool isBreached = false;
    String? prompt;

    if (isStationary) {
      _stationaryStartTime ??= now;
      stationarySecs = now.difference(_stationaryStartTime!).inSeconds;

      if (stationarySecs >= thresholdSeconds) {
        isBreached = true;
        prompt = "You haven't moved for $thresholdMinutes minutes. Still on track?";

        if (!_breachPromptFired) {
          _breachPromptFired = true;
          DevLog.log(
            'STATIONARY_WATCHDOG',
            'Stationary threshold reached ($stationarySecs s / $thresholdSeconds s for ${travelMode.name}). Triggering check-in.',
          );
          if (onStationaryBreach != null) {
            onStationaryBreach!(thresholdMinutes, prompt);
          }
        }
      }
    } else {
      // Movement detected -> reset stationary timer and update anchor
      if (_stationaryStartTime != null) {
        DevLog.log(
          'STATIONARY_WATCHDOG',
          'Movement detected (speed=${gpsSpeedKmh.toStringAsFixed(1)}km/h, disp=${displacement.toStringAsFixed(1)}m, accelVar=${accelVariance.toStringAsFixed(2)}). Resetting stationary timer.',
        );
      }
      _stationaryStartTime = null;
      _stationaryAnchorPosition = position;
      _breachPromptFired = false;
      stationarySecs = 0;
    }

    return StationaryReport(
      isStationary: isStationary,
      stationarySeconds: stationarySecs,
      isThresholdBreached: isBreached,
      thresholdSeconds: thresholdSeconds,
      travelMode: travelMode,
      displacementMeters: displacement,
      accelVariance: accelVariance,
      gpsSpeedKmh: gpsSpeedKmh,
      promptMessage: prompt,
    );
  }

  /// Reset all internal state and anchors.
  void reset() {
    _stationaryAnchorPosition = null;
    _stationaryStartTime = null;
    _breachPromptFired = false;
    _recentAccelMagnitudes.clear();
  }
}
