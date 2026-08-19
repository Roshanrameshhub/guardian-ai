import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../data/dto/api_dto.dart';
import '../../../domain/entities/entities.dart';
import '../../../providers/repository_providers.dart';

class JourneyConfirmationScreen extends ConsumerStatefulWidget {
  const JourneyConfirmationScreen({
    super.key,
    this.destinationName = 'Selected Destination',
    this.destLat = 13.0827,
    this.destLng = 80.2707,
    this.originLat = 12.9716,
    this.originLng = 80.2435,
    this.routeName = 'Safer Route',
    this.safetyScore = 92,
    this.estimatedDistanceKm = 3.2,
    this.estimatedMinutes = 18,
    this.routePoints = const [],
  });

  final String destinationName;
  final double destLat;
  final double destLng;
  final double originLat;
  final double originLng;
  final String routeName;
  final int safetyScore;
  final double estimatedDistanceKm;
  final int estimatedMinutes;
  final List<LatLngPoint> routePoints;

  @override
  ConsumerState<JourneyConfirmationScreen> createState() =>
      _JourneyConfirmationScreenState();
}

class _JourneyConfirmationScreenState
    extends ConsumerState<JourneyConfirmationScreen> {
  bool _isStarting = false;

  Future<void> _handleStartJourney() async {
    setState(() => _isStarting = true);
    try {
      final journeyRepo = ref.read(journeyRepositoryProvider);
      final journey = await journeyRepo.startJourney(
        StartJourneyRequest(
          origin: 'Current Location',
          destination: widget.destinationName,
          originLat: widget.originLat,
          originLng: widget.originLng,
          destLat: widget.destLat,
          destLng: widget.destLng,
        ),
      );

      if (mounted) {
        context.pushReplacement(
          RoutePaths.liveJourney,
          extra: {
            'journeyId': journey.id,
            'destinationName': widget.destinationName,
            'destLat': widget.destLat,
            'destLng': widget.destLng,
            'routePoints': widget.routePoints,
            'safetyScore': widget.safetyScore,
            'estimatedDistanceKm': widget.estimatedDistanceKm,
            'estimatedMinutes': widget.estimatedMinutes,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        // Fallback open live journey with client state if network error
        context.pushReplacement(
          RoutePaths.liveJourney,
          extra: {
            'journeyId': null,
            'destinationName': widget.destinationName,
            'destLat': widget.destLat,
            'destLng': widget.destLng,
            'routePoints': widget.routePoints,
            'safetyScore': widget.safetyScore,
            'estimatedDistanceKm': widget.estimatedDistanceKm,
            'estimatedMinutes': widget.estimatedMinutes,
          },
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'CONFIRM SAFE JOURNEY',
            style: AppTextStyles.labelSm.copyWith(
              letterSpacing: 1.0,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryPulse,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route & Destination Summary
                GlassCard(
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
                            child: const Icon(
                              AppIcons.walk,
                              color: AppColors.primaryPulse,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.destinationName,
                                  style: AppTextStyles.headlineMd.copyWith(fontSize: 20),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.routeName,
                                  style: AppTextStyles.labelSm.copyWith(
                                    color: AppColors.tertiary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.tertiary.withValues(alpha: 0.15),
                              borderRadius: AppRadius.borderFull,
                            ),
                            child: Text(
                              '${widget.safetyScore} SCORE',
                              style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.tertiary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Divider(color: AppColors.glassBorder),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MetricColumn(
                            label: 'DISTANCE',
                            value: '${widget.estimatedDistanceKm} km',
                          ),
                          Container(width: 1, height: 28, color: AppColors.glassBorder),
                          _MetricColumn(
                            label: 'ESTIMATED TIME',
                            value: '~${widget.estimatedMinutes} min',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                Text(
                  'ACTIVE PROTECTION LAYERS',
                  style: AppTextStyles.labelSm.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Protection checklist
                Expanded(
                  child: ListView(
                    children: const [
                      _ProtectionTile(
                        icon: Icons.gps_fixed,
                        title: 'Live GPS Tracking & Geofencing',
                        subtitle: 'High precision location telemetry synced with server',
                      ),
                      _ProtectionTile(
                        icon: Icons.alt_route,
                        title: 'Route Deviation Watchdog',
                        subtitle: 'Instant alert if moved > 150m away from planned path',
                      ),
                      _ProtectionTile(
                        icon: Icons.vibration,
                        title: 'Motion & Fall Detection',
                        subtitle: 'Accelerometer & gyroscope monitor for sudden drops/impact',
                      ),
                      _ProtectionTile(
                        icon: Icons.mic_none,
                        title: 'Hands-Free Voice Distress Recognition',
                        subtitle: 'Speech-to-text engine listens for configured emergency triggers',
                      ),
                      _ProtectionTile(
                        icon: Icons.timer,
                        title: 'Stationary Prolonged Stop Check',
                        subtitle: 'Safety verification prompt after unusual stopping periods',
                      ),
                      _ProtectionTile(
                        icon: Icons.sos,
                        title: 'Instant Emergency SOS Dispatch',
                        subtitle: 'Twilio SMS & Push alerts with live GPS to Trusted Circle',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Start Safe Journey',
                  icon: AppIcons.shieldFilled,
                  isLoading: _isStarting,
                  onPressed: _handleStartJourney,
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Change Route / Cancel',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.labelSm.copyWith(fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.headlineMd.copyWith(fontSize: 16),
        ),
      ],
    );
  }
}

class _ProtectionTile extends StatelessWidget {
  const _ProtectionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.success, size: 18),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMd.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.check_circle, color: AppColors.success, size: 18),
          ],
        ),
      ),
    );
  }
}
