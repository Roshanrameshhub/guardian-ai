import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';

import '../theme/app_icons.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import '../../data/dto/api_dto.dart';
import '../../providers/repository_providers.dart';
import 'app_button.dart';

enum SosDialogState {
  countdown,
  sending,
  active,
  cancelled,
  error,
}

Future<void> showEmergencySosModal({
  required BuildContext context,
  required WidgetRef ref,
  String triggerSource = 'manual',
}) {
  return showModalBottomSheet(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _EmergencySosSheet(
      ref: ref,
      triggerSource: triggerSource,
    ),
  );
}

class _EmergencySosSheet extends StatefulWidget {
  const _EmergencySosSheet({
    required this.ref,
    required this.triggerSource,
  });

  final WidgetRef ref;
  final String triggerSource;

  @override
  State<_EmergencySosSheet> createState() => _EmergencySosSheetState();
}

class _EmergencySosSheetState extends State<_EmergencySosSheet> {
  SosDialogState _state = SosDialogState.countdown;
  int _secondsRemaining = 3;
  Timer? _countdownTimer;
  String _statusMessage = '';
  String _channelStatus = '';
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        _dispatchSos();
      }
    });
  }

  Future<void> _dispatchSos() async {
    setState(() {
      _state = SosDialogState.sending;
      _statusMessage = 'Acquiring high-accuracy GPS coordinates...';
    });

    try {
      final locationService = widget.ref.read(locationServiceProvider);
      final position = await locationService.getCurrentPosition(
        timeout: const Duration(seconds: 10),
      );

      _lat = position.latitude;
      _lng = position.longitude;

      setState(() {
        _statusMessage = 'Dispatching emergency alert to Guardian AI...';
      });

      final guardianRepo = widget.ref.read(guardianRepositoryProvider);
      final response = await guardianRepo.triggerSos(
        SosRequest(
          lat: position.latitude,
          lng: position.longitude,
          triggerSource: widget.triggerSource,
          message: 'EMERGENCY SOS Triggered from device',
        ),
      );

      if (!mounted) return;

      setState(() {
        _state = SosDialogState.active;
        _statusMessage = response.message.isNotEmpty
            ? response.message
            : 'Emergency SOS recorded on server.';

        if (response.message.toLowerCase().contains('sent to')) {
          _channelStatus = 'DELIVERY CONFIRMED';
        } else if (response.message.toLowerCase().contains('not configured')) {
          _channelStatus = 'SMS NOT CONFIGURED';
        } else {
          _channelStatus = 'RECORDED';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = SosDialogState.error;
        _statusMessage = 'Failed to dispatch SOS: $e';
      });
    }
  }

  void _cancelSos() {
    _countdownTimer?.cancel();
    setState(() {
      _state = SosDialogState.cancelled;
      _statusMessage = 'SOS cancelled. No emergency notifications were sent.';
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        MediaQuery.paddingOf(context).bottom + AppSpacing.md,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withValues(alpha: 0.98),
          borderRadius: AppRadius.borderXxl,
          border: Border.all(
            color: _state == SosDialogState.countdown || _state == SosDialogState.active
                ? AppColors.error
                : AppColors.glassBorder,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.35),
              blurRadius: 40,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: AppRadius.borderFull,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_state == SosDialogState.countdown) ...[
              Text(
                'EMERGENCY SOS',
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Alert will be sent to your trusted contacts with live GPS coordinates in:',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.error, width: 3),
                ),
                child: Center(
                  child: Text(
                    '$_secondsRemaining',
                    style: AppTextStyles.displayLg.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                    begin: const Offset(0.95, 0.95),
                    end: const Offset(1.05, 1.05),
                    duration: 600.ms,
                  ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: 'CANCEL SOS',
                icon: Icons.close,
                variant: AppButtonVariant.secondary,
                onPressed: _cancelSos,
              ),
            ] else if (_state == SosDialogState.sending) ...[
              const CircularProgressIndicator(color: AppColors.error),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'DISPATCHING ALERT',
                style: AppTextStyles.headlineMd.copyWith(color: AppColors.error),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd,
              ),
            ] else if (_state == SosDialogState.active) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(AppIcons.sos, color: AppColors.error, size: 40),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'SOS ALERT ACTIVE',
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _channelStatus == 'DELIVERY CONFIRMED'
                      ? AppColors.tertiary.withValues(alpha: 0.2)
                      : AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: AppRadius.borderFull,
                ),
                child: Text(
                  _channelStatus,
                  style: AppTextStyles.labelSm.copyWith(
                    color: _channelStatus == 'DELIVERY CONFIRMED'
                        ? AppColors.tertiary
                        : AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd,
              ),
              if (_lat != null && _lng != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'GPS: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Close Window',
                onPressed: () => Navigator.pop(context),
              ),
            ] else if (_state == SosDialogState.cancelled) ...[
              const Icon(Icons.check_circle_outline, color: AppColors.tertiary, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text('SOS Cancelled', style: AppTextStyles.headlineMd),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Dismiss',
                onPressed: () => Navigator.pop(context),
              ),
            ] else if (_state == SosDialogState.error) ...[
              const Icon(AppIcons.warning, color: AppColors.error, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text('SOS Dispatch Error', style: AppTextStyles.headlineMd.copyWith(color: AppColors.error)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Dismiss',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: 'Retry SOS',
                      onPressed: _dispatchSos,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
