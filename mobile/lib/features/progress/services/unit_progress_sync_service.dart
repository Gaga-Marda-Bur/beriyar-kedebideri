import '../../../core/api/api_client.dart';
import '../../../core/device/device_id_service.dart';
import '../models/unit_progress_local_model.dart';

class UnitProgressSyncResult {
  final int syncedCount;
  final int errorCount;
  final List<dynamic> synced;
  final List<dynamic> errors;

  const UnitProgressSyncResult({
    required this.syncedCount,
    required this.errorCount,
    required this.synced,
    required this.errors,
  });

  factory UnitProgressSyncResult.fromJson(Map<String, dynamic> json) {
    return UnitProgressSyncResult(
      syncedCount: _asInt(json['synced_count']),
      errorCount: _asInt(json['error_count']),
      synced: json['synced'] is List ? json['synced'] as List : [],
      errors: json['errors'] is List ? json['errors'] as List : [],
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class UnitProgressSyncService {
  final ApiClient _apiClient;
  final DeviceIdService _deviceIdService;

  UnitProgressSyncService({
    ApiClient? apiClient,
    DeviceIdService? deviceIdService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _deviceIdService = deviceIdService ?? DeviceIdService();

  Future<UnitProgressSyncResult> syncProgressList(
    List<UnitProgressLocalModel> progressList,
  ) async {
    if (progressList.isEmpty) {
      return const UnitProgressSyncResult(
        syncedCount: 0,
        errorCount: 0,
        synced: [],
        errors: [],
      );
    }

    final deviceId = await _deviceIdService.getOrCreateDeviceId();
    final deviceToken = await _deviceIdService.getOrCreateDeviceToken();

    final payload = {
      'items': progressList.map((progress) {
        return {
          'unit_slug': progress.unitSlug,
          'device_id': deviceId,
          'device_token': deviceToken,
          'status': progress.status,
          'last_stage': progress.lastStage,
          'lessons_seen': progress.lessonsSeen,
          'characters_seen': progress.charactersSeen,
          'words_seen': progress.wordsSeen,
          'quizzes_answered': progress.quizzesAnswered,
          'correct_answers': progress.correctAnswers,
          'score_percent': progress.bestScorePercent,
          'scoring_version': progress.scoringVersion,
          'last_session_score': progress.lastSessionScore,
          'completed': progress.completed,
          'started_at': progress.startedAt.toIso8601String(),
          'updated_at': progress.updatedAt.toIso8601String(),
          'client_updated_at': progress.updatedAt.toIso8601String(),
          'completed_at': progress.completedAt?.toIso8601String(),
        };
      }).toList(),
    };

    final response = await _apiClient.postMap(
      '/progress/unit-progress/sync/',
      body: payload,
      headers: {'X-Device-Id': deviceId, 'X-Device-Token': deviceToken},
    );

    return UnitProgressSyncResult.fromJson(response);
  }

  Future<UnitProgressSyncResult> syncOne(UnitProgressLocalModel progress) {
    return syncProgressList([progress]);
  }
}
