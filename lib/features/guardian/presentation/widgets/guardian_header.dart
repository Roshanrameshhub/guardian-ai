import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';

class GuardianHeader extends StatelessWidget {
  const GuardianHeader({super.key, required this.avatarUrl});

  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          AppAvatar(imageUrl: avatarUrl, size: 40),
          Expanded(
            child: Text(
              'Guardian AI',
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineMd.copyWith(color: AppColors.primaryPulse),
            ),
          ),
          InkWell(
            onTap: () => context.push(RoutePaths.notifications),
            child: const GlassCard(
              padding: EdgeInsets.all(10),
              child: Icon(AppIcons.notifications, color: AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
