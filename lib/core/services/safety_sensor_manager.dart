import 'dart:async';
import 'package:geolocator/geolocator.dart';

import '../utils/dev_log.dart';
import 'location_service.dart';
import 'sensor_service.dart';
import 'voice_service.dart';

/// Operational status of an individual safety sensor.
enum SensorStatus {
  active,
  inactive,
  permissionRequired,
  error,
  degraded,
}

/// Device kinematic movement state derived from fused multi-sensor signals.
enum DeviceMotionState {
  stationary,
  walking,
  running,
  vehicular,
  anomaly,
}

/// Structured telemetry record for a single sensor.
class SensorTelemetry {
  const SensorTelemetry({
    required this.name,
    required this.status,
    required this.permission,
    required this.availability,
    this.lastUpdate,
    this.rawValues = const {},
    this.filteredValues = const {},
    this.confidence = 0.0,
    this.eventClassification = 'NORMAL',
    this.errorMessage,
  });

  final String name;
  final SensorStatus status;
  final String permission;
  final bool availability;
  final DateTime? lastUpdate;
  final Map<String, dynamic> rawValues;
  final Map<String, dynamic> filteredValues;
  final double confidence;
  final String eventClassification;
  final String? errorMessage;

  SensorTelemetry copyWith({
    String? name,
    SensorStatus? status,
    String? permission,
    bool? availability,
    DateTime? lastUpdate,
    Map<String, dynamic>? rawValues,
    Map<String, dynamic>? filteredValues,
    double? confidence,
    String? eventClassification,
    String? errorMessage,
  }) {
    return SensorTelemetry(
      name: name ?? this.name,
      status: status ?? this.status,
      permission: permission ?? this.permission,
      availability: availability ?? this.availability,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      rawValues: rawValues ?? this.rawValues,
      filteredValues: filteredValues ?? this.filteredValues,
      confidence: confidence ?? this.confidence,
      eventClassification: eventClassification ?? this.eventClassification,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Instantaneous complete safety sensor snapshot.
class SafetySensorSnapshot {
  const SafetySensorSnapshot({
    required this.gps,
    required this.accelerometer,
    required this.gyroscope,
    required this.voice,
    required this.deviceMotionState,
    required this.timestamp,
  });

  final SensorTelemetry gps;
  final SensorTelemetry accelerometer;
  final SensorTelemetry gyroscope;
  final SensorTelemetry voice;
  final DeviceMotionState deviceMotionState;
  final DateTime timestamp;

  factory SafetySensorSnapshot.initial() {
    final now = DateTime.now();
    return SafetySensorSnapshot(
      gps: SensorTelemetry(
        name: 'GPS',
        status: SensorStatus.inactive,
        permission: 'UNKNOWN',
        availability: true,
        lastUpdate: now,
      ),
      accelerometer: SensorTelemetry(
        name: 'ACCELEROMETER',
        status: SensorStatus.inactive,
        permission: 'GRANTED',
        availability: true,
        lastUpdate: now,
        rawValues: const {'x': 0.0, 'y': 0.0, 'z': 9.81, 'magnitude': 9.81},
        filteredValues: const {'baseline': 9.81, 'variance': 0.0},
      ),
      gyroscope: SensorTelemetry(
        name: 'GYROSCOPE',
        status: SensorStatus.inactive,
        permission: 'GRANTED',
        availability: true,
        lastUpdate: now,
        rawValues: const {'x': 0.0, 'y': 0.0, 'z': 0.0, 'rotation': 0.0},
        filteredValues: const {'rotation_smoothed': 0.0},
      ),
      voice: SensorTelemetry(
        name: 'VOICE',
        status: SensorStatus.inactive,
        permission: 'UNKNOWN',
        availability: false,
        lastUpdate: now,
      ),
      deviceMotionState: DeviceMotionState.stationary,
      timestamp: now,
    );
  }
}

/// Centralized Safety Sensor Foundation.
///
/// Responsible for:
/// - GPS
/// - Accelerometer (Low-pass filtered gravity baseline + high-pass motion delta)
/// - Gyroscope (Rotational velocity and variance)
/// - Voice (Microphone permission, speech-to-text listener state, acoustic confidence)
/// - Device Motion State (Stationary vs Walking vs Running vs Anomaly)
///
/// NOTE: SafetySensorManager NEVER directly triggers SOS. It provides structured,
/// truthful telemetry and event classifications to higher layers (Risk Engine, GuardianEngine).
class SafetySensorManager {
  SafetySensorManager({
    required LocationService locationService,
    required SensorService sensorService,
    required VoiceService voiceService,
  })  : _locationService = locationService,
        _sensorService = sensorService,
        _voiceService = voiceService {
    _currentSnapshot = SafetySensorSnapshot.initial();
  }

  final LocationService _locationService;
  final SensorService _sensorService;
  final VoiceService _voiceService;

  bool _isMonitoring = false;
  late SafetySensorSnapshot _currentSnapshot;

  StreamSubscription<Position>? _gpsSub;
  StreamSubscription<SensorReading>? _sensorSub;
  StreamSubscription<String>? _voiceSub;

  final StreamController<SafetySensorSnapshot> _snapshotController =
      StreamController<SafetySensorSnapshot>.broadcast();

  // Exponential Moving Average (EMA) baseline filters
  double _emaAccelMagnitude = 9.81;
  double _emaGyroMagnitude = 0.0;
  static const double _filterAlpha = 0.15; // Smoothing factor

  bool get isMonitoring => _isMonitoring;
  SafetySensorSnapshot get currentSnapshot => _currentSnapshot;
  Stream<SafetySensorSnapshot> get snapshotStream => _snapshotController.stream;

  SensorTelemetry get gps => _currentSnapshot.gps;
  SensorTelemetry get accelerometer => _currentSnapshot.accelerometer;
  SensorTelemetry get gyroscope => _currentSnapshot.gyroscope;
  SensorTelemetry get voice => _currentSnapshot.voice;
  DeviceMotionState get deviceMotionState => _currentSnapshot.deviceMotionState;

  /// Start monitoring all hardware sensors.
  Future<void> start() async {
    if (_isMonitoring) return;
    _isMonitoring = true;
    DevLog.log('SENSOR_MGR', 'Starting centralized SafetySensorManager...');

    // 1. Audit and initialize GPS
    await _initGps();

    // 2. Audit and initialize Accelerometer & Gyroscope
    _initInertialSensors();

    // 3. Audit and initialize Voice Subsystem
    await _initVoice();

    _emitSnapshot();
  }

  /// Stop monitoring all sensors.
  Future<void> stop() async {
    _isMonitoring = false;
    await _gpsSub?.cancel();
    _gpsSub = null;
    await _sensorSub?.cancel();
    _sensorSub = null;
    await _voiceSub?.cancel();
    _voiceSub = null;

    final now = DateTime.now();
    _currentSnapshot = SafetySensorSnapshot(
      gps: _currentSnapshot.gps.copyWith(status: SensorStatus.inactive, lastUpdate: now),
      accelerometer: _currentSnapshot.accelerometer.copyWith(status: SensorStatus.inactive, lastUpdate: now),
      gyroscope: _currentSnapshot.gyroscope.copyWith(status: SensorStatus.inactive, lastUpdate: now),
      voice: _currentSnapshot.voice.copyWith(status: SensorStatus.inactive, lastUpdate: now),
      deviceMotionState: DeviceMotionState.stationary,
      timestamp: now,
    );
    _emitSnapshot();
    DevLog.log('SENSOR_MGR', 'SafetySensorManager stopped.');
  }

  Future<void> _initGps() async {
    try {
      final perm = await _locationService.checkPermission();
      final isServiceOn = await _locationService.isServiceEnabled();

      final permStr = perm == LocationPermission.always || perm == LocationPermission.whileInUse
          ? 'GRANTED'
          : (perm == LocationPermission.deniedForever ? 'DENIED_FOREVER' : 'DENIED');

      if (!isServiceOn || perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _currentSnapshot = _currentSnapshot.copyWith(
          gps: SensorTelemetry(
            name: 'GPS',
            status: perm == LocationPermission.denied || perm == LocationPermission.deniedForever
                ? SensorStatus.permissionRequired
                : SensorStatus.degraded,
            permission: permStr,
            availability: isServiceOn,
            lastUpdate: DateTime.now(),
            errorMessage: !isServiceOn ? 'Location service disabled' : 'Permission needed',
          ),
        );
      } else {
        _gpsSub?.cancel();
        _gpsSub = _locationService
            .getPositionStream(desiredAccuracy: LocationAccuracy.high, distanceFilter: 3)
            .listen(_onGpsUpdate, onError: (e) {
          _currentSnapshot = _currentSnapshot.copyWith(
            gps: _currentSnapshot.gps.copyWith(
              status: SensorStatus.error,
              errorMessage: e.toString(),
            ),
          );
          _emitSnapshot();
        });
      }
    } catch (e) {
      DevLog.log('SENSOR_MGR', 'GPS init error: $e');
    }
  }

  void _onGpsUpdate(Position pos) {
    final speedKmh = (pos.speed * 3.6).clamp(0.0, 200.0);
    final now = DateTime.now();

    // Deduce motion state from GPS + Kinematics
    DeviceMotionState motion = _currentSnapshot.deviceMotionState;
    if (speedKmh < 1.0) {
      motion = DeviceMotionState.stationary;
    } else if (speedKmh < 6.5) {
      motion = DeviceMotionState.walking;
    } else if (speedKmh < 16.0) {
      motion = DeviceMotionState.running;
    } else {
      motion = DeviceMotionState.vehicular;
    }

    _currentSnapshot = _currentSnapshot.copyWith(
      gps: SensorTelemetry(
        name: 'GPS',
        status: SensorStatus.active,
        permission: 'GRANTED',
        availability: true,
        lastUpdate: now,
        rawValues: {
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'accuracy': pos.accuracy,
          'altitude': pos.altitude,
          'speedKmh': speedKmh,
          'heading': pos.heading,
        },
        filteredValues: {
          'accuracyMeters': double.parse(pos.accuracy.toStringAsFixed(1)),
          'speedKmh': double.parse(speedKmh.toStringAsFixed(1)),
        },
        confidence: (1.0 - (pos.accuracy / 100.0)).clamp(0.1, 0.99),
        eventClassification: 'LOCK_HIGH_ACCURACY',
      ),
      deviceMotionState: motion,
      timestamp: now,
    );
    _emitSnapshot();
  }

  void _initInertialSensors() {
    _sensorService.startMonitoring();
    _sensorSub?.cancel();
    _sensorSub = _sensorService.readingStream.listen(_onSensorReading);
  }

  void _onSensorReading(SensorReading reading) {
    final now = DateTime.now();

    // 1. Accelerometer Filtering (EMA low-pass for gravity + high-pass delta)
    final rawMag = reading.accelMagnitude;
    _emaAccelMagnitude = _filterAlpha * rawMag + (1 - _filterAlpha) * _emaAccelMagnitude;
    final accelDelta = (rawMag - _emaAccelMagnitude).abs();

    String accelClass = 'NORMAL';
    double accelConfidence = 0.95;
    if (rawMag > 24.0) {
      accelClass = 'IMPACT_HIGH';
      accelConfidence = 0.90;
    } else if (rawMag > 16.0) {
      accelClass = 'ELEVATED_MOTION';
      accelConfidence = 0.80;
    } else if (rawMag < 3.0) {
      accelClass = 'FREEFALL_CANDIDATE';
      accelConfidence = 0.85;
    }

    final accelTelemetry = SensorTelemetry(
      name: 'ACCELEROMETER',
      status: _sensorService.isAccelAvailable ? SensorStatus.active : SensorStatus.error,
      permission: 'GRANTED',
      availability: _sensorService.isAccelAvailable,
      lastUpdate: now,
      rawValues: {
        'x': reading.accelX,
        'y': reading.accelY,
        'z': reading.accelZ,
        'magnitude': rawMag,
      },
      filteredValues: {
        'baseline': double.parse(_emaAccelMagnitude.toStringAsFixed(2)),
        'delta': double.parse(accelDelta.toStringAsFixed(2)),
      },
      confidence: accelConfidence,
      eventClassification: accelClass,
    );

    // 2. Gyroscope Filtering
    final rawGyroMag = reading.gyroMagnitude;
    _emaGyroMagnitude = _filterAlpha * rawGyroMag + (1 - _filterAlpha) * _emaGyroMagnitude;

    String gyroClass = 'STABLE';
    if (rawGyroMag > 6.0) {
      gyroClass = 'HIGH_ROTATION';
    } else if (rawGyroMag > 2.0) {
      gyroClass = 'ROTATING';
    }

    final gyroTelemetry = SensorTelemetry(
      name: 'GYROSCOPE',
      status: _sensorService.isGyroAvailable ? SensorStatus.active : SensorStatus.error,
      permission: 'GRANTED',
      availability: _sensorService.isGyroAvailable,
      lastUpdate: now,
      rawValues: {
        'x': reading.gyroX,
        'y': reading.gyroY,
        'z': reading.gyroZ,
        'rotation': rawGyroMag,
      },
      filteredValues: {
        'rotation_smoothed': double.parse(_emaGyroMagnitude.toStringAsFixed(2)),
      },
      confidence: 0.90,
      eventClassification: gyroClass,
    );

    _currentSnapshot = _currentSnapshot.copyWith(
      accelerometer: accelTelemetry,
      gyroscope: gyroTelemetry,
      timestamp: now,
    );
    _emitSnapshot();
  }

  Future<void> _initVoice() async {
    final hasMic = await _voiceService.checkPermission();
    final now = DateTime.now();

    _currentSnapshot = _currentSnapshot.copyWith(
      voice: SensorTelemetry(
        name: 'VOICE',
        status: hasMic ? (_voiceService.isListening ? SensorStatus.active : SensorStatus.inactive) : SensorStatus.permissionRequired,
        permission: hasMic ? 'GRANTED' : 'PERMISSION_REQUIRED',
        availability: _voiceService.isSttAvailable,
        lastUpdate: now,
        rawValues: {
          'listening': _voiceService.isListening,
          'transcript': _voiceService.latestTranscript,
        },
        filteredValues: {
          'distressCandidate': false,
        },
        confidence: 0.0,
        eventClassification: 'READY',
      ),
      timestamp: now,
    );

    _voiceSub?.cancel();
    _voiceSub = _voiceService.emergencyTriggerStream.listen((phrase) {
      _currentSnapshot = _currentSnapshot.copyWith(
        voice: _currentSnapshot.voice.copyWith(
          status: SensorStatus.active,
          lastUpdate: DateTime.now(),
          rawValues: {
            'listening': true,
            'transcript': phrase,
          },
          filteredValues: {
            'distressCandidate': true,
          },
          confidence: 0.90,
          eventClassification: 'DISTRESS_TRIGGER',
        ),
        timestamp: DateTime.now(),
      );
      _emitSnapshot();
    });
  }

  void _emitSnapshot() {
    if (!_snapshotController.isClosed) {
      _snapshotController.add(_currentSnapshot);
    }
  }

  void dispose() {
    stop();
    _snapshotController.close();
  }
}

extension SafetySensorSnapshotExt on SafetySensorSnapshot {
  SafetySensorSnapshot copyWith({
    SensorTelemetry? gps,
    SensorTelemetry? accelerometer,
    SensorTelemetry? gyroscope,
    SensorTelemetry? voice,
    DeviceMotionState? deviceMotionState,
    DateTime? timestamp,
  }) {
    return SafetySensorSnapshot(
      gps: gps ?? this.gps,
      accelerometer: accelerometer ?? this.accelerometer,
      gyroscope: gyroscope ?? this.gyroscope,
      voice: voice ?? this.voice,
      deviceMotionState: deviceMotionState ?? this.deviceMotionState,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
