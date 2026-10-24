import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/api_config.dart';
import 'package:mobile/core/cache/cached_content_service.dart';
import 'package:mobile/core/cache/online_content_cache_service.dart';
import 'package:mobile/core/cache/memory_content_cache.dart';
import 'package:mobile/core/network/backend_status_service.dart';
import 'package:mobile/features/vocabulary/vocabulary_api_service.dart';

class OnlineBackend extends BackendStatusService {
  @override
  Future<bool> isBackendReachable({Duration? cacheDuration}) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MemoryContentCache.instance.clear();
  });
  test(
    'partial network response cannot overwrite complete persistent vocabulary cache',
    () async {
      final cache = OnlineContentCacheService();
      await cache.saveList(
        key: 'words',
        items: [
          {'id': 1, 'beriya_text': '𖺡'},
          {'id': 2, 'beriya_text': '𖺣'},
        ],
      );
      final before = (await SharedPreferences.getInstance()).getString(
        'bk_online_cache_words',
      );
      final api = ApiClient(
        client: MockClient(
          (request) async => request.url.queryParameters['page'] == '2'
              ? http.Response('failed', 503)
              : http.Response(
                  jsonEncode({
                    'results': [
                      {'id': 3},
                    ],
                    'next': '${ApiConfig.baseUrl}/vocabulary/words/?page=2',
                  }),
                  200,
                ),
        ),
      );
      final service = CachedContentService(
        backendStatusService: OnlineBackend(),
        vocabularyApiService: VocabularyApiService(apiClient: api),
        cacheService: cache,
      );
      final words = await service.loadWords(forceRefresh: true);
      expect(words.map((w) => w.id), [1, 2]);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'bk_online_cache_words',
        ),
        before,
      );
    },
  );
  test(
    'page cap is explicitly incomplete and retains the acquired items',
    () async {
      final api = ApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'results': [
                {'id': 1},
              ],
              'next': '?page=2',
            }),
            200,
          ),
        ),
      );
      await expectLater(
        api.getList('/items/', maxPages: 1),
        throwsA(
          isA<IncompleteListException>().having(
            (e) => e.items.length,
            'acquired items',
            1,
          ),
        ),
      );
    },
  );
  test(
    'relative next URLs resolve correctly and scheme changes are rejected',
    () async {
      var calls = 0;
      final api = ApiClient(
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, endsWith('/items/'));
          return http.Response(
            jsonEncode({
              'results': [
                {'id': calls},
              ],
              'next': calls == 1 ? '?page=2' : null,
            }),
            200,
          );
        }),
      );
      expect((await api.getList('/items/')).length, 2);
      final base = Uri.parse(ApiConfig.baseUrl);
      final otherScheme = base.replace(
        scheme: base.scheme == 'http' ? 'https' : 'http',
      );
      final hostile = ApiClient(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'results': [
                {'id': 1},
              ],
              'next': '$otherScheme/items/?page=2',
            }),
            200,
          ),
        ),
      );
      await expectLater(
        hostile.getList('/items/'),
        throwsA(isA<IncompleteListException>()),
      );
    },
  );
}
