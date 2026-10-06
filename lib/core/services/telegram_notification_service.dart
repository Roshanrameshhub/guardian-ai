import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/dev_log.dart';

/// Direct Telegram Notification Service for Guardian AI.
///
/// Dispatches real-time emergency SOS alerts and test pings directly to
/// the Guardian AI Alert Bot (@GuardAIAlertBot) on Telegram.
abstract final class TelegramNotificationService {
  static const String botToken = '8820326376:AAFj5gQak0weWbzQjp18XGN2ncmSnBuTh8Q';
  static const String botUsername = 'GuardAIAlertBot';

  /// Dispatches live SOS emergency alert with Google Maps coordinates to a Telegram chat.
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
      final url = Uri.parse('https://api.telegram.org/bot$botToken/sendMessage');
      final mapsLink = 'https://maps.google.com/?q=$lat,$lng';
      final nowStr = DateTime.now().toLocal().toString().split('.').first;

      final text = '🚨 *GUARDIAN AI EMERGENCY SOS* 🚨\n\n'
          '⚠️ *Alert for Trusted Contact:* $contactName\n'
          '⚡ *Trigger Source:* ${reason ?? "Emergency SOS Triggered"}\n'
          '🔋 *Battery Level:* ${batteryLevel != null ? "$batteryLevel%" : "Unknown"}\n'
          '🕒 *Time:* $nowStr\n\n'
          '📍 *Live GPS Location:*\n$mapsLink\n\n'
          '👉 Please contact the user immediately or alert local authorities if needed.';

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': cleanChatId,
          'text': text,
          'parse_mode': 'Markdown',
          'disable_web_page_preview': false,
        }),
      ).timeout(const Duration(seconds: 10));

      final success = response.statusCode == 200;
      DevLog.log(
        'TELEGRAM',
        success
            ? 'Emergency alert successfully sent to Telegram chat $cleanChatId for $contactName'
            : 'Telegram alert failed (HTTP ${response.statusCode}): ${response.body}',
      );
      return success;
    } catch (e) {
      DevLog.log('TELEGRAM', 'Exception sending Telegram alert: $e');
      return false;
    }
  }

  /// Sends a verification test ping to confirm Telegram bot connectivity.
  static Future<bool> sendTestPing({
    required String chatId,
    required String contactName,
  }) async {
    final cleanChatId = chatId.trim();
    if (cleanChatId.isEmpty) return false;

    try {
      final url = Uri.parse('https://api.telegram.org/bot$botToken/sendMessage');
      final text = '🛡️ *Guardian AI — Telegram Connection Verified*\n\n'
          'Hello $contactName! This Telegram chat is linked to Guardian AI.\n'
          'You will automatically receive instant SOS alerts with live GPS location whenever an emergency is detected.';

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': cleanChatId,
          'text': text,
          'parse_mode': 'Markdown',
        }),
      ).timeout(const Duration(seconds: 10));

      final success = response.statusCode == 200;
      DevLog.log('TELEGRAM', 'Test ping to $cleanChatId result: $success');
      return success;
    } catch (e) {
      DevLog.log('TELEGRAM', 'Exception sending test ping: $e');
      return false;
    }
  }
}
