import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/core/config/api_config.dart';
import 'package:guardian_ai/core/network/api_client.dart';
import 'package:guardian_ai/core/services/token_storage_service.dart';
import 'package:guardian_ai/core/services/sensor_service.dart';
import 'package:guardian_ai/core/services/safety_sensor_manager.dart';
import 'package:guardian_ai/core/services/fall_detector.dart';
import 'package:guardian_ai/core/services/location_service.dart';
import 'package:guardian_ai/core/services/voice_service.dart';
import 'package:guardian_ai/core/services/background_safety_service.dart';
import 'package:guardian_ai/core/services/guardian_risk_engine.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guardian_ai/core/services/guardian_engine.dart';
import 'package:guardian_ai/core/services/false_alarm_manager.dart';
import 'package:guardian_ai/core/services/route_deviation_detector.dart';
import 'package:guardian_ai/core/services/stationary_detector.dart';
import 'package:guardian_ai/core/services/eta_speed_watchdog.dart';
import 'package:guardian_ai/core/services/safe_arrival_detector.dart';
import 'package:guardian_ai/core/services/sos_escalation_engine.dart';
import 'package:guardian_ai/core/services/notification_delivery_service.dart';
import 'package:guardian_ai/core/services/permission_manager.dart';
import 'package:guardian_ai/core/services/safety_score_calculator.dart';
import 'package:guardian_ai/core/services/offline_sync_manager.dart';
import 'package:guardian_ai/data/dto/api_dto.dart';
import 'package:guardian_ai/domain/repositories/repositories.dart';
import 'package:guardian_ai/domain/entities/entities.dart';

class MockIntelligenceRepo implements IntelligenceRepository {
  MotionSignalRequest? lastMotionSignal;

  @override
  Future<MotionAnomalyEntity> sendMotionSignal(MotionSignalRequest request) async {
    lastMotionSignal = request;
    return const MotionAnomalyEntity(
      eventId: 'evt_100',
      eventType: 'SHAKE_DETECTED',
      evaluatedRiskContribution: 0.35,
      confidenceAdjusted: 0.85,
      message: 'Processed',
    );
  }

  @override
  Future<VoiceDistressEntity> sendVoiceAnalysis(VoiceAnalysisRequest request) async {
    return const VoiceDistressEntity(
      signal: 'VOICE_DISTRESS',
      distressScore: 0.1,
      urgency: 'LOW',
      helpKeyword: false,
      repetitionCount: 0,
      voiceIntensity: 0.5,
      modelConfidence: 0.8,
      matchedKeywords: [],
      message: 'OK',
    );
  }

  @override
  Future<RiskAssessmentEntity> fuseRisk(RiskFusionRequest request) async {
    return const RiskAssessmentEntity(
      riskLevel: 'LOW',
      riskScore: 0.1,
      signals: [],
      recommendedAction: 'None',
      requiresUserPrompt: false,
      autoEscalatePrepared: false,
    );
  }

  @override
  Future<ApiMessageResponse> recordFalsePositive(FalsePositiveFeedbackRequest request) async =>
      const ApiMessageResponse(success: true, message: 'Recorded');

  @override
  Future<SafetyCheckInEntity> startCheckIn(CheckInStartRequest request) async =>
      SafetyCheckInEntity(
        id: 'chk_1',
        title: request.title,
        durationMinutes: request.durationMinutes,
        status: 'active',
        startedAt: DateTime.now().toIso8601String(),
        expiresAt: DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
        minutesRemaining: 15,
      );

  @override
  Future<ApiMessageResponse> confirmCheckIn(String checkInId) async =>
      const ApiMessageResponse(success: true, message: 'Confirmed');

  @override
  Future<ApiMessageResponse> cancelCheckIn(String checkInId) async =>
      const ApiMessageResponse(success: true, message: 'Cancelled');

  @override
  Future<List<SafetyCheckInEntity>> fetchCheckIns() async => [];

  @override
  Future<List<SafetyRecommendationEntity>> fetchRecommendations() async => [];
}

class MockGuardianRepo implements GuardianRepository {
  @override
  Future<GuardianStatusEntity> fetchStatus() async => const GuardianStatusEntity(
        isActive: false,
        statusLabel: 'Inactive',
        monitoringLabel: 'Standby',
        voiceSyncLive: false,
        voiceSyncState: 'Disconnected',
        batteryPercent: 100,
        speedKmh: 0,
        speedStatus: 'Normal',
        estimatedArrival: '--:--',
        minutesLeft: 0,
        origin: '',
        destination: '',
        progress: 0,
        currentLocation: '',
        avatarUrl: '',
      );

  @override
  Future<GuardianStatusEntity> startGuardian() async => const GuardianStatusEntity(
        isActive: true,
        statusLabel: 'Active',
        monitoringLabel: 'Monitoring',
        voiceSyncLive: true,
        voiceSyncState: 'Connected',
        batteryPercent: 100,
        speedKmh: 0,
        speedStatus: 'Normal',
        estimatedArrival: '--:--',
        minutesLeft: 0,
        origin: '',
        destination: '',
        progress: 0,
        currentLocation: '',
        avatarUrl: '',
      );

  @override
  Future<GuardianStatusEntity> stopGuardian() async => const GuardianStatusEntity(
        isActive: false,
        statusLabel: 'Inactive',
        monitoringLabel: 'Standby',
        voiceSyncLive: false,
        voiceSyncState: 'Disconnected',
        batteryPercent: 100,
        speedKmh: 0,
        speedStatus: 'Normal',
        estimatedArrival: '--:--',
        minutesLeft: 0,
        origin: '',
        destination: '',
        progress: 0,
        currentLocation: '',
        avatarUrl: '',
      );

  @override
  Future<void> sendHeartbeat(HeartbeatRequest request) async {}

  @override
  Future<ApiMessageResponse> triggerSos(SosRequest request) async =>
      const ApiMessageResponse(success: true, message: 'SOS Triggered');

  @override
  Future<GuardianRoutePlanEntity> calculateSafeRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String? destinationName,
    String travelMode = 'DRIVE',
    String? departureTime,
  }) async =>
      throw UnimplementedError();

  @override
  Future<List<SafetyZoneEntity>> fetchSafetyZones() async => [];

  @override
  Future<List<PoliceStationEntity>> fetchPoliceStations({
    double? lat,
    double? lng,
    int limit = 15,
  }) async =>
      [];

  @override
  Future<NearbyHelpEntity> fetchNearbyHelp({double? lat, double? lng}) async =>
      throw UnimplementedError();
}

class MockJourneyRepo implements JourneyRepository {
  @override
  Future<JourneyEntity> fetchJourney(String id) async => throw UnimplementedError();

  @override
  Future<List<JourneyEntity>> fetchJourneys() async => [];

  @override
  Future<JourneyEntity> startJourney(StartJourneyRequest request) async => throw UnimplementedError();

  @override
  Future<void> stopJourney(String id) async {}

  @override
  Future<void> checkStationary(StationaryCheckRequestDto request) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiConfig Tests', () {

    test('Resolves non-empty default baseUrl', () {
      expect(ApiConfig.baseUrl, isNotEmpty);
      expect(ApiConfig.isConfigured, isTrue);
    });

    test('Custom baseUrl override works', () {
      ApiConfig.setBaseUrl('http://192.168.1.100:8000/api/v1/');
      expect(ApiConfig.baseUrl, 'http://192.168.1.100:8000/api/v1');
      // Reset
      ApiConfig.setBaseUrl('');
    });
  });

  group('TokenStorageService Tests', () {
    test('Saves, retrieves, and clears tokens', () async {
      final storage = InMemoryTokenStorageService();
      expect(await storage.hasValidToken(), isFalse);

      await storage.saveTokens(
        accessToken: 'access_123',
        refreshToken: 'refresh_456',
        userId: 'usr_789',
      );

      expect(await storage.getAccessToken(), 'access_123');
      expect(await storage.getRefreshToken(), 'refresh_456');
      expect(await storage.getUserId(), 'usr_789');
      expect(await storage.hasValidToken(), isTrue);

      await storage.updateAccessToken('access_999');
      expect(await storage.getAccessToken(), 'access_999');

      await storage.clear();
      expect(await storage.getAccessToken(), isNull);
      expect(await storage.hasValidToken(), isFalse);
    });
  });

  group('SensorService Tests', () {
    test('Classifies shake and drop events and dispatches to repository', () async {
      final mockRepo = MockIntelligenceRepo();
      final sensorService = SensorService(
        intelligenceRepository: mockRepo,
        accelerometerStream: const Stream.empty(),
        gyroscopeStream: const Stream.empty(),
      );

      sensorService.startMonitoring();

      expect(sensorService.isMonitoring, isTrue);

      await sensorService.dispatchMotionEvent(
        type: MotionEventType.shakeDetected,
        accelerationPeak: 19.5,
        rotationPeak: 7.2,
      );

      expect(mockRepo.lastMotionSignal, isNotNull);
      expect(mockRepo.lastMotionSignal!.eventType, 'SHAKE_DETECTED');
      expect(mockRepo.lastMotionSignal!.accelerationPeak, 19.5);

      sensorService.stopMonitoring();
      expect(sensorService.isMonitoring, isFalse);
    });
  });

  group('OfflineSyncManager Tests', () {
    test('Queues offline events with idempotency keys', () {
      final client = ApiClient();
      final syncManager = OfflineSyncManager(apiClient: client);

      expect(syncManager.pendingCount, 0);
      syncManager.enqueueEvent(
        idempotencyKey: 'key_1',
        entityType: 'SOS_EVENT',
        payload: {'lat': 13.0827, 'lng': 80.2707},
      );
      expect(syncManager.pendingCount, 1);
    });
  });

  group('DTO Serialization Tests', () {
    test('LoginRequest and RegisterRequest serialize correctly', () {
      const login = LoginRequest(email: 'test@example.com', password: 'password123', rememberMe: true);
      expect(login.toJson(), {
        'email': 'test@example.com',
        'password': 'password123',
        'remember_me': true,
      });

      const register = RegisterRequest(
        fullName: 'Jane Doe',
        email: 'jane@example.com',
        phone: '+91 99999 88888',
        password: 'securePassword!',
      );
      expect(register.toJson(), {
        'full_name': 'Jane Doe',
        'email': 'jane@example.com',
        'phone': '+91 99999 88888',
        'password': 'securePassword!',
      });
    });

    test('SosRequest and StartJourneyRequest serialize real coordinates correctly', () {
      const sos = SosRequest(
        lat: 13.0827,
        lng: 80.2707,
        triggerSource: 'hold_to_alarm',
        message: 'EMERGENCY SOS',
      );
      expect(sos.toJson(), {
        'lat': 13.0827,
        'lng': 80.2707,
        'trigger_source': 'hold_to_alarm',
        'message': 'EMERGENCY SOS',
      });

      const journey = StartJourneyRequest(
        origin: '123 Main St',
        destination: '456 Safe Ave',
        originLat: 13.0827,
        originLng: 80.2707,
      );
      expect(journey.toJson(), {
        'origin': '123 Main St',
        'destination': '456 Safe Ave',
        'origin_lat': 13.0827,
        'origin_lng': 80.2707,
      });
    });

    test('TrustedContactEntity supports copyWith and full attributes', () {
      const contact = TrustedContactEntity(
        id: 'c_1',
        name: 'Sarah Connor',
        avatarUrl: '',
        isOnline: true,
        phone: '+1 555 0199',
        relationshipLabel: 'Mom',
        emergencyNotifyEnabled: true,
        locationShareEnabled: false,
        priority: 1,
      );

      final updated = contact.copyWith(relationshipLabel: 'Parent', priority: 2);
      expect(updated.relationshipLabel, 'Parent');
      expect(updated.priority, 2);
      expect(updated.name, 'Sarah Connor');
      expect(updated.emergencyNotifyEnabled, isTrue);
    });

    test('HeartbeatRequest serializes GPS and battery telemetry correctly', () {
      const hb = HeartbeatRequest(
        lat: 13.0827,
        lng: 80.2707,
        speedKmh: 4.8,
        batteryPercent: 88,
      );
      expect(hb.toJson(), {
        'lat': 13.0827,
        'lng': 80.2707,
        'speed_kmh': 4.8,
        'battery_percent': 88,
      });
    });

    test('GoogleLoginRequest serializes ID token correctly', () {
      const google = GoogleLoginRequest(idToken: 'sample_id_token_123');
      expect(google.toJson(), {
        'id_token': 'sample_id_token_123',
        'platform': 'android',
      });
    });
  });

  group('ApiClient Error Taxonomy Tests', () {
    test('NetworkException produces NETWORK_ERROR code and structured message', () {
      const ex = NetworkException(message: 'Unreachable', uri: '/api/v1/dashboard');
      expect(ex.category, ApiErrorCategory.networkError);
      expect(ex.categoryCode, 'NETWORK_ERROR');
      expect(ex.statusCode, 0);
      expect(ex.message, 'Unreachable');
    });

    test('AuthException produces AUTH_ERROR category and code', () {
      const ex = AuthException(message: 'Invalid credentials', statusCode: 401, uri: '/api/v1/auth/login');
      expect(ex.category, ApiErrorCategory.authError);
      expect(ex.categoryCode, 'AUTH_ERROR');
      expect(ex.statusCode, 401);
    });

    test('PermissionException produces PERMISSION_ERROR code', () {
      const ex = PermissionException(message: 'Forbidden', statusCode: 403, uri: '/api/v1/admin');
      expect(ex.category, ApiErrorCategory.permissionError);
      expect(ex.categoryCode, 'PERMISSION_ERROR');
      expect(ex.statusCode, 403);
    });

    test('ValidationException produces VALIDATION_ERROR code', () {
      const ex = ValidationException(message: 'Missing field', statusCode: 422, uri: '/api/v1/journeys');
      expect(ex.category, ApiErrorCategory.validationError);
      expect(ex.categoryCode, 'VALIDATION_ERROR');
      expect(ex.statusCode, 422);
    });

    test('ServerException produces SERVER_ERROR code', () {
      const ex = ServerException(message: 'Internal error', statusCode: 500, uri: '/api/v1/dashboard');
      expect(ex.category, ApiErrorCategory.serverError);
      expect(ex.categoryCode, 'SERVER_ERROR');
      expect(ex.statusCode, 500);
    });

    test('ApiTimeoutException produces TIMEOUT code', () {
      const ex = ApiTimeoutException(message: 'Timed out', uri: '/api/v1/dashboard');
      expect(ex.category, ApiErrorCategory.timeout);
      expect(ex.categoryCode, 'TIMEOUT');
      expect(ex.statusCode, 408);
    });

    test('ApiConfig explains resolution source cleanly', () {
      expect(ApiConfig.resolutionSource, isNotEmpty);
    });
  });

  group('SafetySensorManager Foundation Tests', () {
    test('Initial snapshot exposes all 4 sensors and stationary state', () {
      final snapshot = SafetySensorSnapshot.initial();
      expect(snapshot.gps.name, 'GPS');
      expect(snapshot.accelerometer.name, 'ACCELEROMETER');
      expect(snapshot.gyroscope.name, 'GYROSCOPE');
      expect(snapshot.voice.name, 'VOICE');
      expect(snapshot.deviceMotionState, DeviceMotionState.stationary);
    });

    test('SensorTelemetry supports rawValues, filteredValues, and copyWith', () {
      const telemetry = SensorTelemetry(
        name: 'ACCELEROMETER',
        status: SensorStatus.active,
        permission: 'GRANTED',
        availability: true,
        confidence: 0.92,
        eventClassification: 'ELEVATED_MOTION',
        rawValues: {'magnitude': 17.5},
        filteredValues: {'baseline': 9.81, 'delta': 7.69},
      );

      expect(telemetry.status, SensorStatus.active);
      expect(telemetry.confidence, 0.92);
      expect(telemetry.rawValues['magnitude'], 17.5);
      expect(telemetry.filteredValues['baseline'], 9.81);

      final updated = telemetry.copyWith(eventClassification: 'NORMAL', confidence: 0.99);
      expect(updated.eventClassification, 'NORMAL');
      expect(updated.confidence, 0.99);
    });

    test('SafetySensorManager provides telemetry snapshot without triggering SOS', () async {
      final mockRepo = MockIntelligenceRepo();
      final sensorService = SensorService(
        intelligenceRepository: mockRepo,
        accelerometerStream: const Stream.empty(),
        gyroscopeStream: const Stream.empty(),
      );
      final locationService = LocationService();
      final voiceService = VoiceService(intelligenceRepository: mockRepo);

      final manager = SafetySensorManager(
        locationService: locationService,
        sensorService: sensorService,
        voiceService: voiceService,
      );

      expect(manager.isMonitoring, isFalse);
      expect(manager.currentSnapshot.gps.name, 'GPS');
      expect(manager.currentSnapshot.accelerometer.name, 'ACCELEROMETER');
      expect(manager.currentSnapshot.gyroscope.name, 'GYROSCOPE');
      expect(manager.currentSnapshot.voice.name, 'VOICE');

      manager.dispose();
    });
  });

  group('MultiStageFallDetector Tests', () {
    test('Normal phone pickup (12 m/s²) does NOT trigger a fall', () {
      final detector = MultiStageFallDetector();
      FallEvaluationReport? generatedReport;
      detector.onReportGenerated = (report) => generatedReport = report;

      // Simulate normal pickup: mild acceleration increase, minimal gyro rotation
      detector.processAccelSample(0.5, 0.5, 12.0, 12.02);
      detector.processGyroSample(0.1, 0.1, 0.2, 0.24);

      // No fall candidate window or false alarm
      expect(generatedReport, isNull);
      detector.dispose();
    });

    test('Table placement does NOT trigger a fall', () {
      final detector = MultiStageFallDetector();
      FallEvaluationReport? generatedReport;
      detector.onReportGenerated = (report) => generatedReport = report;

      // Normal table placement: slight deceleration to 9.8 m/s²
      detector.processAccelSample(0.0, 0.0, 9.8, 9.8);
      detector.processGyroSample(0.0, 0.0, 0.0, 0.0);

      expect(generatedReport, isNull);
      detector.dispose();
    });

    test('Fall sequence: freefall -> high impact -> immobility evaluates correctly', () async {
      FallEvaluationReport? finalReport;
      final detector = MultiStageFallDetector(
        onReportGenerated: (report) => finalReport = report,
      );

      // Stage 1: Freefall entry (< 4.0 m/s²)
      detector.processAccelSample(0.1, 0.1, 1.2, 1.21);

      // Stage 2 & 3: High impact (> 25 m/s²) with tumbling rotation (> 4.0 rad/s)
      detector.processAccelSample(10.0, 15.0, 22.0, 28.4);
      detector.processGyroSample(3.0, 4.0, 2.0, 5.38);

      // Stage 5: Rest on ground (9.8 m/s² with stillness)
      for (int i = 0; i < 20; i++) {
        detector.processAccelSample(0.0, 0.0, 9.81, 9.81);
      }

      // Wait for immobility timer (1800ms) to trigger Stage 7 confidence
      await Future.delayed(const Duration(milliseconds: 1900));

      expect(finalReport, isNotNull);
      expect(finalReport!.freefallDetected, isTrue);
      expect(finalReport!.peakAcceleration, greaterThanOrEqualTo(25.0));
      expect(finalReport!.postImpactImmobility, isTrue);
      expect(finalReport!.confidence, greaterThanOrEqualTo(0.70));
      expect(finalReport!.isFallSuspected, isTrue);

      detector.dispose();
    });
  });

  group('VoiceService Distress & Simulation Tests', () {
    test('Simulated voice trigger flags source as TEST_SIMULATOR', () async {
      final mockRepo = MockIntelligenceRepo();
      final voiceService = VoiceService(intelligenceRepository: mockRepo);

      String? triggeredPhrase;
      final sub = voiceService.emergencyTriggerStream.listen((p) => triggeredPhrase = p);

      voiceService.simulateVoiceTrigger('HELP ME EMERGENCY');
      await Future.delayed(const Duration(milliseconds: 50));

      expect(triggeredPhrase, 'HELP ME EMERGENCY');
      expect(voiceService.lastEventSource, 'TEST_SIMULATOR');
      expect(voiceService.latestTranscript, 'HELP ME EMERGENCY');
      expect(voiceService.matchedKeywords, contains('HELP ME EMERGENCY'));
      expect(voiceService.confidence, greaterThanOrEqualTo(0.8));
      expect(voiceService.latestUrgency, 'LOW');

      sub.cancel();
      voiceService.stopListening();
    });

    test('Trigger phrases list includes safety keywords', () {
      expect(VoiceService.triggerPhrases, contains('help'));
      expect(VoiceService.triggerPhrases, contains('emergency'));
      expect(VoiceService.triggerPhrases, contains('call police'));
      expect(VoiceService.triggerPhrases, contains('bachao'));
    });
  });

  group('BackgroundSafetyService Foreground Tests', () {
    test('Foreground service manages lifecycle and stop cleanly', () async {
      final service = BackgroundSafetyService();
      expect(service.isServiceRunning, isFalse);

      await service.startForegroundService(
        title: 'Guardian AI Active',
        body: 'Monitoring safety · GPS ±8m · Battery 85%',
      );
      expect(service.isServiceRunning, isTrue);

      await service.updateStatus(
        title: 'Guardian AI Active',
        body: 'Elevated risk detected near Commercial Street',
        isElevatedRisk: true,
      );
      expect(service.isServiceRunning, isTrue);

      await service.stopForegroundService();
      expect(service.isServiceRunning, isFalse);

      service.dispose();
    });
  });

  group('GuardianRiskEngine Multi-Signal & Explainability Tests', () {
    const engine = GuardianRiskEngine();

    test('Baseline daylight evaluation produces LOW risk report', () {
      final report = engine.evaluateRisk(
        currentTime: DateTime(2026, 8, 18, 14, 0), // 2 PM daylight
        locationSafetyScore: 85.0,
        routeDeviationMeters: 0.0,
        stationarySeconds: 0,
        batteryPercent: 90,
      );

      expect(report.riskCategory, RiskLevelCategory.low);
      expect(report.categoryLabel, 'LOW');
      expect(report.overallRiskPercent, lessThan(25));
    });

    test('Multi-signal risk fusion calculates exact explainable percentage and itemized reasons', () {
      final nightTime = DateTime(2026, 8, 18, 23, 30); // 11:30 PM
      final report = engine.evaluateRisk(
        currentTime: nightTime,
        routeDeviationMeters: 140.0,
        weatherCondition: 'Rain',
        batteryPercent: 12,
      );

      // Night (+15%) + Route Deviation 140m (+25%) + Rain (+10%) + Battery 12% (+12%) = 62%
      expect(report.overallRiskPercent, 62);
      expect(report.riskCategory, RiskLevelCategory.high);
      expect(report.categoryLabel, 'HIGH');

      final descriptions = report.factors.map((f) => f.description).toList();
      expect(descriptions, contains('Walking after 11 PM (+15%)'));
      expect(descriptions, contains('Off safe route by 140m (+25%)'));
      expect(descriptions, contains('Rain detected (+10%)'));
      expect(descriptions, contains('Battery at 12% (+12%)'));
    });

    test('Critical kinematic and voice distress anomalies escalate risk to CRITICAL', () {
      final report = engine.evaluateRisk(
        hasMotionAnomaly: true,
        motionAnomalyPeak: 28.4,
        hasVoiceDistress: true,
        voiceUrgency: 'CRITICAL',
        batteryPercent: 8,
      );

      expect(report.overallRiskPercent, greaterThanOrEqualTo(75));
      expect(report.riskCategory, RiskLevelCategory.critical);
      expect(report.categoryLabel, 'CRITICAL');
    });
  });

  group('Risk-Based Automatic Actions & Escalation Tests', () {
    test('Heartbeat intervals dynamically calibrate based on risk tiers', () {
      final engine = GuardianEngine(
        guardianRepository: MockGuardianRepo(),
        journeyRepository: MockJourneyRepo(),
        locationService: LocationService(),
        sensorService: SensorService(intelligenceRepository: MockIntelligenceRepo()),
        voiceService: VoiceService(intelligenceRepository: MockIntelligenceRepo()),
      );

      // Low Risk (<30%) -> 60s
      engine.setHeartbeatIntervalForRisk(20);
      expect(engine.heartbeatIntervalSeconds, 60);

      // Moderate Risk (30-60%) -> 30s
      engine.setHeartbeatIntervalForRisk(45);
      expect(engine.heartbeatIntervalSeconds, 30);

      // High Risk (60-80%) -> 15s
      engine.setHeartbeatIntervalForRisk(70);
      expect(engine.heartbeatIntervalSeconds, 15);

      // Critical Risk (>80%) -> 10s
      engine.setHeartbeatIntervalForRisk(90);
      expect(engine.heartbeatIntervalSeconds, 10);

      engine.dispose();
    });
  });

  group('False Alarm Feedback Loop & ML Calibration Tests', () {
    test('Cancelling 2 fall alerts in 24h increases fall threshold by 10%', () async {
      final manager = FalseAlarmManager(intelligenceRepository: MockIntelligenceRepo());
      expect(manager.fallSensitivityMultiplier, 1.0);

      // 1st cancellation: no threshold boost yet
      final res1 = await manager.recordCancellation(triggerSource: 'FALL_DETECTION');
      expect(res1.wasAdjusted, isFalse);
      expect(manager.fallSensitivityMultiplier, 1.0);

      // 2nd cancellation within 24h: increases threshold by 10% (1.0 -> 1.10)
      final res2 = await manager.recordCancellation(triggerSource: 'FALL_DETECTION');
      expect(res2.wasAdjusted, isTrue);
      expect(res2.message, 'Sensitivity adjusted to reduce false alarms.');
      expect(manager.fallSensitivityMultiplier, closeTo(1.10, 0.001));
    });

    test('Higher calibrated threshold prevents identical borderline movement from triggering false alarm', () {
      final detector = MultiStageFallDetector();
      FallEvaluationReport? generatedReport;
      detector.onReportGenerated = (report) => generatedReport = report;

      // Calibrate sensitivity multiplier to 1.10 (threshold = 25.0 * 1.10 = 27.5 m/s²)
      detector.sensitivityMultiplier = 1.10;
      expect(detector.effectiveImpactThreshold, closeTo(27.5, 0.01));

      // Stage 1: Freefall (< 4.0 m/s²)
      detector.processAccelSample(0.1, 0.1, 1.2, 1.21);

      // Stage 2: Borderline impact spike of 26.0 m/s² (which would trigger at 25.0, but NOT at 27.5)
      detector.processAccelSample(10.0, 15.0, 20.0, 26.0);
      detector.processGyroSample(3.0, 4.0, 2.0, 5.38);

      // Verify that 26.0 m/s² does NOT trigger candidate impact window
      expect(generatedReport, isNull);

      detector.dispose();
    });
  });

  group('RouteDeviationDetector Corridor Tests', () {
    test('100m corridor perpendicular distance calculation and 45s sustained deviation filter', () {
      final detector = RouteDeviationDetector(corridorWidthMeters: 100.0);
      double? confirmedDeviationDistance;
      detector.onSustainedDeviationConfirmed = (d) => confirmedDeviationDistance = d;

      // Planned route along latitude 13.0000 -> 13.0100 on longitude 80.2000
      final route = [
        const LatLng(13.0000, 80.2000),
        const LatLng(13.0100, 80.2000),
      ];
      detector.setPlannedRoute(route);

      final t0 = DateTime(2026, 8, 18, 12, 0, 0);

      // 1. On route position -> normal
      final r0 = detector.processPosition(const LatLng(13.0050, 80.2000), sampleTime: t0);
      expect(r0.isDeviated, isFalse);
      expect(r0.isSustained, isFalse);

      // 2. Off route position by ~140m (approx 0.0013 deg longitude offset)
      // 0.0013 deg * 111,000 * cos(13 deg) ~ 140 meters
      final offRoutePos = const LatLng(13.0050, 80.2013);
      final t1 = t0.add(const Duration(seconds: 5));
      final r1 = detector.processPosition(offRoutePos, sampleTime: t1);
      expect(r1.isDeviated, isTrue);
      expect(r1.isSustained, isFalse); // Not yet sustained for 45s (filters noise)
      expect(confirmedDeviationDistance, isNull);

      // 3. Off route after 20s -> still candidate
      final t2 = t0.add(const Duration(seconds: 25));
      final r2 = detector.processPosition(offRoutePos, sampleTime: t2);
      expect(r2.isDeviated, isTrue);
      expect(r2.isSustained, isFalse);

      // 4. Off route after 50s -> confirmed sustained deviation!
      final t3 = t0.add(const Duration(seconds: 55));
      final r3 = detector.processPosition(offRoutePos, sampleTime: t3);
      expect(r3.isDeviated, isTrue);
      expect(r3.isSustained, isTrue);
      expect(confirmedDeviationDistance, isNotNull);
      expect(confirmedDeviationDistance!, greaterThan(100.0));

      // 5. User confirms "I'M OK" -> expands corridor to encompass deviation
      detector.handleUserSafeInCurrentLocation(r3.currentDistanceMeters);
      expect(detector.corridorWidthMeters, greaterThan(r3.currentDistanceMeters));

      // 6. Next check at same position is now within expanded corridor!
      final r4 = detector.processPosition(offRoutePos, sampleTime: t3.add(const Duration(seconds: 5)));
      expect(r4.isDeviated, isFalse);
    });
  });

  group('StationaryDetector Watchdog Tests', () {
    test('Walking mode: 3 minutes stationary triggers check-in prompt', () {
      final detector = StationaryDetector(travelMode: TravelMode.walking);
      String? firedPrompt;
      int? firedMinutes;
      detector.onStationaryBreach = (mins, prompt) {
        firedMinutes = mins;
        firedPrompt = prompt;
      };

      final anchor = const LatLng(13.0827, 80.2707);
      final t0 = DateTime(2026, 8, 18, 14, 0, 0);

      // 1. Initial stationary reading (speed < 1 km/h, still accelerometer variance < 0.5)
      final r0 = detector.processTelemetry(
        position: anchor,
        gpsSpeedKmh: 0.0,
        recentAccelSamples: const [9.8, 9.81, 9.8, 9.79],
        sampleTime: t0,
      );
      expect(r0.isStationary, isTrue);
      expect(r0.isThresholdBreached, isFalse);

      // 2. Stationary after 2 minutes (120s) with minor GPS jitter (12m displacement)
      final t1 = t0.add(const Duration(minutes: 2));
      final jitterPos = const LatLng(13.08275, 80.27075); // ~8 meters displacement
      final r1 = detector.processTelemetry(
        position: jitterPos,
        gpsSpeedKmh: 0.2,
        recentAccelSamples: const [9.8, 9.8, 9.81, 9.8],
        sampleTime: t1,
      );
      expect(r1.isStationary, isTrue);
      expect(r1.isThresholdBreached, isFalse);
      expect(firedPrompt, isNull);

      // 3. Stationary after 3 minutes (180s) -> threshold breached!
      final t2 = t0.add(const Duration(minutes: 3));
      final r2 = detector.processTelemetry(
        position: jitterPos,
        gpsSpeedKmh: 0.1,
        recentAccelSamples: const [9.8, 9.8, 9.8, 9.8],
        sampleTime: t2,
      );
      expect(r2.isStationary, isTrue);
      expect(r2.isThresholdBreached, isTrue);
      expect(firedMinutes, 3);
      expect(firedPrompt, contains("You haven't moved for 3 minutes. Still on track?"));
    });

    test('Accelerometer movement resets stationary timer', () {
      final detector = StationaryDetector(travelMode: TravelMode.walking);
      final anchor = const LatLng(13.0827, 80.2707);
      final t0 = DateTime(2026, 8, 18, 14, 0, 0);

      // Initial stationary
      detector.processTelemetry(
        position: anchor,
        gpsSpeedKmh: 0.0,
        recentAccelSamples: const [9.8, 9.8, 9.8, 9.8],
        sampleTime: t0,
      );

      // 2 minutes later, user begins walking (accel variance > 0.5)
      final t1 = t0.add(const Duration(minutes: 2));
      final r1 = detector.processTelemetry(
        position: anchor,
        gpsSpeedKmh: 0.5,
        recentAccelSamples: const [8.0, 12.5, 7.5, 14.0], // walking stride dynamics
        sampleTime: t1,
      );
      expect(r1.isStationary, isFalse);
      expect(r1.stationarySeconds, 0);
    });

    test('Travel mode threshold scaling: Transit (5 min) vs Driving (8 min)', () {
      final transitDetector = StationaryDetector(travelMode: TravelMode.transit);
      expect(transitDetector.thresholdMinutes, 5);
      expect(transitDetector.thresholdSeconds, 300);

      final drivingDetector = StationaryDetector(travelMode: TravelMode.driving);
      expect(drivingDetector.thresholdMinutes, 8);
      expect(drivingDetector.thresholdSeconds, 480);
    });
  });

  group('EtaSpeedWatchdog Tests (Phase 11)', () {
    test('Overdue tolerance (5 min for walking) triggers prompt and extendEta resets', () {
      final t0 = DateTime(2026, 8, 18, 15, 0, 0);
      final watchdog = EtaSpeedWatchdog(
        travelMode: TravelMode.walking,
        initialExpectedArrival: t0.add(const Duration(minutes: 15)), // ETA: 15:15
      );

      // At 15:18 (3 min past ETA, within 5 min tolerance) -> not overdue
      final r1 = watchdog.processTelemetry(currentSpeedKmh: 4.5, sampleTime: t0.add(const Duration(minutes: 18)));
      expect(r1.isOverdue, isFalse);

      // At 15:21 (6 min past ETA, exceeds 5 min tolerance) -> overdue!
      final r2 = watchdog.processTelemetry(currentSpeedKmh: 4.5, sampleTime: t0.add(const Duration(minutes: 21)));
      expect(r2.isOverdue, isTrue);
      expect(r2.promptMessage, contains('Your journey is taking longer than expected'));

      // User extends ETA by +10 min (new ETA: 15:25)
      watchdog.extendEta(10);
      final r3 = watchdog.processTelemetry(currentSpeedKmh: 4.5, sampleTime: t0.add(const Duration(minutes: 21)));
      expect(r3.isOverdue, isFalse);
    });

    test('Walking at vehicle speed (>25 km/h for >30s) triggers unexpected speeding anomaly', () {
      final t0 = DateTime(2026, 8, 18, 15, 0, 0);
      final watchdog = EtaSpeedWatchdog(travelMode: TravelMode.walking);

      // Exceeds 25 km/h for 10s -> not yet sustained
      final r1 = watchdog.processTelemetry(currentSpeedKmh: 35.0, sampleTime: t0.add(const Duration(seconds: 10)));
      expect(r1.speedAnomaly, SpeedAnomalyType.none);

      // Exceeds 25 km/h for 35s after start (t0 + 45s) -> unexpected vehicle speed detected!
      final r2 = watchdog.processTelemetry(currentSpeedKmh: 35.0, sampleTime: t0.add(const Duration(seconds: 45)));
      expect(r2.speedAnomaly, SpeedAnomalyType.unexpectedSpeeding);
    });
  });

  group('SafeArrivalDetector Tests (Phase 12)', () {
    test('Within 80m prompts safe arrival, within 50m for 2min auto-confirms', () {
      final dest = const LatLng(13.0827, 80.2707);
      final detector = SafeArrivalDetector(destination: dest, destinationName: 'Central Station');

      final t0 = DateTime(2026, 8, 18, 16, 0, 0);

      // 1. Far away (500m) -> no arrival
      final r0 = detector.processPosition(
        position: const LatLng(13.0870, 80.2707),
        speedKmh: 15.0,
        sampleTime: t0,
      );
      expect(r0.isWithinProximity, isFalse);
      expect(r0.isAutoConfirmed, isFalse);

      // 2. Within 80m (~60m) at low speed -> triggers prompt
      final closePos = const LatLng(13.0831, 80.2707);
      final r1 = detector.processPosition(
        position: closePos,
        speedKmh: 1.2,
        sampleTime: t0.add(const Duration(seconds: 10)),
      );
      expect(r1.isWithinProximity, isTrue);
      expect(r1.promptMessage, contains("Looks like you've arrived at Central Station"));
      expect(r1.isAutoConfirmed, isFalse);

      // 3. Within 50m (~30m) stationary for 130s -> auto-confirms safe arrival!
      final exactPos = const LatLng(13.0829, 80.2707);
      final r2 = detector.processPosition(
        position: exactPos,
        speedKmh: 0.0,
        sampleTime: t0.add(const Duration(seconds: 140)),
      );
      expect(r2.isAutoConfirmed, isTrue);
    });
  });

  group('SosEscalationEngine Multi-Signal & Cooldown Tests (Phases 13-16)', () {
    test('Single sensor signal is NEVER permitted to unilaterally trigger SOS', () {
      final engine = SosEscalationEngine(guardianRepository: MockGuardianRepo());

      // Only high risk area (1 signal) -> should NOT escalate
      final r1 = engine.evaluateSignals(highRiskArea: true);
      expect(r1.shouldEscalate, isFalse);

      // Only voice distress keyword (1 signal) -> should NOT escalate
      final r2 = engine.evaluateSignals(voiceDistressConfirmed: true);
      expect(r2.shouldEscalate, isFalse);
    });

    test('Correlated multi-signals (Fall sequence OR >= 2 signals) triggers SOS escalation', () {
      final engine = SosEscalationEngine(guardianRepository: MockGuardianRepo());

      // Multi-stage fall confirmed (freefall + impact spike + post-impact stillness) -> escalates
      final r1 = engine.evaluateSignals(multiStageFallConfirmed: true);
      expect(r1.shouldEscalate, isTrue);

      // Voice distress + high risk area (2 signals) -> escalates
      final r2 = engine.evaluateSignals(voiceDistressConfirmed: true, highRiskArea: true);
      expect(r2.shouldEscalate, isTrue);
    });

    test('5-minute emergency cooldown throttles duplicate dispatches', () async {
      final engine = SosEscalationEngine(guardianRepository: MockGuardianRepo());
      expect(engine.isCooldownActive, isFalse);

      // 1. Dispatch emergency SOS
      final res1 = await engine.dispatchEmergencySos(
        lat: 13.0827,
        lng: 80.2707,
        batteryLevel: 85,
        triggerType: 'AUTOMATIC_MULTI_SIGNAL',
      );
      expect(res1.success, isTrue);
      expect(engine.isCooldownActive, isTrue);
      expect(engine.cooldownSecondsRemaining, greaterThan(290));

      // 2. Attempt immediate second dispatch -> throttled by cooldown!
      final res2 = await engine.dispatchEmergencySos(
        lat: 13.0827,
        lng: 80.2707,
        batteryLevel: 85,
        triggerType: 'AUTOMATIC_MULTI_SIGNAL',
      );
      expect(res2.success, isFalse);
      expect(res2.message, contains('5-minute cooldown'));
    });
  });

  group('NotificationDeliveryService & SafetyPermissionManager Tests (Phases 17-21)', () {
    test('NotificationDeliveryService tracks delivery lifecycle across contacts', () async {
      final service = NotificationDeliveryService();
      final contacts = [
        const TrustedContactEntity(
          id: 'c1',
          name: 'Priya Sharma',
          phone: '+919876543210',
          avatarUrl: '',
          isOnline: true,
          relationshipLabel: 'Sister',
          emergencyNotifyEnabled: true,
        ),
        const TrustedContactEntity(
          id: 'c2',
          name: 'Dr. Ramesh Kumar',
          phone: '+919876543211',
          avatarUrl: '',
          isOnline: true,
          relationshipLabel: 'Doctor',
          emergencyNotifyEnabled: true,
        ),
      ];

      final results = await service.dispatchAlertsToContacts(
        contacts: contacts,
        lat: 13.0827,
        lng: 80.2707,
        triggerType: 'TEST_EMERGENCY',
        batteryPercent: 92,
      );

      expect(results.length, 2);
      expect(results[0].status, DeliveryStatus.delivered);
      expect(results[0].contactName, 'Priya Sharma');
      expect(results[1].status, DeliveryStatus.delivered);
      expect(results[1].contactName, 'Dr. Ramesh Kumar');
      expect(results[0].deliveryLatencyMs, isNotNull);

      service.dispose();
    });

    test('SafetyPermissionManager checks permissions gracefully without crashing', () async {
      final manager = SafetyPermissionManager();
      final status = await manager.checkPermissions();
      expect(status, isNotNull);
      expect(status.sensorsGranted, isTrue);
    });
  });

  group('SafetyScoreCalculator & End-to-End Scenarios Tests (Phases 22-25)', () {
    const calc = SafetyScoreCalculator();

    test('Baseline daylight with healthy battery produces score 100 (Excellent)', () {
      final dayTime = DateTime(2026, 8, 18, 14, 0, 0);
      final report = calc.calculateScore(
        currentTime: dayTime,
        batteryPercent: 95,
        isInHighRiskZone: false,
        isSevereWeather: false,
      );

      expect(report.score, 100);
      expect(report.category, SafetyCategory.excellent);
      expect(report.categoryLabel, 'Excellent');
      expect(report.factors.length, greaterThanOrEqualTo(2));
    });

    test('Night (-15), critical battery (-15), high risk zone (-20), severe weather (-10) deducts to 40 (Low)', () {
      final nightTime = DateTime(2026, 8, 18, 23, 30, 0);
      final report = calc.calculateScore(
        currentTime: nightTime,
        batteryPercent: 12, // < 20%
        isInHighRiskZone: true,
        isSevereWeather: true,
      );

      // 100 - 15 (night) - 15 (crit batt) - 20 (high risk) - 10 (weather) = 40
      expect(report.score, 40);
      expect(report.category, SafetyCategory.low);
      expect(report.categoryLabel, 'Low');
    });

    test('End-to-End System Safety Lifecycle validation', () async {
      // 1. Initial State: Normal Walking Journey
      final routeDetector = RouteDeviationDetector();
      final watchdog = EtaSpeedWatchdog(travelMode: TravelMode.walking);
      final arrivalDetector = SafeArrivalDetector(
        destination: const LatLng(13.0827, 80.2707),
        destinationName: 'Central HQ',
      );
      final sosEngine = SosEscalationEngine(guardianRepository: MockGuardianRepo());

      // 2. Telemetry tracking within corridor
      final route = const [LatLng(13.0800, 80.2700), LatLng(13.0827, 80.2707)];
      final pos1 = const LatLng(13.0805, 80.2702);
      expect(routeDetector.isDeviated(pos1, route), isFalse);
      final watchdogReport = watchdog.processTelemetry(currentSpeedKmh: 4.2);
      expect(watchdogReport.isOverdue, isFalse);

      // 3. User deviates off-path into dark alley
      final offRoutePos = const LatLng(13.0850, 80.2750);
      expect(routeDetector.isDeviated(offRoutePos, route), isTrue);

      // 4. Multi-signal risk escalates and SOS evaluates safely
      final sosDecision = sosEngine.evaluateSignals(
        sustainedRouteDeviation: true,
        highRiskArea: true,
        compositeRiskPercent: 85,
      );
      expect(sosDecision.shouldEscalate, isTrue);
      expect(sosDecision.signalCount, greaterThanOrEqualTo(3));

      // 5. Emergency SOS Dispatches
      final sosResult = await sosEngine.dispatchEmergencySos(
        lat: offRoutePos.latitude,
        lng: offRoutePos.longitude,
        batteryLevel: 45,
        triggerType: 'MULTI_SIGNAL_DEVIATION_HIGH_RISK',
      );
      expect(sosResult.success, isTrue);

      // 6. User confirms safety and cancels SOS
      await sosEngine.cancelSosByUser(triggerType: 'MULTI_SIGNAL_DEVIATION_HIGH_RISK');
      expect(sosEngine.state, SosEngineState.idle);

      routeDetector.reset();
      arrivalDetector.reset();
    });
  });
}















