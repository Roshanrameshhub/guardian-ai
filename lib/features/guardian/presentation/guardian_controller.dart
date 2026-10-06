import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/guardian_risk_engine.dart';
import '../../../core/utils/dev_log.dart';
import '../../../data/dto/api_dto.dart';
import '../../../domain/entities/entities.dart';
import '../../../providers/repository_providers.dart';
import '../../home/presentation/home_controller.dart';

final guardianRiskReportProvider = Provider<RiskAssessmentReport>((ref) {
  final engine = ref.watch(guardianEngineProvider);
  final dashboard = ref.watch(dashboardProvider).valueOrNull;

  if (!engine.isActive) {
    return RiskAssessmentReport.baseline();
  }

  final riskEngine = ref.watch(guardianRiskEngineProvider);
  return riskEngine.evaluateRisk(
    currentTime: DateTime.now(),
    locationSafetyScore: dashboard?.safetyScore.toDouble() ?? 82.0,
    batteryPercent: engine.batteryPercent,
    stationarySeconds: engine.stationarySeconds,
    weatherCondition: dashboard?.weather.condition,
    accumulatedFactors: engine.accumulatedSignals,
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
