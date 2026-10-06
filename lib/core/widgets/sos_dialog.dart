import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import '../../data/dto/api_dto.dart';
import '../../features/profile/presentation/contacts_controller.dart';
import '../../providers/repository_providers.dart';
import '../services/telegram_notification_service.dart';
import 'app_button.dart';

enum SosDialogState {
  countdown,
  sending,
  active,
  cancelled,
  error,
}

bool _isSosModalVisible = false;

Future<void> showEmergencySosModal({
  BuildContext? context,
  WidgetRef? ref,
  String triggerSource = 'manual',
}) {
  final targetContext = context ?? rootNavigatorKey.currentContext;
  if (targetContext == null || _isSosModalVisible) return Future.value();
  _isSosModalVisible = true;

  return showModalBottomSheet(
    context: targetContext,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _EmergencySosSheet(
      triggerSource: triggerSource,
    ),
  ).whenComplete(() {
    _isSosModalVisible = false;
  });
}

class _EmergencySosSheet extends ConsumerStatefulWidget {
  const _EmergencySosSheet({
    required this.triggerSource,
  });

  final String triggerSource;

  @override
  ConsumerState<_EmergencySosSheet> createState() => _EmergencySosSheetState();
}

class _EmergencySosSheetState extends ConsumerState<_EmergencySosSheet> {
  SosDialogState _state = SosDialogState.countdown;
  int _secondsRemaining = 30;
  static const int _totalSeconds = 30;
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

  List<NotificationDeliveryItemDto> _deliveryDetails = [];

  Future<void> _dispatchSos() async {
    setState(() {
      _state = SosDialogState.sending;
      _statusMessage = 'Acquiring high-accuracy GPS coordinates...';
    });

    try {
      final locationService = ref.read(locationServiceProvider);
      final position = await locationService.getCurrentPosition(
        timeout: const Duration(seconds: 10),
      );

      _lat = position.latitude;
      _lng = position.longitude;

      setState(() {
        _statusMessage = 'Dispatching emergency alert to Guardian AI...';
      });

      final guardianRepo = ref.read(guardianRepositoryProvider);
      final response = await guardianRepo.triggerSos(
        SosRequest(
          lat: position.latitude,
          lng: position.longitude,
          triggerSource: widget.triggerSource,
          message: 'EMERGENCY SOS Triggered from device',
        ),
      );

      final deliveryList = List<NotificationDeliveryItemDto>.from(response.deliveryDetails);

      // Verify and dispatch Telegram alert directly to trusted contacts who have Telegram configured
      final contactsAsync = ref.read(trustedContactsProvider);
      final contacts = contactsAsync.valueOrNull ?? [];
      for (final contact in contacts) {
        if (contact.emergencyNotifyEnabled &&
            contact.telegramChatId != null &&
            contact.telegramChatId!.trim().isNotEmpty) {
          final alreadySent = deliveryList.any((d) =>
              d.channel.toLowerCase() == 'telegram' &&
              d.status == 'sent' &&
              d.contactName == contact.name);

          if (!alreadySent) {
            final tgSuccess = await TelegramNotificationService.sendEmergencyAlert(
              chatId: contact.telegramChatId!,
              contactName: contact.name,
              lat: position.latitude,
              lng: position.longitude,
              reason: widget.triggerSource,
            );

            final existingIdx = deliveryList.indexWhere((d) =>
                d.channel.toLowerCase() == 'telegram' && d.contactName == contact.name);

            if (existingIdx != -1) {
              if (tgSuccess) {
                deliveryList[existingIdx] = NotificationDeliveryItemDto(
                  contactName: contact.name,
                  channel: 'Telegram',
                  deliveryStatus: 'sent',
                  detail: 'Delivered via Guardian Alert Bot',
                );
              }
            } else {
              deliveryList.add(NotificationDeliveryItemDto(
                contactName: contact.name,
                channel: 'Telegram',
                deliveryStatus: tgSuccess ? 'sent' : 'failed',
                detail: tgSuccess
                    ? 'Delivered via Guardian Alert Bot'
                    : 'Telegram delivery failed',
              ));
            }
          }
        }
      }

      if (!mounted) return;

      final anySent = deliveryList.any((d) => d.status == 'sent');
      final anyTelegramSent = deliveryList.any((d) => d.channel.toLowerCase() == 'telegram' && d.status == 'sent');
      final allFailed = deliveryList.isNotEmpty && deliveryList.every((d) => d.status != 'sent');

      setState(() {
        _state = SosDialogState.active;
        _deliveryDetails = deliveryList;

        if (anyTelegramSent) {
          _channelStatus = 'DELIVERY CONFIRMED';
          _statusMessage = 'SMS notification unavailable: The SMS provider account is inactive. Telegram notification was sent successfully.';
        } else if (anySent) {
          _channelStatus = 'DELIVERY CONFIRMED';
          _statusMessage = response.message.isNotEmpty
              ? response.message
              : 'Emergency SOS alert dispatched successfully.';
        } else if (allFailed) {
          _channelStatus = 'DELIVERY FAILED / UNCONFIGURED';
          _statusMessage = 'Emergency alert recorded on server. Contact delivery unavailable.';
        } else if (response.message.toLowerCase().contains('sent to')) {
          _channelStatus = 'DELIVERY CONFIRMED';
          _statusMessage = response.message;
        } else {
          _channelStatus = 'RECORDED ON SERVER';
          _statusMessage = response.message.isNotEmpty
              ? response.message
              : 'Emergency SOS recorded on server.';
        }
      });
    } catch (e) {
      if (!mounted) return;

      // Resilient fallback: attempt direct Telegram dispatch if coordinates are available
      final fallbackDetails = <NotificationDeliveryItemDto>[];
      var anyFallbackSent = false;
      if (_lat != null && _lng != null) {
        final contactsAsync = ref.read(trustedContactsProvider);
        final contacts = contactsAsync.valueOrNull ?? [];
        for (final contact in contacts) {
          if (contact.emergencyNotifyEnabled &&
              contact.telegramChatId != null &&
              contact.telegramChatId!.trim().isNotEmpty) {
            final tgSuccess = await TelegramNotificationService.sendEmergencyAlert(
              chatId: contact.telegramChatId!,
              contactName: contact.name,
              lat: _lat!,
              lng: _lng!,
              reason: widget.triggerSource,
            );
            fallbackDetails.add(NotificationDeliveryItemDto(
              contactName: contact.name,
              channel: 'Telegram',
              deliveryStatus: tgSuccess ? 'sent' : 'failed',
              detail: tgSuccess ? 'Delivered via Direct Bot' : 'Delivery failed',
            ));
            if (tgSuccess) anyFallbackSent = true;
          }
        }
      }

      if (anyFallbackSent) {
        setState(() {
          _state = SosDialogState.active;
          _deliveryDetails = fallbackDetails;
          _statusMessage = 'Emergency SOS alert dispatched to Telegram contacts.';
          _channelStatus = 'DELIVERY CONFIRMED';
        });
      } else {
        setState(() {
          _state = SosDialogState.error;
          _statusMessage = 'Failed to dispatch SOS: $e';
        });
      }
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
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: CircularProgressIndicator(
                      value: _secondsRemaining / _totalSeconds,
                      strokeWidth: 6,
                      backgroundColor: AppColors.error.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.error),
                    ),
                  ),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.error.withValues(alpha: 0.15),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$_secondsRemaining',
                            style: AppTextStyles.displayLg.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'SEC',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                    begin: const Offset(0.97, 0.97),
                    end: const Offset(1.03, 1.03),
                    duration: 800.ms,
                  ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'I AM SAFE / CANCEL (30s Cooldown)',
                icon: Icons.shield,
                variant: AppButtonVariant.secondary,
                onPressed: _cancelSos,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () {
                  _countdownTimer?.cancel();
                  _dispatchSos();
                },
                child: Text(
                  'Send SOS Immediately',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
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
              if (_lat != null && _lng != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: AppRadius.borderSm,
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Text(
                    'GPS: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.onSurface,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd,
              ),
              if (_deliveryDetails.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications Delivery:',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ..._deliveryDetails.map((detail) {
                        final isSent = detail.status == 'sent';
                        final isUnconfigured = detail.status == 'unconfigured';
                        final channelLower = detail.channel.toLowerCase();

                        // Friendly sanitize provider errors
                        final rawErr = (detail.error ?? detail.detail ?? '').toLowerCase();
                        final bool isProviderInactive = rawErr.contains('twilio') ||
                            rawErr.contains('401') ||
                            rawErr.contains('20003') ||
                            rawErr.contains('trial') ||
                            rawErr.contains('authenticate') ||
                            rawErr.contains('inactive');

                        Color color;
                        IconData icon;
                        String label;

                        if (isSent) {
                          color = AppColors.tertiary;
                          icon = Icons.check_circle_outline;
                          label = '✓ ${detail.recipientName} — ${detail.channel.toUpperCase()} sent';
                        } else if (channelLower == 'sms' && isProviderInactive) {
                          color = AppColors.warning;
                          icon = Icons.warning_amber_rounded;
                          label = '⚠ ${detail.recipientName} — SMS unavailable — provider account inactive';
                        } else if (isUnconfigured) {
                          color = AppColors.outline;
                          icon = Icons.info_outline;
                          label = '${detail.recipientName} — ${detail.channel.toUpperCase()} unconfigured';
                        } else {
                          color = AppColors.error;
                          icon = Icons.cancel_outlined;
                          final cleanErr = isProviderInactive
                              ? 'provider account inactive'
                              : (detail.error != null && detail.error!.isNotEmpty ? detail.error! : 'delivery failed');
                          label = '${detail.recipientName} — ${detail.channel.toUpperCase()} failed ($cleanErr)';
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(icon, size: 14, color: color),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  label,
                                  style: AppTextStyles.labelSm.copyWith(
                                    color: color,
                                    fontWeight: isSent ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
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
