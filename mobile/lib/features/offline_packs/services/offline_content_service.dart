import '../../alphabet/models/character_model.dart';
import '../../learning/models/learning_theme_model.dart';
import '../../learning/models/learning_unit_model.dart';
import '../../lessons/models/lesson_model.dart';
import '../../quiz/models/quiz_question_model.dart';
import '../../vocabulary/models/word_model.dart';
import 'local_pack_reader_service.dart';
import 'package:flutter/foundation.dart';
import 'offline_media_resolver.dart';

class OfflineContentService {
  final LocalPackReaderService _readerService;

  OfflineContentService({
    LocalPackReaderService? readerService,
  }) : _readerService = readerService ?? LocalPackReaderService();

  /*Future<List<CharacterModel>> loadCharacters() async {
    final packs = await _readerService.listInstalledPacks();
    final map = <int, CharacterModel>{};

    for (final pack in packs) {
      for (final raw in pack.characters) {
        if (raw is Map<String, dynamic>) {
          final item = CharacterModel.fromJson(raw);
          map[item.id] = item;
        }
      }
    }

    final items = map.values.toList();
    items.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return items;
  }*/

  Future<List<CharacterModel>> loadCharacters() async {
  final packs = await _readerService.listInstalledPacks();

  debugPrint('OFFLINE PACKS FOUND: ${packs.length}');

  final map = <int, CharacterModel>{};

  for (final pack in packs) {
    debugPrint('OFFLINE PACK READ: slug=${pack.slug}, path=${pack.localPath}');
    debugPrint('OFFLINE RAW CHARACTERS: ${pack.characters.length}');

    for (final raw in pack.characters) {
      if (raw is Map<String, dynamic>) {
        final normalized = OfflineMediaResolver.resolveFields(
          raw,
          localPackPath: pack.localPath,
          fields: [
            'audio_url',
            'slow_audio_url',
            'image_url',
          ],
        );

        final item = CharacterModel.fromJson(normalized);
        map[item.id] = item;
      }
    }
  }

  final items = map.values.toList();
  items.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  debugPrint('OFFLINE CHARACTERS FOUND: ${items.length}');

  return items;
}

  Future<List<WordModel>> loadWords() async {
    final packs = await _readerService.listInstalledPacks();
    final map = <int, WordModel>{};

    for (final pack in packs) {
      for (final raw in pack.words) {
        if (raw is Map<String, dynamic>) {
          final normalized = OfflineMediaResolver.resolveFields(
            raw,
            localPackPath: pack.localPath,
            fields: [
              'audio_url',
              'image_url',
            ],
          );

          final item = WordModel.fromJson(normalized);
          map[item.id] = item;
        }
      }
    }

    final items = map.values.toList();
    items.sort((a, b) => a.beriyaText.compareTo(b.beriyaText));
    return items;
  }

  Future<List<LearningThemeModel>> loadThemes() async {
    final packs = await _readerService.listInstalledPacks();
    final themesRaw = <Map<String, dynamic>>[];
    final unitsRaw = <Map<String, dynamic>>[];

    for (final pack in packs) {
      for (final raw in pack.themes) {
        if (raw is Map<String, dynamic>) {
          themesRaw.add(
            OfflineMediaResolver.resolveFields(
              Map<String, dynamic>.from(raw),
              localPackPath: pack.localPath,
              fields: [
                'cover_image_url',
                'image_url',
              ],
            ),
          );
        }
      }

      for (final raw in pack.units) {
        if (raw is Map<String, dynamic>) {
          unitsRaw.add(
            OfflineMediaResolver.resolveFields(
              Map<String, dynamic>.from(raw),
              localPackPath: pack.localPath,
              fields: [
                'cover_image_url',
                'image_url',
                'thumbnail_url',
              ],
            ),
          );
        }
      }
    }

    final result = <LearningThemeModel>[];

    for (final theme in themesRaw) {
      final themeId = _asInt(theme['id']);

      final themeUnits = unitsRaw.where((unit) {
        return _asInt(unit['theme']) == themeId ||
            unit['theme_slug']?.toString() == theme['slug']?.toString();
      }).map((unit) {
        return {
          ...unit,
          'characters_count': _asList(unit['character_ids']).length,
          'words_count': _asList(unit['word_ids']).length,
        };
      }).toList();

      theme['units'] = themeUnits;
      theme['units_count'] = themeUnits.length;

      result.add(LearningThemeModel.fromJson(theme));
    }

    result.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return result;
  }

  Future<List<LearningUnitModel>> loadUnits() async {
    final packs = await _readerService.listInstalledPacks();

    final charactersById = <int, Map<String, dynamic>>{};
    final wordsById = <int, Map<String, dynamic>>{};
    final unitsRaw = <Map<String, dynamic>>[];

    for (final pack in packs) {
      for (final raw in pack.characters) {
        if (raw is Map<String, dynamic>) {
          charactersById[_asInt(raw['id'])] = OfflineMediaResolver.resolveFields(
            Map<String, dynamic>.from(raw),
            localPackPath: pack.localPath,
            fields: [
              'audio_url',
              'slow_audio_url',
              'image_url',
            ],
          );
        }
      }

      for (final raw in pack.words) {
        if (raw is Map<String, dynamic>) {
          wordsById[_asInt(raw['id'])] = OfflineMediaResolver.resolveFields(
            Map<String, dynamic>.from(raw),
            localPackPath: pack.localPath,
            fields: [
              'audio_url',
              'slow_audio_url',
              'image_url',
            ],
          );
        }
      }

      for (final raw in pack.units) {
        if (raw is Map<String, dynamic>) {
          unitsRaw.add(
            OfflineMediaResolver.resolveFields(
              Map<String, dynamic>.from(raw),
              localPackPath: pack.localPath,
              fields: [
                'cover_image_url',
                'image_url',
                'thumbnail_url',
              ],
            ),
          );
        }
      }
    }

    final map = <int, LearningUnitModel>{};

    for (final unit in unitsRaw) {
      final characterIds = _asIntList(unit['character_ids']);
      final wordIds = _asIntList(unit['word_ids']);

      unit['characters'] = characterIds
          .where((id) => charactersById.containsKey(id))
          .map((id) => charactersById[id]!)
          .toList();

      unit['words'] = wordIds
          .where((id) => wordsById.containsKey(id))
          .map((id) => wordsById[id]!)
          .toList();

      unit['theme_title_fr'] = unit['theme_title_fr'] ?? '';
      unit['theme_title_en'] = unit['theme_title_en'] ?? '';
      unit['theme_title_ar'] = unit['theme_title_ar'] ?? '';

      final item = LearningUnitModel.fromJson(unit);
      map[item.id] = item;
    }

    final items = map.values.toList();
    items.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return items;
  }

  Future<List<LessonModel>> loadLessons() async {
    final packs = await _readerService.listInstalledPacks();
    final map = <int, LessonModel>{};

    for (final pack in packs) {
      for (final raw in pack.lessons) {
        if (raw is Map<String, dynamic>) {
          final lessonMap = OfflineMediaResolver.resolveFields(
            Map<String, dynamic>.from(raw),
            localPackPath: pack.localPath,
            fields: [
              'intro_audio_url',
              'cover_image_url',
            ],
          );

          final rawItems = raw['items'];
          if (rawItems is List) {
            lessonMap['items'] = rawItems.map((item) {
              if (item is Map<String, dynamic>) {
                return OfflineMediaResolver.resolveFields(
                  Map<String, dynamic>.from(item),
                  localPackPath: pack.localPath,
                  fields: [
                    'audio_url',
                    'slow_audio_url',
                    'image_url',
                  ],
                );
              }
              return item;
            }).toList();
          }

          final item = LessonModel.fromJson(lessonMap);
          map[item.id] = item;
        }
      }
    }

    final items = map.values.toList();
    items.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return items;
  }

  Future<List<QuizQuestionModel>> loadQuizzes() async {
    final packs = await _readerService.listInstalledPacks();
    final map = <int, QuizQuestionModel>{};

    for (final pack in packs) {
      for (final raw in pack.quizzes) {
        if (raw is Map<String, dynamic>) {
          final quizMap = OfflineMediaResolver.resolveFields(
            Map<String, dynamic>.from(raw),
            localPackPath: pack.localPath,
            fields: [
              'question_audio_url',
              'question_slow_audio_url',
              'question_image_url',
              'explanation_audio_url',
            ],
          );

          final rawOptions = raw['options'];
          if (rawOptions is List) {
            quizMap['options'] = rawOptions.map((option) {
              if (option is Map<String, dynamic>) {
                return OfflineMediaResolver.resolveFields(
                  Map<String, dynamic>.from(option),
                  localPackPath: pack.localPath,
                  fields: [
                    'image_url',
                    'audio_url',
                  ],
                );
              }
              return option;
            }).toList();
          }

          final item = QuizQuestionModel.fromJson(quizMap);
          map[item.id] = item;
        }
      }
    }

    final items = map.values.toList();
    items.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return items;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    return [];
  }

  List<int> _asIntList(dynamic value) {
    if (value is List) {
      return value.map(_asInt).where((id) => id > 0).toList();
    }

    return [];
  }
}