import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../domain/entities/entities.dart';
import '../theme/animation_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'glass_card.dart';
import 'common_widgets.dart';

class JourneyCard extends StatelessWidget {
  const JourneyCard({super.key, required this.journey, this.onTap});

  final JourneyEntity journey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: journey.isAlert
                  ? AppColors.errorContainer
                  : AppColors.surfaceContainerHighest,
              borderRadius: AppRadius.borderXl,
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    journey.isAlert ? AppIcons.warning : AppIcons.map,
                    color: journey.isAlert ? AppColors.error : AppColors.tertiary,
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: journey.isAlert
                          ? AppColors.error
                          : AppColors.primaryPulse,
                      borderRadius: AppRadius.borderFull,
                    ),
                    child: Text(
                      journey.safetyScore.toStringAsFixed(1),
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(journey.title, style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  journey.subtitle,
                  style: AppTextStyles.labelSm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RecentJourneyCard extends StatelessWidget {
  const RecentJourneyCard({super.key, required this.journey});

  final JourneyEntity journey;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              Text('Recent Journey', style: AppTextStyles.labelLg),
              const Spacer(),
              Text(journey.dateLabel, style: AppTextStyles.labelSm),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryPulse,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 28,
                    color: AppColors.primaryPulse.withValues(alpha: 0.35),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPulse.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      journey.title,
                      style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(journey.subtitle, style: AppTextStyles.labelSm),
                  ],
                ),
              ),
              const Icon(AppIcons.shieldFilled, color: AppColors.primaryPulse),
            ],
          ),
        ],
      ),
    );
  }
}

class StatisticsCard extends StatelessWidget {
  const StatisticsCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryPulse, size: 22),
          const SizedBox(height: AppSpacing.md),
          Text(value, style: AppTextStyles.headlineMd),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.labelUpper.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

class MetricRowCard extends StatelessWidget {
  const MetricRowCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelSm),
                Text(value, style: AppTextStyles.headlineMd.copyWith(fontSize: 22)),
              ],
            ),
          ),
          IconBadge(icon: icon),
        ],
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  const NotificationCard({super.key, required this.notification});

  final NotificationEntity notification;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: notification.isRead ? AppColors.outline : AppColors.primaryPulse,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(notification.body, style: AppTextStyles.labelSm),
              ],
            ),
          ),
          Text(notification.timeLabel, style: AppTextStyles.labelSm),
        ],
      ),
    );
  }
}

class SosFab extends StatelessWidget {
  const SosFab({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: AppSpacing.sosFabSize,
        height: AppSpacing.sosFabSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.pulseGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryPulse.withValues(alpha: 0.5),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(AppIcons.sos, color: AppColors.white, size: 26),
            Text(
              'SOS',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.05, 1.05),
          duration: AppAnimations.breathe,
        );
  }
}

class HoldToAlarmButton extends StatefulWidget {
  const HoldToAlarmButton({super.key, required this.onAlarm});

  final VoidCallback onAlarm;

  @override
  State<HoldToAlarmButton> createState() => _HoldToAlarmButtonState();
}

class _HoldToAlarmButtonState extends State<HoldToAlarmButton> {
  double _progress = 0;
  bool _holding = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        setState(() {
          _holding = true;
          _progress = 0;
        });
        _tick();
      },
      onLongPressEnd: (_) {
        setState(() {
          _holding = false;
          _progress = 0;
        });
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.primaryPulse,
          borderRadius: AppRadius.borderXxl,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryPulse.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_holding)
              Positioned.fill(
                child: FractionallySizedBox(
                  widthFactor: _progress,
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.2),
                      borderRadius: AppRadius.borderXxl,
                    ),
                  ),
                ),
              ),
            Column(
              children: [
                const Icon(AppIcons.location, color: AppColors.surface),
                const SizedBox(height: 4),
                Text(
                  'HOLD TO ALARM',
                  style: AppTextStyles.labelLg.copyWith(
                    color: AppColors.surface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Alerts Emergency Contacts & Professional Response Team',
                  style: AppTextStyles.labelSm.copyWith(color: AppColors.surface.withValues(alpha: 0.8)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tick() async {
    while (_holding && _progress < 1) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (!_holding) return;
      setState(() => _progress += 0.05);
    }
    if (_progress >= 1) {
      widget.onAlarm();
      setState(() {
        _holding = false;
        _progress = 0;
      });
    }
  }
}
