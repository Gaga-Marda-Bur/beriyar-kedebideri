import '../../alphabet/models/character_model.dart';
import '../../vocabulary/models/word_model.dart';

class LessonModel {
  final int id;
  final int unit;
  final String unitSlug;
  final String unitTitleFr;
  final String unitTitleEn;
  final String unitTitleAr;

  final String slug;
  final String titleFr;
  final String titleEn;
  final String titleAr;

  final String descriptionFr;
  final String descriptionEn;
  final String descriptionAr;

  final String oralIntroFr;
  final String oralIntroEn;
  final String oralIntroAr;

  final String level;
  final int orderIndex;
  final int estimatedMinutes;
  final String status;
  final bool isActive;
  final bool availableOffline;

  final int itemsCount;
  final List<LessonItemModel> items;

  const LessonModel({
    required this.id,
    required this.unit,
    required this.unitSlug,
    required this.unitTitleFr,
    required this.unitTitleEn,
    required this.unitTitleAr,
    required this.slug,
    required this.titleFr,
    required this.titleEn,
    required this.titleAr,
    required this.descriptionFr,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.oralIntroFr,
    required this.oralIntroEn,
    required this.oralIntroAr,
    required this.level,
    required this.orderIndex,
    required this.estimatedMinutes,
    required this.status,
    required this.isActive,
    required this.availableOffline,
    required this.itemsCount,
    required this.items,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    return LessonModel(
      id: _asInt(json['id']),
      unit: _asInt(json['unit']),
      unitSlug: _asString(json['unit_slug']),
      unitTitleFr: _asString(json['unit_title_fr']),
      unitTitleEn: _asString(json['unit_title_en']),
      unitTitleAr: _asString(json['unit_title_ar']),
      slug: _asString(json['slug']),
      titleFr: _asString(json['title_fr']),
      titleEn: _asString(json['title_en']),
      titleAr: _asString(json['title_ar']),
      descriptionFr: _asString(json['description_fr']),
      descriptionEn: _asString(json['description_en']),
      descriptionAr: _asString(json['description_ar']),
      oralIntroFr: _asString(json['oral_intro_fr']),
      oralIntroEn: _asString(json['oral_intro_en']),
      oralIntroAr: _asString(json['oral_intro_ar']),
      level: _asString(json['level']),
      orderIndex: _asInt(json['order_index']),
      estimatedMinutes: _asInt(json['estimated_minutes']),
      status: _asString(json['status']),
      isActive: _asBool(json['is_active']),
      availableOffline: _asBool(json['available_offline']),
      itemsCount: _asInt(json['items_count']),
      items: _asMapList(json['items'])
          .map((item) => LessonItemModel.fromJson(item))
          .toList(),
    );
  }

  static List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is List) return value.whereType<Map<String, dynamic>>().toList();
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

class LessonItemModel {
  final int id;
  final int lesson;
  final String itemType;

  final CharacterModel? character;
  final int? characterId;

  final WordModel? word;
  final int? wordId;

  final String titleFr;
  final String titleEn;
  final String titleAr;

  final String oralPromptFr;
  final String oralPromptEn;
  final String oralPromptAr;

  final String explanationFr;
  final String explanationEn;
  final String explanationAr;

  final String writingHintFr;
  final String writingHintEn;
  final String writingHintAr;

  final int repeatCount;

  final String? imageUrl;
  final String? audioUrl;
  final String? slowAudioUrl;
  final String? promptAudioUrl;
  final String? explanationAudioUrl;

  final int orderIndex;
  final bool isActive;
  final bool availableOffline;

  const LessonItemModel({
    required this.id,
    required this.lesson,
    required this.itemType,
    required this.character,
    required this.characterId,
    required this.word,
    required this.wordId,
    required this.titleFr,
    required this.titleEn,
    required this.titleAr,
    required this.oralPromptFr,
    required this.oralPromptEn,
    required this.oralPromptAr,
    required this.explanationFr,
    required this.explanationEn,
    required this.explanationAr,
    required this.writingHintFr,
    required this.writingHintEn,
    required this.writingHintAr,
    required this.repeatCount,
    required this.imageUrl,
    required this.audioUrl,
    required this.slowAudioUrl,
    required this.promptAudioUrl,
    required this.explanationAudioUrl,
    required this.orderIndex,
    required this.isActive,
    required this.availableOffline,
  });

  factory LessonItemModel.fromJson(Map<String, dynamic> json) {
    final characterJson = json['character'];
    final wordJson = json['word'];

    return LessonItemModel(
      id: _asInt(json['id']),
      lesson: _asInt(json['lesson']),
      itemType: _asString(json['item_type']),
      character: characterJson is Map<String, dynamic>
          ? CharacterModel.fromJson(characterJson)
          : null,
      characterId: json['character_id'] == null ? null : _asInt(json['character_id']),
      word: wordJson is Map<String, dynamic> ? WordModel.fromJson(wordJson) : null,
      wordId: json['word_id'] == null ? null : _asInt(json['word_id']),
      titleFr: _asString(json['title_fr']),
      titleEn: _asString(json['title_en']),
      titleAr: _asString(json['title_ar']),
      oralPromptFr: _asString(json['oral_prompt_fr']),
      oralPromptEn: _asString(json['oral_prompt_en']),
      oralPromptAr: _asString(json['oral_prompt_ar']),
      explanationFr: _asString(json['explanation_fr']),
      explanationEn: _asString(json['explanation_en']),
      explanationAr: _asString(json['explanation_ar']),
      writingHintFr: _asString(json['writing_hint_fr']),
      writingHintEn: _asString(json['writing_hint_en']),
      writingHintAr: _asString(json['writing_hint_ar']),
      repeatCount: _asInt(json['repeat_count']),
      imageUrl: _asNullableString(json['image_url']),
      audioUrl: _asNullableString(json['audio_url']),
      slowAudioUrl: _asNullableString(json['slow_audio_url']),
      promptAudioUrl: _asNullableString(json['prompt_audio_url']),
      explanationAudioUrl: _asNullableString(json['explanation_audio_url']),
      orderIndex: _asInt(json['order_index']),
      isActive: _asBool(json['is_active']),
      availableOffline: _asBool(json['available_offline']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static String? _asNullableString(dynamic value) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? null : text;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    return value?.toString() == 'true' || value?.toString() == '1';
  }
}