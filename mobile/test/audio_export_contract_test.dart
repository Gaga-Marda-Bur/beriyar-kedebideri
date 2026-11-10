import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/features/lessons/models/lesson_model.dart';
import 'package:mobile/features/offline_packs/models/lesson_pack_model.dart';
import 'package:mobile/features/offline_packs/services/local_pack_reader_service.dart';
import 'package:mobile/features/offline_packs/services/offline_content_service.dart';
import 'package:mobile/features/offline_packs/services/offline_pack_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('bk-audio-contract-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => temporary.path,
        );
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await temporary.delete(recursive: true);
  });

  test(
    'Django ZIP installs and lesson/quiz audio survives reader restart offline',
    () async {
      // Real exporter output containing synthetic silence, never language content.
      final bytes = await File('test/fixtures/audio_export.zip').readAsBytes();
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        return http.Response.bytes(bytes, 200);
      });
      final pack = LessonPackModel.fromJson({
        'id': 1,
        'slug': 'audio-contract',
        'version': 1,
        'file_url': 'https://example.invalid/audio-contract.zip',
        'is_downloadable': true,
        'checksum': sha256.convert(bytes).toString(),
      });
      await OfflinePackDownloadService(client: client).downloadAndExtract(pack);
      client.close();
      expect(requests, 1);

      // Fresh reader/content service: no downloader or API is used from here.
      final reader = LocalPackReaderService();
      final installed = await reader.listInstalledPacks();
      expect(installed, hasLength(1));
      final content = OfflineContentService(readerService: reader);
      final lessons = await content.loadLessons();
      final quizzes = await content.loadQuizzes();
      expect(lessons, hasLength(1));
      expect(lessons.single.oralIntroFr, 'Instruction test');
      expect(lessons.single.itemsCount, 1);
      final item = lessons.single.items.single;
      expect(item.repeatCount, 3);
      expect(item.writingHintFr, 'Indice test');
      expect(item.lesson, lessons.single.id);
      expect(quizzes, hasLength(1));
      expect(quizzes.single.promptTextFr, 'Test audio');
      expect(quizzes.single.hasAudio, isTrue);

      for (final path in [
        item.audioUrl,
        item.slowAudioUrl,
        item.promptAudioUrl,
        item.explanationAudioUrl,
        quizzes.single.questionAudioUrl,
        quizzes.single.questionSlowAudioUrl,
        quizzes.single.explanationAudioUrl,
      ]) {
        expect(path, isNotNull);
        expect(path!.startsWith(installed.single.localPath), isTrue);
        final audio = await File(path).readAsBytes();
        expect(String.fromCharCodes(audio.take(4)), 'RIFF');
        expect(audio.length, greaterThan(44));
      }
      expect(requests, 1);
    },
  );

  test('legacy lesson with no media stays readable with null audio', () {
    final lesson = LessonModel.fromJson({
      'id': 7,
      'slug': 'legacy',
      'title_fr': 'Legacy',
      'items': [
        {'id': 8, 'item_type': 'audio_only', 'audio_url': null},
      ],
    });
    expect(lesson.slug, 'legacy');
    expect(lesson.items.single.audioUrl, isNull);
    expect(lesson.items.single.promptAudioUrl, isNull);
  });
}
