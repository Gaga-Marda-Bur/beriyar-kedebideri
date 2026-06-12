import '../../../core/api/api_client.dart';

class FeedbackApiService {
  final ApiClient _apiClient;

  FeedbackApiService({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient();

  Future<void> sendFeedback({
    required String feedbackType,
    required String title,
    required String message,
    required String deviceId,
    required String appVersion,
    required String platform,
    required String languageCode,
  }) async {
    await _apiClient.postMap(
      '/feedback/create/',
      body: {
        'feedback_type': feedbackType,
        'title': title,
        'message': message,
        'device_id': deviceId,
        'app_version': appVersion,
        'platform': platform,
        'language_code': languageCode,
      },
    );
  }
}