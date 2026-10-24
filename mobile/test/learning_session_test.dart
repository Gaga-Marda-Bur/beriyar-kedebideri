import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/learning/engine/learning_session.dart';
import 'package:mobile/features/progress/models/unit_progress_local_model.dart';
import 'package:mobile/features/progress/services/unit_progress_local_storage.dart';

List<Map<String, dynamic>> flow() => [
  {
    'step_type': 'discovery',
    'symbol': '𖺡',
    'audio_url': 'https://media.example/b.mp3',
  },
  {'step_type': 'discrimination', 'target_symbol': '𖺡', 'other_symbol': '𖺣'},
  {
    'step_type': 'keyboard_encoding',
    'target_word': '𖺡𖺣',
    'keyboard_keys': ['𖺡', '𖺣'],
  },
  {'step_type': 'celebration'},
];
LearningSession session({int threshold = 70}) => LearningSession(flow(), {
  'recognition': 35,
  'encoding': 30,
  'tracing': 35,
}, threshold);

void answerSession(LearningSession s, {bool firstRecognitionCorrect = true}) {
  s.viewed.add(0);
  s.currentStep = 1;
  s.answer(firstRecognitionCorrect);
  if (!firstRecognitionCorrect) s.answer(true);
  s.currentStep = 2;
  s.answer(true);
  s.currentStep = 3;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('navigation alone awards zero and cannot demonstrate mastery', () {
    final s = session();
    s.viewed.addAll([0, 1, 2]);
    s.currentStep = 1;
    expect(s.canAdvance, isFalse);
    expect(s.score, 0);
    expect(s.canFinish, isFalse);
    expect(s.passed, isFalse);
    expect(s.answeredCount, 0);
  });

  test('scores use first responses and weights of actual assessments', () {
    final s = session();
    answerSession(s, firstRecognitionCorrect: false);
    expect(s.canFinish, isTrue);
    expect(s.score, 46); // 30 / (35 + 30), no imaginary tracing credit.
    expect(s.answeredCount, 2);
    expect(s.correctCount, 1);
    expect(s.passed, isFalse);
    s.currentStep = 1;
    s.answer(
      true,
    ); // Revisiting must not turn an incorrect first answer into a success.
    expect(s.score, 46);
    expect(s.answeredCount, 2);
  });

  test('threshold is applied inclusively without a forced minimum score', () {
    final pass = session(threshold: 46);
    answerSession(pass, firstRecognitionCorrect: false);
    expect(pass.passed, isTrue);
    final fail = session(threshold: 47);
    answerSession(fail, firstRecognitionCorrect: false);
    expect(fail.passed, isFalse);
    final perfect = session(threshold: 100);
    answerSession(perfect);
    expect(perfect.passed, isTrue);
    expect(perfect.score, 100);
  });

  test(
    'checkpoint restores attempts, position and typed text after restart',
    () async {
      final storage = UnitProgressLocalStorage();
      final original = session()
        ..viewed.add(0)
        ..currentStep = 1;
      original.answer(false);
      original.currentStep = 2;
      original.typedText = '𖺡';
      await storage.saveSession('unit', original);
      final restored = session();
      await UnitProgressLocalStorage().restoreSession('unit', restored);
      expect(restored.currentStep, 2);
      expect(restored.typedText, '𖺡');
      expect(restored.answers[1]?['attempts'], 1);
      expect(restored.answers[1]?['first_correct'], isFalse);
      expect(restored.viewed, contains(0));
    },
  );

  test(
    'media relocation preserves checkpoint, changed exercise preserves old checkpoint separately',
    () async {
      final storage = UnitProgressLocalStorage();
      final original = session()..currentStep = 1;
      await storage.saveSession('unit', original);
      final relocatedFlow = flow()..first['audio_url'] = '/local/audio/b.mp3';
      final relocated = LearningSession(
        relocatedFlow,
        original.weights,
        original.threshold,
      );
      expect(relocated.revision, original.revision);
      await storage.restoreSession('unit', relocated);
      expect(relocated.currentStep, 1);
      final changedFlow = flow()..[1]['target_symbol'] = '𖺵';
      final changed = LearningSession(
        changedFlow,
        original.weights,
        original.threshold,
      );
      await storage.restoreSession('unit', changed);
      expect(changed.currentStep, 0);
      expect(changed.revision, isNot(original.revision));
      final oldAgain = session();
      await storage.restoreSession('unit', oldAgain);
      expect(oldAgain.currentStep, 1);
    },
  );

  test(
    'failed new session preserves legacy best, completion date and scoring rule',
    () async {
      final legacy = UnitProgressLocalModel.fromJson({
        'unit_slug': 'unit',
        'completed': true,
        'status': 'completed',
        'best_score_percent': 100,
        'completed_at': '2026-01-01T00:00:00Z',
      });
      final storage = UnitProgressLocalStorage();
      await storage.saveProgress(legacy);
      final s = session();
      answerSession(s, firstRecognitionCorrect: false);
      s.finished = true;
      await storage.saveSession('unit', s);
      final progress = (await storage.getProgress('unit'))!;
      expect(progress.completed, isTrue);
      expect(progress.completedAt, legacy.completedAt);
      expect(progress.bestScorePercent, 100);
      expect(progress.scoringVersion, 1);
      expect(progress.lastSessionScore, 46);
      expect(progress.quizzesAnswered, 2);
      expect(progress.correctAnswers, 1);
      await storage.restartUnit(unitSlug: 'unit', totalSteps: 4);
      expect((await storage.getProgress('unit'))!.completed, isTrue);
    },
  );

  test('failed session needs review, passed session records mastery', () async {
    final storage = UnitProgressLocalStorage();
    final fail = session();
    answerSession(fail, firstRecognitionCorrect: false);
    fail.finished = true;
    await storage.saveSession('fail', fail);
    expect((await storage.getProgress('fail'))!.status, 'review');
    expect((await storage.getProgress('fail'))!.completed, isFalse);
    final pass = session();
    answerSession(pass);
    pass.finished = true;
    await storage.saveSession('pass', pass);
    final progress = (await storage.getProgress('pass'))!;
    expect(progress.status, 'completed');
    expect(progress.scoringVersion, 2);
    expect(progress.completedAt, isNotNull);
  });

  test(
    'corrupt checkpoint is retained and passive review cannot award a score',
    () async {
      final s = session();
      final key = 'bk_learning_session_unit_${s.revision}';
      SharedPreferences.setMockInitialValues({key: '{broken'});
      final storage = UnitProgressLocalStorage();
      await storage.restoreSession('unit', s);
      expect(s.currentStep, 0);
      expect((await SharedPreferences.getInstance()).getString(key), '{broken');
      await storage.finishReview('unit', 6);
      final progress = (await storage.getProgress('unit'))!;
      expect(progress.completed, isFalse);
      expect(progress.bestScorePercent, 0);
      expect(progress.status, 'review');
    },
  );

  test('practice replay archives the preceding session', () async {
    final s = session();
    answerSession(s);
    s.finished = true;
    await UnitProgressLocalStorage().archiveSession('unit', s);
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getKeys().singleWhere(
      (k) => k.startsWith('bk_learning_history_unit_'),
    );
    expect(jsonDecode(prefs.getString(key)!)['finished'], isTrue);
  });

  test(
    'tracing requires both practice repetitions and preserves attempts on resume',
    () {
      final steps = <Map<String, dynamic>>[
        {'step_type': 'tracing', 'symbol': '𖺡'},
      ];
      final s = LearningSession(steps, {'tracing': 100}, 70);
      s.answer(true);
      expect(s.canAdvance, isFalse);
      final restored = LearningSession(steps, {'tracing': 100}, 70)
        ..restore(s.toJson());
      restored.answer(true);
      expect(restored.canAdvance, isTrue);
      expect(restored.answeredCount, 1);
      expect(restored.answers[0]?['attempts'], 2);
    },
  );

  test('unfinished session never relabels a historical best score', () async {
    final storage = UnitProgressLocalStorage();
    await storage.saveProgress(
      UnitProgressLocalModel.fromJson({
        'unit_slug': 'unit',
        'best_score_percent': 80,
      }),
    );
    final s = session();
    answerSession(s);
    await storage.saveSession('unit', s);
    final progress = (await storage.getProgress('unit'))!;
    expect(progress.bestScorePercent, 80);
    expect(progress.scoringVersion, 1);
    expect(progress.completed, isFalse);
  });
}
