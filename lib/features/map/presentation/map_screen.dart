import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/sos_dialog.dart';
import '../../../domain/entities/entities.dart';
import '../../guardian/presentation/guardian_map_controller.dart';
import '../../guardian/presentation/widgets/destination_search_sheet.dart';
import '../../guardian/presentation/widgets/guardian_route_comparison_card.dart';
import '../../guardian/presentation/widgets/police_station_detail_sheet.dart';
import '../../guardian/presentation/widgets/safety_zone_detail_sheet.dart';

/// MAP SCREEN — DEDICATED PLANNING & EXPLORATION SCREEN
///
/// Answers: "Where am I going and which route should I take?"
///
/// Features:
/// 1. Real-time GPS location
/// 2. Destination search & suggestions (Home, Work, Airport, Hospital)
/// 3. Google Directions route alternatives (Safer, Fastest, Balanced)
/// 4. Auto-framing camera bounds (_fitRouteBounds)
/// 5. Safety Zones, Police Stations, Hospitals, Transit layers
/// 6. Start Safe Journey transition to JourneyConfirmationScreen
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;

  static const _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1d2c4d"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8ec3b9"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#1a3646"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#304a7d"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0e1626"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#283d6a"}]}
]
''';

  void _fitRouteBounds(GuardianRoutePlanEntity plan) {
    if (_mapController == null) return;
    final points = <LatLng>[
      LatLng(plan.originLat, plan.originLng),
      LatLng(plan.destLat, plan.destLng),
    ];
    if (plan.recommendedRoute.points.isNotEmpty) {
      points.addAll(plan.recommendedRoute.points.map((p) => LatLng(p.lat, p.lng)));
    }
    for (final alt in plan.alternatives) {
      points.addAll(alt.points.map((p) => LatLng(p.lat, p.lng)));
    }

    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(guardianMapControllerProvider);
    final controller = ref.read(guardianMapControllerProvider.notifier);

    ref.listen<GuardianMapState>(guardianMapControllerProvider, (prev, next) {
      if (next.routePlan != null &&
          (prev?.routePlan != next.routePlan ||
              prev?.selectedAlternativeIndex != next.selectedAlternativeIndex)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitRouteBounds(next.routePlan!);
        });
      }
    });

    final userLoc = state.userLocation != null
        ? LatLng(state.userLocation!.lat, state.userLocation!.lng)
        : const LatLng(13.0067, 80.2567);

    // Build Polylines
    final polylines = <Polyline>{};
    if (state.routePlan != null && state.activeRoute != null) {
      final active = state.activeRoute!;
      // Draw non-selected alternatives as subtle lines
      for (int i = 0; i < state.routePlan!.alternatives.length; i++) {
        if (i != state.selectedAlternativeIndex) {
          final alt = state.routePlan!.alternatives[i];
          polylines.add(
            Polyline(
              polylineId: PolylineId('alt_route_$i'),
              points: alt.points.map((p) => LatLng(p.lat, p.lng)).toList(),
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.45),
              width: 4,
            ),
          );
        }
      }

      // Draw selected active route
      polylines.add(
        Polyline(
          polylineId: const PolylineId('active_selected_route'),
          points: active.points.map((p) => LatLng(p.lat, p.lng)).toList(),
          color: active.role.toLowerCase().contains('safer')
              ? AppColors.primaryPulse
              : (active.role.toLowerCase().contains('fastest')
                  ? AppColors.warning
                  : AppColors.tertiary),
          width: 7,
          patterns: const [],
        ),
      );
    }

    // Build Markers
    final markers = <Marker>{
      // User current position marker
      Marker(
        markerId: const MarkerId('user_location'),
        position: userLoc,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: '📍 Your Location'),
      ),
    };

    // Add Destination Marker if route is planned
    if (state.routePlan != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(state.routePlan!.destLat, state.routePlan!.destLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueMagenta),
          infoWindow: InfoWindow(title: '🏁 ${state.routePlan!.destinationName}'),
        ),
      );
    }

    // Add Police Station Markers if layer is enabled
    if (state.showPolice) {
      for (final ps in state.policeStations) {
        if (ps.latitude != null && ps.longitude != null) {
          markers.add(
            Marker(
              markerId: MarkerId('police_${ps.id}'),
              position: LatLng(ps.latitude!, ps.longitude!),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: InfoWindow(title: '👮 ${ps.stationName}', snippet: ps.contactNumber),
              onTap: () => controller.selectPolice(ps),
            ),
          );
        }
      }
    }

    // Add Hospital Markers if layer is enabled
    if (state.showHospitals && state.nearbyHelp != null) {
      for (final h in state.nearbyHelp!.hospitals) {
        markers.add(
          Marker(
            markerId: MarkerId('hospital_${h.id}'),
            position: LatLng(h.latitude, h.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: '🏥 ${h.name}'),
          ),
        );
      }
    }

    // Add Metro / Transit Markers if layer is enabled
    if (state.showStations && state.nearbyHelp != null) {
      for (final t in state.nearbyHelp!.stations) {
        markers.add(
          Marker(
            markerId: MarkerId('transit_${t.id}'),
            position: LatLng(t.latitude, t.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(title: '🚇 ${t.name}'),
          ),
        );
      }
    }

    // Build Circles (Safety Zones)
    final circles = <Circle>{};
    if (state.showSafetyZones) {
      for (final zone in state.safetyZones) {
        final isHigh = zone.demoSafetyScore < 50;
        final isMed = zone.demoSafetyScore >= 50 && zone.demoSafetyScore < 75;
        circles.add(
          Circle(
            circleId: CircleId('zone_${zone.id}'),
            center: LatLng(zone.latitude, zone.longitude),
            radius: zone.radiusMeters,
            fillColor: isHigh
                ? AppColors.error.withValues(alpha: 0.22)
                : (isMed
                    ? AppColors.warning.withValues(alpha: 0.20)
                    : AppColors.success.withValues(alpha: 0.15)),
            strokeColor: isHigh
                ? AppColors.error
                : (isMed ? AppColors.warning : AppColors.success),
            strokeWidth: 2,
            consumeTapEvents: true,
            onTap: () => controller.selectZone(zone),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Full Screen Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: userLoc,
              zoom: 14.5,
            ),
              style: _darkMapStyle,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              markers: markers,
              polylines: polylines,
              circles: circles,
              onMapCreated: (ctrl) {
                _mapController = ctrl;
                if (state.routePlan != null) {
                  _fitRouteBounds(state.routePlan!);
                }
              },
            ),

            // Top Header: Search Bar & Floating POI Layer Filter Chips
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Search Bar
                    GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      borderRadius: AppRadius.borderFull,
                      onTap: () => _openDestinationPicker(context, controller),
                      child: Row(
                        children: [
                          const Icon(AppIcons.search, color: AppColors.primaryPulse, size: 20),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              state.routePlan?.destinationName.isNotEmpty == true
                                  ? state.routePlan!.destinationName
                                  : 'Where are you going? (Tap to plan)',
                              style: AppTextStyles.bodyMd.copyWith(
                                color: state.routePlan != null ? AppColors.onSurface : AppColors.onSurfaceVariant,
                                fontWeight: state.routePlan != null ? FontWeight.w700 : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (state.routePlan != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: AppColors.onSurfaceVariant),
                              onPressed: controller.clearRoute,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // POI Layer Toggles
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _LayerChip(
                            label: 'Safety Zones',
                            icon: Icons.shield_outlined,
                            isActive: state.showSafetyZones,
                            activeColor: AppColors.primaryPulse,
                            onTap: controller.toggleSafetyZones,
                          ),
                          const SizedBox(width: 6),
                          _LayerChip(
                            label: 'Police',
                            icon: Icons.local_police_outlined,
                            isActive: state.showPolice,
                            activeColor: AppColors.police,
                            onTap: controller.togglePolice,
                          ),
                          const SizedBox(width: 6),
                          _LayerChip(
                            label: 'Hospitals',
                            icon: Icons.local_hospital_outlined,
                            isActive: state.showHospitals,
                            activeColor: AppColors.hospital,
                            onTap: controller.toggleHospitals,
                          ),
                          const SizedBox(width: 6),
                          _LayerChip(
                            label: 'Metro',
                            icon: Icons.directions_subway_outlined,
                            isActive: state.showStations,
                            activeColor: AppColors.tertiary,
                            onTap: controller.toggleStations,
                          ),
                        ],
                      ),
                    ),
                    // Quick Destination Carousel (when no active route is planned)
                    if (state.routePlan == null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _QuickDestChip(
                              label: 'Besant Nagar Beach',
                              icon: Icons.beach_access,
                              onTap: () => controller.planRouteTo(
                                destLat: 13.0001,
                                destLng: 80.2667,
                                destName: 'Besant Nagar Beach',
                              ),
                            ),
                            const SizedBox(width: 6),
                            _QuickDestChip(
                              label: 'Marina Beach',
                              icon: Icons.waves,
                              onTap: () => controller.planRouteTo(
                                destLat: 13.0556,
                                destLng: 80.2821,
                                destName: 'Marina Beach Promenade',
                              ),
                            ),
                            const SizedBox(width: 6),
                            _QuickDestChip(
                              label: 'Central Railway',
                              icon: Icons.train,
                              onTap: () => controller.planRouteTo(
                                destLat: 13.0827,
                                destLng: 80.2756,
                                destName: 'Chennai Central Station',
                              ),
                            ),
                            const SizedBox(width: 6),
                            _QuickDestChip(
                              label: 'Phoenix Mall',
                              icon: Icons.shopping_bag,
                              onTap: () => controller.planRouteTo(
                                destLat: 12.9912,
                                destLng: 80.2178,
                                destName: 'Phoenix Marketcity',
                              ),
                            ),
                            const SizedBox(width: 6),
                            _QuickDestChip(
                              label: 'T. Nagar Hub',
                              icon: Icons.storefront,
                              onTap: () => controller.planRouteTo(
                                destLat: 13.0412,
                                destLng: 80.2345,
                                destName: 'T. Nagar Commercial Hub',
                              ),
                            ),
                            const SizedBox(width: 6),
                            _QuickDestChip(
                              label: 'Guindy Metro',
                              icon: Icons.subway,
                              onTap: () => controller.planRouteTo(
                                destLat: 13.0078,
                                destLng: 80.2134,
                                destName: 'Guindy Metro Station',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Real-time route planning indicator
                    if (state.isLoading) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHighest.withValues(alpha: 0.95),
                          borderRadius: AppRadius.borderFull,
                          border: Border.all(color: AppColors.primaryPulse.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryPulse),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Evaluating safe routes with real-time risk avoidance...',
                              style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.primaryPulse,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Error message banner if route calculation failed
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      GlassCard(
                        color: AppColors.errorContainer.withValues(alpha: 0.92),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: AppColors.onErrorContainer),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                state.errorMessage!,
                                style: AppTextStyles.bodySm.copyWith(color: AppColors.onErrorContainer, fontSize: 11),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16, color: AppColors.onErrorContainer),
                              onPressed: controller.clearRoute,
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Sheets / Route Comparison Card / Detail Sheets
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  0,
                  AppSpacing.gutter,
                  MediaQuery.paddingOf(context).bottom + AppSpacing.bottomNavHeight + AppSpacing.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // If a Safety Zone is Selected
                    if (state.selectedZone != null) ...[
                      SafetyZoneDetailSheet(
                        zone: state.selectedZone!,
                        onClose: controller.clearSelectedZone,
                      ).animate().slideY(begin: 0.2, duration: 250.ms).fadeIn(),
                    ]
                    // If a Police Station is Selected
                    else if (state.selectedPolice != null) ...[
                      PoliceStationDetailSheet(
                        police: state.selectedPolice!,
                        onClose: controller.clearSelectedPolice,
                      ).animate().slideY(begin: 0.2, duration: 250.ms).fadeIn(),
                    ]
                    // If a Route Plan is Active
                    else if (state.routePlan != null) ...[
                      GuardianRouteComparisonCard(
                        plan: state.routePlan!,
                        selectedIndex: state.selectedAlternativeIndex,
                        onSelectIndex: controller.selectAlternative,
                        isNavigating: false,
                        navigationProgress: 0.0,
                        onClearRoute: controller.clearRoute,
                        onStopNavigation: controller.stopNavigation,
                        onStartNavigation: () {
                          final active = state.activeRoute;
                          final plan = state.routePlan!;
                          final userPos = state.userLocation;

                          context.push(
                            RoutePaths.journeyConfirmation,
                            extra: {
                              'destinationName': plan.destinationName,
                              'destLat': plan.destLat,
                              'destLng': plan.destLng,
                              'originLat': userPos?.lat ?? plan.originLat,
                              'originLng': userPos?.lng ?? plan.originLng,
                              'routeName': active?.role.toUpperCase() ?? 'Safer Route',
                              'safetyScore': active?.safetyScore ?? 88,
                              'estimatedDistanceKm': active?.distanceKm ?? 3.2,
                              'estimatedMinutes': active?.durationMinutes ?? 15,
                              'routePoints': active?.points ?? const [],
                            },
                          );
                        },
                      ).animate().slideY(begin: 0.3, duration: 300.ms).fadeIn(),
                    ]
                    // Default State: Plan a Route CTA & Quick SOS
                    else ...[
                      GlassCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryPulse,
                                  foregroundColor: AppColors.white,
                                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderFull),
                                ),
                                icon: const Icon(AppIcons.search, size: 16),
                                label: const Text('Search Destination'),
                                onPressed: () => _openDestinationPicker(context, controller),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: AppColors.white,
                                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderFull),
                                ),
                                icon: const Icon(AppIcons.sos, size: 16),
                                label: const Text('EMERGENCY SOS'),
                                onPressed: () => showEmergencySosModal(
                                  context: context,
                                  ref: ref,
                                  triggerSource: 'map_quick_sos',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Loading overlay
            if (state.isLoading)
              Container(
                color: Colors.black38,
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryPulse),
                ),
              ),
          ],
        ),
      );
  }

  void _openDestinationPicker(BuildContext context, GuardianMapController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DestinationSearchSheet(
        onClose: () => Navigator.of(ctx).pop(),
        onSelectDestination: (lat, lng, name, mode) {
          Navigator.of(ctx).pop();
          controller.planRouteTo(
            destLat: lat,
            destLng: lng,
            destName: name,
            travelMode: mode,
          );
        },
      ),
    );
  }
}

class _LayerChip extends StatelessWidget {
  const _LayerChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderFull,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.2)
              : AppColors.surfaceContainerHigh.withValues(alpha: 0.85),
          borderRadius: AppRadius.borderFull,
          border: Border.all(
            color: isActive ? activeColor : AppColors.glassBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? activeColor : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.labelSm.copyWith(
                color: isActive ? activeColor : AppColors.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickDestChip extends StatelessWidget {
  const _QuickDestChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderFull,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest.withValues(alpha: 0.9),
          borderRadius: AppRadius.borderFull,
          border: Border.all(
            color: AppColors.primaryPulse.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primaryPulse),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
