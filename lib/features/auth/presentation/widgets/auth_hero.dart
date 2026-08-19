import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/animation_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/glass_card.dart';

class AuthHeroShield extends StatelessWidget {
  const AuthHeroShield({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
      child: Column(
        children: [
          SizedBox(
            height: compact ? 120 : 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: compact ? 110 : 140,
                  height: compact ? 110 : 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.info.withValues(alpha: 0.35),
                        AppColors.primaryPulse.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(0.92, 0.92),
                      end: const Offset(1.05, 1.05),
                      duration: AppAnimations.breathe,
                    ),
                Icon(
                  AppIcons.shieldFilled,
                  size: compact ? 72 : 96,
                  color: AppColors.info.withValues(alpha: 0.9),
                ),
                Positioned(
                  child: Icon(
                    AppIcons.location,
                    size: compact ? 28 : 36,
                    color: AppColors.primaryPulse,
                  ),
                ),
              ],
            ),
          ),
          if (compact) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'SECURE YOUR JOURNEY',
              style: AppTextStyles.labelUpper.copyWith(color: AppColors.white),
            ),
          ],
        ],
      ),
    );
  }
}
