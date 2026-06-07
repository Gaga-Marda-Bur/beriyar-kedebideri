import 'models/learning_theme_model.dart';
import 'models/learning_unit_model.dart';
import '../../core/api/api_client.dart';

class LearningApiService {
  final ApiClient _apiClient;

  LearningApiService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  Future<List<LearningThemeModel>> fetchThemes({
    String? level,
    String? status,
    bool offlineOnly = false,
  }) async {
    final query = <String, String>{};

    if (level != null && level.isNotEmpty) {
      query['level'] = level;
    }

    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }

    if (offlineOnly) {
      query['offline'] = 'true';
    }

    final items = await _apiClient.getList(
      '/learning/themes/',
      query: query.isEmpty ? null : query,
    );

    return items
        .whereType<Map<String, dynamic>>()
        .map(LearningThemeModel.fromJson)
        .toList();
  }

  Future<List<LearningUnitModel>> fetchUnits({
    String? theme,
    String? level,
    String? status,
    bool offlineOnly = false,
  }) async {
    final query = <String, String>{};

    if (theme != null && theme.isNotEmpty) {
      query['theme'] = theme;
    }

    if (level != null && level.isNotEmpty) {
      query['level'] = level;
    }

    if (status != null && status.isNotEmpty) {
      query['status'] = status;
    }

    if (offlineOnly) {
      query['offline'] = 'true';
    }

    final items = await _apiClient.getList(
      '/learning/units/',
      query: query.isEmpty ? null : query,
    );

    return items
        .whereType<Map<String, dynamic>>()
        .map(LearningUnitModel.fromJson)
        .toList();
  }
}