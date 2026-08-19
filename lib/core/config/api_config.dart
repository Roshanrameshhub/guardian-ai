import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

/// Unified API configuration managing base URLs across environments.
///
/// ## LAN / Physical-device testing
/// Supply the host machine's LAN IP at run-time via `--dart-define`:
///
/// ```
/// flutter run --dart-define=API_HOST=192.168.1.6
/// ```
///
/// `API_HOST` overrides every platform default and is the only value
/// that needs to change when the PC's IP address changes.
/// No source-code edits are ever required.
///
/// ## Production / CI
/// Use `--dart-define=API_HOST=api.example.com` (or a full URL via
/// `API_BASE_URL`) in your CI build command to point at the real server.
abstract final class ApiConfig {
  // ── dart-define injected values ──────────────────────────────────────────
  
  static const String _dartDefineHost =
      String.fromEnvironment('API_HOST', defaultValue: '');

  static const String _dartDefineBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static const String _dartDefinePort =
      String.fromEnvironment('API_PORT', defaultValue: '8000');

  static const String _dartDefineScheme =
      String.fromEnvironment('API_SCHEME', defaultValue: 'http');

  static const String _dartDefinePrefix =
      String.fromEnvironment('API_PREFIX', defaultValue: '/api/v1');

  // ── Runtime override (kept for backward-compatibility & testing) ─────────

  static String? _customBaseUrl;

  static void setBaseUrl(String url) {
    _customBaseUrl = _normalizeUrl(url);
  }

  static void resetBaseUrl() {
    _customBaseUrl = null;
  }

  // ── Resolution logic ─────────────────────────────────────────────────────

  static String get resolutionSource {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return 'Runtime Override (Custom)';
    }
    if (_dartDefineBaseUrl.isNotEmpty) {
      return '--dart-define=API_BASE_URL';
    }
    if (_dartDefineHost.isNotEmpty) {
      return '--dart-define=API_HOST';
    }
    if (kIsWeb) return 'Platform Default (Web Localhost)';
    try {
      if (Platform.isAndroid) {
        return 'Android Default (127.0.0.1 via adb reverse)';
      }
    } catch (_) {}
    return 'Platform Default (Localhost)';
  }

  static String get configuredHost => _dartDefineHost;
  static String get configuredBaseUrl => _dartDefineBaseUrl;
  static String get configuredPort => _dartDefinePort;
  static String get configuredScheme => _dartDefineScheme;
  static String get configuredPrefix => _dartDefinePrefix;

  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    
    if (_dartDefineBaseUrl.isNotEmpty) {
      final url = _normalizeUrl(_dartDefineBaseUrl);
      _debugLog('dart-define API_BASE_URL', url);
      return url;
    }

    if (_dartDefineHost.isNotEmpty) {
      final url = _normalizeUrl(_dartDefineHost);
      _debugLog('dart-define API_HOST', url);
      return url;
    }

    final url = _normalizeUrl(_platformDefaultHost());
    _debugLog('platform default', url);
    return url;
  }

  static bool get isConfigured => baseUrl.isNotEmpty;

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _platformDefaultHost() {
    if (kIsWeb) return 'localhost';
    try {
      if (Platform.isAndroid) return '127.0.0.1';
    } catch (_) {}
    return 'localhost';
  }
  
  /// Defensively normalizes any input to ensure there's exactly one scheme, host, port, and prefix.
  static String _normalizeUrl(String input) {
    if (input.isEmpty) return '';
    
    String url = input.trim();
    
    // Clean up accident-prone manual URL entry
    url = url.replaceAll('http://http://', 'http://');
    url = url.replaceAll('https://https://', 'https://');
    url = url.replaceAll('http://https://', 'https://');
    url = url.replaceAll('https://http://', 'https://');
    url = url.replaceAll(':8000:8000', ':8000');
    
    // Ensure input has some scheme so Uri.parse can extract host
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = '$_dartDefineScheme://$url';
    }
    
    try {
      final uri = Uri.parse(url);
      final scheme = uri.scheme.isNotEmpty ? uri.scheme : _dartDefineScheme;
      final host = uri.host.isNotEmpty ? uri.host : uri.path; // Sometimes parsed as path if no scheme was initially present
      
      int? port = uri.hasPort ? uri.port : null;
      if (port == null && (host == 'localhost' || host == '127.0.0.1' || host.startsWith('192.168.') || host.startsWith('10.'))) {
        port = int.tryParse(_dartDefinePort);
      }
      
      String prefix = _dartDefinePrefix;
      if (!prefix.startsWith('/')) prefix = '/$prefix';
      if (prefix.endsWith('/')) prefix = prefix.substring(0, prefix.length - 1);
      
      String path = uri.path;
      // Resolve duplicate prefix like /api/v1/api/v1
      path = path.replaceAll('$prefix$prefix', prefix);
      
      if (!path.endsWith(prefix)) {
        if (path.endsWith('/')) path = path.substring(0, path.length - 1);
        path = path.isEmpty || path == '/' ? prefix : '$path$prefix';
      }
      
      path = path.replaceAll('//', '/');
      if (path.endsWith('/')) path = path.substring(0, path.length - 1);
      
      return port != null && port != 80 && port != 443 ? '$scheme://$host:$port$path' : '$scheme://$host$path';
    } catch (_) {
      // Fallback in case of parse error
      return url;
    }
  }

  static bool _logged = false;
  static void _debugLog(String source, String url) {
    if (kDebugMode && !_logged) {
      _logged = true;
      // ignore: avoid_print
      print('[ApiConfig] base URL resolved via $source → $url');
    }
  }
}
