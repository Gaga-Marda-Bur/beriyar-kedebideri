class LearningThemeModel {
  final int id;
  final String slug;
  final String titleFr;
  final String titleEn;
  final String titleAr;
  final String descriptionFr;
  final String descriptionEn;
  final String descriptionAr;
  final String level;
  final int orderIndex;
  final String status;
  final bool isActive;
  final bool availableOffline;
  final int unitsCount;
  final List<LearningUnitCompactModel> units;

  const LearningThemeModel({
    required this.id,
    required this.slug,
    required this.titleFr,
    required this.titleEn,
    required this.titleAr,
    required this.descriptionFr,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.level,
    required this.orderIndex,
    required this.status,
    required this.isActive,
    required this.availableOffline,
    required this.unitsCount,
    required this.units,
  });

  factory LearningThemeModel.fromJson(Map<String, dynamic> json) {
    return LearningThemeModel(
      id: _asInt(json['id']),
      slug: _asString(json['slug']),
      titleFr: _asString(json['title_fr']),
      titleEn: _asString(json['title_en']),
      titleAr: _asString(json['title_ar']),
      descriptionFr: _asString(json['description_fr']),
      descriptionEn: _asString(json['description_en']),
      descriptionAr: _asString(json['description_ar']),
      level: _asString(json['level']),
      orderIndex: _asInt(json['order_index']),
      status: _asString(json['status']),
      isActive: _asBool(json['is_active']),
      availableOffline: _asBool(json['available_offline']),
      unitsCount: _asInt(json['units_count']),
      units: _asList(json['units'])
          .map((item) => LearningUnitCompactModel.fromJson(item))
          .toList(),
    );
  }

  static List<Map<String, dynamic>> _asList(dynamic value) {
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
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

class LearningUnitCompactModel {
  final int id;
  final int theme;
  final String slug;
  final String titleFr;
  final String titleEn;
  final String titleAr;
  final String descriptionFr;
  final String descriptionEn;
  final String descriptionAr;
  final String level;
  final int estimatedMinutes;
  final int minScoreToPass;
  final int orderIndex;
  final String status;
  final bool isActive;
  final bool availableOffline;
  final int charactersCount;
  final int wordsCount;

  const LearningUnitCompactModel({
    required this.id,
    required this.theme,
    required this.slug,
    required this.titleFr,
    required this.titleEn,
    required this.titleAr,
    required this.descriptionFr,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.level,
    required this.estimatedMinutes,
    required this.minScoreToPass,
    required this.orderIndex,
    required this.status,
    required this.isActive,
    required this.availableOffline,
    required this.charactersCount,
    required this.wordsCount,
  });

  factory LearningUnitCompactModel.fromJson(Map<String, dynamic> json) {
    return LearningUnitCompactModel(
      id: _asInt(json['id']),
      theme: _asInt(json['theme']),
      slug: _asString(json['slug']),
      titleFr: _asString(json['title_fr']),
      titleEn: _asString(json['title_en']),
      titleAr: _asString(json['title_ar']),
      descriptionFr: _asString(json['description_fr']),
      descriptionEn: _asString(json['description_en']),
      descriptionAr: _asString(json['description_ar']),
      level: _asString(json['level']),
      estimatedMinutes: _asInt(json['estimated_minutes']),
      minScoreToPass: _asInt(json['min_score_to_pass']),
      orderIndex: _asInt(json['order_index']),
      status: _asString(json['status']),
      isActive: _asBool(json['is_active']),
      availableOffline: _asBool(json['available_offline']),
      charactersCount: _asInt(json['characters_count']),
      wordsCount: _asInt(json['words_count']),
    );
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