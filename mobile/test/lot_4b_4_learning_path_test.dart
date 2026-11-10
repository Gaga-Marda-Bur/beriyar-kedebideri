import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/widgets/bk_learning_node.dart';
import 'package:mobile/features/learning/models/learning_theme_model.dart';
import 'package:mobile/features/learning/screens/learning_path_screen.dart';
import 'package:mobile/features/learning/screens/srs_review_session_screen.dart';
import 'package:mobile/features/learning/srs/local_srs_service.dart';
import 'package:mobile/features/progress/models/unit_progress_local_model.dart';
import 'package:mobile/features/progress/services/unit_progress_local_storage.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';

List<LearningThemeModel> _buildSampleThemes() {
  return [
    LearningThemeModel.fromJson({
      'id': 1,
      'slug': 'theme-fondations-erfe',
      'title_fr': 'Fondations de l\'Erfe',
      'title_en': 'Erfe Foundations',
      'title_ar': 'أساسيات الإرفي',
      'description_fr': 'Premiers sons et caractères authentiques Beřiya',
      'description_en': 'First authentic Beřiya sounds and characters',
      'description_ar': 'الأصوات والحروف الأولى',
      'level': 'beginner',
      'order_index': 1,
      'status': 'published',
      'is_active': true,
      'available_offline': true,
      'units_count': 4,
      'units': [
        {
          'id': 101,
          'theme': 1,
          'slug': 'unit-1-completed',
          'title_fr': 'Unité 1 : Consonne 𖺡 (/b/)',
          'title_en': 'Unit 1: Consonant 𖺡 (/b/)',
          'title_ar': 'الوحدة ١',
          'description_fr': 'Découverte orale et lecture de 𖺡',
          'description_en': 'Oral discovery of 𖺡',
          'description_ar': 'اكتشاف 𖺡',
          'level': 'beginner',
          'estimated_minutes': 5,
          'min_score_to_pass': 70,
          'order_index': 1,
          'status': 'published',
          'is_active': true,
          'available_offline': true,
          'characters_count': 2,
          'words_count': 1,
        },
        {
          'id': 102,
          'theme': 1,
          'slug': 'unit-2-review-due',
          'title_fr': 'Unité 2 : Voyelle 𖺣 (/e/)',
          'title_en': 'Unit 2: Vowel 𖺣 (/e/)',
          'title_ar': 'الوحدة ٢',
          'description_fr': 'Reconnaissance et syllabe 𖺡𖺣',
          'description_en': 'Recognition and syllable 𖺡𖺣',
          'description_ar': 'تعرّف ومقطع 𖺡𖺣',
          'level': 'beginner',
          'estimated_minutes': 5,
          'min_score_to_pass': 70,
          'order_index': 2,
          'status': 'published',
          'is_active': true,
          'available_offline': true,
          'characters_count': 2,
          'words_count': 2,
        },
        {
          'id': 103,
          'theme': 1,
          'slug': 'unit-3-in-progress',
          'title_fr': 'Unité 3 : Consonne 𖺵 (/t/)',
          'title_en': 'Unit 3: Consonant 𖺵 (/t/)',
          'title_ar': 'الوحدة ٣',
          'description_fr': 'Composition au clavier Erfe',
          'description_en': 'Erfe keyboard composition',
          'description_ar': 'الكتابة بلوحة الإرفي',
          'level': 'beginner',
          'estimated_minutes': 6,
          'min_score_to_pass': 70,
          'order_index': 3,
          'status': 'published',
          'is_active': true,
          'available_offline': true,
          'characters_count': 3,
          'words_count': 2,
        },
        {
          'id': 104,
          'theme': 1,
          'slug': 'unit-4-locked',
          'title_fr': 'Unité 4 : Mots du quotidien 𖺠',
          'title_en': 'Unit 4: Everyday words 𖺠',
          'title_ar': 'الوحدة ٤',
          'description_fr': 'Consolidation orale et écrite',
          'description_en': 'Oral and written consolidation',
          'description_ar': 'تثبيت سمعي وكتابي',
          'level': 'beginner',
          'estimated_minutes': 7,
          'min_score_to_pass': 70,
          'order_index': 4,
          'status': 'published',
          'is_active': true,
          'available_offline': true,
          'characters_count': 4,
          'words_count': 3,
        },
      ],
    }),
  ];
}

Widget _wrapWithApp(
  Widget child, {
  ThemeData? theme,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    locale: const Locale('fr'),
    theme: theme ?? AppTheme.darkTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, widget) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(textScaler: textScaler),
        child: widget!,
      );
    },
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lot 4B.4 — Logique déterministe des états BkLearningNode', () {
    test('Distingue les 5 états : locked, available, inProgress, completed et reviewDue', () {
      // 1. Verrouillé si non commencé et unité précédente non terminée
      expect(
        LearningPathScreen.resolveNodeStatus(
          progress: null,
          dueSrsCount: 0,
          isFirstUnit: false,
          previousUnitCompleted: false,
        ),
        BkLearningNodeStatus.locked,
      );

      // 2. Disponible si première unité ou unité précédente terminée
      expect(
        LearningPathScreen.resolveNodeStatus(
          progress: null,
          dueSrsCount: 0,
          isFirstUnit: true,
          previousUnitCompleted: false,
        ),
        BkLearningNodeStatus.available,
      );
      expect(
        LearningPathScreen.resolveNodeStatus(
          progress: null,
          dueSrsCount: 0,
          isFirstUnit: false,
          previousUnitCompleted: true,
        ),
        BkLearningNodeStatus.available,
      );

      // 3. En cours si commencé mais non terminé
      final inProgressModel = UnitProgressLocalModel.fromJson({
        'unit_slug': 'unit-3',
        'status': 'in_progress',
        'current_step': 2,
        'total_steps': 5,
        'completed': false,
        'best_score_percent': 40,
        'quizzes_answered': 1,
        'correct_answers': 1,
      });
      expect(
        LearningPathScreen.resolveNodeStatus(
          progress: inProgressModel,
          dueSrsCount: 0,
          isFirstUnit: false,
          previousUnitCompleted: true,
        ),
        BkLearningNodeStatus.inProgress,
      );
      expect(
        LearningPathScreen.resolveNodeProgress(inProgressModel),
        closeTo(0.4, 0.001),
      );

      // 4. Terminé si completed == true et 0 révision SRS due
      final completedModel = inProgressModel.copyWith(
        completed: true,
        currentStep: 5,
        bestScorePercent: 92,
      );
      expect(
        LearningPathScreen.resolveNodeStatus(
          progress: completedModel,
          dueSrsCount: 0,
          isFirstUnit: true,
          previousUnitCompleted: true,
        ),
        BkLearningNodeStatus.completed,
      );
      expect(LearningPathScreen.resolveNodeProgress(completedModel), 1.0);

      // 5. Révision à effectuer (reviewDue) si des éléments SRS sont dus
      expect(
        LearningPathScreen.resolveNodeStatus(
          progress: completedModel,
          dueSrsCount: 2,
          isFirstUnit: true,
          previousUnitCompleted: true,
        ),
        BkLearningNodeStatus.reviewDue,
      );
    });

    test('Extrait le glyphe Unicode Erfe du titre ou de la description', () {
      expect(
        LearningPathScreen.extractErfeSymbol('Unité 1 : Consonne 𖺡 (/b/)'),
        '𖺡',
      );
      expect(
        LearningPathScreen.extractErfeSymbol('Titre sans caractère'),
        isNull,
      );
    });
  });

  group('Lot 4B.4 — Interface du chemin d’apprentissage modernisé (Parcours A & B)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'bk_audio_auto_play_v1': false});
    });

    testWidgets(
      'Parcours A : affiche BkLearningNode (completed, reviewDue, inProgress, locked), la prochaine activité recommandée, le compteur SRS et les packs hors ligne',
      (tester) async {
        final t0 = DateTime.utc(2026, 11, 10, 12, 0);
        final progressStorage = UnitProgressLocalStorage();
        final srsService = LocalSrsService(userScope: 'path_test', clock: () => t0);

        // Unité 1 : terminée sans SRS dû
        await progressStorage.saveProgress(
          UnitProgressLocalModel.fromJson({
            'unit_slug': 'unit-1-completed',
            'status': 'completed',
            'current_step': 4,
            'total_steps': 4,
            'completed': true,
            'best_score_percent': 95,
            'quizzes_answered': 2,
            'correct_answers': 2,
          }),
        );

        // Unité 2 : terminée mais avec 1 élément SRS difficile / à réviser
        await progressStorage.saveProgress(
          UnitProgressLocalModel.fromJson({
            'unit_slug': 'unit-2-review-due',
            'status': 'completed',
            'current_step': 4,
            'total_steps': 4,
            'completed': true,
            'best_score_percent': 80,
            'quizzes_answered': 2,
            'correct_answers': 2,
          }),
        );
        await srsService.recordOutcome(
          itemType: 'char',
          erfeText: '𖺣',
          unitSlug: 'unit-2-review-due',
          correct: false, // Marqué difficile -> dû immédiatement
          label: 'Voyelle e',
        );

        // Unité 3 : en cours (étape 2/5)
        await progressStorage.saveProgress(
          UnitProgressLocalModel.fromJson({
            'unit_slug': 'unit-3-in-progress',
            'status': 'in_progress',
            'current_step': 2,
            'total_steps': 5,
            'completed': false,
            'best_score_percent': 50,
            'quizzes_answered': 1,
            'correct_answers': 1,
          }),
        );

        // Unité 4 : non commencée (et Unité 3 non terminée -> verrouillée)

        await tester.pumpWidget(
          _wrapWithApp(
            LearningPathScreen(
              initialThemes: _buildSampleThemes(),
              progressStorage: progressStorage,
              srsService: srsService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Indicateurs de réussite discrets
        expect(find.byKey(const ValueKey('discreet-progress-summary')), findsOneWidget);
        expect(find.textContaining('2 / 4 unités validées'), findsOneWidget);

        // 2. Bandeau SRS avec compteur exact ("1 élément(s) à réviser") et bouton direct
        expect(find.byKey(const ValueKey('learning-path-srs-banner')), findsOneWidget);
        expect(find.text('1 élément(s) à réviser'), findsOneWidget);
        expect(find.byKey(const ValueKey('learning-path-srs-review-button')), findsOneWidget);

        // 3. Accès aux packs hors ligne conservé
        expect(find.byKey(const ValueKey('learning-path-offline-packs-action')), findsOneWidget);
        expect(find.byKey(const ValueKey('learning-path-offline-packs-card')), findsOneWidget);

        // 4. Prochaine activité recommandée mise en évidence (Unité 3 en cours est prioritaire)
        expect(find.byKey(const ValueKey('recommended-next-activity-card')), findsOneWidget);
        expect(find.text('REPRENDRE LA SÉANCE'), findsOneWidget);

        // 5. Vérification des 4 nœuds BkLearningNode et de leurs états
        final node1 = tester.widget<BkLearningNode>(
          find.byKey(const ValueKey('learning-node-unit-1-completed')),
        );
        final node2 = tester.widget<BkLearningNode>(
          find.byKey(const ValueKey('learning-node-unit-2-review-due')),
        );
        final node3 = tester.widget<BkLearningNode>(
          find.byKey(const ValueKey('learning-node-unit-3-in-progress')),
        );
        final node4 = tester.widget<BkLearningNode>(
          find.byKey(const ValueKey('learning-node-unit-4-locked')),
        );

        expect(node1.status, BkLearningNodeStatus.completed);
        expect(node2.status, BkLearningNodeStatus.reviewDue);
        expect(node3.status, BkLearningNodeStatus.inProgress);
        expect(node4.status, BkLearningNodeStatus.locked);

        // 6. Accès direct aux révisions SRS depuis le bandeau
        await tester.ensureVisible(
          find.byKey(const ValueKey('learning-path-srs-review-button')),
        );
        await tester.tap(find.byKey(const ValueKey('learning-path-srs-review-button')));
        await tester.pumpAndSettle();
        expect(find.byType(SrsReviewSessionScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Choix entre Parcours A et Parcours B : préserve le catalogue libre du Parcours B sans verrouillage séquentiel',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithApp(
            LearningPathScreen(
              initialThemes: _buildSampleThemes(),
              progressStorage: UnitProgressLocalStorage(),
              srsService: LocalSrsService(userScope: 'track_b_test'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Par défaut sur le Parcours A
        expect(find.byKey(const ValueKey('track-selector-a')), findsOneWidget);
        expect(find.byKey(const ValueKey('track-selector-b')), findsOneWidget);

        // Bascule vers le Parcours B (« J'apprends le Beřiya et l'Erfe »)
        await tester.ensureVisible(find.byKey(const ValueKey('track-selector-b')));
        await tester.tap(find.byKey(const ValueKey('track-selector-b')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('track-b-overview-card')), findsOneWidget);
        // En Parcours B, même la 4e unité est accessible librement (sans verrouillage)
        expect(find.byKey(const ValueKey('track-b-unit-unit-4-locked')), findsOneWidget);
        final openDetailBtn = tester.widget<OutlinedButton>(
          find.byKey(const ValueKey('track-b-open-detail-unit-4-locked')),
        );
        expect(openDetailBtn.onPressed, isNotNull);
      },
    );

    testWidgets(
      'Accessibilité : thèmes clair et sombre, petits écrans (320x568 & 360x800) et TextScaler 1.3x sans débordement',
      (tester) async {
        for (final size in [const Size(320, 568), const Size(360, 800)]) {
          for (final theme in [AppTheme.darkTheme(), AppTheme.lightTheme()]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;

            await tester.pumpWidget(
              _wrapWithApp(
                LearningPathScreen(
                  initialThemes: _buildSampleThemes(),
                  progressStorage: UnitProgressLocalStorage(),
                  srsService: LocalSrsService(userScope: 'a11y_test'),
                ),
                theme: theme,
                textScaler: const TextScaler.linear(1.3),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
          }
        }
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      },
    );
  });
}
