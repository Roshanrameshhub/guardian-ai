import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';
import '../theme/text_styles.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.validator,
    this.lightFill = false,
    this.textInputAction,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool lightFill;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          textInputAction: textInputAction,
          style: AppTextStyles.bodyMd.copyWith(
            color: lightFill ? AppColors.surfaceContainerLowest : AppColors.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(
                    prefixIcon,
                    color: lightFill
                        ? AppColors.surfaceContainerHigh
                        : AppColors.onSurfaceVariant,
                  ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: lightFill ? AppColors.white : AppColors.surfaceContainerLowest,
            border: const OutlineInputBorder(
              borderRadius: AppRadius.borderXl,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.borderXl,
              borderSide: lightFill
                  ? BorderSide.none
                  : BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: AppRadius.borderXl,
              borderSide: BorderSide(color: AppColors.primaryPulse, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
