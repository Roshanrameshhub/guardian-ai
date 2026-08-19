import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';
import 'app_button.dart';

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  String? title,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          MediaQuery.paddingOf(context).bottom + AppSpacing.floatingOffset,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer.withValues(alpha: 0.95),
            borderRadius: AppRadius.borderXxl,
            border: Border.all(color: AppColors.glassBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.4),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: AppRadius.borderFull,
                  ),
                ),
              ),
              if (title != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(title, style: AppTextStyles.headlineMd.copyWith(fontSize: 20)),
              ],
              const SizedBox(height: AppSpacing.lg),
              child,
            ],
          ),
        ),
      );
    },
  );
}

Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderXxl),
        title: Text(title, style: AppTextStyles.headlineMd.copyWith(fontSize: 20)),
        content: Text(message, style: AppTextStyles.bodyMd),
        actions: [
          AppButton(
            label: cancelLabel,
            onPressed: () => Navigator.pop(context, false),
            variant: AppButtonVariant.ghost,
            expand: false,
            height: 44,
          ),
          AppButton(
            label: confirmLabel,
            onPressed: () => Navigator.pop(context, true),
            expand: false,
            height: 44,
          ),
        ],
      );
    },
  );
}
