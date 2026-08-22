import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/core/services/fall_detector.dart';
import 'package:guardian_ai/core/services/sensor_service.dart';
import 'package:guardian_ai/core/services/guardian_risk_engine.dart';
import 'package:guardian_ai/core/services/sos_escalation_engine.dart';
import 'package:guardian_ai/domain/entities/entities.dart';
import 'package:guardian_ai/data/dto/api_dto.dart';
import 'package:guardian_ai/domain/repositories/repositories.dart';

class MockIntelligenceRepo implements IntelligenceRepository {
  MotionSignalRequest? lastMotionRequest;

  @override
  Future<MotionAnomalyEntity> sendMotionSignal(MotionSignalRequest request) async {
    lastMotionRequest = request;
    return const MotionAnomalyEntity(
      eventId: 'evt_fall_1',
      eventType: 'FALL_DETECTED',
      evaluatedRiskContribution: 0.40,
      confidenceAdjusted: 0.95,
      message: 'Fall processed',
    );
  }

  @override
  Future<VoiceDistressEntity> sendVoiceAnalysis(VoiceAnalysisRequest request) async {
    return const VoiceDistressEntity(
      signal: 'NORMAL',
      distressScore: 0.0,
      urgency: 'NONE',
      helpKeyword: false,
      repetitionCount: 0,
      voiceIntensity: 0.0,
      modelConfidence: 0.9,
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
  SosRequest? lastSosRequest;

  @override
  Future<GuardianStatusEntity> fetchStatus() async => const GuardianStatusEntity(
        isActive: true,
        statusLabel: 'Active',
        monitoringLabel: 'AI Shield Active',
        voiceSyncLive: true,
        voiceSyncState: 'Listening',
        batteryPercent: 95,
        speedKmh: 0,
        speedStatus: 'Normal',
        estimatedArrival: '10:00',
        minutesLeft: 10,
        origin: 'A',
        destination: 'B',
        progress: 50,
        currentLocation: 'GPS Lock',
        avatarUrl: '',
      );

  @override
  Future<GuardianStatusEntity> startGuardian() async => fetchStatus();

  @override
  Future<GuardianStatusEntity> stopGuardian() async => const GuardianStatusEntity(
        isActive: false,
        statusLabel: 'Inactive',
        monitoringLabel: 'Standby',
        voiceSyncLive: false,
        voiceSyncState: 'Disconnected',
        batteryPercent: 95,
        speedKmh: 0,
        speedStatus: 'Idle',
        estimatedArrival: '',
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
  Future<ApiMessageResponse> triggerSos(SosRequest request) async {
    lastSosRequest = request;
    return const ApiMessageResponse(success: true, message: 'SOS Triggered');
  }

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

void main() {
  group('Fall & Accelerometer Pipeline Tests', () {
    late SensorService sensorService;
    late MockIntelligenceRepo mockIntelligence;

    setUp(() {
      mockIntelligence = MockIntelligenceRepo();
      sensorService = SensorService(intelligenceRepository: mockIntelligence);
    });

    test('Simulated Fall emits fallDetected anomaly to stream and dispatches signal', () async {
      MotionEventType? emittedAnomaly;
      final sub = sensorService.anomalyStream.listen((event) {
        emittedAnomaly = event;
      });

      sensorService.simulateFall();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emittedAnomaly, equals(MotionEventType.fallDetected));
      expect(mockIntelligence.lastMotionRequest, isNotNull);
      expect(mockIntelligence.lastMotionRequest!.eventType, equals('FALL_DETECTED'));

      await sub.cancel();
    });

    test('Simulated Shake emits shakeDetected anomaly to stream and dispatches signal', () async {
      MotionEventType? emittedAnomaly;
      final sub = sensorService.anomalyStream.listen((event) {
        emittedAnomaly = event;
      });

      sensorService.simulateShake();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(emittedAnomaly, equals(MotionEventType.shakeDetected));
      expect(mockIntelligence.lastMotionRequest, isNotNull);
      expect(mockIntelligence.lastMotionRequest!.eventType, equals('SHAKE_DETECTED'));

      await sub.cancel();
    });

    test('Normal movement and small translations do not trigger fall or shake anomalies', () {
      final detector = MultiStageFallDetector();
      FallEvaluationReport? generatedReport;
      detector.onReportGenerated = (report) => generatedReport = report;

      // Normal pickup: moderate acceleration (12 m/s²) without freefall
      detector.processAccelSample(0.5, 9.8, 4.0, 11.2);
      detector.processGyroSample(0.2, 0.3, 0.1, 0.4);

      expect(generatedReport, isNull); // Does not trigger false alarm
    });

    test('Downstream Pipeline: Fall event integrates with Risk Engine and SOS escalation', () async {
      final riskEngine = const GuardianRiskEngine();
      final mockGuardian = MockGuardianRepo();
      final sosEngine = SosEscalationEngine(guardianRepository: mockGuardian);

      // 1. Evaluate risk on fall impact
      final report = riskEngine.evaluateRisk(
        hasMotionAnomaly: true,
        motionAnomalyPeak: 28.5,
      );

      expect(report.overallRiskPercent, greaterThanOrEqualTo(30));
      expect(report.factors.any((f) => f.name == 'Kinematic Anomaly'), isTrue);

      // 2. Automated SOS decision matrix on multiStageFallConfirmed + unanswered prompt
      final decision = sosEngine.evaluateSignals(
        multiStageFallConfirmed: true,
        unansweredCriticalPrompt: true,
      );

      expect(decision.shouldEscalate, isTrue);
      expect(decision.signalCount, greaterThanOrEqualTo(2));

      // 3. SOS dispatch
      final res = await sosEngine.dispatchEmergencySos(
        lat: 13.0827,
        lng: 80.2707,
        batteryLevel: 85,
        triggerType: 'fall_detected',
      );

      expect(res.success, isTrue);
      expect(mockGuardian.lastSosRequest, isNotNull);
      expect(mockGuardian.lastSosRequest!.triggerSource, equals('fall_detected'));
    });
  });
}
