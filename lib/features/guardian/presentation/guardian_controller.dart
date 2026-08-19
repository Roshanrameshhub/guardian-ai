import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/guardian_risk_engine.dart';
import '../../../core/utils/dev_log.dart';
import '../../../data/dto/api_dto.dart';
import '../../../domain/entities/entities.dart';
import '../../../providers/repository_providers.dart';

final guardianRiskReportProvider = Provider<RiskAssessmentReport>((ref) {
  final riskEngine = ref.watch(guardianRiskEngineProvider);
  final engine = ref.watch(guardianEngineProvider);
  final voiceService = ref.watch(voiceServiceProvider);
  final sensorService = ref.watch(sensorServiceProvider);

  // Compute live multi-signal risk
  return riskEngine.evaluateRisk(
    currentTime: DateTime.now(),
    locationSafetyScore: 82.0, // Baseline Chennai safety dataset score
    batteryPercent: engine.batteryPercent,
    hasMotionAnomaly: sensorService.liveAccelMagnitude > 22.0,
    motionAnomalyPeak: sensorService.liveAccelMagnitude,
    hasVoiceDistress: voiceService.matchedKeywords.isNotEmpty,
    voiceUrgency: voiceService.latestUrgency,
  );
});

final guardianStatusProvider = FutureProvider<GuardianStatusEntity>((ref) async {
  DevLog.guardian('Fetching Guardian status from backend...');
  try {
    final status = await ref.watch(guardianRepositoryProvider).fetchStatus();
    DevLog.guardian('Guardian status: active=${status.isActive}, label=${status.statusLabel}');
    return status;
  } catch (e) {
    DevLog.guardian('Failed to fetch Guardian status', error: e);
    rethrow;
  }
});

class GuardianController extends StateNotifier<AsyncValue<GuardianStatusEntity?>> {
  GuardianController(this._ref) : super(const AsyncData(null));

  final Ref _ref;

  Future<void> toggle(bool active) async {
    DevLog.guardian('Toggling Guardian Mode: active=$active');
    state = const AsyncLoading();
    try {
      final engine = _ref.read(guardianEngineProvider);
      final result = active ? await engine.startGuardian() : await engine.stopGuardian();
      _ref.invalidate(guardianStatusProvider);
      DevLog.guardian('Guardian Mode toggle successful: ${result.statusLabel}');
      state = AsyncData(result);
    } catch (e, st) {
      DevLog.guardian('Guardian Mode toggle failed', error: e);
      state = AsyncError(e, st);
    }
  }

  Future<ApiMessageResponse> holdToAlarm() async {
    DevLog.sos('Hold-to-Alarm triggered from Guardian screen');
    final locationService = _ref.read(locationServiceProvider);
    final pos = await locationService.getCurrentPosition();
    return await _ref.read(guardianRepositoryProvider).triggerSos(
          SosRequest(
            lat: pos.latitude,
            lng: pos.longitude,
            triggerSource: 'hold_to_alarm',
            message: 'HOLD TO ALARM triggered',
          ),
        );
  }
}

final guardianControllerProvider =
    StateNotifierProvider<GuardianController, AsyncValue<GuardianStatusEntity?>>(
  GuardianController.new,
);
