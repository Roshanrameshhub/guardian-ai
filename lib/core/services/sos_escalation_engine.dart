import 'dart:async';
import '../../data/dto/api_dto.dart';
import '../../domain/repositories/repositories.dart';
import '../utils/dev_log.dart';
import 'false_alarm_manager.dart';

/// Status of the automated emergency escalation engine.
enum SosEngineState {
  idle,
  evaluating,
  countdown20s,
  dispatching,
  emergencyActive,
  cooldown,
  cancelled,
}

/// Detailed evaluation report from multi-signal SOS decision matrix.
class SosDecisionReport {
  const SosDecisionReport({
    required this.shouldEscalate,
    required this.signalCount,
    required this.reasons,
    required this.cooldownActive,
    required this.cooldownSecondsRemaining,
  });

  final bool shouldEscalate;
  final int signalCount;
  final List<String> reasons;
  final bool cooldownActive;
  final int cooldownSecondsRemaining;
}

/// Unified SOS Escalation Engine (Phases 13 - 16).
///
/// Implements:
/// - Multi-signal automatic SOS matrix (Requires >= 2 correlated signals or verified multi-stage event).
/// - 20-second cancellation window with user PIN / safe cancel.
/// - 5-minute emergency cooldown window preventing duplicate rapid alarms.
/// - False positive feedback loop on cancellation.
class SosEscalationEngine {
  SosEscalationEngine({
    required GuardianRepository guardianRepository,
    FalseAlarmManager? falseAlarmManager,
  })  : _guardianRepo = guardianRepository,
        _falseAlarmManager = falseAlarmManager;

  final GuardianRepository _guardianRepo;
  final FalseAlarmManager? _falseAlarmManager;

  SosEngineState _state = SosEngineState.idle;
  DateTime? _lastSosDispatchedTime;
  static const Duration cooldownDuration = Duration(minutes: 5);

  SosEngineState get state => _state;
  bool get isCooldownActive {
    if (_lastSosDispatchedTime == null) return false;
    return DateTime.now().difference(_lastSosDispatchedTime!) < cooldownDuration;
  }

  int get cooldownSecondsRemaining {
    if (!isCooldownActive) return 0;
    final elapsed = DateTime.now().difference(_lastSosDispatchedTime!).inSeconds;
    return (cooldownDuration.inSeconds - elapsed).clamp(0, cooldownDuration.inSeconds);
  }

  /// Evaluates multi-signal criteria for automated SOS trigger.
  ///
  /// Invariant: Single raw sensor is NEVER permitted to unilaterally trigger SOS.
  SosDecisionReport evaluateSignals({
    bool multiStageFallConfirmed = false,
    bool voiceDistressConfirmed = false,
    bool sustainedRouteDeviation = false,
    bool stationaryBreached = false,
    bool highRiskArea = false,
    int compositeRiskPercent = 0,
    bool unansweredCriticalPrompt = false,
  }) {
    final List<String> reasons = [];
    int signalCount = 0;

    if (multiStageFallConfirmed) {
      signalCount += 2; // Verified 7-stage fall includes freefall, impact, and immobility
      reasons.add('Verified multi-stage fall sequence with post-impact immobility');
    }
    if (voiceDistressConfirmed) {
      signalCount += 1;
      reasons.add('Acoustic distress keyword identified by AI model');
    }
    if (sustainedRouteDeviation) {
      signalCount += 1;
      reasons.add('Sustained corridor deviation > 100m');
    }
    if (stationaryBreached) {
      signalCount += 1;
      reasons.add('Unexpected prolonged stationary stop');
    }
    if (highRiskArea) {
      signalCount += 1;
      reasons.add('Located within elevated crime / high-risk zone');
    }
    if (compositeRiskPercent >= 80) {
      signalCount += 1;
      reasons.add('Composite AI risk score reached critical tier ($compositeRiskPercent%)');
    }
    if (unansweredCriticalPrompt) {
      signalCount += 2;
      reasons.add('User failed to respond to critical safety confirmation prompt');
    }

    final cooldown = isCooldownActive;
    final shouldEscalate = (signalCount >= 2 || unansweredCriticalPrompt) && !cooldown;

    return SosDecisionReport(
      shouldEscalate: shouldEscalate,
      signalCount: signalCount,
      reasons: reasons,
      cooldownActive: cooldown,
      cooldownSecondsRemaining: cooldownSecondsRemaining,
    );
  }

  /// Dispatches verified emergency SOS payload to backend and emergency contacts.
  Future<ApiMessageResponse> dispatchEmergencySos({
    required double lat,
    required double lng,
    required int batteryLevel,
    required String triggerType,
    String? incidentSummary,
  }) async {
    if (isCooldownActive) {
      DevLog.log('SOS_ENGINE', 'SOS dispatch suppressed by active 5-minute cooldown ($cooldownSecondsRemaining s left).');
      return const ApiMessageResponse(
        success: false,
        message: 'SOS dispatch throttled by 5-minute cooldown window.',
      );
    }

    _state = SosEngineState.dispatching;
    DevLog.log('SOS_ENGINE', 'DISPATCHING EMERGENCY SOS: type=$triggerType, coords=($lat, $lng), batt=$batteryLevel%');

    final req = SosRequest(
      lat: lat,
      lng: lng,
      triggerSource: triggerType,
      message: incidentSummary ?? 'Emergency SOS - Battery: $batteryLevel%',
    );

    try {
      final response = await _guardianRepo.triggerSos(req);
      _lastSosDispatchedTime = DateTime.now();
      _state = SosEngineState.emergencyActive;
      DevLog.log('SOS_ENGINE', 'EMERGENCY SOS CONFIRMED BY BACKEND: ${response.message}');
      return response;
    } catch (e) {
      _state = SosEngineState.idle;
      DevLog.log('SOS_ENGINE', 'Emergency SOS dispatch error: $e');
      rethrow;
    }
  }

  /// User cancels false alarm during countdown or after escalation.
  Future<void> cancelSosByUser({required String triggerType}) async {
    _state = SosEngineState.cancelled;
    DevLog.log('SOS_ENGINE', 'SOS cancelled by user ($triggerType). Recording false alarm feedback.');
    if (_falseAlarmManager != null) {
      await _falseAlarmManager.recordCancellation(triggerSource: triggerType);
    }
    _state = SosEngineState.idle;
  }

  void resetCooldown() {
    _lastSosDispatchedTime = null;
    _state = SosEngineState.idle;
  }
}
