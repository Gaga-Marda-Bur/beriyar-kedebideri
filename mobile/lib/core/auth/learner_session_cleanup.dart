import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../cache/memory_content_cache.dart';
import '../cache/online_content_cache_service.dart';
import '../storage/app_directories.dart';

/// Clears cached protected content and user-scoped local progress on explicit
/// logout or account switch. Never called on network loss.
class LearnerSessionCleanup {
  static Future<void> clearUserSessionData() async {
    MemoryContentCache.instance.clear();
    await OnlineContentCacheService().clearAll();

    final prefs = await SharedPreferences.getInstance();
    final keysToRemove = prefs
        .getKeys()
        .where(
          (k) =>
              k.startsWith('bk_unit_progress_') ||
              k.startsWith('bk_learning_session_') ||
              k.startsWith('bk_learning_history_') ||
              k.startsWith('bk_srs_v1_'),
        )
        .toList();
    for (final key in keysToRemove) {
      await prefs.remove(key);
    }

    try {
      final packsDir = await AppDirectories.getPacksDirectory();
      if (await packsDir.exists()) {
        await for (final entity in packsDir.list()) {
          if (entity is Directory) {
            await entity.delete(recursive: true);
          } else if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (_) {
      // Ignore filesystem cleanup errors if directory is not initialized (e.g. unit tests)
    }
  }
}
