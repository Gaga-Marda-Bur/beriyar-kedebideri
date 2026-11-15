import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mobile/features/learning/engine/learning_session.dart';
import 'package:mobile/features/learning/models/learning_unit_model.dart';
import 'package:mobile/features/learning/screens/learning_core_unit_screen.dart';
import 'package:mobile/features/learning/screens/srs_review_session_screen.dart';
import 'package:mobile/features/learning/srs/local_srs_service.dart';
import 'package:mobile/features/progress/services/unit_progress_local_storage.dart';

LearningUnitModel _buildErf01() {
  const rows = [
    ['𖺠', 'A', 'U+16EA0', 'vowel'],
    ['𖺡', 'B', 'U+16EA1', 'consonant'],
    ['𖺢', 'D', 'U+16EA2', 'consonant'],
    ['𖺣', 'E', 'U+16EA3', 'vowel'],
    ['𖺤', 'F', 'U+16EA4', 'consonant'],
  ];
  return LearningUnitModel.fromJson({
    'id': 101,
    'theme': 10,
    'theme_slug': 'bk-preprod-alphabet-erfe',
    'theme_title_fr': 'Alphabet Erfe (Préproduction)',
    'slug': 'bk-preprod-erf-01',
    'title_fr': 'Alphabet Erfe — groupe 1',
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
          'audio_url': '',
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
    'order_index': 1,
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

  testWidgets('Pilote ERF-01 : réponses incorrectes et correctes, score < 100%, révision SRS sans audio et reprise hors ligne', (tester) async {
    final erf01 = _buildErf01();
    final storage = UnitProgressLocalStorage();
    final srsService = LocalSrsService();

    Future<void> tapContinue() async {
      await tester.tap(find.text('Continuer').last);
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(wrapApp(LearningCoreUnitScreen(unit: erf01, srsService: srsService)));
    await tester.pumpAndSettle();

    // 1. Découverte de A -> Continuer
    await tapContinue();

    // 2. Discrimination de A (attendu 𖺠) : répondre FAUX d'abord (𖺡), puis CORRIGER (𖺠)
    await tester.ensureVisible(find.text('𖺡').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('𖺡').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('𖺠').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('𖺠').first);
    await tester.pumpAndSettle();
    await tapContinue();

    // 3. Compléter B, D, E, F correctement
    for (final sym in ['𖺡', '𖺢', '𖺣', '𖺤']) {
      await tapContinue();
      final card = find.text(sym).first;
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      await tapContinue();
    }

    // 4. Clavier Erfe : saisir FAUX (𖺡) -> Valider, vérifier encouragement, effacer, saisir BON (𖺠) -> Valider
    final wrongKey = find.text('𖺡').last;
    await tester.ensureVisible(wrongKey);
    await tester.pumpAndSettle();
    await tester.tap(wrongKey);
    await tester.pumpAndSettle();

    final validateBtn = find.byKey(const ValueKey('validate-encoding'));
    await tester.ensureVisible(validateBtn);
    await tester.pumpAndSettle();
    await tester.tap(validateBtn);
    await tester.pumpAndSettle();
    expect(find.text('Vérifiez les caractères Erfe'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pumpAndSettle();
    final rightKey = find.text('𖺠').last;
    await tester.ensureVisible(rightKey);
    await tester.pumpAndSettle();
    await tester.tap(rightKey);
    await tester.pumpAndSettle();
    await tester.ensureVisible(validateBtn);
    await tester.pumpAndSettle();
    await tester.tap(validateBtn);
    await tester.pumpAndSettle();
    expect(find.text('Mot Erfe validé !'), findsOneWidget);
    await tapContinue();

    // 5. Bilan : 4/5 reconnaissance (80%) + 0/1 premier essai encodage (0%) => score 40% (< 70%)
    expect(find.text('5. RÉVISER'), findsOneWidget);
    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();

    final progress = await storage.getProgress('bk-preprod-erf-01');
    expect(progress, isNotNull);
    expect(progress!.bestScorePercent, 40);
    expect(progress.completed, isFalse);

    // 6. Vérifier que les éléments SRS ont bien enregistré le libellé latin ('A'..)
    final srsMap = await srsService.loadAllMap();
    final charA = srsMap.values.firstWhere((r) => r.erfeText == '𖺠' && r.itemType == 'char');
    expect(charA.translationFr, 'A');

    // 7. Ouvrir l'écran de révision SRS sans audio avec cet item : consigne lisible + aucune pénalité
    await tester.pumpWidget(
      wrapApp(
        SrsReviewSessionScreen(
          items: [charA],
          distractorPool: const ['𖺠', '𖺡', '𖺢', '𖺣'],
          srsService: srsService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Touchez l\'écriture Erfe correspondant à « A »'), findsOneWidget);
    expect(find.byKey(const ValueKey('srs-audio-missing-banner')), findsOneWidget);

    // Répondre correctement dans la révision SRS
    final optionA = find.byKey(ValueKey('srs-option-${charA.stableId}-𖺠'));
    await tester.ensureVisible(optionA);
    await tester.pumpAndSettle();
    await tester.tap(optionA);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Continuer').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('srs-summary-card')), findsOneWidget);
    expect(find.textContaining('Bilan SRS'), findsOneWidget);
  });

  test('Scoring LearningSession : réussite >= 70% vs révision < 70%', () {
    final erf01 = _buildErf01();
    final flow = erf01.effectiveCoreFlow;
    final weights = {'recognition': 50, 'tracing': 0, 'encoding': 50};

    // 3/5 reconnaissance (60%) + 1/1 encodage (100%) => 80% >= 70% => passed
    final passSession = LearningSession(flow, weights, 70);
    int recCount = 0;
    for (int i = 0; i < flow.length - 1; i++) {
      passSession.currentStep = i;
      passSession.viewed.add(i);
      final cat = LearningSession.category(flow[i]);
      if (cat == 'recognition') {
        if (recCount < 3) {
          passSession.answer(true);
        } else {
          passSession.answer(false);
          passSession.answer(true);
        }
        recCount++;
      } else if (cat == 'encoding') {
        passSession.answer(true);
      }
    }
    passSession.finished = true;
    expect(passSession.score, 80);
    expect(passSession.passed, isTrue);

    // 1/5 reconnaissance (20%) + 0/1 encodage (0%) => 10% < 70% => failed (révision requise)
    final failSession = LearningSession(flow, weights, 70);
    recCount = 0;
    for (int i = 0; i < flow.length - 1; i++) {
      failSession.currentStep = i;
      failSession.viewed.add(i);
      final cat = LearningSession.category(flow[i]);
      if (cat == 'recognition') {
        if (recCount == 0) {
          failSession.answer(true);
        } else {
          failSession.answer(false);
          failSession.answer(true);
        }
        recCount++;
      } else if (cat == 'encoding') {
        failSession.answer(false);
        failSession.answer(true);
      }
    }
    failSession.finished = true;
    expect(failSession.score, 10);
    expect(failSession.passed, isFalse);
  });
}
