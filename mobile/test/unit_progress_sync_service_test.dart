import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/features/progress/models/unit_progress_local_model.dart';
import 'package:mobile/features/progress/services/unit_progress_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UnitProgressSyncService Security (A01 / A03)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'syncProgressList includes device_id, device_token and security headers',
      () async {
        Map<String, String>? capturedHeaders;
        Map<String, dynamic>? capturedBody;

        final mockClient = MockClient((request) async {
          capturedHeaders = request.headers;
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;

          return http.Response(
            jsonEncode({
              'synced_count': 1,
              'error_count': 0,
              'synced': [
                {
                  'unit_slug': 'test-slug',
                  'completed': false,
                  'best_score_percent': 75,
                  'status': 'started',
                  'synced_at': DateTime.now().toIso8601String(),
                },
              ],
              'errors': [],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

        final apiClient = ApiClient(client: mockClient);
        final syncService = UnitProgressSyncService(apiClient: apiClient);

        final localModel = UnitProgressLocalModel(
          unitSlug: 'test-slug',
          status: 'started',
          currentStep: 2,
          totalSteps: 5,
          lastStage: 'lessons',
          completed: false,
          bestScorePercent: 75,
          startedAt: DateTime.parse('2026-10-23T10:00:00Z'),
          updatedAt: DateTime.parse('2026-10-23T10:05:00Z'),
          completedAt: null,
          quizzesAnswered: 7,
          correctAnswers: 5,
          charactersSeen: 3,
        );

        final result = await syncService.syncProgressList([localModel]);

        expect(result.syncedCount, 1);
        expect(result.errorCount, 0);

        // Vérifier les en-têtes de sécurité
        expect(capturedHeaders, isNotNull);
        expect(capturedHeaders!['X-Device-Id'], isNotEmpty);
        expect(capturedHeaders!['X-Device-Token'], isNotEmpty);

        // Vérifier le payload des éléments
        expect(capturedBody, isNotNull);
        final items = capturedBody!['items'] as List<dynamic>;
        expect(items.length, 1);
        final item = items[0] as Map<String, dynamic>;
        expect(item['unit_slug'], 'test-slug');
        expect(item['device_id'], capturedHeaders!['X-Device-Id']);
        expect(item['device_token'], capturedHeaders!['X-Device-Token']);
        expect(item['quizzes_answered'], 7);
        expect(item['correct_answers'], 5);
        expect(item['characters_seen'], 3);
      },
    );
  });
}
