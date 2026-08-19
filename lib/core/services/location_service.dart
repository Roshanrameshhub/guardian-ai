import 'dart:async';
import 'package:geolocator/geolocator.dart';


/// Exceptions for location handling.
class LocationServiceDisabledException implements Exception {
  const LocationServiceDisabledException([this.message = 'GPS location services are disabled on device.']);
  final String message;
  @override
  String toString() => message;
}

class LocationPermissionDeniedException implements Exception {
  const LocationPermissionDeniedException([this.message = 'Location permission was denied.']);
  final String message;
  @override
  String toString() => message;
}

class LocationPermissionDeniedForeverException implements Exception {
  const LocationPermissionDeniedForeverException([this.message = 'Location permission is permanently denied. Please enable it in system settings.']);
  final String message;
  @override
  String toString() => message;
}

class LocationTimeoutException implements Exception {
  const LocationTimeoutException([this.message = 'Location request timed out.']);
  final String message;
  @override
  String toString() => message;
}

/// Unified real device GPS location service.
class LocationService {
  LocationService();

  Position? _lastKnownPosition;
  StreamSubscription<Position>? _positionSubscription;

  Position? get lastKnownPosition => _lastKnownPosition;

  /// Check whether GPS hardware service is enabled.
  Future<bool> isServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check current permission status.
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request foreground location permission from user.
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Ensure location service is enabled and permission is granted.
  Future<void> ensurePermissionAndService() async {
    final serviceEnabled = await isServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationPermissionDeniedException();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionDeniedForeverException();
    }
  }

  /// Get current high-accuracy device coordinates.
  /// Throws specific exceptions on denial or disablement.
  Future<Position> getCurrentPosition({
    Duration timeout = const Duration(seconds: 15),
    LocationAccuracy desiredAccuracy = LocationAccuracy.high,
  }) async {
    await ensurePermissionAndService();

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: desiredAccuracy,
          timeLimit: timeout,
        ),
      );
      _lastKnownPosition = position;
      return position;
    } on TimeoutException {
      // If active GNSS lock timed out, attempt to fall back to last known position before failing
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _lastKnownPosition = last;
        return last;
      }
      throw const LocationTimeoutException();
    } catch (e) {
      if (e is LocationServiceDisabledException ||
          e is LocationPermissionDeniedException ||
          e is LocationPermissionDeniedForeverException) {
        rethrow;
      }
      throw Exception('Failed to obtain device GPS location: $e');
    }
  }

  /// Stream continuous real-time location updates (e.g. for active Guardian Mode or Journey).
  Stream<Position> getPositionStream({
    LocationAccuracy desiredAccuracy = LocationAccuracy.high,
    int distanceFilter = 5,
  }) {
    final locationSettings = LocationSettings(
      accuracy: desiredAccuracy,
      distanceFilter: distanceFilter,
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings).map((pos) {
      _lastKnownPosition = pos;
      return pos;
    });
  }

  /// Calculate distance between two coordinates in meters.
  double distanceBetween(double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  void dispose() {
    _positionSubscription?.cancel();
  }
}
