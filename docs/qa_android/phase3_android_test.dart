// Device-only QA harness, copied into an isolated applicationId-suffixed clone.
// integration_test is added to that clone only. No mocked preferences/audio/files.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/main.dart' as application;
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/audio/audio_url_player.dart';
import 'package:mobile/core/cache/cached_content_service.dart';
import 'package:mobile/core/device/device_id_service.dart';
import 'package:mobile/core/storage/app_directories.dart';
import 'package:mobile/core/sync/sync_manager.dart';
import 'package:mobile/features/learning/models/learning_unit_model.dart';
import 'package:mobile/features/offline_packs/services/local_pack_reader_service.dart';
import 'package:mobile/features/offline_packs/services/offline_content_service.dart';
import 'package:mobile/features/offline_packs/services/offline_pack_api_service.dart';
import 'package:mobile/features/offline_packs/services/offline_pack_download_service.dart';
import 'package:mobile/features/progress/services/unit_progress_local_storage.dart';
import 'package:mobile/features/quiz/quiz_api_service.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mobile/shared/beriya/beriya_keyboard.dart';

const stage = String.fromEnvironment('QA_STAGE', defaultValue: 'online');
final results = <String, dynamic>{'stage': stage, 'scope': 'native Android QA clone'};

Future<int> directoryBytes(Directory directory) async {
  var count = 0;
  await for (final entry in directory.list(recursive: true, followLinks: false)) {
    if (entry is File) count += await entry.length();
  }
  return count;
}

Future<void> writeResults() async {
  final root = await AppDirectories.getAppRootDirectory();
  await File('${root.path}/qa_$stage.json').writeAsString(jsonEncode(results), flush: true);
  print('QA_RESULT ${jsonEncode(results)}');
}

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 45));
  final error = tester.takeException();
  if (error != null) throw error;
}

Future<void> route(WidgetTester tester, String name, {Object? arguments}) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.popUntil((r) => r.isFirst);
  await settle(tester); // Finish native route transitions before pushing again.
  unawaited(navigator.pushNamed(name, arguments: arguments));
  await settle(tester);
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await settle(tester);
}

Future<void> verifyLocalAudio(String path) async {
  expect(await File(path).exists(), isTrue);
  final raw = AudioPlayer();
  final player = AudioUrlPlayer(player: raw);
  final completed = raw.onPlayerComplete.first.timeout(const Duration(seconds: 15));
  await player.playLocalPath(path);
  expect(player.status.value, AudioPlaybackStatus.playing);
  final duration = await raw.getDuration();
  expect(duration?.inMilliseconds ?? 0, greaterThan(0));
  await completed;
  results['native_audio_duration_ms'] = duration?.inMilliseconds;
  results['native_audio_completed'] = true;
  await player.dispose();
}

Future<LearningUnitModel> sourceUnit() async {
  final prefs = await SharedPreferences.getInstance();
  final slug = prefs.getString('qa_unit_slug');
  final units = await OfflineContentService().loadUnits();
  return units.firstWhere((u) => slug == null
      ? u.effectiveCoreFlow.any((s) => s['step_type'] == 'discrimination') &&
        u.effectiveCoreFlow.any((s) => s['step_type'] == 'keyboard_encoding')
      : u.slug == slug);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('phase3 native $stage', (tester) async {
    try {
      final launch = Stopwatch()..start();
      await application.main();
      await settle(tester);
      results['main_to_first_settled_frame_ms'] = launch.elapsedMilliseconds;
      final prefs = await SharedPreferences.getInstance();
      final root = await AppDirectories.getAppRootDirectory();
      final storage = UnitProgressLocalStorage();
      if (stage == 'online') {
        expect((await storage.getAllProgress()).isEmpty, isTrue, reason: 'Use a new QA installation; never clear an existing app automatically.');
        final packs = await OfflinePackApiService().fetchPacks();
        final pack = packs.firstWhere((p) => p.slug == 'qa-phase3');
        final before = await directoryBytes(root);
        final watch = Stopwatch()..start();
        await OfflinePackDownloadService().downloadAndExtract(pack);
        final firstDownloadMs = watch.elapsedMilliseconds;
        // Re-import the exact same pack a 2nd time to verify idempotence (P3-02).
        await OfflinePackDownloadService().downloadAndExtract(pack);
        final installedAfterReimport = await LocalPackReaderService().listInstalledPacks();
        expect(installedAfterReimport.where((p) => p.slug == 'qa-phase3').length, 1);
        await CachedContentService().loadUnits(forceRefresh: true);
        await CachedContentService().loadQuizzes(forceRefresh: true);
        await CachedContentService().loadQuizzes(forceRefresh: true);
        results.addAll({'pack_download_extract_ms': firstDownloadMs,
          'pack_reimported_twice_idempotent': true,
          'pack_advertised_bytes_approx': (pack.sizeMb * 1024 * 1024).round(),
          'documents_bytes_before': before, 'documents_bytes_after': await directoryBytes(root)});
        final unit = await sourceUnit();
        await prefs.setString('qa_unit_slug', unit.slug);
        final lessons = await OfflineContentService().loadLessons();
        final quizzes = await OfflineContentService().loadQuizzes();
        expect(lessons, isNotEmpty);
        expect(quizzes, isNotEmpty);
        await verifyLocalAudio(lessons.first.items.first.audioUrl!);
        await route(tester, '/my-packs');
        results['my_packs_rendered'] = true;
        await route(tester, '/quiz');
        results['quiz_rendered'] = true;
        final open = Stopwatch()..start();
        await route(tester, '/unit-practice', arguments: unit.slug);
        results['lesson_open_to_settled_ms'] = open.elapsedMilliseconds;
        final next = find.byKey(const ValueKey('learning-next'));
        expect(next, findsOneWidget);
        await tap(tester, next); // First auditory discovery -> discrimination.
        final step = unit.effectiveCoreFlow[1];
        await tap(tester, find.byKey(ValueKey('answer-1-${step['target_symbol']}')));
        await tap(tester, next);
        final progress = (await storage.getProgress(unit.slug))!;
        expect(progress.currentStep, 2);
        await prefs.setString('qa_expected_progress', jsonEncode(progress.toJson()));
        results['saved_step_before_process_stop'] = progress.currentStep;
        results['saved_answers_before_process_stop'] = progress.quizzesAnswered;
      } else if (stage == 'offline') {
        final unit = await sourceUnit();
        final expected = jsonDecode(prefs.getString('qa_expected_progress')!) as Map<String, dynamic>;
        final progress = (await storage.getProgress(unit.slug))!;
        expect(progress.toJson(), expected);
        final packs = await LocalPackReaderService().listInstalledPacks();
        expect(packs.any((p) => p.slug == 'qa-phase3'), isTrue);
        final lessons = await OfflineContentService().loadLessons();
        await verifyLocalAudio(lessons.first.items.first.audioUrl!);
        await route(tester, '/my-packs');
        await route(tester, '/quiz');
        final opening = Stopwatch()..start();
        await route(tester, '/unit-practice', arguments: unit.slug);
        results['offline_lesson_open_to_settled_ms'] = opening.elapsedMilliseconds;
        final steps = unit.effectiveCoreFlow;
        for (var i = progress.currentStep; i < steps.length; i++) {
          final step = steps[i];
          if (step['step_type'] == 'discrimination') {
            await tap(tester, find.byKey(ValueKey('answer-$i-${step['target_symbol']}')));
          } else if (step['step_type'] == 'keyboard_encoding') {
            for (final rune in (step['target_word'] as String).runes) {
              final key = find.descendant(of: find.byType(BeriyaKeyboard), matching: find.text(String.fromCharCode(rune))).first;
              await tap(tester, key);
            }
            await tap(tester, find.byKey(const ValueKey('validate-encoding')));
          }
          expect(step['step_type'], isNot('tracing'));
          await tap(tester, find.byKey(const ValueKey('learning-next')));
        }
        final finished = (await storage.getProgress(unit.slug))!;
        expect(finished.completed, isTrue);
        results.addAll({'restored_step': progress.currentStep, 'offline_completed': finished.completed,
          'offline_score': finished.bestScorePercent, 'documents_bytes': await directoryBytes(root)});
        final sync = await SyncManager().syncAll();
        expect(sync.success, isFalse, reason: 'The QA USB tunnel must be removed while offline.');
        expect((await storage.getProgress(unit.slug))!.toJson(), finished.toJson());
        results['offline_sync_rejected_and_local_preserved'] = true;
      } else if (stage == 'resync') {
        final unit = await sourceUnit();
        final local = (await storage.getProgress(unit.slug))!;
        expect(local.completed, isTrue);
        final identity = DeviceIdService();
        final id = await identity.getOrCreateDeviceId();
        final token = await identity.getOrCreateDeviceToken();
        final api = ApiClient();
        final good = await SyncManager().syncAll();
        expect(good.success, isTrue);
        final rejected = await api.postMap('/progress/unit-progress/sync/', body: {'items': [{
          'unit_slug': unit.slug, 'device_id': id, 'device_token': 'synthetic-invalid-qa-token', 'lessons_seen': 99,
        }]}, headers: {'X-Device-Id': id, 'X-Device-Token': 'synthetic-invalid-qa-token'});
        expect(rejected['error_count'], 1);
        expect((await storage.getProgress(unit.slug))!.toJson(), local.toJson());
        final stale = await api.postMap('/progress/unit-progress/sync/', body: {'items': [{
          'unit_slug': unit.slug, 'device_id': id, 'device_token': token,
          'updated_at': '2000-01-01T00:00:00Z', 'score_percent': 0, 'quizzes_answered': 0,
        }]}, headers: {'X-Device-Id': id, 'X-Device-Token': token});
        expect(stale['synced_count'], 1);
        final remote = await api.getMap('/progress/unit-progress/', query: {'device_id': id}, headers: {'X-Device-Token': token});
        final row = (remote['results'] as List).single as Map;
        expect(row['best_score_percent'], local.bestScorePercent);
        expect(row['completed'], isTrue);
        expect((await SyncManager().syncAll()).success, isTrue);
        results.addAll({'sync_success': true, 'invalid_token_rejected': true,
          'stale_update_preserved_score': true, 'local_preserved_after_refusal': true,
          'authentication_ui': 'not implemented', 'expiring_token': 'not implemented; invalid bearer tested'});
      } else if (stage == 'quiz-check') {
        // Exercise the real refresh path deterministically, rather than relying
        // on the race between startup preloading and opening the quiz screen.
        await CachedContentService().loadQuizzes(forceRefresh: true);
        await CachedContentService().loadQuizzes(forceRefresh: true);
        final questions = await QuizApiService().fetchQuizzes();
        questions.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        final question = questions.first;
        final correct = question.options[question.correctIndex];
        final target = correct.textFrOut.isNotEmpty ? correct.textFrOut
            : correct.characterSymbol.isNotEmpty ? correct.characterSymbol
            : correct.wordText.isNotEmpty ? correct.wordText : correct.text;
        await route(tester, '/quiz');
        await tap(tester, find.text(target).last);
        final scoreConfirmed = find.text('Score provisoire : 1/${questions.length}').evaluate().isNotEmpty;
        final feedbackCorrect = find.text('Correct, très bien !').evaluate().isNotEmpty;
        await route(tester, '/quiz');
        final reset = find.text('Score provisoire : 0/${questions.length}').evaluate().isNotEmpty;
        results.addAll({'answer_scored_correct': scoreConfirmed,
          'correct_feedback_displayed': feedbackCorrect,
          'standalone_quiz_resets_after_reopen': reset});
        expect(scoreConfirmed, isTrue);
        expect(feedbackCorrect, isTrue, reason: 'Feedback must use the shuffled display index, as scoring already does.');
      } else {
        fail('Unknown QA_STAGE');
      }
      results['passed'] = true;
    } catch (error) {
      results.addAll({'passed': false, 'failure': error.toString()});
      rethrow;
    } finally {
      await writeResults();
    }
  }, timeout: const Timeout(Duration(minutes: 6)));
  if (stage == 'offline') {
    testWidgets('downloaded audio must remain usable through the production cache', (tester) async {
      final local = await sourceUnit();
      final cached = (await CachedContentService().loadUnits()).firstWhere((u) => u.slug == local.slug);
      final url = cached.effectiveCoreFlow.map((s) => s['audio_url']).whereType<String>().firstWhere((u) => u.isNotEmpty);
      final player = AudioUrlPlayer();
      try {
        await player.playUrl(url);
        final outcome = {'scenario': 'cached unit audio while offline',
          'cached_reference_is_remote': url.startsWith('http'),
          'native_status': player.status.value.name,
          'passed': player.status.value == AudioPlaybackStatus.playing};
        final root = await AppDirectories.getAppRootDirectory();
        await File('${root.path}/qa_cached_audio.json').writeAsString(jsonEncode(outcome), flush: true);
        print('QA_CACHE_AUDIO ${jsonEncode(outcome)}');
        expect(player.status.value, AudioPlaybackStatus.playing);
      } finally {
        await player.dispose();
      }
    });
    testWidgets('cached quiz identifiers must remain unique offline', (tester) async {
      final quizzes = await CachedContentService().loadQuizzes();
      final ids = quizzes.map((q) => q.id).toSet();
      final outcome = {'scenario': 'quiz cache uniqueness after online refresh',
        'cached_count': quizzes.length, 'unique_ids': ids.length,
        'passed': quizzes.length == ids.length};
      final root = await AppDirectories.getAppRootDirectory();
      await File('${root.path}/qa_cached_quizzes.json').writeAsString(jsonEncode(outcome), flush: true);
      print('QA_CACHE_QUIZZES ${jsonEncode(outcome)}');
      expect(quizzes.length, ids.length);
    });
    testWidgets('installed packs stay reachable from the offline catalogue', (tester) async {
      await application.main();
      await settle(tester);
      await route(tester, '/offline-packs');
      final context = tester.element(find.byType(Scaffold).last);
      final label = AppLocalizations.of(context)!.myDownloads;
      final found = find.text(label).evaluate().isNotEmpty;
      final installed = await LocalPackReaderService().listInstalledPacks();
      final outcome = {'scenario': 'offline catalogue local access',
        'installed_packs': installed.length, 'my_downloads_link_present': found,
        'passed': found && installed.isNotEmpty};
      final root = await AppDirectories.getAppRootDirectory();
      await File('${root.path}/qa_offline_catalogue.json').writeAsString(jsonEncode(outcome), flush: true);
      print('QA_OFFLINE_CATALOGUE ${jsonEncode(outcome)}');
      expect(found, isTrue);
    });
  }
}
