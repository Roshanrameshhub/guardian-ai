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

    test('Deployed Render production backend URL', () {
      ApiConfig.setBaseUrl('https://guardian-ai-t55s.onrender.com');
      expect(ApiConfig.baseUrl, 'https://guardian-ai-t55s.onrender.com/api/v1');
    });

    test('Deployed Render production backend URL with trailing slash', () {
      ApiConfig.setBaseUrl('https://guardian-ai-t55s.onrender.com/');
      expect(ApiConfig.baseUrl, 'https://guardian-ai-t55s.onrender.com/api/v1');
    });

    test('Deployed Render production backend URL with prefix', () {
      ApiConfig.setBaseUrl('https://guardian-ai-t55s.onrender.com/api/v1');
      expect(ApiConfig.baseUrl, 'https://guardian-ai-t55s.onrender.com/api/v1');
    });

    test('Deployed Render production backend URL with prefix and trailing slash', () {
      ApiConfig.setBaseUrl('https://guardian-ai-t55s.onrender.com/api/v1/');
      expect(ApiConfig.baseUrl, 'https://guardian-ai-t55s.onrender.com/api/v1');
    });
  });
}
