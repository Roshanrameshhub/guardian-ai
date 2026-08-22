import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/dto/api_dto.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../utils/dev_log.dart';

/// Complete state machine for Voice Distress Subsystem.
enum VoiceState {
  off,
  starting,
  listening,
  processing,
  distressDetected,
  permissionRequired,
  error,
  paused,
}

/// Real Voice Distress Detection Service with Continuous Active Monitoring.
class VoiceService {
  VoiceService({
    required IntelligenceRepository intelligenceRepository,
    SpeechToText? speechToText,
  })  : _intelligenceRepo = intelligenceRepository,
        _stt = speechToText ?? SpeechToText();

  final IntelligenceRepository _intelligenceRepo;
  final SpeechToText _stt;

  VoiceState _state = VoiceState.off;
  bool _isMonitoring = false;
  bool _sttAvailable = false;
  bool _hasMicPermission = false;
  bool _isPermanentlyDenied = false;
  String? _activeJourneyId;
  String _latestTranscript = '';
  List<String> _matchedKeywords = [];
  double _confidence = 0.0;
  String _latestUrgency = 'NONE';
  String _lastEventSource = 'NONE'; // 'REAL_MIC' or 'TEST_SIMULATOR'
  String? _errorMessage;

  Timer? _restartDebounceTimer;
  Timer? _watchdogTimer;
  int _consecutiveRestartCount = 0;
  DateTime? _lastRestartTime;

  static const List<String> triggerPhrases = [
    'help',
    'help me',
    'i need help',
    'please help',
    'please help me',
    'someone help',
    'save me',
    'save my life',
    'emergency',
    'danger',
    'in danger',
    'i am in danger',
    'call police',
    'bachao',
    'chhod do',
    'guardian',
    'sos',
  ];

  final StreamController<VoiceState> _stateController =
      StreamController<VoiceState>.broadcast();
  final StreamController<String> _emergencyTriggerController =
      StreamController<String>.broadcast();

  VoiceState get state => _state;
  bool get isListening => _state == VoiceState.listening || _stt.isListening;
  bool get isMonitoring => _isMonitoring;
  bool get isSttAvailable => _sttAvailable;
  bool get hasMicPermission => _hasMicPermission;
  bool get isPermanentlyDenied => _isPermanentlyDenied;
  String get latestTranscript => _latestTranscript;
  List<String> get matchedKeywords => List.unmodifiable(_matchedKeywords);
  double get confidence => _confidence;
  String get latestUrgency => _latestUrgency;
  String get lastEventSource => _lastEventSource;
  String? get errorMessage => _errorMessage;

  Stream<VoiceState> get stateStream => _stateController.stream;
  Stream<String> get emergencyTriggerStream => _emergencyTriggerController.stream;

  void _setState(VoiceState newState) {
    if (_state != newState) {
      _state = newState;
      DevLog.log('VOICE', '[VOICE] state = ${_state.name.toUpperCase()}');
      if (!_stateController.isClosed) {
        _stateController.add(_state);
      }
    }
  }

  /// Check mic permission status without requesting
  Future<bool> checkPermission() async {
    try {
      final status = await Permission.microphone.status;
      _hasMicPermission = status.isGranted;
      _isPermanentlyDenied = status.isPermanentlyDenied || status.isRestricted;
      return _hasMicPermission;
    } catch (_) {
      _hasMicPermission = false;
      return false;
    }
  }

  /// Request microphone permission explicitly
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      _hasMicPermission = status.isGranted;
      _isPermanentlyDenied = status.isPermanentlyDenied || status.isRestricted;
      DevLog.log('VOICE', '[VOICE] microphone permission = ${_hasMicPermission ? "granted" : "denied"}');
      if (!_hasMicPermission) {
        _setState(VoiceState.permissionRequired);
      }
      return _hasMicPermission;
    } catch (e) {
      DevLog.log('VOICE', '[VOICE] microphone permission request error: $e');
      _hasMicPermission = false;
      _setState(VoiceState.permissionRequired);
      return false;
    }
  }

  /// Start voice distress monitoring session.
  Future<void> startListening({String? journeyId}) async {
    _activeJourneyId = journeyId;
    _isMonitoring = true;
    _consecutiveRestartCount = 0;
    _errorMessage = null;

    DevLog.log('VOICE', '[VOICE] service initialization started');
    _setState(VoiceState.starting);

    // 1. Verify Microphone Permission
    final granted = await requestPermission();
    if (!granted) {
      DevLog.log('VOICE', '[VOICE] microphone permission = denied');
      _setState(VoiceState.permissionRequired);
      return;
    }

    // 2. Initialize Speech Recognition Engine
    if (!_sttAvailable) {
      try {
        _sttAvailable = await _stt.initialize(
          onError: _onSttError,
          onStatus: _onSttStatus,
          debugLogging: false,
        );
        DevLog.log('VOICE', '[VOICE] speech recognition available = $_sttAvailable');
      } catch (e) {
        DevLog.log('VOICE', '[VOICE] STT initialization exception: $e');
        _sttAvailable = false;
      }
    }

    if (!_sttAvailable) {
      _errorMessage = 'Speech recognition unavailable on this device.';
      DevLog.log('VOICE', '[VOICE] speech recognition available = false ($errorMessage)');
      _setState(VoiceState.error);
      return;
    }

    // 3. Start Active Listening Cycle
    DevLog.log('VOICE', '[VOICE] starting listener');
    _startListenCycle();

    // 4. Start Watchdog Timer for continuous monitoring integrity
    _startWatchdog();
  }

  /// Stop voice distress monitoring session.
  void stopListening() {
    _isMonitoring = false;
    _activeJourneyId = null;
    _restartDebounceTimer?.cancel();
    _restartDebounceTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;

    if (_stt.isListening) {
      try {
        _stt.stop();
      } catch (_) {}
    }

    _setState(VoiceState.off);
    _latestTranscript = '';
    _matchedKeywords = [];
    DevLog.log('VOICE', '[VOICE] voice monitoring stopped');
  }

  /// Pause voice distress monitoring (e.g. background restriction).
  void pauseListening() {
    if (!_isMonitoring) return;
    _restartDebounceTimer?.cancel();
    _restartDebounceTimer = null;
    if (_stt.isListening) {
      try {
        _stt.stop();
      } catch (_) {}
    }
    _setState(VoiceState.paused);
    DevLog.log('VOICE', '[VOICE] status = paused');
  }

  /// Resume voice distress monitoring after pause.
  void resumeListening() {
    if (!_isMonitoring) return;
    DevLog.log('VOICE', '[VOICE] resuming listener');
    _startListenCycle();
  }

  void _startListenCycle() {
    if (!_isMonitoring || !_sttAvailable) return;
    if (_stt.isListening) {
      _setState(VoiceState.listening);
      return;
    }

    // Circuit breaker for runaway crash loops
    final now = DateTime.now();
    if (_lastRestartTime != null && now.difference(_lastRestartTime!).inMilliseconds < 300) {
      _consecutiveRestartCount++;
      if (_consecutiveRestartCount > 10) {
        DevLog.log('VOICE', '[VOICE] rapid restart limit reached, backing off 2s...');
        _scheduleRestart(delayMs: 2000);
        return;
      }
    } else {
      _consecutiveRestartCount = 0;
    }
    _lastRestartTime = now;

    try {
      _setState(VoiceState.starting);
      _stt.listen(
        onResult: _onSttResult,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          onDevice: false,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
        ),
      );
      DevLog.log('VOICE', '[VOICE] listening started');
      _setState(VoiceState.listening);
    } catch (e) {
      DevLog.log('VOICE', '[VOICE] listen start failed: $e');
      _scheduleRestart(delayMs: 1000);
    }
  }

  void _scheduleRestart({int delayMs = 400}) {
    if (!_isMonitoring) return;
    _restartDebounceTimer?.cancel();
    _restartDebounceTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_isMonitoring) {
        _startListenCycle();
      }
    });
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_isMonitoring && _state != VoiceState.paused && _state != VoiceState.permissionRequired) {
        if (!_stt.isListening) {
          DevLog.log('VOICE', '[VOICE] Watchdog: recognizer inactive, triggering safe restart cycle');
          _startListenCycle();
        }
      }
    });
  }

  void _onSttResult(SpeechRecognitionResult result) {
    final rawTranscript = result.recognizedWords.trim();
    if (rawTranscript.isEmpty) return;

    _latestTranscript = rawTranscript;
    _lastEventSource = 'REAL_MIC';

    DevLog.log('VOICE', '[VOICE] recognition result received (words: ${rawTranscript.split(" ").length}, final: ${result.finalResult})');
    DevLog.log('VOICE', '[VOICE] recognized text received');

    // Analyze recognized words for distress keywords
    _analyzeTranscript(rawTranscript);

    // If session finalized, schedule continuous loop restart
    if (result.finalResult && _isMonitoring) {
      _scheduleRestart(delayMs: 400);
    }
  }

  /// Evaluates distress keywords with punctuation sanitation & boundary matching.
  void _analyzeTranscript(String transcript) {
    final clean = _sanitizeForMatching(transcript);
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();

    final matched = <String>[];

    for (final phrase in triggerPhrases) {
      final cleanPhrase = _sanitizeForMatching(phrase);
      if (cleanPhrase.contains(' ')) {
        // Multi-word phrase check (e.g. "help me", "in danger", "save me")
        if (clean.contains(cleanPhrase)) {
          matched.add(phrase);
        }
      } else {
        // Single word token check (e.g. "help", "danger", "emergency", "guardian")
        if (words.contains(cleanPhrase)) {
          matched.add(phrase);
        }
      }
    }

    _matchedKeywords = matched;

    if (matched.isNotEmpty) {
      _confidence = 0.95;
      _latestUrgency = 'HIGH';
      _setState(VoiceState.distressDetected);

      DevLog.log('VOICE', '[VOICE] distress keyword detected: "$matched"');
      DevLog.log('VOICE', '[VOICE] creating safety incident');
      DevLog.log('VOICE', '[VOICE] danger confirmation requested');

      _emergencyTriggerController.add(transcript);

      // Asynchronously process with backend intelligence without blocking UI confirmation
      processVoiceSample(
        text: transcript,
        voiceIntensity: _estimateIntensityProxy(transcript),
        journeyId: _activeJourneyId,
      );
    }
  }

  String _sanitizeForMatching(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .trim();
  }

  double _estimateIntensityProxy(String text) {
    final tokens = text.split(RegExp(r'\s+'));
    int capsWords = tokens.where((w) => w.length > 1 && w == w.toUpperCase()).length;
    bool hasExclamation = text.contains('!') || text.contains('?');
    double base = 0.40;
    if (capsWords > 0) base += 0.20;
    if (hasExclamation) base += 0.15;
    return base.clamp(0.0, 1.0);
  }

  /// Process voice sample with backend AI distress model.
  Future<VoiceDistressEntity?> processVoiceSample({
    required String text,
    double voiceIntensity = 0.5,
    double pitchVariance = 0.5,
    int? speechRateWpm,
    String? journeyId,
  }) async {
    if (text.trim().isEmpty) return null;

    try {
      final response = await _intelligenceRepo.sendVoiceAnalysis(
        VoiceAnalysisRequest(
          transcriptOrText: text,
          voiceIntensity: voiceIntensity,
          pitchVariance: pitchVariance,
          speechRateWpm: speechRateWpm,
          journeyId: journeyId ?? _activeJourneyId,
        ),
      );
      _latestUrgency = response.urgency.toUpperCase();
      _confidence = response.modelConfidence;
      DevLog.log('VOICE', '[VOICE] AI distress urgency: ${response.urgency}, score: ${response.distressScore}');
      return response;
    } catch (e) {
      DevLog.log('VOICE', '[VOICE] Voice analysis dispatch error: $e');
      return null;
    }
  }

  /// Safe simulated voice trigger for non-destructive development/test verification.
  /// Clearly flagged with source 'TEST_SIMULATOR' (does not use real microphone).
  void simulateVoiceTrigger(String phrase, {String? journeyId}) {
    DevLog.log('VOICE', '[VOICE] [TEST EVENT] distress keyword detected: "$phrase"');
    DevLog.log('VOICE', '[VOICE] [TEST EVENT] creating safety incident');
    DevLog.log('VOICE', '[VOICE] [TEST EVENT] danger confirmation requested');

    _lastEventSource = 'TEST_SIMULATOR';
    _latestTranscript = phrase;
    _matchedKeywords = [phrase];
    _confidence = 1.0;
    _latestUrgency = 'CRITICAL';
    _setState(VoiceState.distressDetected);

    _emergencyTriggerController.add(phrase);

    processVoiceSample(
      text: phrase,
      voiceIntensity: 0.95,
      pitchVariance: 0.85,
      journeyId: journeyId ?? _activeJourneyId,
    );
  }

  /// Safe simulated loud noise anomaly for development testing.
  void simulateLoudNoise({String? journeyId}) {
    DevLog.log('VOICE', '[VOICE] [TEST EVENT] loud noise impact detected');
    _lastEventSource = 'TEST_SIMULATOR';
    _latestTranscript = 'LOUD NOISE IMPACT';
    _matchedKeywords = ['LOUD_NOISE_ANOMALY'];
    _confidence = 0.95;
    _latestUrgency = 'CRITICAL';
    _setState(VoiceState.distressDetected);

    _emergencyTriggerController.add('LOUD_NOISE_ANOMALY');

    processVoiceSample(
      text: 'LOUD NOISE IMPACT',
      voiceIntensity: 0.98,
      pitchVariance: 0.90,
      journeyId: journeyId ?? _activeJourneyId,
    );
  }

  void _onSttError(SpeechRecognitionError error) {
    DevLog.log('VOICE', '[VOICE] STT error: ${error.errorMsg} (permanent: ${error.permanent})');

    // Treat common recoverable speech errors by scheduling controlled restart
    final errorMsg = error.errorMsg.toLowerCase();
    final isRecoverableTimeout = errorMsg.contains('timeout') ||
        errorMsg.contains('no speech') ||
        errorMsg.contains('no match') ||
        errorMsg.contains('busy') ||
        errorMsg.contains('network');

    if (!error.permanent || isRecoverableTimeout) {
      _scheduleRestart(delayMs: 600);
    } else {
      _errorMessage = error.errorMsg;
      _setState(VoiceState.error);
    }
  }

  void _onSttStatus(String status) {
    DevLog.log('VOICE', '[VOICE] status = $status');

    if (status == 'listening') {
      _setState(VoiceState.listening);
    } else if (status == 'notListening' || status == 'done') {
      if (_isMonitoring && _state != VoiceState.paused && _state != VoiceState.permissionRequired) {
        _scheduleRestart(delayMs: 300);
      }
    }
  }

  void dispose() {
    stopListening();
    _stateController.close();
    _emergencyTriggerController.close();
  }
}
