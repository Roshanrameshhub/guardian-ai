import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_ai/core/config/api_config.dart';

void main() {
  group('ApiConfig Normalization Logic', () {
    test('Host only', () {
      ApiConfig.setBaseUrl('192.168.1.6');
      expect(ApiConfig.baseUrl, 'http://192.168.1.6:8000/api/v1');
    });

    test('Host and port', () {
      ApiConfig.setBaseUrl('http://192.168.1.6:8000');
      expect(ApiConfig.baseUrl, 'http://192.168.1.6:8000/api/v1');
    });

    test('Production full URL', () {
      ApiConfig.setBaseUrl('https://api.example.com');
      expect(ApiConfig.baseUrl, 'https://api.example.com/api/v1');
    });

    test('No duplicate scheme', () {
      ApiConfig.setBaseUrl('http://http://192.168.1.6:8000');
      expect(ApiConfig.baseUrl, 'http://192.168.1.6:8000/api/v1');
    });

    test('No duplicate port', () {
      ApiConfig.setBaseUrl('http://192.168.1.6:8000:8000');
      expect(ApiConfig.baseUrl, 'http://192.168.1.6:8000/api/v1');
    });

    test('No duplicate prefix', () {
      ApiConfig.setBaseUrl('http://192.168.1.6:8000/api/v1/api/v1');
      expect(ApiConfig.baseUrl, 'http://192.168.1.6:8000/api/v1');
    });
  });
}
