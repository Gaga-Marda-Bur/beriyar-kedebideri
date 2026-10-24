import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/cache/online_content_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const key = 'bk_online_cache_words';
  final items = <Map<String, dynamic>>[
    {
      'id': 7,
      'beriya_text': '𖺡𖺣',
      'arabic_translation': 'بلد',
      'audio_url': '/media/audio/word.mp3',
      'tags': ['validé', 'hors connexion'],
    },
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'saved cache survives service restart with content and date intact',
    () async {
      await OnlineContentCacheService().saveList(key: 'words', items: items);
      final prefs = await SharedPreferences.getInstance();
      final persisted = prefs.getString(key)!;
      final cachedAt = await OnlineContentCacheService().cachedAt(key: 'words');
      expect(cachedAt, isNotNull);

      // Recreate the preference cache from persisted data, without live user data.
      SharedPreferences.setMockInitialValues({
        key: persisted,
        'bk_unit_progress_existing': 'keep-progress',
        'beriya_editor_active_draft': 'keep-draft',
      });
      final restarted = OnlineContentCacheService();
      expect(await restarted.readList(key: 'words'), equals(items));
      expect(await restarted.cachedAt(key: 'words'), equals(cachedAt));

      final reloadedPrefs = await SharedPreferences.getInstance();
      expect(reloadedPrefs.getString(key), persisted);
      expect(
        reloadedPrefs.getString('bk_unit_progress_existing'),
        'keep-progress',
      );
      expect(
        reloadedPrefs.getString('beriya_editor_active_draft'),
        'keep-draft',
      );
    },
  );

  test(
    'legacy raw lists remain readable without rewriting preferences',
    () async {
      final raw = jsonEncode(items);
      SharedPreferences.setMockInitialValues({key: raw});
      final service = OnlineContentCacheService();

      expect(await service.readList(key: 'words'), equals(items));
      expect(await service.cachedAt(key: 'words'), isNull);
      expect((await SharedPreferences.getInstance()).getString(key), raw);
    },
  );

  test('empty saved list remains a valid cache with a timestamp', () async {
    final service = OnlineContentCacheService();
    await service.saveList(key: 'words', items: []);
    expect(await service.readList(key: 'words'), isEmpty);
    expect(await service.cachedAt(key: 'words'), isNotNull);
  });

  test('missing cache returns no content or timestamp', () async {
    final service = OnlineContentCacheService();
    expect(await service.readList(key: 'words'), isEmpty);
    expect(await service.cachedAt(key: 'words'), isNull);
  });

  test('invalid JSON remains stored for recovery and does not throw', () async {
    const raw = '{broken';
    SharedPreferences.setMockInitialValues({key: raw});
    final service = OnlineContentCacheService();
    expect(await service.readList(key: 'words'), isEmpty);
    expect(await service.cachedAt(key: 'words'), isNull);
    expect((await SharedPreferences.getInstance()).getString(key), raw);
  });

  test(
    'unsupported roots and invalid item containers fail safely without deletion',
    () async {
      for (final raw in [
        'null',
        '42',
        '"text"',
        '{}',
        '{"items":null}',
        '{"items":{}}',
      ]) {
        SharedPreferences.setMockInitialValues({key: raw});
        expect(
          await OnlineContentCacheService().readList(key: 'words'),
          isEmpty,
        );
        expect((await SharedPreferences.getInstance()).getString(key), raw);
      }
    },
  );

  test(
    'mixed cached lists retain valid objects in both supported formats',
    () async {
      final mixed = [null, 4, 'invalid', ...items];
      for (final payload in [
        mixed,
        {'items': mixed},
      ]) {
        SharedPreferences.setMockInitialValues({key: jsonEncode(payload)});
        expect(
          await OnlineContentCacheService().readList(key: 'words'),
          equals(items),
        );
      }
    },
  );
}
