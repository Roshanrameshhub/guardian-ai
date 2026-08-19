import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'app_button.dart';
import 'glass_card.dart';

/// Shows a gentle 15-second "Everything okay?" check-in dialog
/// for High Risk (60-80%) situations.
Future<void> showGentleCheckinDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String reason,
  VoidCallback? onOkConfirmed,
  VoidCallback? onNeedsHelp,
}) {
  return showModalBottomSheet(
    context: context,
    isDismissible: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _GentleCheckinSheet(
      ref: ref,
      reason: reason,
      onOkConfirmed: onOkConfirmed,
      onNeedsHelp: onNeedsHelp,
    ),
  );
}

class _GentleCheckinSheet extends StatefulWidget {
  const _GentleCheckinSheet({
    required this.ref,
    required this.reason,
    this.onOkConfirmed,
    this.onNeedsHelp,
  });

  final WidgetRef ref;
  final String reason;
  final VoidCallback? onOkConfirmed;
  final VoidCallback? onNeedsHelp;

  @override
  State<_GentleCheckinSheet> createState() => _GentleCheckinSheetState();
}

class _GentleCheckinSheetState extends State<_GentleCheckinSheet> {
  int _secondsRemaining = 15;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.md),
        child: GlassCard(
          borderColor: AppColors.warning.withValues(alpha: 0.5),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(AppIcons.shield, color: AppColors.warning, size: 28),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Everything okay?',
                style: AppTextStyles.headlineMd.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.reason,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: AppRadius.borderFull,
                ),
                child: Text(
                  'Auto-dismissing in ${_secondsRemaining}s',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: "I'M OK",
                icon: Icons.check,
                onPressed: () async {
                  _timer?.cancel();
                  if (widget.onOkConfirmed != null) widget.onOkConfirmed!();
                  
                  final falseAlarmManager = widget.ref.read(falseAlarmManagerProvider);
                  final result = await falseAlarmManager.recordCancellation(
                    triggerSource: 'GENTLE_CHECKIN',
                  );

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.message),
                        backgroundColor: AppColors.success,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'I NEED ASSISTANCE',
                icon: AppIcons.sos,
                variant: AppButtonVariant.secondary,
                onPressed: () {
                  _timer?.cancel();
                  Navigator.of(context).pop();
                  if (widget.onNeedsHelp != null) widget.onNeedsHelp!();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
