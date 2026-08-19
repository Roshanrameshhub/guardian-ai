import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/route_paths.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.location});

  final String location;

  int get _index {
    if (location.startsWith(RoutePaths.map)) return 1;
    if (location.startsWith(RoutePaths.guardian)) return 2;
    if (location.startsWith(RoutePaths.activity)) return 3;
    if (location.startsWith(RoutePaths.profile)) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      (AppIcons.home, AppIcons.homeFilled, 'Home', RoutePaths.home),
      (AppIcons.map, AppIcons.mapFilled, 'Map', RoutePaths.map),
      (AppIcons.shield, AppIcons.shieldFilled, 'Guardian', RoutePaths.guardian),
      (AppIcons.activity, AppIcons.activity, 'Activity', RoutePaths.activity),
      (AppIcons.profile, AppIcons.profileFilled, 'Profile', RoutePaths.profile),
    ];

    return Container(
      height: AppSpacing.bottomNavHeight + MediaQuery.paddingOf(context).bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: AppColors.glassBorder, width: 0.5)),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final selected = _index == i;
          final item = items[i];
          return Expanded(
            child: InkWell(
              onTap: () => context.go(item.$4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: EdgeInsets.symmetric(
                      horizontal: selected ? 14 : 10,
                      vertical: selected ? 8 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primaryPulse : Colors.transparent,
                      borderRadius: AppRadius.borderFull,
                    ),
                    child: Icon(
                      selected ? item.$2 : item.$1,
                      color: selected ? AppColors.white : AppColors.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.$3,
                    style: AppTextStyles.labelSm.copyWith(
                      color: selected ? AppColors.white : AppColors.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNav(location: location),
    );
  }
}
