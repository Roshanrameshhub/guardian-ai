import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_paths.dart';
import '../../../core/services/guardian_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/guardian_system_status.dart';
import '../../../core/widgets/sos_dialog.dart';
import '../../../core/widgets/voice_monitoring_card.dart';
import '../../../domain/entities/entities.dart';
import '../../../providers/repository_providers.dart';
import 'guardian_controller.dart';
import 'guardian_map_controller.dart';
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
  @override
  void initState() {
    super.initState();
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
    final engine = ref.watch(guardianEngineProvider);
    final riskReport = ref.watch(guardianRiskReportProvider);
    final mapState = ref.watch(guardianMapControllerProvider);
    final isGuardianActive = ref.watch(guardianActiveStateProvider);

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
              // 1. Protection Hero Shield
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

              // 2. Global System Status Cards (Gyroscope, Voice, Route Watchdog, Risk Engine, etc.)
              const GuardianSystemStatus(isCompact: false),
              const SizedBox(height: AppSpacing.lg),

              // 3. Overall Risk Level & Dynamic Contributing Signals
              RiskBreakdownCard(report: riskReport),
              const SizedBox(height: AppSpacing.lg),

              // 4. Voice Monitoring Card (Listening / Paused)
              const VoiceMonitoringCard(),
              const SizedBox(height: AppSpacing.lg),

              // 5. Route Watchdog & Route Safety
              _RouteWatchdogCard(
                engine: engine,
                routePlan: mapState.routePlan,
                onPlanRoute: () => context.go(RoutePaths.map),
              ),
              const SizedBox(height: AppSpacing.xl),

              // 6. Emergency SOS Action Button
              AppButton(
                label: 'EMERGENCY SOS ALERT',
                icon: AppIcons.sos,
                variant: AppButtonVariant.primary,
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

class _RouteWatchdogCard extends StatelessWidget {
  const _RouteWatchdogCard({
    required this.engine,
    this.routePlan,
    required this.onPlanRoute,
  });

  final GuardianEngine engine;
  final GuardianRoutePlanEntity? routePlan;
  final VoidCallback onPlanRoute;

  @override
  Widget build(BuildContext context) {
    final hasRoute = routePlan != null || engine.deviationDetector.plannedRoutePoints.isNotEmpty;
    final isDeviated = engine.deviationDetector.hasActiveCandidate;
    final devDist = engine.deviationDetector.lastDistanceMeters;
    final safetyScore = routePlan?.safetyScore ?? 91;

    String safetyRating;
    Color safetyColor;
    if (safetyScore >= 80) {
      safetyRating = 'SAFE';
      safetyColor = AppColors.success;
    } else if (safetyScore >= 50) {
      safetyRating = 'MODERATE RISK';
      safetyColor = AppColors.warning;
    } else {
      safetyRating = 'HIGH RISK';
      safetyColor = AppColors.error;
    }

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (hasRoute ? AppColors.tertiary : AppColors.outline).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.alt_route,
                  color: hasRoute ? AppColors.tertiary : AppColors.outline,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ROUTE WATCHDOG',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      hasRoute ? 'ACTIVE CORRIDOR MONITOR' : 'NO ACTIVE ROUTE',
                      style: AppTextStyles.bodyMd.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hasRoute ? AppColors.onSurface : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (hasRoute ? AppColors.tertiary : AppColors.surfaceContainerHigh).withValues(alpha: 0.15),
                  borderRadius: AppRadius.borderFull,
                ),
                child: Text(
                  hasRoute ? 'ACTIVE' : 'STANDBY',
                  style: AppTextStyles.labelSm.copyWith(
                    color: hasRoute ? AppColors.tertiary : AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (hasRoute) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppRadius.borderSm,
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Route Safety:',
                        style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: safetyColor.withValues(alpha: 0.15),
                          borderRadius: AppRadius.borderSm,
                        ),
                        child: Text(
                          '$safetyScore/100 • $safetyRating',
                          style: AppTextStyles.labelSm.copyWith(
                            color: safetyColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (routePlan != null)
                    Text(
                      'Destination: ${routePlan!.destinationName}',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isDeviated ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                        size: 14,
                        color: isDeviated ? AppColors.warning : AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          isDeviated
                              ? 'Route deviation detected (+${devDist.toStringAsFixed(0)}m off corridor)'
                              : 'Following safe corridor (${engine.deviationDetector.plannedRoutePoints.length} checkpoints)',
                          style: AppTextStyles.labelSm.copyWith(
                            color: isDeviated ? AppColors.warning : AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Prototype safety score — Does not represent official crime statistics or guarantee safety.',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else ...[
            Text(
              'No route currently planned. Plan a route on the map to activate automatic corridor deviation detection and safe route monitoring.',
              style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(AppIcons.map, size: 16),
                label: const Text('Plan a Safe Route on Map'),
                onPressed: onPlanRoute,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
