import 'models/no_ena_publication_model.dart';
import '../../core/api/api_client.dart';

class NoEnaApiService {
  final ApiClient _apiClient;

  NoEnaApiService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  Future<List<NoEnaPublicationModel>> fetchPublications({
    String? type,
    String? theme,
    bool featuredOnly = false,
    bool offlineOnly = false,
  }) async {
    final query = <String, String>{};

    if (type != null && type.isNotEmpty) {
      query['type'] = type;
    }

    if (theme != null && theme.isNotEmpty) {
      query['theme'] = theme;
    }

    if (featuredOnly) {
      query['featured'] = 'true';
    }

    if (offlineOnly) {
      query['offline'] = 'true';
    }

    final items = await _apiClient.getList(
      '/no-ena/publications/',
      query: query.isEmpty ? null : query,
    );

    return items
        .whereType<Map<String, dynamic>>()
        .map(NoEnaPublicationModel.fromJson)
        .toList();
  }

  Future<void> increaseViewCount(String slug) async {
    await _apiClient.postMap('/no-ena/publications/$slug/view/');
  }
}