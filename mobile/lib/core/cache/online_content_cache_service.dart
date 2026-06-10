import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnlineContentCacheService {
  static const String _prefix = 'bk_online_cache_';

  Future<void> saveList({
    required String key,
    required List<Map<String, dynamic>> items,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      '$_prefix$key',
      jsonEncode({
        'cached_at': DateTime.now().toUtc().toIso8601String(),
        'items': items,
      }),
    );
    debugPrint('CACHE SAVE [$key]: ${items.length} items');
  }

  Future<List<Map<String, dynamic>>> readList({
    required String key,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map<String, dynamic>) {
        final items = decoded['items'];
        debugPrint('CACHE READ [$key]: ${items.length} raw items');
        if (items is List) {
          return items
              .whereType<Map<String, dynamic>>()
              .map(Map<String, dynamic>.from)
              .toList();
        }
      }
    } catch (_) {
      debugPrint('CACHE READ [$key]: empty');
      return [];
    }
    debugPrint('CACHE READ [$key]: empty');
    return [];
  }

  Future<DateTime?> cachedAt({
    required String key,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map<String, dynamic>) {
        final value = decoded['cached_at']?.toString() ?? '';
        return DateTime.tryParse(value);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> clearKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();

    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefix)) {
        await prefs.remove(key);
      }
    }
  }
}