import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../domain/entities/entities.dart';

class NearbyServicesCard extends StatelessWidget {
  const NearbyServicesCard({super.key, required this.services});

  final List<NearbyServiceEntity> services;

  IconData _icon(NearbyServiceType type) => switch (type) {
        NearbyServiceType.metro => AppIcons.metro,
        NearbyServiceType.hospital => AppIcons.hospital,
        NearbyServiceType.police => AppIcons.police,
      };

  String _label(NearbyServiceType type) => switch (type) {
        NearbyServiceType.metro => 'Nearest Metro',
        NearbyServiceType.hospital => 'Nearby Hospital',
        NearbyServiceType.police => 'Nearby Police',
      };

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Nearby Safety Services', style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                'Live GPS Active',
                style: AppTextStyles.labelSm.copyWith(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (services.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Searching for nearby emergency stations...',
                style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant),
              ),
            )
          else
            ...services.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    IconBadge(icon: _icon(s.type)),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_label(s.type), style: AppTextStyles.labelSm.copyWith(fontSize: 10)),
                          Text(
                            s.name,
                            style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${s.distanceKm.toStringAsFixed(1)} km',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.primaryPulse,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
