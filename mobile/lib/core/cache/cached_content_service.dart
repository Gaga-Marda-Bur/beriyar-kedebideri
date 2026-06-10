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
import '../utils/app_logger.dart';
import 'memory_content_cache.dart';

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
  final MemoryContentCache _memoryCache;

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
    MemoryContentCache? memoryCache,
  })  : _backendStatusService = backendStatusService ?? BackendStatusService(),
        _cacheService = cacheService ?? OnlineContentCacheService(),
        _offlineContentService = offlineContentService ?? OfflineContentService(),
        _alphabetApiService = alphabetApiService ?? AlphabetApiService(),
        _vocabularyApiService = vocabularyApiService ?? VocabularyApiService(),
        _learningApiService = learningApiService ?? LearningApiService(),
        _lessonsApiService = lessonsApiService ?? LessonsApiService(),
        _quizApiService = quizApiService ?? QuizApiService(),
        _noEnaApiService = noEnaApiService ?? NoEnaApiService(),
        _memoryCache = memoryCache ?? MemoryContentCache.instance;


  Future<List<CharacterModel>> loadCharacters({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final memory = _memoryCache.get<List<CharacterModel>>(
        CacheKeys.memoryCharacters,
        maxAge: const Duration(minutes: 10),
      );

      if (memory != null && memory.isNotEmpty) {
        AppLogger.debug('MEMORY HIT characters: ${memory.length}');
        return memory;
      }
    }

    final online = await _backendStatusService.isBackendReachable();

    AppLogger.debug('CACHED LOAD characters: backendOnline=$online');

    if (online) {
      try {
        final items = await _alphabetApiService.fetchCharacters();

        AppLogger.debug('CACHED LOAD characters: API=${items.length}');

        if (items.isNotEmpty) {
          await _cacheService.saveList(
            key: CacheKeys.characters,
            items: items.map((item) => item.toJson()).toList(),
          );

          _memoryCache.set(CacheKeys.memoryCharacters, items);

          return items;
        }
      } catch (error, stackTrace) {
        AppLogger.error(
          'CACHED LOAD characters API failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    final cached = await _cacheService.readList(key: CacheKeys.characters);

    AppLogger.debug('CACHED LOAD characters: cache=${cached.length}');

    if (cached.isNotEmpty) {
      final items = cached.map(CharacterModel.fromJson).toList();
      _memoryCache.set(CacheKeys.memoryCharacters, items);
      return items;
    }

    final offline = await _offlineContentService.loadCharacters();

    AppLogger.debug('CACHED LOAD characters: pack=${offline.length}');

    _memoryCache.set(CacheKeys.memoryCharacters, offline);

    return offline;
  }

  Future<List<WordModel>> loadWords({
    String? search,
    bool forceRefresh = false,
  }) async {
    final query = search?.trim().toLowerCase() ?? '';

    if (!forceRefresh && query.isEmpty) {
      final memory = _memoryCache.get<List<WordModel>>(
        CacheKeys.memoryWords,
        maxAge: const Duration(minutes: 10),
      );

      if (memory != null && memory.isNotEmpty) {
        AppLogger.debug('MEMORY HIT words: ${memory.length}');
        return memory;
      }
    }

    final online = await _backendStatusService.isBackendReachable();

    if (online) {
      try {
        final items = await _vocabularyApiService.fetchWords(
          search: query.isEmpty ? null : query,
        );

        if (items.isNotEmpty) {
          if (query.isEmpty) {
            await _cacheService.saveList(
              key: CacheKeys.words,
              items: items.map((item) => item.toJson()).toList(),
            );

            _memoryCache.set(CacheKeys.memoryWords, items);
          }

          return items;
        }
      } catch (error, stackTrace) {
        AppLogger.error(
          'CACHED LOAD words API failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    final cached = await _cacheService.readList(key: CacheKeys.words);

    final source = cached.isNotEmpty
        ? cached.map(WordModel.fromJson).toList()
        : await _offlineContentService.loadWords();

    if (query.isEmpty) {
      _memoryCache.set(CacheKeys.memoryWords, source);
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

  Future<List<LearningThemeModel>> loadThemes({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final memory = _memoryCache.get<List<LearningThemeModel>>(
        CacheKeys.memoryThemes,
        maxAge: const Duration(minutes: 10),
      );

      if (memory != null && memory.isNotEmpty) {
        AppLogger.debug('MEMORY HIT themes: ${memory.length}');
        return memory;
      }
    }

    final online = await _backendStatusService.isBackendReachable();

    if (online) {
      try {
        final items = await _learningApiService.fetchThemes();

        if (items.isNotEmpty) {
          await _cacheService.saveList(
            key: CacheKeys.themes,
            items: items.map((item) => item.toJson()).toList(),
          );

          _memoryCache.set(CacheKeys.memoryThemes, items);

          return items;
        }
      } catch (error, stackTrace) {
        AppLogger.error(
          'CACHED LOAD themes API failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    final cached = await _cacheService.readList(key: CacheKeys.themes);

    if (cached.isNotEmpty) {
      final items = cached.map(LearningThemeModel.fromJson).toList();
      _memoryCache.set(CacheKeys.memoryThemes, items);
      return items;
    }

    final offline = await _offlineContentService.loadThemes();

    _memoryCache.set(CacheKeys.memoryThemes, offline);

    return offline;
  }

  Future<List<LearningUnitModel>> loadUnits({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final memory = _memoryCache.get<List<LearningUnitModel>>(
        CacheKeys.memoryUnits,
        maxAge: const Duration(minutes: 10),
      );

      if (memory != null && memory.isNotEmpty) {
        AppLogger.debug('MEMORY HIT units: ${memory.length}');
        return memory;
      }
    }

    final online = await _backendStatusService.isBackendReachable();

    if (online) {
      try {
        final items = await _learningApiService.fetchUnits();

        if (items.isNotEmpty) {
          await _cacheService.saveList(
            key: CacheKeys.units,
            items: items.map((item) => item.toJson()).toList(),
          );

          _memoryCache.set(CacheKeys.memoryUnits, items);

          return items;
        }
      } catch (error, stackTrace) {
        AppLogger.error(
          'CACHED LOAD units API failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    final cached = await _cacheService.readList(key: CacheKeys.units);

    if (cached.isNotEmpty) {
      final items = cached.map(LearningUnitModel.fromJson).toList();
      _memoryCache.set(CacheKeys.memoryUnits, items);
      return items;
    }

    final offline = await _offlineContentService.loadUnits();

    _memoryCache.set(CacheKeys.memoryUnits, offline);

    return offline;
  }

  Future<List<LessonModel>> loadLessons({
    String? unitSlug,
    bool forceRefresh = false,
  }) async {
    final memoryKey = '${CacheKeys.memoryLessons}_${unitSlug ?? 'all'}';

    if (!forceRefresh) {
      final memory = _memoryCache.get<List<LessonModel>>(
        memoryKey,
        maxAge: const Duration(minutes: 10),
      );

      if (memory != null && memory.isNotEmpty) {
        AppLogger.debug('MEMORY HIT lessons[$unitSlug]: ${memory.length}');
        return memory;
      }
    }

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

          _memoryCache.set(memoryKey, items);

          return items;
        }
      } catch (error, stackTrace) {
        AppLogger.error(
          'CACHED LOAD lessons API failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    final cached = await _cacheService.readList(key: CacheKeys.lessons);

    final source = cached.isNotEmpty
        ? cached.map(LessonModel.fromJson).toList()
        : await _offlineContentService.loadLessons();

    final filtered = unitSlug == null || unitSlug.isEmpty
        ? source
        : source.where((lesson) => lesson.unitSlug == unitSlug).toList();

    _memoryCache.set(memoryKey, filtered);

    return filtered;
  }

  Future<List<QuizQuestionModel>> loadQuizzes({
    String? unitSlug,
    bool forceRefresh = false,
  }) async {
    final memoryKey = '${CacheKeys.memoryQuizzes}_${unitSlug ?? 'all'}';

    if (!forceRefresh) {
      final memory = _memoryCache.get<List<QuizQuestionModel>>(
        memoryKey,
        maxAge: const Duration(minutes: 10),
      );

      if (memory != null && memory.isNotEmpty) {
        AppLogger.debug('MEMORY HIT quizzes[$unitSlug]: ${memory.length}');
        return memory;
      }
    }

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

          _memoryCache.set(memoryKey, items);

          return items;
        }
      } catch (error, stackTrace) {
        AppLogger.error(
          'CACHED LOAD quizzes API failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    final cached = await _cacheService.readList(key: CacheKeys.quizzes);

    final source = cached.isNotEmpty
        ? cached.map(QuizQuestionModel.fromJson).toList()
        : await _offlineContentService.loadQuizzes();

    final filtered = unitSlug == null || unitSlug.isEmpty
        ? source
        : source.where((quiz) => quiz.unitSlug == unitSlug).toList();

    _memoryCache.set(memoryKey, filtered);

    return filtered;
  }

  Future<List<NoEnaPublicationModel>> loadNoEna({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final memory = _memoryCache.get<List<NoEnaPublicationModel>>(
        CacheKeys.memoryNoEna,
        maxAge: const Duration(minutes: 10),
      );

      if (memory != null && memory.isNotEmpty) {
        AppLogger.debug('MEMORY HIT no_ena: ${memory.length}');
        return memory;
      }
    }

    final online = await _backendStatusService.isBackendReachable();

    if (online) {
      try {
        final items = await _noEnaApiService.fetchPublications();

        if (items.isNotEmpty) {
          await _cacheService.saveList(
            key: CacheKeys.noEna,
            items: items.map((item) => item.toJson()).toList(),
          );

          _memoryCache.set(CacheKeys.memoryNoEna, items);

          return items;
        }
      } catch (error, stackTrace) {
        AppLogger.error(
          'CACHED LOAD no_ena API failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    final cached = await _cacheService.readList(key: CacheKeys.noEna);

    if (cached.isNotEmpty) {
      final items = cached.map(NoEnaPublicationModel.fromJson).toList();
      _memoryCache.set(CacheKeys.memoryNoEna, items);
      return items;
    }

    return [];
  }
}