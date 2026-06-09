class LessonPackModel {
  final int id;
  final String titleFr;
  final String titleEn;
  final String titleAr;
  final String slug;
  final String descriptionFr;
  final String descriptionEn;
  final String descriptionAr;
  final String level;
  final String packType;
  final int version;
  final String fileUrl;
  final bool isDownloadable;
  final Map<String, dynamic> manifest;
  final String checksum;
  final double sizeMb;
  final int itemsCount;
  final String status;
  final bool isActive;
  final bool isFeatured;
  final String generatedAt;

  const LessonPackModel({
    required this.id,
    required this.titleFr,
    required this.titleEn,
    required this.titleAr,
    required this.slug,
    required this.descriptionFr,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.level,
    required this.packType,
    required this.version,
    required this.fileUrl,
    required this.isDownloadable,
    required this.manifest,
    required this.checksum,
    required this.sizeMb,
    required this.itemsCount,
    required this.status,
    required this.isActive,
    required this.isFeatured,
    required this.generatedAt,
  });

  factory LessonPackModel.fromJson(Map<String, dynamic> json) {
    return LessonPackModel(
      id: _asInt(json['id']),
      titleFr: _asString(json['title_fr']),
      titleEn: _asString(json['title_en']),
      titleAr: _asString(json['title_ar']),
      slug: _asString(json['slug']),
      descriptionFr: _asString(json['description_fr']),
      descriptionEn: _asString(json['description_en']),
      descriptionAr: _asString(json['description_ar']),
      level: _asString(json['level']),
      packType: _asString(json['pack_type']),
      version: _asInt(json['version']),
      fileUrl: _asString(json['file_url']),
      isDownloadable: _asBool(json['is_downloadable']),
      manifest: json['manifest'] is Map<String, dynamic>
          ? json['manifest'] as Map<String, dynamic>
          : {},
      checksum: _asString(json['checksum']),
      sizeMb: _asDouble(json['size_mb']),
      itemsCount: _asInt(json['items_count']),
      status: _asString(json['status']),
      isActive: _asBool(json['is_active']),
      isFeatured: _asBool(json['is_featured']),
      generatedAt: _asString(json['generated_at']),
    );
  }

  String titleForLang(String lang) {
    if (lang == 'ar' && titleAr.isNotEmpty) return titleAr;
    if (lang == 'en' && titleEn.isNotEmpty) return titleEn;
    return titleFr.isNotEmpty ? titleFr : titleEn;
  }

  String descriptionForLang(String lang) {
    if (lang == 'ar' && descriptionAr.isNotEmpty) return descriptionAr;
    if (lang == 'en' && descriptionEn.isNotEmpty) return descriptionEn;
    return descriptionFr.isNotEmpty ? descriptionFr : descriptionEn;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    return value?.toString() == 'true' || value?.toString() == '1';
  }
}