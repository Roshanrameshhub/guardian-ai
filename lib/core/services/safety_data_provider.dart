import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/entities.dart';
import '../../providers/repository_providers.dart';

/// Clean abstraction for crime and safety data.
///
/// Designed so prototype/demo safety scores and Chennai zone data can be
/// seamlessly swapped with official police/crime APIs or a machine-learning
/// risk service in the future without rewriting UI components.
abstract class SafetyDataProvider {
  /// Whether this provider is currently backed by demo/prototype data.
  bool get isPrototypeDemoData;

  /// Transparent user-facing disclosure for safety data integrity.
  String get disclaimer;

  /// Retrieve all safety/risk zones for map visualization.
  Future<List<SafetyZoneEntity>> getSafetyZones();

  /// Retrieve nearby safety resources (police, hospitals, transit, safe places).
  Future<NearbyHelpEntity> getNearbySafetyResources({
    required double lat,
    required double lng,
  });

  /// Evaluate situational location risk [0 .. 100] based on spatial proximity.
  Future<int> evaluateLocationRiskScore({
    required double lat,
    required double lng,
    required bool isNight,
  });
}

/// Prototype implementation using calibrated location-based risk percentages.
///
/// Implements caching and request debouncing to minimize unnecessary API requests.
class DemoSafetyDataProviderImpl implements SafetyDataProvider {
  DemoSafetyDataProviderImpl(this._ref);

  final Ref _ref;

  static const String _disclaimer =
      'Prototype safety score — Does not represent official crime statistics or guarantee safety.';

  // In-memory cache
  List<SafetyZoneEntity>? _cachedZones;
  DateTime? _zonesCacheTime;

  NearbyHelpEntity? _cachedNearbyHelp;
  double? _cachedNearbyLat;
  double? _cachedNearbyLng;
  DateTime? _nearbyHelpCacheTime;

  static const Duration _cacheTtl = Duration(minutes: 5);

  @override
  bool get isPrototypeDemoData => true;

  @override
  String get disclaimer => _disclaimer;

  @override
  Future<List<SafetyZoneEntity>> getSafetyZones() async {
    final now = DateTime.now();
    if (_cachedZones != null &&
        _zonesCacheTime != null &&
        now.difference(_zonesCacheTime!) < _cacheTtl) {
      return _cachedZones!;
    }

    try {
      final repo = _ref.read(guardianRepositoryProvider);
      final zones = await repo.fetchSafetyZones();
      _cachedZones = zones;
      _zonesCacheTime = now;
      return zones;
    } catch (_) {
      // Return cached if available on error, otherwise empty list
      return _cachedZones ?? const [];
    }
  }

  @override
  Future<NearbyHelpEntity> getNearbySafetyResources({
    required double lat,
    required double lng,
  }) async {
    final now = DateTime.now();
    if (_cachedNearbyHelp != null &&
        _nearbyHelpCacheTime != null &&
        now.difference(_nearbyHelpCacheTime!) < _cacheTtl &&
        _cachedNearbyLat != null &&
        _cachedNearbyLng != null) {
      // Re-use if within 100 meters
      final latDiff = (lat - _cachedNearbyLat!).abs();
      final lngDiff = (lng - _cachedNearbyLng!).abs();
      if (latDiff < 0.001 && lngDiff < 0.001) {
        return _cachedNearbyHelp!;
      }
    }

    try {
      final repo = _ref.read(guardianRepositoryProvider);
      final nearby = await repo.fetchNearbyHelp(lat: lat, lng: lng);
      _cachedNearbyHelp = nearby;
      _cachedNearbyLat = lat;
      _cachedNearbyLng = lng;
      _nearbyHelpCacheTime = now;
      return nearby;
    } catch (_) {
      if (_cachedNearbyHelp != null) return _cachedNearbyHelp!;
      rethrow;
    }
  }

  @override
  Future<int> evaluateLocationRiskScore({
    required double lat,
    required double lng,
    required bool isNight,
  }) async {
    final zones = await getSafetyZones();
    if (zones.isEmpty) {
      return isNight ? 25 : 12; // Baseline
    }

    // Find nearest safety zone within 1.5km
    double minDistanceKm = double.infinity;
    SafetyZoneEntity? nearestZone;

    for (final z in zones) {
      final dLat = (z.latitude - lat) * 111.0;
      final dLng = (z.longitude - lng) * 111.0 * 0.97;
      final distKm = (dLat * dLat + dLng * dLng);
      if (distKm < minDistanceKm) {
        minDistanceKm = distKm;
        nearestZone = z;
      }
    }

    if (nearestZone != null && minDistanceKm < 2.25) { // within ~1.5 km
      final zoneRisk = isNight ? nearestZone.nightRiskScore : nearestZone.dayRiskScore;
      return zoneRisk.clamp(5, 95);
    }

    return isNight ? 22 : 10;
  }
}

final safetyDataProvider = Provider<SafetyDataProvider>((ref) {
  return DemoSafetyDataProviderImpl(ref);
});
