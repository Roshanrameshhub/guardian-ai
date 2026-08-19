import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/core/constants/app_constants.dart';
import 'package:guardian_ai/core/constants/route_paths.dart';

void main() {
  test('AppConstants contains correct Guardian AI branding and copy', () {
    expect(AppConstants.appName, 'Guardian AI');
    expect(AppConstants.appVersion, '1.2.0');
    expect(AppConstants.loginHeroTagline, 'Your Safety Starts Here');
  });

  test('RoutePaths contains all primary reconstructed screen routes', () {
    expect(RoutePaths.splash, '/');
    expect(RoutePaths.home, '/home');
    expect(RoutePaths.login, '/login');
    expect(RoutePaths.map, '/map');
    expect(RoutePaths.guardian, '/guardian');
    expect(RoutePaths.journeyConfirmation, '/journey-confirmation');
    expect(RoutePaths.liveJourney, '/live-journey');
    expect(RoutePaths.journeySummary, '/journey-summary');
    expect(RoutePaths.activity, '/activity');
    expect(RoutePaths.profile, '/profile');
  });
}
