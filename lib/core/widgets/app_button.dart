import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/animation_constants.dart';
import '../theme/app_colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, sos }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final child = isLoading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: _foreground),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label, style: AppTextStyles.labelLg.copyWith(color: _foreground)),
            ],
          );

    final button = switch (variant) {
      AppButtonVariant.primary || AppButtonVariant.sos => DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: AppRadius.borderFull,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPulse.withValues(alpha: 0.45),
                blurRadius: variant == AppButtonVariant.sos ? 28 : 18,
                spreadRadius: variant == AppButtonVariant.sos ? 2 : 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: AppRadius.borderFull,
              child: SizedBox(
                height: height,
                width: expand ? double.infinity : null,
                child: Center(child: child),
              ),
            ),
          ),
        ),
      AppButtonVariant.secondary => Material(
          color: AppColors.surfaceContainerHigh,
          borderRadius: AppRadius.borderFull,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: AppRadius.borderFull,
            child: Container(
              height: height,
              width: expand ? double.infinity : null,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: AppRadius.borderFull,
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: child,
            ),
          ),
        ),
      AppButtonVariant.outline => OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(expand ? double.infinity : 0, height),
            side: const BorderSide(color: AppColors.primaryPulse),
            shape: const StadiumBorder(),
            foregroundColor: AppColors.primaryPulse,
          ),
          child: child,
        ),
      AppButtonVariant.ghost => TextButton(
          onPressed: enabled ? onPressed : null,
          child: child,
        ),
    };

    return button
        .animate(target: enabled ? 1 : 0)
        .scale(
          begin: const Offset(0.98, 0.98),
          end: const Offset(1, 1),
          duration: AppAnimations.fast,
        );
  }

  Color get _foreground {
    return switch (variant) {
      AppButtonVariant.outline || AppButtonVariant.ghost => AppColors.primaryPulse,
      _ => AppColors.white,
    };
  }
}
