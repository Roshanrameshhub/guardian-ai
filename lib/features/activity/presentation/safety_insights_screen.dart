import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../domain/entities/entities.dart';
import '../../../providers/repository_providers.dart';

final recommendationsProvider = FutureProvider<List<SafetyRecommendationEntity>>((ref) {
  return ref.watch(intelligenceRepositoryProvider).fetchRecommendations();
});

class SafetyInsightsScreen extends ConsumerWidget {
  const SafetyInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendationsAsync = ref.watch(recommendationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLow,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('AI Safety Insights', style: AppTextStyles.headlineMd.copyWith(fontSize: 20)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall AI Safety Score Card
            GlassCard(
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.tertiary.withValues(alpha: 0.15),
                      border: Border.all(color: AppColors.tertiary, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '92',
                        style: AppTextStyles.headlineLg.copyWith(
                          color: AppColors.tertiary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Safety Posture: Optimal', style: AppTextStyles.headlineMd.copyWith(fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(
                          'Based on your last 14 journeys and local environmental safety factors.',
                          style: AppTextStyles.labelSm,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Safety Stats Row
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(AppIcons.walk, color: AppColors.primaryPulse, size: 24),
                        const SizedBox(height: 8),
                        Text('Safe Trips', style: AppTextStyles.labelSm),
                        Text('28', style: AppTextStyles.headlineMd.copyWith(fontSize: 22)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(AppIcons.shield, color: AppColors.tertiary, size: 24),
                        const SizedBox(height: 8),
                        Text('Route Adherence', style: AppTextStyles.labelSm),
                        Text('98.4%', style: AppTextStyles.headlineMd.copyWith(fontSize: 22)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Personalized AI Recommendations', style: AppTextStyles.headlineMd.copyWith(fontSize: 18)),
            const SizedBox(height: AppSpacing.md),
            recommendationsAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => GlassCard(
                child: Row(
                  children: [
                    const Icon(AppIcons.brain, color: AppColors.primaryPulse, size: 32),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Keep Battery Above 30%', style: AppTextStyles.headlineMd.copyWith(fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('Guardian AI uses adaptive power when traveling after 9:00 PM.', style: AppTextStyles.bodyMd),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              data: (recs) {
                if (recs.isEmpty) {
                  return GlassCard(
                    child: Row(
                      children: [
                        const Icon(AppIcons.brain, color: AppColors.primaryPulse, size: 32),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Optimal Walking Habits', style: AppTextStyles.headlineMd.copyWith(fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('Your chosen routes stay along well-lit primary transit corridors.', style: AppTextStyles.bodyMd),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: recs.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: GlassCard(
                      child: Row(
                        children: [
                          const Icon(AppIcons.brain, color: AppColors.primaryPulse, size: 32),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.title, style: AppTextStyles.headlineMd.copyWith(fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(r.evidence.isNotEmpty ? r.evidence : r.category, style: AppTextStyles.bodyMd),
                              ],

                            ),
                          ),
                        ],
                      ),
                    ),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
