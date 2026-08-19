import '../entities/entities.dart';
import '../../data/dto/api_dto.dart';

abstract class AuthRepository {
  Future<AuthResponse> login(LoginRequest request);
  Future<AuthResponse> register(RegisterRequest request);
  Future<AuthResponse> loginWithGoogle(String idToken);
  Future<void> logout();
  Future<void> forgotPassword(String email);
  Future<bool> isAuthenticated();
}

abstract class ProfileRepository {
  Future<UserEntity> fetchProfile();
  Future<UserEntity> updateProfile(UserEntity user);
  Future<List<TrustedContactEntity>> fetchContacts();
  Future<void> addContact(TrustedContactEntity contact);
}

abstract class ContactRepository {
  Future<List<TrustedContactEntity>> fetchContacts();
  Future<TrustedContactEntity> createContact(TrustedContactEntity contact);
  Future<TrustedContactEntity> updateContact(TrustedContactEntity contact);
  Future<void> deleteContact(String contactId);
}


abstract class DashboardRepository {
  Future<DashboardEntity> fetchDashboard({double? lat, double? lng});
  Future<WeatherEntity> fetchWeather({double? lat, double? lng});
  Future<List<NearbyServiceEntity>> fetchNearbyServices({double? lat, double? lng});
}



abstract class JourneyRepository {
  Future<JourneyEntity> fetchJourney(String id);
  Future<List<JourneyEntity>> fetchJourneys();
  Future<JourneyEntity> startJourney(StartJourneyRequest request);
  Future<void> stopJourney(String id);
  Future<void> checkStationary(StationaryCheckRequestDto request);
}

abstract class GuardianRepository {
  Future<GuardianStatusEntity> fetchStatus();
  Future<GuardianStatusEntity> startGuardian();
  Future<GuardianStatusEntity> stopGuardian();
  Future<ApiMessageResponse> triggerSos(SosRequest request);
  Future<void> sendHeartbeat(HeartbeatRequest request);
  Future<GuardianRoutePlanEntity> calculateSafeRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String? destinationName,
    String travelMode = 'DRIVE',
    String? departureTime,
  });
  Future<List<SafetyZoneEntity>> fetchSafetyZones();
  Future<List<PoliceStationEntity>> fetchPoliceStations({
    double? lat,
    double? lng,
    int limit = 15,
  });
  Future<NearbyHelpEntity> fetchNearbyHelp({double? lat, double? lng});
}


abstract class MapRepository {
  Future<MapRouteEntity> fetchRoute({
    String? destination,
    double? originLat,
    double? originLng,
    double? destLat,
    double? destLng,
  });
  Future<List<AreaSafetyEntity>> fetchAreaSafety();
}


abstract class ActivityRepository {
  Future<ActivityEntity> fetchActivity();
  Future<List<NotificationEntity>> fetchNotifications();
  Future<List<AchievementEntity>> fetchAchievements();
}

abstract class ToolsRepository {
  Future<FakeCallEntity> fetchFakeCall();
  Future<FakeMessageEntity> fetchFakeMessage();
  Future<ApiMessageResponse> startFakeCall();
  Future<ApiMessageResponse> startFakeMessage();
}

abstract class IntelligenceRepository {
  Future<MotionAnomalyEntity> sendMotionSignal(MotionSignalRequest request);
  Future<VoiceDistressEntity> sendVoiceAnalysis(VoiceAnalysisRequest request);
  Future<RiskAssessmentEntity> fuseRisk(RiskFusionRequest request);
  Future<ApiMessageResponse> recordFalsePositive(FalsePositiveFeedbackRequest request);
  Future<SafetyCheckInEntity> startCheckIn(CheckInStartRequest request);
  Future<ApiMessageResponse> confirmCheckIn(String checkInId);
  Future<ApiMessageResponse> cancelCheckIn(String checkInId);
  Future<List<SafetyCheckInEntity>> fetchCheckIns();
  Future<List<SafetyRecommendationEntity>> fetchRecommendations();
}

