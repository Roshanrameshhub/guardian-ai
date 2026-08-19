import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/dev_log.dart';
import '../../../domain/entities/entities.dart';
import '../../../providers/repository_providers.dart';

final activityProvider = FutureProvider<ActivityEntity>((ref) async {
  DevLog.log('ACTIVITY', 'Loading activity and history timeline...');
  try {
    final activity = await ref.watch(activityRepositoryProvider).fetchActivity();
    DevLog.log('ACTIVITY', 'Activity loaded: ${activity.journeys.length} journeys, ${activity.achievements.length} achievements.');
    return activity;
  } catch (e, st) {
    DevLog.log('ACTIVITY', 'Failed to load activity', error: e, stackTrace: st);
    rethrow;
  }
});

final notificationsProvider = FutureProvider<List<NotificationEntity>>((ref) async {
  DevLog.log('NOTIFICATIONS', 'Loading notifications...');
  try {
    final notifs = await ref.watch(activityRepositoryProvider).fetchNotifications();
    DevLog.log('NOTIFICATIONS', 'Loaded ${notifs.length} notifications.');
    return notifs;
  } catch (e, st) {
    DevLog.log('NOTIFICATIONS', 'Failed to load notifications', error: e, stackTrace: st);
    rethrow;
  }
});
