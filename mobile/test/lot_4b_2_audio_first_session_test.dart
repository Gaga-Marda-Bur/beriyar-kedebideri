import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/audio/bk_audio_preferences.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/widgets/bk_audio_hero_button.dart';
import 'package:mobile/core/widgets/bk_feedback_sheet.dart';
import 'package:mobile/core/widgets/bk_option_card.dart';
import 'package:mobile/features/learning/engine/learning_session.dart';
import 'package:mobile/features/learning/models/learning_unit_model.dart';
import 'package:mobile/features/learning/screens/learning_core_unit_screen.dart';
import 'package:mobile/features/progress/services/unit_progress_local_storage.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mobile/shared/beriya/beriya_keyboard.dart';

/// Unité authentique du Pilote A (« Je parle Beřiya, j'apprends l'Erfe »)
/// utilisant uniquement des caractères (𖺠, 𖺡, 𖺣) et mots (𖺡𖺣) réels validés,
/// avec certains audios présents et certains audios manquants (conformément à l'Étape 3).
LearningUnitModel buildPilotAudioFirstUnit({bool withMissingAudio = false}) {
  return LearningUnitModel.fromJson({
    'id': 101,
    'slug': 'pilote-a-unite-1',
    'title_fr': 'Pilote A — Unité 1 : Premiers sons Erfe',
    'title_en': 'Pilot A — Unit 1: First Erfe sounds',
    'title_ar': 'الوحدة ١',
    'level': 'beginner',
    'enable_tracing': false,
    'weight_recognition': 50,
    'weight_tracing': 0,
    'weight_encoding': 50,
    'min_score_to_pass': 70,
    'estimated_minutes': 5,
    'order_index': 1,
    'status': 'published',
    'is_active': true,
    'available_offline': true,
    'core_flow': [
      {
        'index': 0,
        'step_type': 'discovery',
        'symbol': '𖺡',
        'unicode_code': 'U+16EA1',
        'character_type': 'consonant',
        'phoneme_ipa': 'b',
        'label': 'Écoute et découvre la consonne /b/',
        'audio_url': withMissingAudio ? null : 'assets/audio/test_b.mp3',
        'weight_category': 'recognition',
      },
      {
        'index': 1,
        'step_type': 'discrimination',
        'target_symbol': '𖺡',
        'other_symbol': '𖺣',
        'phoneme_ipa': 'b',
        'instruction': 'Touche la consonne /b/',
        'audio_url': withMissingAudio ? '' : 'assets/audio/test_b.mp3',
        'weight_category': 'recognition',
      },
      {
        'index': 2,
        'step_type': 'word_decoding',
        'word': '𖺡𖺣',
        'latin_transcription': 'be',
        'french_translation': 'pays',
        'oral_prompt': 'Écoute et lis le mot complet',
        'audio_url': withMissingAudio ? null : 'assets/audio/test_be.mp3',
        'weight_category': 'recognition',
      },
      {
        'index': 3,
        'step_type': 'keyboard_encoding',
        'target_word': '𖺡𖺣',
        'latin_transcription': 'be',
        'french_translation': 'pays',
        'keyboard_keys': ['𖺡', '𖺣', '𖺠'],
        'instruction': 'Écris le mot "be" au clavier :',
        'audio_url': withMissingAudio ? null : 'assets/audio/test_be.mp3',
        'weight_category': 'encoding',
      },
      {
        'index': 4,
        'step_type': 'celebration',
        'title': 'Félicitations !',
        'message': 'Tu as terminé la séance Pilote A !',
        'target_word': '𖺡𖺣',
        'french_translation': 'pays',
      },
    ],
  });
}

Widget wrapWithApp(
  Widget child, {
  ThemeData? theme,
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    locale: const Locale('fr'),
    theme: theme ?? AppTheme.darkTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, widget) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(
          textScaler: textScaler,
          disableAnimations: disableAnimations,
        ),
        child: widget!,
      );
    },
    home: child,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Étape 1 — Tests de référence du moteur LearningSession existant', () {
    test('Le moteur LearningSession conserve son calcul de révision et son barème v2', () {
      final unit = buildPilotAudioFirstUnit();
      final session = LearningSession(
        unit.effectiveCoreFlow,
        {'recognition': 50, 'tracing': 0, 'encoding': 50},
        unit.minScoreToPass,
      );

      expect(session.scoringVersionCompat, 2);
      expect(session.steps.length, 5);
      expect(session.canAdvance, isTrue); // discovery (étape 0) non évaluée
    });
  });

  group('Étape 2 — Séance pédagogique audio-first en 5 étapes (ÉCOUTER, RECONNAÎTRE, LIRE, COMPOSER, RÉVISER)', () {
    testWidgets(
      'Parcours complet des 5 étapes avec BkAudioHeroButton, BkOptionCard, BkFeedbackSheet et bilan RÉVISER',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final unit = buildPilotAudioFirstUnit();
        await tester.pumpWidget(
          wrapWithApp(LearningCoreUnitScreen(unit: unit)),
        );
        await tester.pumpAndSettle();

        // --- ÉTAPE 1 : ÉCOUTER (discovery) ---
        expect(find.byKey(const ValueKey('session-phase-badge')), findsOneWidget);
        expect(find.textContaining('ÉCOUTER'), findsOneWidget);
        expect(find.byType(BkAudioHeroButton), findsOneWidget);
        expect(find.byKey(const ValueKey('bk-audio-replay-button')), findsOneWidget);
        expect(find.text('𖺡'), findsWidgets);

        await tester.tap(find.byKey(const ValueKey('learning-next')));
        await tester.pumpAndSettle();

        // --- ÉTAPE 2 : RECONNAÎTRE (discrimination) ---
        expect(find.textContaining('RECONNAÎTRE'), findsOneWidget);
        expect(find.byType(BkAudioHeroButton), findsOneWidget);
        expect(find.byType(BkOptionCard), findsNWidgets(2));

        // 1re tentative erronée -> affiche BkFeedbackSheet d'encouragement, sans bloquer la suite
        await tester.tap(find.byKey(const ValueKey('answer-1-𖺣')));
        await tester.pumpAndSettle();
        expect(find.byType(BkFeedbackSheet), findsOneWidget);

        // 2e tentative correcte -> affiche BkFeedbackSheet positif
        await tester.tap(find.byKey(const ValueKey('answer-1-𖺡')));
        await tester.pumpAndSettle();
        expect(find.byType(BkFeedbackSheet), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('learning-next')));
        await tester.pumpAndSettle();

        // --- ÉTAPE 3 : LIRE (word_decoding) ---
        expect(find.textContaining('LIRE'), findsOneWidget);
        expect(find.byType(BkAudioHeroButton), findsOneWidget);
        expect(find.text('𖺡𖺣'), findsWidgets);
        expect(find.textContaining('pays'), findsWidgets);

        await tester.tap(find.byKey(const ValueKey('learning-next')));
        await tester.pumpAndSettle();

        // --- ÉTAPE 4 : COMPOSER (keyboard_encoding) ---
        expect(find.textContaining('COMPOSER'), findsOneWidget);
        expect(find.byType(BeriyaKeyboard), findsOneWidget);

        // Saisie du mot 𖺡𖺣 au clavier Erfe existant
        final keyboard = tester.widget<BeriyaKeyboard>(find.byType(BeriyaKeyboard));
        keyboard.onInsert('𖺡');
        keyboard.onInsert('𖺣');
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const ValueKey('validate-encoding')));
        await tester.tap(find.byKey(const ValueKey('validate-encoding')));
        await tester.pumpAndSettle();
        expect(find.byType(BkFeedbackSheet), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('learning-next')));
        await tester.pumpAndSettle();

        // --- ÉTAPE 5 : RÉVISER (celebration / récapitulatif) ---
        expect(find.textContaining('RÉVISER'), findsOneWidget);
        // L'étape 4 (𖺡𖺣) a été réussie du 1er coup -> présente dans mastered
        expect(find.byKey(const ValueKey('review-mastered-section')), findsOneWidget);
        // L'étape 2 (𖺡) a eu 1 erreur avant réussite -> présente dans difficult
        expect(find.byKey(const ValueKey('review-difficult-section')), findsOneWidget);

        // Terminer la séance et vérifier la sauvegarde dans UnitProgressLocalStorage
        await tester.tap(find.byKey(const ValueKey('learning-next')));
        await tester.pumpAndSettle();

        final savedProgress = await UnitProgressLocalStorage().getProgress('pilote-a-unite-1');
        expect(savedProgress, isNotNull);
        expect(savedProgress!.quizzesAnswered, 2);
        expect(savedProgress.correctAnswers, 1);
      },
    );
  });

  group('Étape 3 — Données authentiques & Gestion gracieuse des audios absents', () {
    testWidgets(
      'Audio absent : affiche un état clair non bloquant et permet de compléter toute la séance',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final unitWithoutAudio = buildPilotAudioFirstUnit(withMissingAudio: true);
        await tester.pumpWidget(
          wrapWithApp(LearningCoreUnitScreen(unit: unitWithoutAudio)),
        );
        await tester.pumpAndSettle();

        // Bannière informative d'audio absent affichée, aucune erreur bloquante
        expect(find.byKey(const ValueKey('audio-missing-banner')), findsOneWidget);

        // Peut avancer à l'étape 2 (RECONNAÎTRE)
        await tester.tap(find.byKey(const ValueKey('learning-next')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('audio-missing-banner')), findsOneWidget);

        // Peut répondre et avancer à l'étape 3 (LIRE)
        await tester.tap(find.byKey(const ValueKey('answer-1-𖺡')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('learning-next')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('audio-missing-banner')), findsOneWidget);
      },
    );
  });

  group('Étape 4 — Accessibilité, Auto-play configurable, TextScaler & Animations réduites', () {
    testWidgets(
      'Permet de basculer la préférence auto-play depuis la séance et persiste le choix',
      (tester) async {
        SharedPreferences.setMockInitialValues({'bk_audio_auto_play': true});

        final unit = buildPilotAudioFirstUnit();
        await tester.pumpWidget(
          wrapWithApp(LearningCoreUnitScreen(unit: unit)),
        );
        await tester.pumpAndSettle();

        final toggleFinder = find.byKey(const ValueKey('toggle-autoplay-button'));
        expect(toggleFinder, findsOneWidget);
        expect(await BkAudioPreferencesService.isAutoPlayEnabled(), isTrue);

        await tester.tap(toggleFinder);
        await tester.pumpAndSettle();
        expect(await BkAudioPreferencesService.isAutoPlayEnabled(), isFalse);
      },
    );

    testWidgets(
      'Respecte auto-play désactivé dès l\'ouverture de la séance (icône volume_off et bouton Réécouter actif)',
      (tester) async {
        SharedPreferences.setMockInitialValues({'bk_audio_auto_play': false});

        final unit = buildPilotAudioFirstUnit();
        await tester.pumpWidget(
          wrapWithApp(LearningCoreUnitScreen(unit: unit)),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
        expect(find.byKey(const ValueKey('bk-audio-replay-button')), findsOneWidget);
      },
    );

    testWidgets(
      'Supporte TextScaler 1.3x, disableAnimations=true et thème Clair sur écran compact (360x800)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final unit = buildPilotAudioFirstUnit();
        await tester.pumpWidget(
          wrapWithApp(
            LearningCoreUnitScreen(unit: unit),
            theme: AppTheme.lightTheme(),
            textScaler: const TextScaler.linear(1.3),
            disableAnimations: true,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(BkAudioHeroButton), findsOneWidget);
      },
    );
  });
}

extension on LearningSession {
  int get scoringVersionCompat => LearningSession.scoringVersion;
}
