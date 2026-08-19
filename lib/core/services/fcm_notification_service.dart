import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../network/api_client.dart';

/// Real Firebase Cloud Messaging push notification and local notifications manager.
class FcmNotificationService {
  FcmNotificationService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  String? _currentToken;

  String? get currentToken => _currentToken;
  bool get isInitialized => _isInitialized;

  /// Initialize local notification channels, Firebase Messaging permissions,
  /// token registration, and foreground/background listeners.
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Initialize local notifications plugin for foreground alerts
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          // Handle local notification tap
        },
      );
    } catch (_) {}

    // 2. Initialize Firebase Core safely
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final messaging = FirebaseMessaging.instance;

      // 3. Request user notification permissions
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // 4. Obtain real device FCM push token
        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) {
          _currentToken = token;
          await _registerTokenWithBackend(token);
        }

        // 5. Listen for token refresh
        messaging.onTokenRefresh.listen((newToken) async {
          _currentToken = newToken;
          await _registerTokenWithBackend(newToken);
        });

        // 6. Handle foreground push notifications
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          _showForegroundNotification(message);
        });

        // 7. Handle background notification tap
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          // Deep link navigation if payload exists
        });
      }

      _isInitialized = true;
    } catch (e) {
      // In desktop/testing environments where Google Play Services are absent,
      // FCM gracefully falls back without crashing the app.
      debugPrint('[FCM] Push notifications initialization: $e');
    }
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await _apiClient.post(
        '/notifications/device-token',
        body: {
          'token': token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
          'app_version': '1.2.0',
        },
      );
    } catch (_) {
      // Non-fatal token sync failure
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'guardian_alerts',
      'Guardian Safety Alerts',
      channelDescription: 'High-priority notifications for emergency events and check-ins',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const platformDetails = NotificationDetails(android: androidDetails);

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformDetails,
    );
  }
}
