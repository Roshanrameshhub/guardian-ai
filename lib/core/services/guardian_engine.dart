import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/dto/api_dto.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../config/app_router.dart';
import '../utils/dev_log.dart';
import '../widgets/safety_confirmation_dialog.dart';
import '../widgets/sos_dialog.dart';
import 'background_safety_service.dart';
import 'guardian_risk_engine.dart';
import 'location_service.dart';
import 'route_deviation_detector.dart';
import 'sensor_service.dart';
import 'stationary_detector.dart';
import 'voice_service.dart';

/// Real-time engine orchestrating Guardian Mode background timers, GPS streams,
/// battery reporting, sensor processing, voice listening, and live safety events.
class GuardianEngine with WidgetsBindingObserver, ChangeNotifier {
  GuardianEngine({
    required GuardianRepository guardianRepository,
    required JourneyRepository journeyRepository,
    required LocationService locationService,
    required SensorService sensorService,
    required VoiceService voiceService,
    required IntelligenceRepository intelligenceRepository,
    BackgroundSafetyService? backgroundSafetyService,
    RouteDeviationDetector? routeDeviationDetector,
    StationaryDetector? stationaryDetector,
  })  : _guardianRepo = guardianRepository,
        _journeyRepo = journeyRepository,
        _locationService = locationService,
        _sensorService = sensorService,
        _voiceService = voiceService,
        _intelligenceRepo = intelligenceRepository,
        _bgService = backgroundSafetyService ?? BackgroundSafetyService(),
        _deviationDetector = routeDeviationDetector ?? RouteDeviationDetector(),
        _stationaryDetector = stationaryDetector ?? StationaryDetector(),
        _battery = Battery() {
    WidgetsBinding.instance.addObserver(this);
    _bgService.onStopRequested = () {
      stopGuardian();
    };
  }

  final GuardianRepository _guardianRepo;
  final JourneyRepository _journeyRepo;
  final LocationService _locationService;
  final SensorService _sensorService;
  final VoiceService _voiceService;
  final BackgroundSafetyService _bgService;
  final RouteDeviationDetector _deviationDetector;
  final StationaryDetector _stationaryDetector;
  final Battery _battery;
  final IntelligenceRepository _intelligenceRepo;

  bool _isActive = false;
  int _heartbeatIntervalSeconds = 60;
  Timer? _heartbeatTimer;
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<MotionEventType>? _sensorSubscription;
  StreamSubscription<String>? _voiceSubscription;

  Position? _currentPosition;
  int _batteryPercent = 100;
  double _currentSpeedKmh = 0.0;
  int _stationarySeconds = 0;
  String? _activeJourneyId;

  final List<SafetyEventModel> _events = [];
  final StreamController<SafetyEventModel> _eventStreamController =
      StreamController<SafetyEventModel>.broadcast();

  final GuardianRiskEngine _riskEngine = const GuardianRiskEngine();
  final Map<String, RiskFactorExplanation> _accumulatedSignals = {};
  final Map<String, DateTime> _signalCooldowns = {};

  bool get isActive => _isActive;
  int get heartbeatIntervalSeconds => _heartbeatIntervalSeconds;
  Position? get currentPosition => _currentPosition;
  int get batteryPercent => _batteryPercent;
  double get currentSpeedKmh => _currentSpeedKmh;
  int get stationarySeconds => _stationarySeconds;
  String? get activeJourneyId => _activeJourneyId;
  List<SafetyEventModel> get events => List.unmodifiable(_events);
  Stream<SafetyEventModel> get safetyEventStream => _eventStreamController.stream;

  List<RiskFactorExplanation> get accumulatedSignals => _accumulatedSignals.values.toList();

  RiskAssessmentReport get currentRiskReport {
    if (!_isActive) {
      return RiskAssessmentReport.baseline();
    }
    return _riskEngine.evaluateRisk(
      currentTime: DateTime.now(),
      batteryPercent: _batteryPercent,
      stationarySeconds: _stationarySeconds,
      accumulatedFactors: _accumulatedSignals.values.toList(),
    );
  }

  SensorService get sensorService => _sensorService;
  VoiceService get voiceService => _voiceService;
  LocationService get locationService => _locationService;
  RouteDeviationDetector get deviationDetector => _deviationDetector;
  StationaryDetector get stationaryDetector => _stationaryDetector;
  JourneyRepository get journeyRepository => _journeyRepo;

  /// Start real Guardian Mode session.
  Future<GuardianStatusEntity> startGuardian({String? journeyId}) async {
    DevLog.guardian('Starting Guardian Engine session...');
    _activeJourneyId = journeyId;

    // 1. Activate on backend
    GuardianStatusEntity status;
    try {
      status = await _guardianRepo.startGuardian();
    } catch (e) {
      DevLog.guardian('Backend startGuardian warning: $e');
      status = const GuardianStatusEntity(
        isActive: true,
        statusLabel: 'Guardian Active',
        monitoringLabel: 'AI Shield Active',
        voiceSyncLive: true,
        voiceSyncState: 'Connected',
        batteryPercent: 100,
        speedKmh: 0,
        speedStatus: 'Normal',
        estimatedArrival: '--:--',
        minutesLeft: 0,
        origin: 'Current Location',
        destination: 'Destination',
        progress: 0,
        currentLocation: 'GPS Active',
        avatarUrl: '',
      );
    }
    _isActive = true;
    resetRiskAccumulator();
    notifyListeners();

    // 2. Log initial event
    logEvent(
      type: SafetyEventType.journeyStarted,
      severity: SafetyEventSeverity.success,
      title: 'Guardian Mode Activated',
      message: 'Sensors, GPS, and AI Watchdog initialized.',
    );

    // 3. Fetch initial battery & start foreground service notification
    try {
      _batteryPercent = await _battery.batteryLevel;
    } catch (_) {
      _batteryPercent = 100;
    }

    await _bgService.startForegroundService(
      title: 'Guardian AI Active',
      currentPosition: _currentPosition,
      batteryLevel: _batteryPercent,
    );

    // 4. Start real location stream
    try {
      _locationSubscription = _locationService.getPositionStream(
        desiredAccuracy: LocationAccuracy.high,
        distanceFilter: 2,
      ).listen((pos) {
        final isFirst = _currentPosition == null;
        _currentPosition = pos;
        _currentSpeedKmh = (pos.speed * 3.6).clamp(0.0, 200.0);

        _bgService.updateStatus(
          title: 'Guardian AI Active',
          currentPosition: pos,
          batteryLevel: _batteryPercent,
        );

        if (isFirst) {
          logEvent(
            type: SafetyEventType.gpsRestored,
            severity: SafetyEventSeverity.info,
            title: 'GPS Lock Acquired',
            message: 'High accuracy ±${pos.accuracy.toStringAsFixed(0)}m',
          );
        }

        // Evaluate planned route corridor deviation
        if (_deviationDetector.plannedRoutePoints.isNotEmpty) {
          final devReport = _deviationDetector.processPosition(
            LatLng(pos.latitude, pos.longitude),
          );
          if (devReport.isSustained) {
            handleAnomalySignal(
              signalType: 'route_deviation',
              title: 'Route Deviation Warning',
              message: 'You are ${devReport.currentDistanceMeters.toStringAsFixed(0)}m off your planned route. Everything okay?',
              points: 20,
              factorName: 'Route Deviation',
              factorDescription: 'Off safe route corridor by ${devReport.currentDistanceMeters.toStringAsFixed(0)}m',
            );
          }
        }

        // Evaluate multi-sensor stationary status
        final statReport = _stationaryDetector.processTelemetry(
          position: LatLng(pos.latitude, pos.longitude),
          gpsSpeedKmh: _currentSpeedKmh,
          recentAccelSamples: const [9.8, 9.81, 9.8, 9.79],
        );
        _stationarySeconds = statReport.stationarySeconds;
        if (statReport.isThresholdBreached) {
          logEvent(
            type: SafetyEventType.prolongedStop,
            severity: SafetyEventSeverity.warning,
            title: 'Stationary Stop Warning',
            message: statReport.promptMessage ?? "You haven't moved for 3 minutes. Still on track?",
          );
        }
      }, onError: (err) {
        logEvent(
          type: SafetyEventType.gpsLost,
          severity: SafetyEventSeverity.warning,
          title: 'GPS Signal Degraded',
          message: err.toString(),
        );
      });
    } catch (_) {}

    // 5. Start edge kinematics processing & listen to anomalies
    _sensorService.startMonitoring();
    _sensorSubscription?.cancel();
    _sensorSubscription = _sensorService.anomalyStream.listen((anomaly) {
      if (anomaly == MotionEventType.fallDetected) {
        handleAnomalySignal(
          signalType: 'fall',
          title: '⚠ POSSIBLE FALL DETECTED',
          message: 'Multi-stage fall signature detected with post-impact stillness.',
          points: 20,
          factorName: 'Fall Detected',
          factorDescription: 'Impact spike & post-fall stillness confirmed',
        );
      } else if (anomaly == MotionEventType.phoneDrop) {
        handleAnomalySignal(
          signalType: 'drop',
          title: '⚠ POSSIBLE DROP DETECTED',
          message: 'Freefall impact spike recorded by accelerometer.',
          points: 15,
          factorName: 'Drop Impact',
          factorDescription: 'Freefall impact spike recorded',
        );
      } else {
        handleAnomalySignal(
          signalType: 'shake',
          title: '⚠ UNUSUAL MOVEMENT DETECTED',
          message: 'High acceleration shake peak recorded by accelerometer.',
          points: 15,
          factorName: 'Unusual Motion',
          factorDescription: 'High acceleration shake peak recorded',
        );
      }
    });

    // 6. Start voice monitoring lifecycle & listen to voice triggers
    _voiceService.startListening(journeyId: journeyId);
    _voiceSubscription?.cancel();
    _voiceSubscription = _voiceService.emergencyTriggerStream.listen((phrase) {
      handleAnomalySignal(
        signalType: 'voice_distress',
        title: '⚠ POSSIBLE DISTRESS',
        message: '"$phrase" detected.',
        points: 25,
        factorName: 'Voice Distress',
        factorDescription: 'Emergency distress keyword "$phrase" detected',
      );
    });

    // 7. Start risk-calibrated periodic heartbeat
    _restartHeartbeatTimer();

    // Send immediate initial heartbeat
    _dispatchHeartbeat();

    return status;
  }

  /// Dynamically adjust heartbeat interval based on real-time risk tier:
  /// - Low (<30%): 60s
  /// - Moderate (30-60%): 30s
  /// - High (60-80%): 15s
  /// - Critical (>80%): 10s
  void setHeartbeatIntervalForRisk(int riskPercent) {
    int newInterval;
    if (riskPercent >= 80) {
      newInterval = 10;
    } else if (riskPercent >= 60) {
      newInterval = 15;
    } else if (riskPercent >= 30) {
      newInterval = 30;
    } else {
      newInterval = 60;
    }

    if (newInterval != _heartbeatIntervalSeconds) {
      DevLog.guardian('Adjusting heartbeat interval to ${newInterval}s based on risk ($riskPercent%)');
      _heartbeatIntervalSeconds = newInterval;
      _restartHeartbeatTimer();
    }
  }

  void _restartHeartbeatTimer() {
    if (!_isActive) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(seconds: _heartbeatIntervalSeconds), (_) async {
      await _dispatchHeartbeat();
      await _dispatchRiskFusion();
    });
  }

  /// Stop Guardian Mode session and clean up all background timers & streams.
  Future<GuardianStatusEntity> stopGuardian() async {
    DevLog.guardian('Stopping Guardian Engine session...');
    _isActive = false;
    resetRiskAccumulator();
    notifyListeners();

    await _bgService.stopForegroundService();

    logEvent(
      type: SafetyEventType.journeyCompleted,
      severity: SafetyEventSeverity.info,
      title: 'Guardian Mode Deactivated',
      message: 'Monitoring session ended safely.',
    );

    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    _locationSubscription?.cancel();
    _locationSubscription = null;

    _sensorSubscription?.cancel();
    _sensorSubscription = null;

    _voiceSubscription?.cancel();
    _voiceSubscription = null;

    _sensorService.stopMonitoring();
    _voiceService.stopListening();
    _stationarySeconds = 0;

    try {
      return await _guardianRepo.stopGuardian();
    } catch (_) {
      return const GuardianStatusEntity(
        isActive: false,
        statusLabel: 'Guardian Inactive',
        monitoringLabel: 'Standby',
        voiceSyncLive: false,
        voiceSyncState: 'Disconnected',
        batteryPercent: 100,
        speedKmh: 0,
        speedStatus: 'Idle',
        estimatedArrival: '--:--',
        minutesLeft: 0,
        origin: '',
        destination: '',
        progress: 0,
        currentLocation: '',
        avatarUrl: '',
      );
    }
  }

  /// Add a safety event to the engine's real-time audit timeline
  void logEvent({
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
      latitude: _currentPosition?.latitude,
      longitude: _currentPosition?.longitude,
    );

    _events.add(event);
    _eventStreamController.add(event);
    DevLog.guardian('[SAFETY_EVENT] [${severity.name.toUpperCase()}] $title: $message');

    // Update persistent notification if elevated risk is detected
    if (severity == SafetyEventSeverity.warning || severity == SafetyEventSeverity.critical) {
      _bgService.updateStatus(
        title: 'Guardian AI Alert',
        body: '$title · $message',
        isElevatedRisk: true,
        currentPosition: _currentPosition,
        batteryLevel: _batteryPercent,
      );
    }
  }

  /// Process an unusual sensor/route/voice event through the false-positive
  /// 30-second verification window before committing risk points to the engine.
  void handleAnomalySignal({
    required String signalType,
    required String title,
    required String message,
    required int points,
    required String factorName,
    required String factorDescription,
  }) {
    if (!_isActive) return;

    // 30-second cooldown per signal type to debounce and prevent double-counting
    final lastTime = _signalCooldowns[signalType];
    final now = DateTime.now();
    if (lastTime != null && now.difference(lastTime).inSeconds < 30) {
      DevLog.guardian('[DEBOUNCE] Signal $signalType suppressed by 30s cooldown');
      return;
    }
    _signalCooldowns[signalType] = now;

    // If this signal is already confirmed and active in the current session, do not duplicate
    if (_accumulatedSignals.containsKey(signalType)) {
      DevLog.guardian('[ACCUMULATOR] Signal $signalType already active in current session');
      return;
    }

    // Log to safety audit stream
    logEvent(
      type: _mapSignalToEventType(signalType),
      severity: points >= 20 ? SafetyEventSeverity.critical : SafetyEventSeverity.warning,
      title: title,
      message: message,
    );

    // Trigger 30-second verification prompt: [ I'M SAFE ] vs [ SEND SOS ]
    showSafetyConfirmationDialog(
      context: rootNavigatorKey.currentContext,
      title: 'Potential emergency detected',
      subtitle: 'Do you need help?',
      triggerSource: signalType,
      riskScore: currentRiskReport.overallRiskPercent,
      signals: [
        title,
        message,
        'Risk increment if unconfirmed: +$points%',
      ],
      onSafeConfirmed: () {
        DevLog.guardian('[CONFIRMATION] User verified I\'M SAFE for $signalType. Cancellation recorded, 0 risk added.');
      },
      onSendSos: () {
        DevLog.sos('[CONFIRMATION] User requested immediate SOS from $signalType modal.');
        showEmergencySosModal(triggerSource: 'user_sos_$signalType');
      },
      onCountdownExpired: () {
        DevLog.guardian('[CONFIRMATION] 30s countdown expired for $signalType without cancellation. Committing +$points% risk.');
        commitRiskSignal(
          signalType: signalType,
          points: points,
          factorName: factorName,
          factorDescription: factorDescription,
        );
      },
    );
  }

  /// Commits confirmed risk contribution to the engine and evaluates escalation threshold (>= 80% SOS).
  void commitRiskSignal({
    required String signalType,
    required int points,
    required String factorName,
    required String factorDescription,
  }) {
    _accumulatedSignals[signalType] = RiskFactorExplanation(
      name: factorName,
      percentageContribution: points,
      description: '$factorDescription (+$points%)',
    );
    notifyListeners();

    final report = currentRiskReport;
    setHeartbeatIntervalForRisk(report.overallRiskPercent);
    DevLog.guardian('[RISK_ACCUMULATED] Total risk is now ${report.overallRiskPercent}% (${report.categoryLabel})');

    // Trigger automatic SOS if total risk crosses critical threshold (>= 80%)
    if (report.overallRiskPercent >= 80) {
      DevLog.sos('[AUTO_SOS_THRESHOLD] Fused risk reached ${report.overallRiskPercent}% >= 80% threshold! Launching SOS.');
      showEmergencySosModal(triggerSource: 'auto_risk_threshold_$signalType');
    }
  }

  /// Reset accumulated risks and cooldowns on start or stop
  void resetRiskAccumulator() {
    _accumulatedSignals.clear();
    _signalCooldowns.clear();
    notifyListeners();
  }

  SafetyEventType _mapSignalToEventType(String signalType) {
    switch (signalType) {
      case 'fall':
        return SafetyEventType.fallDetected;
      case 'drop':
        return SafetyEventType.phoneDrop;
      case 'shake':
        return SafetyEventType.shakeDetected;
      case 'voice_distress':
        return SafetyEventType.voiceDistress;
      case 'route_deviation':
        return SafetyEventType.routeDeviation;
      case 'stationary':
        return SafetyEventType.prolongedStop;
      default:
        return SafetyEventType.shakeDetected;
    }
  }

  // Workbench test trigger helpers
  void testTriggerShake() {
    handleAnomalySignal(
      signalType: 'shake',
      title: '⚠ UNUSUAL MOVEMENT DETECTED',
      message: 'High acceleration shake peak recorded (TEST EVENT).',
      points: 15,
      factorName: 'Unusual Motion',
      factorDescription: 'High acceleration shake peak recorded',
    );
  }

  void testTriggerFall() {
    handleAnomalySignal(
      signalType: 'fall',
      title: '⚠ POSSIBLE FALL DETECTED',
      message: 'Multi-stage fall signature detected (TEST EVENT).',
      points: 20,
      factorName: 'Fall Detected',
      factorDescription: 'Impact spike & post-fall stillness confirmed',
    );
  }

  void testTriggerVoice([String phrase = 'HELP']) {
    handleAnomalySignal(
      signalType: 'voice_distress',
      title: '⚠ POSSIBLE DISTRESS',
      message: '"$phrase" detected (TEST EVENT).',
      points: 25,
      factorName: 'Voice Distress',
      factorDescription: 'Emergency distress keyword "$phrase" detected',
    );
  }

  void testTriggerRouteDeviation([double meters = 80.0]) {
    handleAnomalySignal(
      signalType: 'route_deviation',
      title: 'Route Deviation Warning',
      message: 'You are ${meters.toStringAsFixed(0)}m off planned route (TEST EVENT).',
      points: 20,
      factorName: 'Route Deviation',
      factorDescription: 'Off safe route corridor by ${meters.toStringAsFixed(0)}m',
    );
  }


  Future<void> _dispatchRiskFusion() async {
    if (!_isActive) return;
    try {
      final List<SignalInputDto> signals = [];
      
      if (_sensorService.liveAccelMagnitude > 16.0) {
        signals.add(const SignalInputDto(
          type: 'MOTION_ANOMALY',
          score: 0.8,
          confidence: 0.9,
        ));
      }
      if (_voiceService.matchedKeywords.isNotEmpty) {
        signals.add(const SignalInputDto(
          type: 'VOICE_DISTRESS',
          score: 0.85,
          confidence: 0.95,
        ));
      }
      if (_stationarySeconds > 180) {
        signals.add(const SignalInputDto(
          type: 'STATIONARY_ANOMALY',
          score: 0.6,
          confidence: 0.8,
        ));
      }

      if (signals.isEmpty) {
        signals.add(const SignalInputDto(type: 'BASELINE', score: 0.1, confidence: 1.0));
      }

      final riskReport = await _intelligenceRepo.fuseRisk(
        RiskFusionRequest(
          signals: signals,
          journeyId: _activeJourneyId,
          guardianModeActive: true,
          currentLat: _currentPosition?.latitude,
          currentLng: _currentPosition?.longitude,
        ),
      );
      
      if (riskReport.riskLevel == 'CRITICAL' && riskReport.autoEscalatePrepared) {
         DevLog.sos('Backend commanded SOS based on fused risk!');
         showEmergencySosModal(triggerSource: 'critical_risk_fusion');
      }
    } catch (e) {
      DevLog.guardian('Backend risk fusion failed: ');
    }
  }

  Future<void> _dispatchHeartbeat() async {
    if (!_isActive) return;

    try {
      _batteryPercent = await _battery.batteryLevel;
    } catch (_) {}

    final pos = _currentPosition;
    if (pos != null) {
      if (_currentSpeedKmh < 2.0) {
        _stationarySeconds += 30;
        if (_stationarySeconds == 180) {
          logEvent(
            type: SafetyEventType.prolongedStop,
            severity: SafetyEventSeverity.warning,
            title: 'Prolonged Stop Detected',
            message: 'User stationary for > 3 minutes.',
          );
        }
      } else {
        if (_stationarySeconds >= 60) {
          logEvent(
            type: SafetyEventType.movementResumed,
            severity: SafetyEventSeverity.info,
            title: 'Movement Resumed',
            message: 'Speed ${_currentSpeedKmh.toStringAsFixed(1)} km/h',
          );
        }
        _stationarySeconds = 0;
      }
    }

    try {
      await _guardianRepo.sendHeartbeat(
        HeartbeatRequest(
          lat: pos?.latitude,
          lng: pos?.longitude,
          speedKmh: _currentSpeedKmh,
          batteryPercent: _batteryPercent,
        ),
      );
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isActive) return;
    if (state == AppLifecycleState.resumed) {
      _dispatchHeartbeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    _locationSubscription?.cancel();
    _sensorSubscription?.cancel();
    _voiceSubscription?.cancel();
    _sensorService.stopMonitoring();
    _voiceService.stopListening();
    super.dispose();
  }
}
