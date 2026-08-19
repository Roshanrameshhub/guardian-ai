import '../../core/constants/api_constants.dart';

import '../../core/network/api_client.dart';
import '../../core/services/token_storage_service.dart';
import '../../core/utils/dev_log.dart';
import '../../core/utils/polyline_utils.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../dto/api_dto.dart';

// ─── Entity Deserializers ──────────────────────────────────────────────────────

UserEntity _userFromJson(Map<String, dynamic> json) => UserEntity(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      isPremium: json['is_premium'] as bool? ?? false,
      membershipName: json['membership_name'] as String? ?? 'Guardian Free',
      nextBilling: json['next_billing'] as String? ?? '',
      safeTrips: (json['safe_trips'] as num?)?.toInt() ?? 0,
      trustedContactCount: (json['trusted_contact_count'] as num?)?.toInt() ?? 0,
      appVersion: json['app_version'] as String? ?? '',
      safetyShieldActive: json['safety_shield_active'] as bool? ?? false,
    );

TrustedContactEntity _contactFromJson(Map<String, dynamic> json) =>
    TrustedContactEntity(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      isOnline: json['is_online'] as bool? ?? false,
      phone: json['phone'] as String? ?? '',
      relationshipLabel: json['relationship_label'] as String? ?? 'Friend',
      emergencyNotifyEnabled: json['emergency_notify_enabled'] as bool? ?? true,
      locationShareEnabled: json['location_share_enabled'] as bool? ?? false,
      priority: (json['priority'] as num?)?.toInt() ?? 1,
    );

WeatherEntity _weatherFromJson(Map<String, dynamic> json) => WeatherEntity(
      temperatureC: (json['temperature_c'] as num?)?.toInt() ?? 0,
      location: json['location'] as String? ?? 'Location unavailable',
      condition: json['condition'] as String? ?? 'Unknown',
      visibilityKm: (json['visibility_km'] as num?)?.toDouble() ?? 0.0,
    );

NearbyServiceEntity _serviceFromJson(Map<String, dynamic> json) =>
    NearbyServiceEntity(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: _serviceType(json['type'] as String? ?? ''),
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
    );

NearbyServiceType _serviceType(String type) {
  switch (type.toLowerCase()) {
    case 'hospital':
      return NearbyServiceType.hospital;
    case 'police':
      return NearbyServiceType.police;
    default:
      return NearbyServiceType.metro;
  }
}

JourneyEntity _journeyFromJson(Map<String, dynamic> json) => JourneyEntity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      from: json['from_'] as String? ?? json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      dateLabel: json['date_label'] as String? ?? '',
      timeRange: json['time_range'] as String? ?? '',
      safetyScore: (json['safety_score'] as num?)?.toDouble() ?? 0.0,
      isAlert: json['is_alert'] as bool? ?? false,
      completedSafely: json['completed_safely'] as bool? ?? false,
    );

DashboardEntity _dashboardFromJson(Map<String, dynamic> json) {
  final recentJourneyJson = json['recent_journey'];
  final weatherJson = json['weather'] as Map<String, dynamic>? ?? {};
  final nearbyList = (json['nearby_services'] as List<dynamic>?) ?? [];
  final contactsList = (json['contacts'] as List<dynamic>?) ?? [];

  return DashboardEntity(
    userName: json['user_name'] as String? ?? 'Guardian User',
    avatarUrl: json['avatar_url'] as String? ?? '',
    safetyScore: (json['safety_score'] as num?)?.toInt() ?? 85,
    safetyStatus: json['safety_status'] as String? ?? 'SECURE',
    guardianModeActive: json['guardian_mode_active'] as bool? ?? false,
    guardianSubtitle: json['guardian_subtitle'] as String? ?? 'Guardian inactive',
    recentJourney: recentJourneyJson != null
        ? _journeyFromJson(recentJourneyJson as Map<String, dynamic>)
        : const JourneyEntity(
            id: '',
            title: 'No recent journeys',
            subtitle: 'Start a safe walk to begin tracking',
            from: '',
            to: '',
            dateLabel: 'Today',
            timeRange: '',
            safetyScore: 10.0,
            isAlert: false,
            completedSafely: true,
          ),
    weather: _weatherFromJson(weatherJson),
    aiScanningLabel: json['ai_scanning_label'] as String? ?? 'Guardian inactive',
    nearbyServices:
        nearbyList.map((s) => _serviceFromJson(s as Map<String, dynamic>)).toList(),
    contacts:
        contactsList.map((c) => _contactFromJson(c as Map<String, dynamic>)).toList(),
  );
}

GuardianStatusEntity _guardianFromJson(Map<String, dynamic> json) =>
    GuardianStatusEntity(
      isActive: json['is_active'] as bool? ?? false,
      statusLabel: json['status_label'] as String? ?? 'INACTIVE',
      monitoringLabel: json['monitoring_label'] as String? ?? 'Guardian paused',
      voiceSyncLive: json['voice_sync_live'] as bool? ?? false,
      voiceSyncState: json['voice_sync_state'] as String? ?? 'Idle',
      batteryPercent: (json['battery_percent'] as num?)?.toInt() ?? 100,
      speedKmh: (json['speed_kmh'] as num?)?.toDouble() ?? 0.0,
      speedStatus: json['speed_status'] as String? ?? 'Stationary',
      estimatedArrival: json['estimated_arrival'] as String? ?? '--:--',
      minutesLeft: (json['minutes_left'] as num?)?.toInt() ?? 0,
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      currentLocation: json['current_location'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
    );

MapRouteEntity _mapRouteFromJson(Map<String, dynamic> json) {
  final pointsList = (json['route_points'] as List<dynamic>?) ?? [];
  final poisList = (json['pois'] as List<dynamic>?) ?? [];

  return MapRouteEntity(
    from: json['from_'] as String? ?? json['from'] as String? ?? '',
    to: json['to'] as String? ?? '',
    safetyScore: json['safety_score'] as int? ?? 0,
    safetyLabel: json['safety_label'] as String? ?? '',
    etaMinutes: json['eta_minutes'] as int? ?? 0,
    trafficLabel: json['traffic_label'] as String? ?? '',
    distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
    via: json['via'] as String? ?? '',
    policeNearby: json['police_nearby'] as int? ?? 0,
    hospitalsNearby: json['hospitals_nearby'] as int? ?? 0,
    metroKm: (json['metro_km'] as num?)?.toDouble() ?? 0.0,
    routePoints: pointsList
        .map((p) => LatLngPoint(
              (p['lat'] as num).toDouble(),
              (p['lng'] as num).toDouble(),
            ))
        .toList(),
    pois: poisList
        .map((p) => MapPoiEntity(
              id: p['id'] as String? ?? '',
              name: p['name'] as String? ?? '',
              type: _serviceType(p['type'] as String? ?? ''),
              lat: (p['lat'] as num).toDouble(),
              lng: (p['lng'] as num).toDouble(),
            ))
        .toList(),
    originLat: (json['origin_lat'] as num?)?.toDouble() ?? 0.0,
    originLng: (json['origin_lng'] as num?)?.toDouble() ?? 0.0,
    destLat: (json['dest_lat'] as num?)?.toDouble() ?? 0.0,
    destLng: (json['dest_lng'] as num?)?.toDouble() ?? 0.0,
  );
}

ActivityEntity _activityFromJson(Map<String, dynamic> json) {
  final weeklyJson = json['weekly_overview'] as Map<String, dynamic>? ?? {};
  final metricsList = (json['metrics'] as List<dynamic>?) ?? [];
  final journeysList = (json['journeys'] as List<dynamic>?) ?? [];
  final achievementsList = (json['achievements'] as List<dynamic>?) ?? [];
  final safetyEventsList = (json['safety_events'] as List<dynamic>?) ?? [];

  return ActivityEntity(
    avatarUrl: json['avatar_url'] as String? ?? '',
    weeklyOverview: WeeklyOverviewEntity(
      globalScore: weeklyJson['global_score'] as int? ?? 0,
      bars: ((weeklyJson['bars'] as List<dynamic>?) ?? [])
          .map((b) => (b as num).toDouble())
          .toList(),
      labels: ((weeklyJson['labels'] as List<dynamic>?) ?? [])
          .map((l) => l as String)
          .toList(),
    ),
    metrics: metricsList
        .map((m) => ActivityMetricEntity(
              label: (m as Map<String, dynamic>)['label'] as String? ?? '',
              value: m['value'] as String? ?? '',
              iconKey: m['icon_key'] as String? ?? '',
            ))
        .toList(),
    journeys: journeysList
        .map((j) => _journeyFromJson(j as Map<String, dynamic>))
        .toList(),
    achievements: achievementsList
        .map((a) => AchievementEntity(
              id: (a as Map<String, dynamic>)['id'] as String? ?? '',
              title: a['title'] as String? ?? '',
              subtitle: a['subtitle'] as String? ?? '',
              unlocked: a['unlocked'] as bool? ?? false,
              iconKey: a['icon_key'] as String? ?? '',
            ))
        .toList(),
    safetyEvents: safetyEventsList
        .map((e) => SafetyEventEntity(
              id: (e as Map<String, dynamic>)['id'] as String? ?? '',
              time: e['time'] as String? ?? '',
              title: e['title'] as String? ?? '',
              subtitle: e['subtitle'] as String? ?? '',
            ))
        .toList(),
  );
}

// ─── AUTH ─────────────────────────────────────────────────────────────────────

/// Auth repository connected to live FastAPI backend.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api, {TokenStorageService? tokenStorage})
      : _tokenStorage = tokenStorage ?? _api.tokenStorage;

  final ApiClient _api;
  final TokenStorageService _tokenStorage;
  bool _authenticated = false;

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    DevLog.auth('login started');
    DevLog.auth('login endpoint = ${ApiConstants.login}');
    try {
      final json = await _api.post(ApiConstants.login, body: request.toJson());
      final status = ApiClient.lastStatusCode ?? 200;
      DevLog.auth('login HTTP status = $status');
      final response = AuthResponse.fromJson(json);
      final hasToken = response.accessToken.isNotEmpty;
      DevLog.auth('token received = $hasToken');
      
      _api.setAuthToken(response.accessToken);
      await _tokenStorage.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        userId: response.userId,
      );
      final storedToken = await _tokenStorage.getAccessToken();
      final tokenStored = storedToken != null && storedToken.isNotEmpty;
      DevLog.auth('token stored = $tokenStored');

      _authenticated = true;
      return response;
    } catch (e) {
      DevLog.auth('login failed with error', error: e);
      rethrow;
    }
  }

  @override
  Future<AuthResponse> register(RegisterRequest request) async {
    DevLog.auth('register started');
    DevLog.auth('register endpoint = ${ApiConstants.register}');
    try {
      final json = await _api.post(ApiConstants.register, body: request.toJson());
      final status = ApiClient.lastStatusCode ?? 201;
      DevLog.auth('register HTTP status = $status');
      final response = AuthResponse.fromJson(json);
      final hasToken = response.accessToken.isNotEmpty;
      DevLog.auth('token received = $hasToken');

      _api.setAuthToken(response.accessToken);
      await _tokenStorage.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        userId: response.userId,
      );
      final storedToken = await _tokenStorage.getAccessToken();
      final tokenStored = storedToken != null && storedToken.isNotEmpty;
      DevLog.auth('token stored = $tokenStored');

      _authenticated = true;
      return response;
    } catch (e) {
      DevLog.auth('register failed with error', error: e);
      rethrow;
    }
  }

  @override
  Future<AuthResponse> loginWithGoogle(String idToken) async {
    DevLog.log('GOOGLE_AUTH', 'backend exchange started');
    DevLog.log('GOOGLE_AUTH', 'POST ${ApiConstants.googleLogin}');
    try {
      final req = GoogleLoginRequest(idToken: idToken);
      final json = await _api.post(ApiConstants.googleLogin, body: req.toJson());
      final status = ApiClient.lastStatusCode ?? 200;
      DevLog.log('GOOGLE_AUTH', 'backend HTTP status = $status');

      final response = AuthResponse.fromJson(json);
      final hasToken = response.accessToken.isNotEmpty;
      DevLog.log('GOOGLE_AUTH', 'backend authentication success = $hasToken');

      _api.setAuthToken(response.accessToken);
      await _tokenStorage.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        userId: response.userId,
      );
      final storedToken = await _tokenStorage.getAccessToken();
      final tokenStored = storedToken != null && storedToken.isNotEmpty;
      DevLog.log('GOOGLE_AUTH', 'JWT stored = $tokenStored');

      _authenticated = true;
      return response;
    } catch (e) {
      DevLog.log('GOOGLE_AUTH', 'backend exchange failed', error: e);
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    DevLog.auth('logout started');
    try {
      await _api.post(ApiConstants.logout);
    } catch (_) {
      // Best-effort server-side session revocation
    }
    await _tokenStorage.clear();
    _api.setAuthToken(null);
    _authenticated = false;
    DevLog.auth('logout complete');
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _api.post(ApiConstants.forgotPassword, body: {'email': email});
  }

  @override
  Future<bool> isAuthenticated() async {
    final hasToken = await _tokenStorage.hasValidToken();
    DevLog.auth('stored token exists = $hasToken');
    return hasToken || _authenticated;
  }
}

// ─── PROFILE ──────────────────────────────────────────────────────────────────

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<UserEntity> fetchProfile() async {
    final json = await _api.get(ApiConstants.profile);
    return _userFromJson(json);
  }

  @override
  Future<UserEntity> updateProfile(UserEntity user) async {
    final json = await _api.patch(ApiConstants.updateProfile, body: {
      'name': user.name,
      'phone': user.phone,
      'avatar_url': user.avatarUrl,
      'safety_shield_active': user.safetyShieldActive,
    });
    return _userFromJson(json);
  }

  @override
  Future<List<TrustedContactEntity>> fetchContacts() async {
    final json = await _api.get(ApiConstants.contacts);
    if (json.containsKey('id')) {
      return [_contactFromJson(json)];
    }
    final rawList = _extractList(json);
    return rawList.map((c) => _contactFromJson(c as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> addContact(TrustedContactEntity contact) async {
    await _api.post(ApiConstants.contacts, body: {
      'name': contact.name,
      'phone': contact.phone,
      'avatar_url': contact.avatarUrl,
      'relationship_label': contact.relationshipLabel,
      'priority': contact.priority,
      'emergency_notify_enabled': contact.emergencyNotifyEnabled,
      'location_share_enabled': contact.locationShareEnabled,
    });
  }
}

// ─── CONTACTS ─────────────────────────────────────────────────────────────────

class ContactRepositoryImpl implements ContactRepository {
  ContactRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<List<TrustedContactEntity>> fetchContacts() async {
    final json = await _api.get(ApiConstants.contacts);
    if (json.containsKey('id')) {
      return [_contactFromJson(json)];
    }
    final rawList = _extractList(json);
    return rawList.map((c) => _contactFromJson(c as Map<String, dynamic>)).toList();
  }

  @override
  Future<TrustedContactEntity> createContact(TrustedContactEntity contact) async {
    final json = await _api.post(ApiConstants.contacts, body: {
      'name': contact.name,
      'phone': contact.phone,
      'relationship_label': contact.relationshipLabel,
      'avatar_url': contact.avatarUrl,
      'priority': contact.priority,
      'emergency_notify_enabled': contact.emergencyNotifyEnabled,
      'location_share_enabled': contact.locationShareEnabled,
    });
    return _contactFromJson(json);
  }

  @override
  Future<TrustedContactEntity> updateContact(TrustedContactEntity contact) async {
    final json = await _api.patch('${ApiConstants.contacts}/${contact.id}', body: {
      'name': contact.name,
      'phone': contact.phone,
      'relationship_label': contact.relationshipLabel,
      'avatar_url': contact.avatarUrl,
      'priority': contact.priority,
      'emergency_notify_enabled': contact.emergencyNotifyEnabled,
      'location_share_enabled': contact.locationShareEnabled,
    });
    return _contactFromJson(json);
  }

  @override
  Future<void> deleteContact(String contactId) async {
    await _api.delete('${ApiConstants.contacts}/$contactId');
  }
}

// ─── DASHBOARD ────────────────────────────────────────────────────────────────

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<DashboardEntity> fetchDashboard({double? lat, double? lng}) async {
    final json = await _api.get(ApiConstants.dashboard, query: {
      if (lat != null) 'lat': lat.toString(),
      if (lng != null) 'lng': lng.toString(),
    });
    return _dashboardFromJson(json);
  }


  @override
  Future<WeatherEntity> fetchWeather({double? lat, double? lng}) async {
    final json = await _api.get(ApiConstants.weather, query: {
      if (lat != null) 'lat': lat.toString(),
      if (lng != null) 'lng': lng.toString(),
    });
    return _weatherFromJson(json);
  }

  @override
  Future<List<NearbyServiceEntity>> fetchNearbyServices({double? lat, double? lng}) async {
    final json = await _api.get(ApiConstants.nearbyServices, query: {
      if (lat != null) 'lat': lat.toString(),
      if (lng != null) 'lng': lng.toString(),
    });
    final rawList = _extractList(json);
    return rawList.map((s) => _serviceFromJson(s as Map<String, dynamic>)).toList();
  }
}


// ─── JOURNEY ──────────────────────────────────────────────────────────────────

class JourneyRepositoryImpl implements JourneyRepository {
  JourneyRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<JourneyEntity> fetchJourney(String id) async {
    final json = await _api.get('${ApiConstants.journey}/$id');
    return _journeyFromJson(json);
  }

  @override
  Future<List<JourneyEntity>> fetchJourneys() async {
    final json = await _api.get(ApiConstants.journeys);
    final rawList = _extractList(json, key: 'journeys');
    return rawList.map((j) => _journeyFromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<JourneyEntity> startJourney(StartJourneyRequest request) async {
    final json = await _api.post(ApiConstants.startJourney, body: request.toJson());
    return _journeyFromJson(json);
  }

  @override
  Future<void> stopJourney(String id) async {
    await _api.post('${ApiConstants.stopJourney}/$id');
  }

  @override
  Future<void> checkStationary(StationaryCheckRequestDto request) async {
    await _api.post(
      ApiConstants.journeyStationaryCheck,
      body: {
        'journey_id': request.journeyId,
        'current_lat': request.currentLat,
        'current_lng': request.currentLng,
        'speed_kmh': request.speedKmh,
        'stationary_minutes': request.stationaryMinutes,
        'traffic_congestion_level': request.trafficCongestionLevel,
        if (request.destLat != null) 'destination_lat': request.destLat,
        if (request.destLng != null) 'destination_lng': request.destLng,
      },
    );
  }
}

// ─── GUARDIAN ─────────────────────────────────────────────────────────────────

class GuardianRepositoryImpl implements GuardianRepository {
  GuardianRepositoryImpl(this._api);
  final ApiClient _api;
  String? _activeSessionId;

  @override
  Future<GuardianStatusEntity> fetchStatus() async {
    final json = await _api.get(ApiConstants.guardianStatus);
    final entity = _guardianFromJson(json);
    _activeSessionId = json['session_id'] as String?;
    return entity;
  }

  @override
  Future<GuardianStatusEntity> startGuardian() async {
    final json = await _api.post(ApiConstants.startGuardian);
    _activeSessionId = json['session_id'] as String?;
    return _guardianFromJson(json);
  }

  @override
  Future<GuardianStatusEntity> stopGuardian() async {
    final json = await _api.post(ApiConstants.stopGuardian);
    _activeSessionId = null;
    return _guardianFromJson(json);
  }

  @override
  Future<ApiMessageResponse> triggerSos(SosRequest request) async {
    final json = await _api.post(ApiConstants.sos, body: request.toJson());
    return ApiMessageResponse.fromJson(json);
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
  }) async {
    final payload = {
      'origin': {
        'latitude': originLat,
        'longitude': originLng,
      },
      'destination': {
        'latitude': destLat,
        'longitude': destLng,
        if (destinationName != null) 'name': destinationName,
      },
      'travel_mode': travelMode,
      if (departureTime != null) 'departure_time': departureTime,
    };

    final json = await _api.post(ApiConstants.guardianRoute, body: payload);
    return _guardianRoutePlanFromJson(json);
  }

  @override
  Future<List<SafetyZoneEntity>> fetchSafetyZones() async {
    final json = await _api.get(ApiConstants.safetyZones);
    final rawList = _extractList(json);
    return rawList.map((z) => _safetyZoneFromJson(z as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<PoliceStationEntity>> fetchPoliceStations({
    double? lat,
    double? lng,
    int limit = 15,
  }) async {
    final json = await _api.get(ApiConstants.policeStations, query: {
      if (lat != null) 'lat': lat.toString(),
      if (lng != null) 'lng': lng.toString(),
      'limit': limit.toString(),
    });
    final rawList = _extractList(json);
    return rawList.map((p) => _policeStationFromJson(p as Map<String, dynamic>)).toList();
  }

  @override
  Future<NearbyHelpEntity> fetchNearbyHelp({double? lat, double? lng}) async {
    final json = await _api.get(ApiConstants.nearbyHelp, query: {
      if (lat != null) 'lat': lat.toString(),
      if (lng != null) 'lng': lng.toString(),
    });
    return _nearbyHelpFromJson(json);
  }

  /// Send periodic heartbeat to keep guardian session alive and report current kinematics.
  @override
  Future<void> sendHeartbeat(HeartbeatRequest request) async {
    if (_activeSessionId == null) return;
    try {
      await _api.post(
        '${ApiConstants.guardianHeartbeat}/$_activeSessionId/heartbeat',
        body: request.toJson(),
      );
    } catch (_) {
      // Non-fatal — heartbeat failure handled by server watchdog
    }
  }
}

SafetyZoneEntity _safetyZoneFromJson(Map<String, dynamic> json) {
  return SafetyZoneEntity(
    id: json['id'] as String? ?? '',
    place: json['place'] as String? ?? '',
    category: json['category'] as String? ?? '',
    anchorArea: json['anchor_area'] as String? ?? '',
    demoSafetyLabel: json['demo_safety_label'] as String? ?? '',
    dayRiskScore: (json['day_risk_score'] as num?)?.toInt() ?? 0,
    nightRiskScore: (json['night_risk_score'] as num?)?.toInt() ?? 0,
    routeRiskScore: (json['route_risk_score'] as num?)?.toInt() ?? 0,
    footfall: json['footfall'] as String? ?? '',
    nightActivity: json['night_activity'] as String? ?? '',
    lighting: json['lighting'] as String? ?? '',
    isolation: json['isolation'] as String? ?? '',
    recommendation: json['recommendation'] as String? ?? '',
    demoSafetyScore: (json['demo_safety_score'] as num?)?.toInt() ?? 0,
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    radiusMeters: (json['radius_meters'] as num?)?.toDouble() ?? 600.0,
    dataStatus: json['data_status'] as String? ?? '',
    sourceBasis: json['source_basis'] as String? ?? '',
    disclaimer: json['disclaimer'] as String? ?? 'Prototype/demo data — not official crime statistics.',
  );
}

PoliceStationEntity _policeStationFromJson(Map<String, dynamic> json) {
  return PoliceStationEntity(
    id: json['id'] as String? ?? '',
    city: json['city'] as String? ?? 'Chennai',
    zone: json['zone'] as String? ?? '',
    subDivision: json['sub_division'] as String? ?? '',
    stationName: json['station_name'] as String? ?? '',
    contactNumber: json['contact_number'] as String? ?? '',
    address: json['address'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
    distanceDisplay: json['distance_display'] as String?,
    sourceInfo: json['source_info'] as String? ?? '',
  );
}

NearbyHelpItemEntity _nearbyHelpItemFromJson(Map<String, dynamic> json) {
  return NearbyHelpItemEntity(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    address: json['address'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
    distanceDisplay: json['distance_display'] as String? ?? '',
    rating: (json['rating'] as num?)?.toDouble(),
    openNow: json['open_now'] as bool?,
    source: json['source'] as String?,
  );
}

NearbyHelpEntity _nearbyHelpFromJson(Map<String, dynamic> json) {
  final summary = json['nearest_summary'] as Map<String, dynamic>? ?? {};
  final policeList = (json['police_stations'] as List<dynamic>?) ?? [];
  final hospitalList = (json['hospitals'] as List<dynamic>?) ?? [];
  final stationList = (json['stations'] as List<dynamic>?) ?? [];
  final activeList = (json['active_places'] as List<dynamic>?) ?? [];

  return NearbyHelpEntity(
    policeDistance: summary['police'] as String? ?? 'N/A',
    hospitalDistance: summary['hospital'] as String? ?? 'N/A',
    stationDistance: summary['station'] as String? ?? 'N/A',
    activeAreaDistance: summary['active_area'] as String? ?? 'N/A',
    policeStations: policeList.map((p) => _policeStationFromJson(p as Map<String, dynamic>)).toList(),
    hospitals: hospitalList.map((h) => _nearbyHelpItemFromJson(h as Map<String, dynamic>)).toList(),
    stations: stationList.map((s) => _nearbyHelpItemFromJson(s as Map<String, dynamic>)).toList(),
    activePlaces: activeList.map((a) => _nearbyHelpItemFromJson(a as Map<String, dynamic>)).toList(),
    disclaimer: json['disclaimer'] as String? ?? '',
  );
}

GuardianRouteAlternativeEntity _guardianAlternativeFromJson(Map<String, dynamic> json) {
  final pts = (json['points'] as List<dynamic>?) ?? [];
  final zones = (json['impacted_zones'] as List<dynamic>?) ?? [];
  final overviewPoly = json['overview_polyline'] as String? ?? '';

  List<LatLngPoint> decodedPoints = [];
  if (pts.isNotEmpty) {
    decodedPoints = pts.map((p) {
      final m = p as Map<String, dynamic>;
      return LatLngPoint(
        (m['lat'] as num).toDouble(),
        (m['lng'] as num).toDouble(),
      );
    }).toList();
  } else if (overviewPoly.isNotEmpty) {
    decodedPoints = PolylineUtils.decodePolyline(overviewPoly);
  }

  return GuardianRouteAlternativeEntity(
    routeIndex: (json['route_index'] as num?)?.toInt() ?? 0,
    summary: json['summary'] as String? ?? '',
    role: json['role'] as String? ?? 'Safer Route',
    tag: json['tag'] as String? ?? '🛡 Recommended',
    safetyScore: (json['safety_score'] as num?)?.toInt() ?? 80,
    durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
    distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
    trafficCondition: json['traffic_condition'] as String? ?? 'Moderate',
    reason: json['reason'] as String? ?? '',
    points: decodedPoints,
    impactedZones: zones.map((z) => Map<String, dynamic>.from(z as Map)).toList(),
  );
}

GuardianRoutePlanEntity _guardianRoutePlanFromJson(Map<String, dynamic> json) {
  final origin = json['origin'] as Map<String, dynamic>? ?? {};
  final dest = json['destination'] as Map<String, dynamic>? ?? {};
  final recRoute = json['recommended_route'] as Map<String, dynamic>? ?? {};
  final altList = (json['alternative_routes'] as List<dynamic>?) ?? [];
  final policeList = (json['nearby_police'] as List<dynamic>?) ?? [];
  final hospList = (json['nearby_hospitals'] as List<dynamic>?) ?? [];
  final stnList = (json['nearby_stations'] as List<dynamic>?) ?? [];
  final actList = (json['active_places'] as List<dynamic>?) ?? [];
  final zonesList = (json['risk_zones'] as List<dynamic>?) ?? [];
  final timeJson = json['travel_time'] as Map<String, dynamic>? ?? {};
  final distJson = json['distance'] as Map<String, dynamic>? ?? {};

  return GuardianRoutePlanEntity(
    originLat: (origin['latitude'] as num?)?.toDouble() ?? 0.0,
    originLng: (origin['longitude'] as num?)?.toDouble() ?? 0.0,
    destLat: (dest['latitude'] as num?)?.toDouble() ?? 0.0,
    destLng: (dest['longitude'] as num?)?.toDouble() ?? 0.0,
    destinationName: dest['name'] as String? ?? 'Destination',
    isNight: json['is_night'] as bool? ?? false,
    evaluationPeriod: json['evaluation_period'] as String? ?? 'Day',
    recommendedRoute: _guardianAlternativeFromJson(recRoute),
    alternatives: altList.map((a) => _guardianAlternativeFromJson(a as Map<String, dynamic>)).toList(),
    safetyScore: (json['safety_score'] as num?)?.toInt() ?? 80,
    riskLevel: json['risk_level'] as String? ?? 'LOW',
    riskZones: zonesList.map((z) => Map<String, dynamic>.from(z as Map)).toList(),
    nearbyPolice: policeList.map((p) => _policeStationFromJson(p as Map<String, dynamic>)).toList(),
    nearbyHospitals: hospList.map((h) => _nearbyHelpItemFromJson(h as Map<String, dynamic>)).toList(),
    nearbyStations: stnList.map((s) => _nearbyHelpItemFromJson(s as Map<String, dynamic>)).toList(),
    activePlaces: actList.map((a) => _nearbyHelpItemFromJson(a as Map<String, dynamic>)).toList(),
    travelTimeDisplay: timeJson['display'] as String? ?? '${timeJson['minutes'] ?? 0} min',
    distanceDisplay: distJson['display'] as String? ?? '${distJson['km'] ?? 0} km',
    reason: json['reason'] as String? ?? '',
    disclaimer: json['disclaimer'] as String? ?? 'Safety scores shown are prototype/demo data and do not represent official crime statistics or guaranteed safety.',
  );
}

// ─── MAP ──────────────────────────────────────────────────────────────────────

class MapRepositoryImpl implements MapRepository {
  MapRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<MapRouteEntity> fetchRoute({
    String? destination,
    double? originLat,
    double? originLng,
    double? destLat,
    double? destLng,
  }) async {
    final json = await _api.get(ApiConstants.route, query: {
      if (destination != null && destination.isNotEmpty) 'destination': destination,
      if (originLat != null) 'origin_lat': originLat.toString(),
      if (originLng != null) 'origin_lng': originLng.toString(),
      if (destLat != null) 'dest_lat': destLat.toString(),
      if (destLng != null) 'dest_lng': destLng.toString(),
    });
    return _mapRouteFromJson(json);
  }


  @override
  Future<List<AreaSafetyEntity>> fetchAreaSafety() async {
    final json = await _api.get(ApiConstants.areaSafety);
    final rawList = _extractList(json);
    return rawList
        .map((a) => AreaSafetyEntity(
              areaName: (a as Map<String, dynamic>)['area_name'] as String? ?? '',
              score: a['score'] as int? ?? 0,
              label: a['label'] as String? ?? '',
            ))
        .toList();
  }
}

// ─── ACTIVITY ─────────────────────────────────────────────────────────────────

class ActivityRepositoryImpl implements ActivityRepository {
  ActivityRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<ActivityEntity> fetchActivity() async {
    final json = await _api.get(ApiConstants.activity);
    return _activityFromJson(json);
  }

  @override
  Future<List<NotificationEntity>> fetchNotifications() async {
    final json = await _api.get(ApiConstants.notifications);
    final rawList = _extractList(json);
    return rawList
        .map((n) => NotificationEntity(
              id: (n as Map<String, dynamic>)['id'] as String? ?? '',
              title: n['title'] as String? ?? '',
              body: n['body'] as String? ?? '',
              timeLabel: n['time_label'] as String? ?? '',
              isRead: n['is_read'] as bool? ?? false,
            ))
        .toList();
  }

  @override
  Future<List<AchievementEntity>> fetchAchievements() async {
    final json = await _api.get(ApiConstants.achievements);
    final rawList = _extractList(json);
    return rawList
        .map((a) => AchievementEntity(
              id: (a as Map<String, dynamic>)['id'] as String? ?? '',
              title: a['title'] as String? ?? '',
              subtitle: a['subtitle'] as String? ?? '',
              unlocked: a['unlocked'] as bool? ?? false,
              iconKey: a['icon_key'] as String? ?? '',
            ))
        .toList();
  }
}

// ─── TOOLS ────────────────────────────────────────────────────────────────────

class ToolsRepositoryImpl implements ToolsRepository {
  ToolsRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<FakeCallEntity> fetchFakeCall() async {
    final json = await _api.get(ApiConstants.fakeCall);
    return FakeCallEntity(
      callerName: json['caller_name'] as String? ?? 'Mom',
      callerNumber: json['caller_number'] as String? ?? '+91 90000 11111',
      delaySeconds: json['delay_seconds'] as int? ?? 5,
    );
  }

  @override
  Future<FakeMessageEntity> fetchFakeMessage() async {
    final json = await _api.get(ApiConstants.fakeMessage);
    return FakeMessageEntity(
      senderName: json['sender_name'] as String? ?? 'Alex',
      message: json['message'] as String? ?? 'Hey, where are you?',
    );
  }

  @override
  Future<ApiMessageResponse> startFakeCall() async {
    final json = await _api.post(ApiConstants.fakeCall);
    return ApiMessageResponse.fromJson(json);
  }

  @override
  Future<ApiMessageResponse> startFakeMessage() async {
    final json = await _api.post(ApiConstants.fakeMessage);
    return ApiMessageResponse.fromJson(json);
  }
}

// ─── INTELLIGENCE ─────────────────────────────────────────────────────────────

class IntelligenceRepositoryImpl implements IntelligenceRepository {
  IntelligenceRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<MotionAnomalyEntity> sendMotionSignal(MotionSignalRequest request) async {
    final json = await _api.post(ApiConstants.signalsMotion, body: request.toJson());
    return MotionAnomalyEntity(
      eventId: json['event_id'] as String? ?? '',
      eventType: json['event_type'] as String? ?? 'MOTION_ANOMALY',
      evaluatedRiskContribution:
          (json['evaluated_risk_contribution'] as num?)?.toDouble() ?? 0.0,
      confidenceAdjusted:
          (json['confidence_adjusted'] as num?)?.toDouble() ?? 0.5,
      message: json['message'] as String? ?? '',
    );
  }

  @override
  Future<VoiceDistressEntity> sendVoiceAnalysis(VoiceAnalysisRequest request) async {
    final json = await _api.post(ApiConstants.signalsVoice, body: request.toJson());
    final kwList = (json['matched_keywords'] as List<dynamic>?) ?? [];
    return VoiceDistressEntity(
      signal: json['signal'] as String? ?? 'VOICE_DISTRESS',
      distressScore: (json['distress_score'] as num?)?.toDouble() ?? 0.0,
      urgency: json['urgency'] as String? ?? 'LOW',
      helpKeyword: json['help_keyword'] as bool? ?? false,
      repetitionCount: json['repetition_count'] as int? ?? 0,
      voiceIntensity: (json['voice_intensity'] as num?)?.toDouble() ?? 0.0,
      modelConfidence: (json['model_confidence'] as num?)?.toDouble() ?? 0.0,
      matchedKeywords: kwList.map((k) => k.toString()).toList(),
      message: json['message'] as String? ?? '',
    );
  }

  @override
  Future<RiskAssessmentEntity> fuseRisk(RiskFusionRequest request) async {
    final json = await _api.post(ApiConstants.riskFuse, body: request.toJson());
    final signalsList = (json['signals'] as List<dynamic>?) ?? [];
    return RiskAssessmentEntity(
      riskLevel: json['risk_level'] as String? ?? 'LOW',
      riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0.0,
      signals: signalsList
          .map((s) => RiskSignalEntity(
                type: (s as Map<String, dynamic>)['type'] as String? ?? '',
                score: (s['score'] as num?)?.toDouble() ?? 0.0,
                weightedContribution:
                    (s['weighted_contribution'] as num?)?.toDouble() ?? 0.0,
                explanation: s['explanation'] as String? ?? '',
              ))
          .toList(),
      recommendedAction: json['recommended_action'] as String? ?? '',
      requiresUserPrompt: json['requires_user_prompt'] as bool? ?? false,
      autoEscalatePrepared: json['auto_escalate_prepared'] as bool? ?? false,
    );
  }

  @override
  Future<ApiMessageResponse> recordFalsePositive(
      FalsePositiveFeedbackRequest request) async {
    final json = await _api.post(ApiConstants.falsePositive, body: request.toJson());
    return ApiMessageResponse.fromJson(json);
  }

  @override
  Future<SafetyCheckInEntity> startCheckIn(CheckInStartRequest request) async {
    final json = await _api.post('${ApiConstants.checkins}/start', body: request.toJson());

    return SafetyCheckInEntity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      durationMinutes: json['duration_minutes'] as int? ?? 15,
      status: json['status'] as String? ?? 'ACTIVE',
      startedAt: json['started_at'] as String? ?? '',
      expiresAt: json['expires_at'] as String? ?? '',
      minutesRemaining: json['minutes_remaining'] as int? ?? 0,
      confirmedAt: json['confirmed_at'] as String?,
    );
  }

  @override
  Future<ApiMessageResponse> confirmCheckIn(String checkInId) async {
    final json = await _api.post('${ApiConstants.checkins}/$checkInId/confirm');
    return ApiMessageResponse.fromJson(json);
  }

  @override
  Future<ApiMessageResponse> cancelCheckIn(String checkInId) async {
    final json = await _api.post('${ApiConstants.checkins}/$checkInId/cancel');
    return ApiMessageResponse.fromJson(json);
  }

  @override
  Future<List<SafetyCheckInEntity>> fetchCheckIns() async {
    final json = await _api.get(ApiConstants.checkins);
    final rawList = _extractList(json);
    return rawList
        .map((c) => SafetyCheckInEntity(
              id: (c as Map<String, dynamic>)['id'] as String? ?? '',
              title: c['title'] as String? ?? '',
              durationMinutes: c['duration_minutes'] as int? ?? 15,
              status: c['status'] as String? ?? 'ACTIVE',
              startedAt: c['started_at'] as String? ?? '',
              expiresAt: c['expires_at'] as String? ?? '',
              minutesRemaining: c['minutes_remaining'] as int? ?? 0,
              confirmedAt: c['confirmed_at'] as String?,
            ))
        .toList();
  }

  @override
  Future<List<SafetyRecommendationEntity>> fetchRecommendations() async {
    final json = await _api.get(ApiConstants.recommendations);
    final rawList = _extractList(json);
    return rawList
        .map((r) => SafetyRecommendationEntity(
              id: (r as Map<String, dynamic>)['id'] as String? ?? '',
              title: r['title'] as String? ?? '',
              category: r['category'] as String? ?? '',
              evidence: r['evidence'] as String? ?? '',
              actionType: r['action_type'] as String? ?? '',
              actionLabel: r['action_label'] as String? ?? '',
            ))
        .toList();
  }
}

// ─── Internal utility ─────────────────────────────────────────────────────────

List<dynamic> _extractList(Map<String, dynamic> json, {String? key}) {
  if (key != null && json.containsKey(key)) {
    return json[key] as List<dynamic>? ?? [];
  }
  if (json.containsKey('data')) {
    final data = json['data'];
    if (data is List) return data;
  }
  if (json.containsKey('items')) {
    final items = json['items'];
    if (items is List) return items;
  }
  return [];
}
