import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/guardian_system_status.dart';
import '../../../core/widgets/safety_confirmation_dialog.dart';
import '../../../core/widgets/sos_dialog.dart';
import '../../../core/widgets/voice_monitoring_card.dart';
import '../../../domain/entities/entities.dart';
import '../../../providers/repository_providers.dart';
import 'guardian_controller.dart';
import 'widgets/risk_breakdown_card.dart';

/// SCREEN 7 — GUARDIAN MODE DEDICATED PROTECTION CONTROL
///
/// Answers: "Is Guardian AI protecting my device in the background?"
///
/// Features:
/// 1. Primary Guardian Mode toggle (Start / Stop with confirmation)
/// 2. Live telemetry monitor for all 7 background subsystems
/// 3. Voice distress status & microphone permissions
/// 4. Motion sensor baseline status
/// 5. Plan Safe Walk shortcut (routes to Map)
/// 6. Global Emergency SOS trigger
class GuardianScreen extends ConsumerStatefulWidget {
  const GuardianScreen({super.key});

  @override
  ConsumerState<GuardianScreen> createState() => _GuardianScreenState();
}

class _GuardianScreenState extends ConsumerState<GuardianScreen> {
  StreamSubscription<SafetyEventModel>? _eventSub;
  bool _isAlertOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final engine = ref.read(guardianEngineProvider);
      _eventSub = engine.safetyEventStream.listen((event) {
        if (!mounted || _isAlertOpen) return;
        if (event.severity == SafetyEventSeverity.critical || event.severity == SafetyEventSeverity.warning) {
          _isAlertOpen = true;
          showSafetyConfirmationDialog(
            context: context,
            ref: ref,
            title: event.title,
            subtitle: '${event.message}\nAre you in danger?',
            triggerSource: event.type.name,
            onSafeConfirmed: () {
              _isAlertOpen = false;
            },
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> _handleToggleGuardian(bool currentlyActive) async {
    if (currentlyActive) {
      // Confirm before stopping active protection
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerHigh,
          title: Text(
            'Stop Guardian Protection?',
            style: AppTextStyles.headlineMd.copyWith(fontSize: 18),
          ),
          content: Text(
            'Stopping Guardian Mode will disable real-time motion anomaly, voice distress listening, and heartbeat telemetry.',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep Active'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Stop Protection'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        await ref.read(guardianControllerProvider.notifier).toggle(false);
      }
    } else {
      await ref.read(guardianControllerProvider.notifier).toggle(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(guardianStatusProvider);
    final engine = ref.watch(guardianEngineProvider);
    final riskReport = ref.watch(guardianRiskReportProvider);

    final isGuardianActive = engine.isActive || (statusAsync.value?.isActive ?? false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.shieldFilled, color: AppColors.primaryPulse, size: 20),
              const SizedBox(width: 8),
              Text(
                'GUARDIAN MODE',
                style: AppTextStyles.labelSm.copyWith(
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.analytics_outlined, color: AppColors.primaryPulse),
              tooltip: 'System Diagnostics & Test Controls',
              onPressed: () => context.push(RoutePaths.diagnostics),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Column(
              children: [
                // Big Protection Hero Shield
                Center(
                  child: InkWell(
                    onTap: () => _handleToggleGuardian(isGuardianActive),
                    borderRadius: BorderRadius.circular(100),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isGuardianActive
                            ? AppColors.primaryPulse.withValues(alpha: 0.18)
                            : AppColors.surfaceContainerHigh,
                        border: Border.all(
                          color: isGuardianActive
                              ? AppColors.primaryPulse
                              : AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                          width: 3,
                        ),
                        boxShadow: [
                          if (isGuardianActive)
                            BoxShadow(
                              color: AppColors.primaryPulse.withValues(alpha: 0.4),
                              blurRadius: 36,
                              spreadRadius: 6,
                            ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isGuardianActive ? AppIcons.shieldFilled : AppIcons.shield,
                            color: isGuardianActive ? AppColors.primaryPulse : AppColors.onSurfaceVariant,
                            size: 52,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isGuardianActive ? 'ACTIVE' : 'OFF',
                            style: AppTextStyles.headlineMd.copyWith(
                              color: isGuardianActive ? AppColors.primaryPulse : AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            isGuardianActive ? 'Tap to Stop' : 'Tap to Activate',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9)),

                const SizedBox(height: AppSpacing.lg),
                Text(
                  isGuardianActive
                      ? 'Guardian AI is actively protecting you in background'
                      : 'Activate Guardian Mode for continuous trip protection',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),

                // Reusable Global System Status Card
                const GuardianSystemStatus(isCompact: false),
                const SizedBox(height: AppSpacing.lg),

                // Phase 6 Explainable Multi-Signal Risk Breakdown Card
                RiskBreakdownCard(report: riskReport),
                const SizedBox(height: AppSpacing.lg),

                // Dynamic Vector Voice Monitoring Component with Waveform
                const VoiceMonitoringCard(),
                const SizedBox(height: AppSpacing.lg),

                // Action Buttons
                AppButton(
                  label: 'Plan a Safe Route on Map',
                  icon: AppIcons.map,
                  onPressed: () => context.go(RoutePaths.map),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Emergency SOS Alert',
                  icon: AppIcons.sos,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => showEmergencySosModal(
                    context: context,
                    ref: ref,
                    triggerSource: 'guardian_screen_sos',
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      );
  }
}
