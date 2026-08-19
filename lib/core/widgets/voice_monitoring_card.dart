import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import '../theme/app_colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'glass_card.dart';

enum VoiceMonitoringDisplayState {
  off,
  starting,
  listening,
  processing,
  permissionRequired,
  error,
}

class VoiceMonitoringCard extends ConsumerStatefulWidget {
  const VoiceMonitoringCard({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  ConsumerState<VoiceMonitoringCard> createState() => _VoiceMonitoringCardState();
}

class _VoiceMonitoringCardState extends ConsumerState<VoiceMonitoringCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  VoiceMonitoringDisplayState _resolveState(
    bool hasPermission,
    bool isListening,
    bool isSttAvailable,
    String latestTranscript,
  ) {
    if (!hasPermission) return VoiceMonitoringDisplayState.permissionRequired;
    if (isListening) {
      if (latestTranscript.isNotEmpty) {
        return VoiceMonitoringDisplayState.processing;
      }
      return VoiceMonitoringDisplayState.listening;
    }
    if (isSttAvailable) return VoiceMonitoringDisplayState.starting;
    return VoiceMonitoringDisplayState.off;
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(guardianEngineProvider);
    final voiceService = engine.voiceService;

    final displayState = _resolveState(
      voiceService.hasMicPermission,
      voiceService.isListening,
      voiceService.isSttAvailable,
      voiceService.latestTranscript,
    );

    final isActuallyListening = displayState == VoiceMonitoringDisplayState.listening ||
        displayState == VoiceMonitoringDisplayState.processing;

    if (isActuallyListening) {
      if (!_waveController.isAnimating) {
        _waveController.repeat();
      }
    } else {
      if (_waveController.isAnimating) {
        _waveController.stop();
        _waveController.reset();
      }
    }

    Color stateColor;
    String statusTitle;
    String statusSubtitle;
    IconData iconData;

    switch (displayState) {
      case VoiceMonitoringDisplayState.listening:
        stateColor = const Color(0xFF00E676); // Neon safety green
        statusTitle = 'LISTENING...';
        statusSubtitle = 'Monitoring surroundings for distress keywords';
        iconData = Icons.mic;
        break;
      case VoiceMonitoringDisplayState.processing:
        stateColor = AppColors.primaryPulse;
        statusTitle = 'PROCESSING VOICE...';
        statusSubtitle = '"${voiceService.latestTranscript}"';
        iconData = Icons.graphic_eq;
        break;
      case VoiceMonitoringDisplayState.starting:
        stateColor = const Color(0xFFFFD600);
        statusTitle = 'STARTING...';
        statusSubtitle = 'Starting voice monitoring engine...';
        iconData = Icons.mic_none;
        break;
      case VoiceMonitoringDisplayState.permissionRequired:
        stateColor = AppColors.warning;
        statusTitle = 'PERMISSION REQUIRED';
        statusSubtitle = 'Microphone permission required for distress recognition';
        iconData = Icons.mic_off;
        break;
      case VoiceMonitoringDisplayState.error:
        stateColor = AppColors.error;
        statusTitle = 'VOICE MONITORING ERROR';
        statusSubtitle = 'Speech recognition unavailable on this device';
        iconData = Icons.error_outline;
        break;
      case VoiceMonitoringDisplayState.off:
        stateColor = AppColors.onSurfaceVariant;
        statusTitle = 'VOICE MONITORING OFF';
        statusSubtitle = 'Activate Guardian Mode to begin listening';
        iconData = Icons.mic_off_outlined;
        break;
    }

    if (widget.compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: stateColor.withValues(alpha: 0.12),
          borderRadius: AppRadius.borderFull,
          border: Border.all(color: stateColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, size: 16, color: stateColor),
            const SizedBox(width: 6),
            Text(
              statusTitle,
              style: AppTextStyles.labelSm.copyWith(
                color: stateColor,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      borderColor: isActuallyListening
          ? stateColor.withValues(alpha: 0.6)
          : AppColors.glassBorder,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, size: 16, color: stateColor),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'VOICE MONITORING',
                style: AppTextStyles.labelSm.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontSize: 11,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: stateColor,
                  boxShadow: isActuallyListening
                      ? [
                          BoxShadow(
                            color: stateColor.withValues(alpha: 0.8),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                displayState.name.toUpperCase(),
                style: AppTextStyles.labelSm.copyWith(
                  color: stateColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Central Waveform / Visualizer Animation
          Center(
            child: isActuallyListening
                ? AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      return SizedBox(
                        height: 36,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(14, (index) {
                            final shift = (index / 14) * 2 * math.pi;
                            final value = math.sin(_waveController.value * 2 * math.pi + shift).abs();
                            final barHeight = 8.0 + value * 24.0;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: 3.5,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: stateColor.withValues(alpha: 0.4 + (value * 0.6)),
                                borderRadius: AppRadius.borderFull,
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  )
                : Container(
                    height: 28,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(14, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 3.5,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.25),
                            borderRadius: AppRadius.borderFull,
                          ),
                        );
                      }),
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Status & Action
          Center(
            child: Column(
              children: [
                Text(
                  statusTitle,
                  style: AppTextStyles.labelSm.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: stateColor,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusSubtitle,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Action Button for Permission or Retry
          if (displayState == VoiceMonitoringDisplayState.permissionRequired) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.black,
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.mic, size: 16),
                label: const Text('ENABLE MICROPHONE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                onPressed: () async {
                  await voiceService.requestPermission();
                  if (mounted) setState(() {});
                },
              ),
            ),
          ] else if (displayState == VoiceMonitoringDisplayState.error) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPulse,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('RETRY VOICE ENGINE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                onPressed: () async {
                  await voiceService.startListening();
                  if (mounted) setState(() {});
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
