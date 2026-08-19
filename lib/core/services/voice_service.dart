import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/dto/api_dto.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../utils/dev_log.dart';

/// Real Voice Distress Detection Service.
class VoiceService {
  VoiceService({required IntelligenceRepository intelligenceRepository})
      : _intelligenceRepo = intelligenceRepository;

  final IntelligenceRepository _intelligenceRepo;
  final SpeechToText _stt = SpeechToText();

  bool _isListening = false;
  bool _sttAvailable = false;
  bool _hasMicPermission = false;
  String? _activeJourneyId;
  String _latestTranscript = '';
  List<String> _matchedKeywords = [];
  double _confidence = 0.0;
  String _latestUrgency = 'NONE';
  String _lastEventSource = 'NONE'; // 'REAL_MIC' or 'TEST_SIMULATOR'
  Timer? _listenCycleTimer;

  static const List<String> triggerPhrases = [
    'help',
    'help me',
    'i need help',
    'please help',
    'someone help',
    'save me',
    'emergency',
    'danger',
    'call police',
    'bachao',
    'chhod do',
  ];

  final StreamController<String> _emergencyTriggerController =
      StreamController<String>.broadcast();

  bool get isListening => _isListening;
  bool get isSttAvailable => _sttAvailable;
  bool get hasMicPermission => _hasMicPermission;
  String get latestTranscript => _latestTranscript;
  List<String> get matchedKeywords => List.unmodifiable(_matchedKeywords);
  double get confidence => _confidence;
  String get latestUrgency => _latestUrgency;
  String get lastEventSource => _lastEventSource;
  Stream<String> get emergencyTriggerStream => _emergencyTriggerController.stream;

  /// Check mic permission status
  Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    _hasMicPermission = status.isGranted;
    return _hasMicPermission;
  }

  /// Request microphone permission explicitly
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    _hasMicPermission = status.isGranted;
    return _hasMicPermission;
  }

  /// Start voice distress monitoring.
  Future<void> startListening({String? journeyId}) async {
    if (_isListening) return;
    _activeJourneyId = journeyId;

    // 1. Check / Request microphone permission
    final granted = await requestPermission();
    if (!granted) {
      DevLog.log('VOICE', 'Microphone permission denied — voice trigger inactive.');
      return;
    }

    // 2. Initialize the STT engine
    try {
      _sttAvailable = await _stt.initialize(
        onError: _onSttError,
        onStatus: _onSttStatus,
      );
    } catch (e) {
      DevLog.log('VOICE', 'STT initialization error: $e');
      _sttAvailable = false;
      return;
    }

    if (!_sttAvailable) {
      DevLog.log('VOICE', 'STT speech recognition not available on this platform/device.');
      return;
    }

    _isListening = true;
    DevLog.log('VOICE', 'Voice monitoring active and listening for distress phrases...');

    // 3. Start first listen cycle
    _startListenCycle();
  }

  /// Stop voice distress monitoring.
  void stopListening() {
    _isListening = false;
    _activeJourneyId = null;
    _listenCycleTimer?.cancel();
    _listenCycleTimer = null;
    if (_stt.isListening) {
      _stt.stop();
    }
    _latestTranscript = '';
    DevLog.log('VOICE', 'Voice monitoring stopped.');
  }

  /// Safe simulated voice trigger for non-destructive testing.
  /// Clearly flagged with source 'TEST_SIMULATOR' (does not use real microphone).
  void simulateVoiceTrigger(String phrase, {String? journeyId}) {
    DevLog.log('VOICE', '[TEST_SIMULATOR] Injecting simulated VOICE TRIGGER: "$phrase"');
    _lastEventSource = 'TEST_SIMULATOR';
    _latestTranscript = phrase;
    _matchedKeywords = [phrase];
    _confidence = 1.0;
    _latestUrgency = 'CRITICAL';
    _emergencyTriggerController.add(phrase);
    processVoiceSample(
      text: phrase,
      voiceIntensity: 0.95,
      pitchVariance: 0.85,
      journeyId: journeyId ?? _activeJourneyId,
    );
  }

  /// Safe simulated loud noise detection.
  /// Clearly flagged with source 'TEST_SIMULATOR' (does not use real microphone).
  void simulateLoudNoise({String? journeyId}) {
    DevLog.log('VOICE', '[TEST_SIMULATOR] Injecting simulated LOUD NOISE trigger');
    _lastEventSource = 'TEST_SIMULATOR';
    _latestTranscript = 'LOUD NOISE IMPACT';
    _matchedKeywords = ['LOUD_NOISE_ANOMALY'];
    _confidence = 0.95;
    _latestUrgency = 'CRITICAL';
    _emergencyTriggerController.add('LOUD_NOISE_ANOMALY');
    processVoiceSample(
      text: 'LOUD NOISE IMPACT',
      voiceIntensity: 0.98,
      pitchVariance: 0.90,
      journeyId: journeyId ?? _activeJourneyId,
    );
  }

  /// Process voice sample with backend Gemini AI distress model.
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
      DevLog.log('VOICE', 'Backend AI voice distress urgency: ${response.urgency}, score: ${response.distressScore}');
      return response;
    } catch (e) {
      DevLog.log('VOICE', 'Voice analysis dispatch error: $e');
      return null;
    }
  }

  void _startListenCycle() {
    if (!_isListening || !_sttAvailable) return;
    if (_stt.isListening) return;

    try {
      _stt.listen(
        onResult: _onSttResult,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          onDevice: false,
        ),
      );
    } catch (e) {
      DevLog.log('VOICE', 'STT listen start failed: $e');
    }
  }

  void _onSttResult(SpeechRecognitionResult result) {
    final transcript = result.recognizedWords.trim();
    _latestTranscript = transcript;
    _lastEventSource = 'REAL_MIC';
    DevLog.log('VOICE', 'Live Transcript [REAL_MIC]: "$transcript" (final=${result.finalResult})');

    if (transcript.isNotEmpty) {
      _analyzeTranscript(transcript);
    }

    if (result.finalResult) {
      _listenCycleTimer?.cancel();
      _listenCycleTimer = Timer(const Duration(milliseconds: 800), () {
        if (_isListening) _startListenCycle();
      });
    }
  }

  Future<void> _analyzeTranscript(String transcript) async {
    final lower = transcript.toLowerCase();
    final matched = <String>[];
    for (final kw in triggerPhrases) {
      if (lower.contains(kw)) {
        matched.add(kw);
      }
    }
    _matchedKeywords = matched;

    if (matched.isNotEmpty) {
      _confidence = 0.95;
      _latestUrgency = 'HIGH';
      DevLog.log('VOICE', 'MATCHED EMERGENCY TRIGGER PHRASE [REAL_MIC]: "$matched" in "$transcript"');
      _emergencyTriggerController.add(transcript);
    }

    try {
      final intensity = _estimateIntensityProxy(transcript);
      final result = await processVoiceSample(
        text: transcript,
        voiceIntensity: intensity,
        journeyId: _activeJourneyId,
      );
      if (result != null) {
        _latestUrgency = result.urgency.toUpperCase();
        _confidence = result.modelConfidence;
        if (result.urgency.toLowerCase() == 'high' || result.urgency.toLowerCase() == 'critical') {
          _emergencyTriggerController.add(transcript);
        }
      }
    } catch (_) {}
  }

  double _estimateIntensityProxy(String text) {
    int capsWords = text.split(' ').where((w) => w == w.toUpperCase() && w.length > 2).length;
    bool hasExclamation = text.contains('!') || text.contains('?');
    double base = 0.35;
    if (capsWords > 1) base += 0.15;
    if (hasExclamation) base += 0.10;
    return base.clamp(0.0, 1.0);
  }

  void _onSttError(SpeechRecognitionError error) {
    DevLog.log('VOICE', 'STT Error: ${error.errorMsg} (permanent=${error.permanent})');
    if (error.permanent) {
      _isListening = false;
    } else if (_isListening) {
      _listenCycleTimer?.cancel();
      _listenCycleTimer = Timer(const Duration(seconds: 2), () {
        if (_isListening) _startListenCycle();
      });
    }
  }

  void _onSttStatus(String status) {
    DevLog.log('VOICE', 'STT status: $status');
    if (status == 'done' && _isListening) {
      _listenCycleTimer?.cancel();
      _listenCycleTimer = Timer(const Duration(milliseconds: 500), () {
        if (_isListening) _startListenCycle();
      });
    }
  }
}
