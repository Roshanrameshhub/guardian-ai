import '../config/api_config.dart';

/// Configurable API endpoints — connected to live FastAPI backend.
abstract final class ApiConstants {
  static String get baseUrl => ApiConfig.baseUrl;

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String googleLogin = '/auth/google';
  static const String logout = '/auth/logout';
  static const String refreshToken = '/auth/refresh';
  static const String forgotPassword = '/auth/forgot-password';

  // Profile
  static const String profile = '/profile';
  static const String updateProfile = '/profile';
  static const String contacts = '/contacts';

  // Dashboard & safety
  static const String dashboard = '/dashboard';
  static const String safetyScore = '/safety/score';
  static const String weather = '/weather';
  static const String nearbyServices = '/services/nearby';

  // Journey / Map
  static const String journey = '/journey';
  static const String startJourney = '/journey/start';
  static const String stopJourney = '/journey/stop';
  static const String journeys = '/journeys';
  static const String journeyStationaryCheck = '/journey/stationary-check';
  static const String journeyReroute = '/journey/reroute';
  static const String route = '/map/route';
  static const String areaSafety = '/map/area-safety';

  // Guardian Mode & Safety Navigation
  static const String startGuardian = '/guardian/start';
  static const String stopGuardian = '/guardian/stop';
  static const String guardianStatus = '/guardian/status';
  static const String guardianHeartbeat = '/guardian';
  static const String guardianRoute = '/guardian/route';
  static const String safetyZones = '/guardian/safety-zones';
  static const String policeStations = '/guardian/police-stations';
  static const String nearbyHelp = '/guardian/nearby-help';

  // AI & Intelligence Features
  static const String aiChat = '/ai/chat';
  static const String aiInsights = '/ai/insights';
  static const String signalsMotion = '/signals/motion';
  static const String signalsVoice = '/signals/voice';
  static const String riskFuse = '/risk/fuse';
  static const String falsePositive = '/safety/false-positive';
  static const String safeArrival = '/safety/safe-arrival';
  static const String routeDeviation = '/safety/route-deviation';
  static const String checkins = '/checkins';
  static const String syncEvents = '/sync/events';
  static const String recommendations = '/safety/recommendations';
  static const String locationShare = '/location/share';

  // Activity & notifications
  static const String activity = '/activity';
  static const String notifications = '/notifications';
  static const String statistics = '/statistics';
  static const String achievements = '/achievements';
  static const String safetyEvents = '/safety/events';

  // Fake tools
  static const String fakeCall = '/tools/fake-call';
  static const String fakeMessage = '/tools/fake-message';

  // SOS
  static const String sos = '/emergency/sos';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
