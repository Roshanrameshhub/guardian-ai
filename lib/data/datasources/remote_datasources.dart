import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';

/// Remote datasources for live FastAPI backend endpoints.

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> login(Map<String, dynamic> body) =>
      _api.post(ApiConstants.login, body: body);

  Future<Map<String, dynamic>> register(Map<String, dynamic> body) =>
      _api.post(ApiConstants.register, body: body);
}

class DashboardRemoteDataSource {
  DashboardRemoteDataSource(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> fetchDashboard() => _api.get(ApiConstants.dashboard);
}

class GuardianRemoteDataSource {
  GuardianRemoteDataSource(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> start() => _api.post(ApiConstants.startGuardian);
  Future<Map<String, dynamic>> stop() => _api.post(ApiConstants.stopGuardian);
  Future<Map<String, dynamic>> status() => _api.get(ApiConstants.guardianStatus);
}

class MapRemoteDataSource {
  MapRemoteDataSource(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> fetchRoute({String? destination}) =>
      _api.get(ApiConstants.route, query: {
        if (destination != null) 'destination': destination,
      });
}

class ActivityRemoteDataSource {
  ActivityRemoteDataSource(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> fetchActivity() => _api.get(ApiConstants.activity);
  Future<Map<String, dynamic>> fetchNotifications() =>
      _api.get(ApiConstants.notifications);
}
