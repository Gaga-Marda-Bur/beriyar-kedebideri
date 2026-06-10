import '../../features/alphabet/alphabet_api_service.dart';
import '../../features/alphabet/models/character_model.dart';
import '../../features/learning/learning_api_service.dart';
import '../../features/learning/models/learning_theme_model.dart';
import '../../features/learning/models/learning_unit_model.dart';
import '../../features/lessons/lessons_api_service.dart';
import '../../features/lessons/models/lesson_model.dart';
import '../../features/no_ena/models/no_ena_publication_model.dart';
import '../../features/no_ena/no_ena_api_service.dart';
import '../../features/offline_packs/services/offline_content_service.dart';
import '../../features/quiz/models/quiz_question_model.dart';
import '../../features/quiz/quiz_api_service.dart';
import '../../features/vocabulary/models/word_model.dart';
import '../../features/vocabulary/vocabulary_api_service.dart';
import '../network/backend_status_service.dart';
import 'cache_keys.dart';
import 'online_content_cache_service.dart';

class CachedContentService {
  final BackendStatusService _backendStatusService;
  final OnlineContentCacheService _cacheService;
  final OfflineContentService _offlineContentService;

  final AlphabetApiService _alphabetApiService;
  final VocabularyApiService _vocabularyApiService;
  final LearningApiService _learningApiService;
  final LessonsApiService _lessonsApiService;
  final QuizApiService _quizApiService;
  final NoEnaApiService _noEnaApiService;

  CachedContentService({
    BackendStatusService? backendStatusService,
    OnlineContentCacheService? cacheService,
    OfflineContentService? offlineContentService,
    AlphabetApiService? alphabetApiService,
    VocabularyApiService? vocabularyApiService,
    LearningApiService? learningApiService,
    LessonsApiService? lessonsApiService,
    QuizApiService? quizApiService,
    NoEnaApiService? noEnaApiService,
  })  : _backendStatusService = backendStatusService ?? BackendStatusService(),
        _cacheService = cacheService ?? OnlineContentCacheService(),
        _offlineContentService = offlineContentService ?? OfflineContentService(),
        _alphabetApiService = alphabetApiService ?? AlphabetApiService(),
        _vocabularyApiService = vocabularyApiService ?? VocabularyApiService(),
        _learningApiService = learningApiService ?? LearningApiService(),
        _lessonsApiService = lessonsApiService ?? LessonsApiService(),
        _quizApiService = quizApiService ?? QuizApiService(),
        _noEnaApiService = noEnaApiService ?? NoEnaApiService();

  Future<List<CharacterModel>> loadCharacters() async {
    final online = await _backendStatusService.isBackendReachable();

    if (online) {
      try {
        final items = await _alphabetApiService.fetchCharacters();

        if (items.isNotEmpty) {
          await _cacheService.saveList(
            key: CacheKeys.characters,
            items: items.map((item) => item.toJson()).toList(),
          );

          return items;
        }
      } catch (_) {}
    }

    final cached = await _cacheService.readList(key: CacheKeys.characters);

    if (cached.isNotEmpty) {
      return cached.map(CharacterModel.fromJson).toList();
    }

    return _offlineContentService.loadCharacters();
  }

  Future<List<WordModel>> loadWords({String? search}) async {
    final online = await _backendStatusService.isBackendReachable();

    if (online) {
      try {
        final items = await _vocabularyApiService.fetchWords(search: search);

        if (items.isNotEmpty) {
          await _cacheService.saveList(
            key: CacheKeys.words,
            items: items.map((item) => item.toJson()).toList(),
          );

          return items;
        }
      } catch (_) {}
    }

    final cached = await _cacheService.readList(key: CacheKeys.words);

    final source = cached.isNotEmpty
        ? cached.map(WordModel.fromJson).toList()
        : await _offlineContentService.loadWords();

    final query = search?.trim().toLowerCase() ?? '';

    if (query.isEmpty) {
      return source;
    }

    return source.where((word) {
      return word.beriyaText.toLowerCase().contains(query) ||
          word.latinTranscription.toLowerCase().contains(query) ||
          word.translationFr.toLowerCase().contains(query) ||
          word.translationEn.toLowerCase().contains(query) ||
          word.translationAr.toLowerCase().contains(query) ||
          word.frenchTranslation.toLowerCase().contains(query) ||
          word.englishTranslation.toLowerCase().contains(query) ||
          word.arabicTranslation.toLowerCase().contains(query);
    }).toList();
  }

  Future<List<LearningThemeModel>> loadThemes() async {
    final online = await _backendStatusService.isBackendReachable();

    if (online) {
      try {
        final items = await _learningApiService.fetchThemes();

        if (items.isNotEmpty) {
          await _cacheService.saveList(
            key: CacheKeys.themes,
            items: items.map((item) => item.toJson()).toList(),
          );

          return items;
        }
      } catch (_) {}
    }

    final cached = await _cacheService.readList(key: CacheKeys.themes);

    if (cached.isNotEmpty) {
      return cached.map(LearningThemeModel.fromJson).toList();
    }

    return _offlineContentService.loadThemes();
  }

  Future<List<LearningUnitModel>> loadUnits() async {
    final online = await _backendStatusService.isBackendReachable();

    if (online) {
      try {
        final items = await _learningApiService.fetchUnits();

        if (items.isNotEmpty) {
          await _cacheService.saveList(
            key: CacheKeys.units,
            items: items.map((item) => item.toJson()).toList(),
          );

          return items;
        }
      } catch (_) {}
    }

    final cached = await _cacheService.readList(key: CacheKeys.units);

    if (cached.isNotEmpty) {
      return cached.map(LearningUnitModel.fromJson).toList();
    }

    return _offlineContentService.loadUnits();
  }

  Future<List<LessonModel>> loadLessons({
    String? unitSlug,
  }) async {
    final online = await _backendStatusService.isBackendReachable();

    if (online) {
      try {
        final items = await _lessonsApiService.fetchLessons(
          unit: unitSlug,
        );

        if (items.isNotEmpty) {
          final allExisting = await _cacheService.readList(
            key: CacheKeys.lessons,
          );

          final existing = allExisting
              .map(LessonModel.fromJson)
              .where((lesson) => lesson.unitSlug != unitSlug)
              .toList();

          final merged = [
            ...existing,
            ...items,
          ];

          await _cacheService.saveList(
            key: CacheKeys.lessons,
            items: merged.map((item) => item.toJson()).toList(),
          );

          return items;
        }
      } catch (_) {}
    }

    final cached = await _cacheService.readList(key: CacheKeys.lessons);

    final source = cached.isNotEmpty
        ? cached.map(LessonModel.fromJson).toList()
        : await _offlineContentService.loadLessons();

    if (unitSlug == null || unitSlug.isEmpty) {
      return source;
    }

    return source.where((lesson) => lesson.unitSlug == unitSlug).toList();
  }

  Future<List<QuizQuestionModel>> loadQuizzes({
    String? unitSlug,
  }) async {
    final online = await _backendStatusService.isBackendReachable();

    if (online) {
      try {
        final items = await _quizApiService.fetchQuizzes(
          unit: unitSlug,
        );

        if (items.isNotEmpty) {
          final allExisting = await _cacheService.readList(
            key: CacheKeys.quizzes,
          );

          final existing = allExisting
              .map(QuizQuestionModel.fromJson)
              .where((quiz) => quiz.unitSlug != unitSlug)
              .toList();

          final merged = [
            ...existing,
            ...items,
          ];

          await _cacheService.saveList(
            key: CacheKeys.quizzes,
            items: merged.map((item) => item.toJson()).toList(),
          );

          return items;
        }
      } catch (_) {}
    }

    final cached = await _cacheService.readList(key: CacheKeys.quizzes);

    final source = cached.isNotEmpty
        ? cached.map(QuizQuestionModel.fromJson).toList()
        : await _offlineContentService.loadQuizzes();

    if (unitSlug == null || unitSlug.isEmpty) {
      return source;
    }

    return source.where((quiz) => quiz.unitSlug == unitSlug).toList();
  }

  Future<List<NoEnaPublicationModel>> loadNoEna() async {
    final online = await _backendStatusService.isBackendReachable();

    if (online) {
      try {
        final items = await _noEnaApiService.fetchPublications();

        if (items.isNotEmpty) {
          await _cacheService.saveList(
            key: CacheKeys.noEna,
            items: items.map((item) => item.toJson()).toList(),
          );

          return items;
        }
      } catch (_) {}
    }

    final cached = await _cacheService.readList(key: CacheKeys.noEna);

    if (cached.isNotEmpty) {
      return cached.map(NoEnaPublicationModel.fromJson).toList();
    }

    return [];
  }
}