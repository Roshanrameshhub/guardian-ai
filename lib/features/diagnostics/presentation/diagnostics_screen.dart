import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/api_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/sensor_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/sos_dialog.dart';
import '../../../domain/entities/entities.dart';
import '../../../providers/repository_providers.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  String? _apiHealthStatus = 'Checking...';
  bool _isCheckingApi = false;
  String? _hasJwtToken;
  StreamSubscription<SensorReading>? _sensorSub;
  SensorReading? _liveReading;

  @override
  void initState() {
    super.initState();
    _checkBackendHealth();
    _checkJwt();
    _subscribeLiveSensors();
  }

  void _subscribeLiveSensors() {
    final engine = ref.read(guardianEngineProvider);
    final sensorService = engine.sensorService;
    // Auto-start monitor on diagnostics screen to verify hardware stream
    sensorService.startMonitoring();
    _sensorSub = sensorService.readingStream.listen((reading) {
      if (mounted) {
        setState(() => _liveReading = reading);
      }
    });
  }

  Future<void> _checkJwt() async {
    final tokenStorage = ref.read(tokenStorageServiceProvider);
    final token = await tokenStorage.getAccessToken();
    if (mounted) {
      setState(() {
        _hasJwtToken = token != null && token.isNotEmpty ? 'Present (${token.substring(0, token.length > 10 ? 10 : token.length)}...)' : 'None';
      });
    }
  }

  Future<void> _checkBackendHealth() async {
    setState(() => _isCheckingApi = true);
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('/health');
      if (mounted) {
        setState(() {
          _apiHealthStatus = res['status'] == 'healthy' || res['status'] == 'ok'
              ? '✓ Connected (${ApiConfig.baseUrl})'
              : 'Status: ${res['status']}';
          _isCheckingApi = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _apiHealthStatus = '✕ Unreachable: $e';
          _isCheckingApi = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(guardianEngineProvider);
    final sensorService = engine.sensorService;
    final voiceService = engine.voiceService;

    final accelX = _liveReading?.accelX ?? sensorService.latestAccelX;
    final accelY = _liveReading?.accelY ?? sensorService.latestAccelY;
    final accelZ = _liveReading?.accelZ ?? sensorService.latestAccelZ;
    final accelMag = _liveReading?.accelMagnitude ?? sensorService.liveAccelMagnitude;

    final gyroX = _liveReading?.gyroX ?? sensorService.latestGyroX;
    final gyroY = _liveReading?.gyroY ?? sensorService.latestGyroY;
    final gyroZ = _liveReading?.gyroZ ?? sensorService.latestGyroZ;
    final gyroMag = _liveReading?.gyroMagnitude ?? sensorService.liveGyroMagnitude;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'GUARDIAN SYSTEM DIAGNOSTICS',
          style: AppTextStyles.labelSm.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            fontSize: 13,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryPulse),
            tooltip: 'Refresh Status',
            onPressed: () {
              _checkBackendHealth();
              _checkJwt();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── 1. REAL HARDWARE LIVE SENSOR TELEMETRY ──────────────────────
            const _SectionHeader(title: 'LIVE HARDWARE SENSOR TELEMETRY', icon: Icons.sensors),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SensorMetricBox(
                          label: 'ACCELEROMETER',
                          x: accelX,
                          y: accelY,
                          z: accelZ,
                          magnitude: accelMag,
                          unit: 'm/s²',
                          isAvailable: sensorService.isAccelAvailable,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SensorMetricBox(
                          label: 'GYROSCOPE',
                          x: gyroX,
                          y: gyroY,
                          z: gyroZ,
                          magnitude: gyroMag,
                          unit: 'rad/s',
                          isAvailable: sensorService.isGyroAvailable,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _StatusRow(
                    label: 'Kinematic Speed',
                    value: '${engine.currentSpeedKmh.toStringAsFixed(1)} km/h',
                    isOk: true,
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _StatusRow(
                    label: 'Battery Telemetry',
                    value: '${engine.batteryPercent}%',
                    isOk: engine.batteryPercent > 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ─── 2. LOCATION & GPS ────────────────────────────────────────────
            const _SectionHeader(title: 'LOCATION & GPS SUBSYSTEM', icon: AppIcons.location),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              child: Column(
                children: [
                  _StatusRow(
                    label: 'GPS Satellite Fix',
                    value: engine.currentPosition != null ? '✓ Active Lock' : 'Acquiring Satellites...',
                    isOk: engine.currentPosition != null,
                  ),
                  if (engine.currentPosition != null) ...[
                    const Divider(color: AppColors.glassBorder),
                    _StatusRow(
                      label: 'Coordinates',
                      value: '${engine.currentPosition!.latitude.toStringAsFixed(5)}, ${engine.currentPosition!.longitude.toStringAsFixed(5)}',
                      isOk: true,
                    ),
                    const Divider(color: AppColors.glassBorder),
                    _StatusRow(
                      label: 'Accuracy',
                      value: '±${engine.currentPosition!.accuracy.toStringAsFixed(1)}m High',
                      isOk: engine.currentPosition!.accuracy < 30,
                    ),
                    const Divider(color: AppColors.glassBorder),
                    _StatusRow(
                      label: 'Altitude / Heading',
                      value: '${engine.currentPosition!.altitude.toStringAsFixed(1)}m / ${engine.currentPosition!.heading.toStringAsFixed(0)}°',
                      isOk: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ─── 3. VOICE & MICROPHONE ────────────────────────────────────────
            const _SectionHeader(title: 'VOICE & DISTRESS SUBSYSTEM', icon: AppIcons.mic),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusRow(
                    label: 'Microphone Permission',
                    value: voiceService.hasMicPermission ? 'GRANTED' : 'DENIED / PERMISSION_REQUIRED',
                    isOk: voiceService.hasMicPermission,
                  ),
                  if (!voiceService.hasMicPermission) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPulse,
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
                        ),
                        icon: const Icon(Icons.mic, size: 16),
                        label: const Text('GRANT MICROPHONE PERMISSION'),
                        onPressed: () async {
                          await voiceService.requestPermission();
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                  const Divider(color: AppColors.glassBorder),
                  _StatusRow(
                    label: 'Speech-to-Text Engine',
                    value: voiceService.isSttAvailable ? 'TRUE (Initialized)' : 'FALSE (Unavailable)',
                    isOk: voiceService.isSttAvailable,
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _StatusRow(
                    label: 'Distress Listener State',
                    value: voiceService.isListening ? 'LISTENING (Active)' : 'IDLE (Guardian Standby)',
                    isOk: voiceService.isListening,
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _StatusRow(
                    label: 'Last Transcript',
                    value: voiceService.latestTranscript.isNotEmpty
                        ? '"${voiceService.latestTranscript}"'
                        : 'None yet',
                    isOk: true,
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _StatusRow(
                    label: 'Matched Keywords',
                    value: voiceService.matchedKeywords.isNotEmpty
                        ? '[${voiceService.matchedKeywords.join(', ')}]'
                        : '[]',
                    isOk: true,
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _StatusRow(
                    label: 'Distress Confidence',
                    value: '${(voiceService.confidence * 100).toStringAsFixed(0)}%',
                    isOk: true,
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _StatusRow(
                    label: 'Last Event Source',
                    value: voiceService.lastEventSource == 'REAL_MIC'
                        ? 'Real Phone Microphone'
                        : (voiceService.lastEventSource == 'TEST_SIMULATOR'
                            ? 'Test Simulator'
                            : 'None'),
                    isOk: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ─── 4. BACKEND & NETWORK TELEMETRY ──────────────────────────────
            const _SectionHeader(title: 'BACKEND & ENVIRONMENT CONFIGURATION', icon: AppIcons.activity),
            const SizedBox(height: AppSpacing.sm),
            GlassCard(
              child: Column(
                children: [
                  const _StatusRow(
                    label: 'App Version',
                    value: AppConstants.appVersion,
                    isOk: true,
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _StatusRow(
                    label: 'API Base URL',
                    value: ApiConfig.baseUrl,
                    isOk: true,
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _StatusRow(
                    label: 'Host',
                    value: ApiConfig.configuredHost.isNotEmpty ? ApiConfig.configuredHost : 'Default',
                    isOk: true,
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _StatusRow(
                    label: 'Port',
                    value: ApiConfig.configuredPort,
                    isOk: true,
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _StatusRow(
                    label: 'Scheme',
                    value: ApiConfig.configuredScheme,
                    isOk: true,
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _StatusRow(
                    label: 'API Prefix',
                    value: ApiConfig.configuredPrefix,
                    isOk: true,
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _StatusRow(
                    label: 'URL Resolution',
                    value: ApiConfig.resolutionSource,
                    isOk: true,
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _StatusRow(
                    label: 'Health Check (/health)',
                    value: _isCheckingApi ? 'Pinging...' : _apiHealthStatus ?? 'Unknown',
                    isOk: _apiHealthStatus?.contains('Connected') == true,
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _StatusRow(
                    label: 'JWT Session State',
                    value: _hasJwtToken ?? 'Checking...',
                    isOk: _hasJwtToken != 'None',
                  ),
                  const Divider(color: AppColors.glassBorder),
                  const _StatusRow(
                    label: 'Google OAuth Package',
                    value: 'com.guardianai.guardian_ai',
                    isOk: true,
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _StatusRow(
                    label: 'Last API Endpoint',
                    value: ApiClient.lastEndpoint ?? 'None yet',
                    isOk: true,
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _StatusRow(
                    label: 'Last HTTP Status',
                    value: ApiClient.lastStatusCode != null ? '${ApiClient.lastStatusCode}' : 'N/A',
                    isOk: ApiClient.lastStatusCode == null || (ApiClient.lastStatusCode! >= 200 && ApiClient.lastStatusCode! < 400),
                  ),
                  if (ApiClient.lastErrorCategory != null) ...[
                    const Divider(color: AppColors.glassBorder),
                    _StatusRow(
                      label: 'Last Error Category',
                      value: ApiClient.lastErrorCategory!.name.toUpperCase(),
                      isOk: false,
                    ),
                  ],
                  if (ApiClient.lastError != null) ...[
                    const Divider(color: AppColors.glassBorder),
                    _StatusRow(
                      label: 'Last Error',
                      value: ApiClient.lastError!,
                      isOk: false,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ─── 5. HARDWARE & PIPELINE TEST CONTROLS ────────────────────────
            const _SectionHeader(title: 'HARDWARE & PIPELINE TEST WORKBENCH', icon: Icons.science_outlined),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Test Simulator (does not use real microphone)\nInject synthetic hardware anomaly events to verify emergency pipelines without physical risk.',
              style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TestButton(
                  label: 'TEST SHAKE PIPELINE',
                  icon: Icons.vibration,
                  color: AppColors.warning,
                  onPressed: () {
                    sensorService.simulateShake();
                    engine.logEvent(
                      type: SafetyEventType.shakeDetected,
                      severity: SafetyEventSeverity.warning,
                      title: 'Real Shake Pipeline Injected',
                      message: 'Processed through 3-axis SensorService anomaly pipeline.',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Shake event dispatched through production pipeline')),
                    );
                  },
                ),
                _TestButton(
                  label: 'TEST PHONE DROP / FALL',
                  icon: Icons.arrow_downward,
                  color: AppColors.error,
                  onPressed: () {
                    sensorService.simulatePhoneDrop();
                    engine.logEvent(
                      type: SafetyEventType.phoneDrop,
                      severity: SafetyEventSeverity.critical,
                      title: 'Real Phone Drop Injected',
                      message: 'High acceleration peak (>24 m/s²) dispatched to AI layer.',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Drop anomaly dispatched to AI layer')),
                    );
                  },
                ),
                _TestButton(
                  label: 'TEST VOICE "HELP" TRIGGER',
                  icon: Icons.record_voice_over,
                  color: AppColors.error,
                  onPressed: () {
                    voiceService.simulateVoiceTrigger('HELP ME EMERGENCY');
                    engine.logEvent(
                      type: SafetyEventType.loudNoiseDetected,
                      severity: SafetyEventSeverity.critical,
                      title: 'Voice Distress Triggered',
                      message: 'Triggered "HELP ME EMERGENCY" against Gemini distress model.',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Voice distress analysis requested from backend')),
                    );
                  },
                ),
                _TestButton(
                  label: 'TEST GPS REFRESH',
                  icon: Icons.my_location,
                  color: AppColors.primaryPulse,
                  onPressed: () async {
                    try {
                      final pos = await ref.read(locationServiceProvider).getCurrentPosition();
                      engine.logEvent(
                        type: SafetyEventType.gpsRestored,
                        severity: SafetyEventSeverity.info,
                        title: 'GPS Lock Verified',
                        message: '±${pos.accuracy.toStringAsFixed(0)}m (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})',
                      );
                      setState(() {});
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('GPS Lock: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('GPS error: $e')),
                        );
                      }
                    }
                  },
                ),
                _TestButton(
                  label: 'TEST EMERGENCY SOS',
                  icon: AppIcons.sos,
                  color: AppColors.error,
                  onPressed: () {
                    showEmergencySosModal(
                      context: context,
                      ref: ref,
                      triggerSource: 'diagnostics_test',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ─── 6. REAL-TIME SAFETY AUDIT LOG ────────────────────────────────
            _SectionHeader(title: 'REAL-TIME SAFETY AUDIT LOG (${engine.events.length})', icon: Icons.history),
            const SizedBox(height: AppSpacing.sm),
            if (engine.events.isEmpty) ...[
              GlassCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'No safety events recorded yet. Start Guardian Mode or run a test from the workbench above.',
                      style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ] else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: engine.events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, idx) {
                  final event = engine.events[engine.events.length - 1 - idx];
                  final isWarning = event.severity == SafetyEventSeverity.warning ||
                      event.severity == SafetyEventSeverity.critical;
                  final color = isWarning ? AppColors.warning : AppColors.success;

                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest,
                      borderRadius: AppRadius.borderSm,
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(isWarning ? Icons.warning_amber_rounded : Icons.check_circle, color: color, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          event.timeFormatted,
                          style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event.title, style: AppTextStyles.labelSm.copyWith(color: color, fontWeight: FontWeight.w700)),
                              if (event.message.isNotEmpty)
                                Text(event.message, style: AppTextStyles.bodySm.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryPulse),
        const SizedBox(width: 6),
        Text(
          title,
          style: AppTextStyles.labelSm.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            fontSize: 11,
            color: AppColors.primaryPulse,
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value, required this.isOk});
  final String label;
  final String value;
  final bool isOk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.labelSm.copyWith(
                fontWeight: FontWeight.w700,
                color: isOk ? AppColors.onSurface : AppColors.warning,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorMetricBox extends StatelessWidget {
  const _SensorMetricBox({
    required this.label,
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.unit,
    required this.isAvailable,
  });

  final String label;
  final double x;
  final double y;
  final double z;
  final double magnitude;
  final String unit;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.8),
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: AppTextStyles.labelSm.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryPulse,
                ),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isAvailable ? const Color(0xFF00E676) : AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Mag: ${magnitude.toStringAsFixed(2)} $unit',
            style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'X: ${x.toStringAsFixed(2)}\nY: ${y.toStringAsFixed(2)}\nZ: ${z.toStringAsFixed(2)}',
            style: AppTextStyles.labelSm.copyWith(
              fontSize: 11,
              fontFamily: 'monospace',
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TestButton extends StatelessWidget {
  const _TestButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      icon: Icon(icon, size: 14),
      label: Text(label, style: AppTextStyles.labelSm.copyWith(fontSize: 10, fontWeight: FontWeight.w800)),
      onPressed: onPressed,
    );
  }
}
