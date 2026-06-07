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
  final String characterType;
  final int orderIndex;
  final String description;
  final String validationStatus;
  final bool isActive;
  final bool availableOffline;
  final String? audioUrl;
  final String? slowAudioUrl;

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
    required this.characterType,
    required this.orderIndex,
    required this.description,
    required this.validationStatus,
    required this.isActive,
    required this.availableOffline,
    required this.audioUrl,
    required this.slowAudioUrl,
  });

  factory CharacterModel.fromJson(Map<String, dynamic> json) {
    return CharacterModel(
      id: _asInt(json['id']),
      symbol: _asString(json['symbol']),
      unicodeCode: _asString(json['unicode_code']),
      name: _asString(json['name']),
      nameFr: _asString(json['name_fr']),
      nameEn: _asString(json['name_en']),
      nameAr: _asString(json['name_ar']),
      latinTranscription: _asString(json['latin_transcription']),
      arabicTranscription: _asString(json['arabic_transcription']),
      characterType: _asString(json['character_type']),
      orderIndex: _asInt(json['order_index']),
      description: _asString(json['description']),
      validationStatus: _asString(json['validation_status']),
      isActive: _asBool(json['is_active']),
      availableOffline: _asBool(json['available_offline']),
      audioUrl: _asNullableString(json['audio_url']),
      slowAudioUrl: _asNullableString(json['slow_audio_url']),
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
      'character_type': characterType,
      'order_index': orderIndex,
      'description': description,
      'validation_status': validationStatus,
      'is_active': isActive,
      'available_offline': availableOffline,
      'audio_url': audioUrl,
      'slow_audio_url': slowAudioUrl,
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