import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../domain/entities/entities.dart';

class NearbyHelpBar extends StatelessWidget {
  const NearbyHelpBar({
    super.key,
    required this.nearbyHelp,
    this.onTapPolice,
    this.onTapHospital,
    this.onTapStation,
    this.onTapActive,
  });

  final NearbyHelpEntity? nearbyHelp;
  final VoidCallback? onTapPolice;
  final VoidCallback? onTapHospital;
  final VoidCallback? onTapStation;
  final VoidCallback? onTapActive;

  @override
  Widget build(BuildContext context) {
    if (nearbyHelp == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.85),
        borderRadius: AppRadius.borderXl,
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primaryPulse,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text('NEARBY HELP & PROXIMITY', style: AppTextStyles.labelSm.copyWith(letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: _ProximityItem(
                  icon: AppIcons.police,
                  iconColor: AppColors.police,
                  title: 'Police',
                  distance: nearbyHelp!.policeDistance,
                  onTap: onTapPolice,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ProximityItem(
                  icon: AppIcons.hospital,
                  iconColor: AppColors.hospital,
                  title: 'Hospital',
                  distance: nearbyHelp!.hospitalDistance,
                  onTap: onTapHospital,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ProximityItem(
                  icon: AppIcons.metro,
                  iconColor: AppColors.info,
                  title: 'Transit',
                  distance: nearbyHelp!.stationDistance,
                  onTap: onTapStation,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ProximityItem(
                  icon: Icons.groups_rounded,
                  iconColor: AppColors.primaryPulse,
                  title: 'Active Hub',
                  distance: nearbyHelp!.activeAreaDistance,
                  onTap: onTapActive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProximityItem extends StatelessWidget {
  const _ProximityItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.distance,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String distance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderMd,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest.withValues(alpha: 0.6),
          borderRadius: AppRadius.borderMd,
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(height: 2),
            Text(
              distance,
              style: AppTextStyles.labelSm.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              title,
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
