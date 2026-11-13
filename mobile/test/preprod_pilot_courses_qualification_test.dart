import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/learning/models/learning_unit_model.dart';
import 'package:mobile/features/lessons/models/lesson_model.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mobile/shared/beriya/beriya_keyboard.dart';

void main() {
  group('BK-CONTENT-15 Qualification cours pilotes Alphabet Erfe', () {
    late Map<String, dynamic> preprodPack;
    late List<Map<String, dynamic>> pilotLessons;

    setUpAll(() {
      final fixturePath = File(
        '../backend/learning/fixtures/bk_preprod_pack_fr_beriya.json',
      );
      expect(fixturePath.existsSync(), isTrue);
      preprodPack = jsonDecode(fixturePath.readAsStringSync()) as Map<String, dynamic>;
      final allLessons = (preprodPack['lessons'] as List).cast<Map<String, dynamic>>();
      pilotLessons = allLessons
          .where((l) => l['track'] == 'ALPHABET_ERFE')
          .toList();
    });

    test('Les 5 leçons pilotes ERF-01..ERF-05 couvrent 25 lettres Erfe sans doublon et en brouillon', () {
      expect(pilotLessons.length, 5);
      expect(preprodPack['public_enabled'], isFalse);

      final seenSymbols = <String>{};
      final units = <LearningUnitModel>[];
      final lessons = <LessonModel>[];

      for (int i = 0; i < pilotLessons.length; i++) {
        final raw = pilotLessons[i];
        expect(raw['public_enabled'], isFalse);

        final items = (raw['items'] as List).cast<Map<String, dynamic>>();
        expect(items.length, 5);

        final charsJson = <Map<String, dynamic>>[];
        final lessonItemsJson = <Map<String, dynamic>>[];

        for (int j = 0; j < items.length; j++) {
          final item = items[j];
          final symbol = item['beriya_erfe'] as String;
          expect(seenSymbols.add(symbol), isTrue, reason: 'Doublon Erfe: $symbol');
          expect(item['audio_path'], isNull);
          expect(item['publication_status'], 'BLOQUE');

          final charId = (i * 5) + j + 1;
          charsJson.add({
            'id': charId,
            'symbol': symbol,
            'unicode_code': 'U+${symbol.runes.first.toRadixString(16).toUpperCase()}',
            'name_fr': item['french'],
            'latin_transcription': item['beriya_latin'],
            'arabic_transcription': item['arabic_reference'],
            'character_type': 'unknown',
            'order_index': j + 1,
            'validation_status': 'draft',
            'is_active': true,
            'available_offline': true,
            'audio_url': '',
          });

          lessonItemsJson.add({
            'id': charId,
            'lesson': i + 1,
            'item_type': 'character',
            'character_id': charId,
            'title_fr': item['french'],
            'explanation_fr': '[bk_id:${item['id']}]',
            'order_index': j + 1,
            'is_active': true,
            'available_offline': true,
            'audio_url': '',
          });
        }

        final unit = LearningUnitModel.fromJson({
          'id': i + 1,
          'theme': 1,
          'theme_slug': 'bk-preprod-alphabet-erfe',
          'theme_title_fr': 'Alphabet Erfe (Préproduction)',
          'slug': 'bk-preprod-${(raw['id'] as String).toLowerCase()}',
          'title_fr': raw['title'],
          'description_fr': raw['objective'],
          'level': 'beginner',
          'characters': charsJson,
          'words': const [],
          'character_ids': charsJson.map((c) => c['id']).toList(),
          'word_ids': const [],
          'estimated_minutes': 5,
          'min_score_to_pass': 70,
          'order_index': i + 1,
          'status': 'draft',
          'is_active': true,
          'available_offline': true,
        });
        units.add(unit);

        final lesson = LessonModel.fromJson({
          'id': i + 1,
          'unit': i + 1,
          'unit_slug': unit.slug,
          'unit_title_fr': unit.titleFr,
          'slug': unit.slug,
          'title_fr': raw['title'],
          'description_fr': raw['objective'],
          'level': 'beginner',
          'order_index': i + 1,
          'estimated_minutes': 5,
          'status': 'draft',
          'is_active': true,
          'available_offline': true,
          'items_count': lessonItemsJson.length,
          'items': lessonItemsJson,
        });
        lessons.add(lesson);
      }

      expect(seenSymbols.length, 25);
      expect(units.map((u) => u.orderIndex).toList(), [1, 2, 3, 4, 5]);
      for (final unit in units) {
        expect(unit.status, 'draft');
        expect(unit.characters.length, 5);
        expect(unit.effectiveCoreFlow, isNotEmpty);
      }
      for (final lesson in lessons) {
        expect(lesson.status, 'draft');
        expect(lesson.items.length, 5);
      }
    });

    testWidgets('BeriyaKeyboard restitue et saisit les caractères Erfe de ERF-01', (tester) async {
      final erf01Items = (pilotLessons.first['items'] as List).cast<Map<String, dynamic>>();
      final keys = erf01Items.map((e) => e['beriya_erfe'] as String).toList();
      final typed = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BeriyaKeyboard(
              layout: BeriyaKeyboardLayout.learning,
              scaffoldedKeys: keys,
              onInsert: typed.add,
              onBackspace: () {},
              onSpace: () {},
              onClear: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final kb = tester.widget<BeriyaKeyboard>(find.byType(BeriyaKeyboard));
      for (final k in keys) {
        kb.onInsert(k);
      }
      expect(typed, equals(keys));
    });
  });
}
