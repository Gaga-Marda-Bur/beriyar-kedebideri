import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/learning/models/learning_unit_model.dart';
import 'package:mobile/features/learning/screens/learning_core_unit_screen.dart';
import 'package:mobile/features/progress/services/unit_progress_local_storage.dart';
import 'package:mobile/shared/beriya/beriya_keyboard.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';

LearningUnitModel unit() => LearningUnitModel.fromJson({
  'id': 11,
  'slug': 'tested',
  'title_fr': 'Test',
  'min_score_to_pass': 90,
  'core_flow': [
    {
      'step_type': 'discrimination',
      'target_symbol': '𖺡',
      'other_symbol': '𖺣',
    },
    {
      'step_type': 'keyboard_encoding',
      'target_word': '𖺡',
      'keyboard_keys': ['𖺡', '𖺣'],
    },
    {'step_type': 'celebration'},
  ],
});

Widget app() => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: LearningCoreUnitScreen(unit: unit()),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'cannot skip answers; failed assessment finishes in review, not mastery',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final next = find.byKey(const ValueKey('learning-next'));
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('answer-0-𖺣')));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('answer-0-𖺡')));
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      tester.widget<BeriyaKeyboard>(find.byType(BeriyaKeyboard)).onInsert('𖺡');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('validate-encoding')));
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      final progress = (await UnitProgressLocalStorage().getProgress(
        'tested',
      ))!;
      expect(progress.status, 'review');
      expect(progress.completed, isFalse);
      expect(progress.quizzesAnswered, 2);
      expect(progress.correctAnswers, 1);
    },
  );

  testWidgets('reopening same unit resumes persisted position and typed text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('answer-0-𖺡')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learning-next')));
    await tester.pumpAndSettle();
    tester.widget<BeriyaKeyboard>(find.byType(BeriyaKeyboard)).onInsert('𖺣');
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(BeriyaKeyboard), findsOneWidget);
    expect(find.text('𖺣'), findsWidgets);
    expect(find.text('Test (2/3)'), findsOneWidget);
    final progress = (await UnitProgressLocalStorage().getProgress('tested'))!;
    expect(progress.currentStep, 1);
    expect(progress.completed, isFalse);
  });

  testWidgets('keyboard validation remains reachable on a compact screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final compact = LearningUnitModel.fromJson({
      'id': 12,
      'slug': 'compact',
      'title_fr': 'Test',
      'core_flow': [
        {
          'step_type': 'keyboard_encoding',
          'target_word': '𖺡',
          'keyboard_keys': ['𖺡', '𖺣'],
        },
        {'step_type': 'celebration'},
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LearningCoreUnitScreen(unit: compact),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('validate-encoding')));
    expect(find.byKey(const ValueKey('validate-encoding')), findsOneWidget);
  });
}
