import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/progress_ring.dart';
import '../../../../domain/entities/entities.dart';

class MapRouteCard extends StatelessWidget {
  const MapRouteCard({
    super.key,
    required this.route,
    this.onStartNavigation,
    this.onShare,
  });

  final MapRouteEntity route;
  final VoidCallback? onStartNavigation;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FROM ${route.from}', style: AppTextStyles.labelSm),
                    Text(
                      'TO ${route.to}',
                      style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              ProgressRing(
                progress: route.safetyScore / 100,
                size: 64,
                strokeWidth: 5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${route.safetyScore}',
                      style: AppTextStyles.labelLg.copyWith(color: AppColors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${route.etaMinutes} min ETA', style: AppTextStyles.labelLg),
                    Text(route.trafficLabel, style: AppTextStyles.labelSm),
                    Text(
                      '${route.distanceKm} km via ${route.via}',
                      style: AppTextStyles.labelSm,
                      textAlign: TextAlign.right,
                    ),
                    Text(
                      route.safetyLabel,
                      style: AppTextStyles.labelSm.copyWith(color: AppColors.success),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _Stat(label: 'Traffic', value: 'Light', valueColor: AppColors.success),
              _Stat(label: 'Police', value: '${route.policeNearby} Nearby'),
              _Stat(label: 'Hospitals', value: '${route.hospitalsNearby} Nearby'),
              _Stat(label: 'Metro', value: '${route.metroKm} km'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Start Navigation',
                  icon: AppIcons.arrowForward,
                  onPressed: onStartNavigation ?? () {},
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Material(
                color: AppColors.surfaceContainerHighest,
                borderRadius: AppRadius.borderXl,
                child: InkWell(
                  onTap: onShare ?? () {},
                  borderRadius: AppRadius.borderXl,
                  child: const SizedBox(
                    width: 56,
                    height: 56,
                    child: Icon(AppIcons.share, color: AppColors.onSurface),
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


class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.labelSm.copyWith(fontSize: 10)),
        Text(
          value,
          style: AppTextStyles.labelSm.copyWith(
            color: valueColor ?? AppColors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
