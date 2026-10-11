class CharacterModel {
  final int id;
  final String symbol;
  final String unicodeCode;
  final String name;
  final String nameFr;
  final String nameEn;
  final String nameAr;
  final String latinTranscription;
  final String arabicTranscription;
  final String latinGrapheme;
  final String phonemeIpa;
  final String tonePattern;
  final String vowelLength;
  final Map<String, dynamic> strokePathData;
  final Map<String, dynamic> strokeOrderRules;
  final String characterType;
  final int orderIndex;
  final String description;
  final String validationStatus;
  final bool isActive;
  final bool availableOffline;
  final String? audioUrl;
  final String? slowAudioUrl;
  final String? phonemeAudioUrl;
  final String? letterNameAudioUrl;

  const CharacterModel({
    required this.id,
    required this.symbol,
    required this.unicodeCode,
    required this.name,
    required this.nameFr,
    required this.nameEn,
    required this.nameAr,
    required this.latinTranscription,
    required this.arabicTranscription,
    this.latinGrapheme = '',
    this.phonemeIpa = 'À_VALIDER',
    this.tonePattern = 'À_VALIDER',
    this.vowelLength = 'À_VALIDER',
    this.strokePathData = const {},
    this.strokeOrderRules = const {},
    required this.characterType,
    required this.orderIndex,
    required this.description,
    required this.validationStatus,
    required this.isActive,
    required this.availableOffline,
    required this.audioUrl,
    required this.slowAudioUrl,
    this.phonemeAudioUrl,
    this.letterNameAudioUrl,
  });

  String get character => symbol;

  factory CharacterModel.fromJson(Map<String, dynamic> json) {
    return CharacterModel(
      id: _asInt(json['id']),
      symbol: _asString(json['symbol'] ?? json['character']),
      unicodeCode: _asString(json['unicode_code']),
      name: _asString(json['name']),
      nameFr: _asString(json['name_fr']),
      nameEn: _asString(json['name_en']),
      nameAr: _asString(json['name_ar']),
      latinTranscription: _asString(json['latin_transcription']),
      arabicTranscription: _asString(json['arabic_transcription']),
      latinGrapheme: _asString(json['latin_grapheme']),
      phonemeIpa: _asString(json['phoneme_ipa'] ?? 'À_VALIDER'),
      tonePattern: _asString(json['tone_pattern'] ?? 'À_VALIDER'),
      vowelLength: _asString(json['vowel_length'] ?? 'À_VALIDER'),
      strokePathData: json['stroke_path_data'] is Map<String, dynamic>
          ? json['stroke_path_data'] as Map<String, dynamic>
          : {},
      strokeOrderRules: json['stroke_order_rules'] is Map<String, dynamic>
          ? json['stroke_order_rules'] as Map<String, dynamic>
          : {},
      characterType: _asString(json['character_type']),
      orderIndex: _asInt(json['order_index']),
      description: _asString(json['description']),
      validationStatus: _asString(json['validation_status']),
      isActive: _asBool(json['is_active']),
      availableOffline: _asBool(json['available_offline']),
      audioUrl: _asNullableString(json['audio_url']),
      slowAudioUrl: _asNullableString(json['slow_audio_url']),
      phonemeAudioUrl: _asNullableString(json['phoneme_audio_url']),
      letterNameAudioUrl: _asNullableString(json['letter_name_audio_url']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'unicode_code': unicodeCode,
      'name': name,
      'name_fr': nameFr,
      'name_en': nameEn,
      'name_ar': nameAr,
      'latin_transcription': latinTranscription,
      'arabic_transcription': arabicTranscription,
      'latin_grapheme': latinGrapheme,
      'phoneme_ipa': phonemeIpa,
      'tone_pattern': tonePattern,
      'vowel_length': vowelLength,
      'stroke_path_data': strokePathData,
      'stroke_order_rules': strokeOrderRules,
      'character_type': characterType,
      'order_index': orderIndex,
      'description': description,
      'validation_status': validationStatus,
      'is_active': isActive,
      'available_offline': availableOffline,
      'audio_url': audioUrl,
      'slow_audio_url': slowAudioUrl,
      'phoneme_audio_url': phonemeAudioUrl,
      'letter_name_audio_url': letterNameAudioUrl,
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