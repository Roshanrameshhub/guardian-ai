import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../domain/entities/entities.dart';
import 'contacts_controller.dart';

class TrustedContactsScreen extends ConsumerWidget {
  const TrustedContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(trustedContactsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Trusted Contacts', style: AppTextStyles.headlineMd.copyWith(fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.userPlus, color: AppColors.primaryPulse),
            tooltip: 'Add Contact',
            onPressed: () => _showAddContactOptions(context, ref),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryPulse.withValues(alpha: 0.08),
              AppColors.background,
            ],
          ),
        ),
        child: contactsAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorStateView(
            message: e.toString(),
            onRetry: () => ref.invalidate(trustedContactsProvider),
          ),
          data: (contacts) {
            if (contacts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPulse.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(AppIcons.shieldFilled, color: AppColors.primaryPulse, size: 48),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text('No Trusted Contacts Yet', style: AppTextStyles.headlineMd),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Add trusted family or friends who will receive instant SOS alerts and live location updates during emergencies.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'Add First Contact',
                        icon: AppIcons.userPlus,
                        onPressed: () => _showAddContactOptions(context, ref),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(trustedContactsProvider),
              color: AppColors.primaryPulse,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                itemCount: contacts.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return _ContactCard(contact: contact)
                      .animate()
                      .fadeIn(delay: (40 * index).ms)
                      .slideY(begin: 0.05, end: 0);
                },
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: AppButton(
            label: 'Add Trusted Contact',
            icon: AppIcons.userPlus,
            onPressed: () => _showAddContactOptions(context, ref),
          ),
        ),
      ),
    );
  }

  void _showAddContactOptions(BuildContext context, WidgetRef ref) {
    showAppBottomSheet(
      context: context,
      title: 'Add Trusted Contact',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primaryPulse.withValues(alpha: 0.15),
                borderRadius: AppRadius.borderMd,
              ),
              child: const Icon(Icons.contacts, color: AppColors.primaryPulse),
            ),
            title: Text('Pick from Address Book', style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text('Select one contact securely from your phone', style: AppTextStyles.labelSm),
            onTap: () async {
              Navigator.pop(context);
              try {
                final picked = await ref.read(contactsControllerProvider.notifier).pickSingleDeviceContact();
                if (picked != null && context.mounted) {
                  _showContactFormSheet(
                    context: context,
                    ref: ref,
                    initialName: picked.name,
                    initialPhone: picked.phone,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
                  );
                }
              }
            },
          ),
          const Divider(color: AppColors.outlineVariant),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: AppRadius.borderMd,
              ),
              child: const Icon(Icons.edit, color: AppColors.onSurfaceVariant),
            ),
            title: Text('Enter Contact Details Manually', style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text('Type name, phone, and emergency preferences', style: AppTextStyles.labelSm),
            onTap: () {
              Navigator.pop(context);
              _showContactFormSheet(context: context, ref: ref);
            },
          ),
        ],
      ),
    );
  }

  static void _showContactFormSheet({
    required BuildContext context,
    required WidgetRef ref,
    TrustedContactEntity? existingContact,
    String? initialName,
    String? initialPhone,
  }) {
    showAppBottomSheet(
      context: context,
      title: existingContact != null ? 'Edit Trusted Contact' : 'New Trusted Contact',
      child: _ContactForm(
        existingContact: existingContact,
        initialName: initialName,
        initialPhone: initialPhone,
      ),
    );
  }
}

class _ContactCard extends ConsumerWidget {
  const _ContactCard({required this.contact});

  final TrustedContactEntity contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.surfaceContainerHighest,
                backgroundImage: contact.avatarUrl.isNotEmpty ? NetworkImage(contact.avatarUrl) : null,
                child: contact.avatarUrl.isEmpty
                    ? Text(
                        contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                        style: AppTextStyles.headlineMd.copyWith(color: AppColors.primaryPulse, fontSize: 18),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: contact.isOnline ? AppColors.tertiary : AppColors.outline,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surfaceContainer, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        contact.name,
                        style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPulse.withValues(alpha: 0.15),
                        borderRadius: AppRadius.borderFull,
                      ),
                      child: Text(
                        contact.relationshipLabel,
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.primaryPulse,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(contact.phone, style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (contact.emergencyNotifyEnabled)
                      const _Badge(label: 'SOS Alerts', color: AppColors.error, icon: Icons.notifications_active)
                    else
                      const _Badge(label: 'No SOS', color: AppColors.outline, icon: Icons.notifications_off),
                    const SizedBox(width: AppSpacing.sm),
                    if (contact.locationShareEnabled)
                      const _Badge(label: 'Live Track', color: AppColors.tertiary, icon: Icons.location_on),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.onSurfaceVariant),
            color: AppColors.surfaceContainerHigh,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
            onSelected: (value) async {
              if (value == 'edit') {
                TrustedContactsScreen._showContactFormSheet(
                  context: context,
                  ref: ref,
                  existingContact: contact,
                );
              } else if (value == 'delete') {
                final confirmed = await showConfirmDialog(
                  context: context,
                  title: 'Remove Contact',
                  message: 'Are you sure you want to remove ${contact.name} from your trusted contacts?',
                  confirmLabel: 'Remove',
                );
                if (confirmed == true) {
                  await ref.read(contactsControllerProvider.notifier).deleteContact(contact.id);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: AppColors.onSurface, size: 18),
                    SizedBox(width: AppSpacing.sm),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                    SizedBox(width: AppSpacing.sm),
                    Text('Remove', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.icon});
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label, style: AppTextStyles.labelSm.copyWith(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

class _ContactForm extends ConsumerStatefulWidget {
  const _ContactForm({
    this.existingContact,
    this.initialName,
    this.initialPhone,
  });

  final TrustedContactEntity? existingContact;
  final String? initialName;
  final String? initialPhone;

  @override
  ConsumerState<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends ConsumerState<_ContactForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late String _relationship;
  late bool _emergencyNotify;
  late bool _locationShare;
  late int _priority;
  bool _submitting = false;

  final _relationships = ['Mom', 'Dad', 'Partner', 'Sibling', 'Friend', 'Colleague', 'Other'];

  @override
  void initState() {
    super.initState();
    final c = widget.existingContact;
    _nameCtrl = TextEditingController(text: c?.name ?? widget.initialName ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? widget.initialPhone ?? '');
    _relationship = c?.relationshipLabel ?? 'Friend';
    if (!_relationships.contains(_relationship)) {
      _relationship = 'Other';
    }
    _emergencyNotify = c?.emergencyNotifyEnabled ?? true;
    _locationShare = c?.locationShareEnabled ?? false;
    _priority = c?.priority ?? 1;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final notifier = ref.read(contactsControllerProvider.notifier);
      if (widget.existingContact != null) {
        final updated = widget.existingContact!.copyWith(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          relationshipLabel: _relationship,
          emergencyNotifyEnabled: _emergencyNotify,
          locationShareEnabled: _locationShare,
          priority: _priority,
        );
        await notifier.updateContact(updated);
      } else {
        final newContact = TrustedContactEntity(
          id: '',
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          avatarUrl: '',
          isOnline: false,
          relationshipLabel: _relationship,
          emergencyNotifyEnabled: _emergencyNotify,
          locationShareEnabled: _locationShare,
          priority: _priority,
        );
        await notifier.addContact(newContact);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingContact != null ? 'Contact updated.' : 'Contact added to Trusted Circle.'),
            backgroundColor: AppColors.tertiary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'Full Name',
              controller: _nameCtrl,
              hint: 'e.g. Mom, Alex Smith',
              prefixIcon: Icons.person_outline,
              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Phone Number',
              controller: _phoneCtrl,
              hint: 'e.g. +91 98765 43210',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
              validator: (v) => v == null || v.trim().length < 5 ? 'Valid phone number is required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Relationship', style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _relationships.map((rel) {
                final selected = _relationship == rel;
                return ChoiceChip(
                  label: Text(rel),
                  selected: selected,
                  selectedColor: AppColors.primaryPulse,
                  backgroundColor: AppColors.surfaceContainerLowest,
                  labelStyle: AppTextStyles.labelSm.copyWith(
                    color: selected ? AppColors.white : AppColors.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _relationship = rel);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Notify on Emergency SOS', style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text('Send automatic SMS alert with your live GPS location', style: AppTextStyles.labelSm),
              activeTrackColor: AppColors.primaryPulse,
              value: _emergencyNotify,
              onChanged: (v) => setState(() => _emergencyNotify = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Share Live Location on Journey', style: AppTextStyles.bodyMd.copyWith(fontWeight: FontWeight.w600)),
              subtitle: Text('Allow contact to view live tracking during active Guardian walk', style: AppTextStyles.labelSm),
              activeTrackColor: AppColors.tertiary,
              value: _locationShare,
              onChanged: (v) => setState(() => _locationShare = v),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: widget.existingContact != null ? 'Save Changes' : 'Add to Trusted Circle',
              isLoading: _submitting,
              onPressed: _submit,
            ),

          ],
        ),
      ),
    );
  }
}
