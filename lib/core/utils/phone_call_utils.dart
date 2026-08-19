import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/text_styles.dart';

/// Helper utility to safely initiate phone calls via url_launcher with user-facing fallback.
class PhoneCallUtils {
  const PhoneCallUtils._();

  /// Cleans a phone number and launches the native dialer.
  /// If device cannot place calls (e.g. tablet, emulator, or blocked permission),
  /// displays a non-crashing SnackBar notice.
  static Future<bool> launchCall(BuildContext context, String rawNumber) async {
    // Extract first number if multiple separated by semicolon/slash
    final cleaned = rawNumber
        .split(RegExp(r'[;,/]'))
        .first
        .replaceAll(RegExp(r'[^\d+]'), '')
        .trim();

    if (cleaned.isEmpty) {
      if (context.mounted) {
        _showNotice(context, 'Invalid phone number format: "$rawNumber"');
      }
      return false;
    }

    final uri = Uri(scheme: 'tel', path: cleaned);

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Attempt direct launch if canLaunchUrl fails on some Android 11+ OEM layers
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched && context.mounted) {
          _showNotice(context, 'Unable to launch phone dialer for $cleaned. Dial manually.');
        }
        return launched;
      }
    } catch (e) {
      if (context.mounted) {
        _showNotice(context, 'Phone dialer unavailable on this device ($cleaned)');
      }
      return false;
    }
  }

  static void _showNotice(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceContainerHighest,
        content: Text(
          message,
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: AppColors.primaryPulse,
          onPressed: () {},
        ),
      ),
    );
  }
}
