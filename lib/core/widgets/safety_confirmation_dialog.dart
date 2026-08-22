import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/dev_log.dart';
import '../../providers/repository_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

import 'app_button.dart';
import 'glass_card.dart';
import 'sos_dialog.dart';

/// Shows an urgent 20-second safety confirmation prompt.
///
/// Triggered by:
/// - Voice distress / emergency keyword triggers
/// - Sensor anomalies (violent shake, severe drop/fall)
/// - Route deviation (moving off-course from planned safe route)
///
/// If the user taps "I'M IN DANGER" / "SEND SOS" or the 20-second timer expires with no response,
/// it immediately escalates to the official SOS emergency pipeline.
Future<void> showSafetyConfirmationDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String subtitle,
  required String triggerSource,
  VoidCallback? onSafeConfirmed,
}) {
  return showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SafetyConfirmationSheet(
      ref: ref,
      title: title,
      subtitle: subtitle,
      triggerSource: triggerSource,
      onSafeConfirmed: onSafeConfirmed,
    ),
  );
}

class _SafetyConfirmationSheet extends StatefulWidget {
  const _SafetyConfirmationSheet({
    required this.ref,
    required this.title,
    required this.subtitle,
    required this.triggerSource,
    this.onSafeConfirmed,
  });

  final WidgetRef ref;
  final String title;
  final String subtitle;
  final String triggerSource;
  final VoidCallback? onSafeConfirmed;

  @override
  State<_SafetyConfirmationSheet> createState() => _SafetyConfirmationSheetState();
}

class _SafetyConfirmationSheetState extends State<_SafetyConfirmationSheet> {
  int _secondsRemaining = 20;
  Timer? _timer;
  bool _isEscalated = false;

  @override
  void initState() {
    super.initState();
    DevLog.log('CONFIRMATION', '[VOICE] countdown started (source: ${widget.triggerSource})');
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
        _onCountdownExpired();
      }
    });
  }

  Future<void> _onSafe() async {
    _timer?.cancel();
    DevLog.log('CONFIRMATION', '[VOICE] user marked safe');

    // Resume voice listening if Guardian Mode is active
    final voiceService = widget.ref.read(voiceServiceProvider);
    if (voiceService.isMonitoring) {
      voiceService.resumeListening();
    }

    if (widget.onSafeConfirmed != null) {
      widget.onSafeConfirmed!();
    }

    // Record user false alarm cancellation and adjust ML sensitivity
    final falseAlarmManager = widget.ref.read(falseAlarmManagerProvider);
    final result = await falseAlarmManager.recordCancellation(
      triggerSource: widget.triggerSource,
    );

    // Apply calibrated multiplier to FallDetector if active
    final sensorService = widget.ref.read(sensorServiceProvider);
    sensorService.fallDetector.sensitivityMultiplier = falseAlarmManager.fallSensitivityMultiplier;

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _triggerEmergencySos() {
    if (_isEscalated) return;
    _isEscalated = true;
    _timer?.cancel();
    DevLog.log('CONFIRMATION', '[VOICE] SOS requested by user');

    if (mounted) {
      Navigator.of(context).pop();
      showEmergencySosModal(
        context: context,
        ref: widget.ref,
        triggerSource: widget.triggerSource,
      );
    }
  }

  void _onCountdownExpired() {
    if (_isEscalated) return;
    _isEscalated = true;
    _timer?.cancel();
    DevLog.log('CONFIRMATION', '[VOICE] countdown expired without response - escalating to emergency SOS');

    // Pass through SOS escalation engine
    final sosEngine = widget.ref.read(sosEscalationEngineProvider);
    sosEngine.evaluateSignals(unansweredCriticalPrompt: true);

    if (mounted) {
      Navigator.of(context).pop();
      showEmergencySosModal(
        context: context,
        ref: widget.ref,
        triggerSource: '${widget.triggerSource}_countdown_expired',
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _secondsRemaining / 20.0;
    final isCritical = widget.title.contains('DISTRESS') || widget.title.contains('FALL');
    final accentColor = isCritical ? AppColors.error : AppColors.warning;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
      ),
      child: GlassCard(
        borderColor: accentColor.withValues(alpha: 0.8),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Warning Pulse Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.15),
                border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 2),
              ),
              child: Icon(AppIcons.warning, color: accentColor, size: 36),
            ),
            const SizedBox(height: AppSpacing.md),

            // Title & Subtitle
            Text(
              widget.title,
              style: AppTextStyles.headlineMd.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.subtitle,
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Live 20-second Countdown Ring
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _secondsRemaining <= 5 ? AppColors.error : accentColor,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_secondsRemaining',
                      style: AppTextStyles.headlineLg.copyWith(
                        color: _secondsRemaining <= 5 ? AppColors.error : AppColors.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                      ),
                    ),
                    Text(
                      'SEC',
                      style: AppTextStyles.labelSm.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Emergency SOS triggers automatically on zero',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Action Buttons: I'M SAFE / SEND SOS
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: "I'M SAFE",
                    icon: AppIcons.check,
                    variant: AppButtonVariant.secondary,
                    onPressed: _onSafe,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: 'SEND SOS',
                    icon: AppIcons.sos,
                    onPressed: _triggerEmergencySos,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
