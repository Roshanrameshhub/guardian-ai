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

  /// Proactively prompt for missing safety permissions upon entering the app.
  Future<SafetyPermissionsStatus> requestStartupPermissions() async {
    DevLog.log('PERMISSIONS', '[STARTUP] Checking and requesting essential safety permissions...');

    // 1. Location permission
    try {
      var locStatus = await Geolocator.checkPermission();
      if (locStatus == LocationPermission.denied) {
        DevLog.log('PERMISSIONS', '[STARTUP] Requesting Location permission...');
        locStatus = await Geolocator.requestPermission();
      }
      DevLog.log('PERMISSIONS', '[STARTUP] Location status = $locStatus');
    } catch (e) {
      DevLog.log('PERMISSIONS', '[STARTUP] Error checking location permission: $e');
    }

    // 2. Microphone permission (Voice Distress)
    try {
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        DevLog.log('PERMISSIONS', '[STARTUP] Requesting Microphone permission...');
        await Permission.microphone.request();
      }
    } catch (e) {
      DevLog.log('PERMISSIONS', '[STARTUP] Error checking microphone permission: $e');
    }

    // 3. Notification permission (Foreground alerts & background updates)
    try {
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        DevLog.log('PERMISSIONS', '[STARTUP] Requesting Notification permission...');
        await Permission.notification.request();
      }
    } catch (e) {
      DevLog.log('PERMISSIONS', '[STARTUP] Error checking notification permission: $e');
    }

    // 4. Activity Recognition (Sensor kinematics)
    try {
      final activityStatus = await Permission.activityRecognition.status;
      if (!activityStatus.isGranted) {
        await Permission.activityRecognition.request();
      }
    } catch (_) {}

    final finalStatus = await checkPermissions();
    DevLog.log('PERMISSIONS', '[STARTUP] Result: Location=${finalStatus.locationGranted}, Mic=${finalStatus.microphoneGranted}, Notif=${finalStatus.notificationGranted}');
    return finalStatus;
  }

  /// Request all necessary permissions with user context.
  Future<SafetyPermissionsStatus> requestAllPermissions() async {
    return requestStartupPermissions();
  }
}
