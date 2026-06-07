import 'api_client.dart';

class BackendHealthService {
  final ApiClient _apiClient;

  BackendHealthService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  Future<bool> checkConnection() async {
    try {
      final items = await _apiClient.getList('/alphabet/characters/');
      return items.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}