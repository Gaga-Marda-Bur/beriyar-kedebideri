import 'models/quiz_question_model.dart';
import '../../core/api/api_client.dart';

class QuizApiService {
  final ApiClient _apiClient;

  QuizApiService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  Future<List<QuizQuestionModel>> fetchQuizzes({
    String? unit,
    String? lesson,
    String? type,
    String? difficulty,
    String? status,
    bool offlineOnly = false,
  }) async {
    final query = <String, String>{};

    if (unit != null && unit.isNotEmpty) {
      query['unit'] = unit;
    }

    if (lesson != null && lesson.isNotEmpty) {
      query['lesson'] = lesson;
    }

    if (type != null && type.isNotEmpty) {
      query['type'] = type;
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
      '/quizzes/',
      query: query.isEmpty ? null : query,
    );

    return items
        .whereType<Map<String, dynamic>>()
        .map(QuizQuestionModel.fromJson)
        .toList();
  }
}