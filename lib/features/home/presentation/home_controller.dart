import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/dev_log.dart';
import '../../../data/dto/api_dto.dart';
import '../../../domain/entities/entities.dart';
import '../../../providers/repository_providers.dart';

final dashboardProvider = FutureProvider<DashboardEntity>((ref) async {
  DevLog.home('Loading dashboard data...');
  double? lat;
  double? lng;
  try {
    final pos = await ref.read(locationServiceProvider).getCurrentPosition(
          timeout: const Duration(seconds: 4),
        );
    lat = pos.latitude;
    lng = pos.longitude;
    DevLog.home('Device GPS lock: lat=$lat, lng=$lng');
  } catch (e) {
    DevLog.home('Location unavailable for dashboard query: $e');
  }
  try {
    final res = await ref.watch(dashboardRepositoryProvider).fetchDashboard(lat: lat, lng: lng);
    DevLog.home('Dashboard loaded successfully for user: ${res.userName}, score: ${res.safetyScore}');
    return res;
  } catch (e, st) {
    DevLog.home('Dashboard fetch failed', error: e, stack: st);
    rethrow;
  }
});

class HomeController extends StateNotifier<AsyncValue<void>> {
  HomeController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> toggleGuardian(bool active) async {
    state = const AsyncLoading();
    try {
      final engine = _ref.read(guardianEngineProvider);
      if (active) {
        await engine.startGuardian();
      } else {
        await engine.stopGuardian();
      }
      _ref.invalidate(dashboardProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<JourneyEntity?> startSafeWalk({
    String destination = 'Home',
    double? destLat,
    double? destLng,
  }) async {
    state = const AsyncLoading();
    try {
      double? lat;
      double? lng;
      try {
        final pos = await _ref.read(locationServiceProvider).getCurrentPosition(
              timeout: const Duration(seconds: 5),
            );
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}

      final journey = await _ref.read(journeyRepositoryProvider).startJourney(
            StartJourneyRequest(
              origin: 'Current Location',
              destination: destination,
              originLat: lat,
              originLng: lng,
              destLat: destLat,
              destLng: destLng,
            ),
          );
      _ref.invalidate(dashboardProvider);
      state = const AsyncData(null);
      return journey;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<void> fakeCall() async {
    await _ref.read(toolsRepositoryProvider).startFakeCall();
  }

  Future<void> fakeMessage() async {
    await _ref.read(toolsRepositoryProvider).startFakeMessage();
  }

  Future<void> triggerSos() async {
    final location = _ref.read(locationServiceProvider);
    final pos = await location.getCurrentPosition();
    await _ref.read(guardianRepositoryProvider).triggerSos(
          SosRequest(
            lat: pos.latitude,
            lng: pos.longitude,
            triggerSource: 'home_sos',
          ),
        );
  }
}

final homeControllerProvider =
    StateNotifierProvider<HomeController, AsyncValue<void>>(HomeController.new);
