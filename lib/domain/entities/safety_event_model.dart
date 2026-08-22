/// Unified Safety Event Model for Guardian AI.
/// Tracks real-time security, kinematic, location, and network events.
library;

enum SafetyEventType {
  journeyStarted,
  journeyPaused,
  journeyResumed,
  journeyCompleted,
  shakeDetected,
  phoneDrop,
  fallDetected,
  voiceDistress,
  loudNoiseDetected,
  prolongedStop,
  movementResumed,
  movementNormalized,
  routeDeviation,
  routeMatched,
  gpsLost,
  gpsRestored,
  networkLost,
  networkRestored,
  unsafeZoneEntered,
  unsafeZoneExited,
  speedAnomaly,
  sosTriggered,
  sosCancelled,
  trustedContactAlerted,
  lowBattery,
  safeArrivalConfirmed,
  manualCheckIn,
}

enum SafetyEventSeverity {
  info,
  warning,
  critical,
  success,
}

class SafetyEventModel {
  const SafetyEventModel({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    this.latitude,
    this.longitude,
    this.source = 'device_sensor',
    this.metadata = const {},
  });

  final String id;
  final DateTime timestamp;
  final SafetyEventType type;
  final SafetyEventSeverity severity;
  final String title;
  final String message;
  final double? latitude;
  final double? longitude;
  final String source;
  final Map<String, dynamic> metadata;

  String get timeFormatted {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  SafetyEventModel copyWith({
    String? id,
    DateTime? timestamp,
    SafetyEventType? type,
    SafetyEventSeverity? severity,
    String? title,
    String? message,
    double? latitude,
    double? longitude,
    String? source,
    Map<String, dynamic>? metadata,
  }) {
    return SafetyEventModel(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      message: message ?? this.message,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      source: source ?? this.source,
      metadata: metadata ?? this.metadata,
    );
  }
}
