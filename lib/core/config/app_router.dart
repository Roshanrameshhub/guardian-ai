import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/route_paths.dart';
import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/text_styles.dart';
import '../widgets/app_bottom_nav.dart';
import '../../domain/entities/entities.dart';
import '../../features/activity/presentation/activity_screen.dart';
import '../../features/activity/presentation/notifications_screen.dart';
import '../../features/activity/presentation/safety_insights_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/diagnostics/presentation/diagnostics_screen.dart';
import '../../features/guardian/presentation/guardian_screen.dart';
import '../../features/home/presentation/fake_call_screen.dart';
import '../../features/home/presentation/fake_message_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/journey/presentation/journey_confirmation_screen.dart';
import '../../features/journey/presentation/journey_summary_screen.dart';
import '../../features/journey/presentation/live_journey_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/settings_screen.dart';
import '../../features/profile/presentation/trusted_contacts_screen.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: RoutePaths.splash,
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.contacts,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const TrustedContactsScreen(),
      ),
      GoRoute(
        path: RoutePaths.fakeCall,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const FakeCallScreen(),
      ),
      GoRoute(
        path: RoutePaths.fakeMessage,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const FakeMessageScreen(),
      ),
      GoRoute(
        path: RoutePaths.journeyConfirmation,
        parentNavigatorKey: _rootKey,
        builder: (context, state) {
          if (state.extra is Map<String, dynamic>) {
            final extra = state.extra! as Map<String, dynamic>;
            return JourneyConfirmationScreen(
              destinationName: extra['destinationName'] as String? ?? 'Destination',
              destLat: (extra['destLat'] as num?)?.toDouble() ?? 13.0827,
              destLng: (extra['destLng'] as num?)?.toDouble() ?? 80.2707,
              originLat: (extra['originLat'] as num?)?.toDouble() ?? 12.9716,
              originLng: (extra['originLng'] as num?)?.toDouble() ?? 80.2435,
              routeName: extra['routeName'] as String? ?? 'Safer Route',
              safetyScore: (extra['safetyScore'] as num?)?.toInt() ?? 92,
              estimatedDistanceKm: (extra['estimatedDistanceKm'] as num?)?.toDouble() ?? 3.2,
              estimatedMinutes: (extra['estimatedMinutes'] as num?)?.toInt() ?? 18,
              routePoints: (extra['routePoints'] as List<LatLngPoint>?) ?? const [],
            );
          }
          return const JourneyConfirmationScreen();
        },
      ),
      GoRoute(
        path: RoutePaths.liveJourney,
        parentNavigatorKey: _rootKey,
        builder: (context, state) {
          if (state.extra is Map<String, dynamic>) {
            final extra = state.extra! as Map<String, dynamic>;
            return LiveJourneyScreen(
              journeyId: extra['journeyId'] as String?,
              destinationName: extra['destinationName'] as String? ?? 'Home',
              destLat: (extra['destLat'] as num?)?.toDouble() ?? 13.0827,
              destLng: (extra['destLng'] as num?)?.toDouble() ?? 80.2707,
              routePoints: (extra['routePoints'] as List<LatLngPoint>?) ?? const [],
              safetyScore: (extra['safetyScore'] as num?)?.toInt() ?? 88,
              estimatedDistanceKm: (extra['estimatedDistanceKm'] as num?)?.toDouble() ?? 3.2,
              estimatedMinutes: (extra['estimatedMinutes'] as num?)?.toInt() ?? 15,
            );
          }
          return const LiveJourneyScreen();
        },
      ),
      GoRoute(
        path: RoutePaths.journeySummary,
        parentNavigatorKey: _rootKey,
        builder: (context, state) {
          if (state.extra is Map<String, dynamic>) {
            final extra = state.extra! as Map<String, dynamic>;
            return JourneySummaryScreen(
              destinationName: extra['destinationName'] as String? ?? 'Destination',
              durationText: extra['durationText'] as String? ?? '18:30',
              distanceKm: (extra['distanceKm'] as num?)?.toDouble() ?? 3.2,
              avgSpeedKmh: (extra['avgSpeedKmh'] as num?)?.toDouble() ?? 4.6,
              safetyScore: (extra['safetyScore'] as num?)?.toInt() ?? 94,
              incidentCount: (extra['incidentCount'] as num?)?.toInt() ?? 0,
            );
          }
          return const JourneySummaryScreen();
        },
      ),
      GoRoute(
        path: RoutePaths.safetyInsights,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SafetyInsightsScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: RoutePaths.diagnostics,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const DiagnosticsScreen(),
      ),

      ShellRoute(
        navigatorKey: _shellKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.home,
            pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: RoutePaths.map,
            pageBuilder: (context, state) => const NoTransitionPage(child: MapScreen()),
          ),
          GoRoute(
            path: RoutePaths.guardian,
            pageBuilder: (context, state) => const NoTransitionPage(child: GuardianScreen()),
          ),
          GoRoute(
            path: RoutePaths.activity,
            pageBuilder: (context, state) => const NoTransitionPage(child: ActivityScreen()),
          ),
          GoRoute(
            path: RoutePaths.profile,
            pageBuilder: (context, state) => const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.warning, color: AppColors.primaryPulse, size: 40),
            const SizedBox(height: 12),
            Text('Route not found', style: AppTextStyles.headlineMd),
            TextButton(
              onPressed: () => context.go(RoutePaths.home),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
