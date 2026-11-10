import 'package:flutter/foundation.dart';

/// Modèle immuable d'un élément de répétition espacée (SRS — Lot 4B.3).
///
/// L'identifiant stable (`stableId`) est basé sur la séquence Unicode Erfe
/// normalisée en NFC (`char:<symbole>` ou `word:<mot>`) afin de survivre :
/// - aux réimports de packs hors ligne,
/// - aux changements d'ID numériques de base de données,
/// - aux mises à jour de traductions ou de chemins audio.
@immutable
class SrsItemRecord {
  final String stableId;
  final String itemType; // 'character' | 'word'
  final String erfeText;
  final String unitSlug;
  final String phonemeIpa;
  final String latinTranscription;
  final String translationFr;
  final String? audioUrl;
  final DateTime lastReviewedAt;
  final DateTime nextReviewAt;
  final int masteryLevel; // 0..5
  final int successCount;
  final int errorCount;
  final int consecutiveSuccesses;
  final int intervalDays; // 1, 3, 7, 14, 30
  final double easeFactor; // 1.3..2.5

  const SrsItemRecord({
    required this.stableId,
    required this.itemType,
    required this.erfeText,
    required this.unitSlug,
    this.phonemeIpa = '',
    this.latinTranscription = '',
    this.translationFr = '',
    this.audioUrl,
    required this.lastReviewedAt,
    required this.nextReviewAt,
    required this.masteryLevel,
    required this.successCount,
    required this.errorCount,
    required this.consecutiveSuccesses,
    required this.intervalDays,
    this.easeFactor = 2.5,
  });

  /// Normalise une chaîne Erfe / Beřiya pour l'identification et l'évaluation.
  static String normalizeErfe(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Construit un identifiant stable basé sur le type et le texte Unicode Erfe normalisé.
  static String buildStableId({
    required String itemType,
    required String erfeText,
  }) {
    final normalized = normalizeErfe(erfeText);
    final prefix = itemType == 'word' ? 'word' : 'char';
    return '$prefix:$normalized';
  }

  /// Libellé descriptif lisible (traduction française ou transcription).
  String get label =>
      translationFr.isNotEmpty ? translationFr : latinTranscription;

  /// Indique si l'élément est arrivé à échéance de révision à l'instant `now`.
  bool isDueAt(DateTime now) {
    final nowUtc = now.toUtc();
    // Protection contre un décalage d'horloge système (si lastReviewedAt est dans le futur par rapport à now)
    if (nowUtc.isBefore(lastReviewedAt)) {
      return false;
    }
    return !nowUtc.isBefore(nextReviewAt);
  }

  /// Indique si l'élément est considéré comme difficile (erreurs récentes ou faible maîtrise).
  bool get isDifficult =>
      errorCount > 0 && (consecutiveSuccesses == 0 || masteryLevel <= 1);

  SrsItemRecord copyWith({
    String? stableId,
    String? itemType,
    String? erfeText,
    String? unitSlug,
    String? phonemeIpa,
    String? latinTranscription,
    String? translationFr,
    String? audioUrl,
    DateTime? lastReviewedAt,
    DateTime? nextReviewAt,
    int? masteryLevel,
    int? successCount,
    int? errorCount,
    int? consecutiveSuccesses,
    int? intervalDays,
    double? easeFactor,
  }) {
    return SrsItemRecord(
      stableId: stableId ?? this.stableId,
      itemType: itemType ?? this.itemType,
      erfeText: erfeText ?? this.erfeText,
      unitSlug: (unitSlug != null && unitSlug.isNotEmpty) ? unitSlug : this.unitSlug,
      phonemeIpa: (phonemeIpa != null && phonemeIpa.isNotEmpty)
          ? phonemeIpa
          : this.phonemeIpa,
      latinTranscription:
          (latinTranscription != null && latinTranscription.isNotEmpty)
          ? latinTranscription
          : this.latinTranscription,
      translationFr: (translationFr != null && translationFr.isNotEmpty)
          ? translationFr
          : this.translationFr,
      audioUrl: (audioUrl != null && audioUrl.isNotEmpty) ? audioUrl : this.audioUrl,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      successCount: successCount ?? this.successCount,
      errorCount: errorCount ?? this.errorCount,
      consecutiveSuccesses: consecutiveSuccesses ?? this.consecutiveSuccesses,
      intervalDays: intervalDays ?? this.intervalDays,
      easeFactor: easeFactor ?? this.easeFactor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stable_id': stableId,
      'item_type': itemType,
      'erfe_text': erfeText,
      'unit_slug': unitSlug,
      'phoneme_ipa': phonemeIpa,
      'latin_transcription': latinTranscription,
      'translation_fr': translationFr,
      'audio_url': audioUrl,
      'last_reviewed_at': lastReviewedAt.toUtc().toIso8601String(),
      'next_review_at': nextReviewAt.toUtc().toIso8601String(),
      'mastery_level': masteryLevel,
      'success_count': successCount,
      'error_count': errorCount,
      'consecutive_successes': consecutiveSuccesses,
      'interval_days': intervalDays,
      'ease_factor': easeFactor,
    };
  }

  factory SrsItemRecord.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    final itemType = (json['item_type'] as String?) ?? 'character';
    final erfeText = (json['erfe_text'] as String?) ?? '';
    final rawStableId = (json['stable_id'] as String?) ?? '';

    return SrsItemRecord(
      stableId: rawStableId.isNotEmpty
          ? rawStableId
          : buildStableId(itemType: itemType, erfeText: erfeText),
      itemType: itemType,
      erfeText: erfeText,
      unitSlug: (json['unit_slug'] as String?) ?? '',
      phonemeIpa: (json['phoneme_ipa'] as String?) ?? '',
      latinTranscription: (json['latin_transcription'] as String?) ?? '',
      translationFr: (json['translation_fr'] as String?) ?? '',
      audioUrl: json['audio_url'] as String?,
      lastReviewedAt: _parseUtc(json['last_reviewed_at']) ?? now,
      nextReviewAt: _parseUtc(json['next_review_at']) ?? now,
      masteryLevel: _asInt(json['mastery_level']).clamp(0, 5),
      successCount: _asInt(json['success_count']),
      errorCount: _asInt(json['error_count']),
      consecutiveSuccesses: _asInt(json['consecutive_successes']),
      intervalDays: _asInt(json['interval_days'], fallback: 1).clamp(1, 365),
      easeFactor: _asDouble(json['ease_factor'], fallback: 2.5).clamp(1.3, 2.5),
    );
  }

  static DateTime? _parseUtc(dynamic value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString());
    return parsed?.toUtc();
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _asDouble(dynamic value, {double fallback = 2.5}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
