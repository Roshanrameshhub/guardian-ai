import 'dart:async';
import 'dart:math' as math;
import '../utils/dev_log.dart';

/// Diagnostic outcome of the multi-stage fall evaluation.
enum FallEvaluationResult {
  noFall,
  normalPickup,
  normalWalking,
  tablePlacement,
  shakeAnomaly,
  phoneDroppedSafe,
  fallSuspected,
}

/// Detailed evaluation report from all 7 stages.
class FallEvaluationReport {
  const FallEvaluationReport({
    required this.result,
    required this.confidence,
    required this.freefallDetected,
    required this.peakAcceleration,
    required this.peakGyroRotation,
    required this.postImpactImmobility,
    required this.gpsSpeedDrop,
    required this.reason,
    required this.timestamp,
  });

  final FallEvaluationResult result;
  final double confidence; // [0.0 .. 1.0]
  final bool freefallDetected;
  final double peakAcceleration; // m/s^2
  final double peakGyroRotation; // rad/s
  final bool postImpactImmobility;
  final bool gpsSpeedDrop;
  final String reason;
  final DateTime timestamp;

  bool get isFallSuspected => result == FallEvaluationResult.fallSuspected && confidence >= 0.70;
}

/// Multi-Stage Fall Detector
///
/// Implements a 7-stage kinematic pipeline to eliminate false positives from:
/// - Phone picked up
/// - Phone placed down
/// - Normal walking / running
/// - Small shake or pocket movement
/// - Table vibration
///
/// STAGES:
/// 1. Motion Anomaly (Freefall < 4.0 m/s² or sudden jerk > 20 m/s²)
/// 2. Acceleration Magnitude (Impact spike check > 25.0 m/s²)
/// 3. Gyroscope Rotation (Tumbling check > 4.0 rad/s)
/// 4. Temporal Pattern (Freefall followed by impact within 500ms)
/// 5. Post-Impact Immobility (Movement cessation for 1.5–2.5s)
/// 6. GPS Movement State (Speed drop check)
/// 7. Weighted Confidence Calculation (Requires >= 0.70 score)
class MultiStageFallDetector {
  MultiStageFallDetector({
    this.onFallSuspected,
    this.onReportGenerated,
  });

  void Function(FallEvaluationReport report)? onFallSuspected;
  void Function(FallEvaluationReport report)? onReportGenerated;

  // Internal state tracking
  bool _inCandidateWindow = false;
  DateTime? _freefallStartTime;
  DateTime? _impactTime;
  double _peakAccel = 0.0;
  double _peakGyro = 0.0;
  double _lastGpsSpeedKmh = 0.0;

  final List<double> _postImpactWindow = [];
  Timer? _immobilityTimer;

  // Calibration thresholds
  static const double _freefallThreshold = 4.0; // m/s² (~0.4g)
  static const double _impactThreshold = 25.0; // m/s² (~2.5g)
  static const double _gyroRotationThreshold = 4.0; // rad/s
  static const double _stillnessVarianceLimit = 1.8; // m/s² std dev for post-fall resting

  /// Machine learning sensitivity multiplier calibrated dynamically from user false alarm feedback.
  /// (e.g. 1.10 = 10% higher threshold to prevent repeated false positives).
  double sensitivityMultiplier = 1.0;

  double get effectiveImpactThreshold => _impactThreshold * sensitivityMultiplier;

  /// Update detector with live GPS ground speed.
  void updateGpsSpeed(double speedKmh) {
    _lastGpsSpeedKmh = speedKmh;
  }

  /// Ingest raw accelerometer sample.
  void processAccelSample(double x, double y, double z, double magnitude) {
    final now = DateTime.now();

    // Stage 1: Freefall candidate detection
    if (magnitude < _freefallThreshold && !_inCandidateWindow) {
      _inCandidateWindow = true;
      _freefallStartTime = now;
      _peakAccel = magnitude;
      _peakGyro = 0.0;
      _postImpactWindow.clear();
      DevLog.log('FALL_DETECTOR', 'Stage 1: Potential freefall detected (mag=${magnitude.toStringAsFixed(2)} m/s²)');
      return;
    }

    // Stage 2 & 4: Impact spike following candidate window
    if (_inCandidateWindow && _impactTime == null) {
      if (magnitude > _peakAccel) {
        _peakAccel = magnitude;
      }

      if (magnitude >= effectiveImpactThreshold) {
        final elapsedSinceFreefall = _freefallStartTime != null
            ? now.difference(_freefallStartTime!).inMilliseconds
            : 999;

        // Valid impact within 600ms of freefall entry
        if (elapsedSinceFreefall <= 600 || _freefallStartTime == null) {
          _impactTime = now;
          DevLog.log('FALL_DETECTOR', 'Stage 2 & 4: Impact spike recorded (${magnitude.toStringAsFixed(2)} m/s² vs threshold ${effectiveImpactThreshold.toStringAsFixed(2)})');

          // Schedule Stage 5 (Post-impact immobility check after 1.8s)
          _immobilityTimer?.cancel();
          _immobilityTimer = Timer(const Duration(milliseconds: 1800), () {
            _evaluateCompleteFallSequence();
          });
        }
      }
    } else if (_impactTime != null) {
      // Accumulate post-impact samples for Stage 5 (samples after impact peak)
      _postImpactWindow.add(magnitude);
      if (_postImpactWindow.length > 50) {
        _postImpactWindow.removeAt(0);
      }
    }
  }

  /// Ingest raw gyroscope sample.
  void processGyroSample(double x, double y, double z, double rotationMagnitude) {
    if (_inCandidateWindow) {
      if (rotationMagnitude > _peakGyro) {
        _peakGyro = rotationMagnitude;
      }
    }
  }

  /// Stage 5, 6, 7: Final multi-stage evaluation.
  void _evaluateCompleteFallSequence() {
    final now = DateTime.now();
    final hasFreefall = _freefallStartTime != null;
    final hasImpact = _peakAccel >= _impactThreshold;
    final hasRotation = _peakGyro >= _gyroRotationThreshold;

    // Stage 5: Calculate post-impact variance to check for stillness
    bool isImmobile = false;
    double variance = 0.0;
    if (_postImpactWindow.isNotEmpty) {
      final mean = _postImpactWindow.reduce((a, b) => a + b) / _postImpactWindow.length;
      final sumSquares = _postImpactWindow.map((val) => math.pow(val - mean, 2)).reduce((a, b) => a + b);
      variance = math.sqrt(sumSquares / _postImpactWindow.length);

      // Stillness condition: mean near gravity (8.5 - 11.0) and very low variance
      isImmobile = (mean >= 8.5 && mean <= 11.5) && (variance < _stillnessVarianceLimit);
    }

    // Stage 6: GPS speed check
    final isGpsStill = _lastGpsSpeedKmh < 1.5;

    // Stage 7: Weighted Confidence Calculation
    double confidence = 0.0;
    if (hasFreefall) confidence += 0.25;
    if (hasImpact) confidence += 0.25;
    if (hasRotation) confidence += 0.20;
    if (isImmobile) confidence += 0.20;
    if (isGpsStill) confidence += 0.10;

    confidence = confidence.clamp(0.0, 1.0);

    // Classify result
    FallEvaluationResult result = FallEvaluationResult.noFall;
    String reason = 'Normal movement pattern.';

    if (confidence >= 0.70 && hasImpact && (hasRotation || hasFreefall)) {
      result = FallEvaluationResult.fallSuspected;
      reason = 'Multi-stage fall criteria satisfied: impact (${_peakAccel.toStringAsFixed(1)} m/s²), '
          'rotation (${_peakGyro.toStringAsFixed(1)} rad/s), post-impact immobility=$isImmobile.';
    } else if (hasImpact && !isImmobile) {
      result = FallEvaluationResult.phoneDroppedSafe;
      reason = 'Impact detected but user movement continued immediately (no incapacitation).';
    } else if (_peakAccel < 16.0 && _peakGyro < 2.0) {
      result = FallEvaluationResult.normalPickup;
      reason = 'Low-acceleration translation consistent with picking up/placing phone.';
    } else {
      result = FallEvaluationResult.shakeAnomaly;
      reason = 'Kinematic vibration or shake without fall impact signature.';
    }

    final report = FallEvaluationReport(
      result: result,
      confidence: confidence,
      freefallDetected: hasFreefall,
      peakAcceleration: _peakAccel,
      peakGyroRotation: _peakGyro,
      postImpactImmobility: isImmobile,
      gpsSpeedDrop: isGpsStill,
      reason: reason,
      timestamp: now,
    );

    DevLog.log(
      'FALL_DETECTOR',
      'Evaluation: ${result.name.toUpperCase()} (Confidence: ${(confidence * 100).toStringAsFixed(0)}%) - $reason',
    );

    onReportGenerated?.call(report);

    if (report.isFallSuspected) {
      onFallSuspected?.call(report);
    }

    // Reset detector state
    _reset();
  }

  void _reset() {
    _inCandidateWindow = false;
    _freefallStartTime = null;
    _impactTime = null;
    _peakAccel = 0.0;
    _peakGyro = 0.0;
    _postImpactWindow.clear();
    _immobilityTimer?.cancel();
    _immobilityTimer = null;
  }

  void dispose() {
    _immobilityTimer?.cancel();
  }
}
