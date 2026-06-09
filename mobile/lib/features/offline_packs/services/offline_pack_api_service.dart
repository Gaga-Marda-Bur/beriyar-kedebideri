import '../../../core/api/api_client.dart';
import '../models/lesson_pack_model.dart';

class OfflinePackApiService {
  final ApiClient _apiClient;

  OfflinePackApiService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  Future<List<LessonPackModel>> fetchPacks({
    String? level,
    bool featuredOnly = false,
  }) async {
    final query = <String, String>{};

    if (level != null && level.isNotEmpty) {
      query['level'] = level;
    }

    if (featuredOnly) {
      query['featured'] = 'true';
    }

    final items = await _apiClient.getList(
      '/offline-packs/',
      query: query.isEmpty ? null : query,
    );

    return items
        .whereType<Map<String, dynamic>>()
        .map(LessonPackModel.fromJson)
        .toList();
  }
}