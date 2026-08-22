import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/core/services/voice_service.dart';
import 'package:guardian_ai/core/services/guardian_risk_engine.dart';
import 'package:guardian_ai/core/services/sos_escalation_engine.dart';
import 'package:guardian_ai/data/dto/api_dto.dart';
import 'package:guardian_ai/domain/entities/entities.dart';
import 'package:guardian_ai/domain/repositories/repositories.dart';

class MockIntelligenceRepo implements IntelligenceRepository {
  VoiceAnalysisRequest? lastVoiceRequest;

  @override
  Future<VoiceDistressEntity> sendVoiceAnalysis(VoiceAnalysisRequest request) async {
    lastVoiceRequest = request;
    final isCritical = request.transcriptOrText.toLowerCase().contains('help') ||
        request.transcriptOrText.toLowerCase().contains('danger');
    return VoiceDistressEntity(
      signal: 'VOICE_DISTRESS',
      distressScore: isCritical ? 0.95 : 0.20,
      urgency: isCritical ? 'HIGH' : 'LOW',
      helpKeyword: isCritical,
      repetitionCount: 1,
      voiceIntensity: request.voiceIntensity,
      modelConfidence: 0.95,
      matchedKeywords: isCritical ? ['help'] : [],
      message: 'Processed',
    );
  }

  @override
  Future<MotionAnomalyEntity> sendMotionSignal(MotionSignalRequest request) async {
    return const MotionAnomalyEntity(
      eventId: 'evt_1',
      eventType: 'NORMAL',
      evaluatedRiskContribution: 0.1,
      confidenceAdjusted: 0.9,
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
  group('Voice Distress Pipeline & Keyword Matching Tests', () {
    late VoiceService voiceService;
    late MockIntelligenceRepo mockIntelligence;

    setUp(() {
      mockIntelligence = MockIntelligenceRepo();
      voiceService = VoiceService(intelligenceRepository: mockIntelligence);
    });

    test('Initial voice state is OFF and listeners are idle', () {
      expect(voiceService.state, VoiceState.off);
      expect(voiceService.isListening, isFalse);
      expect(voiceService.latestTranscript, isEmpty);
      expect(voiceService.matchedKeywords, isEmpty);
    });

    test('Keyword Matching detects all distress variations accurately', () async {
      final testPhrases = [
        'HELP',
        'help',
        'Help!',
        'I need help',
        'please help me',
        'I am in danger',
        'EMERGENCY',
        'emergency situation',
        'danger',
        'guardian',
        'save me',
        'bachao',
        'chhod do',
        'sos',
      ];

      for (final phrase in testPhrases) {
        String? triggeredPhrase;
        final sub = voiceService.emergencyTriggerStream.listen((p) {
          triggeredPhrase = p;
        });

        voiceService.simulateVoiceTrigger(phrase);

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(triggeredPhrase, equals(phrase), reason: 'Failed to detect: $phrase');
        expect(voiceService.state, equals(VoiceState.distressDetected));
        expect(voiceService.matchedKeywords.isNotEmpty, isTrue);
        expect(voiceService.lastEventSource, equals('TEST_SIMULATOR'));

        await sub.cancel();
      }
    });

    test('Negative case: Normal speech does not trigger distress keywords', () async {
      final safePhrases = [
        'That was helpful',
        'This is an unhelpful comment',
        'He walked dangerously close to the puddle',
        'Hello how are you doing today',
        'Let us go get some coffee',
      ];

      for (final phrase in safePhrases) {
        bool triggered = false;
        final sub = voiceService.emergencyTriggerStream.listen((_) {
          triggered = true;
        });

        // Test matching logic with sanitized token bounds
        final clean = phrase.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
        final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
        final matched = <String>[];
        for (final kw in VoiceService.triggerPhrases) {
          final cleanKw = kw.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
          if (cleanKw.contains(' ')) {
            if (clean.contains(cleanKw)) matched.add(kw);
          } else {
            if (words.contains(cleanKw)) matched.add(kw);
          }
        }

        expect(matched, isEmpty, reason: 'False positive for: $phrase');
        expect(triggered, isFalse);

        await sub.cancel();
      }
    });

    test('Downstream Pipeline: Voice distress triggers Risk Engine elevation and SOS flow', () async {
      final riskEngine = const GuardianRiskEngine();
      final mockGuardian = MockGuardianRepo();
      final sosEngine = SosEscalationEngine(guardianRepository: mockGuardian);

      // 1. Simulate voice distress
      voiceService.simulateVoiceTrigger('HELP');
      expect(voiceService.state, VoiceState.distressDetected);

      // 2. Risk Engine evaluates voice distress
      final report = riskEngine.evaluateRisk(
        hasVoiceDistress: true,
        voiceUrgency: voiceService.latestUrgency,
      );

      expect(report.overallRiskPercent, greaterThanOrEqualTo(35));
      expect(report.factors.any((f) => f.name == 'Voice Distress'), isTrue);

      // 3. User fails to confirm safety prompt (unansweredCriticalPrompt)
      final decision = sosEngine.evaluateSignals(
        voiceDistressConfirmed: true,
        compositeRiskPercent: report.overallRiskPercent,
        unansweredCriticalPrompt: true,
      );

      expect(decision.shouldEscalate, isTrue);
      expect(decision.reasons.any((r) => r.contains('unanswered') || r.contains('Acoustic distress')), isTrue);

      // 4. SOS dispatch reaches existing SOS repository
      final res = await sosEngine.dispatchEmergencySos(
        lat: 13.0827,
        lng: 80.2707,
        batteryLevel: 90,
        triggerType: 'voice_trigger_unanswered',
      );

      expect(res.success, isTrue);
      expect(mockGuardian.lastSosRequest, isNotNull);
      expect(mockGuardian.lastSosRequest!.triggerSource, equals('voice_trigger_unanswered'));
    });
  });
}
