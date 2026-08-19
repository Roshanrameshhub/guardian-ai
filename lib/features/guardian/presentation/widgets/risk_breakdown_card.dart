import 'package:flutter/material.dart';

import '../../../../core/services/guardian_risk_engine.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/glass_card.dart';

/// Reusable Explainable Risk Breakdown Card for Guardian Mode.
///
/// Displays:
/// - Overall risk percentage & qualitative tier (e.g. 62% MODERATE)
/// - Visual progress indicator
/// - Itemized list of exact contributing factors and percentages
/// - Dynamic safety recommendation
class RiskBreakdownCard extends StatelessWidget {
  const RiskBreakdownCard({
    super.key,
    required this.report,
  });

  final RiskAssessmentReport report;

  Color get _tierColor {
    switch (report.riskCategory) {
      case RiskLevelCategory.low:
        return AppColors.success;
      case RiskLevelCategory.moderate:
        return const Color(0xFFFFD600); // Yellow/Amber
      case RiskLevelCategory.high:
        return AppColors.warning;
      case RiskLevelCategory.critical:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = report.overallRiskPercent / 100.0;

    return GlassCard(
      borderColor: _tierColor.withValues(alpha: 0.4),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Shield Icon + Title + Risk Percentage Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _tierColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(AppIcons.shield, color: _tierColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OVERALL RISK LEVEL',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      '${report.overallRiskPercent}% (${report.categoryLabel})',
                      style: AppTextStyles.headlineMd.copyWith(
                        color: _tierColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _tierColor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.borderFull,
                  border: Border.all(color: _tierColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  report.categoryLabel,
                  style: AppTextStyles.labelSm.copyWith(
                    color: _tierColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Linear Risk Gauge
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation<Color>(_tierColor),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Factor Explanations Header
          Text(
            'CONTRIBUTING SIGNALS & REASONS:',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Itemized Factor List
          ...report.factors.map(
            (factor) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: _tierColor, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      factor.description,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(color: AppColors.glassBorder),
          const SizedBox(height: AppSpacing.xs),

          // Actionable Recommendation
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.onSurfaceVariant, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  report.recommendation,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
