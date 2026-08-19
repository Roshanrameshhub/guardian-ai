import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/utils/phone_call_utils.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../domain/entities/entities.dart';

class PoliceStationDetailSheet extends StatelessWidget {
  const PoliceStationDetailSheet({
    super.key,
    required this.police,
    required this.onClose,
  });

  final PoliceStationEntity police;
  final VoidCallback onClose;

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
                  color: AppColors.police.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(AppIcons.police, color: AppColors.police, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(police.stationName, style: AppTextStyles.headlineMd),
                    Text(
                      'Sub-Division: ${police.subDivision} • Zone: ${police.zone}',
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
          if (police.distanceDisplay != null) ...[
            GlassCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Icon(AppIcons.location, color: AppColors.primaryPulse, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Distance from you:', style: AppTextStyles.bodyMd),
                  const Spacer(),
                  Text(
                    police.distanceDisplay!,
                    style: AppTextStyles.headlineMd.copyWith(
                      color: AppColors.primaryPulse,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          GlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(AppIcons.phone, color: AppColors.success, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Official Contact Number', style: AppTextStyles.labelSm),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: AppRadius.borderSm,
                      ),
                      child: Text(
                        'Verified Directory',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  police.contactNumber,
                  style: AppTextStyles.headlineMd.copyWith(
                    color: AppColors.success,
                    fontSize: 19,
                    letterSpacing: 1,
                  ),
                ),
                if (police.address != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(police.address!, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                ],
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.white,
                      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderFull),
                    ),
                    icon: const Icon(Icons.call, size: 18),
                    label: Text(
                      'CALL POLICE STATION',
                      style: AppTextStyles.labelSm.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.white,
                      ),
                    ),
                    onPressed: () => PhoneCallUtils.launchCall(context, police.contactNumber),
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
                const Icon(Icons.info_outline, size: 16, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    police.sourceInfo,
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
