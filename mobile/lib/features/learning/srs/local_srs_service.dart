import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/learning_session.dart';
import '../models/learning_unit_model.dart';
import 'srs_item_model.dart';

/// Service local indépendant de répétition espacée (SRS — Lot 4B.3).
///
/// Principes d'architecture :
/// - Complète `UnitProgressLocalStorage` au niveau granulaire (caractère / mot)
///   sans créer de système concurrent de progression d'unité.
/// - Basé sur un algorithme SM-2 simplifié avec paliers [1, 3, 7, 14, 30] jours.
/// - Fonctionne 100 % hors ligne, survit aux redémarrages et aux réimports de packs.
/// - Isolé par `userScope` (par défaut `'guest'`) avec support de migration vers
///   un compte utilisateur sans perte de données.
class LocalSrsService {
  static const String _storageKeyPrefix = 'bk_srs_v1_';
  static const List<int> baseIntervalsDays = [1, 3, 7, 14, 30];

  final String userScope;
  final DateTime Function() _clock;

  LocalSrsService({
    this.userScope = 'guest',
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  String get _storageKey {
    final sanitized = userScope.trim().isEmpty
        ? 'guest'
        : userScope.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\-.]'), '_');
    return '$_storageKeyPrefix$sanitized';
  }

  /// Charge tous les enregistrements SRS de l'utilisateur courant.
  Future<Map<String, SrsItemRecord>> loadAllMap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final result = <String, SrsItemRecord>{};
      for (final entry in decoded.entries) {
        if (entry.value is Map) {
          final record = SrsItemRecord.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
          if (record.erfeText.trim().isNotEmpty) {
            result[record.stableId] = record;
          }
        }
      }
      return result;
    } catch (_) {
      // Préserve l'application de tout crash si le JSON local a été altéré.
      return {};
    }
  }

  Future<List<SrsItemRecord>> loadAll() async {
    final map = await loadAllMap();
    final list = map.values.toList()
      ..sort((a, b) => a.nextReviewAt.compareTo(b.nextReviewAt));
    return list;
  }

  Future<SrsItemRecord?> getRecord(String stableId) async {
    final map = await loadAllMap();
    return map[stableId];
  }

  Future<void> saveAllMap(Map<String, SrsItemRecord> records) async {
    await _saveAllMap(records);
  }

  Future<void> _saveAllMap(Map<String, SrsItemRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = <String, dynamic>{
      for (final entry in records.entries) entry.key: entry.value.toJson(),
    };
    await prefs.setString(_storageKey, jsonEncode(serialized));
  }

  /// Calcule l'intervalle en jours selon le niveau de maîtrise (1..5) et le facteur de facilité.
  static int computeIntervalDays({
    required int masteryLevel,
    required double easeFactor,
  }) {
    if (masteryLevel <= 0) return 1;
    final index = (masteryLevel - 1).clamp(0, baseIntervalsDays.length - 1);
    final base = baseIntervalsDays[index];
    if (easeFactor < 1.7 && index > 0) {
      // Si l'élément a connu plusieurs erreurs récentes, progression plus prudente.
      return baseIntervalsDays[index - 1];
    }
    return base;
  }

  /// Enregistre le résultat d'un exercice sur un élément Beřiya/Erfe.
  ///
  /// - Si `submittedAnswer` est fourni et vide après normalisation, l'appel est ignoré
  ///   (aucune pénalité ni création d'entrée fantôme).
  /// - Si `audioMissing == true` et `correct == false`, l'apprenant n'est **jamais pénalisé**
  ///   (conformément à l'Étape 3 du Lot 4B.3).
  Future<SrsItemRecord?> recordOutcome({
    required String itemType,
    required String erfeText,
    required String unitSlug,
    required bool correct,
    String? submittedAnswer,
    bool audioMissing = false,
    String phonemeIpa = '',
    String latinTranscription = '',
    String translationFr = '',
    String label = '',
    String? audioUrl,
    DateTime? reviewedAt,
  }) async {
    final resolvedTranslationFr =
        translationFr.isNotEmpty ? translationFr : label;
    final normalizedErfe = SrsItemRecord.normalizeErfe(erfeText);
    if (normalizedErfe.isEmpty) {
      return null;
    }

    // Ne jamais évaluer ni pénaliser une réponse vide soumise par erreur.
    if (submittedAnswer != null &&
        SrsItemRecord.normalizeErfe(submittedAnswer).isEmpty) {
      final map = await loadAllMap();
      final id = SrsItemRecord.buildStableId(
        itemType: itemType,
        erfeText: normalizedErfe,
      );
      return map[id];
    }

    final nowUtc = (reviewedAt ?? _clock()).toUtc();
    final stableId = SrsItemRecord.buildStableId(
      itemType: itemType,
      erfeText: normalizedErfe,
    );

    final map = await loadAllMap();
    final existing = map[stableId];

    // Normalisation d'horloge si l'appareil avait une date dans le futur lors d'une session précédente.
    final baseLastReviewed =
        existing != null && existing.lastReviewedAt.isAfter(nowUtc)
        ? nowUtc
        : (existing?.lastReviewedAt ?? nowUtc);

    // Protection explicite : si l'audio requis est absent et que la réponse est fausse,
    // on ne pénalise ni le niveau de maîtrise, ni le compteur d'erreurs, ni l'intervalle.
    if (audioMissing && !correct) {
      if (existing != null) {
        final preserved = existing.copyWith(
          unitSlug: unitSlug,
          phonemeIpa: phonemeIpa,
          latinTranscription: latinTranscription,
          translationFr: resolvedTranslationFr,
          audioUrl: audioUrl,
          lastReviewedAt: baseLastReviewed,
        );
        map[stableId] = preserved;
        await _saveAllMap(map);
        return preserved;
      } else {
        final neutral = SrsItemRecord(
          stableId: stableId,
          itemType: itemType,
          erfeText: normalizedErfe,
          unitSlug: unitSlug,
          phonemeIpa: phonemeIpa,
          latinTranscription: latinTranscription,
          translationFr: resolvedTranslationFr,
          audioUrl: audioUrl,
          lastReviewedAt: nowUtc,
          nextReviewAt: nowUtc.add(const Duration(days: 1)),
          masteryLevel: 0,
          successCount: 0,
          errorCount: 0,
          consecutiveSuccesses: 0,
          intervalDays: 1,
          easeFactor: 2.5,
        );
        map[stableId] = neutral;
        await _saveAllMap(map);
        return neutral;
      }
    }

    if (correct) {
      final prevMastery = existing?.masteryLevel ?? 0;
      final prevSuccesses = existing?.successCount ?? 0;
      final prevErrors = existing?.errorCount ?? 0;
      final prevConsecutive = existing?.consecutiveSuccesses ?? 0;
      final prevEase = existing?.easeFactor ?? 2.5;

      final nextMastery = (prevMastery + 1).clamp(1, 5);
      final nextConsecutive = prevConsecutive + 1;
      final nextEase = (prevEase + 0.1).clamp(1.3, 2.5);
      final nextInterval = computeIntervalDays(
        masteryLevel: nextMastery,
        easeFactor: nextEase,
      );

      final updated = SrsItemRecord(
        stableId: stableId,
        itemType: itemType,
        erfeText: normalizedErfe,
        unitSlug: unitSlug.isNotEmpty ? unitSlug : (existing?.unitSlug ?? ''),
        phonemeIpa: phonemeIpa.isNotEmpty
            ? phonemeIpa
            : (existing?.phonemeIpa ?? ''),
        latinTranscription: latinTranscription.isNotEmpty
            ? latinTranscription
            : (existing?.latinTranscription ?? ''),
        translationFr: resolvedTranslationFr.isNotEmpty
            ? resolvedTranslationFr
            : (existing?.translationFr ?? ''),
        audioUrl: (audioUrl != null && audioUrl.isNotEmpty)
            ? audioUrl
            : existing?.audioUrl,
        lastReviewedAt: nowUtc,
        nextReviewAt: nowUtc.add(Duration(days: nextInterval)),
        masteryLevel: nextMastery,
        successCount: prevSuccesses + 1,
        errorCount: prevErrors,
        consecutiveSuccesses: nextConsecutive,
        intervalDays: nextInterval,
        easeFactor: nextEase,
      );

      map[stableId] = updated;
      await _saveAllMap(map);
      return updated;
    } else {
      final prevMastery = existing?.masteryLevel ?? 0;
      final prevSuccesses = existing?.successCount ?? 0;
      final prevErrors = existing?.errorCount ?? 0;
      final prevEase = existing?.easeFactor ?? 2.5;

      final nextMastery = (prevMastery - 1).clamp(0, 5);
      final nextEase = (prevEase - 0.2).clamp(1.3, 2.5);
      const nextInterval = 1;

      final updated = SrsItemRecord(
        stableId: stableId,
        itemType: itemType,
        erfeText: normalizedErfe,
        unitSlug: unitSlug.isNotEmpty ? unitSlug : (existing?.unitSlug ?? ''),
        phonemeIpa: phonemeIpa.isNotEmpty
            ? phonemeIpa
            : (existing?.phonemeIpa ?? ''),
        latinTranscription: latinTranscription.isNotEmpty
            ? latinTranscription
            : (existing?.latinTranscription ?? ''),
        translationFr: resolvedTranslationFr.isNotEmpty
            ? resolvedTranslationFr
            : (existing?.translationFr ?? ''),
        audioUrl: (audioUrl != null && audioUrl.isNotEmpty)
            ? audioUrl
            : existing?.audioUrl,
        lastReviewedAt: nowUtc,
        nextReviewAt: nowUtc.add(const Duration(days: nextInterval)),
        masteryLevel: nextMastery,
        successCount: prevSuccesses,
        errorCount: prevErrors + 1,
        consecutiveSuccesses: 0,
        intervalDays: nextInterval,
        easeFactor: nextEase,
      );

      map[stableId] = updated;
      await _saveAllMap(map);
      return updated;
    }
  }

  /// Enregistre les résultats d'une séance `LearningSession` complète pour une unité.
  Future<List<SrsItemRecord>> recordSessionResults({
    required LearningUnitModel unit,
    required LearningSession session,
    DateTime? reviewedAt,
  }) async {
    final recorded = <SrsItemRecord>[];
    for (var i = 0; i < session.steps.length; i++) {
      final step = session.steps[i];
      if (LearningSession.category(step) == null) continue;
      final ans = session.answers[i];
      if (ans == null) continue;

      final stepType = step['step_type'] as String? ?? '';
      final isWordStep =
          stepType == 'keyboard_encoding' ||
          stepType == 'word_decoding' ||
          stepType == 'fusion';
      final itemType = isWordStep ? 'word' : 'character';
      final erfeText =
          (step['target_symbol'] ??
                  step['target_word'] ??
                  step['symbol'] ??
                  step['word'] ??
                  '')
              .toString();
      if (erfeText.trim().isEmpty) continue;

      final audioUrl = step['audio_url'] as String?;
      final audioMissing = audioUrl == null || audioUrl.trim().isEmpty;
      final firstCorrect = ans['first_correct'] == true;

      final item = await recordOutcome(
        itemType: itemType,
        erfeText: erfeText,
        unitSlug: unit.slug,
        correct: firstCorrect,
        audioMissing: audioMissing,
        phonemeIpa: (step['phoneme_ipa'] as String?) ?? '',
        latinTranscription: (step['latin_transcription'] as String?) ?? '',
        translationFr: (step['french_translation'] as String?) ?? '',
        audioUrl: audioUrl,
        reviewedAt: reviewedAt,
      );
      if (item != null) {
        recorded.add(item);
      }
    }
    return recorded;
  }

  /// Synchronise les métadonnées descriptives (traductions, IPA, URL audio locale)
  /// lors du réimport ou de la mise à jour d'un pack, sans jamais écraser les scores SRS.
  Future<void> reconcileWithUnit(LearningUnitModel unit) async {
    final map = await loadAllMap();
    if (map.isEmpty) return;
    bool changed = false;

    for (final c in unit.characters) {
      final id = SrsItemRecord.buildStableId(
        itemType: 'character',
        erfeText: c.symbol,
      );
      final existing = map[id];
      if (existing != null) {
        map[id] = existing.copyWith(
          unitSlug: unit.slug,
          phonemeIpa: c.phonemeIpa,
          latinTranscription: c.latinTranscription,
          translationFr: c.nameFr.isNotEmpty ? c.nameFr : c.name,
          audioUrl: c.phonemeAudioUrl ?? c.audioUrl,
        );
        changed = true;
      }
    }

    for (final w in unit.words) {
      final id = SrsItemRecord.buildStableId(
        itemType: 'word',
        erfeText: w.beriyaText,
      );
      final existing = map[id];
      if (existing != null) {
        map[id] = existing.copyWith(
          unitSlug: unit.slug,
          latinTranscription: w.latinTranscription,
          translationFr: w.frenchTranslation,
          audioUrl: w.audioUrl,
        );
        changed = true;
      }
    }

    if (changed) {
      await _saveAllMap(map);
    }
  }

  /// Retourne les éléments arrivés à échéance de révision (`isDueAt(now)`)
  /// ou marqués comme difficiles (`includeDifficult == true`).
  ///
  /// Si `allowedStableIds` est fourni (ex. éléments présents dans le pack actif),
  /// les anciens éléments supprimés d'un pack sont filtrés proprement sans erreur.
  Future<List<SrsItemRecord>> getDueItems({
    String? unitSlug,
    DateTime? now,
    bool includeDifficult = false,
    Set<String>? allowedStableIds,
  }) async {
    final checkTime = (now ?? _clock()).toUtc();
    final all = await loadAll();
    return all.where((item) {
      if (unitSlug != null &&
          unitSlug.isNotEmpty &&
          item.unitSlug != unitSlug) {
        return false;
      }
      if (allowedStableIds != null &&
          !allowedStableIds.contains(item.stableId)) {
        return false;
      }
      if (includeDifficult && item.isDifficult) {
        return true;
      }
      return item.isDueAt(checkTime);
    }).toList();
  }

  /// Migre / fusionne les données SRS invitées (`guestScope`) vers un compte identifié
  /// (`accountScope`) sans écraser des révisions plus récentes du compte cible.
  Future<void> migrateGuestToAccount({
    String guestScope = 'guest',
    required String accountScope,
  }) async {
    final trimmed = accountScope.trim();
    if (trimmed.isEmpty || trimmed == guestScope) return;

    final guestService = LocalSrsService(userScope: guestScope, clock: _clock);
    final targetService = LocalSrsService(userScope: trimmed, clock: _clock);

    final guestMap = await guestService.loadAllMap();
    if (guestMap.isEmpty) return;

    final targetMap = await targetService.loadAllMap();
    for (final entry in guestMap.entries) {
      final existing = targetMap[entry.key];
      if (existing == null ||
          entry.value.lastReviewedAt.isAfter(existing.lastReviewedAt)) {
        targetMap[entry.key] = entry.value;
      }
    }

    await targetService._saveAllMap(targetMap);
  }
}
