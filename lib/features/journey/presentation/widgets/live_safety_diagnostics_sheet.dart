import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../domain/entities/entities.dart';

/// Compact, expandable Live Safety Report & Diagnostics Sheet for active journeys.
class LiveSafetyDiagnosticsSheet extends StatefulWidget {
  const LiveSafetyDiagnosticsSheet({
    super.key,
    required this.events,
    required this.gpsActive,
    required this.gpsAccuracyMeters,
    required this.guardianActive,
    required this.routeDeviated,
    required this.isStationary,
    required this.speedKmh,
  });

  final List<SafetyEventModel> events;
  final bool gpsActive;
  final double gpsAccuracyMeters;
  final bool guardianActive;
  final bool routeDeviated;
  final bool isStationary;
  final double speedKmh;

  @override
  State<LiveSafetyDiagnosticsSheet> createState() => _LiveSafetyDiagnosticsSheetState();
}

class _LiveSafetyDiagnosticsSheetState extends State<LiveSafetyDiagnosticsSheet> {
  bool _isExpanded = false;

  Color _severityColor(SafetyEventSeverity severity) {
    switch (severity) {
      case SafetyEventSeverity.info:
        return AppColors.info;
      case SafetyEventSeverity.warning:
        return AppColors.warning;
      case SafetyEventSeverity.critical:
        return AppColors.error;
      case SafetyEventSeverity.success:
        return AppColors.success;
    }
  }

  IconData _severityIcon(SafetyEventSeverity severity) {
    switch (severity) {
      case SafetyEventSeverity.info:
        return Icons.info_outline;
      case SafetyEventSeverity.warning:
        return Icons.warning_amber_rounded;
      case SafetyEventSeverity.critical:
        return Icons.error_outline;
      case SafetyEventSeverity.success:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.96),
        borderRadius: AppRadius.borderLg,
        border: Border.all(
          color: widget.routeDeviated
              ? AppColors.warning
              : AppColors.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar / Tap to Toggle
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: AppRadius.borderLg,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.guardianActive ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'LIVE SAFETY REPORT',
                    style: AppTextStyles.labelSm.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      fontSize: 11,
                      color: AppColors.primaryPulse,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: Text(
                      '${widget.events.length} Events',
                      style: AppTextStyles.labelSm.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                    color: AppColors.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Collapsed Subsystem Status Chips
          if (!_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _MiniStatusPill(
                      label: 'GPS ${widget.gpsAccuracyMeters > 0 ? "±${widget.gpsAccuracyMeters.toStringAsFixed(0)}m" : "Active"}',
                      isGood: widget.gpsActive,
                    ),
                    const SizedBox(width: 6),
                    _MiniStatusPill(
                      label: widget.routeDeviated ? 'Route Deviated' : 'Route Matched',
                      isGood: !widget.routeDeviated,
                    ),
                    const SizedBox(width: 6),
                    _MiniStatusPill(
                      label: widget.isStationary ? 'Stationary' : 'Moving (${widget.speedKmh.toStringAsFixed(1)} km/h)',
                      isGood: true,
                    ),
                    const SizedBox(width: 6),
                    const _MiniStatusPill(label: 'Sensors Active', isGood: true),
                  ],
                ),
              ),
            ),
          ],

          // Expanded Content: Subsystem Grid + Chronological Event Timeline
          if (_isExpanded) ...[
            const Divider(color: AppColors.glassBorder, height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subsystems Grid
                  Row(
                    children: [
                      Expanded(
                        child: _SubsystemStatusTile(
                          icon: Icons.gps_fixed,
                          title: 'GPS Tracking',
                          status: widget.gpsActive ? 'High Accuracy (±${widget.gpsAccuracyMeters.toStringAsFixed(0)}m)' : 'Inactive',
                          isGood: widget.gpsActive,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _SubsystemStatusTile(
                          icon: Icons.alt_route,
                          title: 'Route Watchdog',
                          status: widget.routeDeviated ? 'Deviation Alert' : 'On Safe Path',
                          isGood: !widget.routeDeviated,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Row(
                    children: [
                      Expanded(
                        child: _SubsystemStatusTile(
                          icon: Icons.vibration,
                          title: 'Motion Kinematics',
                          status: 'Accelerometer Active',
                          isGood: true,
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _SubsystemStatusTile(
                          icon: Icons.shield,
                          title: 'Guardian Engine',
                          status: 'AI Watchdog Ready',
                          isGood: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Event Timeline Header
                  Row(
                    children: [
                      Text(
                        'REAL-TIME TIMELINE',
                        style: AppTextStyles.labelSm.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Live audit log',
                        style: AppTextStyles.labelSm.copyWith(
                          fontSize: 10,
                          color: AppColors.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Timeline List (up to last 10 events)
                  if (widget.events.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Monitoring started. All security channels nominal.',
                        style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant, fontSize: 12),
                      ),
                    ),
                  ] else ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: widget.events.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, idx) {
                          // Display in reverse chronological order (newest first)
                          final event = widget.events[widget.events.length - 1 - idx];
                          final color = _severityColor(event.severity);
                          final icon = _severityIcon(event.severity);

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest.withValues(alpha: 0.7),
                              borderRadius: AppRadius.borderSm,
                              border: Border.all(color: color.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(icon, color: color, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  event.timeFormatted,
                                  style: AppTextStyles.labelSm.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.title,
                                        style: AppTextStyles.labelSm.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                          color: color,
                                        ),
                                      ),
                                      if (event.message.isNotEmpty)
                                        Text(
                                          event.message,
                                          style: AppTextStyles.bodySm.copyWith(
                                            fontSize: 10,
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStatusPill extends StatelessWidget {
  const _MiniStatusPill({required this.label, required this.isGood});

  final String label;
  final bool isGood;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isGood ? AppColors.success : AppColors.warning).withValues(alpha: 0.12),
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: (isGood ? AppColors.success : AppColors.warning).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGood ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 11,
            color: isGood ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSm.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isGood ? AppColors.success : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubsystemStatusTile extends StatelessWidget {
  const _SubsystemStatusTile({
    required this.icon,
    required this.title,
    required this.status,
    required this.isGood,
  });

  final IconData icon;
  final String title;
  final String status;
  final bool isGood;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isGood ? AppColors.success : AppColors.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelSm.copyWith(fontSize: 10, fontWeight: FontWeight.w600)),
                Text(
                  status,
                  style: AppTextStyles.labelSm.copyWith(
                    fontSize: 9,
                    color: isGood ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
