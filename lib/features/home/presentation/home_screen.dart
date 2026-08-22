import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/api_config.dart';
import '../../../core/constants/route_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/feature_cards.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/guardian_system_status.dart';
import '../../../core/widgets/progress_ring.dart';
import '../../../core/widgets/sos_dialog.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../domain/entities/entities.dart';
import 'home_controller.dart';
import 'widgets/home_header.dart';
import 'widgets/nearby_services_card.dart';
import 'widgets/trusted_contacts_row.dart';

import 'dart:async';
import '../../../core/theme/radius.dart';
import '../../../core/widgets/safety_confirmation_dialog.dart';
import '../../../providers/repository_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription<SafetyEventModel>? _eventSub;
  bool _isAlertOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final engine = ref.read(guardianEngineProvider);
      _eventSub = engine.safetyEventStream.listen((event) {
        if (!mounted || _isAlertOpen) return;
        if (event.severity == SafetyEventSeverity.warning || event.severity == SafetyEventSeverity.critical) {
          _isAlertOpen = true;
          showSafetyConfirmationDialog(
            context: context,
            ref: ref,
            title: event.title,
            subtitle: '${event.message}\nSOS will trigger if not confirmed safe.',
            triggerSource: event.type.name,
            onSafeConfirmed: () {
              _isAlertOpen = false;
            },
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);

    return Scaffold(
      floatingActionButton: SosFab(
        onPressed: () {
          showEmergencySosModal(
            context: context,
            ref: ref,
            triggerSource: 'home_floating_sos',
          );
        },
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.background,
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.2,
            colors: [
              AppColors.primaryPulse.withValues(alpha: 0.12),
              AppColors.background,
              AppColors.auraGlow.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: dashboard.when(
          loading: () => const LoadingView(message: 'Securing connection & loading Guardian dashboard...'),
          error: (e, _) {
            if (e is AuthException) {
              return ErrorStateView(
                title: '[AUTH_ERROR] Authentication Required',
                message: 'Your credentials could not be validated or your session has expired. Please sign in to continue.\n\n${e.message}',
                icon: AppIcons.lock,
                actionLabel: 'Sign In Again',
                onRetry: () => context.go(RoutePaths.login),
              );
            }
            if (e is NetworkException) {
              return ErrorStateView(
                title: '[NETWORK_ERROR] Backend Unreachable',
                message: 'Unable to connect to Guardian AI backend at:\n${ApiConfig.baseUrl}\n\nResolution: ${ApiConfig.resolutionSource}\n\nTroubleshooting:\n1. Verify FastAPI server is running (uvicorn app.main:app)\n2. Connect phone to same Wi-Fi LAN\n3. Launch with --dart-define=API_HOST=<HOST_IP>',
                icon: AppIcons.activity,
                actionLabel: 'Retry Connection',
                onRetry: () => ref.invalidate(dashboardProvider),
              );
            }
            if (e is ApiTimeoutException) {
              return ErrorStateView(
                title: '[TIMEOUT] Server Request Timed Out',
                message: 'The Guardian AI server at ${ApiConfig.baseUrl} took too long to respond.\n\n${e.message}',
                icon: AppIcons.clock,
                actionLabel: 'Retry Connection',
                onRetry: () => ref.invalidate(dashboardProvider),
              );
            }
            if (e is PermissionException) {
              return ErrorStateView(
                title: '[PERMISSION_ERROR] Access Forbidden (403)',
                message: 'Access to this safety resource was denied by server.\n\n${e.message}',
                icon: AppIcons.shield,
                actionLabel: 'Sign In Again',
                onRetry: () => context.go(RoutePaths.login),
              );
            }
            if (e is ValidationException) {
              return ErrorStateView(
                title: '[VALIDATION_ERROR] Request Validation Failed (422)',
                message: 'Server rejected the request parameters:\n\n${e.message}',
                icon: AppIcons.warning,
                actionLabel: 'Retry Request',
                onRetry: () => ref.invalidate(dashboardProvider),
              );
            }
            if (e is ServerException) {
              return ErrorStateView(
                title: '[SERVER_ERROR] Backend Error (${e.statusCode})',
                message: 'Guardian AI backend encountered an error processing dashboard:\n\n${e.message}',
                icon: AppIcons.warning,
                actionLabel: 'Retry Request',
                onRetry: () => ref.invalidate(dashboardProvider),
              );
            }
            if (e is ApiException) {
              return ErrorStateView(
                title: '[${e.categoryCode}] Dashboard Error',
                message: e.message,
                icon: AppIcons.warning,
                actionLabel: 'Try Again',
                onRetry: () => ref.invalidate(dashboardProvider),
              );
            }
            return ErrorStateView(
              title: '[UNKNOWN_ERROR] Dashboard Error',
              message: e.toString(),
              icon: AppIcons.warning,
              actionLabel: 'Try Again',
              onRetry: () => ref.invalidate(dashboardProvider),
            );
          },
          data: (data) => _HomeBody(data: data),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.data});

  final DashboardEntity data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(homeControllerProvider.notifier);

    return SafeArea(
      child: ResponsivePadding(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: HomeHeader(
                name: data.userName,
                avatarUrl: data.avatarUrl,
                onNotifications: () => context.push(RoutePaths.notifications),
              ).animate().fadeIn().slideY(begin: -0.05, end: 0),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  SafetyScoreRing(score: data.safetyScore, size: Responsive.scale(context, 190)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    data.safetyScore == 88 && data.recentJourney.id.isEmpty
                        ? 'Baseline score — complete a walk to personalize'
                        : 'Calculated from completed journeys & area risk',
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  StatusChip(label: data.safetyStatus, pulse: true),
                ],
              ).animate().fadeIn(delay: 80.ms).scale(begin: const Offset(0.95, 0.95)),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

            // Real-time Background Subsystems Card
            const SliverToBoxAdapter(
              child: GuardianSystemStatus(),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),

            // Start Safe Journey CTA Card
            SliverToBoxAdapter(
              child: GlassCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPulse.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(AppIcons.walk, color: AppColors.primaryPulse, size: 24),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'START A SAFE JOURNEY',
                                style: AppTextStyles.labelSm.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryPulse,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Choose your destination and let Guardian AI calculate the safest route.',
                                style: AppTextStyles.bodyMd.copyWith(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'Plan Safe Route',
                      icon: AppIcons.map,
                      onPressed: () {
                        context.go(RoutePaths.map);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverToBoxAdapter(
              child: GlassCard(
                child: Row(
                  children: [
                    const IconBadge(icon: AppIcons.shieldFilled),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Guardian Mode', style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w700)),
                          Text(data.guardianSubtitle, style: AppTextStyles.labelSm),
                        ],
                      ),
                    ),
                    Switch(
                      value: data.guardianModeActive,
                      onChanged: controller.toggleGuardian,
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverToBoxAdapter(child: RecentJourneyCard(journey: data.recentJourney)),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(AppIcons.weather, color: AppColors.warning),
                          const SizedBox(height: AppSpacing.sm),
                          if (data.weather.condition.toLowerCase().contains('unavailable') ||
                              data.weather.condition.toLowerCase().contains('not configured') ||
                              data.weather.temperatureC == 0) ...[
                            Text('Weather', style: AppTextStyles.headlineMd.copyWith(fontSize: 18)),
                            Text(data.weather.location, style: AppTextStyles.labelSm),
                            Text(
                              'Live weather unavailable • GPS active',
                              style: AppTextStyles.labelSm.copyWith(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ] else ...[
                            Text('${data.weather.temperatureC}°C', style: AppTextStyles.headlineMd),
                            Text(data.weather.location, style: AppTextStyles.labelSm),
                            Text(
                              '${data.weather.condition} • Visibility ${data.weather.visibilityKm}km',
                              style: AppTextStyles.labelSm.copyWith(fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: GlassCard(
                      onTap: () => context.push(RoutePaths.safetyInsights),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(AppIcons.brain, color: AppColors.primaryPulse),
                              const Spacer(),
                              Icon(Icons.more_horiz, color: AppColors.onSurfaceVariant.withValues(alpha: 0.7)),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text('Guardian AI', style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w700)),
                          Text(data.aiScanningLabel, style: AppTextStyles.labelSm),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverToBoxAdapter(child: NearbyServicesCard(services: data.nearbyServices)),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
                      onTap: () {
                        controller.fakeCall();
                        context.push(RoutePaths.fakeCall);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(AppIcons.phone, color: AppColors.primaryPulse, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Fake Call',
                            style: AppTextStyles.bodyMd.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
                      onTap: () {
                        controller.fakeMessage();
                        context.push(RoutePaths.fakeMessage);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(AppIcons.message, color: AppColors.primaryPulse, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Fake Text',
                            style: AppTextStyles.bodyMd.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverToBoxAdapter(
              child: GlassCard(
                onTap: () => context.push(RoutePaths.diagnostics),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPulse.withValues(alpha: 0.15),
                        borderRadius: AppRadius.borderMd,
                      ),
                      child: const Icon(Icons.analytics_outlined, color: AppColors.primaryPulse, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Guardian System Diagnostics', style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w700)),
                          Text('Inspect real hardware sensors, voice trigger, and safe test tools', style: AppTextStyles.labelSm),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverToBoxAdapter(
              child: TrustedContactsRow(
                contacts: data.contacts,
                onEdit: () => context.push(RoutePaths.contacts),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}
