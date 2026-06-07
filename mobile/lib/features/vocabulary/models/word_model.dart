class WordModel {
  final int id;
  final String beriyaText;
  final String latinTranscription;
  final String arabicTranscription;

  final String frenchTranslation;
  final String englishTranslation;
  final String arabicTranslation;

  final String translationFr;
  final String translationEn;
  final String translationAr;

  final int? category;
  final String categorySlug;
  final String categoryFr;
  final String categoryEn;
  final String categoryAr;

  final String difficulty;
  final String level;
  final int difficultyOrder;

  final String? imageUrl;
  final String? audioUrl;
  final String? slowAudioUrl;
  final String? exampleAudioUrl;

  final String oralPrompt;
  final String pronunciationNote;
  final String dialectNote;
  final String exampleSentence;

  final String validationStatus;
  final bool isActive;
  final bool availableOffline;

  const WordModel({
    required this.id,
    required this.beriyaText,
    required this.latinTranscription,
    required this.arabicTranscription,
    required this.frenchTranslation,
    required this.englishTranslation,
    required this.arabicTranslation,
    required this.translationFr,
    required this.translationEn,
    required this.translationAr,
    required this.category,
    required this.categorySlug,
    required this.categoryFr,
    required this.categoryEn,
    required this.categoryAr,
    required this.difficulty,
    required this.level,
    required this.difficultyOrder,
    required this.imageUrl,
    required this.audioUrl,
    required this.slowAudioUrl,
    required this.exampleAudioUrl,
    required this.oralPrompt,
    required this.pronunciationNote,
    required this.dialectNote,
    required this.exampleSentence,
    required this.validationStatus,
    required this.isActive,
    required this.availableOffline,
  });

  factory WordModel.fromJson(Map<String, dynamic> json) {
    return WordModel(
      id: _asInt(json['id']),
      beriyaText: _asString(json['beriya_text']),
      latinTranscription: _asString(json['latin_transcription']),
      arabicTranscription: _asString(json['arabic_transcription']),
      frenchTranslation: _asString(json['french_translation']),
      englishTranslation: _asString(json['english_translation']),
      arabicTranslation: _asString(json['arabic_translation']),
      translationFr: _asString(json['translation_fr'] ?? json['french_translation']),
      translationEn: _asString(json['translation_en'] ?? json['english_translation']),
      translationAr: _asString(json['translation_ar'] ?? json['arabic_translation']),
      category: json['category'] == null ? null : _asInt(json['category']),
      categorySlug: _asString(json['category_slug']),
      categoryFr: _asString(json['category_fr']),
      categoryEn: _asString(json['category_en']),
      categoryAr: _asString(json['category_ar']),
      difficulty: _asString(json['difficulty']),
      level: _asString(json['level'] ?? json['difficulty']),
      difficultyOrder: _asInt(json['difficulty_order']),
      imageUrl: _asNullableString(json['image_url']),
      audioUrl: _asNullableString(json['audio_url']),
      slowAudioUrl: _asNullableString(json['slow_audio_url']),
      exampleAudioUrl: _asNullableString(json['example_audio_url']),
      oralPrompt: _asString(json['oral_prompt']),
      pronunciationNote: _asString(json['pronunciation_note']),
      dialectNote: _asString(json['dialect_note']),
      exampleSentence: _asString(json['example_sentence']),
      validationStatus: _asString(json['validation_status']),
      isActive: _asBool(json['is_active']),
      availableOffline: _asBool(json['available_offline']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'beriya_text': beriyaText,
      'latin_transcription': latinTranscription,
      'arabic_transcription': arabicTranscription,
      'french_translation': frenchTranslation,
      'english_translation': englishTranslation,
      'arabic_translation': arabicTranslation,
      'translation_fr': translationFr,
      'translation_en': translationEn,
      'translation_ar': translationAr,
      'category': category,
      'category_slug': categorySlug,
      'category_fr': categoryFr,
      'category_en': categoryEn,
      'category_ar': categoryAr,
      'difficulty': difficulty,
      'level': level,
      'difficulty_order': difficultyOrder,
      'image_url': imageUrl,
      'audio_url': audioUrl,
      'slow_audio_url': slowAudioUrl,
      'example_audio_url': exampleAudioUrl,
      'oral_prompt': oralPrompt,
      'pronunciation_note': pronunciationNote,
      'dialect_note': dialectNote,
      'example_sentence': exampleSentence,
      'validation_status': validationStatus,
      'is_active': isActive,
      'available_offline': availableOffline,
    };
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _asString(dynamic value) {
    return value?.toString() ?? '';
  }

  static String? _asNullableString(dynamic value) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? null : text;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    return value?.toString() == 'true' || value?.toString() == '1';
  }
}