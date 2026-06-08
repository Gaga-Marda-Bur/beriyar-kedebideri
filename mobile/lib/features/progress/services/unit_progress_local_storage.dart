import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/unit_progress_local_model.dart';

class UnitProgressLocalStorage {
  static const String _prefix = 'bk_unit_progress_';

  Future<UnitProgressLocalModel?> getProgress(String unitSlug) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$unitSlug');

    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);

    if (decoded is Map<String, dynamic>) {
      return UnitProgressLocalModel.fromJson(decoded);
    }

    return null;
  }

  Future<void> saveProgress(UnitProgressLocalModel progress) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      '$_prefix${progress.unitSlug}',
      jsonEncode(progress.toJson()),
    );
  }

  Future<UnitProgressLocalModel> startOrGet({
    required String unitSlug,
    required int totalSteps,
  }) async {
    final existing = await getProgress(unitSlug);

    if (existing != null) {
      return existing.copyWith(
        totalSteps: totalSteps,
        updatedAt: DateTime.now().toUtc(),
      );
    }

    final progress = UnitProgressLocalModel.started(
      unitSlug: unitSlug,
      totalSteps: totalSteps,
    );

    await saveProgress(progress);
    return progress;
  }

  Future<void> updateStep({
    required String unitSlug,
    required int currentStep,
    required int totalSteps,
    required String lastStage,
  }) async {
    final existing = await getProgress(unitSlug);

    final base = existing ??
        UnitProgressLocalModel.started(
          unitSlug: unitSlug,
          totalSteps: totalSteps,
        );

    final updated = base.copyWith(
      status: base.completed ? 'completed' : 'started',
      currentStep: currentStep,
      totalSteps: totalSteps,
      lastStage: lastStage,
      updatedAt: DateTime.now().toUtc(),
    );

    await saveProgress(updated);
  }

  Future<void> completeUnit({
    required String unitSlug,
    required int totalSteps,
    required int scorePercent,
  }) async {
    final existing = await getProgress(unitSlug);

    final base = existing ??
        UnitProgressLocalModel.started(
          unitSlug: unitSlug,
          totalSteps: totalSteps,
        );

    final now = DateTime.now().toUtc();

    final updated = base.copyWith(
      status: 'completed',
      currentStep: totalSteps - 1,
      totalSteps: totalSteps,
      completed: true,
      bestScorePercent: scorePercent > base.bestScorePercent
          ? scorePercent
          : base.bestScorePercent,
      lastStage: 'result',
      updatedAt: now,
      completedAt: base.completedAt ?? now,
    );

    await saveProgress(updated);
  }

  Future<void> restartUnit({
    required String unitSlug,
    required int totalSteps,
  }) async {
    final existing = await getProgress(unitSlug);

    final now = DateTime.now().toUtc();

    final restarted = UnitProgressLocalModel(
      unitSlug: unitSlug,
      status: 'started',
      currentStep: 0,
      totalSteps: totalSteps,
      bestScorePercent: existing?.bestScorePercent ?? 0,
      completed: false,
      lastStage: 'intro',
      startedAt: now,
      updatedAt: now,
      completedAt: null,
    );

    await saveProgress(restarted);
  }

  Future<List<UnitProgressLocalModel>> getAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final results = <UnitProgressLocalModel>[];

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;

      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;

      final decoded = jsonDecode(raw);

      if (decoded is Map<String, dynamic>) {
        results.add(UnitProgressLocalModel.fromJson(decoded));
      }
    }

    results.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return results;
  }
}