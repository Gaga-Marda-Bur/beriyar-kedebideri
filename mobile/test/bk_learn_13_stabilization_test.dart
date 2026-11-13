import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/cache/cache_keys.dart';
import 'package:mobile/core/cache/cached_content_service.dart';
import 'package:mobile/core/cache/memory_content_cache.dart';
import 'package:mobile/core/cache/online_content_cache_service.dart';
import 'package:mobile/core/network/backend_status_service.dart';
import 'package:mobile/core/sync/sync_manager.dart';
import 'package:mobile/features/learning/engine/learning_session.dart';
import 'package:mobile/features/learning/models/learning_theme_model.dart';
import 'package:mobile/features/learning/models/learning_unit_model.dart';
import 'package:mobile/features/lessons/models/lesson_model.dart';
import 'package:mobile/features/offline_packs/services/offline_content_service.dart';
import 'package:mobile/features/offline_packs/services/offline_media_resolver.dart';
import 'package:mobile/features/progress/services/unit_progress_local_storage.dart';
import 'package:mobile/features/progress/services/unit_progress_sync_service.dart';

class _OfflineBackend extends BackendStatusService {
  @override
  Future<bool> isBackendReachable({Duration? cacheDuration}) async => false;
}

class _FakeOfflineContentService extends OfflineContentService {
  final List<LearningThemeModel> themes;
  final List<LearningUnitModel> units;
  final List<LessonModel> lessons;

  _FakeOfflineContentService({
    this.themes = const [],
    this.units = const [],
    this.lessons = const [],
  });

  @override
  Future<List<LearningThemeModel>> loadThemes() async => themes;

  @override
  Future<List<LearningUnitModel>> loadUnits() async => units;

  @override
  Future<List<LessonModel>> loadLessons() async => lessons;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MemoryContentCache.instance.clear();
  });

  test('OfflineMediaResolver resolves /media/ relative paths into local pack dir', () {
    expect(
      OfflineMediaResolver.resolve(
        value: '/media/audio/a.mp3',
        localPackPath: '/data/packs/u1',
      ),
      '/data/packs/u1/audio/a.mp3',
    );
    expect(
      OfflineMediaResolver.resolve(
        value: 'media/audio/b.mp3',
        localPackPath: '/data/packs/u1',
      ),
      '/data/packs/u1/audio/b.mp3',
    );
    expect(
      OfflineMediaResolver.resolve(
        value: '/data/packs/u1/audio/c.mp3',
        localPackPath: '/data/packs/u1',
      ),
      '/data/packs/u1/audio/c.mp3',
    );
    expect(
      OfflineMediaResolver.resolve(
        value: 'assets/audio/erfe/a.mp3',
        localPackPath: '/data/packs/u1',
      ),
      'assets/audio/erfe/a.mp3',
    );
    expect(
      OfflineMediaResolver.resolve(
        value: '/media/../../etc/passwd',
        localPackPath: '/data/packs/u1',
      ),
      isNull,
    );
    expect(
      OfflineMediaResolver.resolve(
        value: '../../secret.mp3',
        localPackPath: '/data/packs/u1',
      ),
      isNull,
    );
    expect(
      OfflineMediaResolver.resolve(
        value: '/etc/passwd',
        localPackPath: '/data/packs/u1',
      ),
      isNull,
    );
  });

  test('CachedContentService merges offline pack themes, units and lessons when partial cache exists', () async {
    final cache = OnlineContentCacheService();
    await cache.saveList(
      key: CacheKeys.themes,
      items: [
        {'id': 1, 'slug': 't1', 'title_fr': 'Thème 1', 'order_index': 1},
      ],
    );
    await cache.saveList(
      key: CacheKeys.units,
      items: [
        {'id': 1, 'slug': 'u1', 'title_fr': 'Unité 1', 'order_index': 1},
      ],
    );
    await cache.saveList(
      key: CacheKeys.lessons,
      items: [
        {'id': 1, 'slug': 'l1', 'unit_slug': 'u1', 'title_fr': 'Leçon 1', 'order_index': 1},
      ],
    );

    final offline = _FakeOfflineContentService(
      themes: [
        LearningThemeModel.fromJson({
          'id': 2,
          'slug': 't2',
          'title_fr': 'Thème 2 Pack',
          'order_index': 2,
        }),
      ],
      units: [
        LearningUnitModel.fromJson({
          'id': 2,
          'slug': 'u2',
          'title_fr': 'Unité 2 Pack',
          'order_index': 2,
        }),
      ],
      lessons: [
        LessonModel.fromJson({
          'id': 2,
          'slug': 'l2',
          'unit_slug': 'u2',
          'title_fr': 'Leçon 2 Pack',
          'order_index': 1,
          'items': [
            {
              'id': 1,
              'item_type': 'listen',
              'audio_url': 'assets/audio/l2.mp3',
            },
          ],
        }),
      ],
    );

    final service = CachedContentService(
      backendStatusService: _OfflineBackend(),
      cacheService: cache,
      offlineContentService: offline,
    );

    final themes = await service.loadThemes();
    final units = await service.loadUnits();
    final u2Lessons = await service.loadLessons(unitSlug: 'u2');

    expect(themes.map((t) => t.slug), containsAll(['t1', 't2']));
    expect(units.map((u) => u.slug), containsAll(['u1', 'u2']));
    expect(u2Lessons.map((l) => l.slug), ['l2']);
    expect(u2Lessons.single.items.single.audioUrl, 'assets/audio/l2.mp3');
  });

  test('local core flow never selects identical distractor symbol in discrimination', () {
    final unit = LearningUnitModel.fromJson({
      'id': 10,
      'slug': 'u-disc',
      'title_fr': 'Test',
      'level': 'A1',
      'status': 'published',
      'order_index': 1,
      'available_offline': true,
      'characters': [
        {
          'id': 1,
          'symbol': '𖺠',
          'character_type': 'vowel',
          'phoneme_ipa': 'a',
        },
      ],
      'distractor_characters': [
        {
          'id': 2,
          'symbol': '𖺠',
          'character_type': 'vowel',
          'phoneme_ipa': 'a',
        },
        {
          'id': 3,
          'symbol': '𖺡',
          'character_type': 'consonant',
          'phoneme_ipa': 'b',
        },
      ],
      'words': [],
    });

    final disc = unit.effectiveCoreFlow.firstWhere(
      (s) => s['step_type'] == 'discrimination',
    );
    expect(disc['target_symbol'], '𖺠');
    expect(disc['other_symbol'], '𖺡');
  });

  test('session progress survives close/reopen and syncs without duplication on reconnect', () async {
    final steps = [
      {'step_type': 'discovery', 'symbol': '𖺠'},
      {'step_type': 'discrimination', 'target_symbol': '𖺠', 'other_symbol': '𖺡'},
      {'step_type': 'keyboard_encoding', 'target_word': '𖺠𖺡'},
    ];
    final weights = {'recognition': 50, 'tracing': 0, 'encoding': 50};
    final storage = UnitProgressLocalStorage();

    final s1 = LearningSession(steps, weights, 70);
    s1.viewed.add(0);
    s1.currentStep = 1;
    s1.answer(true);
    await storage.saveSession('u-resume', s1);

    // Simulate app close & reopen
    final s2 = LearningSession(steps, weights, 70);
    await storage.restoreSession('u-resume', s2);
    expect(s2.currentStep, 1);
    expect(s2.resolved(1), isTrue);
    expect(s2.correctCount, 1);

    s2.currentStep = 2;
    s2.answer(true);
    s2.finished = true;
    await storage.saveSession('u-resume', s2);

    final sentPayloads = <List<dynamic>>[];
    final mockClient = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      sentPayloads.add(body['items'] as List<dynamic>);
      return http.Response(
        jsonEncode({'synced_count': 1, 'error_count': 0, 'synced': [], 'errors': []}),
        200,
      );
    });

    final manager = SyncManager(
      progressStorage: storage,
      progressSyncService: UnitProgressSyncService(
        apiClient: ApiClient(client: mockClient),
      ),
    );
    final res1 = await manager.syncAll();
    final res2 = await manager.syncAll();

    expect(res1.success, isTrue);
    expect(res2.success, isTrue);
    expect(sentPayloads.length, 2);
    expect(sentPayloads[0].length, 1);
    expect((sentPayloads[0].single as Map)['unit_slug'], 'u-resume');
    expect((sentPayloads[0].single as Map)['best_score_percent'] ?? (sentPayloads[0].single as Map)['score_percent'], 100);
    mockClient.close();
  });

  test('OfflineMediaResolver + File integration resolves and validates non-empty audio', () async {
    final tmp = await Directory.systemTemp.createTemp('bk_learn_13_');
    try {
      final audioDir = Directory('${tmp.path}/audio')..createSync(recursive: true);
      final f = File('${audioDir.path}/sample.mp3')..writeAsBytesSync([1, 2, 3, 4]);
      final resolved = OfflineMediaResolver.resolve(
        value: '/media/audio/sample.mp3',
        localPackPath: tmp.path,
      );
      expect(resolved, '${tmp.path}/audio/sample.mp3');
      expect(File(resolved!).existsSync(), isTrue);
      expect(f.lengthSync(), 4);
    } finally {
      await tmp.delete(recursive: true);
    }
  });
}
