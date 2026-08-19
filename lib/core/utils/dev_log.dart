import 'package:flutter/foundation.dart';

/// Structured development diagnostics logger for Guardian AI.
///
/// Outputs formatted, tag-based log entries in debug mode without exposing
/// sensitive secrets (passwords, JWTs, API keys).
abstract final class DevLog {
  static void log(String tag, String message, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;

    final sanitized = _sanitize(message);
    // ignore: avoid_print
    print('[$tag] $sanitized');

    if (error != null) {
      // ignore: avoid_print
      print('[$tag] ERROR: ${_sanitize(error.toString())}');
    }
    if (stackTrace != null) {
      // ignore: avoid_print
      print('[$tag] STACK: ${stackTrace.toString().split('\n').take(3).join('\n')}');
    }
  }

  static void auth(String message, {Object? error}) => log('AUTH', message, error: error);
  static void home(String message, {Object? error, StackTrace? stack}) => log('HOME', message, error: error, stackTrace: stack);
  static void map(String message, {Object? error}) => log('MAP', message, error: error);
  static void route(String message, {Object? error}) => log('ROUTE', message, error: error);
  static void journey(String message, {Object? error}) => log('JOURNEY', message, error: error);
  static void gps(String message, {Object? error}) => log('GPS', message, error: error);
  static void sensor(String message, {Object? error}) => log('SENSOR', message, error: error);
  static void gyroscope(String message, {Object? error}) => log('GYROSCOPE', message, error: error);
  static void voice(String message, {Object? error}) => log('VOICE', message, error: error);
  static void guardian(String message, {Object? error}) => log('GUARDIAN', message, error: error);
  static void heartbeat(String message, {Object? error}) => log('HEARTBEAT', message, error: error);
  static void weather(String message, {Object? error}) => log('WEATHER', message, error: error);
  static void contact(String message, {Object? error}) => log('CONTACT', message, error: error);
  static void sos(String message, {Object? error}) => log('SOS', message, error: error);
  static void fcm(String message, {Object? error}) => log('FCM', message, error: error);
  static void gemini(String message, {Object? error}) => log('GEMINI', message, error: error);

  /// Strips JWT tokens and secret parameters from log strings
  static String _sanitize(String input) {
    var text = input;
    // Mask Bearer tokens
    text = text.replaceAll(RegExp(r'Bearer\s+[A-Za-z0-9\-_=]+\.[A-Za-z0-9\-_=]+\.?[A-Za-z0-9\-_=]*'), 'Bearer [REDACTED_JWT]');
    // Mask password parameters
    text = text.replaceAll(RegExp(r'"password":\s*"[^"]*"'), '"password": "[REDACTED]"');
    // Mask access_token / refresh_token
    text = text.replaceAll(RegExp(r'"(access|refresh)_token":\s*"[^"]*"'), '"\$1_token": "[REDACTED]"');
    return text;
  }
}
