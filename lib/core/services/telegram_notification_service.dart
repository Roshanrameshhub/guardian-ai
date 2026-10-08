import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../utils/dev_log.dart';

/// Telegram Notification Service for Guardian AI.
///
/// Dispatches real-time emergency SOS alerts and test pings to trusted contacts via
/// the Guardian AI backend proxy (FastAPI backend -> Telegram Bot API).
///
/// NOTE: The Telegram Bot Token is never stored on the mobile device or client application.
/// It is securely managed and loaded exclusively by the backend environment (TELEGRAM_BOT_TOKEN).
abstract final class TelegramNotificationService {
  static const String botUsername = 'GuardAIAlertBot';

  static ApiClient? _customApiClient;

  @visibleForTesting
  static void setApiClient(ApiClient? client) {
    _customApiClient = client;
  }

  static ApiClient get _client => _customApiClient ?? ApiClient();

  /// Dispatches live SOS emergency alert with Google Maps coordinates to a Telegram chat
  /// through the backend proxy endpoint.
  static Future<bool> sendEmergencyAlert({
    required String chatId,
    required String contactName,
    required double lat,
    required double lng,
    String? reason,
    int? batteryLevel,
  }) async {
    final cleanChatId = chatId.trim();
    if (cleanChatId.isEmpty) return false;

    try {
      final response = await _client.post(
        ApiConstants.telegramAlert,
        body: {
          'chat_id': cleanChatId,
          'contact_name': contactName,
          'lat': lat,
          'lng': lng,
          if (reason != null) 'reason': reason,
          if (batteryLevel != null) 'battery_level': batteryLevel,
        },
      );

      final success = response['success'] == true;
      DevLog.log(
        'TELEGRAM',
        success
            ? 'Emergency alert successfully dispatched via backend to Telegram chat $cleanChatId for $contactName'
            : 'Telegram alert failed: ${response['message']}',
      );
      return success;
    } catch (e) {
      DevLog.log('TELEGRAM', 'Exception sending Telegram alert via backend: $e');
      return false;
    }
  }

  /// Sends a verification test ping to confirm Telegram bot connectivity
  /// through the backend proxy endpoint.
  static Future<bool> sendTestPing({
    required String chatId,
    required String contactName,
  }) async {
    final cleanChatId = chatId.trim();
    if (cleanChatId.isEmpty) return false;

    try {
      final response = await _client.post(
        ApiConstants.telegramTest,
        body: {
          'chat_id': cleanChatId,
          'contact_name': contactName,
        },
      );

      final success = response['success'] == true;
      DevLog.log('TELEGRAM', 'Test ping via backend to $cleanChatId result: $success');
      return success;
    } catch (e) {
      DevLog.log('TELEGRAM', 'Exception sending test ping via backend: $e');
      return false;
    }
  }
}
