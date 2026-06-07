import 'models/character_model.dart';
import '../../core/api/api_client.dart';

class AlphabetApiService {
  final ApiClient _apiClient;

  AlphabetApiService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  Future<List<CharacterModel>> fetchCharacters({
    String? status,
    String? type,
    bool offlineOnly = false,
  }) async {
    final query = <String, String>{};

    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }

    if (type != null && type.isNotEmpty) {
      query['type'] = type;
    }

    if (offlineOnly) {
      query['offline'] = 'true';
    }

    final items = await _apiClient.getList(
      '/alphabet/characters/',
      query: query.isEmpty ? null : query,
    );

    return items
        .whereType<Map<String, dynamic>>()
        .map(CharacterModel.fromJson)
        .toList();
  }
}