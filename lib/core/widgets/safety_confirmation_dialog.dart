import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/dev_log.dart';
import '../../providers/repository_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

import '../config/app_router.dart';
import 'app_button.dart';
import 'glass_card.dart';
import 'sos_dialog.dart';

bool _isSafetyModalOpen = false;

/// Shows an urgent 30-second safety verification prompt.
///
/// Triggered by:
/// - Voice distress / emergency keyword triggers
/// - Sensor anomalies (violent shake, severe drop/fall)
/// - Route deviation (moving off-course from planned safe route)
/// - High multi-signal fused risk
///
/// If the user taps "SEND SOS" or the 30-second timer expires without user confirmation,
/// it commits the event's risk contribution and only triggers SOS if the risk threshold is reached.
Future<void> showSafetyConfirmationDialog({
  BuildContext? context,
  WidgetRef? ref,
  String title = 'Potential emergency detected',
  String subtitle = 'Do you need help?',
  required String triggerSource,
  int? riskScore,
  List<String>? signals,
  VoidCallback? onSafeConfirmed,
  VoidCallback? onCountdownExpired,
  VoidCallback? onSendSos,
}) {
  if (_isSafetyModalOpen) return Future.value();
  final targetContext = context ?? rootNavigatorKey.currentContext;
  if (targetContext == null) return Future.value();
  _isSafetyModalOpen = true;

  return showModalBottomSheet(
    context: targetContext,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SafetyConfirmationSheet(
      ref: ref,
      title: title,
      subtitle: subtitle,
      triggerSource: triggerSource,
      riskScore: riskScore,
      signals: signals,
      onSafeConfirmed: onSafeConfirmed,
      onCountdownExpired: onCountdownExpired,
      onSendSos: onSendSos,
    ),
  ).whenComplete(() {
    _isSafetyModalOpen = false;
  });
}

class _SafetyConfirmationSheet extends StatefulWidget {
  const _SafetyConfirmationSheet({
    this.ref,
    required this.title,
    required this.subtitle,
    required this.triggerSource,
    this.riskScore,
    this.signals,
    this.onSafeConfirmed,
    this.onCountdownExpired,
    this.onSendSos,
  });

  final WidgetRef? ref;
  final String title;
  final String subtitle;
  final String triggerSource;
  final int? riskScore;
  final List<String>? signals;
  final VoidCallback? onSafeConfirmed;
  final VoidCallback? onCountdownExpired;
  final VoidCallback? onSendSos;

  @override
  State<_SafetyConfirmationSheet> createState() => _SafetyConfirmationSheetState();
}

class _SafetyConfirmationSheetState extends State<_SafetyConfirmationSheet> {
  int _secondsRemaining = 30;
  static const int _totalSeconds = 30;
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
    DevLog.log('CONFIRMATION', '[SAFETY] user marked safe (source: ${widget.triggerSource})');

    // Resume voice listening if Guardian Mode is active
    if (widget.ref != null) {
      final voiceService = widget.ref!.read(voiceServiceProvider);
      if (voiceService.isMonitoring) {
        voiceService.resumeListening();
      }

      // Record user false alarm cancellation and adjust ML sensitivity
      final falseAlarmManager = widget.ref!.read(falseAlarmManagerProvider);
      await falseAlarmManager.recordCancellation(
        triggerSource: widget.triggerSource,
      );

      // Apply calibrated multiplier to FallDetector if active
      final sensorService = widget.ref!.read(sensorServiceProvider);
      sensorService.fallDetector.sensitivityMultiplier = falseAlarmManager.fallSensitivityMultiplier;
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification cancelled. Resuming normal Guardian monitoring.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
    }

    if (widget.onSafeConfirmed != null) {
      widget.onSafeConfirmed!();
    }
  }

  void _triggerEmergencySos() {
    if (_isEscalated) return;
    _isEscalated = true;
    _timer?.cancel();
    DevLog.log('CONFIRMATION', '[SAFETY] SOS requested by user (source: ${widget.triggerSource})');

    if (mounted) {
      Navigator.of(context).pop();
    }

    if (widget.onSendSos != null) {
      widget.onSendSos!();
    } else {
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
    DevLog.log('CONFIRMATION', '[SAFETY] countdown expired without response (source: ${widget.triggerSource})');

    if (mounted) {
      Navigator.of(context).pop();
    }

    if (widget.onCountdownExpired != null) {
      widget.onCountdownExpired!();
    } else {
      if (widget.ref != null) {
        final sosEngine = widget.ref!.read(sosEscalationEngineProvider);
        sosEngine.evaluateSignals(unansweredCriticalPrompt: true);
      }
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
    final progress = _secondsRemaining / _totalSeconds.toDouble();
    final isCritical = widget.title.contains('DISTRESS') ||
        widget.title.contains('FALL') ||
        (widget.riskScore != null && widget.riskScore! >= 80);
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

            // Title
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

            // Risk Score Badge (if available)
            if (widget.riskScore != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: AppRadius.borderFull,
                ),
                child: Text(
                  'Risk score: ${widget.riskScore}/100',
                  style: AppTextStyles.labelSm.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],

            // Contributing Signals (if available)
            if (widget.signals != null && widget.signals!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: AppRadius.borderSm,
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Signals:',
                      style: AppTextStyles.labelSm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...widget.signals!.map(
                      (s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: AppColors.primaryPulse, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                s,
                                style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Text(
              widget.subtitle,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Live 30-second Countdown Ring
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
                      _secondsRemaining <= 10 ? AppColors.error : accentColor,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_secondsRemaining',
                      style: AppTextStyles.headlineLg.copyWith(
                        color: _secondsRemaining <= 10 ? AppColors.error : AppColors.onSurface,
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
              'Automatic SOS in: $_secondsRemaining seconds',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Action Buttons: I'M SAFE / GET HELP
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
                    variant: AppButtonVariant.primary,
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
