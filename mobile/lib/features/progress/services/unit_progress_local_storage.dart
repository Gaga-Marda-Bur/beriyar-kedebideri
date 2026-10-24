import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/unit_progress_local_model.dart';
import '../../learning/engine/learning_session.dart';

class UnitProgressLocalStorage {
  static const String _prefix = 'bk_unit_progress_';

  Future<void> archiveSession(String slug, LearningSession session) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      'bk_learning_history_${slug}_${DateTime.now().microsecondsSinceEpoch}',
      jsonEncode(session.toJson()),
    )) {
      throw StateError('Session history could not be saved');
    }
  }

  Future<void> finishReview(String unitSlug, int totalSteps) async {
    final base =
        await getProgress(unitSlug) ??
        UnitProgressLocalModel.started(
          unitSlug: unitSlug,
          totalSteps: totalSteps,
        );
    await saveProgress(
      base.copyWith(
        status: base.completed ? 'completed' : 'review',
        lastStage: 'result',
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> restoreSession(String slug, LearningSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      'bk_learning_session_${slug}_${session.revision}',
    );
    if (raw == null) return;
    try {
      session.restore(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      // Leave corrupt data untouched so it can be recovered separately.
    }
  }

  Future<void> saveSession(String slug, LearningSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final base =
        await getProgress(slug) ??
        UnitProgressLocalModel.started(
          unitSlug: slug,
          totalSteps: session.steps.length,
        );
    final passed = session.finished && session.passed;
    await saveProgress(
      base.copyWith(
        currentStep: session.currentStep,
        totalSteps: session.steps.length,
        lastStage: session.finished
            ? 'result'
            : session.steps[session.currentStep]['step_type'] as String?,
        status: base.completed || passed
            ? 'completed'
            : session.finished
            ? 'review'
            : 'started',
        completed: base.completed || passed,
        completedAt: passed
            ? base.completedAt ?? DateTime.now().toUtc()
            : base.completedAt,
        // An existing historical best remains tied to its original scoring rule.
        scoringVersion:
            session.finished && session.score > base.bestScorePercent
            ? LearningSession.scoringVersion
            : base.scoringVersion,
        lastSessionScore: session.finished
            ? session.score
            : base.lastSessionScore,
        bestScorePercent:
            session.finished && session.score > base.bestScorePercent
            ? session.score
            : base.bestScorePercent,
        lessonsSeen: base.lessonsSeen,
        charactersSeen: session.countViewed('discovery') > base.charactersSeen
            ? session.countViewed('discovery')
            : base.charactersSeen,
        wordsSeen: session.countViewed('word_decoding') > base.wordsSeen
            ? session.countViewed('word_decoding')
            : base.wordsSeen,
        quizzesAnswered: session.answeredCount > base.quizzesAnswered
            ? session.answeredCount
            : base.quizzesAnswered,
        correctAnswers: session.correctCount > base.correctAnswers
            ? session.correctCount
            : base.correctAnswers,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    final written = await prefs.setString(
      'bk_learning_session_${slug}_${session.revision}',
      jsonEncode(session.toJson()),
    );
    if (!written) throw StateError('Session could not be saved');
  }

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

    final saved = await prefs.setString(
      '$_prefix${progress.unitSlug}',
      jsonEncode(progress.toJson()),
    );
    if (!saved) throw StateError('Progress could not be saved');
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

    final base =
        existing ??
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
    required int minScoreToPass,
  }) async {
    final existing = await getProgress(unitSlug);

    final base =
        existing ??
        UnitProgressLocalModel.started(
          unitSlug: unitSlug,
          totalSteps: totalSteps,
        );

    final now = DateTime.now().toUtc();

    final updated = base.copyWith(
      status: base.completed || scorePercent >= minScoreToPass
          ? 'completed'
          : 'review',
      currentStep: totalSteps - 1,
      totalSteps: totalSteps,
      completed: base.completed || scorePercent >= minScoreToPass,
      bestScorePercent: scorePercent > base.bestScorePercent
          ? scorePercent
          : base.bestScorePercent,
      lastStage: 'result',
      updatedAt: now,
      completedAt:
          base.completedAt ?? (scorePercent >= minScoreToPass ? now : null),
    );

    await saveProgress(updated);
  }

  Future<void> restartUnit({
    required String unitSlug,
    required int totalSteps,
  }) async {
    final existing = await getProgress(unitSlug);

    final now = DateTime.now().toUtc();

    final base =
        existing ??
        UnitProgressLocalModel.started(
          unitSlug: unitSlug,
          totalSteps: totalSteps,
        );
    final restarted = base.copyWith(
      status: base.completed ? 'completed' : 'started',
      currentStep: 0,
      totalSteps: totalSteps,
      bestScorePercent: existing?.bestScorePercent ?? 0,
      lastStage: 'intro',
      updatedAt: now,
    );

    await saveProgress(restarted);
  }

  Future<List<UnitProgressLocalModel>> getAllProgress() async {
    final prefs = await SharedPreferences.getInstance();

    final items = <UnitProgressLocalModel>[];

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;

      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) continue;

      try {
        final decoded = jsonDecode(raw);

        if (decoded is Map<String, dynamic>) {
          items.add(UnitProgressLocalModel.fromJson(decoded));
        }
      } catch (_) {
        // ignore corrupted progress
      }
    }

    items.sort((a, b) {
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return items;
  }
}
