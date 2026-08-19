import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/entities.dart';
import '../../../providers/repository_providers.dart';

final mapRouteProvider = FutureProvider<MapRouteEntity>((ref) async {
  final locationService = ref.read(locationServiceProvider);
  double? lat;
  double? lng;
  try {
    final pos = await locationService.getCurrentPosition(
      timeout: const Duration(seconds: 5),
    );
    lat = pos.latitude;
    lng = pos.longitude;
  } catch (_) {}

  return ref.watch(mapRepositoryProvider).fetchRoute(
        originLat: lat,
        originLng: lng,
      );
});

class MapUiState {
  const MapUiState({
    this.selectedFilter = MapFilter.safeRoute,
    this.nightMode = true,
    this.searchQuery = '',
  });

  final MapFilter selectedFilter;
  final bool nightMode;
  final String searchQuery;

  MapUiState copyWith({
    MapFilter? selectedFilter,
    bool? nightMode,
    String? searchQuery,
  }) {
    return MapUiState(
      selectedFilter: selectedFilter ?? this.selectedFilter,
      nightMode: nightMode ?? this.nightMode,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

enum MapFilter { safeRoute, police, hospital }

class MapController extends StateNotifier<MapUiState> {
  MapController() : super(const MapUiState());

  void selectFilter(MapFilter filter) =>
      state = state.copyWith(selectedFilter: filter);

  void toggleNightMode() => state = state.copyWith(nightMode: !state.nightMode);

  void setSearch(String query) => state = state.copyWith(searchQuery: query);
}

final mapControllerProvider =
    StateNotifierProvider<MapController, MapUiState>((ref) => MapController());
