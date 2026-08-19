import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/dto/api_dto.dart';
import '../../domain/repositories/repositories.dart';
import '../utils/dev_log.dart';

/// Result summary returned after recording user cancellation.
class FalseAlarmAdjustmentResult {
  const FalseAlarmAdjustmentResult({
    required this.wasAdjusted,
    required this.message,
    required this.currentFallMultiplier,
    required this.currentVoiceThreshold,
    required this.recentCancellationCount,
  });

  final bool wasAdjusted;
  final String message;
  final double currentFallMultiplier;
  final double currentVoiceThreshold;
  final int recentCancellationCount;
}

/// Manages the user false alarm feedback loop and ML sensitivity calibration.
///
/// Ensures:
/// 1. Tapping "I'M OK" logs a false positive event to backend and local history.
/// 2. If user cancels 2 fall alerts in 24h, increases fall detection threshold by 10%.
/// 3. If user cancels voice alerts frequently, increases voice confidence threshold.
/// 4. Calibrations persist across app restarts via secure storage.
class FalseAlarmManager {
  FalseAlarmManager({
    IntelligenceRepository? intelligenceRepository,
    FlutterSecureStorage? secureStorage,
  })  : _intelligenceRepo = intelligenceRepository,
        _storage = secureStorage ?? const FlutterSecureStorage();

  final IntelligenceRepository? _intelligenceRepo;
  final FlutterSecureStorage _storage;

  double _fallSensitivityMultiplier = 1.0;
  double _voiceConfidenceThreshold = 0.70;

  final List<DateTime> _fallCancellations = [];
  final List<DateTime> _voiceCancellations = [];
  final List<DateTime> _shakeCancellations = [];

  static const String _storageKeyFall = 'guardian_ml_fall_multiplier';
  static const String _storageKeyVoice = 'guardian_ml_voice_threshold';
  static const String _storageKeyHistory = 'guardian_ml_cancellation_history';

  double get fallSensitivityMultiplier => _fallSensitivityMultiplier;
  double get voiceConfidenceThreshold => _voiceConfidenceThreshold;
  int get recentFallCancellations => _countRecent(_fallCancellations);
  int get recentVoiceCancellations => _countRecent(_voiceCancellations);

  /// Load persisted ML calibration thresholds from local secure storage.
  Future<void> loadCalibration() async {
    try {
      final savedFall = await _storage.read(key: _storageKeyFall);
      if (savedFall != null) {
        _fallSensitivityMultiplier = double.tryParse(savedFall) ?? 1.0;
      }

      final savedVoice = await _storage.read(key: _storageKeyVoice);
      if (savedVoice != null) {
        _voiceConfidenceThreshold = double.tryParse(savedVoice) ?? 0.70;
      }

      final savedHistory = await _storage.read(key: _storageKeyHistory);
      if (savedHistory != null) {
        final data = jsonDecode(savedHistory) as Map<String, dynamic>;
        _restoreHistory(_fallCancellations, data['fall'] as List?);
        _restoreHistory(_voiceCancellations, data['voice'] as List?);
        _restoreHistory(_shakeCancellations, data['shake'] as List?);
      }

      DevLog.log(
        'ML_CALIBRATION',
        'Loaded sensitivity calibration: fallMult=$_fallSensitivityMultiplier, voiceThresh=$_voiceConfidenceThreshold',
      );
    } catch (e) {
      DevLog.log('ML_CALIBRATION', 'Error loading calibration: $e');
    }
  }

  /// Record user cancellation ("I'M OK"), adjust ML calibration, persist, and sync to backend.
  Future<FalseAlarmAdjustmentResult> recordCancellation({
    required String triggerSource,
    Map<String, dynamic>? sensorValues,
    String? eventId,
    String userResponse = 'CANCELLED_BY_USER',
  }) async {
    final now = DateTime.now();
    final sourceLower = triggerSource.toLowerCase();
    bool adjusted = false;
    String feedbackMsg = 'Safety confirmed. Monitoring continues.';

    if (sourceLower.contains('fall') || sourceLower.contains('drop')) {
      _fallCancellations.add(now);
      final recentCount = _countRecent(_fallCancellations);
      if (recentCount >= 2) {
        _fallSensitivityMultiplier = (_fallSensitivityMultiplier * 1.10).clamp(1.0, 2.0);
        adjusted = true;
        feedbackMsg = 'Sensitivity adjusted to reduce false alarms.';
        DevLog.log(
          'ML_CALIBRATION',
          '2 fall alerts cancelled within 24h. Increased fall threshold to $_fallSensitivityMultiplier (+10%)',
        );
      }
    } else if (sourceLower.contains('voice') || sourceLower.contains('mic')) {
      _voiceCancellations.add(now);
      final recentCount = _countRecent(_voiceCancellations);
      if (recentCount >= 2) {
        _voiceConfidenceThreshold = (_voiceConfidenceThreshold + 0.05).clamp(0.50, 0.95);
        adjusted = true;
        feedbackMsg = 'Sensitivity adjusted to reduce false alarms.';
        DevLog.log(
          'ML_CALIBRATION',
          'Voice alert cancelled frequently. Increased voice confidence threshold to $_voiceConfidenceThreshold',
        );
      }
    } else if (sourceLower.contains('shake')) {
      _shakeCancellations.add(now);
    }

    // Persist calibration
    await _saveCalibration();

    // Sync to backend intelligence service
    if (_intelligenceRepo != null) {
      try {
        await _intelligenceRepo.recordFalsePositive(
          FalsePositiveFeedbackRequest(
            eventId: eventId ?? 'evt_${now.millisecondsSinceEpoch}',
            triggerSource: triggerSource.toUpperCase(),
            userResponse: userResponse,
            notes: jsonEncode(sensorValues ?? {}),
          ),
        );
        DevLog.log('ML_CALIBRATION', 'Synced false positive feedback to backend.');
      } catch (e) {
        DevLog.log('ML_CALIBRATION', 'Warning syncing false positive to backend: $e');
      }
    }

    return FalseAlarmAdjustmentResult(
      wasAdjusted: adjusted,
      message: feedbackMsg,
      currentFallMultiplier: _fallSensitivityMultiplier,
      currentVoiceThreshold: _voiceConfidenceThreshold,
      recentCancellationCount: sourceLower.contains('fall')
          ? recentFallCancellations
          : recentVoiceCancellations,
    );
  }

  int _countRecent(List<DateTime> list) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    list.removeWhere((dt) => dt.isBefore(cutoff));
    return list.length;
  }

  void _restoreHistory(List<DateTime> list, List? source) {
    if (source == null) return;
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    for (final item in source) {
      if (item is String) {
        final dt = DateTime.tryParse(item);
        if (dt != null && dt.isAfter(cutoff)) {
          list.add(dt);
        }
      }
    }
  }

  Future<void> _saveCalibration() async {
    try {
      await _storage.write(key: _storageKeyFall, value: _fallSensitivityMultiplier.toString());
      await _storage.write(key: _storageKeyVoice, value: _voiceConfidenceThreshold.toString());

      final history = {
        'fall': _fallCancellations.map((dt) => dt.toIso8601String()).toList(),
        'voice': _voiceCancellations.map((dt) => dt.toIso8601String()).toList(),
        'shake': _shakeCancellations.map((dt) => dt.toIso8601String()).toList(),
      };
      await _storage.write(key: _storageKeyHistory, value: jsonEncode(history));
    } catch (e) {
      DevLog.log('ML_CALIBRATION', 'Error saving calibration: $e');
    }
  }

  /// Reset ML calibration back to factory defaults.
  Future<void> resetToDefaults() async {
    _fallSensitivityMultiplier = 1.0;
    _voiceConfidenceThreshold = 0.70;
    _fallCancellations.clear();
    _voiceCancellations.clear();
    _shakeCancellations.clear();
    await _saveCalibration();
    DevLog.log('ML_CALIBRATION', 'Reset sensitivity calibrations to defaults.');
  }
}
