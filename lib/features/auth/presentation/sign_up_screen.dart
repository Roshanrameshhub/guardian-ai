import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/route_paths.dart';
import '../../../core/theme/animation_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import 'auth_controller.dart';
import 'widgets/auth_hero.dart';


class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.background,
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 1.1,
            colors: [
              AppColors.primaryPulse.withValues(alpha: 0.12),
              AppColors.auraGlow.withValues(alpha: 0.08),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: ResponsivePadding(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const AuthHeroShield(compact: true)
                        .animate()
                        .fadeIn(duration: AppAnimations.slow),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      AppConstants.signUpTitle,
                      style: AppTextStyles.headlineLg.copyWith(fontSize: 28),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      AppConstants.signUpSubtitle,
                      style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    AppTextField(
                      label: 'Full Name',
                      controller: _name,
                      hint: 'John Doe',
                      prefixIcon: AppIcons.person,
                      lightFill: true,
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Email Address',
                      controller: _email,
                      hint: 'john@example.com',
                      prefixIcon: AppIcons.email,
                      lightFill: true,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Phone Number',
                      controller: _phone,
                      hint: '+1 (555) 000-0000',
                      prefixIcon: AppIcons.phone,
                      lightFill: true,
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.length < 8) ? 'Enter a valid phone' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Password',
                      controller: _password,
                      prefixIcon: AppIcons.lock,
                      lightFill: true,
                      obscureText: state.obscurePassword,
                      suffixIcon: IconButton(
                        onPressed: controller.toggleObscurePassword,
                        icon: Icon(
                          state.obscurePassword ? AppIcons.visibility : AppIcons.visibilityOff,
                          color: AppColors.surfaceContainerHigh,
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Min 6 characters' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Confirm',
                      controller: _confirm,
                      prefixIcon: AppIcons.shield,
                      lightFill: true,
                      obscureText: state.obscureConfirm,
                      suffixIcon: IconButton(
                        onPressed: controller.toggleObscureConfirm,
                        icon: Icon(
                          state.obscureConfirm ? AppIcons.visibility : AppIcons.visibilityOff,
                          color: AppColors.surfaceContainerHigh,
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 6) ? 'Min 6 characters' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: state.agreedToTerms,
                          onChanged: (v) => controller.setAgreedToTerms(v ?? false),
                          activeColor: AppColors.primaryPulse,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text.rich(
                              TextSpan(
                                text: 'I agree to the ',
                                style: AppTextStyles.labelSm,
                                children: [
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: AppTextStyles.labelSm.copyWith(
                                      color: AppColors.tertiary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    recognizer: TapGestureRecognizer()..onTap = () {},
                                  ),
                                  const TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Terms of Service',
                                    style: AppTextStyles.labelSm.copyWith(
                                      color: AppColors.tertiary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    recognizer: TapGestureRecognizer()..onTap = () {},
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Text(
                          state.error!,
                          style: AppTextStyles.labelSm.copyWith(color: AppColors.error),
                        ),
                      ),
                    AppButton(
                      label: 'Create Account',
                      isLoading: state.isLoading,
                      onPressed: () async {
                        if (kDebugMode) {
                          // ignore: avoid_print
                          print('[REGISTER] button pressed');
                        }
                        if (!_formKey.currentState!.validate()) {
                          if (kDebugMode) {
                            // ignore: avoid_print
                            print('[REGISTER] form validation failed — check field errors above');
                          }
                          return;
                        }
                        if (kDebugMode) {
                          // ignore: avoid_print
                          print('[REGISTER] form validation passed');
                          // ignore: avoid_print
                          print('[REGISTER] agreedToTerms=${state.agreedToTerms}');
                        }
                        final ok = await controller.register(
                          fullName: _name.text,
                          email: _email.text,
                          phone: _phone.text,
                          password: _password.text,
                          confirmPassword: _confirm.text,
                        );
                        // Scroll up so error banner is visible if registration failed
                        if (!ok && _scrollController.hasClients) {
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        }
                        if (ok && context.mounted) context.go(RoutePaths.home);
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text.rich(
                      TextSpan(
                        text: 'Already have an account? ',
                        style: AppTextStyles.bodyMd,
                        children: [
                          TextSpan(
                            text: 'Sign In',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.primaryPulse,
                              fontWeight: FontWeight.w700,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => context.go(RoutePaths.login),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
