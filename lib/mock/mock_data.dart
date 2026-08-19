import '../domain/entities/entities.dart';

/// Single source of truth for all UI data until FastAPI is connected.
/// Delete this file and swap repository implementations when integrating.
abstract final class MockData {
  static const String _avatarJulian =
      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop';
  static const String _avatarAlex =
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&h=200&fit=crop';
  static const String _avatarMom =
      'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=200&h=200&fit=crop';
  static const String _avatarFriend =
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&h=200&fit=crop';

  static const UserEntity user = UserEntity(
    id: 'usr_001',
    name: 'Alex Sterling',
    email: 'alex@guardian.ai',
    phone: '+91 98765 43210',
    avatarUrl: _avatarAlex,
    isPremium: true,
    membershipName: 'Guardian Elite',
    nextBilling: 'Oct 24, 2023',
    safeTrips: 124,
    trustedContactCount: 8,
    appVersion: '1.2.0',
    safetyShieldActive: true,
  );

  /// Home dashboard uses a first-name greeting (Julian in Stitch).
  static const String dashboardFirstName = 'Julian';
  static const String dashboardAvatar = _avatarJulian;

  static const List<TrustedContactEntity> contacts = [
    TrustedContactEntity(
      id: 'c1',
      name: 'Mom',
      avatarUrl: _avatarMom,
      isOnline: true,
      phone: '+91 90000 11111',
    ),
    TrustedContactEntity(
      id: 'c2',
      name: 'Alex',
      avatarUrl: _avatarFriend,
      isOnline: true,
      phone: '+91 90000 22222',
    ),
    TrustedContactEntity(
      id: 'c3',
      name: 'Priya',
      avatarUrl: _avatarAlex,
      isOnline: false,
      phone: '+91 90000 33333',
    ),
  ];

  static const WeatherEntity weather = WeatherEntity(
    temperatureC: 31,
    location: 'Chennai, TN',
    condition: 'Humid',
    visibilityKm: 8,
  );

  static const List<NearbyServiceEntity> nearbyServices = [
    NearbyServiceEntity(
      id: 'ns1',
      name: 'Thousand Lights',
      type: NearbyServiceType.metro,
      distanceKm: 0.8,
    ),
    NearbyServiceEntity(
      id: 'ns2',
      name: 'Apollo Greams Road',
      type: NearbyServiceType.hospital,
      distanceKm: 1.2,
    ),
    NearbyServiceEntity(
      id: 'ns3',
      name: 'T3 Egmore PS',
      type: NearbyServiceType.police,
      distanceKm: 0.5,
    ),
  ];

  static const JourneyEntity recentJourney = JourneyEntity(
    id: 'j_recent',
    title: 'Trip from Phoenix Marketcity to Adyar',
    subtitle: 'Completed safely with Guardian AI',
    from: 'Phoenix Marketcity',
    to: 'Adyar',
    dateLabel: 'Yesterday',
    timeRange: '6:30 PM - 7:15 PM',
    safetyScore: 9.4,
    isAlert: false,
    completedSafely: true,
  );

  static const List<JourneyEntity> journeys = [
    JourneyEntity(
      id: 'j1',
      title: 'Midnight walk in Besant Nagar',
      subtitle: 'Today • 12:15 AM - 12:45 AM',
      from: 'Elliot\'s Beach',
      to: 'Home',
      dateLabel: 'Today',
      timeRange: '12:15 AM - 12:45 AM',
      safetyScore: 9.8,
      isAlert: false,
      completedSafely: true,
    ),
    JourneyEntity(
      id: 'j2',
      title: 'Evening commute from Guindy to Velachery',
      subtitle: 'Yesterday • 6:30 PM - 7:15 PM',
      from: 'Guindy',
      to: 'Velachery',
      dateLabel: 'Yesterday',
      timeRange: '6:30 PM - 7:15 PM',
      safetyScore: 9.2,
      isAlert: false,
      completedSafely: true,
    ),
    JourneyEntity(
      id: 'j3',
      title: 'SOS Triggered',
      subtitle: 'Oct 12 • 11:02 PM',
      from: 'Unknown',
      to: 'Safe Zone',
      dateLabel: 'Oct 12',
      timeRange: '11:02 PM',
      safetyScore: 4.2,
      isAlert: true,
      completedSafely: false,
    ),
  ];

  static DashboardEntity get dashboard => const DashboardEntity(
        userName: dashboardFirstName,
        avatarUrl: dashboardAvatar,
        safetyScore: 94,
        safetyStatus: 'SECURE',
        guardianModeActive: true,
        guardianSubtitle: 'AI-Enhanced Monitoring Active',
        recentJourney: recentJourney,
        weather: weather,
        aiScanningLabel: 'Scanning surroundings...',
        nearbyServices: nearbyServices,
        contacts: contacts,
      );

  static const GuardianStatusEntity guardian = GuardianStatusEntity(
    isActive: true,
    statusLabel: 'ACTIVE',
    monitoringLabel: 'Monitoring Surroundings',
    voiceSyncLive: true,
    voiceSyncState: 'Listening',
    batteryPercent: 88,
    speedKmh: 1.2,
    speedStatus: 'Walking',
    estimatedArrival: '09:15 PM',
    minutesLeft: 22,
    origin: 'Anna Salai',
    destination: 'Besant Nagar',
    progress: 0.62,
    currentLocation: 'Anna Salai, Teynampet',
    avatarUrl: _avatarAlex,
  );

  static const MapRouteEntity mapRoute = MapRouteEntity(
    from: 'Keelkattalai',
    to: 'T. Nagar, Chennai',
    safetyScore: 24,
    safetyLabel: 'Good',
    etaMinutes: 32,
    trafficLabel: 'Normal Traffic',
    distanceKm: 14.6,
    via: 'GST Road',
    policeNearby: 5,
    hospitalsNearby: 3,
    metroKm: 2.1,
    originLat: 12.9550,
    originLng: 80.2040,
    destLat: 13.0418,
    destLng: 80.2341,
    routePoints: [
      LatLngPoint(12.9550, 80.2040),
      LatLngPoint(12.9700, 80.2100),
      LatLngPoint(12.9900, 80.2200),
      LatLngPoint(13.0100, 80.2280),
      LatLngPoint(13.0418, 80.2341),
    ],
    pois: [
      MapPoiEntity(
        id: 'poi1',
        name: 'Apollo Hospital',
        type: NearbyServiceType.hospital,
        lat: 13.0200,
        lng: 80.2250,
      ),
      MapPoiEntity(
        id: 'poi2',
        name: 'T. Nagar Police Station',
        type: NearbyServiceType.police,
        lat: 13.0350,
        lng: 80.2300,
      ),
    ],
  );

  static const WeeklyOverviewEntity weeklyOverview = WeeklyOverviewEntity(
    globalScore: 98,
    bars: [0.55, 0.7, 0.45, 0.85, 0.65, 0.9, 0.75],
    labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  );

  static const List<ActivityMetricEntity> activityMetrics = [
    ActivityMetricEntity(label: 'Total Walks', value: '24', iconKey: 'walk'),
    ActivityMetricEntity(label: 'Shield Time', value: '12.5h', iconKey: 'shield'),
    ActivityMetricEntity(label: 'Alerts Avoided', value: '3', iconKey: 'alert'),
  ];

  static const List<AchievementEntity> achievements = [
    AchievementEntity(
      id: 'a1',
      title: 'Night Sentinel',
      subtitle: '10 Night walks secured',
      unlocked: true,
      iconKey: 'ribbon',
    ),
    AchievementEntity(
      id: 'a2',
      title: 'Swift Responder',
      subtitle: 'Check-in within 5s',
      unlocked: false,
      iconKey: 'check',
    ),
    AchievementEntity(
      id: 'a3',
      title: 'First Guard',
      subtitle: 'Set up Trusted Circle',
      unlocked: true,
      iconKey: 'shield',
    ),
  ];

  static const List<SafetyEventEntity> safetyEvents = [
    SafetyEventEntity(
      id: 'e1',
      time: '01:20 AM',
      title: 'Arrived at Home Base (Anna Nagar)',
      subtitle: 'Automatically deactivated Shield',
    ),
    SafetyEventEntity(
      id: 'e2',
      time: '12:45 AM',
      title: 'Commence Midnight Walk',
      subtitle: 'Route optimized for Besant Nagar',
    ),
  ];

  static ActivityEntity get activity => const ActivityEntity(
        avatarUrl: _avatarAlex,
        weeklyOverview: weeklyOverview,
        metrics: activityMetrics,
        journeys: journeys,
        achievements: achievements,
        safetyEvents: safetyEvents,
      );

  static const List<NotificationEntity> notifications = [
    NotificationEntity(
      id: 'n1',
      title: 'Guardian Mode Active',
      body: 'AI is monitoring your surroundings on Anna Salai.',
      timeLabel: '2m ago',
      isRead: false,
    ),
    NotificationEntity(
      id: 'n2',
      title: 'Safe Arrival',
      body: 'Mom confirmed your arrival at home.',
      timeLabel: '1h ago',
      isRead: true,
    ),
    NotificationEntity(
      id: 'n3',
      title: 'Area Safety Update',
      body: 'T. Nagar safety score improved to Good.',
      timeLabel: 'Yesterday',
      isRead: true,
    ),
  ];

  static const FakeCallEntity fakeCall = FakeCallEntity(
    callerName: 'Mom',
    callerNumber: '+91 90000 11111',
    delaySeconds: 5,
  );

  static const FakeMessageEntity fakeMessage = FakeMessageEntity(
    senderName: 'Alex',
    message: 'Hey, where are you? I\'m waiting outside.',
  );

  static const List<AreaSafetyEntity> areaSafety = [
    AreaSafetyEntity(areaName: 'T. Nagar', score: 82, label: 'Good'),
    AreaSafetyEntity(areaName: 'Besant Nagar', score: 91, label: 'Excellent'),
    AreaSafetyEntity(areaName: 'Guindy', score: 74, label: 'Moderate'),
  ];

  static const String loginHeroTagline = 'Your Safety Starts Here';
  static const String loginSubtitle =
      'Travel smarter, stay protected, and keep your loved ones connected wherever you go.';
  static const String loginFooter =
      'Guardian AI never shares your live location without your permission.';

  static const String signUpTitle = 'Create Your Guardian';
  static const String signUpSubtitle =
      'Join thousands of users building safer journeys every day.';
}
