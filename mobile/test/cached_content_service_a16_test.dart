import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/cache/cache_keys.dart';
import 'package:mobile/core/cache/cached_content_service.dart';
import 'package:mobile/core/cache/content_source.dart';
import 'package:mobile/core/cache/memory_content_cache.dart';
import 'package:mobile/core/cache/online_content_cache_service.dart';
import 'package:mobile/core/network/backend_status_service.dart';
import 'package:mobile/features/alphabet/alphabet_api_service.dart';
import 'package:mobile/features/vocabulary/vocabulary_api_service.dart';

class AlwaysOnlineBackend extends BackendStatusService {
  @override
  Future<bool> isBackendReachable({Duration? cacheDuration}) async => true;
}

class AlwaysOfflineBackend extends BackendStatusService {
  @override
  Future<bool> isBackendReachable({Duration? cacheDuration}) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MemoryContentCache.instance.clear();
    ContentSourceState.instance.clear();
  });

  group('A16 — Distinction réponse API vide vs erreur vs cache', () {
    test('une réponse API 200 vide met à jour le cache et retourne une liste vide sans ressusciter l’ancien cache', () async {
      final cacheService = OnlineContentCacheService();

      // Pré-remplir le cache avec un caractère obsolète / retiré de publication
      await cacheService.saveList(
        key: CacheKeys.characters,
        items: [
          {
            'id': 1,
            'symbol': '𖺡',
            'unicode_code': 'U+16EA1',
            'name': 'Erfe A (retiré)',
          }
        ],
      );

      // Simuler une réponse API 200 OK avec 0 élément (ex. retrait éditorial ou corpus vide)
      final mockApi = ApiClient(
        client: MockClient((request) async {
          return http.Response(jsonEncode({'results': []}), 200);
        }),
      );

      final service = CachedContentService(
        backendStatusService: AlwaysOnlineBackend(),
        alphabetApiService: AlphabetApiService(apiClient: mockApi),
        cacheService: cacheService,
      );

      final results = await service.loadCharacters(forceRefresh: true);

      // Ne doit PAS renvoyer l'ancien élément du cache
      expect(results, isEmpty);
      expect(ContentSourceState.instance.getSource(CacheKeys.characters), ContentSourceType.empty);

      // Le cache persistant a été synchronisé avec la réponse faisant foi
      final cachedNow = await cacheService.readList(key: CacheKeys.characters);
      expect(cachedNow, isEmpty);
    });

    test('en cas d’erreur réseau (500), le cache existant est préservé et utilisé en repli', () async {
      final cacheService = OnlineContentCacheService();

      // Pré-remplir le cache
      await cacheService.saveList(
        key: CacheKeys.characters,
        items: [
          {
            'id': 2,
            'symbol': '𖺢',
            'unicode_code': 'U+16EA2',
            'name': 'Erfe B',
          }
        ],
      );

      // Simuler une coupure ou panne serveur 500
      final mockApi = ApiClient(
        client: MockClient((request) async {
          return http.Response('Server Error', 500);
        }),
      );

      final service = CachedContentService(
        backendStatusService: AlwaysOnlineBackend(),
        alphabetApiService: AlphabetApiService(apiClient: mockApi),
        cacheService: cacheService,
      );

      final results = await service.loadCharacters(forceRefresh: true);

      // Doit utiliser le repli du cache local
      expect(results.length, 1);
      expect(results.first.symbol, '𖺢');
      expect(ContentSourceState.instance.getSource(CacheKeys.characters), ContentSourceType.localCache);
    });

    test('une recherche sans résultat sur le serveur retourne une liste vide sans réinjecter le cache', () async {
      final cacheService = OnlineContentCacheService();

      // Pré-remplir le cache avec un mot
      await cacheService.saveList(
        key: CacheKeys.words,
        items: [
          {
            'id': 10,
            'beriya_text': '𖺡𖺣',
            'translation_fr': 'Soleil',
          }
        ],
      );

      // Recherche en ligne renvoyant 0 résultat
      final mockApi = ApiClient(
        client: MockClient((request) async {
          return http.Response(jsonEncode({'results': []}), 200);
        }),
      );

      final service = CachedContentService(
        backendStatusService: AlwaysOnlineBackend(),
        vocabularyApiService: VocabularyApiService(apiClient: mockApi),
        cacheService: cacheService,
      );

      final results = await service.loadWords(search: 'introuvable', forceRefresh: true);

      expect(results, isEmpty);
      expect(ContentSourceState.instance.getSource(CacheKeys.words), ContentSourceType.empty);
    });
  });
}
