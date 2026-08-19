/// Request / response DTOs — fully wired to FastAPI backend.
/// Every fromJson matches the exact backend schema field names.
library;

// ─── Auth ─────────────────────────────────────────────────────────────────────

class LoginRequest {
  const LoginRequest({
    required this.email,
    required this.password,
    this.rememberMe = false,
  });

  final String email;
  final String password;
  final bool rememberMe;

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'remember_me': rememberMe,
      };
}

class RegisterRequest {
  const RegisterRequest({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
  });

  final String fullName;
  final String email;
  final String phone;
  final String password;

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'password': password,
      };
}

class GoogleLoginRequest {
  const GoogleLoginRequest({
    required this.idToken,
    this.platform = 'android',
  });

  final String idToken;
  final String platform;

  Map<String, dynamic> toJson() => {
        'id_token': idToken,
        'platform': platform,
      };
}

class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken: json['access_token'] as String? ?? '',
        refreshToken: json['refresh_token'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
      );
}

class StationaryCheckRequestDto {
  const StationaryCheckRequestDto({
    required this.journeyId,
    required this.currentLat,
    required this.currentLng,
    this.speedKmh = 0.0,
    this.stationaryMinutes = 0,
    this.trafficCongestionLevel = 'LOW',
    this.destLat,
    this.destLng,
  });

  final String journeyId;
  final double currentLat;
  final double currentLng;
  final double speedKmh;
  final int stationaryMinutes;
  final String trafficCongestionLevel;
  final double? destLat;
  final double? destLng;

  Map<String, dynamic> toJson() => {
        'journey_id': journeyId,
        'current_lat': currentLat,
        'current_lng': currentLng,
        'speed_kmh': speedKmh,
        'stationary_minutes': stationaryMinutes,
        'traffic_congestion_level': trafficCongestionLevel,
        if (destLat != null) 'destination_lat': destLat,
        if (destLng != null) 'destination_lng': destLng,
      };
}

class StationaryCheckResponseDto {
  const StationaryCheckResponseDto({
    required this.journeyId,
    required this.isStationary,
    required this.isTrafficDelay,
    required this.alertLevel,
    required this.message,
    required this.requiresPrompt,
  });

  final String journeyId;
  final bool isStationary;
  final bool isTrafficDelay;
  final String alertLevel;
  final String message;
  final bool requiresPrompt;

  factory StationaryCheckResponseDto.fromJson(Map<String, dynamic> json) =>
      StationaryCheckResponseDto(
        journeyId: json['journey_id'] as String? ?? '',
        isStationary: json['is_stationary'] as bool? ?? false,
        isTrafficDelay: json['is_traffic_delay'] as bool? ?? false,
        alertLevel: json['alert_level'] as String? ?? 'NONE',
        message: json['message'] as String? ?? '',
        requiresPrompt: json['requires_prompt'] as bool? ?? false,
      );
}

class RerouteRequestDto {
  const RerouteRequestDto({
    required this.journeyId,
    required this.currentLat,
    required this.currentLng,
    required this.destLat,
    required this.destLng,
    this.destinationName = 'Destination',
    this.travelMode = 'DRIVE',
  });

  final String journeyId;
  final double currentLat;
  final double currentLng;
  final double destLat;
  final double destLng;
  final String destinationName;
  final String travelMode;

  Map<String, dynamic> toJson() => {
        'journey_id': journeyId,
        'current_lat': currentLat,
        'current_lng': currentLng,
        'destination_lat': destLat,
        'destination_lng': destLng,
        'destination_name': destinationName,
        'travel_mode': travelMode,
      };
}

// ─── Journey ──────────────────────────────────────────────────────────────────

class StartJourneyRequest {
  const StartJourneyRequest({
    required this.origin,
    required this.destination,
    this.originLat,
    this.originLng,
    this.destLat,
    this.destLng,
  });

  final String origin;
  final String destination;
  final double? originLat;
  final double? originLng;
  final double? destLat;
  final double? destLng;

  Map<String, dynamic> toJson() => {
        'origin': origin,
        'destination': destination,
        if (originLat != null) 'origin_lat': originLat,
        if (originLng != null) 'origin_lng': originLng,
        if (destLat != null) 'dest_lat': destLat,
        if (destLng != null) 'dest_lng': destLng,
      };
}

// ─── Emergency ────────────────────────────────────────────────────────────────

class SosRequest {
  const SosRequest({
    required this.lat,
    required this.lng,
    this.message,
    this.triggerSource = 'manual',
  });

  final double lat;
  final double lng;
  final String? message;
  final String triggerSource;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        if (message != null) 'message': message,
        'trigger_source': triggerSource,
      };
}

// ─── Guardian heartbeat ───────────────────────────────────────────────────────

class HeartbeatRequest {
  const HeartbeatRequest({
    this.lat,
    this.lng,
    this.batteryPercent,
    this.speedKmh,
  });

  final double? lat;
  final double? lng;
  final int? batteryPercent;
  final double? speedKmh;

  Map<String, dynamic> toJson() => {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (batteryPercent != null) 'battery_percent': batteryPercent,
        if (speedKmh != null) 'speed_kmh': speedKmh,
      };
}

// ─── Generic response ─────────────────────────────────────────────────────────

class ApiMessageResponse {
  const ApiMessageResponse({required this.success, required this.message});

  final bool success;
  final String message;

  factory ApiMessageResponse.fromJson(Map<String, dynamic> json) =>
      ApiMessageResponse(
        success: json['success'] as bool? ?? true,
        message: json['message'] as String? ?? '',
      );
}

// ─── Advanced Safety Intelligence DTOs ────────────────────────────────────────

class CheckInStartRequest {
  const CheckInStartRequest({
    this.title = 'Safety Check-In',
    this.durationMinutes = 15,
    this.promptMessage = 'Please confirm you have arrived safely.',
  });

  final String title;
  final int durationMinutes;
  final String promptMessage;

  Map<String, dynamic> toJson() => {
        'title': title,
        'duration_minutes': durationMinutes,
        'prompt_message': promptMessage,
      };
}

class MotionSignalRequest {
  const MotionSignalRequest({
    this.eventType = 'MOTION_ANOMALY',
    this.durationMs = 0,
    this.accelerationPeak = 0.0,
    this.rotationPeak = 0.0,
    this.suddenStop = false,
    this.confidence = 0.5,
    this.journeyId,
  });

  final String eventType;
  final int durationMs;
  final double accelerationPeak;
  final double rotationPeak;
  final bool suddenStop;
  final double confidence;
  final String? journeyId;

  Map<String, dynamic> toJson() => {
        'event_type': eventType,
        'duration_ms': durationMs,
        'acceleration_peak': accelerationPeak,
        'rotation_peak': rotationPeak,
        'sudden_stop': suddenStop,
        'confidence': confidence,
        if (journeyId != null) 'journey_id': journeyId,
      };
}

class VoiceAnalysisRequest {
  const VoiceAnalysisRequest({
    this.transcriptOrText = '',
    this.voiceIntensity = 0.5,
    this.pitchVariance = 0.5,
    this.speechRateWpm,
    this.durationMs = 2000,
    this.journeyId,
  });

  final String transcriptOrText;
  final double voiceIntensity;
  final double pitchVariance;
  final int? speechRateWpm;
  final int durationMs;
  final String? journeyId;

  Map<String, dynamic> toJson() => {
        'transcript_or_text': transcriptOrText,
        'voice_intensity': voiceIntensity,
        'pitch_variance': pitchVariance,
        if (speechRateWpm != null) 'speech_rate_wpm': speechRateWpm,
        'duration_ms': durationMs,
        if (journeyId != null) 'journey_id': journeyId,
      };
}

class SignalInputDto {
  const SignalInputDto({
    required this.type,
    required this.score,
    this.confidence = 1.0,
    this.details,
  });

  final String type;
  final double score;
  final double confidence;
  final String? details;

  Map<String, dynamic> toJson() => {
        'type': type,
        'score': score,
        'confidence': confidence,
        if (details != null) 'details': details,
      };
}

class RiskFusionRequest {
  const RiskFusionRequest({
    required this.signals,
    this.journeyId,
    this.guardianModeActive = false,
    this.nearbySafetyIncident = false,
  });

  final List<SignalInputDto> signals;
  final String? journeyId;
  final bool guardianModeActive;
  final bool nearbySafetyIncident;

  Map<String, dynamic> toJson() => {
        'signals': signals.map((s) => s.toJson()).toList(),
        if (journeyId != null) 'journey_id': journeyId,
        'guardian_mode_active': guardianModeActive,
        'nearby_safety_incident': nearbySafetyIncident,
      };
}

class FalsePositiveFeedbackRequest {
  const FalsePositiveFeedbackRequest({
    required this.triggerSource,
    this.userResponse = 'I_AM_SAFE',
    this.eventId,
    this.voiceScore,
    this.motionScore,
    this.routeDeviation = false,
    this.notes,
  });

  final String triggerSource;
  final String userResponse;
  final String? eventId;
  final double? voiceScore;
  final double? motionScore;
  final bool routeDeviation;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'trigger_source': triggerSource,
        'user_response': userResponse,
        if (eventId != null) 'event_id': eventId,
        if (voiceScore != null) 'voice_score': voiceScore,
        if (motionScore != null) 'motion_score': motionScore,
        'route_deviation': routeDeviation,
        if (notes != null) 'notes': notes,
      };
}

class SyncEventItem {
  const SyncEventItem({
    required this.idempotencyKey,
    required this.entityType,
    required this.payload,
    required this.occurredAt,
  });

  final String idempotencyKey;
  final String entityType;
  final Map<String, dynamic> payload;
  final String occurredAt;

  Map<String, dynamic> toJson() => {
        'idempotency_key': idempotencyKey,
        'entity_type': entityType,
        'payload': payload,
        'occurred_at': occurredAt,
      };
}

class OfflineBatchSyncRequest {
  const OfflineBatchSyncRequest({required this.events});

  final List<SyncEventItem> events;

  Map<String, dynamic> toJson() => {
        'events': events.map((e) => e.toJson()).toList(),
      };
}


