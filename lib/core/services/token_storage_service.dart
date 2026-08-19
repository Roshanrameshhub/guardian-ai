import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstract interface for persistent authentication token storage.
abstract class TokenStorageService {
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<String?> getUserId();
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
  });
  Future<void> updateAccessToken(String accessToken);
  Future<void> clear();
  Future<bool> hasValidToken();
}

/// Secure, hardware-backed persistent token storage for Android & iOS using Keystore / Keychain.
class SecureTokenStorageService implements TokenStorageService {
  SecureTokenStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const String _keyAccessToken = 'guardian_access_token';
  static const String _keyRefreshToken = 'guardian_refresh_token';
  static const String _keyUserId = 'guardian_user_id';

  // In-memory fast cache
  String? _cachedAccessToken;
  String? _cachedRefreshToken;
  String? _cachedUserId;

  @override
  Future<String?> getAccessToken() async {
    if (_cachedAccessToken != null) return _cachedAccessToken;
    try {
      _cachedAccessToken = await _storage.read(key: _keyAccessToken);
    } catch (_) {}
    return _cachedAccessToken;
  }

  @override
  Future<String?> getRefreshToken() async {
    if (_cachedRefreshToken != null) return _cachedRefreshToken;
    try {
      _cachedRefreshToken = await _storage.read(key: _keyRefreshToken);
    } catch (_) {}
    return _cachedRefreshToken;
  }

  @override
  Future<String?> getUserId() async {
    if (_cachedUserId != null) return _cachedUserId;
    try {
      _cachedUserId = await _storage.read(key: _keyUserId);
    } catch (_) {}
    return _cachedUserId;
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
    _cachedUserId = userId;

    try {
      await _storage.write(key: _keyAccessToken, value: accessToken);
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
      await _storage.write(key: _keyUserId, value: userId);
    } catch (_) {}
  }

  @override
  Future<void> updateAccessToken(String accessToken) async {
    _cachedAccessToken = accessToken;
    try {
      await _storage.write(key: _keyAccessToken, value: accessToken);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    _cachedUserId = null;

    try {
      await _storage.delete(key: _keyAccessToken);
      await _storage.delete(key: _keyRefreshToken);
      await _storage.delete(key: _keyUserId);
    } catch (_) {}
  }

  @override
  Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}

/// In-memory token storage (used in unit tests).
class InMemoryTokenStorageService implements TokenStorageService {
  String? _accessToken;
  String? _refreshToken;
  String? _userId;

  @override
  Future<String?> getAccessToken() async => _accessToken;

  @override
  Future<String?> getRefreshToken() async => _refreshToken;

  @override
  Future<String?> getUserId() async => _userId;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _userId = userId;
  }

  @override
  Future<void> updateAccessToken(String accessToken) async {
    _accessToken = accessToken;
  }

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
  }

  @override
  Future<bool> hasValidToken() async =>
      _accessToken != null && _accessToken!.isNotEmpty;
}
