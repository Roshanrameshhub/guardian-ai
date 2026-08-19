import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/dev_log.dart';

/// Detailed evaluation report for route corridor tracking.
class RouteDeviationReport {
  const RouteDeviationReport({
    required this.currentDistanceMeters,
    required this.isDeviated,
    required this.isSustained,
    required this.sustainedSeconds,
    required this.corridorWidthMeters,
    required this.timestamp,
  });

  final double currentDistanceMeters;
  final bool isDeviated; // > corridorWidthMeters (e.g. > 100m)
  final bool isSustained; // sustained for >= 45s
  final int sustainedSeconds;
  final double corridorWidthMeters;
  final DateTime timestamp;
}

/// Journey Watchdog: Mathematical Route Corridor Deviation Detector.
///
/// Implements:
/// 1. Mathematical minimum perpendicular distance projection to all polyline segments.
/// 2. 100-meter safety corridor boundary.
/// 3. 45-second temporal persistence filter (rejects temporary GPS multipath/noise).
/// 4. Dynamic corridor expansion & route recalibration hooks.
class RouteDeviationDetector {
  RouteDeviationDetector({
    double corridorWidthMeters = 100.0,
    double? deviationThresholdMeters,
    this.sustainedDurationThreshold = const Duration(seconds: 45),
    this.onSustainedDeviationConfirmed,
  }) : corridorWidthMeters = deviationThresholdMeters ?? corridorWidthMeters;

  double corridorWidthMeters;
  final Duration sustainedDurationThreshold;
  void Function(double distanceMeters)? onSustainedDeviationConfirmed;

  List<LatLng> _plannedRoutePoints = [];
  DateTime? _deviationCandidateStartTime;
  bool _sustainedAlertFired = false;
  double _lastDistanceMeters = 0.0;

  List<LatLng> get plannedRoutePoints => List.unmodifiable(_plannedRoutePoints);
  double get lastDistanceMeters => _lastDistanceMeters;
  bool get hasActiveCandidate => _deviationCandidateStartTime != null;

  /// Set or update the planned route polyline points.
  void setPlannedRoute(List<LatLng> points) {
    _plannedRoutePoints = List.from(points);
    _deviationCandidateStartTime = null;
    _sustainedAlertFired = false;
    DevLog.log('ROUTE_WATCHDOG', 'Planned route corridor set with ${_plannedRoutePoints.length} points.');
  }

  /// Decode Google Encoded Polyline algorithm string and set as route corridor.
  void setPlannedRouteFromEncoded(String encoded) {
    setPlannedRoute(decodePolyline(encoded));
  }

  /// Ingest real-time GPS coordinate and evaluate mathematical corridor status.
  RouteDeviationReport processPosition(LatLng position, {DateTime? sampleTime}) {
    final now = sampleTime ?? DateTime.now();

    if (_plannedRoutePoints.isEmpty) {
      return RouteDeviationReport(
        currentDistanceMeters: 0.0,
        isDeviated: false,
        isSustained: false,
        sustainedSeconds: 0,
        corridorWidthMeters: corridorWidthMeters,
        timestamp: now,
      );
    }

    final distance = distanceToPolyline(position, _plannedRoutePoints);
    _lastDistanceMeters = distance;
    final isCurrentlyDeviated = distance > corridorWidthMeters;

    int sustainedSecs = 0;
    bool isSustained = false;

    if (isCurrentlyDeviated) {
      if (_deviationCandidateStartTime == null) {
        _deviationCandidateStartTime = now;
        DevLog.log(
          'ROUTE_WATCHDOG',
          'Candidate deviation detected: ${distance.toStringAsFixed(1)}m off route (corridor=${corridorWidthMeters}m). Starting 45s verification window.',
        );
      } else {
        sustainedSecs = now.difference(_deviationCandidateStartTime!).inSeconds;
        if (sustainedSecs >= sustainedDurationThreshold.inSeconds) {
          isSustained = true;
          if (!_sustainedAlertFired) {
            _sustainedAlertFired = true;
            DevLog.log(
              'ROUTE_WATCHDOG',
              'CONFIRMED SUSTAINED DEVIATION: ${distance.toStringAsFixed(1)}m off route sustained for ${sustainedSecs}s.',
            );
            if (onSustainedDeviationConfirmed != null) {
              onSustainedDeviationConfirmed!(distance);
            }
          }
        }
      }
    } else {
      // Returned within safe corridor
      if (_deviationCandidateStartTime != null) {
        DevLog.log('ROUTE_WATCHDOG', 'GPS position returned inside safe corridor (${distance.toStringAsFixed(1)}m). Resetting candidate.');
      }
      _deviationCandidateStartTime = null;
      _sustainedAlertFired = false;
    }

    return RouteDeviationReport(
      currentDistanceMeters: distance,
      isDeviated: isCurrentlyDeviated,
      isSustained: isSustained,
      sustainedSeconds: sustainedSecs,
      corridorWidthMeters: corridorWidthMeters,
      timestamp: now,
    );
  }

  /// User confirms "I changed route" -> replace planned corridor.
  void handleUserChangedRoute(List<LatLng> newRoutePoints) {
    DevLog.log('ROUTE_WATCHDOG', 'User changed route. Recalculating corridor to destination.');
    setPlannedRoute(newRoutePoints);
  }

  /// User confirms "I'm OK" -> expand corridor to encompass current location.
  void handleUserSafeInCurrentLocation(double currentDeviationDistance) {
    corridorWidthMeters = math.max(corridorWidthMeters, currentDeviationDistance + 50.0);
    _deviationCandidateStartTime = null;
    _sustainedAlertFired = false;
    DevLog.log('ROUTE_WATCHDOG', 'User confirmed OK. Expanded corridor width to ${corridorWidthMeters.toStringAsFixed(1)}m.');
  }

  /// Calculate shortest perpendicular distance in meters from point [p] to polyline [routePoints].
  double distanceToPolyline(LatLng p, List<LatLng> routePoints) {
    if (routePoints.isEmpty) return 0.0;
    if (routePoints.length == 1) {
      return distanceBetweenMeters(p, routePoints.first);
    }

    double minDistance = double.infinity;
    for (int i = 0; i < routePoints.length - 1; i++) {
      final d = _distanceToSegment(p, routePoints[i], routePoints[i + 1]);
      if (d < minDistance) {
        minDistance = d;
      }
    }
    return minDistance;
  }

  /// Checks whether point [p] has deviated from [routePoints] based on corridor width.
  bool isDeviated(LatLng p, List<LatLng> routePoints) {
    if (routePoints.length < 2) return false;
    final dist = distanceToPolyline(p, routePoints);
    return dist > corridorWidthMeters;
  }

  /// Great-circle Haversine distance in meters between two coordinates.
  static double distanceBetweenMeters(LatLng p1, LatLng p2) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = _toRadians(p2.latitude - p1.latitude);
    final dLng = _toRadians(p2.longitude - p1.longitude);
    final lat1 = _toRadians(p1.latitude);
    final lat2 = _toRadians(p2.latitude);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) * math.sin(dLng / 2) * math.cos(lat1) * math.cos(lat2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _distanceToSegment(LatLng p, LatLng v, LatLng w) {
    final l2 = _distSq(v, w);
    if (l2 == 0) return distanceBetweenMeters(p, v);

    // Project point p onto segment vw
    final t = math.max(
      0.0,
      math.min(
        1.0,
        ((p.latitude - v.latitude) * (w.latitude - v.latitude) +
                (p.longitude - v.longitude) * (w.longitude - v.longitude)) /
            l2,
      ),
    );

    final projection = LatLng(
      v.latitude + t * (w.latitude - v.latitude),
      v.longitude + t * (w.longitude - v.longitude),
    );

    return distanceBetweenMeters(p, projection);
  }

  static double _distSq(LatLng p1, LatLng p2) {
    final dLat = p1.latitude - p2.latitude;
    final dLng = p1.longitude - p2.longitude;
    return dLat * dLat + dLng * dLng;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;

  /// Decodes Google Encoded Polyline algorithm format into LatLng list.
  static List<LatLng> decodePolyline(String encoded) {
    final List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      final LatLng p = LatLng(lat / 1E5, lng / 1E5);
      poly.add(p);
    }
    return poly;
  }

  void reset() {
    _plannedRoutePoints.clear();
    _deviationCandidateStartTime = null;
    _sustainedAlertFired = false;
    _lastDistanceMeters = 0.0;
  }
}
