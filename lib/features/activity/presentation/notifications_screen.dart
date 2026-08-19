import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/feature_cards.dart';
import 'activity_controller.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(AppIcons.back, size: 18),
        ),
        title: Text('Notifications', style: AppTextStyles.headlineMd.copyWith(fontSize: 18)),
      ),
      body: notifications.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorStateView(
          message: e.toString(),
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyStateView(
              title: 'No notifications',
              subtitle: 'You\'re all caught up.',
              icon: AppIcons.notifications,
            );
          }
          return ResponsivePadding(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => NotificationCard(notification: items[index]),
            ),
          );
        },
      ),
    );
  }
}
