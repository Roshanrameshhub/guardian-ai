import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/route_paths.dart';
import '../../../core/theme/animation_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/glass_card.dart';
import 'auth_controller.dart';
import 'widgets/auth_hero.dart';


class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceContainerLowest, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: ResponsivePadding(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const AuthHeroShield()
                        .animate()
                        .fadeIn(duration: AppAnimations.slow)
                        .slideY(begin: -0.08, end: 0, curve: AppAnimations.emphasized),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      AppConstants.loginHeroTagline,
                      style: AppTextStyles.headlineLg.copyWith(fontSize: 28),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 100.ms),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      AppConstants.loginSubtitle,
                      style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    GlassCard(
                      child: Column(
                        children: [
                          AppTextField(
                            label: 'Email Address',
                            controller: _email,
                            hint: 'name@company.com',
                            prefixIcon: AppIcons.email,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) =>
                                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField(
                            label: 'Password',
                            controller: _password,
                            obscureText: state.obscurePassword,
                            prefixIcon: AppIcons.lock,
                            suffixIcon: IconButton(
                              onPressed: controller.toggleObscurePassword,
                              icon: Icon(
                                state.obscurePassword
                                    ? AppIcons.visibility
                                    : AppIcons.visibilityOff,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            validator: (v) =>
                                (v == null || v.length < 6) ? 'Min 6 characters' : null,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: state.rememberMe,
                                  onChanged: (v) => controller.setRememberMe(v ?? false),
                                  activeColor: AppColors.primaryPulse,
                                  side: const BorderSide(color: AppColors.outline),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: Text(
                                  'Remember me for 30 days',
                                  style: AppTextStyles.labelSm,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: Text(
                                  'Forgot?',
                                  style: AppTextStyles.labelSm.copyWith(
                                    color: AppColors.primaryPulse,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (state.error != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              state.error!,
                              style: AppTextStyles.labelSm.copyWith(color: AppColors.error),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            label: 'Sign In',
                            icon: AppIcons.arrowForward,
                            isLoading: state.isLoading,
                            onPressed: () async {
                              if (!_formKey.currentState!.validate()) return;
                              final ok = await controller.login(
                                email: _email.text,
                                password: _password.text,
                              );
                              if (ok && context.mounted) context.go(RoutePaths.home);
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: [
                              const Expanded(child: Divider(color: AppColors.outlineVariant)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                                child: Text('OR', style: AppTextStyles.labelSm),
                              ),
                              const Expanded(child: Divider(color: AppColors.outlineVariant)),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _SocialButton(
                            label: 'Continue with Google',
                            onTap: () async {
                              final ok = await controller.signInWithGoogle();
                              if (ok && context.mounted) context.go(RoutePaths.home);
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextButton(
                            onPressed: () => context.go(RoutePaths.signUp),
                            child: Text(
                              'Create Account',
                              style: AppTextStyles.labelLg.copyWith(color: AppColors.primaryPulse),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.06, end: 0),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(AppIcons.shield, size: 16, color: AppColors.outline),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            AppConstants.loginFooter,
                            style: AppTextStyles.labelSm.copyWith(fontSize: 11),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      ],
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

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerHighest,
      borderRadius: AppRadius.borderXl,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderXl,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderXl,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Text(label, style: AppTextStyles.labelLg),
        ),
      ),
    );
  }
}
