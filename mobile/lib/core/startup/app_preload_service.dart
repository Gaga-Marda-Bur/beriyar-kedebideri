import 'package:flutter/foundation.dart';

import '../cache/cached_content_service.dart';
import '../utils/app_logger.dart';

class AppPreloadService {
  static final AppPreloadService instance = AppPreloadService._internal();

  AppPreloadService._internal();

  final CachedContentService _cachedContentService = CachedContentService();

  bool _started = false;
  bool _finished = false;

  bool get started => _started;

  bool get finished => _finished;

  Future<void> startLightPreload() async {
    if (_started) return;

    _started = true;

    AppLogger.debug('PRELOAD start');

    try {
      await Future<void>.delayed(const Duration(milliseconds: 500));

      await _safePreload(
        name: 'characters',
        task: () => _cachedContentService.loadCharacters(),
      );

      await Future<void>.delayed(const Duration(milliseconds: 120));

      await _safePreload(
        name: 'words',
        task: () => _cachedContentService.loadWords(),
      );

      await Future<void>.delayed(const Duration(milliseconds: 120));

      await _safePreload(
        name: 'themes',
        task: () => _cachedContentService.loadThemes(),
      );

      await Future<void>.delayed(const Duration(milliseconds: 120));

      await _safePreload(
        name: 'units',
        task: () => _cachedContentService.loadUnits(),
      );

      await Future<void>.delayed(const Duration(milliseconds: 120));

      await _safePreload(
        name: 'quizzes',
        task: () => _cachedContentService.loadQuizzes(),
      );

      _finished = true;

      AppLogger.debug('PRELOAD finished');
    } catch (error, stackTrace) {
      AppLogger.error(
        'PRELOAD failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _safePreload({
    required String name,
    required Future<List<dynamic>> Function() task,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();

      final items = await task();

      stopwatch.stop();

      AppLogger.debug(
        'PRELOAD $name: ${items.length} items in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (error) {
      AppLogger.debug('PRELOAD $name skipped: ${error.runtimeType}');
    }
  }

  Future<void> resetAndPreloadAgain() async {
    _started = false;
    _finished = false;

    await startLightPreload();
  }
}