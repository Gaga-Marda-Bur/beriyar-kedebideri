import 'package:connectivity_plus/connectivity_plus.dart';

import '../api/api_client.dart';

class BackendStatusService {
  static DateTime? _lastCheckedAt;
  static bool _lastResult = false;

  final ApiClient _apiClient;

  BackendStatusService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  Future<bool> isBackendReachable({
    Duration cacheDuration = const Duration(seconds: 8),
  }) async {
    final now = DateTime.now();

    if (_lastCheckedAt != null &&
        now.difference(_lastCheckedAt!) < cacheDuration) {
      return _lastResult;
    }

    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity.contains(ConnectivityResult.none)) {
      _saveResult(false);
      return false;
    }

    try {
      await _apiClient
          .getMap('/core/health/')
          .timeout(const Duration(milliseconds: 900));

      _saveResult(true);
      return true;
    } catch (_) {
      _saveResult(false);
      return false;
    }
  }

  void _saveResult(bool value) {
    _lastResult = value;
    _lastCheckedAt = DateTime.now();
  }

  static void resetCache() {
    _lastCheckedAt = null;
    _lastResult = false;
  }
}