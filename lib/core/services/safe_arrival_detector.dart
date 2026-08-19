import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/dev_log.dart';
import 'route_deviation_detector.dart';

/// Evaluation report from safe arrival analysis.
class SafeArrivalReport {
  const SafeArrivalReport({
    required this.distanceToDestinationMeters,
    required this.isWithinProximity,
    required this.isAutoConfirmed,
    required this.stationaryAtDestinationSeconds,
    this.promptMessage,
  });

  final double distanceToDestinationMeters;
  final bool isWithinProximity; // < 80m and speed < 3 km/h
  final bool isAutoConfirmed;   // < 50m and stationary for >= 2 minutes (120s)
  final int stationaryAtDestinationSeconds;
  final String? promptMessage;
}

/// Detects proximity and automatic safe arrival confirmation at journey destination.
class SafeArrivalDetector {
  SafeArrivalDetector({
    this.destination,
    this.destinationName = 'your destination',
    this.onProximityDetected,
    this.onAutoConfirmed,
  });

  LatLng? destination;
  String destinationName;
  void Function(double distanceMeters, String prompt)? onProximityDetected;
  void Function(double distanceMeters)? onAutoConfirmed;

  DateTime? _closeProximityStartTime;
  bool _proximityPromptFired = false;
  bool _autoConfirmedFired = false;

  void setDestination(LatLng dest, {String? name}) {
    destination = dest;
    if (name != null) destinationName = name;
    _closeProximityStartTime = null;
    _proximityPromptFired = false;
    _autoConfirmedFired = false;
  }

  /// Process live coordinate and speed against target destination.
  SafeArrivalReport processPosition({
    required LatLng position,
    required double speedKmh,
    DateTime? sampleTime,
  }) {
    final now = sampleTime ?? DateTime.now();

    if (destination == null) {
      return const SafeArrivalReport(
        distanceToDestinationMeters: -1,
        isWithinProximity: false,
        isAutoConfirmed: false,
        stationaryAtDestinationSeconds: 0,
      );
    }

    final distance = RouteDeviationDetector.distanceBetweenMeters(position, destination!);
    final isWithin80m = distance <= 80.0 && speedKmh < 3.0;
    final isWithin50m = distance <= 50.0 && speedKmh < 1.5;

    int stationarySecs = 0;
    bool isAutoConfirmed = false;
    String? prompt;

    if (isWithin80m) {
      prompt = "Looks like you've arrived at $destinationName. Confirm safe arrival?";
      if (!_proximityPromptFired) {
        _proximityPromptFired = true;
        DevLog.log('SAFE_ARRIVAL', 'User within 80m of destination (${distance.toStringAsFixed(1)}m). Prompting confirmation.');
        if (onProximityDetected != null) {
          onProximityDetected!(distance, prompt);
        }
      }
    }

    if (isWithin50m) {
      _closeProximityStartTime ??= now;
      stationarySecs = now.difference(_closeProximityStartTime!).inSeconds;

      if (stationarySecs >= 120 && !_autoConfirmedFired) {
        _autoConfirmedFired = true;
        isAutoConfirmed = true;
        DevLog.log('SAFE_ARRIVAL', 'Auto-confirmed safe arrival: within 50m (${distance.toStringAsFixed(1)}m) for ${stationarySecs}s.');
        if (onAutoConfirmed != null) {
          onAutoConfirmed!(distance);
        }
      }
    } else {
      _closeProximityStartTime = null;
    }

    return SafeArrivalReport(
      distanceToDestinationMeters: distance,
      isWithinProximity: isWithin80m,
      isAutoConfirmed: isAutoConfirmed || _autoConfirmedFired,
      stationaryAtDestinationSeconds: stationarySecs,
      promptMessage: prompt,
    );
  }

  void reset() {
    destination = null;
    _closeProximityStartTime = null;
    _proximityPromptFired = false;
    _autoConfirmedFired = false;
  }
}
