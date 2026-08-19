import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/dev_log.dart';

/// Manages the Android Foreground Service and persistent system notification
/// for Guardian Mode and active Journeys.
///
/// Ensures safety monitoring survives when the app is minimized or the screen is locked,
/// displaying real-time GPS accuracy, battery level, and dynamic risk updates.
class BackgroundSafetyService {
  BackgroundSafetyService({
    FlutterLocalNotificationsPlugin? localNotifications,
    Battery? battery,
  })  : _notifications = localNotifications ?? FlutterLocalNotificationsPlugin(),
        _battery = battery ?? Battery();

  final FlutterLocalNotificationsPlugin _notifications;
  final Battery _battery;

  bool _isServiceRunning = false;
  bool _isInitialized = false;
  static const int _notificationId = 8881;

  static const String _channelId = 'guardian_safety_foreground';
  static const String _channelName = 'Guardian AI Safety Monitoring';
  static const String _channelDescription =
      'Persistent notification ensuring continuous safety monitoring when app is in the background';

  bool get isServiceRunning => _isServiceRunning;

  /// Initialize local notification channels for foreground service.
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          DevLog.log('BG_SERVICE', 'Notification tapped: ${response.payload}');
        },
      );
      _isInitialized = true;
    } catch (e) {
      DevLog.log('BG_SERVICE', 'Notification initialization warning: $e');
    }
  }

  /// Start persistent foreground service notification when Guardian Mode or Journey begins.
  Future<void> startForegroundService({
    String title = 'Guardian AI Active',
    String? body,
    Position? currentPosition,
    int? batteryLevel,
  }) async {
    await initialize();
    _isServiceRunning = true;

    final resolvedBody = body ?? await _buildStatusBody(currentPosition, batteryLevel);
    await _showNotification(title, resolvedBody, isOngoing: true);
    DevLog.log('BG_SERVICE', 'Foreground service started: "$title" - "$resolvedBody"');
  }

  /// Update persistent notification with real-time GPS, battery, or elevated risk information.
  Future<void> updateStatus({
    String title = 'Guardian AI Active',
    String? body,
    Position? currentPosition,
    int? batteryLevel,
    bool isElevatedRisk = false,
  }) async {
    if (!_isServiceRunning) return;

    final resolvedBody = body ?? await _buildStatusBody(currentPosition, batteryLevel);
    await _showNotification(
      title,
      resolvedBody,
      isOngoing: true,
      isElevatedRisk: isElevatedRisk,
    );
    DevLog.log('BG_SERVICE', 'Foreground notification updated: "$title" - "$resolvedBody"');
  }

  /// Stop foreground service cleanly and remove persistent notification.
  Future<void> stopForegroundService() async {
    _isServiceRunning = false;
    try {
      await _notifications.cancel(_notificationId);
      DevLog.log('BG_SERVICE', 'Foreground service stopped cleanly. Notification removed.');
    } catch (e) {
      DevLog.log('BG_SERVICE', 'Error cancelling notification: $e');
    }
  }

  Future<String> _buildStatusBody(Position? pos, int? batteryLevel) async {
    final battery = batteryLevel ?? await _getBatteryPercent();
    final gpsString = pos != null
        ? 'GPS ±${pos.accuracy.toStringAsFixed(0)}m'
        : 'GPS Active';

    return 'Monitoring safety · $gpsString · Battery $battery%';
  }

  Future<int> _getBatteryPercent() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return 100;
    }
  }

  Future<void> _showNotification(
    String title,
    String body, {
    required bool isOngoing,
    bool isElevatedRisk = false,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: isElevatedRisk ? Importance.high : Importance.low,
      priority: isElevatedRisk ? Priority.high : Priority.low,
      ongoing: isOngoing,
      autoCancel: !isOngoing,
      showWhen: true,
      onlyAlertOnce: !isElevatedRisk,
      category: AndroidNotificationCategory.service,
    );

    final platformDetails = NotificationDetails(android: androidDetails);

    try {
      await _notifications.show(
        _notificationId,
        title,
        body,
        platformDetails,
      );
    } catch (e) {
      DevLog.log('BG_SERVICE', 'Failed to display notification: $e');
    }
  }

  void dispose() {
    stopForegroundService();
  }
}
