import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/dev_log.dart';

/// Status of core hardware and OS safety permissions.
class SafetyPermissionsStatus {
  const SafetyPermissionsStatus({
    required this.locationGranted,
    required this.backgroundLocationGranted,
    required this.microphoneGranted,
    required this.notificationGranted,
    required this.sensorsGranted,
  });

  final bool locationGranted;
  final bool backgroundLocationGranted;
  final bool microphoneGranted;
  final bool notificationGranted;
  final bool sensorsGranted;

  bool get allEssentialGranted => locationGranted && microphoneGranted && notificationGranted;
}

/// Contextual Permissions & Safety Reliability Enforcer (Phase 20).
class SafetyPermissionManager {
  /// Check current permissions status without prompting.
  Future<SafetyPermissionsStatus> checkPermissions() async {
    bool locGranted = false;
    bool bgLocGranted = false;
    bool micGranted = false;
    bool notifGranted = false;
    bool sensorsGranted = true;

    try {
      final locStatus = await Geolocator.checkPermission();
      locGranted = locStatus == LocationPermission.always || locStatus == LocationPermission.whileInUse;
      bgLocGranted = locStatus == LocationPermission.always;
    } catch (_) {}

    try {
      final micStatus = await Permission.microphone.status;
      micGranted = micStatus.isGranted;
    } catch (_) {}

    try {
      final notifStatus = await Permission.notification.status;
      notifGranted = notifStatus.isGranted;
    } catch (_) {}

    try {
      final activityStatus = await Permission.activityRecognition.status;
      sensorsGranted = activityStatus.isGranted || activityStatus.isLimited;
    } catch (_) {}

    return SafetyPermissionsStatus(
      locationGranted: locGranted,
      backgroundLocationGranted: bgLocGranted,
      microphoneGranted: micGranted,
      notificationGranted: notifGranted,
      sensorsGranted: sensorsGranted,
    );
  }

  /// Request all necessary permissions with user context.
  Future<SafetyPermissionsStatus> requestAllPermissions() async {
    DevLog.log('PERMISSIONS', 'Requesting contextual safety permissions...');

    try {
      await Geolocator.requestPermission();
    } catch (_) {}

    try {
      await Permission.microphone.request();
      await Permission.notification.request();
      await Permission.activityRecognition.request();
    } catch (_) {}

    return checkPermissions();
  }
}
