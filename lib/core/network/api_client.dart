import 'dart:async' as async;
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../constants/api_constants.dart';
import '../services/token_storage_service.dart';
import '../utils/dev_log.dart';

/// Categories of API communication errors for truthful user feedback and telemetry.
enum ApiErrorCategory {
  networkError,
  authError,
  permissionError,
  validationError,
  notFound,
  serverError,
  timeout,
  configurationError,
  unknownError,
}

/// Production-ready HTTP client with JWT injection, 401 automatic refresh,
/// structured telemetry, and truthful error categorization.
class ApiClient {
  ApiClient({
    http.Client? client,
    String? baseUrl,
    TokenStorageService? tokenStorage,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl,
        _tokenStorage = tokenStorage ?? SecureTokenStorageService();

  final http.Client _client;
  final String? _baseUrl;
  final TokenStorageService _tokenStorage;
  bool _isRefreshing = false;

  // Runtime Diagnostics Telemetry
  static String? lastEndpoint;
  static int? lastStatusCode;
  static String? lastError;
  static ApiErrorCategory? lastErrorCategory;
  static DateTime? lastRequestTime;

  String get baseUrl => _baseUrl ?? ApiConfig.baseUrl;

  TokenStorageService get tokenStorage => _tokenStorage;

  void setAuthToken(String? token) {
    if (token != null) {
      _tokenStorage.updateAccessToken(token);
    } else {
      _tokenStorage.clear();
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _tokenStorage.getAccessToken();
    final hasToken = token != null && token.isNotEmpty;
    DevLog.auth('authorization header attached = $hasToken');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (hasToken) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final root = baseUrl.isEmpty ? 'http://localhost:8000/api/v1' : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    try {
      return Uri.parse('$root$normalizedPath').replace(queryParameters: query);
    } catch (e) {
      _recordError(path, 0, 'Malformed URL: $root$normalizedPath', ApiErrorCategory.configurationError);
      throw ConfigurationException(message: 'Malformed URL: $root$normalizedPath', uri: path);
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    DevLog.log('API', 'GET $path ${query != null ? query.toString() : ""}');
    try {
      final headers = await _getHeaders();
      final uri = _uri(path, query);
      _recordRequest(path);
      final response = await _client.get(uri, headers: headers).timeout(ApiConstants.receiveTimeout);
      return _handleResponse(response, () => get(path, query: query), path);
    } on SocketException catch (e) {
      _recordError(path, 0, 'Cannot reach server at $baseUrl. Check network or IP.', ApiErrorCategory.networkError);
      DevLog.log('API', 'SOCKET ERROR $path', error: e);
      throw NetworkException(
        message: 'Unable to connect to server at $baseUrl. Please verify backend is running and LAN IP is correct.',
        uri: path,
      );
    } on async.TimeoutException catch (e) {
      _recordError(path, 408, 'Request timed out after ${ApiConstants.receiveTimeout.inSeconds}s', ApiErrorCategory.timeout);
      DevLog.log('API', 'TIMEOUT $path', error: e);
      throw ApiTimeoutException(
        message: 'Connection timed out. Server at $baseUrl took too long to respond.',
        uri: path,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      _recordError(path, 0, e.toString(), ApiErrorCategory.networkError);
      DevLog.log('API', 'ERROR $path', error: e);
      throw NetworkException(message: 'Network error: $e', uri: path);
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    DevLog.log('API', 'POST $path');
    try {
      final headers = await _getHeaders();
      final uri = _uri(path);
      _recordRequest(path);
      final response = await _client
          .post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(ApiConstants.receiveTimeout);
      return _handleResponse(response, () => post(path, body: body), path);
    } on SocketException catch (e) {
      _recordError(path, 0, 'Cannot reach server at $baseUrl', ApiErrorCategory.networkError);
      DevLog.log('API', 'SOCKET ERROR $path', error: e);
      throw NetworkException(
        message: 'Unable to connect to server at $baseUrl.',
        uri: path,
      );
    } on async.TimeoutException catch (e) {
      _recordError(path, 408, 'Request timed out', ApiErrorCategory.timeout);
      DevLog.log('API', 'TIMEOUT $path', error: e);
      throw ApiTimeoutException(
        message: 'Connection timed out at $baseUrl.',
        uri: path,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      _recordError(path, 0, e.toString(), ApiErrorCategory.networkError);
      DevLog.log('API', 'ERROR $path', error: e);
      throw NetworkException(message: 'Network error: $e', uri: path);
    }
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    DevLog.log('API', 'PUT $path');
    try {
      final headers = await _getHeaders();
      final uri = _uri(path);
      _recordRequest(path);
      final response = await _client
          .put(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(ApiConstants.receiveTimeout);
      return _handleResponse(response, () => put(path, body: body), path);
    } on SocketException {
      _recordError(path, 0, 'Cannot reach server at $baseUrl', ApiErrorCategory.networkError);
      throw NetworkException(message: 'Unable to connect to server at $baseUrl.', uri: path);
    } on async.TimeoutException {
      _recordError(path, 408, 'Request timed out', ApiErrorCategory.timeout);
      throw ApiTimeoutException(message: 'Connection timed out at $baseUrl.', uri: path);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(message: 'Network error: $e', uri: path);
    }
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    DevLog.log('API', 'PATCH $path');
    try {
      final headers = await _getHeaders();
      final uri = _uri(path);
      _recordRequest(path);
      final response = await _client
          .patch(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(ApiConstants.receiveTimeout);
      return _handleResponse(response, () => patch(path, body: body), path);
    } on SocketException {
      _recordError(path, 0, 'Cannot reach server at $baseUrl', ApiErrorCategory.networkError);
      throw NetworkException(message: 'Unable to connect to server at $baseUrl.', uri: path);
    } on async.TimeoutException {
      _recordError(path, 408, 'Request timed out', ApiErrorCategory.timeout);
      throw ApiTimeoutException(message: 'Connection timed out at $baseUrl.', uri: path);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(message: 'Network error: $e', uri: path);
    }
  }

  Future<Map<String, dynamic>> delete(String path) async {
    DevLog.log('API', 'DELETE $path');
    try {
      final headers = await _getHeaders();
      final uri = _uri(path);
      _recordRequest(path);
      final response = await _client.delete(uri, headers: headers).timeout(ApiConstants.receiveTimeout);
      return _handleResponse(response, () => delete(path), path);
    } on SocketException {
      _recordError(path, 0, 'Cannot reach server at $baseUrl', ApiErrorCategory.networkError);
      throw NetworkException(message: 'Unable to connect to server at $baseUrl.', uri: path);
    } on async.TimeoutException {
      _recordError(path, 408, 'Request timed out', ApiErrorCategory.timeout);
      throw ApiTimeoutException(message: 'Connection timed out at $baseUrl.', uri: path);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(message: 'Network error: $e', uri: path);
    }
  }

  void _recordRequest(String path) {
    lastEndpoint = path;
    lastRequestTime = DateTime.now();
  }

  void _recordError(String path, int statusCode, String message, ApiErrorCategory category) {
    lastEndpoint = path;
    lastStatusCode = statusCode;
    lastError = message;
    lastErrorCategory = category;
  }

  Future<Map<String, dynamic>> _handleResponse(
    http.Response response,
    Future<Map<String, dynamic>> Function() retry,
    String path,
  ) async {
    lastStatusCode = response.statusCode;
    DevLog.log('API', 'RESPONSE $path -> ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      lastError = null;
      lastErrorCategory = null;
      if (response.body.isEmpty) return <String, dynamic>{'success': true};
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) return <String, dynamic>{'data': decoded};
      return <String, dynamic>{'data': decoded};
    }

    // Attempt automatic token refresh on 401 Unauthorized
    if (response.statusCode == 401 &&
        !path.contains(ApiConstants.login) &&
        !path.contains(ApiConstants.refreshToken) &&
        !_isRefreshing) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        return retry();
      }
    }

    // Extract error message from FastAPI response
    String errorMessage = 'Request failed with status ${response.statusCode}';
    try {
      if (response.body.isNotEmpty) {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map) {
          if (errorBody.containsKey('detail')) {
            final detail = errorBody['detail'];
            if (detail is String) {
              errorMessage = detail;
            } else if (detail is List && detail.isNotEmpty) {
              errorMessage = detail.map((e) => e is Map ? (e['msg'] ?? e.toString()) : e.toString()).join('; ');
            }
          } else if (errorBody.containsKey('message')) {
            errorMessage = errorBody['message'].toString();
          }
        }
      }
    } catch (_) {
      // Use default status message if body is not JSON
    }

    // Categorize HTTP Error Responses
    if (response.statusCode == 401) {
      _recordError(path, 401, errorMessage, ApiErrorCategory.authError);
      throw AuthException(message: errorMessage, statusCode: 401, uri: path);
    }

    if (response.statusCode == 403) {
      _recordError(path, 403, errorMessage, ApiErrorCategory.permissionError);
      throw PermissionException(message: errorMessage, statusCode: 403, uri: path);
    }

    if (response.statusCode == 404) {
      _recordError(path, 404, errorMessage, ApiErrorCategory.notFound);
      throw NotFoundException(message: errorMessage, uri: path);
    }

    if (response.statusCode == 422) {
      _recordError(path, 422, errorMessage, ApiErrorCategory.validationError);
      throw ValidationException(message: errorMessage, statusCode: 422, uri: path);
    }

    if (response.statusCode == 408) {
      _recordError(path, 408, errorMessage, ApiErrorCategory.timeout);
      throw ApiTimeoutException(message: errorMessage, uri: path);
    }

    if (response.statusCode >= 500) {
      _recordError(path, response.statusCode, errorMessage, ApiErrorCategory.serverError);
      throw ServerException(message: errorMessage, statusCode: response.statusCode, uri: path);
    }

    _recordError(path, response.statusCode, errorMessage, ApiErrorCategory.unknownError);
    throw ApiException(
      statusCode: response.statusCode,
      message: errorMessage,
      category: ApiErrorCategory.unknownError,
      uri: path,
    );
  }

  Future<bool> _tryRefreshToken() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        await _tokenStorage.clear();
        return false;
      }

      final response = await _client.post(
        _uri(ApiConstants.refreshToken),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(ApiConstants.receiveTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String? ?? refreshToken;
        final userId = data['user_id'] as String? ?? await _tokenStorage.getUserId() ?? '';

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await _tokenStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
            userId: userId,
          );
          return true;
        }
      }
      await _tokenStorage.clear();
      return false;
    } catch (_) {
      await _tokenStorage.clear();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  void dispose() => _client.close();
}

/// Base API exception class.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.category = ApiErrorCategory.unknownError,
    this.uri,
  });

  final int statusCode;
  final String message;
  final ApiErrorCategory category;
  final String? uri;

  String get categoryCode => switch (category) {
        ApiErrorCategory.networkError => 'NETWORK_ERROR',
        ApiErrorCategory.authError => 'AUTH_ERROR',
        ApiErrorCategory.permissionError => 'PERMISSION_ERROR',
        ApiErrorCategory.validationError => 'VALIDATION_ERROR',
        ApiErrorCategory.notFound => 'NOT_FOUND',
        ApiErrorCategory.serverError => 'SERVER_ERROR',
        ApiErrorCategory.timeout => 'TIMEOUT',
        ApiErrorCategory.configurationError => 'CONFIGURATION_ERROR',
        ApiErrorCategory.unknownError => 'UNKNOWN_ERROR',
      };

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  const NetworkException({required super.message, required super.uri})
      : super(statusCode: 0, category: ApiErrorCategory.networkError);
}

class AuthException extends ApiException {
  const AuthException({required super.message, required super.statusCode, super.uri})
      : super(category: ApiErrorCategory.authError);
}

class PermissionException extends ApiException {
  const PermissionException({required super.message, required super.statusCode, super.uri})
      : super(category: ApiErrorCategory.permissionError);
}

class ValidationException extends ApiException {
  const ValidationException({required super.message, required super.statusCode, super.uri})
      : super(category: ApiErrorCategory.validationError);
}

class ServerException extends ApiException {
  const ServerException({required super.message, required super.statusCode, super.uri})
      : super(category: ApiErrorCategory.serverError);
}

class ApiTimeoutException extends ApiException {
  const ApiTimeoutException({required super.message, super.uri})
      : super(statusCode: 408, category: ApiErrorCategory.timeout);
}

class ConfigurationException extends ApiException {
  const ConfigurationException({required super.message, super.uri})
      : super(statusCode: 0, category: ApiErrorCategory.configurationError);
}

class NotFoundException extends ApiException {
  const NotFoundException({required super.message, super.uri})
      : super(statusCode: 404, category: ApiErrorCategory.notFound);
}
