/// Domain entities — pure Dart, no Flutter imports.
library;

export 'safety_event_model.dart';

class UserEntity {
  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.isPremium,
    required this.membershipName,
    required this.nextBilling,
    required this.safeTrips,
    required this.trustedContactCount,
    required this.appVersion,
    required this.safetyShieldActive,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String avatarUrl;
  final bool isPremium;
  final String membershipName;
  final String nextBilling;
  final int safeTrips;
  final int trustedContactCount;
  final String appVersion;
  final bool safetyShieldActive;
}

class TrustedContactEntity {
  const TrustedContactEntity({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.isOnline,
    required this.phone,
    this.relationshipLabel = 'Friend',
    this.emergencyNotifyEnabled = true,
    this.locationShareEnabled = false,
    this.priority = 1,
  });

  final String id;
  final String name;
  final String avatarUrl;
  final bool isOnline;
  final String phone;
  final String relationshipLabel;
  final bool emergencyNotifyEnabled;
  final bool locationShareEnabled;
  final int priority;

  TrustedContactEntity copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    bool? isOnline,
    String? phone,
    String? relationshipLabel,
    bool? emergencyNotifyEnabled,
    bool? locationShareEnabled,
    int? priority,
  }) {
    return TrustedContactEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      phone: phone ?? this.phone,
      relationshipLabel: relationshipLabel ?? this.relationshipLabel,
      emergencyNotifyEnabled: emergencyNotifyEnabled ?? this.emergencyNotifyEnabled,
      locationShareEnabled: locationShareEnabled ?? this.locationShareEnabled,
      priority: priority ?? this.priority,
    );
  }
}


class WeatherEntity {
  const WeatherEntity({
    required this.temperatureC,
    required this.location,
    required this.condition,
    required this.visibilityKm,
  });

  final int temperatureC;
  final String location;
  final String condition;
  final double visibilityKm;
}

class NearbyServiceEntity {
  const NearbyServiceEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.distanceKm,
  });

  final String id;
  final String name;
  final NearbyServiceType type;
  final double distanceKm;
}

enum NearbyServiceType { metro, hospital, police }

class JourneyEntity {
  const JourneyEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.from,
    required this.to,
    required this.dateLabel,
    required this.timeRange,
    required this.safetyScore,
    required this.isAlert,
    required this.completedSafely,
  });

  final String id;
  final String title;
  final String subtitle;
  final String from;
  final String to;
  final String dateLabel;
  final String timeRange;
  final double safetyScore;
  final bool isAlert;
  final bool completedSafely;
}

class DashboardEntity {
  const DashboardEntity({
    required this.userName,
    required this.avatarUrl,
    required this.safetyScore,
    required this.safetyStatus,
    required this.guardianModeActive,
    required this.guardianSubtitle,
    required this.recentJourney,
    required this.weather,
    required this.aiScanningLabel,
    required this.nearbyServices,
    required this.contacts,
  });

  final String userName;
  final String avatarUrl;
  final int safetyScore;
  final String safetyStatus;
  final bool guardianModeActive;
  final String guardianSubtitle;
  final JourneyEntity recentJourney;
  final WeatherEntity weather;
  final String aiScanningLabel;
  final List<NearbyServiceEntity> nearbyServices;
  final List<TrustedContactEntity> contacts;
}

class GuardianStatusEntity {
  const GuardianStatusEntity({
    required this.isActive,
    required this.statusLabel,
    required this.monitoringLabel,
    required this.voiceSyncLive,
    required this.voiceSyncState,
    required this.batteryPercent,
    required this.speedKmh,
    required this.speedStatus,
    required this.estimatedArrival,
    required this.minutesLeft,
    required this.origin,
    required this.destination,
    required this.progress,
    required this.currentLocation,
    required this.avatarUrl,
  });

  final bool isActive;
  final String statusLabel;
  final String monitoringLabel;
  final bool voiceSyncLive;
  final String voiceSyncState;
  final int batteryPercent;
  final double speedKmh;
  final String speedStatus;
  final String estimatedArrival;
  final int minutesLeft;
  final String origin;
  final String destination;
  final double progress;
  final String currentLocation;
  final String avatarUrl;
}

class MapPoiEntity {
  const MapPoiEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.lat,
    required this.lng,
  });

  final String id;
  final String name;
  final NearbyServiceType type;
  final double lat;
  final double lng;
}

class MapRouteEntity {
  const MapRouteEntity({
    required this.from,
    required this.to,
    required this.safetyScore,
    required this.safetyLabel,
    required this.etaMinutes,
    required this.trafficLabel,
    required this.distanceKm,
    required this.via,
    required this.policeNearby,
    required this.hospitalsNearby,
    required this.metroKm,
    required this.routePoints,
    required this.pois,
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
  });

  final String from;
  final String to;
  final int safetyScore;
  final String safetyLabel;
  final int etaMinutes;
  final String trafficLabel;
  final double distanceKm;
  final String via;
  final int policeNearby;
  final int hospitalsNearby;
  final double metroKm;
  final List<LatLngPoint> routePoints;
  final List<MapPoiEntity> pois;
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
}

class LatLngPoint {
  const LatLngPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

class SafetyZoneEntity {
  const SafetyZoneEntity({
    required this.id,
    required this.place,
    required this.category,
    required this.anchorArea,
    required this.demoSafetyLabel,
    required this.dayRiskScore,
    required this.nightRiskScore,
    required this.routeRiskScore,
    required this.footfall,
    required this.nightActivity,
    required this.lighting,
    required this.isolation,
    required this.recommendation,
    required this.demoSafetyScore,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 600.0,
    this.dataStatus = 'DEMO / UNVERIFIED',
    this.sourceBasis = '',
    this.disclaimer = 'Prototype/demo data — not official crime statistics.',
  });

  final String id;
  final String place;
  final String category;
  final String anchorArea;
  final String demoSafetyLabel;
  final int dayRiskScore;
  final int nightRiskScore;
  final int routeRiskScore;
  final String footfall;
  final String nightActivity;
  final String lighting;
  final String isolation;
  final String recommendation;
  final int demoSafetyScore;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String dataStatus;
  final String sourceBasis;
  final String disclaimer;

  String get riskCategoryLabel {
    if (demoSafetyScore >= 75) return 'Lower Risk';
    if (demoSafetyScore >= 50) return 'Moderate Risk';
    return 'Higher Risk';
  }
}

class PoliceStationEntity {
  const PoliceStationEntity({
    required this.id,
    required this.city,
    required this.zone,
    required this.subDivision,
    required this.stationName,
    required this.contactNumber,
    this.address,
    this.latitude,
    this.longitude,
    this.distanceMeters,
    this.distanceDisplay,
    this.sourceInfo = 'Chennai Police Department directory - informational prototype data',
  });

  final String id;
  final String city;
  final String zone;
  final String subDivision;
  final String stationName;
  final String contactNumber;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? distanceMeters;
  final String? distanceDisplay;
  final String sourceInfo;
}

class NearbyHelpItemEntity {
  const NearbyHelpItemEntity({
    required this.id,
    required this.name,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.distanceDisplay,
    this.rating,
    this.openNow,
    this.source,
  });

  final String id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final String distanceDisplay;
  final double? rating;
  final bool? openNow;
  final String? source;
}

class NearbyHelpEntity {
  const NearbyHelpEntity({
    required this.policeDistance,
    required this.hospitalDistance,
    required this.stationDistance,
    required this.activeAreaDistance,
    required this.policeStations,
    required this.hospitals,
    required this.stations,
    required this.activePlaces,
    required this.disclaimer,
  });

  final String policeDistance;
  final String hospitalDistance;
  final String stationDistance;
  final String activeAreaDistance;
  final List<PoliceStationEntity> policeStations;
  final List<NearbyHelpItemEntity> hospitals;
  final List<NearbyHelpItemEntity> stations;
  final List<NearbyHelpItemEntity> activePlaces;
  final String disclaimer;
}

class GuardianRouteAlternativeEntity {
  const GuardianRouteAlternativeEntity({
    required this.routeIndex,
    required this.summary,
    required this.role,
    required this.tag,
    required this.safetyScore,
    required this.durationMinutes,
    required this.distanceKm,
    required this.trafficCondition,
    required this.points,
    required this.reason,
    required this.impactedZones,
  });

  final int routeIndex;
  final String summary;
  final String role; // 'Safer Route', 'Fastest Route', 'Balanced Route'
  final String tag;  // '🛡 Recommended', '⚡ Fastest', '⚖ Balanced'
  final int safetyScore;
  final int durationMinutes;
  final double distanceKm;
  final String trafficCondition;
  final List<LatLngPoint> points;
  final String reason;
  final List<Map<String, dynamic>> impactedZones;
}

class GuardianRoutePlanEntity {
  const GuardianRoutePlanEntity({
    required this.originLat,
    required this.originLng,
    required this.destLat,
    required this.destLng,
    required this.destinationName,
    required this.isNight,
    required this.evaluationPeriod,
    required this.recommendedRoute,
    required this.alternatives,
    required this.safetyScore,
    required this.riskLevel,
    required this.riskZones,
    required this.nearbyPolice,
    required this.nearbyHospitals,
    required this.nearbyStations,
    required this.activePlaces,
    required this.travelTimeDisplay,
    required this.distanceDisplay,
    required this.reason,
    required this.disclaimer,
  });

  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;
  final String destinationName;
  final bool isNight;
  final String evaluationPeriod;
  final GuardianRouteAlternativeEntity recommendedRoute;
  final List<GuardianRouteAlternativeEntity> alternatives;
  final int safetyScore;
  final String riskLevel;
  final List<Map<String, dynamic>> riskZones;
  final List<PoliceStationEntity> nearbyPolice;
  final List<NearbyHelpItemEntity> nearbyHospitals;
  final List<NearbyHelpItemEntity> nearbyStations;
  final List<NearbyHelpItemEntity> activePlaces;
  final String travelTimeDisplay;
  final String distanceDisplay;
  final String reason;
  final String disclaimer;
}

class WeeklyOverviewEntity {
  const WeeklyOverviewEntity({
    required this.globalScore,
    required this.bars,
    required this.labels,
  });

  final int globalScore;
  final List<double> bars;
  final List<String> labels;
}

class ActivityMetricEntity {
  const ActivityMetricEntity({
    required this.label,
    required this.value,
    required this.iconKey,
  });

  final String label;
  final String value;
  final String iconKey;
}

class AchievementEntity {
  const AchievementEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.unlocked,
    required this.iconKey,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool unlocked;
  final String iconKey;
}

class SafetyEventEntity {
  const SafetyEventEntity({
    required this.id,
    required this.time,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String time;
  final String title;
  final String subtitle;
}

class ActivityEntity {
  const ActivityEntity({
    required this.avatarUrl,
    required this.weeklyOverview,
    required this.metrics,
    required this.journeys,
    required this.achievements,
    required this.safetyEvents,
  });

  final String avatarUrl;
  final WeeklyOverviewEntity weeklyOverview;
  final List<ActivityMetricEntity> metrics;
  final List<JourneyEntity> journeys;
  final List<AchievementEntity> achievements;
  final List<SafetyEventEntity> safetyEvents;
}

class NotificationEntity {
  const NotificationEntity({
    required this.id,
    required this.title,
    required this.body,
    required this.timeLabel,
    required this.isRead,
  });

  final String id;
  final String title;
  final String body;
  final String timeLabel;
  final bool isRead;
}

class FakeCallEntity {
  const FakeCallEntity({
    required this.callerName,
    required this.callerNumber,
    required this.delaySeconds,
  });

  final String callerName;
  final String callerNumber;
  final int delaySeconds;
}

class FakeMessageEntity {
  const FakeMessageEntity({
    required this.senderName,
    required this.message,
  });

  final String senderName;
  final String message;
}

class AreaSafetyEntity {
  const AreaSafetyEntity({
    required this.areaName,
    required this.score,
    required this.label,
  });

  final String areaName;
  final int score;
  final String label;
}

// ─── Advanced Safety Intelligence Entities ────────────────────────────────────

class RiskSignalEntity {
  const RiskSignalEntity({
    required this.type,
    required this.score,
    required this.weightedContribution,
    required this.explanation,
  });

  final String type;
  final double score;
  final double weightedContribution;
  final String explanation;
}

class RiskAssessmentEntity {
  const RiskAssessmentEntity({
    required this.riskLevel,
    required this.riskScore,
    required this.signals,
    required this.recommendedAction,
    required this.requiresUserPrompt,
    required this.autoEscalatePrepared,
  });

  final String riskLevel; // LOW / MEDIUM / HIGH / CRITICAL
  final double riskScore;
  final List<RiskSignalEntity> signals;
  final String recommendedAction;
  final bool requiresUserPrompt;
  final bool autoEscalatePrepared;
}

class SafetyCheckInEntity {
  const SafetyCheckInEntity({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.status,
    required this.startedAt,
    required this.expiresAt,
    required this.minutesRemaining,
    this.confirmedAt,
  });

  final String id;
  final String title;
  final int durationMinutes;
  final String status;
  final String startedAt;
  final String expiresAt;
  final int minutesRemaining;
  final String? confirmedAt;
}

class VoiceDistressEntity {
  const VoiceDistressEntity({
    required this.signal,
    required this.distressScore,
    required this.urgency,
    required this.helpKeyword,
    required this.repetitionCount,
    required this.voiceIntensity,
    required this.modelConfidence,
    required this.matchedKeywords,
    required this.message,
  });

  final String signal;
  final double distressScore;
  final String urgency;
  final bool helpKeyword;
  final int repetitionCount;
  final double voiceIntensity;
  final double modelConfidence;
  final List<String> matchedKeywords;
  final String message;
}

class MotionAnomalyEntity {
  const MotionAnomalyEntity({
    required this.eventId,
    required this.eventType,
    required this.evaluatedRiskContribution,
    required this.confidenceAdjusted,
    required this.message,
  });

  final String eventId;
  final String eventType;
  final double evaluatedRiskContribution;
  final double confidenceAdjusted;
  final String message;
}

class SafetyRecommendationEntity {
  const SafetyRecommendationEntity({
    required this.id,
    required this.title,
    required this.category,
    required this.evidence,
    required this.actionType,
    required this.actionLabel,
  });

  final String id;
  final String title;
  final String category;
  final String evidence;
  final String actionType;
  final String actionLabel;
}

