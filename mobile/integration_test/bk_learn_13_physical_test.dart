import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/audio/audio_url_player.dart';
import 'package:mobile/core/cache/cache_keys.dart';
import 'package:mobile/core/cache/cached_content_service.dart';
import 'package:mobile/core/cache/memory_content_cache.dart';
import 'package:mobile/core/cache/online_content_cache_service.dart';
import 'package:mobile/core/network/backend_status_service.dart';
import 'package:mobile/core/sync/sync_manager.dart';
import 'package:mobile/features/editor/services/beriya_pdf_service.dart';
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
    required this.themes,
    required this.units,
    required this.lessons,
  });

  @override
  Future<List<LearningThemeModel>> loadThemes() async => themes;

  @override
  Future<List<LearningUnitModel>> loadUnits() async => units;

  @override
  Future<List<LessonModel>> loadLessons() async => lessons;
}

Uint8List _minimalWavBytes() {
  const sampleRate = 8000;
  const numSamples = 800; // 0.1s silence
  const dataSize = numSamples * 2;
  final bd = ByteData(44 + dataSize);
  // RIFF
  bd.setUint8(0, 0x52);
  bd.setUint8(1, 0x49);
  bd.setUint8(2, 0x46);
  bd.setUint8(3, 0x46);
  bd.setUint32(4, 36 + dataSize, Endian.little);
  // WAVE
  bd.setUint8(8, 0x57);
  bd.setUint8(9, 0x41);
  bd.setUint8(10, 0x56);
  bd.setUint8(11, 0x45);
  // fmt
  bd.setUint8(12, 0x66);
  bd.setUint8(13, 0x6D);
  bd.setUint8(14, 0x74);
  bd.setUint8(15, 0x20);
  bd.setUint32(16, 16, Endian.little);
  bd.setUint16(20, 1, Endian.little); // PCM
  bd.setUint16(22, 1, Endian.little); // Mono
  bd.setUint32(24, sampleRate, Endian.little);
  bd.setUint32(28, sampleRate * 2, Endian.little);
  bd.setUint16(32, 2, Endian.little);
  bd.setUint16(34, 16, Endian.little);
  // data
  bd.setUint8(36, 0x64);
  bd.setUint8(37, 0x61);
  bd.setUint8(38, 0x74);
  bd.setUint8(39, 0x61);
  bd.setUint32(40, dataSize, Endian.little);
  return bd.buffer.asUint8List();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('BK-LEARN-13 QA physique Samsung SM-A336E hors ligne', (tester) async {
    expect(const bool.fromEnvironment('BK_TOOLS_QA'), isTrue);
    expect(BeriyaPdfService.experimentalArabicPdfEnabled, isFalse);

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    MemoryContentCache.instance.clear();

    final docsDir = await getApplicationDocumentsDirectory();
    final packDir = Directory('${docsDir.path}/bk_learn_13_qa_pack');
    if (packDir.existsSync()) {
      packDir.deleteSync(recursive: true);
    }
    Directory('${packDir.path}/audio').createSync(recursive: true);
    final wavFile = File('${packDir.path}/audio/sample.wav')
      ..writeAsBytesSync(_minimalWavBytes());

    try {
      // 1. OfflineMediaResolver + real Android AudioUrlPlayer playback
      final resolvedAudio = OfflineMediaResolver.resolve(
        value: '/media/audio/sample.wav',
        localPackPath: packDir.path,
      );
      expect(resolvedAudio, wavFile.path);
      expect(File(resolvedAudio!).existsSync(), isTrue);

      final player = AudioUrlPlayer();
      await player.playUrl(resolvedAudio);
      expect(player.status.value, isNot(AudioPlaybackStatus.failed));
      await player.stop();
      await player.dispose();

      // 2. Partial online cache + offline pack merge
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
                'audio_url': resolvedAudio,
              },
            ],
          }),
        ],
      );

      final contentService = CachedContentService(
        backendStatusService: _OfflineBackend(),
        cacheService: cache,
        offlineContentService: offline,
      );

      final themes = await contentService.loadThemes();
      final units = await contentService.loadUnits();
      final u2Lessons = await contentService.loadLessons(unitSlug: 'u2');
      expect(themes.map((t) => t.slug), containsAll(['t1', 't2']));
      expect(units.map((u) => u.slug), containsAll(['u1', 'u2']));
      expect(u2Lessons.map((l) => l.slug), ['l2']);
      expect(u2Lessons.single.items.single.audioUrl, wavFile.path);

      // 3. Distractor non-duplication
      final discUnit = LearningUnitModel.fromJson({
        'id': 10,
        'slug': 'u-disc',
        'title_fr': 'Test',
        'level': 'A1',
        'status': 'published',
        'order_index': 1,
        'available_offline': true,
        'characters': [
          {'id': 1, 'symbol': '𖺠', 'character_type': 'vowel', 'phoneme_ipa': 'a'},
        ],
        'distractor_characters': [
          {'id': 2, 'symbol': '𖺠', 'character_type': 'vowel', 'phoneme_ipa': 'a'},
          {'id': 3, 'symbol': '𖺡', 'character_type': 'consonant', 'phoneme_ipa': 'b'},
        ],
        'words': [],
      });
      final disc = discUnit.effectiveCoreFlow.firstWhere(
        (s) => s['step_type'] == 'discrimination',
      );
      expect(disc['target_symbol'], '𖺠');
      expect(disc['other_symbol'], '𖺡');

      // 4. Session persistence + duplicate-free sync
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
      await storage.saveSession('u-resume-qa', s1);

      final s2 = LearningSession(steps, weights, 70);
      await storage.restoreSession('u-resume-qa', s2);
      expect(s2.currentStep, 1);
      expect(s2.resolved(1), isTrue);
      expect(s2.correctCount, 1);

      s2.currentStep = 2;
      s2.answer(true);
      s2.finished = true;
      await storage.saveSession('u-resume-qa', s2);

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
      mockClient.close();
    } finally {
      if (packDir.existsSync()) {
        packDir.deleteSync(recursive: true);
      }
      await prefs.clear();
    }
  });
}
