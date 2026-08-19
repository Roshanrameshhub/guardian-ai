import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../../domain/entities/entities.dart';

class TrustedContactsRow extends StatelessWidget {
  const TrustedContactsRow({
    super.key,
    required this.contacts,
    required this.onEdit,
  });

  final List<TrustedContactEntity> contacts;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text('Trusted Contacts', style: AppTextStyles.headlineMd.copyWith(fontSize: 18)),
            const Spacer(),
            TextButton(
              onPressed: onEdit,
              child: Text(
                'Edit',
                style: AppTextStyles.labelLg.copyWith(color: AppColors.primaryPulse),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: contacts.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              if (index == contacts.length) {
                return GestureDetector(
                  onTap: onEdit,
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceContainerHighest,
                          border: Border.all(color: AppColors.glassBorder),
                        ),
                        child: const Icon(AppIcons.add, color: AppColors.primaryPulse),
                      ),
                      const SizedBox(height: 6),
                      Text('Add', style: AppTextStyles.labelSm),
                    ],
                  ),
                );
              }
              final c = contacts[index];
              return GestureDetector(
                onTap: onEdit,
                child: Column(
                  children: [
                    AppAvatar(
                      imageUrl: c.avatarUrl,
                      size: 56,
                      showOnline: true,
                      isOnline: c.isOnline,
                    ),
                    const SizedBox(height: 6),
                    Text(c.name, style: AppTextStyles.labelSm),
                  ],
                ),
              );

            },
          ),
        ),
      ],
    );
  }
}
