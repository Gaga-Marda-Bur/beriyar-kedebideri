import 'dart:io';
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
import 'content_source.dart';

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
  final ContentSourceState _sourceState;

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
    ContentSourceState? sourceState,
  }) : _backendStatusService = backendStatusService ?? BackendStatusService(),
       _cacheService = cacheService ?? OnlineContentCacheService(),
       _offlineContentService =
           offlineContentService ?? OfflineContentService(),
       _alphabetApiService = alphabetApiService ?? AlphabetApiService(),
       _vocabularyApiService = vocabularyApiService ?? VocabularyApiService(),
       _learningApiService = learningApiService ?? LearningApiService(),
       _lessonsApiService = lessonsApiService ?? LessonsApiService(),
       _quizApiService = quizApiService ?? QuizApiService(),
       _noEnaApiService = noEnaApiService ?? NoEnaApiService(),
       _memoryCache = memoryCache ?? MemoryContentCache.instance,
       _sourceState = sourceState ?? ContentSourceState.instance;

  Future<List<CharacterModel>> loadCharacters({
    bool forceRefresh = false,
  }) async {
    final online = await _backendStatusService.isBackendReachable();

    if (!forceRefresh) {
      final memory = _memoryCache.get<List<CharacterModel>>(
        CacheKeys.memoryCharacters,
        maxAge: const Duration(minutes: 10),
      );

      if (memory != null && memory.isNotEmpty) {
        final resolved = await _resolveCharactersMedia(memory, isOnline: online);
        _memoryCache.set(CacheKeys.memoryCharacters, resolved);
        _sourceState.setSource(CacheKeys.characters, ContentSourceType.memory);
        AppLogger.debug('MEMORY HIT characters: ${resolved.length}');
        return resolved;
      }
    }

    AppLogger.debug('CACHED LOAD characters: backendOnline=$online');

    if (online) {
      try {
        final items = await _alphabetApiService.fetchCharacters();
        AppLogger.debug('CACHED LOAD characters: API=${items.length}');

        // A16: Une réponse API valide (même vide si le contenu est retiré) est enregistrée.
        await _cacheService.saveList(
          key: CacheKeys.characters,
          items: items.map((item) => item.toJson()).toList(),
        );

        final resolved = await _resolveCharactersMedia(items, isOnline: true);
        _memoryCache.set(CacheKeys.memoryCharacters, resolved);
        _sourceState.setSource(
          CacheKeys.characters,
          resolved.isEmpty ? ContentSourceType.empty : ContentSourceType.online,
        );

        return resolved;
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
      final resolved = await _resolveCharactersMedia(items, isOnline: online);
      _memoryCache.set(CacheKeys.memoryCharacters, resolved);
      _sourceState.setSource(
        CacheKeys.characters,
        ContentSourceType.localCache,
      );
      return resolved;
    }

    final offline = await _offlineContentService.loadCharacters();
    AppLogger.debug('CACHED LOAD characters: pack=${offline.length}');

    final resolved = await _resolveCharactersMedia(offline, isOnline: online);
    _memoryCache.set(CacheKeys.memoryCharacters, resolved);
    _sourceState.setSource(
      CacheKeys.characters,
      resolved.isEmpty ? ContentSourceType.empty : ContentSourceType.offlinePack,
    );

    return resolved;
  }

  Future<List<WordModel>> loadWords({
    String? search,
    bool forceRefresh = false,
  }) async {
    final query = search?.trim().toLowerCase() ?? '';
    final online = await _backendStatusService.isBackendReachable();

    if (!forceRefresh && query.isEmpty) {
      final memory = _memoryCache.get<List<WordModel>>(
        CacheKeys.memoryWords,
        maxAge: const Duration(minutes: 10),
      );

      if (memory != null && memory.isNotEmpty) {
        final resolved = await _resolveWordsMedia(memory, isOnline: online);
        _memoryCache.set(CacheKeys.memoryWords, resolved);
        _sourceState.setSource(CacheKeys.words, ContentSourceType.memory);
        AppLogger.debug('MEMORY HIT words: ${resolved.length}');
        return resolved;
      }
    }

    if (online) {
      try {
        final items = await _vocabularyApiService.fetchWords(
          search: query.isEmpty ? null : query,
        );

        final resolved = await _resolveWordsMedia(items, isOnline: true);

        // A16: Si la recherche est vide, on met à jour le cache de référence.
        // Si une recherche retourne 0 résultat du serveur, on retourne [] sans
        // réinjecter l'ancien cache obsolète.
        if (query.isEmpty) {
          await _cacheService.saveList(
            key: CacheKeys.words,
            items: items.map((item) => item.toJson()).toList(),
          );

          _memoryCache.set(CacheKeys.memoryWords, resolved);
          _sourceState.setSource(
            CacheKeys.words,
            resolved.isEmpty ? ContentSourceType.empty : ContentSourceType.online,
          );
        } else {
          _sourceState.setSource(
            CacheKeys.words,
            resolved.isEmpty ? ContentSourceType.empty : ContentSourceType.online,
          );
        }

        return resolved;
      } catch (error, stackTrace) {
        AppLogger.error(
          'CACHED LOAD words API failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    final cached = await _cacheService.readList(key: CacheKeys.words);

    final rawSource = cached.isNotEmpty
        ? cached.map(WordModel.fromJson).toList()
        : await _offlineContentService.loadWords();

    final source = await _resolveWordsMedia(rawSource, isOnline: online);

    if (query.isEmpty) {
      _memoryCache.set(CacheKeys.memoryWords, source);
      _sourceState.setSource(
        CacheKeys.words,
        source.isEmpty
            ? ContentSourceType.empty
            : cached.isNotEmpty
            ? ContentSourceType.localCache
            : ContentSourceType.offlinePack,
      );
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
        _sourceState.setSource(CacheKeys.themes, ContentSourceType.memory);
        AppLogger.debug('MEMORY HIT themes: ${memory.length}');
        return memory;
      }
    }

    final online = await _backendStatusService.isBackendReachable();

    if (online) {
      try {
        final items = await _learningApiService.fetchThemes();

        await _cacheService.saveList(
          key: CacheKeys.themes,
          items: items.map((item) => item.toJson()).toList(),
        );

        _memoryCache.set(CacheKeys.memoryThemes, items);
        _sourceState.setSource(
          CacheKeys.themes,
          items.isEmpty ? ContentSourceType.empty : ContentSourceType.online,
        );
        return items;
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
      _sourceState.setSource(CacheKeys.themes, ContentSourceType.localCache);
      return items;
    }

    final offline = await _offlineContentService.loadThemes();

    _memoryCache.set(CacheKeys.memoryThemes, offline);
    _sourceState.setSource(
      CacheKeys.themes,
      offline.isEmpty ? ContentSourceType.empty : ContentSourceType.offlinePack,
    );

    return offline;
  }

  Future<List<LearningUnitModel>> loadUnits({bool forceRefresh = false}) async {
    final online = await _backendStatusService.isBackendReachable();

    if (!forceRefresh) {
      final memory = _memoryCache.get<List<LearningUnitModel>>(
        CacheKeys.memoryUnits,
        maxAge: const Duration(minutes: 10),
      );

      if (memory != null && memory.isNotEmpty) {
        final resolved = await _resolveUnitsMedia(memory, isOnline: online);
        _memoryCache.set(CacheKeys.memoryUnits, resolved);
        _sourceState.setSource(CacheKeys.units, ContentSourceType.memory);
        AppLogger.debug('MEMORY HIT units: ${resolved.length}');
        return resolved;
      }
    }

    if (online) {
      try {
        final items = await _learningApiService.fetchUnits();

        await _cacheService.saveList(
          key: CacheKeys.units,
          items: items.map((item) => item.toJson()).toList(),
        );

        final resolved = await _resolveUnitsMedia(items, isOnline: true);
        _memoryCache.set(CacheKeys.memoryUnits, resolved);
        _sourceState.setSource(
          CacheKeys.units,
          resolved.isEmpty ? ContentSourceType.empty : ContentSourceType.online,
        );

        return resolved;
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
      final resolved = await _resolveUnitsMedia(items, isOnline: online);
      _memoryCache.set(CacheKeys.memoryUnits, resolved);
      _sourceState.setSource(CacheKeys.units, ContentSourceType.localCache);
      return resolved;
    }

    final offline = await _offlineContentService.loadUnits();
    final resolved = await _resolveUnitsMedia(offline, isOnline: online);

    _memoryCache.set(CacheKeys.memoryUnits, resolved);
    _sourceState.setSource(
      CacheKeys.units,
      resolved.isEmpty ? ContentSourceType.empty : ContentSourceType.offlinePack,
    );

    return resolved;
  }

  String _lessonStableKey(LessonModel l) {
    if (l.id > 0) return 'id:${l.id}';
    return 'composite:${l.unitSlug}|${l.slug}|${l.orderIndex}|${l.titleFr}';
  }

  Future<List<LessonModel>> loadLessons({
    String? unitSlug,
    bool forceRefresh = false,
  }) async {
    final memoryKey = '${CacheKeys.memoryLessons}_${unitSlug ?? 'all'}';
    final sourceKey = '${CacheKeys.lessons}_${unitSlug ?? 'all'}';
    final online = await _backendStatusService.isBackendReachable();

    if (!forceRefresh) {
      final memory = _memoryCache.get<List<LessonModel>>(
        memoryKey,
        maxAge: const Duration(minutes: 10),
      );

      if (memory != null && memory.isNotEmpty) {
        final resolved = await _resolveLessonsMedia(memory, isOnline: online);
        _memoryCache.set(memoryKey, resolved);
        _sourceState.setSource(sourceKey, ContentSourceType.memory);
        AppLogger.debug('MEMORY HIT lessons[$unitSlug]: ${resolved.length}');
        return resolved;
      }
    }

    if (online) {
      try {
        final items = await _lessonsApiService.fetchLessons(unit: unitSlug);

        final allExisting = await _cacheService.readList(
          key: CacheKeys.lessons,
        );

        final existing = (unitSlug == null || unitSlug.isEmpty)
            ? <LessonModel>[]
            : allExisting
                .map(LessonModel.fromJson)
                .where((lesson) => lesson.unitSlug != unitSlug)
                .toList();

        // Idempotent merge with deduplication by stable identity
        final map = <String, LessonModel>{};
        for (final l in existing) {
          map[_lessonStableKey(l)] = l;
        }
        for (final l in items) {
          map[_lessonStableKey(l)] = l;
        }
        final merged = map.values.toList();

        await _cacheService.saveList(
          key: CacheKeys.lessons,
          items: merged.map((item) => item.toJson()).toList(),
        );

        final deduplicatedItems = <String, LessonModel>{};
        for (final l in items) {
          deduplicatedItems[_lessonStableKey(l)] = l;
        }
        final resolved = await _resolveLessonsMedia(
          deduplicatedItems.values.toList(),
          isOnline: true,
        );
        _memoryCache.set(memoryKey, resolved);
        _sourceState.setSource(
          sourceKey,
          resolved.isEmpty ? ContentSourceType.empty : ContentSourceType.online,
        );

        return resolved;
      } catch (error, stackTrace) {
        AppLogger.error(
          'CACHED LOAD lessons API failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    final cached = await _cacheService.readList(key: CacheKeys.lessons);
    _sourceState.setSource(sourceKey, ContentSourceType.localCache);

    // Deduplicate cached lessons by stable key and heal local storage if duplicates exist
    final cachedMap = <String, LessonModel>{};
    for (final raw in cached) {
      final lesson = LessonModel.fromJson(raw);
      cachedMap[_lessonStableKey(lesson)] = lesson;
    }
    if (cached.isNotEmpty && cached.length != cachedMap.length) {
      await _cacheService.saveList(
        key: CacheKeys.lessons,
        items: cachedMap.values.map((item) => item.toJson()).toList(),
      );
    }

    final source = cachedMap.isNotEmpty
        ? cachedMap.values.toList()
        : await _offlineContentService.loadLessons();

    final filtered = unitSlug == null || unitSlug.isEmpty
        ? source
        : source.where((lesson) => lesson.unitSlug == unitSlug).toList();

    final resolved = await _resolveLessonsMedia(filtered, isOnline: online);
    _memoryCache.set(memoryKey, resolved);
    _sourceState.setSource(
      sourceKey,
      resolved.isEmpty
          ? ContentSourceType.empty
          : cachedMap.isNotEmpty
          ? ContentSourceType.localCache
          : ContentSourceType.offlinePack,
    );
    return resolved;
  }

  Future<List<QuizQuestionModel>> loadQuizzes({
    String? unitSlug,
    bool forceRefresh = false,
  }) async {
    final memoryKey = '${CacheKeys.memoryQuizzes}_${unitSlug ?? 'all'}';
    final sourceKey = '${CacheKeys.quizzes}_${unitSlug ?? 'all'}';
    final online = await _backendStatusService.isBackendReachable();

    if (!forceRefresh) {
      final memory = _memoryCache.get<List<QuizQuestionModel>>(
        memoryKey,
        maxAge: const Duration(minutes: 10),
      );

      if (memory != null && memory.isNotEmpty) {
        final resolved = await _resolveQuizzesMedia(memory, isOnline: online);
        _memoryCache.set(memoryKey, resolved);
        _sourceState.setSource(sourceKey, ContentSourceType.memory);
        AppLogger.debug('MEMORY HIT quizzes[$unitSlug]: ${resolved.length}');
        return resolved;
      }
    }

    if (online) {
      try {
        final items = await _quizApiService.fetchQuizzes(unit: unitSlug);

        final allExisting = await _cacheService.readList(
          key: CacheKeys.quizzes,
        );

        final existing = (unitSlug == null || unitSlug.isEmpty)
            ? <QuizQuestionModel>[]
            : allExisting
                .map(QuizQuestionModel.fromJson)
                .where((quiz) => quiz.unitSlug != unitSlug)
                .toList();

        // Idempotent merge with deduplication by stable identity (P3-02)
        final map = <String, QuizQuestionModel>{};
        for (final q in existing) {
          map[q.stableKey] = q;
        }
        for (final q in items) {
          map[q.stableKey] = q;
        }
        final merged = map.values.toList();

        await _cacheService.saveList(
          key: CacheKeys.quizzes,
          items: merged.map((item) => item.toJson()).toList(),
        );

        final deduplicatedItems = <String, QuizQuestionModel>{};
        for (final q in items) {
          deduplicatedItems[q.stableKey] = q;
        }
        final resolved = await _resolveQuizzesMedia(
          deduplicatedItems.values.toList(),
          isOnline: true,
        );
        _memoryCache.set(memoryKey, resolved);
        _sourceState.setSource(
          sourceKey,
          resolved.isEmpty ? ContentSourceType.empty : ContentSourceType.online,
        );
        return resolved;
      } catch (error, stackTrace) {
        AppLogger.error(
          'CACHED LOAD quizzes API failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    final cached = await _cacheService.readList(key: CacheKeys.quizzes);
    _sourceState.setSource(sourceKey, ContentSourceType.localCache);

    // Deduplicate cached quizzes by stable key and heal local storage if duplicates exist
    final cachedMap = <String, QuizQuestionModel>{};
    for (final raw in cached) {
      final quiz = QuizQuestionModel.fromJson(raw);
      cachedMap[quiz.stableKey] = quiz;
    }
    if (cached.isNotEmpty && cached.length != cachedMap.length) {
      await _cacheService.saveList(
        key: CacheKeys.quizzes,
        items: cachedMap.values.map((item) => item.toJson()).toList(),
      );
    }

    final source = cachedMap.isNotEmpty
        ? cachedMap.values.toList()
        : await _offlineContentService.loadQuizzes();

    final filtered = unitSlug == null || unitSlug.isEmpty
        ? source
        : source.where((quiz) => quiz.unitSlug == unitSlug).toList();

    final resolved = await _resolveQuizzesMedia(filtered, isOnline: online);
    _memoryCache.set(memoryKey, resolved);
    _sourceState.setSource(
      sourceKey,
      resolved.isEmpty
          ? ContentSourceType.empty
          : cachedMap.isNotEmpty
          ? ContentSourceType.localCache
          : ContentSourceType.offlinePack,
    );

    return resolved;
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
        _sourceState.setSource(CacheKeys.noEna, ContentSourceType.memory);
        AppLogger.debug('MEMORY HIT no_ena: ${memory.length}');
        return memory;
      }
    }

    final online = await _backendStatusService.isBackendReachable();

    if (online) {
      try {
        final items = await _noEnaApiService.fetchPublications();

        await _cacheService.saveList(
          key: CacheKeys.noEna,
          items: items.map((item) => item.toJson()).toList(),
        );

        _memoryCache.set(CacheKeys.memoryNoEna, items);
        _sourceState.setSource(
          CacheKeys.noEna,
          items.isEmpty ? ContentSourceType.empty : ContentSourceType.online,
        );

        return items;
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
      _sourceState.setSource(CacheKeys.noEna, ContentSourceType.localCache);
      return items;
    }
    _sourceState.setSource(CacheKeys.noEna, ContentSourceType.empty);
    return [];
  }

  bool _isValidLocalFile(String? path) {
    if (path == null || path.trim().isEmpty) return false;
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return false;
    }
    try {
      final file = File(trimmed);
      return file.existsSync() && file.lengthSync() > 0;
    } catch (_) {
      return false;
    }
  }

  String? _resolveAudioUri({
    String? localCandidate,
    String? currentUri,
    required bool isOnline,
  }) {
    // 1. Valid local file candidate from installed pack always takes priority
    if (_isValidLocalFile(localCandidate)) {
      return localCandidate!.trim();
    }

    // 2. Check currentUri
    if (currentUri != null && currentUri.trim().isNotEmpty) {
      final trimmed = currentUri.trim();
      final isRemote =
          trimmed.startsWith('http://') || trimmed.startsWith('https://');
      if (!isRemote) {
        if (_isValidLocalFile(trimmed)) {
          return trimmed;
        }
        // Obsolete / missing / 0-byte local path -> reject
        return null;
      } else {
        // Remote HTTP URL -> keep only when online and no local file exists
        return isOnline ? trimmed : null;
      }
    }

    return null;
  }

  String? _resolveMediaUri({
    String? localCandidate,
    String? currentUri,
    required bool isOnline,
  }) {
    if (_isValidLocalFile(localCandidate)) {
      return localCandidate!.trim();
    }
    if (currentUri != null && currentUri.trim().isNotEmpty) {
      final trimmed = currentUri.trim();
      final isRemote =
          trimmed.startsWith('http://') || trimmed.startsWith('https://');
      if (!isRemote) {
        if (_isValidLocalFile(trimmed)) {
          return trimmed;
        }
        return null;
      } else {
        return isOnline ? trimmed : null;
      }
    }
    return null;
  }

  Future<List<LearningUnitModel>> _resolveUnitsMedia(
    List<LearningUnitModel> units, {
    required bool isOnline,
  }) async {
    if (units.isEmpty) return units;

    List<LearningUnitModel> offlineUnits = [];
    List<CharacterModel> offlineChars = [];
    List<WordModel> offlineWords = [];
    try {
      offlineUnits = await _offlineContentService.loadUnits();
    } catch (e) {
      AppLogger.warning('Could not load offline units for media resolution: $e');
    }
    try {
      offlineChars = await _offlineContentService.loadCharacters();
    } catch (_) {}
    try {
      offlineWords = await _offlineContentService.loadWords();
    } catch (_) {}

    final offlineBySlug = <String, LearningUnitModel>{};
    final offlineById = <int, LearningUnitModel>{};
    for (final off in offlineUnits) {
      if (off.slug.isNotEmpty) offlineBySlug[off.slug] = off;
      if (off.id > 0) offlineById[off.id] = off;
    }

    final charAudioBySymbol = <String, String>{};
    for (final c in offlineChars) {
      if (c.symbol.isNotEmpty && _isValidLocalFile(c.audioUrl)) {
        charAudioBySymbol[c.symbol] = c.audioUrl!;
      }
    }

    final wordAudioByText = <String, String>{};
    for (final w in offlineWords) {
      if (w.beriyaText.isNotEmpty && _isValidLocalFile(w.audioUrl)) {
        wordAudioByText[w.beriyaText] = w.audioUrl!;
      }
    }

    return units.map((unit) {
      final matchingOffline = offlineBySlug[unit.slug] ?? offlineById[unit.id];
      final flowToProcess = unit.effectiveCoreFlow;
      final resolvedFlow = <Map<String, dynamic>>[];

      for (int i = 0; i < flowToProcess.length; i++) {
        final step = Map<String, dynamic>.from(flowToProcess[i]);
        Map<String, dynamic>? offlineStep;

        if (matchingOffline != null) {
          final offFlow = matchingOffline.effectiveCoreFlow;
          if (i < offFlow.length &&
              offFlow[i]['step_type'] == step['step_type']) {
            offlineStep = offFlow[i];
          } else {
            offlineStep = offFlow.cast<Map<String, dynamic>?>().firstWhere(
              (s) =>
                  s != null &&
                  s['step_type'] == step['step_type'] &&
                  ((s['symbol'] != null && s['symbol'] == step['symbol']) ||
                      (s['target_symbol'] != null &&
                          s['target_symbol'] == step['target_symbol']) ||
                      (s['word'] != null && s['word'] == step['word']) ||
                      (s['target_word'] != null &&
                          s['target_word'] == step['target_word'])),
              orElse: () => null,
            );
          }
        }

        final stepSymbol =
            (step['symbol'] ?? step['target_symbol'])?.toString() ?? '';
        final stepWord =
            (step['word'] ?? step['target_word'])?.toString() ?? '';
        final fallbackPackAudio = charAudioBySymbol[stepSymbol] ??
            wordAudioByText[stepWord];

        for (final audioKey in [
          'audio_url',
          'letter_name_audio_url',
          'slow_audio_url',
          'audio'
        ]) {
          final current = step[audioKey]?.toString();
          final local = offlineStep?[audioKey]?.toString() ??
              (audioKey == 'audio_url' && current != null && current.isNotEmpty
                  ? fallbackPackAudio
                  : null);
          step[audioKey] = _resolveAudioUri(
            localCandidate: local,
            currentUri: current,
            isOnline: isOnline,
          );
        }

        for (final imgKey in ['image_url', 'image', 'thumbnail_url']) {
          final current = step[imgKey]?.toString();
          final local = offlineStep?[imgKey]?.toString();
          step[imgKey] = _resolveMediaUri(
            localCandidate: local,
            currentUri: current,
            isOnline: isOnline,
          );
        }

        resolvedFlow.add(step);
      }

      final resolvedChars = unit.characters.map((c) {
        final offC = matchingOffline?.characters.cast<CharacterModel?>().firstWhere(
          (oc) => oc != null && (oc.id == c.id || oc.symbol == c.symbol),
          orElse: () => null,
        );
        return c.copyWith(
          audioUrl: _resolveAudioUri(
            localCandidate: offC?.audioUrl ?? charAudioBySymbol[c.symbol],
            currentUri: c.audioUrl,
            isOnline: isOnline,
          ),
          slowAudioUrl: _resolveAudioUri(
            localCandidate: offC?.slowAudioUrl,
            currentUri: c.slowAudioUrl,
            isOnline: isOnline,
          ),
        );
      }).toList();

      final resolvedWords = unit.words.map((w) {
        final offW = matchingOffline?.words.cast<WordModel?>().firstWhere(
          (ow) => ow != null && (ow.id == w.id || ow.beriyaText == w.beriyaText),
          orElse: () => null,
        );
        return w.copyWith(
          audioUrl: _resolveAudioUri(
            localCandidate: offW?.audioUrl ?? wordAudioByText[w.beriyaText],
            currentUri: w.audioUrl,
            isOnline: isOnline,
          ),
          slowAudioUrl: _resolveAudioUri(
            localCandidate: offW?.slowAudioUrl,
            currentUri: w.slowAudioUrl,
            isOnline: isOnline,
          ),
        );
      }).toList();

      WordModel? resolvedTarget = unit.targetWord;
      if (resolvedTarget != null) {
        final offTarget = matchingOffline?.targetWord;
        resolvedTarget = resolvedTarget.copyWith(
          audioUrl: _resolveAudioUri(
            localCandidate:
                offTarget?.audioUrl ?? wordAudioByText[resolvedTarget.beriyaText],
            currentUri: resolvedTarget.audioUrl,
            isOnline: isOnline,
          ),
          slowAudioUrl: _resolveAudioUri(
            localCandidate: offTarget?.slowAudioUrl,
            currentUri: resolvedTarget.slowAudioUrl,
            isOnline: isOnline,
          ),
        );
      }

      return unit.copyWith(
        coreFlow: resolvedFlow,
        characters: resolvedChars,
        words: resolvedWords,
        targetWord: resolvedTarget,
      );
    }).toList();
  }

  Future<List<QuizQuestionModel>> _resolveQuizzesMedia(
    List<QuizQuestionModel> quizzes, {
    required bool isOnline,
  }) async {
    if (quizzes.isEmpty) return quizzes;

    List<QuizQuestionModel> offlineQuizzes = [];
    try {
      offlineQuizzes = await _offlineContentService.loadQuizzes();
    } catch (e) {
      AppLogger.warning('Could not load offline quizzes for media resolution: $e');
    }

    final offlineByKey = <String, QuizQuestionModel>{};
    for (final off in offlineQuizzes) {
      offlineByKey[off.stableKey] = off;
    }

    return quizzes.map((q) {
      final off = offlineByKey[q.stableKey];
      return q.copyWith(
        questionAudioUrl: _resolveAudioUri(
          localCandidate: off?.questionAudioUrl,
          currentUri: q.questionAudioUrl,
          isOnline: isOnline,
        ),
        questionSlowAudioUrl: _resolveAudioUri(
          localCandidate: off?.questionSlowAudioUrl,
          currentUri: q.questionSlowAudioUrl,
          isOnline: isOnline,
        ),
        explanationAudioUrl: _resolveAudioUri(
          localCandidate: off?.explanationAudioUrl,
          currentUri: q.explanationAudioUrl,
          isOnline: isOnline,
        ),
      );
    }).toList();
  }

  Future<List<LessonModel>> _resolveLessonsMedia(
    List<LessonModel> lessons, {
    required bool isOnline,
  }) async {
    if (lessons.isEmpty) return lessons;

    List<LessonModel> offlineLessons = [];
    try {
      offlineLessons = await _offlineContentService.loadLessons();
    } catch (e) {
      AppLogger.warning('Could not load offline lessons for media resolution: $e');
    }

    final offlineByKey = <String, LessonModel>{};
    for (final off in offlineLessons) {
      offlineByKey[_lessonStableKey(off)] = off;
    }

    return lessons.map((lesson) {
      final offLesson = offlineByKey[_lessonStableKey(lesson)];
      final offItemsById = <int, LessonItemModel>{};
      if (offLesson != null) {
        for (final item in offLesson.items) {
          if (item.id > 0) offItemsById[item.id] = item;
        }
      }

      final resolvedItems = lesson.items.map((item) {
        final offItem = offItemsById[item.id];
        return item.copyWith(
          audioUrl: _resolveAudioUri(
            localCandidate: offItem?.audioUrl,
            currentUri: item.audioUrl,
            isOnline: isOnline,
          ),
          slowAudioUrl: _resolveAudioUri(
            localCandidate: offItem?.slowAudioUrl,
            currentUri: item.slowAudioUrl,
            isOnline: isOnline,
          ),
          promptAudioUrl: _resolveAudioUri(
            localCandidate: offItem?.promptAudioUrl,
            currentUri: item.promptAudioUrl,
            isOnline: isOnline,
          ),
          explanationAudioUrl: _resolveAudioUri(
            localCandidate: offItem?.explanationAudioUrl,
            currentUri: item.explanationAudioUrl,
            isOnline: isOnline,
          ),
        );
      }).toList();

      return lesson.copyWith(
        items: resolvedItems,
      );
    }).toList();
  }

  Future<List<CharacterModel>> _resolveCharactersMedia(
    List<CharacterModel> chars, {
    required bool isOnline,
  }) async {
    if (chars.isEmpty) return chars;
    List<CharacterModel> offlineChars = [];
    try {
      offlineChars = await _offlineContentService.loadCharacters();
    } catch (_) {}
    final offlineById = {for (final oc in offlineChars) oc.id: oc};
    final offlineBySymbol = {
      for (final oc in offlineChars)
        if (oc.symbol.isNotEmpty) oc.symbol: oc,
    };
    return chars.map((c) {
      final off = offlineById[c.id] ?? offlineBySymbol[c.symbol];
      return c.copyWith(
        audioUrl: _resolveAudioUri(
          localCandidate: off?.audioUrl,
          currentUri: c.audioUrl,
          isOnline: isOnline,
        ),
        slowAudioUrl: _resolveAudioUri(
          localCandidate: off?.slowAudioUrl,
          currentUri: c.slowAudioUrl,
          isOnline: isOnline,
        ),
      );
    }).toList();
  }

  Future<List<WordModel>> _resolveWordsMedia(
    List<WordModel> words, {
    required bool isOnline,
  }) async {
    if (words.isEmpty) return words;
    List<WordModel> offlineWords = [];
    try {
      offlineWords = await _offlineContentService.loadWords();
    } catch (_) {}
    final offlineById = {for (final ow in offlineWords) ow.id: ow};
    final offlineByText = {
      for (final ow in offlineWords)
        if (ow.beriyaText.isNotEmpty) ow.beriyaText: ow,
    };
    return words.map((w) {
      final off = offlineById[w.id] ?? offlineByText[w.beriyaText];
      return w.copyWith(
        audioUrl: _resolveAudioUri(
          localCandidate: off?.audioUrl,
          currentUri: w.audioUrl,
          isOnline: isOnline,
        ),
        slowAudioUrl: _resolveAudioUri(
          localCandidate: off?.slowAudioUrl,
          currentUri: w.slowAudioUrl,
          isOnline: isOnline,
        ),
      );
    }).toList();
  }
}
