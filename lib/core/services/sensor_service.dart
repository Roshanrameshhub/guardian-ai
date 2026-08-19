import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

import 'fall_detector.dart';

import '../../data/dto/api_dto.dart';
import '../../domain/repositories/repositories.dart';
import '../utils/dev_log.dart';

/// Motion event categories recognized by the Guardian AI intelligence layer.
enum MotionEventType {
  normalWalking,
  running,
  shakeDetected,
  phoneDrop,
  fallDetected,
  suddenStop,
  anomaly,
}

/// Instantaneous raw sensor reading bundle for diagnostics and UI gauges.
class SensorReading {
  const SensorReading({
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.accelMagnitude,
    required this.gyroMagnitude,
    required this.timestamp,
  });

  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final double accelMagnitude;
  final double gyroMagnitude;
  final DateTime timestamp;
}

/// Phone sensor service for lightweight edge processing of real motion signals.
/// Computes derived features locally to preserve battery and privacy.
class SensorService {
  SensorService({
    required IntelligenceRepository intelligenceRepository,
    Stream<AccelerometerEvent>? accelerometerStream,
    Stream<GyroscopeEvent>? gyroscopeStream,
  })  : _intelligenceRepo = intelligenceRepository,
        _customAccelStream = accelerometerStream,
        _customGyroStream = gyroscopeStream {
    _initFallDetector();
  }

  final IntelligenceRepository _intelligenceRepo;
  final Stream<AccelerometerEvent>? _customAccelStream;
  final Stream<GyroscopeEvent>? _customGyroStream;

  late final MultiStageFallDetector _fallDetector;

  void _initFallDetector() {
    _fallDetector = MultiStageFallDetector(
      onFallSuspected: (report) {
        _lastAnomalyTime = DateTime.now();
        DevLog.log('SENSOR', 'MULTI-STAGE FALL CONFIRMED: peak=${report.peakAcceleration.toStringAsFixed(1)} m/s², confidence=${(report.confidence * 100).toStringAsFixed(0)}%');
        _anomalyController.add(MotionEventType.fallDetected);
        dispatchMotionEvent(
          type: MotionEventType.fallDetected,
          accelerationPeak: report.peakAcceleration,
          rotationPeak: report.peakGyroRotation,
          confidence: report.confidence,
        );
      },
    );
  }

  MultiStageFallDetector get fallDetector => _fallDetector;

  bool _isMonitoring = false;
  bool _isAccelAvailable = true;
  bool _isGyroAvailable = true;

  // Live telemetry values
  double _latestAccelX = 0.0;
  double _latestAccelY = 0.0;
  double _latestAccelZ = 9.8;
  double _latestGyroX = 0.0;
  double _latestGyroY = 0.0;
  double _latestGyroZ = 0.0;
  double _liveAccelMagnitude = 9.8;
  double _liveGyroMagnitude = 0.0;
  DateTime? _lastLogTime;

  DateTime? _lastAnomalyTime;
  static const Duration _anomalyCooldown = Duration(milliseconds: 2000);

  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  final StreamController<MotionEventType> _anomalyController =
      StreamController<MotionEventType>.broadcast();

  final StreamController<SensorReading> _readingController =
      StreamController<SensorReading>.broadcast();

  // Local rolling window buffers
  final List<double> _accelWindow = [];
  final List<double> _rotWindow = [];

  bool get isMonitoring => _isMonitoring;
  bool get isAccelAvailable => _isAccelAvailable;
  bool get isGyroAvailable => _isGyroAvailable;

  double get latestAccelX => _latestAccelX;
  double get latestAccelY => _latestAccelY;
  double get latestAccelZ => _latestAccelZ;
  double get latestGyroX => _latestGyroX;
  double get latestGyroY => _latestGyroY;
  double get latestGyroZ => _latestGyroZ;
  double get liveAccelMagnitude => _liveAccelMagnitude;
  double get liveGyroMagnitude => _liveGyroMagnitude;

  Stream<MotionEventType> get anomalyStream => _anomalyController.stream;
  Stream<SensorReading> get readingStream => _readingController.stream;

  /// Start monitoring phone kinematics using real device hardware streams.
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;
    _accelWindow.clear();
    _rotWindow.clear();

    try {
      final accelStream = _customAccelStream ?? accelerometerEventStream();
      _accelSubscription = accelStream.listen(
        (event) => recordAccelerometerSample(event.x, event.y, event.z),
        onError: (err) {
          DevLog.log('SENSOR', 'Accelerometer stream error: $err');
          _isAccelAvailable = false;
        },
        cancelOnError: false,
      );
    } catch (e) {
      DevLog.log('SENSOR', 'Failed to subscribe to accelerometer: $e');
      _isAccelAvailable = false;
    }

    try {
      final gyroStream = _customGyroStream ?? gyroscopeEventStream();
      _gyroSubscription = gyroStream.listen(
        (event) => recordGyroscopeSample(event.x, event.y, event.z),
        onError: (err) {
          DevLog.log('SENSOR', 'Gyroscope stream error: $err');
          _isGyroAvailable = false;
        },
        cancelOnError: false,
      );
    } catch (e) {
      DevLog.log('SENSOR', 'Failed to subscribe to gyroscope: $e');
      _isGyroAvailable = false;
    }
    DevLog.log('SENSOR', 'Sensor monitoring started (accel=$_isAccelAvailable, gyro=$_isGyroAvailable)');
  }

  /// Stop monitoring phone kinematics and cancel all stream listeners.
  void stopMonitoring() {
    _isMonitoring = false;
    _accelSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription?.cancel();
    _gyroSubscription = null;

    _accelWindow.clear();
    _rotWindow.clear();
    DevLog.log('SENSOR', 'Sensor monitoring stopped');
  }

  /// Ingest a raw 3-axis accelerometer sample (x, y, z in m/s^2).
  void recordAccelerometerSample(double x, double y, double z) {
    _latestAccelX = x;
    _latestAccelY = y;
    _latestAccelZ = z;
    final magnitude = math.sqrt(x * x + y * y + z * z);
    _liveAccelMagnitude = magnitude;

    final now = DateTime.now();

    // Broadcast reading for live diagnostics
    _readingController.add(
      SensorReading(
        accelX: _latestAccelX,
        accelY: _latestAccelY,
        accelZ: _latestAccelZ,
        gyroX: _latestGyroX,
        gyroY: _latestGyroY,
        gyroZ: _latestGyroZ,
        accelMagnitude: _liveAccelMagnitude,
        gyroMagnitude: _liveGyroMagnitude,
        timestamp: now,
      ),
    );

    // Throttled debug log (once per 4 seconds)
    if (_lastLogTime == null || now.difference(_lastLogTime!).inSeconds >= 4) {
      _lastLogTime = now;
      DevLog.log('SENSOR', 'ACCEL ax=${x.toStringAsFixed(2)}, ay=${y.toStringAsFixed(2)}, az=${z.toStringAsFixed(2)}, mag=${magnitude.toStringAsFixed(2)} m/s²');
    }

    if (!_isMonitoring) return;

    _accelWindow.add(magnitude);
    if (_accelWindow.length > 50) {
      _accelWindow.removeAt(0);
    }

    // Pass sample into the 7-stage fall evaluation pipeline
    _fallDetector.processAccelSample(x, y, z, magnitude);

    // Instantaneous peak evaluation with cooldown debounce
    if (_lastAnomalyTime != null && now.difference(_lastAnomalyTime!) < _anomalyCooldown) {
      return;
    }

    // Physical high-intensity shake detection (> 26.0 m/s^2 impact with high rotational variance)
    // Picking up the phone (11-14 m/s^2) or placing on table will NEVER trigger this.
    if (magnitude > 26.0 && _liveGyroMagnitude > 3.5) {
      _lastAnomalyTime = now;
      DevLog.log('SENSOR', 'DELIBERATE SHAKE DETECTED: magnitude=${magnitude.toStringAsFixed(2)} m/s², gyro=${_liveGyroMagnitude.toStringAsFixed(2)} rad/s');
      _anomalyController.add(MotionEventType.shakeDetected);
      dispatchMotionEvent(
        type: MotionEventType.shakeDetected,
        accelerationPeak: magnitude,
        rotationPeak: _liveGyroMagnitude,
        confidence: 0.85,
      );
    }
  }

  /// Ingest a raw 3-axis gyroscope sample (x, y, z in rad/s).
  void recordGyroscopeSample(double x, double y, double z) {
    _latestGyroX = x;
    _latestGyroY = y;
    _latestGyroZ = z;
    final magnitude = math.sqrt(x * x + y * y + z * z);
    _liveGyroMagnitude = magnitude;

    if (!_isMonitoring) return;
    _rotWindow.add(magnitude);
    if (_rotWindow.length > 50) {
      _rotWindow.removeAt(0);
    }

    // Feed gyroscope rotation into multi-stage fall detector
    _fallDetector.processGyroSample(x, y, z, magnitude);
  }

  /// Safe simulated shake event for non-destructive development testing.
  /// Injects into the exact same production stream pipeline.
  void simulateShake({String? journeyId}) {
    DevLog.log('SENSOR', '[SIMULATION] Injecting simulated SHAKE event');
    _anomalyController.add(MotionEventType.shakeDetected);
    dispatchMotionEvent(
      type: MotionEventType.shakeDetected,
      accelerationPeak: 18.5,
      rotationPeak: 5.2,
      confidence: 1.0,
      journeyId: journeyId,
    );
  }

  /// Safe simulated phone drop event for development testing.
  void simulatePhoneDrop({String? journeyId}) {
    DevLog.log('SENSOR', '[SIMULATION] Injecting simulated PHONE DROP event');
    _anomalyController.add(MotionEventType.phoneDrop);
    dispatchMotionEvent(
      type: MotionEventType.phoneDrop,
      accelerationPeak: 26.8,
      rotationPeak: 8.1,
      confidence: 1.0,
      journeyId: journeyId,
    );
  }

  /// Safe simulated fall event for development testing.
  void simulateFall({String? journeyId}) {
    DevLog.log('SENSOR', '[SIMULATION] Injecting simulated FALL event');
    _anomalyController.add(MotionEventType.fallDetected);
    dispatchMotionEvent(
      type: MotionEventType.fallDetected,
      accelerationPeak: 22.4,
      rotationPeak: 6.8,
      confidence: 0.95,
      journeyId: journeyId,
    );
  }

  /// Directly dispatch a classified motion event to the backend.
  Future<void> dispatchMotionEvent({
    required MotionEventType type,
    String? journeyId,
    double accelerationPeak = 0.0,
    double rotationPeak = 0.0,
    bool suddenStop = false,
    double confidence = 0.85,
  }) async {
    String eventTypeStr;
    switch (type) {
      case MotionEventType.shakeDetected:
        eventTypeStr = 'SHAKE_DETECTED';
        break;
      case MotionEventType.phoneDrop:
        eventTypeStr = 'PHONE_DROP';
        break;
      case MotionEventType.fallDetected:
        eventTypeStr = 'FALL_DETECTED';
        break;
      case MotionEventType.suddenStop:
        eventTypeStr = 'SUDDEN_STOP';
        break;
      case MotionEventType.running:
        eventTypeStr = 'RUNNING';
        break;
      case MotionEventType.normalWalking:
        eventTypeStr = 'WALKING';
        break;
      case MotionEventType.anomaly:
        eventTypeStr = 'MOTION_ANOMALY';
        break;
    }

    try {
      await _intelligenceRepo.sendMotionSignal(
        MotionSignalRequest(
          eventType: eventTypeStr,
          durationMs: 1500,
          accelerationPeak: accelerationPeak,
          rotationPeak: rotationPeak,
          suddenStop: suddenStop,
          confidence: confidence,
          journeyId: journeyId,
        ),
      );
    } catch (_) {
      // Non-fatal edge event dispatch
    }
  }
}
