import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../domain/entities/entities.dart';

class WeeklyOverviewCard extends StatelessWidget {
  const WeeklyOverviewCard({super.key, required this.overview});

  final WeeklyOverviewEntity overview;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEEKLY OVERVIEW',
                      style: AppTextStyles.labelUpper.copyWith(color: AppColors.tertiary),
                    ),
                    Text('Safety Performance', style: AppTextStyles.headlineMd.copyWith(fontSize: 22)),
                  ],
                ),
              ),
              Column(
                children: [
                  Text('${overview.globalScore}', style: AppTextStyles.headlineLg),
                  Text('Global Score', style: AppTextStyles.labelSm),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(overview.bars.length, (i) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: overview.bars[i],
                            widthFactor: 1,
                            alignment: Alignment.bottomCenter,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: AppRadius.borderMd,
                                gradient: AppColors.primaryGradient,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(overview.labels[i], style: AppTextStyles.labelSm.copyWith(fontSize: 10)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
