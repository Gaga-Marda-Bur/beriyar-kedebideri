import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mobile/features/learning/engine/learning_session.dart';
import 'package:mobile/features/learning/models/learning_unit_model.dart';
import 'package:mobile/features/learning/screens/learning_core_unit_screen.dart';
import 'package:mobile/features/progress/services/unit_progress_local_storage.dart';

const _erfLessons = <String, List<List<String>>>{
  'bk-preprod-erf-01': [
    ['𖺠', 'A', 'U+16EA0', 'vowel'],
    ['𖺡', 'B', 'U+16EA1', 'consonant'],
    ['𖺢', 'D', 'U+16EA2', 'consonant'],
    ['𖺣', 'E', 'U+16EA3', 'vowel'],
    ['𖺤', 'F', 'U+16EA4', 'consonant'],
  ],
  'bk-preprod-erf-02': [
    ['𖺥', 'G', 'U+16EA5', 'consonant'],
    ['𖺦', 'H', 'U+16EA6', 'consonant'],
    ['𖺧', 'I', 'U+16EA7', 'vowel'],
    ['𖺨', 'J', 'U+16EA8', 'consonant'],
    ['𖺩', 'K', 'U+16EA9', 'consonant'],
  ],
  'bk-preprod-erf-03': [
    ['𖺪', 'L', 'U+16EAA', 'consonant'],
    ['𖺫', 'M', 'U+16EAB', 'consonant'],
    ['𖺬', 'N', 'U+16EAC', 'consonant'],
    ['𖺭', 'Ŋ', 'U+16EAD', 'consonant'],
    ['𖺮', 'ɲ', 'U+16EAE', 'consonant'],
  ],
  'bk-preprod-erf-04': [
    ['𖺯', 'O', 'U+16EAF', 'vowel'],
    ['𖺰', 'P', 'U+16EB0', 'consonant'],
    ['𖺱', 'R', 'U+16EB1', 'consonant'],
    ['𖺲', 'Ŕ', 'U+16EB2', 'consonant'],
    ['𖺳', 'S', 'U+16EB3', 'consonant'],
  ],
  'bk-preprod-erf-05': [
    ['𖺴', 'Š', 'U+16EB4', 'consonant'],
    ['𖺵', 'T', 'U+16EB5', 'consonant'],
    ['𖺶', 'U', 'U+16EB6', 'vowel'],
    ['𖺷', 'W', 'U+16EB7', 'consonant'],
    ['𖺸', 'Y', 'U+16EB8', 'consonant'],
  ],
};

LearningUnitModel _buildUnit(String slug, {String? audioUrl}) {
  final rows = _erfLessons[slug]!;
  final unitIndex = _erfLessons.keys.toList().indexOf(slug) + 1;
  return LearningUnitModel.fromJson({
    'id': 100 + unitIndex,
    'theme': 10,
    'theme_slug': 'bk-preprod-alphabet-erfe',
    'theme_title_fr': 'Alphabet Erfe (Préproduction)',
    'slug': slug,
    'title_fr': 'Leçon $slug',
    'description_fr': 'Parcours sans audio',
    'level': 'beginner',
    'characters': [
      for (int i = 0; i < rows.length; i++)
        {
          'id': i + 1,
          'symbol': rows[i][0],
          'unicode_code': rows[i][2],
          'name_fr': 'Lettre latine ${rows[i][1]}',
          'latin_transcription': rows[i][1],
          'phoneme_ipa': 'À_VALIDER',
          'character_type': rows[i][3],
          'order_index': i + 1,
          'validation_status': 'validated',
          'is_active': true,
          'available_offline': true,
          'audio_url': (i == 0 && audioUrl != null) ? audioUrl : '',
        },
    ],
    'words': const [],
    'character_ids': [1, 2, 3, 4, 5],
    'word_ids': const [],
    'weight_recognition': 50,
    'weight_tracing': 0,
    'weight_encoding': 50,
    'enable_tracing': false,
    'estimated_minutes': 5,
    'min_score_to_pass': 70,
    'order_index': unitIndex,
    'status': 'validated',
    'is_active': true,
    'available_offline': true,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrapApp(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('fr'),
    home: child,
  );

  testWidgets('Apprenant débutant sur ERF-01 : découverte, discrimination, clavier Erfe, reprise après fermeture et score 100%', (tester) async {
    final erf01 = _buildUnit('bk-preprod-erf-01');
    final storage = UnitProgressLocalStorage();

    Future<void> tapContinue() async {
      await tester.tap(find.text('Continuer').last);
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(wrapApp(LearningCoreUnitScreen(unit: erf01)));
    await tester.pumpAndSettle();

    // 1. Découverte de la première lettre sans audio
    expect(find.textContaining('Découvre la lettre « A » (𖺠)'), findsOneWidget);
    await tapContinue();

    // 2. Discrimination visuelle de 𖺠
    expect(find.textContaining('Touche la lettre Erfe correspondant à « A »'), findsOneWidget);
    await tester.tap(find.text('𖺠').first);
    await tester.pumpAndSettle();
    await tapContinue();

    // Vérifier qu'on est maintenant à l'étape 2 (découverte de B / 𖺡)
    expect(find.textContaining('Découvre la lettre « B » (𖺡)'), findsOneWidget);

    // 3. Fermer l'écran et rouvrir (reprise hors ligne depuis SharedPreferences)
    await tester.pumpWidget(wrapApp(const Scaffold(body: Text('Fermé'))));
    await tester.pumpAndSettle();

    await tester.pumpWidget(wrapApp(LearningCoreUnitScreen(unit: erf01)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Découvre la lettre « B » (𖺡)'), findsOneWidget);

    // 4. Terminer les lettres restantes (B, D, E, F) jusqu'au clavier Erfe
    for (final sym in ['𖺡', '𖺢', '𖺣', '𖺤']) {
      await tapContinue();
      await tester.tap(find.text(sym).first);
      await tester.pumpAndSettle();
      await tapContinue();
    }

    // 5. Étape clavier Erfe : saisir 𖺠 et valider
    expect(find.textContaining('Écris la lettre « A » au clavier Erfe'), findsOneWidget);
    final erfeKey = find.text('𖺠').last;
    await tester.ensureVisible(erfeKey);
    await tester.pumpAndSettle();
    await tester.tap(erfeKey);
    await tester.pumpAndSettle();
    final validateBtn = find.byKey(const ValueKey('validate-encoding'));
    await tester.ensureVisible(validateBtn);
    await tester.pumpAndSettle();
    await tester.tap(validateBtn);
    await tester.pumpAndSettle();
    await tapContinue();

    // 6. Bilan final (étape 5. RÉVISER) puis Terminer
    expect(find.text('5. RÉVISER'), findsOneWidget);
    expect(find.textContaining('100'), findsWidgets);
    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();
    final savedProgress = await storage.getProgress('bk-preprod-erf-01');
    expect(savedProgress, isNotNull);
    expect(savedProgress!.completed, isTrue);
    expect(savedProgress.bestScorePercent, 100);
  });

  test('Contrôles complets ERF-01 à ERF-05 : parcours complet, sauvegarde/reprise hors ligne et stabilité lors de l’ajout audio', () async {
    final storage = UnitProgressLocalStorage();

    for (final slug in _erfLessons.keys) {
      final unitNoAudio = _buildUnit(slug);
      final flow = unitNoAudio.effectiveCoreFlow;
      expect(flow.length, 12, reason: '$slug doit contenir 12 étapes');
      expect(flow.where((s) => s['step_type'] == 'discovery').length, 5);
      expect(flow.where((s) => s['step_type'] == 'discrimination').length, 5);
      expect(flow.where((s) => s['step_type'] == 'keyboard_encoding').length, 1);
      expect(flow.where((s) => s['step_type'] == 'celebration').length, 1);

      final session = LearningSession(flow, {'recognition': 50, 'tracing': 0, 'encoding': 50}, 70);
      // Simuler fermeture à mi-parcours puis reprise hors ligne
      for (int i = 0; i < 4; i++) {
        session.currentStep = i;
        session.viewed.add(i);
        if (LearningSession.category(flow[i]) != null) {
          session.answer(true);
        }
      }
      session.currentStep = 4;
      await storage.saveSession(slug, session);

      final reopened = LearningSession(flow, {'recognition': 50, 'tracing': 0, 'encoding': 50}, 70);
      await storage.restoreSession(slug, reopened);
      expect(reopened.currentStep, 4);

      for (int i = 4; i < flow.length - 1; i++) {
        reopened.currentStep = i;
        reopened.viewed.add(i);
        if (LearningSession.category(flow[i]) != null) {
          reopened.answer(true);
        }
      }
      reopened.currentStep = flow.length - 1;
      reopened.finished = true;
      await storage.saveSession(slug, reopened);

      final progress = await storage.getProgress(slug);
      expect(progress, isNotNull);
      expect(progress!.completed, isTrue);
      expect(progress.bestScorePercent, 100);

      // Ajout ultérieur d'un audio : la révision et la reprise restent intactes
      final unitWithAudio = _buildUnit(slug, audioUrl: '/media/audio/$slug.mp3');
      final sessionAfterAudio = LearningSession(
        unitWithAudio.effectiveCoreFlow,
        {'recognition': 50, 'tracing': 0, 'encoding': 50},
        70,
      );
      expect(sessionAfterAudio.revision, equals(reopened.revision));
      await storage.restoreSession(slug, sessionAfterAudio);
      expect(sessionAfterAudio.finished, isTrue);
      expect(sessionAfterAudio.score, 100);
    }
  });
}
