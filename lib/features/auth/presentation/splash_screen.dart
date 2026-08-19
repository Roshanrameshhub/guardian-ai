import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/dev_log.dart';
import '../../../providers/repository_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1400), _checkAuthState);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkAuthState() async {
    if (!mounted) return;
    DevLog.auth('Session restoration started');

    try {
      final tokenStorage = ref.read(tokenStorageServiceProvider);
      final token = await tokenStorage.getAccessToken();
      final hasToken = token != null && token.trim().isNotEmpty;
      DevLog.auth('Stored token exists: $hasToken');

      if (hasToken) {
        final apiClient = ref.read(apiClientProvider);
        apiClient.setAuthToken(token);

        // Validate session against backend profile endpoint
        try {
          final profileRepo = ref.read(profileRepositoryProvider);
          await profileRepo.fetchProfile();
          DevLog.auth('Session validated successfully — routing to Home');
          if (mounted) {
            context.go(RoutePaths.home);
          }
          return;
        } catch (e) {
          DevLog.auth('Session validation warning: $e');
          // If auth token is explicitly expired/unauthorized (401), clear and go to Login
          if (e.toString().contains('401') || e.toString().toLowerCase().contains('unauthorized')) {
            await tokenStorage.clear();
            apiClient.setAuthToken(null);
            if (mounted) {
              context.go(RoutePaths.login);
            }
            return;
          }
          // On network/offline failure, still proceed with saved session
          if (mounted) {
            context.go(RoutePaths.home);
          }
          return;
        }
      } else {
        DevLog.auth('No stored token — routing to Login');
        if (mounted) {
          context.go(RoutePaths.login);
        }
      }
    } catch (e) {
      DevLog.auth('Session check error', error: e);
      if (mounted) {
        context.go(RoutePaths.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.background,
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              AppColors.primaryPulse.withValues(alpha: 0.18),
              AppColors.background,
              AppColors.auraGlow.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryPulse.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.primaryPulse.withValues(alpha: 0.6),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPulse.withValues(alpha: 0.35),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    AppIcons.shieldFilled,
                    color: AppColors.primaryPulse,
                    size: 44,
                  ),
                ),
              )
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.easeOutBack)
                  .fadeIn(),
              const SizedBox(height: AppSpacing.xl),
              Text(
                AppConstants.appName,
                style: AppTextStyles.headlineLg.copyWith(
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurface,
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppConstants.loginHeroTagline,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ).animate().fadeIn(delay: 350.ms),
              const SizedBox(height: AppSpacing.xxl),
              const CircularProgressIndicator(
                color: AppColors.primaryPulse,
                strokeWidth: 2.5,
              ).animate().fadeIn(delay: 500.ms),
            ],
          ),
        ),
      ),
    );
  }
}
