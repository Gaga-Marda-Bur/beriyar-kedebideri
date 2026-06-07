import 'models/lesson_model.dart';
import '../../core/api/api_client.dart';

class LessonsApiService {
  final ApiClient _apiClient;

  LessonsApiService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  Future<List<LessonModel>> fetchLessons({
    String? unit,
    String? level,
    String? status,
    bool offlineOnly = false,
  }) async {
    final query = <String, String>{};

    if (unit != null && unit.isNotEmpty) {
      query['unit'] = unit;
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
      '/lessons/',
      query: query.isEmpty ? null : query,
    );

    return items
        .whereType<Map<String, dynamic>>()
        .map(LessonModel.fromJson)
        .toList();
  }

  Future<List<LessonItemModel>> fetchLessonItems({
    String? lesson,
    String? type,
    bool offlineOnly = false,
  }) async {
    final query = <String, String>{};

    if (lesson != null && lesson.isNotEmpty) {
      query['lesson'] = lesson;
    }

    if (type != null && type.isNotEmpty) {
      query['type'] = type;
    }

    if (offlineOnly) {
      query['offline'] = 'true';
    }

    final items = await _apiClient.getList(
      '/lessons/items/',
      query: query.isEmpty ? null : query,
    );

    return items
        .whereType<Map<String, dynamic>>()
        .map(LessonItemModel.fromJson)
        .toList();
  }
}