import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../domain/entities/entities.dart';

class SafetyZoneDetailSheet extends StatelessWidget {
  const SafetyZoneDetailSheet({
    super.key,
    required this.zone,
    required this.onClose,
  });

  final SafetyZoneEntity zone;
  final VoidCallback onClose;

  Color get _riskColor {
    if (zone.demoSafetyScore >= 70) return AppColors.success;
    if (zone.demoSafetyScore >= 45) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: AppRadius.borderFull,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _riskColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(AppIcons.shield, color: _riskColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(zone.place, style: AppTextStyles.headlineMd),
                    Text(
                      'Anchor: ${zone.anchorArea} • ${zone.category}',
                      style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Text('Demo Safety Score', style: AppTextStyles.labelSm),
                      const SizedBox(height: 4),
                      Text(
                        '${zone.demoSafetyScore}/100',
                        style: AppTextStyles.headlineMd.copyWith(color: _riskColor),
                      ),
                      Text(zone.riskCategoryLabel, style: AppTextStyles.labelSm.copyWith(color: _riskColor)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Text('Day / Night Risk', style: AppTextStyles.labelSm),
                      const SizedBox(height: 4),
                      Text(
                        '${zone.dayRiskScore} / ${zone.nightRiskScore}',
                        style: AppTextStyles.headlineMd.copyWith(color: AppColors.primaryPulse),
                      ),
                      Text('Risk Scores', style: AppTextStyles.labelSm),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Environmental Factors', style: AppTextStyles.labelLg.copyWith(color: AppColors.primaryPulse)),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _FactorPill(label: 'Footfall', value: zone.footfall),
                    _FactorPill(label: 'Lighting', value: zone.lighting),
                    _FactorPill(label: 'Night Activity', value: zone.nightActivity),
                    _FactorPill(label: 'Isolation', value: zone.isolation),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppColors.primaryPulse, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Safety Recommendation', style: AppTextStyles.labelSm.copyWith(color: AppColors.primaryPulse)),
                      const SizedBox(height: 2),
                      Text(zone.recommendation, style: AppTextStyles.bodyMd),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppRadius.borderMd,
              border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 16, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    zone.disclaimer,
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FactorPill extends StatelessWidget {
  const _FactorPill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.labelSm.copyWith(fontSize: 11)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerHighest,
            borderRadius: AppRadius.borderSm,
          ),
          child: Text(
            value,
            style: AppTextStyles.labelSm.copyWith(
              fontWeight: FontWeight.w700,
              color: value.contains('High') || value == 'Very High'
                  ? (label == 'Isolation' ? AppColors.error : AppColors.success)
                  : AppColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
