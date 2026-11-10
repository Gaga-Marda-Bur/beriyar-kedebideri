import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/audio/audio_url_player.dart';
import 'package:mobile/core/cache/cache_keys.dart';
import 'package:mobile/core/cache/cached_content_service.dart';
import 'package:mobile/core/cache/content_source.dart';
import 'package:mobile/core/cache/memory_content_cache.dart';
import 'package:mobile/core/cache/online_content_cache_service.dart';
import 'package:mobile/core/network/backend_status_service.dart';
import 'package:mobile/features/learning/models/learning_unit_model.dart';
import 'package:mobile/features/offline_packs/models/lesson_pack_model.dart';
import 'package:mobile/features/offline_packs/models/local_pack_model.dart';
import 'package:mobile/features/offline_packs/screens/offline_packs_screen.dart';
import 'package:mobile/features/offline_packs/services/local_pack_reader_service.dart';
import 'package:mobile/features/offline_packs/services/offline_content_service.dart';
import 'package:mobile/features/offline_packs/services/offline_pack_api_service.dart';
import 'package:mobile/features/progress/models/unit_progress_local_model.dart';
import 'package:mobile/features/progress/services/unit_progress_local_storage.dart';
import 'package:mobile/features/quiz/models/quiz_question_model.dart';
import 'package:mobile/features/quiz/quiz_api_service.dart';
import 'package:mobile/features/quiz/screens/quiz_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';

class AlwaysOnlineBackend extends BackendStatusService {
  @override
  Future<bool> isBackendReachable({Duration? cacheDuration}) async => true;
}

class AlwaysOfflineBackend extends BackendStatusService {
  @override
  Future<bool> isBackendReachable({Duration? cacheDuration}) async => false;
}

class ToggleableBackend extends BackendStatusService {
  bool online;
  ToggleableBackend({this.online = true});

  @override
  Future<bool> isBackendReachable({Duration? cacheDuration}) async => online;
}

class FakeAudioPlayer implements AudioPlayer {
  final events = StreamController<PlayerState>.broadcast(sync: true);
  bool fail = false;
  int stops = 0;
  Source? lastSource;
  @override
  Stream<PlayerState> get onPlayerStateChanged => events.stream;
  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    if (fail) throw StateError('unavailable');
    lastSource = source;
    events.add(PlayerState.playing);
  }

  @override
  Future<void> stop() async {
    stops++;
    events.add(PlayerState.stopped);
  }

  @override
  Future<void> pause() async {
    events.add(PlayerState.paused);
  }

  @override
  Future<void> dispose() async {
    await events.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeOfflinePackApiService extends OfflinePackApiService {
  final bool shouldFail;
  final List<LessonPackModel> onlinePacks;
  FakeOfflinePackApiService({
    this.shouldFail = false,
    this.onlinePacks = const [],
  });

  @override
  Future<List<LessonPackModel>> fetchPacks({
    String? level,
    bool featuredOnly = false,
  }) async {
    if (shouldFail) {
      throw const SocketException('No network connection');
    }
    return onlinePacks;
  }
}

class FakeLocalPackReaderService extends LocalPackReaderService {
  final List<LocalPackModel> packs;
  FakeLocalPackReaderService(this.packs);

  @override
  Future<List<LocalPackModel>> listInstalledPacks() async {
    return packs;
  }
}

class FakeOfflineContentService extends OfflineContentService {
  List<LearningUnitModel> units;
  List<QuizQuestionModel> quizzes;

  FakeOfflineContentService({
    this.units = const [],
    this.quizzes = const [],
  });

  @override
  Future<List<LearningUnitModel>> loadUnits() async => units;

  @override
  Future<List<QuizQuestionModel>> loadQuizzes() async => quizzes;
}

QuizQuestionModel _buildTestQuestion({
  required int id,
  required String slug,
  required String promptText,
  required int correctIndex,
  required List<String> optionTexts,
  String questionType = 'single_choice',
  String? questionAudioUrl,
}) {
  return QuizQuestionModel(
    id: id,
    unit: 1,
    unitSlug: 'test-unit',
    lesson: 1,
    lessonSlug: 'test-lesson',
    questionType: questionType,
    difficulty: 'beginner',
    promptText: promptText,
    promptTextFr: promptText,
    promptTextEn: promptText,
    promptTextAr: '',
    oralPrompt: '',
    oralPromptFr: '',
    oralPromptEn: '',
    oralPromptAr: '',
    character: null,
    characterSymbol: '',
    characterName: '',
    word: null,
    wordText: '',
    wordLatin: '',
    questionImageUrl: null,
    questionAudioUrl: questionAudioUrl,
    questionSlowAudioUrl: null,
    correctTextAnswer: optionTexts[correctIndex],
    correctIndex: correctIndex,
    explanation: 'Explication',
    explanationFr: 'Explication',
    explanationEn: '',
    explanationAr: '',
    explanationAudioUrl: null,
    orderIndex: id,
    points: 10,
    minOptionsRequired: 2,
    status: 'published',
    isActive: true,
    availableOffline: true,
    options: List.generate(
      optionTexts.length,
      (i) => QuizOptionModel(
        id: id * 10 + i,
        question: id,
        text: optionTexts[i],
        textFr: optionTexts[i],
        textEn: optionTexts[i],
        textAr: '',
        textFrOut: optionTexts[i],
        textEnOut: optionTexts[i],
        textArOut: '',
        character: null,
        characterSymbol: '',
        characterName: '',
        characterLatin: '',
        word: null,
        wordText: '',
        wordLatin: '',
        imageUrl: null,
        orderIndex: i,
      ),
    ),
    optionsTextFr: optionTexts,
    optionsTextEn: optionTexts,
    optionsTextAr: [],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MemoryContentCache.instance.clear();
    ContentSourceState.instance.clear();
  });

  group('Correctif 1 — Résolution des fichiers audio (P3-01)', () {
    test('le cache hors ligne résout les URLs audio distantes vers les fichiers locaux du pack', () async {
      final cacheService = OnlineContentCacheService();

      await cacheService.saveList(
        key: CacheKeys.units,
        items: [
          {
            'id': 1,
            'slug': 'test-unit-1',
            'theme': 1,
            'theme_slug': 'theme-1',
            'theme_title_fr': 'Thème 1',
            'title_fr': 'Unité 1',
            'title_en': 'Unit 1',
            'title_ar': 'الوحدة 1',
            'description_fr': 'Description',
            'level': 'A1',
            'order_index': 1,
            'estimated_minutes': 5,
            'min_score_to_pass': 70,
            'status': 'published',
            'is_active': true,
            'available_offline': true,
            'core_flow': [
              {
                'step_type': 'discovery',
                'target_symbol': '𖺠',
                'audio_url': 'http://127.0.0.1:8765/media/audio_assets/published/test.wav',
              }
            ],
          }
        ],
      );

      final tempDir = await Directory.systemTemp.createTemp('bk_p3_audio_test_');
      final localAudioFile = File('${tempDir.path}/test_local.wav');
      await localAudioFile.writeAsBytes([0, 1, 2, 3]);

      final packUnit = LearningUnitModel.fromJson({
        'id': 1,
        'slug': 'test-unit-1',
        'theme': 1,
        'theme_slug': 'theme-1',
        'theme_title_fr': 'Thème 1',
        'title_fr': 'Unité 1',
        'title_en': 'Unit 1',
        'title_ar': 'الوحدة 1',
        'description_fr': 'Description',
        'level': 'A1',
        'order_index': 1,
        'estimated_minutes': 5,
        'min_score_to_pass': 70,
        'status': 'published',
        'is_active': true,
        'available_offline': true,
        'core_flow': [
          {
            'step_type': 'discovery',
            'target_symbol': '𖺠',
            'audio_url': localAudioFile.path,
          }
        ],
      });

      final service = CachedContentService(
        backendStatusService: AlwaysOfflineBackend(),
        cacheService: cacheService,
        offlineContentService: FakeOfflineContentService(units: [packUnit]),
      );

      final units = await service.loadUnits();
      final audioUrl = units.first.effectiveCoreFlow.first['audio_url'] as String?;

      expect(audioUrl, isNotNull);
      expect(audioUrl!.startsWith('http'), isFalse,
          reason: 'L’audio en mode hors ligne doit utiliser le pack local au lieu de conserver l’URL HTTP distante');
      expect(audioUrl, localAudioFile.path);

      await tempDir.delete(recursive: true);
    });

    test('streaming distant conservé en ligne quand aucun média local disponible', () async {
      final cacheService = OnlineContentCacheService();
      await cacheService.saveList(
        key: CacheKeys.units,
        items: [
          {
            'id': 2,
            'slug': 'unit-stream',
            'theme': 1,
            'title_fr': 'Unité Stream',
            'level': 'A1',
            'order_index': 2,
            'estimated_minutes': 5,
            'min_score_to_pass': 70,
            'status': 'published',
            'is_active': true,
            'available_offline': true,
            'core_flow': [
              {
                'step_type': 'discovery',
                'target_symbol': '𖺡',
                'audio_url': 'https://remote.example/audio.mp3',
              }
            ],
          }
        ],
      );

      final service = CachedContentService(
        backendStatusService: AlwaysOnlineBackend(),
        cacheService: cacheService,
        offlineContentService: FakeOfflineContentService(units: []),
      );

      final units = await service.loadUnits();
      final audioUrl = units.first.effectiveCoreFlow.first['audio_url'];
      expect(audioUrl, 'https://remote.example/audio.mp3',
          reason: 'En ligne, le streaming reste possible si aucune ressource locale n’est présente');
    });

    test('rejet des médias absents, corrompus (0 octet) et supprimés sans chemin local obsolète', () async {
      final tempDir = await Directory.systemTemp.createTemp('bk_corrupt_test_');
      final zeroByteFile = File('${tempDir.path}/zero.wav');
      await zeroByteFile.writeAsBytes([]); // 0 octet

      final validThenDeletedFile = File('${tempDir.path}/to_delete.wav');
      await validThenDeletedFile.writeAsBytes([1, 2, 3, 4]);

      final backend = ToggleableBackend(online: false);
      final cacheService = OnlineContentCacheService();
      final packUnit = LearningUnitModel.fromJson({
        'id': 3,
        'slug': 'unit-delete-test',
        'theme': 1,
        'title_fr': 'Unité Suppression',
        'level': 'A1',
        'order_index': 3,
        'estimated_minutes': 5,
        'min_score_to_pass': 70,
        'status': 'published',
        'is_active': true,
        'available_offline': true,
        'core_flow': [
          {
            'step_type': 'discovery',
            'target_symbol': '𖺠',
            'audio_url': validThenDeletedFile.path,
          }
        ],
      });

      final offlineService = FakeOfflineContentService(units: [packUnit]);
      final service = CachedContentService(
        backendStatusService: backend,
        cacheService: cacheService,
        offlineContentService: offlineService,
      );

      // 1. Tant que le fichier existe et > 0 octet, il est résolu
      final beforeDelete = await service.loadUnits();
      expect(
        beforeDelete.first.effectiveCoreFlow.first['audio_url'],
        validThenDeletedFile.path,
      );

      // 2. Si le fichier local est supprimé (chemin obsolète), même avec le cache mémoire actif,
      // il est immédiatement invalidé (null hors ligne)
      await validThenDeletedFile.delete();
      final afterDelete = await service.loadUnits();
      expect(
        afterDelete.first.effectiveCoreFlow.first['audio_url'],
        isNull,
        reason: 'Un fichier local supprimé ne doit pas laisser de chemin obsolète',
      );

      // 3. Test AudioUrlPlayer sur fichier 0 octet et fichier inexistant
      final player = AudioUrlPlayer(player: FakeAudioPlayer());
      await player.playUrl(zeroByteFile.path);
      expect(player.status.value, AudioPlaybackStatus.failed,
          reason: 'Un fichier de 0 octet corrompu doit échouer immédiatement');

      await player.playUrl('${tempDir.path}/non_existent.wav');
      expect(player.status.value, AudioPlaybackStatus.failed,
          reason: 'Un fichier local inexistant doit échouer immédiatement');

      await player.dispose();
      await tempDir.delete(recursive: true);
    });
  });

  group('Correctif 2 — Doublons de quiz (P3-02)', () {
    test('loadQuizzes répété (global et filtré par unité) est idempotent et ne duplique pas les quiz', () async {
      final cacheService = OnlineContentCacheService();

      final mockApi = ApiClient(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'id': 101,
                  'unit_slug': 'unit-a',
                  'prompt_text_fr': 'Question 1',
                  'question_type': 'single_choice',
                  'order_index': 1,
                  'status': 'published',
                  'is_active': true,
                  'options': [
                    {'id': 1, 'text': 'A'},
                    {'id': 2, 'text': 'B'},
                  ],
                },
                {
                  'id': 102,
                  'unit_slug': 'unit-a',
                  'prompt_text_fr': 'Question 2',
                  'question_type': 'single_choice',
                  'order_index': 2,
                  'status': 'published',
                  'is_active': true,
                  'options': [
                    {'id': 3, 'text': 'C'},
                    {'id': 4, 'text': 'D'},
                  ],
                },
              ]
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final service = CachedContentService(
        backendStatusService: AlwaysOnlineBackend(),
        cacheService: cacheService,
        offlineContentService: FakeOfflineContentService(),
        quizApiService: QuizApiService(apiClient: mockApi),
      );

      // 1er chargement global
      final firstLoad = await service.loadQuizzes(forceRefresh: true);
      expect(firstLoad.length, 2);

      // 2e chargement global (idempotent)
      final secondLoad = await service.loadQuizzes(forceRefresh: true);
      expect(secondLoad.length, 2, reason: 'Un 2e import ne doit pas dupliquer la liste');

      // 3e chargement filtré par unitSlug puis re-global
      await service.loadQuizzes(unitSlug: 'unit-a', forceRefresh: true);
      final thirdLoad = await service.loadQuizzes(forceRefresh: true);
      expect(thirdLoad.length, 2);

      // Vérifier le contenu brut du cache
      final rawCached = await cacheService.readList(key: CacheKeys.quizzes);
      expect(rawCached.length, 2, reason: 'Le cache ne doit contenir que 2 entrées sans doublons');
    });

    test('auto-réparation des doublons existants, réimports de packs et préservation des progressions', () async {
      final cacheService = OnlineContentCacheService();
      final progressStorage = UnitProgressLocalStorage();

      // Sauvegarder une progression utilisateur existante avant réparation
      await progressStorage.saveProgress(
        UnitProgressLocalModel(
          unitSlug: 'premiers-5-caracteres',
          status: 'completed',
          currentStep: 7,
          totalSteps: 8,
          bestScorePercent: 95,
          completed: true,
          lastStage: 'celebration',
          startedAt: DateTime.utc(2026, 11, 9),
          updatedAt: DateTime.utc(2026, 11, 9),
          completedAt: DateTime.utc(2026, 11, 9),
          lessonsSeen: 4,
          quizzesAnswered: 2,
          correctAnswers: 2,
        ),
      );

      // On injecte volontairement un cache corrompu contenant 3 entrées avec le même ID = 500
      await cacheService.saveList(
        key: CacheKeys.quizzes,
        items: [
          {'id': 500, 'unit_slug': 'premiers-5-caracteres', 'prompt_text_fr': 'Question doublon 1', 'order_index': 1, 'options': []},
          {'id': 500, 'unit_slug': 'premiers-5-caracteres', 'prompt_text_fr': 'Question doublon 2', 'order_index': 1, 'options': []},
          {'id': 500, 'unit_slug': 'premiers-5-caracteres', 'prompt_text_fr': 'Question doublon 3', 'order_index': 1, 'options': []},
          {'id': 501, 'unit_slug': 'premiers-5-caracteres', 'prompt_text_fr': 'Question unique', 'order_index': 2, 'options': []},
        ],
      );

      final service = CachedContentService(
        backendStatusService: AlwaysOfflineBackend(),
        cacheService: cacheService,
        offlineContentService: FakeOfflineContentService(),
      );

      final loaded = await service.loadQuizzes();
      expect(loaded.length, 2, reason: 'La déduplication doit réduire les 4 entrées à 2 questions uniques');
      expect(loaded.map((q) => q.id).toList(), [500, 501]);

      // Vérifier que le cache sur disque a été guéri
      final healedDisk = await cacheService.readList(key: CacheKeys.quizzes);
      expect(healedDisk.length, 2, reason: 'La base locale doit être assainie automatiquement');

      // Vérifier que la progression utilisateur est intacte
      final savedProgress = await progressStorage.getProgress('premiers-5-caracteres');
      expect(savedProgress, isNotNull);
      expect(savedProgress!.completed, isTrue);
      expect(savedProgress.bestScorePercent, 95);
    });
  });

  group('Correctif 3 — Accès aux packs hors ligne (P3-03)', () {
    testWidgets('le catalogue hors ligne affiche les packs installés, leur bouton d’ouverture et Mes téléchargements', (tester) async {
      final offlineApi = FakeOfflinePackApiService(shouldFail: true);
      final reader = FakeLocalPackReaderService([
        LocalPackModel(
          metadata: const {
            'slug': 'local-pack-1',
            'title_fr': 'Pack Local QA',
            'level': 'A1',
            'version': 1,
          },
          themes: const [],
          units: const [],
          characters: const [],
          words: const [],
          lessons: const [],
          quizzes: const [],
          localPath: '/data/packs/local-pack-1',
          sizeBytes: 1024,
          downloadedAt: DateTime.now(),
        ),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OfflinePacksScreen(
            apiService: offlineApi,
            readerService: reader,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Bouton "Mes téléchargements" visible
      expect(find.widgetWithText(OutlinedButton, 'Mes téléchargements'), findsOneWidget);

      // 2. Pack installé visible avec badge et action d'ouverture
      expect(find.text('Pack Local QA'), findsOneWidget);
      expect(find.text('Ouvrir le pack'), findsOneWidget);

      // 3. Message clair sur le mode hors ligne du catalogue distant
      expect(find.text('Mode hors ligne — catalogue en ligne indisponible'), findsOneWidget);
    });

    testWidgets('état vide informatif quand aucun pack n’est installé hors ligne', (tester) async {
      final offlineApi = FakeOfflinePackApiService(shouldFail: true);
      final reader = FakeLocalPackReaderService([]);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OfflinePacksScreen(
            apiService: offlineApi,
            readerService: reader,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Mes téléchargements'), findsOneWidget);
      expect(find.text('Aucun pack disponible.'), findsOneWidget);
      expect(find.text('Connectez-vous à Internet pour télécharger des packs et apprendre hors ligne.'), findsOneWidget);
    });
  });

  group('Correctif 4 — Cohérence feedback et score du quiz (P3-04)', () {
    testWidgets('QCM et exercice d’écoute avec options mélangées : cohérence totale entre feedback et score', (tester) async {
      final cacheService = OnlineContentCacheService();
      final question = _buildTestQuestion(
        id: 1,
        slug: 'quiz-test',
        promptText: 'Écoute et trouve la bonne lettre Erfe',
        questionType: 'audio_to_character',
        correctIndex: 2,
        optionTexts: [
          '𖺠 (incorrecte)',
          '𖺵 (incorrecte)',
          '𖺡 (CORRECTE)',
        ],
      );

      await cacheService.saveList(
        key: CacheKeys.quizzes,
        items: [question.toJson()],
      );

      final service = CachedContentService(
        backendStatusService: AlwaysOfflineBackend(),
        cacheService: cacheService,
        offlineContentService: FakeOfflineContentService(quizzes: []),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: QuizScreen(
            cachedContentService: service,
            audioPlayer: AudioUrlPlayer(player: FakeAudioPlayer()),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      final correctFinder = find.text('𖺡 (CORRECTE)');
      expect(correctFinder, findsOneWidget);
      await tester.tap(correctFinder);
      await tester.pumpAndSettle();

      // Score = 1/1 ET Feedback = 'Correct, très bien !'
      expect(find.text('Score provisoire : 1/1'), findsOneWidget);
      expect(find.text('Correct, très bien !'), findsOneWidget,
          reason: 'Le feedback doit utiliser la même source de vérité que le scoring');
      expect(find.text('Pas grave, écoute encore et continue.'), findsNothing);
    });

    testWidgets('mauvaise réponse et tentatives répétées : feedback cohérent et verrouillage', (tester) async {
      final cacheService = OnlineContentCacheService();
      final question = _buildTestQuestion(
        id: 2,
        slug: 'quiz-test-wrong',
        promptText: 'Question de test',
        correctIndex: 1,
        optionTexts: [
          'Option A (incorrecte)',
          'Option B (CORRECTE)',
        ],
      );

      await cacheService.saveList(
        key: CacheKeys.quizzes,
        items: [question.toJson()],
      );

      final service = CachedContentService(
        backendStatusService: AlwaysOfflineBackend(),
        cacheService: cacheService,
        offlineContentService: FakeOfflineContentService(quizzes: []),
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: QuizScreen(
            cachedContentService: service,
            audioPlayer: AudioUrlPlayer(player: FakeAudioPlayer()),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      final wrongFinder = find.text('Option A (incorrecte)');
      expect(wrongFinder, findsOneWidget);
      await tester.tap(wrongFinder);
      await tester.pumpAndSettle();

      expect(find.text('Score provisoire : 0/1'), findsOneWidget);
      expect(find.text('Pas grave, écoute encore et continue.'), findsOneWidget);
      expect(find.text('Correct, très bien !'), findsNothing);

      // Tentative répétée verrouillée
      final correctFinder = find.text('Option B (CORRECTE)');
      await tester.tap(correctFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Score provisoire : 0/1'), findsOneWidget);
    });

    test('évaluation centralisée des saisies clavier : cas limites vides, Unicode Erfe et rejet des erreurs linguistiques', () {
      // 1. Saisie Erfe exacte et normalisation d'espaces périphériques
      expect(
        QuizQuestionModel.evaluateTextAnswer(submitted: '𖺡𖺣', expected: '𖺡𖺣'),
        isTrue,
      );
      expect(
        QuizQuestionModel.evaluateTextAnswer(submitted: '  𖺡𖺣  ', expected: '𖺡𖺣'),
        isTrue,
      );

      // 2. Réponses vides ou espaces seuls systématiquement rejetées
      expect(
        QuizQuestionModel.evaluateTextAnswer(submitted: '', expected: '𖺡𖺣'),
        isFalse,
      );
      expect(
        QuizQuestionModel.evaluateTextAnswer(submitted: '   ', expected: '𖺡𖺣'),
        isFalse,
      );
      expect(
        QuizQuestionModel.evaluateTextAnswer(submitted: '', expected: ''),
        isFalse,
      );

      // 3. Caractères Erfe erronés ou incomplets rejetés
      expect(
        QuizQuestionModel.evaluateTextAnswer(submitted: '𖺡', expected: '𖺡𖺣'),
        isFalse,
      );
      expect(
        QuizQuestionModel.evaluateTextAnswer(submitted: '𖺵𖺣', expected: '𖺡𖺣'),
        isFalse,
      );
    });
  });
}
