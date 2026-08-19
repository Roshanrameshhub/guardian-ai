import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../domain/entities/entities.dart';

class GuardianRouteComparisonCard extends StatelessWidget {
  const GuardianRouteComparisonCard({
    super.key,
    required this.plan,
    required this.selectedIndex,
    required this.onSelectIndex,
    required this.isNavigating,
    required this.navigationProgress,
    required this.onStartNavigation,
    required this.onStopNavigation,
    required this.onClearRoute,
  });

  final GuardianRoutePlanEntity plan;
  final int selectedIndex;
  final ValueChanged<int> onSelectIndex;
  final bool isNavigating;
  final double navigationProgress;
  final VoidCallback onStartNavigation;
  final VoidCallback onStopNavigation;
  final VoidCallback onClearRoute;

  @override
  Widget build(BuildContext context) {
    final active = selectedIndex < plan.alternatives.length
        ? plan.alternatives[selectedIndex]
        : plan.recommendedRoute;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.primaryPulse.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 24,
            spreadRadius: 2,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top grab handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: AppRadius.borderFull,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Destination header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryPulse.withValues(alpha: 0.18),
                  borderRadius: AppRadius.borderMd,
                ),
                child: const Icon(AppIcons.location, color: AppColors.primaryPulse, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.destinationName,
                      style: AppTextStyles.headlineMd.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Condition: ${plan.evaluationPeriod} • Route Safe Engine Active',
                      style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
                onPressed: onClearRoute,
                tooltip: 'Clear Route',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Route Alternatives Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(plan.alternatives.length, (idx) {
                final alt = plan.alternatives[idx];
                final isSelected = selectedIndex == idx;
                final isSafer = alt.role.contains('Safer');
                final isFastest = alt.role.contains('Fastest');

                Color badgeColor = isSafer
                    ? AppColors.primaryPulse
                    : isFastest
                        ? AppColors.warning
                        : AppColors.info;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => onSelectIndex(idx),
                    borderRadius: AppRadius.borderLg,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? badgeColor.withValues(alpha: 0.2)
                            : AppColors.surfaceContainerLowest.withValues(alpha: 0.6),
                        borderRadius: AppRadius.borderLg,
                        border: Border.all(
                          color: isSelected ? badgeColor : AppColors.outlineVariant.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(alt.tag, style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  borderRadius: AppRadius.borderSm,
                                ),
                                child: Text(
                                  'Score ${alt.safetyScore}',
                                  style: AppTextStyles.labelSm.copyWith(
                                    color: AppColors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${alt.durationMinutes} min • ${alt.distanceKm} km',
                            style: AppTextStyles.labelSm.copyWith(
                              color: isSelected ? AppColors.onSurface : AppColors.onSurfaceVariant,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Active route summary & rationale
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest.withValues(alpha: 0.8),
              borderRadius: AppRadius.borderLg,
              border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${active.durationMinutes} min • ${active.distanceKm} km',
                      style: AppTextStyles.headlineMd.copyWith(
                        color: AppColors.primaryPulse,
                        fontSize: 20,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: active.safetyScore >= 75 ? AppColors.success : AppColors.warning,
                        borderRadius: AppRadius.borderFull,
                      ),
                      child: Text(
                        'Safety: ${active.safetyScore}/100',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  active.reason.isNotEmpty ? active.reason : plan.reason,
                  style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Navigation action or progress
          if (isNavigating) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(AppIcons.location, color: AppColors.primaryPulse, size: 18),
                    const SizedBox(width: 6),
                    Text('Active Navigation in Progress', style: AppTextStyles.labelSm.copyWith(color: AppColors.primaryPulse)),
                    const Spacer(),
                    Text('${(navigationProgress * 100).toInt()}%', style: AppTextStyles.labelSm),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: AppRadius.borderFull,
                  child: LinearProgressIndicator(
                    value: navigationProgress,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceContainerHighest,
                    color: AppColors.primaryPulse,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.white,
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderFull),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('STOP NAVIGATION'),
                    onPressed: onStopNavigation,
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPulse,
                  foregroundColor: AppColors.white,
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderFull),
                  elevation: 4,
                ),
                icon: const Icon(AppIcons.location),
                label: Text(
                  'START ${active.role.toUpperCase()}',
                  style: AppTextStyles.labelLg.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                onPressed: onStartNavigation,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),

          // Mandatory Prototype Disclaimer
          Center(
            child: Text(
              plan.disclaimer,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
