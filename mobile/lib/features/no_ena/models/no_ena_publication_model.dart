class NoEnaPublicationModel {
  final int id;
  final String slug;

  final String titleFr;
  final String titleEn;
  final String titleAr;
  final String beriyaTitle;

  final String captionFr;
  final String captionEn;
  final String captionAr;
  final String beriyaCaption;

  final String publicationType;

  final String? imageUrl;
  final String? thumbnailUrl;
  final String? videoUrl;
  final String? audioUrl;

  final int? primaryAudioAsset;

  final int? relatedCharacter;
  final String relatedCharacterSymbol;

  final int? relatedWord;
  final String relatedWordText;

  final int? relatedUnit;
  final String relatedUnitSlug;

  final String contributorName;
  final String cultureTheme;

  final int orderIndex;
  final int viewCount;
  final int favoriteCount;

  final String status;
  final bool isActive;
  final bool isFeatured;
  final bool availableOffline;

  final String publishedAt;

  const NoEnaPublicationModel({
    required this.id,
    required this.slug,
    required this.titleFr,
    required this.titleEn,
    required this.titleAr,
    required this.beriyaTitle,
    required this.captionFr,
    required this.captionEn,
    required this.captionAr,
    required this.beriyaCaption,
    required this.publicationType,
    required this.imageUrl,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.audioUrl,
    required this.primaryAudioAsset,
    required this.relatedCharacter,
    required this.relatedCharacterSymbol,
    required this.relatedWord,
    required this.relatedWordText,
    required this.relatedUnit,
    required this.relatedUnitSlug,
    required this.contributorName,
    required this.cultureTheme,
    required this.orderIndex,
    required this.viewCount,
    required this.favoriteCount,
    required this.status,
    required this.isActive,
    required this.isFeatured,
    required this.availableOffline,
    required this.publishedAt,
  });

  factory NoEnaPublicationModel.fromJson(Map<String, dynamic> json) {
    return NoEnaPublicationModel(
      id: _asInt(json['id']),
      slug: _asString(json['slug']),
      titleFr: _asString(json['title_fr']),
      titleEn: _asString(json['title_en']),
      titleAr: _asString(json['title_ar']),
      beriyaTitle: _asString(json['beriya_title']),
      captionFr: _asString(json['caption_fr']),
      captionEn: _asString(json['caption_en']),
      captionAr: _asString(json['caption_ar']),
      beriyaCaption: _asString(json['beriya_caption']),
      publicationType: _asString(json['publication_type']),
      imageUrl: _asNullableString(json['image_url']),
      thumbnailUrl: _asNullableString(json['thumbnail_url']),
      videoUrl: _asNullableString(json['video_url']),
      audioUrl: _asNullableString(json['audio_url']),
      primaryAudioAsset: json['primary_audio_asset'] == null
          ? null
          : _asInt(json['primary_audio_asset']),
      relatedCharacter: json['related_character'] == null
          ? null
          : _asInt(json['related_character']),
      relatedCharacterSymbol: _asString(json['related_character_symbol']),
      relatedWord: json['related_word'] == null ? null : _asInt(json['related_word']),
      relatedWordText: _asString(json['related_word_text']),
      relatedUnit: json['related_unit'] == null ? null : _asInt(json['related_unit']),
      relatedUnitSlug: _asString(json['related_unit_slug']),
      contributorName: _asString(json['contributor_name']),
      cultureTheme: _asString(json['culture_theme']),
      orderIndex: _asInt(json['order_index']),
      viewCount: _asInt(json['view_count']),
      favoriteCount: _asInt(json['favorite_count']),
      status: _asString(json['status']),
      isActive: _asBool(json['is_active']),
      isFeatured: _asBool(json['is_featured']),
      availableOffline: _asBool(json['available_offline']),
      publishedAt: _asString(json['published_at']),
    );
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;

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