import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/dev_log.dart';
import '../../../domain/entities/entities.dart';
import '../../../providers/repository_providers.dart';

class GuardianMapState {
  const GuardianMapState({
    this.userLocation,
    this.destination,
    this.destinationName = '',
    this.routePlan,
    this.selectedAlternativeIndex = 0,
    this.safetyZones = const [],
    this.policeStations = const [],
    this.nearbyHelp,
    this.isNavigating = false,
    this.showSafetyZones = true,
    this.showPolice = true,
    this.showHospitals = true,
    this.showStations = true,
    this.showActivePlaces = true,
    this.isNightMode = false,
    this.isLoading = false,
    this.errorMessage,
    this.selectedZone,
    this.selectedPolice,
    this.navigationProgress = 0.0,
  });

  final LatLngPoint? userLocation;
  final LatLngPoint? destination;
  final String destinationName;
  final GuardianRoutePlanEntity? routePlan;
  final int selectedAlternativeIndex;
  final List<SafetyZoneEntity> safetyZones;
  final List<PoliceStationEntity> policeStations;
  final NearbyHelpEntity? nearbyHelp;
  final bool isNavigating;
  final bool showSafetyZones;
  final bool showPolice;
  final bool showHospitals;
  final bool showStations;
  final bool showActivePlaces;
  final bool isNightMode;
  final bool isLoading;
  final String? errorMessage;
  final SafetyZoneEntity? selectedZone;
  final PoliceStationEntity? selectedPolice;
  final double navigationProgress;

  GuardianRouteAlternativeEntity? get activeRoute {
    if (routePlan == null || routePlan!.alternatives.isEmpty) return null;
    if (selectedAlternativeIndex < routePlan!.alternatives.length) {
      return routePlan!.alternatives[selectedAlternativeIndex];
    }
    return routePlan!.recommendedRoute;
  }

  GuardianMapState copyWith({
    LatLngPoint? userLocation,
    LatLngPoint? destination,
    String? destinationName,
    GuardianRoutePlanEntity? routePlan,
    int? selectedAlternativeIndex,
    List<SafetyZoneEntity>? safetyZones,
    List<PoliceStationEntity>? policeStations,
    NearbyHelpEntity? nearbyHelp,
    bool? isNavigating,
    bool? showSafetyZones,
    bool? showPolice,
    bool? showHospitals,
    bool? showStations,
    bool? showActivePlaces,
    bool? isNightMode,
    bool? isLoading,
    String? errorMessage,
    SafetyZoneEntity? selectedZone,
    PoliceStationEntity? selectedPolice,
    double? navigationProgress,
    bool clearRoute = false,
    bool clearSelectedZone = false,
    bool clearSelectedPolice = false,
  }) {
    return GuardianMapState(
      userLocation: userLocation ?? this.userLocation,
      destination: clearRoute ? null : (destination ?? this.destination),
      destinationName: clearRoute ? '' : (destinationName ?? this.destinationName),
      routePlan: clearRoute ? null : (routePlan ?? this.routePlan),
      selectedAlternativeIndex:
          selectedAlternativeIndex ?? this.selectedAlternativeIndex,
      safetyZones: safetyZones ?? this.safetyZones,
      policeStations: policeStations ?? this.policeStations,
      nearbyHelp: nearbyHelp ?? this.nearbyHelp,
      isNavigating: isNavigating ?? this.isNavigating,
      showSafetyZones: showSafetyZones ?? this.showSafetyZones,
      showPolice: showPolice ?? this.showPolice,
      showHospitals: showHospitals ?? this.showHospitals,
      showStations: showStations ?? this.showStations,
      showActivePlaces: showActivePlaces ?? this.showActivePlaces,
      isNightMode: isNightMode ?? this.isNightMode,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      selectedZone: clearSelectedZone ? null : (selectedZone ?? this.selectedZone),
      selectedPolice:
          clearSelectedPolice ? null : (selectedPolice ?? this.selectedPolice),
      navigationProgress: navigationProgress ?? this.navigationProgress,
    );
  }
}

class GuardianMapController extends StateNotifier<GuardianMapState> {
  GuardianMapController(this._ref) : super(const GuardianMapState()) {
    _initGuardianMap();
  }

  final Ref _ref;
  Timer? _navTimer;

  Future<void> _initGuardianMap() async {
    state = state.copyWith(isLoading: true);

    // 1. Determine Day/Night from local time (19:00 - 06:00 is night)
    final nowHour = DateTime.now().hour;
    final isNight = nowHour >= 19 || nowHour < 6;
    state = state.copyWith(isNightMode: isNight);

    // 2. Fetch User Location (or default Chennai Marina/Central coordinate)
    double userLat = 13.0067;
    double userLng = 80.2567; // Default Adyar/Besant Nagar area

    try {
      final locService = _ref.read(locationServiceProvider);
      final pos = await locService.getCurrentPosition(
        timeout: const Duration(seconds: 5),
      );
      userLat = pos.latitude;
      userLng = pos.longitude;
    } catch (_) {
      // Fall back to default Chennai center
    }

    state = state.copyWith(
      userLocation: LatLngPoint(userLat, userLng),
    );

    // 3. Load Safety Zones & Nearby Help
    try {
      final guardianRepo = _ref.read(guardianRepositoryProvider);
      DevLog.map('Loading safety zones, police stations, and nearby help...');
      final zones = await guardianRepo.fetchSafetyZones();
      final police = await guardianRepo.fetchPoliceStations(lat: userLat, lng: userLng);
      final nearby = await guardianRepo.fetchNearbyHelp(lat: userLat, lng: userLng);
      DevLog.map('Loaded ${zones.length} safety zones, ${police.length} police stations.');

      state = state.copyWith(
        safetyZones: zones,
        policeStations: police,
        nearbyHelp: nearby,
        isLoading: false,
      );
    } catch (e) {
      DevLog.map('Failed to load safety layers', error: e);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load safety layers: $e',
      );
    }
  }

  Future<void> refreshLocation() async {
    try {
      final locService = _ref.read(locationServiceProvider);
      final pos = await locService.getCurrentPosition();
      DevLog.gps('Refreshed GPS position: ${pos.latitude}, ${pos.longitude}');
      state = state.copyWith(
        userLocation: LatLngPoint(pos.latitude, pos.longitude),
      );
      // Refresh nearby help
      final guardianRepo = _ref.read(guardianRepositoryProvider);
      final nearby = await guardianRepo.fetchNearbyHelp(
        lat: pos.latitude,
        lng: pos.longitude,
      );
      state = state.copyWith(nearbyHelp: nearby);
    } catch (e) {
      DevLog.gps('GPS refresh failed', error: e);
      state = state.copyWith(errorMessage: 'Location unavailable: $e');
    }
  }

  Future<void> planRouteTo({
    required double destLat,
    required double destLng,
    required String destName,
    String travelMode = 'DRIVE',
  }) async {
    final userPos = state.userLocation ?? const LatLngPoint(13.0067, 80.2567);
    DevLog.route('Planning route: ($userPos) -> $destName ($destLat, $destLng) via $travelMode');
    state = state.copyWith(
      isLoading: true,
      destination: LatLngPoint(destLat, destLng),
      destinationName: destName,
    );

    try {
      final guardianRepo = _ref.read(guardianRepositoryProvider);
      final plan = await guardianRepo.calculateSafeRoute(
        originLat: userPos.lat,
        originLng: userPos.lng,
        destLat: destLat,
        destLng: destLng,
        destinationName: destName,
        travelMode: travelMode,
      );
      DevLog.route('Safe route plan received: ${plan.alternatives.length} alternatives, score=${plan.safetyScore}');

      state = state.copyWith(
        routePlan: plan,
        selectedAlternativeIndex: 0,
        isLoading: false,
        isNavigating: false,
      );
    } catch (e) {
      DevLog.route('Safe route calculation failed', error: e);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to calculate safe route: $e',
      );
    }
  }

  void selectAlternative(int index) {
    DevLog.route('Switched to alternative route #$index');
    state = state.copyWith(selectedAlternativeIndex: index);
  }

  void toggleSafetyZones() =>
      state = state.copyWith(showSafetyZones: !state.showSafetyZones);

  void togglePolice() =>
      state = state.copyWith(showPolice: !state.showPolice);

  void toggleHospitals() =>
      state = state.copyWith(showHospitals: !state.showHospitals);

  void toggleStations() =>
      state = state.copyWith(showStations: !state.showStations);

  void toggleActivePlaces() =>
      state = state.copyWith(showActivePlaces: !state.showActivePlaces);

  void toggleNightMode() =>
      state = state.copyWith(isNightMode: !state.isNightMode);

  void selectZone(SafetyZoneEntity zone) =>
      state = state.copyWith(selectedZone: zone);

  void clearSelectedZone() =>
      state = state.copyWith(clearSelectedZone: true);

  void selectPolice(PoliceStationEntity police) =>
      state = state.copyWith(selectedPolice: police);

  void clearSelectedPolice() =>
      state = state.copyWith(clearSelectedPolice: true);

  void startNavigation() {
    state = state.copyWith(isNavigating: true, navigationProgress: 0.05);
    _navTimer?.cancel();
    _navTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!state.isNavigating) {
        timer.cancel();
        return;
      }
      final newProgress = state.navigationProgress + 0.08;
      if (newProgress >= 1.0) {
        state = state.copyWith(navigationProgress: 1.0, isNavigating: false);
        timer.cancel();
      } else {
        state = state.copyWith(navigationProgress: newProgress);
      }
    });
  }

  void stopNavigation() {
    _navTimer?.cancel();
    state = state.copyWith(isNavigating: false, navigationProgress: 0.0);
  }

  void clearRoute() {
    stopNavigation();
    state = state.copyWith(clearRoute: true);
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    super.dispose();
  }
}

final guardianMapControllerProvider =
    StateNotifierProvider<GuardianMapController, GuardianMapState>((ref) {
  return GuardianMapController(ref);
});
