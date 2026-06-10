import 'package:connectivity_plus/connectivity_plus.dart';

import '../api/api_client.dart';
import '../config/app_environment.dart';
import '../utils/app_logger.dart';

class BackendStatusService {
  static DateTime? _lastCheckedAt;
  static bool _lastResult = false;

  final ApiClient _apiClient;

  BackendStatusService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  Future<bool> isBackendReachable({
    Duration? cacheDuration,
  }) async {
    final now = DateTime.now();
    final effectiveCacheDuration =
        cacheDuration ?? AppEnvironment.backendStatusCacheDuration;

    if (_lastCheckedAt != null &&
        now.difference(_lastCheckedAt!) < effectiveCacheDuration) {
      AppLogger.debug('BACKEND STATUS cache=$_lastResult');
      return _lastResult;
    }

    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity.contains(ConnectivityResult.none)) {
      _saveResult(false);
      AppLogger.debug('BACKEND STATUS no internet');
      return false;
    }

    try {
      final items = await _apiClient
          .getList('/alphabet/characters/')
          .timeout(AppEnvironment.backendCheckTimeout);

      final reachable = items.isNotEmpty;

      _saveResult(reachable);
      AppLogger.debug(
        'BACKEND STATUS reachable=$reachable items=${items.length}',
      );

      return reachable;
    } catch (error) {
      _saveResult(false);

      AppLogger.debug(
        'BACKEND STATUS unreachable: ${error.runtimeType}',
      );

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