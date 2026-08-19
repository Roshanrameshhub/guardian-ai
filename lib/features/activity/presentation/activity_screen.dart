import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';

import '../../../core/theme/text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/feature_cards.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../domain/entities/entities.dart';
import 'activity_controller.dart';
import 'widgets/weekly_overview_card.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.background),
        child: activity.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorStateView(
            message: e.toString(),
            onRetry: () => ref.invalidate(activityProvider),
          ),
          data: (data) => _ActivityBody(data: data),
        ),
      ),
    );
  }
}

class _ActivityBody extends StatelessWidget {
  const _ActivityBody({required this.data});

  final ActivityEntity data;

  IconData _metricIcon(String key) => switch (key) {
        'walk' => AppIcons.walk,
        'shield' => AppIcons.shieldFilled,
        _ => AppIcons.warning,
      };

  IconData _achievementIcon(String key) => switch (key) {
        'ribbon' => AppIcons.ribbon,
        'check' => AppIcons.check,
        _ => AppIcons.shieldFilled,
      };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ResponsivePadding(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Row(
                  children: [
                    AppAvatar(imageUrl: data.avatarUrl, size: 40),
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
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            SliverToBoxAdapter(
              child: InkWell(
                onTap: () => context.push(RoutePaths.safetyInsights),
                borderRadius: AppRadius.borderXxl,
                child: WeeklyOverviewCard(overview: data.weeklyOverview)
                    .animate()
                    .fadeIn()
                    .slideY(begin: 0.05, end: 0),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverList.separated(
              itemCount: data.metrics.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final m = data.metrics[index];
                return MetricRowCard(
                  label: m.label,
                  value: m.value,
                  icon: _metricIcon(m.iconKey),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'Journey History'),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
            if (data.journeys.isEmpty)
              SliverToBoxAdapter(
                child: GlassCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.directions_walk, size: 32, color: AppColors.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text(
                          'No completed journeys yet',
                          style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Plan a route on the Map to start tracking your safety history.',
                          style: AppTextStyles.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount: data.journeys.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) => JourneyCard(journey: data.journeys[index]),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            const SliverToBoxAdapter(child: SectionHeader(title: 'Achievements')),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
            SliverList.separated(
              itemCount: data.achievements.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final a = data.achievements[index];
                return GlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: a.unlocked
                              ? AppColors.primaryPulse.withValues(alpha: 0.2)
                              : AppColors.surfaceContainerHighest,
                        ),
                        child: Icon(
                          _achievementIcon(a.iconKey),
                          color: a.unlocked ? AppColors.primaryPulse : AppColors.outline,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.title,
                              style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(a.subtitle, style: AppTextStyles.labelSm),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            const SliverToBoxAdapter(child: SectionHeader(title: 'Safety Events')),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
            SliverToBoxAdapter(
              child: GlassCard(
                child: Column(
                  children: List.generate(data.safetyEvents.length, (index) {
                    final e = data.safetyEvents[index];
                    final isLast = index == data.safetyEvents.length - 1;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: AppColors.tertiary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            if (!isLast)
                              Container(
                                width: 2,
                                height: 48,
                                color: AppColors.tertiary.withValues(alpha: 0.35),
                              ),
                          ],
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${e.time} - ${e.title}',
                                  style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(e.subtitle, style: AppTextStyles.labelSm),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
          ],
        ),
      ),
    );
  }
}
