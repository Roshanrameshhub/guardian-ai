import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:guardian_ai/core/constants/api_constants.dart';
import 'package:guardian_ai/core/network/api_client.dart';
import 'package:guardian_ai/core/services/telegram_notification_service.dart';

void main() {
  group('TelegramNotificationService Tests', () {
    test('botUsername is public handle without any secrets', () {
      expect(TelegramNotificationService.botUsername, 'GuardAIAlertBot');
    });

    test('sendEmergencyAlert proxies request to backend endpoint with correct payload', () async {
      late Uri capturedUri;
      late Map<String, dynamic> capturedBody;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode({'success': true, 'message': 'Delivered via Guardian Alert Bot'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test-server:8000/api/v1');
      TelegramNotificationService.setApiClient(apiClient);

      final result = await TelegramNotificationService.sendEmergencyAlert(
        chatId: '123456789',
        contactName: 'Emergency Contact',
        lat: 12.9716,
        lng: 77.5946,
        reason: 'Test Emergency',
        batteryLevel: 90,
      );

      expect(result, isTrue);
      expect(capturedUri.path, endsWith(ApiConstants.telegramAlert));
      expect(capturedBody['chat_id'], '123456789');
      expect(capturedBody['contact_name'], 'Emergency Contact');
      expect(capturedBody['lat'], 12.9716);
      expect(capturedBody['lng'], 77.5946);
      expect(capturedBody['reason'], 'Test Emergency');
      expect(capturedBody['battery_level'], 90);
    });

    test('sendTestPing proxies test request to backend endpoint', () async {
      late Uri capturedUri;
      late Map<String, dynamic> capturedBody;

      final mockClient = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode({'success': true, 'message': 'Delivered directly to @GuardAIAlertBot'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test-server:8000/api/v1');
      TelegramNotificationService.setApiClient(apiClient);

      final result = await TelegramNotificationService.sendTestPing(
        chatId: '987654321',
        contactName: 'Alice',
      );

      expect(result, isTrue);
      expect(capturedUri.path, endsWith(ApiConstants.telegramTest));
      expect(capturedBody['chat_id'], '987654321');
      expect(capturedBody['contact_name'], 'Alice');
    });

    test('returns false when backend returns failure or encounters error', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': false, 'message': 'Telegram bot not configured'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test-server:8000/api/v1');
      TelegramNotificationService.setApiClient(apiClient);

      final result = await TelegramNotificationService.sendTestPing(
        chatId: '987654321',
        contactName: 'Alice',
      );

      expect(result, isFalse);
    });

    test('returns false when chatId is empty without making network calls', () async {
      var called = false;
      final mockClient = MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      });

      final apiClient = ApiClient(client: mockClient, baseUrl: 'http://test-server:8000/api/v1');
      TelegramNotificationService.setApiClient(apiClient);

      final result = await TelegramNotificationService.sendEmergencyAlert(
        chatId: '   ',
        contactName: 'Nobody',
        lat: 0.0,
        lng: 0.0,
      );

      expect(result, isFalse);
      expect(called, isFalse);
    });
  });
}
