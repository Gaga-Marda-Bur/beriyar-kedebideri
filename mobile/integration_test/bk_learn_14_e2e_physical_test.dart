import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/audio/audio_url_player.dart';
import 'package:mobile/core/cache/cache_keys.dart';
import 'package:mobile/core/cache/cached_content_service.dart';
import 'package:mobile/core/cache/memory_content_cache.dart';
import 'package:mobile/core/cache/online_content_cache_service.dart';
import 'package:mobile/core/network/backend_status_service.dart';
import 'package:mobile/core/storage/app_directories.dart';
import 'package:mobile/core/sync/sync_manager.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mobile/features/editor/services/beriya_pdf_service.dart';
import 'package:mobile/features/learning/engine/learning_session.dart';
import 'package:mobile/features/learning/screens/learning_core_unit_screen.dart';
import 'package:mobile/features/offline_packs/services/local_pack_reader_service.dart';
import 'package:mobile/features/offline_packs/services/offline_content_service.dart';
import 'package:mobile/features/progress/services/unit_progress_local_storage.dart';
import 'package:mobile/features/progress/services/unit_progress_sync_service.dart';

class _OfflineBackend extends BackendStatusService {
  @override
  Future<bool> isBackendReachable({Duration? cacheDuration}) async => false;
}

Uint8List _minimalWavBytes() {
  const sampleRate = 8000;
  const numSamples = 800;
  const dataSize = numSamples * 2;
  final bd = ByteData(44 + dataSize);
  bd.setUint8(0, 0x52);
  bd.setUint8(1, 0x49);
  bd.setUint8(2, 0x46);
  bd.setUint8(3, 0x46);
  bd.setUint32(4, 36 + dataSize, Endian.little);
  bd.setUint8(8, 0x57);
  bd.setUint8(9, 0x41);
  bd.setUint8(10, 0x56);
  bd.setUint8(11, 0x45);
  bd.setUint8(12, 0x66);
  bd.setUint8(13, 0x6D);
  bd.setUint8(14, 0x74);
  bd.setUint8(15, 0x20);
  bd.setUint32(16, 16, Endian.little);
  bd.setUint16(20, 1, Endian.little);
  bd.setUint16(22, 1, Endian.little);
  bd.setUint32(24, sampleRate, Endian.little);
  bd.setUint32(28, sampleRate * 2, Endian.little);
  bd.setUint16(32, 2, Endian.little);
  bd.setUint16(34, 16, Endian.little);
  bd.setUint8(36, 0x64);
  bd.setUint8(37, 0x61);
  bd.setUint8(38, 0x74);
  bd.setUint8(39, 0x61);
  bd.setUint32(40, dataSize, Endian.little);
  return bd.buffer.asUint8List();
}

List<int> _buildQaPackZip() {
  final archive = Archive();

  void addJson(String name, Object data) {
    final bytes = utf8.encode(jsonEncode(data));
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  addJson('metadata.json', {
    'slug': 'pack-qa-14',
    'title': 'Pack QA 14',
    'version': 1,
  });
  addJson('themes.json', [
    {
      'id': 914,
      'slug': 't-qa-14',
      'title_fr': 'Thème QA 14',
      'order_index': 1,
    },
  ]);
  addJson('units.json', [
    {
      'id': 914,
      'slug': 'u-qa-14',
      'theme_slug': 't-qa-14',
      'title_fr': 'Unité QA 14',
      'level': 'A1',
      'status': 'published',
      'order_index': 1,
      'available_offline': true,
      'enable_tracing': false,
      'weight_recognition': 50,
      'weight_tracing': 0,
      'weight_encoding': 50,
      'min_score_to_pass': 70,
      'characters': [
        {
          'id': 901,
          'symbol': '𖺠',
          'character_type': 'vowel',
          'phoneme_ipa': 'a',
          'audio_url': '/media/audio/a.wav',
        },
        {
          'id': 902,
          'symbol': '𖺡',
          'character_type': 'consonant',
          'phoneme_ipa': 'b',
          'audio_url': '/media/audio/a.wav',
        },
      ],
      'distractor_characters': [
        {
          'id': 903,
          'symbol': '𖺡',
          'character_type': 'consonant',
          'phoneme_ipa': 'b',
        },
      ],
      'words': [
        {
          'id': 904,
          'beriya_text': '𖺠𖺡',
          'latin_transcription': 'ab',
          'french_translation': 'père (test)',
          'audio_url': '/media/audio/a.wav',
        },
      ],
      'core_flow': [
        {
          'step_type': 'discovery',
          'symbol': '𖺠',
          'phoneme_ipa': 'a',
          'audio_url': '/media/audio/a.wav',
        },
        {
          'step_type': 'discrimination',
          'target_symbol': '𖺠',
          'other_symbol': '𖺡',
          'audio_url': '/media/audio/a.wav',
        },
        {
          'step_type': 'keyboard_encoding',
          'target_word': '𖺠',
          'latin_transcription': 'a',
          'french_translation': 'son a',
          'audio_url': '/media/audio/a.wav',
        },
      ],
    },
  ]);
  addJson('characters.json', [
    {
      'id': 901,
      'symbol': '𖺠',
      'character_type': 'vowel',
      'phoneme_ipa': 'a',
      'audio_url': '/media/audio/a.wav',
    },
  ]);
  addJson('words.json', [
    {
      'id': 904,
      'beriya_text': '𖺠𖺡',
      'latin_transcription': 'ab',
      'french_translation': 'père (test)',
      'audio_url': '/media/audio/a.wav',
    },
  ]);
  addJson('lessons.json', [
    {
      'id': 914,
      'slug': 'l-qa-14',
      'unit_slug': 'u-qa-14',
      'title_fr': 'Leçon QA 14',
      'order_index': 1,
      'items': [
        {
          'id': 1,
          'item_type': 'listen',
          'audio_url': '/media/audio/a.wav',
        },
      ],
    },
  ]);
  addJson('quizzes.json', []);

  final wav = _minimalWavBytes();
  archive.addFile(ArchiveFile('audio/a.wav', wav.length, wav));

  return ZipEncoder().encode(archive)!;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('BK-LEARN-14 E2E pédagogique hors ligne sur Samsung SM-A336E',
      (tester) async {
    expect(const bool.fromEnvironment('BK_TOOLS_QA'), isTrue);
    expect(BeriyaPdfService.experimentalArabicPdfEnabled, isFalse);

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    MemoryContentCache.instance.clear();

    final packDir = await AppDirectories.getExtractedPackDirectory(
      slug: 'pack-qa-14',
      version: 1,
    );
    if (packDir.existsSync()) {
      packDir.deleteSync(recursive: true);
    }

    // 1-2. Local HTTP pack download & extraction
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      if (req.uri.path == '/pack.zip') {
        req.response.statusCode = 200;
        req.response.add(_buildQaPackZip());
      } else {
        req.response.statusCode = 404;
      }
      await req.response.close();
    });

    try {
      final zipResp = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/pack.zip'),
      );
      expect(zipResp.statusCode, 200);
      await server.close(force: true);

      final decoded = ZipDecoder().decodeBytes(zipResp.bodyBytes);
      for (final file in decoded) {
        if (file.isFile) {
          final out = File('${packDir.path}/${file.name}');
          out.parent.createSync(recursive: true);
          out.writeAsBytesSync(file.content as List<int>);
        }
      }
      File('${packDir.path}/local_metadata.json').writeAsStringSync(
        jsonEncode({'status': 'validated'}),
      );

      // 3-5. Offline restart simulation (partial cache + disk pack)
      final cache = OnlineContentCacheService();
      await cache.saveList(
        key: CacheKeys.themes,
        items: [
          {'id': 1, 'slug': 't1', 'title_fr': 'Thème en cache', 'order_index': 2},
        ],
      );
      MemoryContentCache.instance.clear();

      final contentService = CachedContentService(
        backendStatusService: _OfflineBackend(),
        cacheService: cache,
        offlineContentService: OfflineContentService(
          readerService: LocalPackReaderService(),
        ),
      );

      final themes = await contentService.loadThemes();
      final units = await contentService.loadUnits();
      final lessons = await contentService.loadLessons(unitSlug: 'u-qa-14');
      expect(themes.map((t) => t.slug), containsAll(['t-qa-14', 't1']));
      expect(units.map((u) => u.slug), contains('u-qa-14'));
      expect(lessons.map((l) => l.slug), ['l-qa-14']);
      final expectedAudioPath = '${packDir.path}/audio/a.wav';
      expect(lessons.single.items.single.audioUrl, expectedAudioPath);
      expect(File(expectedAudioPath).existsSync(), isTrue);

      // 6. Real Android AudioUrlPlayer playback on extracted local audio
      final player = AudioUrlPlayer();
      await player.playUrl(expectedAudioPath);
      expect(player.status.value, isNot(AudioPlaybackStatus.failed));
      await player.stop();
      await player.dispose();

      // 7-9. Mount real LearningCoreUnitScreen UI & walk through steps
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('fr'),
          home: LearningCoreUnitScreen(
            unitSlug: 'u-qa-14',
            contentService: contentService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 0: discovery
      expect(find.text('Unité QA 14 (1/3)'), findsOneWidget);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      // Step 1: discrimination (target '𖺠' vs '𖺡')
      await tester.tap(find.text('𖺠').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuer').last);
      await tester.pumpAndSettle();

      // Step 2: keyboard_encoding (target '𖺠')
      final keyFinder = find.text('𖺠').last;
      await tester.ensureVisible(keyFinder);
      await tester.tap(keyFinder);
      await tester.pumpAndSettle();
      final validerFinder = find.text('Valider').last;
      await tester.ensureVisible(validerFinder);
      await tester.tap(validerFinder);
      await tester.pumpAndSettle();
      final terminerFinder = find.text('Terminer').last;
      await tester.ensureVisible(terminerFinder);
      await tester.tap(terminerFinder);
      await tester.pumpAndSettle();

      // Verify summary / completion state and persisted score
      final storage = UnitProgressLocalStorage();
      final saved = await storage.getProgress('u-qa-14');
      expect(saved, isNotNull);
      expect(saved!.completed, isTrue);
      expect(saved.bestScorePercent, 100);

      // 10-11. Reopen UI after memory cache clear -> progress preserved
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      MemoryContentCache.instance.clear();

      final reopenedStorage = UnitProgressLocalStorage();
      final reopenedProgress = await reopenedStorage.getProgress('u-qa-14');
      expect(reopenedProgress, isNotNull);
      expect(reopenedProgress!.completed, isTrue);
      expect(reopenedProgress.bestScorePercent, 100);

      // Verify LearningSession resume integrity on saved session
      final unit = units.firstWhere((u) => u.slug == 'u-qa-14');
      final session = LearningSession(unit.effectiveCoreFlow, {
        'recognition': unit.weightRecognition,
        'tracing': 0,
        'encoding': unit.weightEncoding,
      }, unit.minScoreToPass);
      await reopenedStorage.restoreSession('u-qa-14', session);
      expect(session.finished, isTrue);

      // 12. Reconnect sync without duplication
      final syncedItems = <List<dynamic>>[];
      final mockClient = MockClient((req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        syncedItems.add(body['items'] as List<dynamic>);
        return http.Response(
          jsonEncode({
            'synced_count': 1,
            'error_count': 0,
            'synced': [],
            'errors': [],
          }),
          200,
        );
      });
      final syncManager = SyncManager(
        progressStorage: reopenedStorage,
        progressSyncService: UnitProgressSyncService(
          apiClient: ApiClient(client: mockClient),
        ),
      );
      final r1 = await syncManager.syncAll();
      final r2 = await syncManager.syncAll();
      expect(r1.success, isTrue);
      expect(r2.success, isTrue);
      expect(syncedItems.length, 2);
      expect(syncedItems[0].length, 1);
      expect((syncedItems[0].single as Map)['unit_slug'], 'u-qa-14');
      mockClient.close();
    } finally {
      await server.close(force: true);
      if (packDir.existsSync()) {
        packDir.deleteSync(recursive: true);
      }
      await prefs.clear();
    }
  });
}
