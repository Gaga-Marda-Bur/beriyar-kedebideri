import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

class BackendStatusService {
  static DateTime? _lastCheckedAt;
  static bool _lastResult = false;

  final ApiClient _apiClient;

  BackendStatusService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  Future<bool> isBackendReachable({
    Duration cacheDuration = const Duration(seconds: 3),
  }) async {
    final now = DateTime.now();

    if (_lastCheckedAt != null &&
        now.difference(_lastCheckedAt!) < cacheDuration) {
      debugPrint('BACKEND STATUS cache=$_lastResult');
      return _lastResult;
    }

    final connectivity = await Connectivity().checkConnectivity();

    if (connectivity.contains(ConnectivityResult.none)) {
      _saveResult(false);
      debugPrint('BACKEND STATUS no internet');
      return false;
    }

    try {
      final items = await _apiClient
          .getList('/alphabet/characters/')
          .timeout(const Duration(milliseconds: 1200));

      final reachable = items.isNotEmpty;

      _saveResult(reachable);
      debugPrint('BACKEND STATUS reachable=$reachable items=${items.length}');

      return reachable;
    } catch (error) {
      _saveResult(false);
      debugPrint('BACKEND STATUS error=$error');
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