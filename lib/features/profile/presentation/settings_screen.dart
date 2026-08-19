import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/glass_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _locationSharing = true;
  bool _pushNotifications = true;
  bool _emergencySms = true;
  bool _autoGuardian = false;
  bool _aiInsights = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLow,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Settings & Privacy', style: AppTextStyles.headlineMd.copyWith(fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        children: [
          Text('PRIVACY & TRACKING', style: AppTextStyles.labelSm.copyWith(color: AppColors.primaryPulse, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('Live Location Sharing', style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text('Allow trusted contacts to view live journey progress', style: AppTextStyles.labelSm),
                  value: _locationSharing,
                  onChanged: (v) => setState(() => _locationSharing = v),
                ),
                const Divider(height: 1, color: AppColors.glassBorder),
                SwitchListTile(
                  title: Text('Auto-Start Guardian Mode', style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text('Automatically activate safety monitoring after 10:00 PM', style: AppTextStyles.labelSm),
                  value: _autoGuardian,
                  onChanged: (v) => setState(() => _autoGuardian = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('ALERTS & NOTIFICATIONS', style: AppTextStyles.labelSm.copyWith(color: AppColors.primaryPulse, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('Push Notifications', style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text('Receive heads-up safety checks and arrival confirmations', style: AppTextStyles.labelSm),
                  value: _pushNotifications,
                  onChanged: (v) => setState(() => _pushNotifications = v),
                ),
                const Divider(height: 1, color: AppColors.glassBorder),
                SwitchListTile(
                  title: Text('Emergency SMS Backup', style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text('Send cellular SMS when internet is unstable', style: AppTextStyles.labelSm),
                  value: _emergencySms,
                  onChanged: (v) => setState(() => _emergencySms = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('AI & PRIVACY CONTROLS', style: AppTextStyles.labelSm.copyWith(color: AppColors.primaryPulse, fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('AI Safety Intelligence', style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text('Generate personalized route safety insights locally', style: AppTextStyles.labelSm),
                  value: _aiInsights,
                  onChanged: (v) => setState(() => _aiInsights = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              'Guardian AI v1.2.0 • Build 2026.08',
              style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
