import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/services/fcm_notification_service.dart';
import '../core/services/guardian_engine.dart';
import '../core/services/guardian_risk_engine.dart';
import '../core/services/false_alarm_manager.dart';
import '../core/services/route_deviation_detector.dart';
import '../core/services/stationary_detector.dart';
import '../core/services/eta_speed_watchdog.dart';
import '../core/services/safe_arrival_detector.dart';
import '../core/services/sos_escalation_engine.dart';
import '../core/services/notification_delivery_service.dart';
import '../core/services/permission_manager.dart';
import '../core/services/safety_score_calculator.dart';

import '../core/services/background_safety_service.dart';
import '../core/services/location_service.dart';
import '../core/services/safety_sensor_manager.dart';
import '../core/services/sensor_service.dart';
import '../core/services/token_storage_service.dart';
import '../core/services/voice_service.dart';
import '../data/repositories/repository_impl.dart';
import '../domain/repositories/repositories.dart';

final tokenStorageServiceProvider = Provider<TokenStorageService>((ref) {
  return SecureTokenStorageService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(service.dispose);
  return service;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageServiceProvider);
  final client = ApiClient(tokenStorage: tokenStorage);
  ref.onDispose(client.dispose);
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageServiceProvider),
  ),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ref.watch(apiClientProvider)),
);

final contactRepositoryProvider = Provider<ContactRepository>(
  (ref) => ContactRepositoryImpl(ref.watch(apiClientProvider)),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepositoryImpl(ref.watch(apiClientProvider)),
);

final journeyRepositoryProvider = Provider<JourneyRepository>(
  (ref) => JourneyRepositoryImpl(ref.watch(apiClientProvider)),
);

final guardianRepositoryProvider = Provider<GuardianRepository>(
  (ref) => GuardianRepositoryImpl(ref.watch(apiClientProvider)),
);

final mapRepositoryProvider = Provider<MapRepository>(
  (ref) => MapRepositoryImpl(ref.watch(apiClientProvider)),
);

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepositoryImpl(ref.watch(apiClientProvider)),
);

final toolsRepositoryProvider = Provider<ToolsRepository>(
  (ref) => ToolsRepositoryImpl(ref.watch(apiClientProvider)),
);

final intelligenceRepositoryProvider = Provider<IntelligenceRepository>(
  (ref) => IntelligenceRepositoryImpl(ref.watch(apiClientProvider)),
);

final sensorServiceProvider = Provider<SensorService>((ref) {
  final service = SensorService(
    intelligenceRepository: ref.watch(intelligenceRepositoryProvider),
  );
  ref.onDispose(service.stopMonitoring);
  return service;
});

final voiceServiceProvider = Provider<VoiceService>((ref) {
  final service = VoiceService(
    intelligenceRepository: ref.watch(intelligenceRepositoryProvider),
  );
  ref.onDispose(service.stopListening);
  return service;
});

final backgroundSafetyServiceProvider = Provider<BackgroundSafetyService>((ref) {
  final service = BackgroundSafetyService();
  ref.onDispose(service.dispose);
  return service;
});

final guardianEngineProvider = Provider<GuardianEngine>((ref) {
  final engine = GuardianEngine(
    guardianRepository: ref.watch(guardianRepositoryProvider),
    journeyRepository: ref.watch(journeyRepositoryProvider),
    locationService: ref.watch(locationServiceProvider),
    sensorService: ref.watch(sensorServiceProvider),
    voiceService: ref.watch(voiceServiceProvider),
    backgroundSafetyService: ref.watch(backgroundSafetyServiceProvider),
    routeDeviationDetector: ref.watch(routeDeviationDetectorProvider),
    stationaryDetector: ref.watch(stationaryDetectorProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

final safetySensorManagerProvider = Provider<SafetySensorManager>((ref) {
  final manager = SafetySensorManager(
    locationService: ref.watch(locationServiceProvider),
    sensorService: ref.watch(sensorServiceProvider),
    voiceService: ref.watch(voiceServiceProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

final guardianRiskEngineProvider = Provider<GuardianRiskEngine>((ref) {
  return const GuardianRiskEngine();
});

final falseAlarmManagerProvider = Provider<FalseAlarmManager>((ref) {
  final manager = FalseAlarmManager(
    intelligenceRepository: ref.watch(intelligenceRepositoryProvider),
  );
  manager.loadCalibration();
  return manager;
});

final routeDeviationDetectorProvider = Provider<RouteDeviationDetector>((ref) {
  return RouteDeviationDetector();
});

final stationaryDetectorProvider = Provider<StationaryDetector>((ref) {
  return StationaryDetector();
});

final etaSpeedWatchdogProvider = Provider<EtaSpeedWatchdog>((ref) {
  return EtaSpeedWatchdog(travelMode: TravelMode.walking);
});

final safeArrivalDetectorProvider = Provider<SafeArrivalDetector>((ref) {
  return SafeArrivalDetector();
});

final sosEscalationEngineProvider = Provider<SosEscalationEngine>((ref) {
  return SosEscalationEngine(
    guardianRepository: ref.watch(guardianRepositoryProvider),
    falseAlarmManager: ref.watch(falseAlarmManagerProvider),
  );
});

final notificationDeliveryServiceProvider = Provider<NotificationDeliveryService>((ref) {
  final service = NotificationDeliveryService(
    apiClient: ref.watch(apiClientProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final safetyPermissionManagerProvider = Provider<SafetyPermissionManager>((ref) {
  return SafetyPermissionManager();
});

final safetyScoreCalculatorProvider = Provider<SafetyScoreCalculator>((ref) {
  return const SafetyScoreCalculator();
});

final fcmNotificationServiceProvider = Provider<FcmNotificationService>((ref) {
  return FcmNotificationService(
    apiClient: ref.watch(apiClientProvider),
  );
});



