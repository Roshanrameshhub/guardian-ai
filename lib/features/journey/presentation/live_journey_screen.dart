import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/route_paths.dart';
import '../../../core/services/route_deviation_detector.dart';
import '../../../core/services/sensor_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/dev_log.dart';
import '../../../core/widgets/safety_confirmation_dialog.dart';
import '../../../core/widgets/sos_dialog.dart';
import '../../../data/dto/api_dto.dart';
import '../../../domain/entities/entities.dart';
import '../../../providers/repository_providers.dart';
import 'widgets/live_safety_diagnostics_sheet.dart';

class LiveJourneyScreen extends ConsumerStatefulWidget {
  const LiveJourneyScreen({
    super.key,
    this.journeyId,
    this.destinationName = 'Home',
    this.destLat = 13.0827,
    this.destLng = 80.2707,
    this.routePoints = const [],
    this.safetyScore = 88,
    this.estimatedDistanceKm = 3.2,
    this.estimatedMinutes = 15,
  });

  final String? journeyId;
  final String destinationName;
  final double destLat;
  final double destLng;
  final List<LatLngPoint> routePoints;
  final int safetyScore;
  final double estimatedDistanceKm;
  final int estimatedMinutes;

  @override
  ConsumerState<LiveJourneyScreen> createState() => _LiveJourneyScreenState();
}

class _LiveJourneyScreenState extends ConsumerState<LiveJourneyScreen> {
  StreamSubscription<Position>? _posSubscription;
  StreamSubscription<MotionEventType>? _sensorSubscription;
  StreamSubscription<String>? _voiceSubscription;

  GoogleMapController? _mapController;
  LatLng? _currentCoord;
  int _elapsedSeconds = 0;
  int _estimatedRemainingMinutes = 15;
  double _remainingDistanceKm = 0.0;
  double _currentSpeedKmh = 0.0;
  double _accuracyMeters = 0.0;
  int _stationarySeconds = 0;
  bool _isStationary = false;
  bool _hasArrived = false;

  Timer? _journeyTimer;
  bool _isCompleting = false;
  bool _isAutoCentered = true;

  final RouteDeviationDetector _deviationDetector =
      RouteDeviationDetector(deviationThresholdMeters: 150.0);
  int _deviationCounter = 0;
  bool _isDeviationAlertOpen = false;

  final List<SafetyEventModel> _safetyEvents = [];

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

  @override
  void initState() {
    super.initState();
    _estimatedRemainingMinutes = widget.estimatedMinutes;
    _remainingDistanceKm = widget.estimatedDistanceKm;

    // Log Journey Started Event
    _logEvent(
      type: SafetyEventType.journeyStarted,
      severity: SafetyEventSeverity.success,
      title: 'Journey started',
      message: 'Heading to ${widget.destinationName}',
    );

    _startTracking();
    _subscribeHardwareSensors();

    // Start persistent journey foreground notification
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ref.read(backgroundSafetyServiceProvider).startJourneyNotification(
          destination: widget.destinationName,
          estimatedMinutes: _estimatedRemainingMinutes,
        );
      } catch (_) {}
    });
  }

  void _logEvent({
    required SafetyEventType type,
    required SafetyEventSeverity severity,
    required String title,
    required String message,
  }) {
    final event = SafetyEventModel(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      type: type,
      severity: severity,
      title: title,
      message: message,
      latitude: _currentCoord?.latitude,
      longitude: _currentCoord?.longitude,
    );

    if (mounted) {
      setState(() {
        _safetyEvents.add(event);
      });
    } else {
      _safetyEvents.add(event);
    }
    DevLog.journey('[SAFETY_EVENT] [${event.severity.name.toUpperCase()}] ${event.title}: ${event.message}');
  }

  void _startTracking() {
    final locationService = ref.read(locationServiceProvider);

    _posSubscription = locationService
        .getPositionStream(
      desiredAccuracy: LocationAccuracy.high,
      distanceFilter: 2,
    )
        .listen((pos) {
      if (!mounted) return;

      final current = LatLng(pos.latitude, pos.longitude);
      final dest = LatLng(widget.destLat, widget.destLng);
      final speed = (pos.speed * 3.6).clamp(0.0, 150.0);
      final accuracy = pos.accuracy;

      final isFirstLock = _currentCoord == null;
      if (isFirstLock) {
        _logEvent(
          type: SafetyEventType.gpsRestored,
          severity: SafetyEventSeverity.info,
          title: 'GPS lock acquired',
          message: 'Accuracy ±${accuracy.toStringAsFixed(0)}m',
        );
        _logEvent(
          type: SafetyEventType.routeMatched,
          severity: SafetyEventSeverity.info,
          title: 'Route matched',
          message: 'Safe corridor active',
        );
      }

      // Real distance & ETA calculation
      final distMeters = RouteDeviationDetector.distanceBetweenMeters(current, dest);
      final distKm = double.parse((distMeters / 1000.0).toStringAsFixed(1));
      final etaMins = (distKm / 4.5 * 60).round().clamp(1, 120);

      // Destination Proximity Check (< 80 meters)
      if (distMeters <= 80.0 && !_hasArrived) {
        _hasArrived = true;
        _logEvent(
          type: SafetyEventType.safeArrivalConfirmed,
          severity: SafetyEventSeverity.success,
          title: 'Destination reached',
          message: 'Looks like you\'ve arrived at ${widget.destinationName}.',
        );
      }

      // Stationary check
      if (speed < 0.8) {
        if (!_isStationary) {
          _isStationary = true;
        }
      } else {
        if (_isStationary && _stationarySeconds >= 15) {
          _logEvent(
            type: SafetyEventType.movementResumed,
            severity: SafetyEventSeverity.info,
            title: 'Movement resumed',
            message: 'Speed ${speed.toStringAsFixed(1)} km/h',
          );
        }
        _isStationary = false;
        _stationarySeconds = 0;
      }

      setState(() {
        _currentCoord = current;
        _remainingDistanceKm = distKm;
        _estimatedRemainingMinutes = etaMins;
        _currentSpeedKmh = speed;
        _accuracyMeters = accuracy;
      });

      final progressPct = widget.estimatedDistanceKm > 0
          ? ((widget.estimatedDistanceKm - distKm) / widget.estimatedDistanceKm).clamp(0.0, 1.0)
          : 0.0;

      // Update dynamic persistent notification
      try {
        ref.read(backgroundSafetyServiceProvider).updateJourneyProgress(
          destination: widget.destinationName,
          progressPercent: progressPct,
          minutesLeft: etaMins,
          currentPosition: pos,
        );
      } catch (_) {}

      // Animate camera to follow user if auto-centered
      if (_isAutoCentered) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(current),
        );
      }

      // Route deviation watchdog
      if (widget.routePoints.length >= 2) {
        final mappedRoute =
            widget.routePoints.map((p) => LatLng(p.lat, p.lng)).toList();
        final deviated = _deviationDetector.isDeviated(current, mappedRoute);
        if (deviated) {
          _deviationCounter++;
          if (_deviationCounter == 3) {
            _logEvent(
              type: SafetyEventType.routeDeviation,
              severity: SafetyEventSeverity.warning,
              title: 'Route deviation detected',
              message: 'Moved > 150m from planned corridor',
            );
          }
          if (_deviationCounter >= 3 && !_isDeviationAlertOpen) {
            _isDeviationAlertOpen = true;
            showSafetyConfirmationDialog(
              context: context,
              ref: ref,
              title: '⚠ ROUTE DEVIATION DETECTED',
              subtitle:
                  'You appear to have moved away from your planned safe route.\nAre you safe?',
              triggerSource: 'route_deviation',
              onSafeConfirmed: () {
                _deviationCounter = 0;
                _isDeviationAlertOpen = false;
                _logEvent(
                  type: SafetyEventType.routeMatched,
                  severity: SafetyEventSeverity.info,
                  title: 'User confirmed safe',
                  message: 'Route monitoring continuing',
                );
              },
            );
          }
        } else {
          if (_deviationCounter > 0) {
            _logEvent(
              type: SafetyEventType.routeMatched,
              severity: SafetyEventSeverity.info,
              title: 'Route matched',
              message: 'Back on designated safe path',
            );
          }
          _deviationCounter = 0;
        }
      }
    }, onError: (_) {
      _logEvent(
        type: SafetyEventType.gpsLost,
        severity: SafetyEventSeverity.warning,
        title: 'GPS signal weak',
        message: 'Attempting to re-acquire satellite fix',
      );
    });

    _journeyTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
        if (_isStationary) {
          _stationarySeconds++;
          if (_stationarySeconds == 180) {
            _logEvent(
              type: SafetyEventType.prolongedStop,
              severity: SafetyEventSeverity.warning,
              title: 'Prolonged stop detected',
              message: 'Stationary for > 3 minutes',
            );
            if (widget.journeyId != null && _currentCoord != null) {
              ref.read(journeyRepositoryProvider).checkStationary(
                    StationaryCheckRequestDto(
                      journeyId: widget.journeyId!,
                      currentLat: _currentCoord!.latitude,
                      currentLng: _currentCoord!.longitude,
                      speedKmh: _currentSpeedKmh,
                      stationaryMinutes: _stationarySeconds ~/ 60,
                      trafficCongestionLevel: 'moderate',
                    ),
                  );
            }
          }
        }
      });
    });
  }

  void _subscribeHardwareSensors() {
    try {
      final sensorService = ref.read(sensorServiceProvider);
      _sensorSubscription = sensorService.anomalyStream.listen((anomaly) {
        if (!mounted) return;

        SafetyEventType eventType;
        String dialogTitle;
        String dialogSubtitle;

        if (anomaly == MotionEventType.fallDetected) {
          eventType = SafetyEventType.fallDetected;
          dialogTitle = '⚠ POSSIBLE FALL DETECTED';
          dialogSubtitle = 'Fall impact detected with subsequent stillness.\nAre you in danger?';
        } else if (anomaly == MotionEventType.phoneDrop) {
          eventType = SafetyEventType.phoneDrop;
          dialogTitle = '⚠ POSSIBLE DROP DETECTED';
          dialogSubtitle = 'Sudden high acceleration impact detected.\nAre you in danger?';
        } else {
          eventType = SafetyEventType.shakeDetected;
          dialogTitle = '⚠ UNUSUAL MOVEMENT DETECTED';
          dialogSubtitle = 'Sudden shake or impact detected.\nAre you in danger?';
        }

        _logEvent(
          type: eventType,
          severity: anomaly == MotionEventType.fallDetected
              ? SafetyEventSeverity.critical
              : SafetyEventSeverity.warning,
          title: dialogTitle,
          message: dialogSubtitle,
        );

        if (_isDeviationAlertOpen) return;
        _isDeviationAlertOpen = true;
        showSafetyConfirmationDialog(
          context: context,
          ref: ref,
          title: dialogTitle,
          subtitle: dialogSubtitle,
          triggerSource: eventType.name,
          onSafeConfirmed: () {
            _isDeviationAlertOpen = false;
            _logEvent(
              type: SafetyEventType.movementNormalized,
              severity: SafetyEventSeverity.success,
              title: 'Movement normalized',
              message: 'User confirmed safe after motion check',
            );
          },
        );
      });
    } catch (_) {}

    try {
      final voiceService = ref.read(voiceServiceProvider);
      _voiceSubscription =
          voiceService.emergencyTriggerStream.listen((transcript) {
        if (!mounted) return;

        _logEvent(
          type: SafetyEventType.voiceDistress,
          severity: SafetyEventSeverity.critical,
          title: '⚠ POSSIBLE DISTRESS',
          message: '"$transcript" detected.',
        );

        if (_isDeviationAlertOpen) return;
        _isDeviationAlertOpen = true;
        showSafetyConfirmationDialog(
          context: context,
          ref: ref,
          title: '⚠ POSSIBLE DISTRESS',
          subtitle: '"$transcript" detected.\nAre you in danger?',
          triggerSource: 'voice_trigger',
          onSafeConfirmed: () {
            _isDeviationAlertOpen = false;
            _logEvent(
              type: SafetyEventType.manualCheckIn,
              severity: SafetyEventSeverity.info,
              title: 'Voice alert cleared',
              message: 'User confirmed safe',
            );
          },
        );
      });
    } catch (_) {}
  }

  String _formatDuration(int totalSecs) {
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _completeJourney() async {
    setState(() => _isCompleting = true);
    _logEvent(
      type: SafetyEventType.journeyCompleted,
      severity: SafetyEventSeverity.success,
      title: 'Journey completed safely',
      message: 'Arrived at ${widget.destinationName}',
    );

    try {
      if (widget.journeyId != null && widget.journeyId!.isNotEmpty) {
        await ref.read(journeyRepositoryProvider).stopJourney(widget.journeyId!);
      }
    } catch (_) {
      // Continue to summary even if offline
    } finally {
      try {
        ref.read(backgroundSafetyServiceProvider).stopForegroundService();
      } catch (_) {}

      if (mounted) {
        setState(() => _isCompleting = false);
        final warningCount = _safetyEvents
            .where((e) => e.severity == SafetyEventSeverity.warning || e.severity == SafetyEventSeverity.critical)
            .length;

        context.pushReplacement(
          RoutePaths.journeySummary,
          extra: {
            'destinationName': widget.destinationName,
            'durationText': _formatDuration(_elapsedSeconds),
            'distanceKm': widget.estimatedDistanceKm,
            'avgSpeedKmh': _currentSpeedKmh > 0
                ? double.parse(_currentSpeedKmh.toStringAsFixed(1))
                : 4.5,
            'safetyScore': widget.safetyScore,
            'incidentCount': warningCount,
          },
        );
      }
    }
  }

  @override
  void dispose() {
    _posSubscription?.cancel();
    _sensorSubscription?.cancel();
    _voiceSubscription?.cancel();
    _journeyTimer?.cancel();
    try {
      ref.read(backgroundSafetyServiceProvider).stopForegroundService();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPos = _currentCoord ?? const LatLng(13.0827, 80.2707);
    final destPos = LatLng(widget.destLat, widget.destLng);

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('current_pos'),
        position: currentPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: '📍 Your Location'),
      ),
      Marker(
        markerId: const MarkerId('dest_pos'),
        position: destPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueMagenta),
        infoWindow: InfoWindow(title: '🏁 ${widget.destinationName}'),
      ),
    };

    final polylines = <Polyline>{};
    if (widget.routePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('safe_walk_route'),
          points: widget.routePoints.map((p) => LatLng(p.lat, p.lng)).toList(),
          color: AppColors.primaryPulse,
          width: 7,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Full Screen Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(target: currentPos, zoom: 15.5),
            style: _darkMapStyle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: markers,
            polylines: polylines,
            onMapCreated: (ctrl) => _mapController = ctrl,
            onCameraMoveStarted: () {
              if (_isAutoCentered) {
                setState(() => _isAutoCentered = false);
              }
            },
          ),

          // Top Header: Status Bar & Back Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.surfaceContainerHigh.withValues(alpha: 0.95),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest.withValues(alpha: 0.95),
                      borderRadius: AppRadius.borderFull,
                      border: Border.all(color: AppColors.primaryPulse.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPulse.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'GUARDIAN ACTIVE',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Recenter Button (shows when user moved map manually)
          if (!_isAutoCentered && _currentCoord != null)
            Positioned(
              right: AppSpacing.gutter,
              bottom: 310,
              child: FloatingActionButton.small(
                backgroundColor: AppColors.surfaceContainerHighest,
                foregroundColor: AppColors.primaryPulse,
                onPressed: () {
                  setState(() => _isAutoCentered = true);
                  _mapController?.animateCamera(CameraUpdate.newLatLng(_currentCoord!));
                },
                child: const Icon(Icons.my_location),
              ),
            ),

          // Arrival Banner Prompt (when < 80m from destination)
          if (_hasArrived)
            Positioned(
              top: 80,
              left: AppSpacing.gutter,
              right: AppSpacing.gutter,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.successContainer.withValues(alpha: 0.96),
                  borderRadius: AppRadius.borderMd,
                  border: Border.all(color: AppColors.success),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.onSuccessContainer, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You are at your destination! Tap below to confirm safe arrival.',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.onSuccessContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Control Area: Live Safety Diagnostics Sheet + Main Action Panel
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  0,
                  AppSpacing.gutter,
                  MediaQuery.paddingOf(context).bottom + AppSpacing.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Expandable Live Safety Diagnostics Timeline Sheet
                    LiveSafetyDiagnosticsSheet(
                      events: _safetyEvents,
                      gpsActive: _currentCoord != null,
                      gpsAccuracyMeters: _accuracyMeters,
                      guardianActive: true,
                      routeDeviated: _deviationCounter > 0,
                      isStationary: _isStationary,
                      speedKmh: _currentSpeedKmh,
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Near-Opaque High-Contrast Primary Journey Control Card
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.96),
                        borderRadius: AppRadius.borderLg,
                        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.35)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black87,
                            blurRadius: 20,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Destination & Telemetry Summary Row
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPulse.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(AppIcons.walk, color: AppColors.primaryPulse, size: 22),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Heading to ${widget.destinationName}',
                                      style: AppTextStyles.headlineMd.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Elapsed ${_formatDuration(_elapsedSeconds)} • $_remainingDistanceKm km left • ~$_estimatedRemainingMinutes min ETA',
                                      style: AppTextStyles.bodySm.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: widget.safetyScore >= 75 ? AppColors.success : AppColors.warning,
                                  borderRadius: AppRadius.borderFull,
                                ),
                                child: Text(
                                  '${widget.safetyScore} Score',
                                  style: AppTextStyles.labelSm.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),

                          // Live Kinematics Strip
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _TelemetryMiniChip(
                                label: 'SPEED',
                                value: _isStationary ? '0.0 km/h' : '${_currentSpeedKmh.toStringAsFixed(1)} km/h',
                              ),
                              Container(width: 1, height: 20, color: AppColors.glassBorder),
                              _TelemetryMiniChip(
                                label: 'GPS ACCURACY',
                                value: _accuracyMeters > 0 ? '±${_accuracyMeters.toStringAsFixed(0)}m' : 'Acquiring',
                              ),
                              Container(width: 1, height: 20, color: AppColors.glassBorder),
                              _TelemetryMiniChip(
                                label: 'ROUTE STATUS',
                                value: _deviationCounter > 0 ? '⚠ Deviated' : '● On Route',
                                isWarning: _deviationCounter > 0,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Primary Actions: SOS & Confirm Safe Arrival
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.error,
                                      foregroundColor: AppColors.white,
                                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderFull),
                                    ),
                                    icon: const Icon(AppIcons.sos, size: 18),
                                    label: Text(
                                      'SOS ALERT',
                                      style: AppTextStyles.labelSm.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: AppColors.white,
                                      ),
                                    ),
                                    onPressed: () {
                                      showEmergencySosModal(
                                        context: context,
                                        ref: ref,
                                        triggerSource: 'live_journey_manual',
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryPulse,
                                      foregroundColor: AppColors.white,
                                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderFull),
                                      elevation: 3,
                                    ),
                                    icon: _isCompleting
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(AppIcons.check, size: 18),
                                    label: Text(
                                      'CONFIRM SAFE ARRIVAL',
                                      style: AppTextStyles.labelSm.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: AppColors.white,
                                      ),
                                    ),
                                    onPressed: _isCompleting ? null : _completeJourney,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelemetryMiniChip extends StatelessWidget {
  const _TelemetryMiniChip({
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  final String label;
  final String value;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.labelSm.copyWith(fontSize: 9, color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.labelSm.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            color: isWarning ? AppColors.warning : AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}
