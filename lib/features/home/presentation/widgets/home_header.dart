import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../core/widgets/glass_card.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.onNotifications,
  });

  final String name;
  final String avatarUrl;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          AppAvatar(imageUrl: avatarUrl, size: 44),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back,', style: AppTextStyles.labelSm),
                Text(
                  name,
                  style: AppTextStyles.headlineMd.copyWith(color: AppColors.primaryPulse),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onNotifications,
              borderRadius: AppRadius.borderFull,
              child: const GlassCard(
                padding: EdgeInsets.all(10),
                borderRadius: AppRadius.borderFull,
                child: Icon(AppIcons.notifications, color: AppColors.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
