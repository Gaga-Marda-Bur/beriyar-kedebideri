import 'models/word_model.dart';
import '../../core/api/api_client.dart';

class VocabularyApiService {
  final ApiClient _apiClient;

  VocabularyApiService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  Future<List<WordModel>> fetchWords({
    String? search,
    String? category,
    String? difficulty,
    String? status,
    bool offlineOnly = false,
  }) async {
    final query = <String, String>{};

    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    if (category != null && category.isNotEmpty) {
      query['category'] = category;
    }

    if (difficulty != null && difficulty.isNotEmpty) {
      query['difficulty'] = difficulty;
    }

    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }

    if (offlineOnly) {
      query['offline'] = 'true';
    }

    final items = await _apiClient.getList(
      '/vocabulary/words/',
      query: query.isEmpty ? null : query,
    );

    return items
        .whereType<Map<String, dynamic>>()
        .map(WordModel.fromJson)
        .toList();
  }
}