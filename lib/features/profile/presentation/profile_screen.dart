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
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/feature_cards.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../domain/entities/entities.dart';
import 'profile_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final ui = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.background),
        child: profile.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorStateView(
            message: e.toString(),
            onRetry: () => ref.invalidate(profileProvider),
          ),
          data: (user) => _ProfileBody(user: user, ui: ui, controller: controller),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.user,
    required this.ui,
    required this.controller,
  });

  final UserEntity user;
  final ProfileUiState ui;
  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ResponsivePadding(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go(RoutePaths.home),
                      icon: const Icon(AppIcons.back, color: AppColors.primaryPulse, size: 20),
                    ),
                    Expanded(
                      child: Text(
                        'Account',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.headlineMd.copyWith(fontSize: 18),
                      ),
                    ),
                    AppAvatar(
                      imageUrl: user.avatarUrl,
                      size: 36,
                      borderColor: AppColors.primaryPulse,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryPulse.withValues(alpha: 0.45),
                          blurRadius: 24,
                        ),
                      ],
                      border: Border.all(color: AppColors.primaryPulse, width: 2),
                    ),
                    child: AppAvatar(imageUrl: user.avatarUrl, size: 110),
                  ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
                  if (user.isPremium)
                    Positioned(
                      bottom: -10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryPulse,
                          borderRadius: AppRadius.borderFull,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(AppIcons.check, size: 14, color: AppColors.white),
                            const SizedBox(width: 4),
                            Text(
                              'PREMIUM',
                              style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(user.name, style: AppTextStyles.headlineMd),
              Text(
                'Safety Shield Active • v${user.appVersion}',
                style: AppTextStyles.labelSm,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: StatisticsCard(
                      value: '${user.safeTrips}',
                      label: 'SAFE TRIPS',
                      icon: AppIcons.walk,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push(RoutePaths.contacts),
                      child: StatisticsCard(
                        value: '${user.trustedContactCount}',
                        label: 'TRUSTED CONTACTS',
                        icon: Icons.groups_outlined,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              GlassCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.membershipName,
                            style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text('Next billing: ${user.nextBilling}', style: AppTextStyles.labelSm),
                        ],
                      ),
                    ),
                    Material(
                      color: AppColors.surfaceContainerHighest,
                      borderRadius: AppRadius.borderFull,
                      child: InkWell(
                        onTap: () {},
                        borderRadius: AppRadius.borderFull,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text('Manage', style: AppTextStyles.labelSm.copyWith(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('PREFERENCES', style: AppTextStyles.labelUpper),
              ),
              const SizedBox(height: AppSpacing.sm),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _PrefTile(
                      icon: AppIcons.shield,
                      title: 'Guardian Mode',
                      subtitle: 'AI-powered active monitoring',
                      trailing: Switch(
                        value: ui.guardianEnabled,
                        onChanged: controller.setGuardianEnabled,
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.glassBorder),
                    InkWell(
                      onTap: () => context.push(RoutePaths.contacts),
                      child: const _PrefTile(
                        icon: AppIcons.sos,
                        title: 'Trusted Circle & SOS',
                        subtitle: 'Configure emergency alerts and contacts.',
                        trailing: Icon(AppIcons.chevronRight, color: AppColors.onSurfaceVariant),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.glassBorder),
                    const _PrefTile(
                      icon: AppIcons.palette,
                      title: 'Appearance',
                      subtitle: 'Dark mode, accent colors.',
                      trailing: Icon(AppIcons.chevronRight, color: AppColors.onSurfaceVariant),
                    ),
                    const Divider(height: 1, color: AppColors.glassBorder),
                    InkWell(
                      onTap: () => context.push(RoutePaths.settings),
                      child: const _PrefTile(
                        icon: AppIcons.lock,
                        title: 'Privacy & Permissions',
                        subtitle: 'Location and data access.',
                        trailing: Icon(AppIcons.chevronRight, color: AppColors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Sign Out',
                icon: AppIcons.logout,
                variant: AppButtonVariant.outline,
                onPressed: () async {
                  final confirmed = await showConfirmDialog(
                    context: context,
                    title: 'Sign out?',
                    message: 'You can sign back in anytime.',
                    confirmLabel: 'Sign Out',
                  );
                  if (confirmed == true) {
                    await controller.signOut();
                    if (context.mounted) context.go(RoutePaths.login);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          IconBadge(icon: icon, color: AppColors.tertiary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle, style: AppTextStyles.labelSm),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
