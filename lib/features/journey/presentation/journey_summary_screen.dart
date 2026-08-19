import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/glass_card.dart';

class JourneySummaryScreen extends StatelessWidget {
  const JourneySummaryScreen({
    super.key,
    this.destinationName = 'Destination',
    this.durationText = '18:40',
    this.distanceKm = 3.2,
    this.avgSpeedKmh = 4.6,
    this.safetyScore = 94,
    this.incidentCount = 0,
  });

  final String destinationName;
  final String durationText;
  final double distanceKm;
  final double avgSpeedKmh;
  final int safetyScore;
  final int incidentCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Column(
            children: [
              const Spacer(),
              // Success Badge
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.success, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.3),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.check, color: AppColors.success, size: 48),
                ),
              )
                  .animate()
                  .scale(duration: 500.ms, curve: Curves.easeOutBack)
                  .fadeIn(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'SAFE ARRIVAL CONFIRMED',
                style: AppTextStyles.headlineLg.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'You reached $destinationName safely.\nGuardian AI journey protection has concluded.',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Journey Metrics Card
              GlassCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryItem(
                          icon: Icons.timer_outlined,
                          label: 'DURATION',
                          value: durationText,
                        ),
                        Container(width: 1, height: 36, color: AppColors.glassBorder),
                        _SummaryItem(
                          icon: Icons.straighten,
                          label: 'DISTANCE',
                          value: '$distanceKm km',
                        ),
                        Container(width: 1, height: 36, color: AppColors.glassBorder),
                        _SummaryItem(
                          icon: Icons.speed,
                          label: 'AVG SPEED',
                          value: '$avgSpeedKmh km/h',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Divider(color: AppColors.glassBorder),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Icon(AppIcons.shieldFilled, color: AppColors.tertiary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Trip Safety Rating',
                          style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.tertiary.withValues(alpha: 0.15),
                            borderRadius: AppRadius.borderFull,
                          ),
                          child: Text(
                            '$safetyScore / 100',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.tertiary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Icon(
                          incidentCount == 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                          color: incidentCount == 0 ? AppColors.success : AppColors.warning,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          incidentCount == 0
                              ? 'Zero safety anomalies during trip'
                              : '$incidentCount safety confirmation events resolved',
                          style: AppTextStyles.labelSm.copyWith(
                            color: incidentCount == 0 ? AppColors.success : AppColors.warning,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),
              AppButton(
                label: 'View in Activity Timeline',
                icon: AppIcons.activity,
                onPressed: () => context.go(RoutePaths.activity),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Done — Return Home',
                icon: AppIcons.home,
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go(RoutePaths.home),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primaryPulse, size: 18),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.labelSm.copyWith(fontSize: 9)),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.headlineMd.copyWith(fontSize: 15),
        ),
      ],
    );
  }
}
