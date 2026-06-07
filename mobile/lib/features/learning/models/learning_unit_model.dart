import '../../alphabet/models/character_model.dart';
import '../../vocabulary/models/word_model.dart';

class LearningUnitModel {
  final int id;
  final int theme;
  final String themeSlug;
  final String themeTitleFr;
  final String themeTitleEn;
  final String themeTitleAr;

  final String slug;
  final String titleFr;
  final String titleEn;
  final String titleAr;
  final String descriptionFr;
  final String descriptionEn;
  final String descriptionAr;

  final String level;
  final List<CharacterModel> characters;
  final List<WordModel> words;
  final List<int> characterIds;
  final List<int> wordIds;

  final int estimatedMinutes;
  final int minScoreToPass;
  final int orderIndex;
  final String status;
  final bool isActive;
  final bool availableOffline;

  const LearningUnitModel({
    required this.id,
    required this.theme,
    required this.themeSlug,
    required this.themeTitleFr,
    required this.themeTitleEn,
    required this.themeTitleAr,
    required this.slug,
    required this.titleFr,
    required this.titleEn,
    required this.titleAr,
    required this.descriptionFr,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.level,
    required this.characters,
    required this.words,
    required this.characterIds,
    required this.wordIds,
    required this.estimatedMinutes,
    required this.minScoreToPass,
    required this.orderIndex,
    required this.status,
    required this.isActive,
    required this.availableOffline,
  });

  factory LearningUnitModel.fromJson(Map<String, dynamic> json) {
    return LearningUnitModel(
      id: _asInt(json['id']),
      theme: _asInt(json['theme']),
      themeSlug: _asString(json['theme_slug']),
      themeTitleFr: _asString(json['theme_title_fr']),
      themeTitleEn: _asString(json['theme_title_en']),
      themeTitleAr: _asString(json['theme_title_ar']),
      slug: _asString(json['slug']),
      titleFr: _asString(json['title_fr']),
      titleEn: _asString(json['title_en']),
      titleAr: _asString(json['title_ar']),
      descriptionFr: _asString(json['description_fr']),
      descriptionEn: _asString(json['description_en']),
      descriptionAr: _asString(json['description_ar']),
      level: _asString(json['level']),
      characters: _asMapList(json['characters'])
          .map((item) => CharacterModel.fromJson(item))
          .toList(),
      words: _asMapList(json['words'])
          .map((item) => WordModel.fromJson(item))
          .toList(),
      characterIds: _asIntList(json['character_ids']),
      wordIds: _asIntList(json['word_ids']),
      estimatedMinutes: _asInt(json['estimated_minutes']),
      minScoreToPass: _asInt(json['min_score_to_pass']),
      orderIndex: _asInt(json['order_index']),
      status: _asString(json['status']),
      isActive: _asBool(json['is_active']),
      availableOffline: _asBool(json['available_offline']),
    );
  }

  static List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is List) return value.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  static List<int> _asIntList(dynamic value) {
    if (value is List) {
      return value.map((item) => _asInt(item)).toList();
    }
    return [];
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    return value?.toString() == 'true' || value?.toString() == '1';
  }
}