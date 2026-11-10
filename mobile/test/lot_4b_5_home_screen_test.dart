import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/cache/cached_content_service.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/home/screens/home_screen.dart';
import 'package:mobile/features/learning/models/learning_theme_model.dart';
import 'package:mobile/features/learning/models/learning_unit_model.dart';
import 'package:mobile/features/learning/screens/learning_path_screen.dart';
import 'package:mobile/features/learning/screens/srs_review_session_screen.dart';
import 'package:mobile/features/learning/srs/local_srs_service.dart';
import 'package:mobile/features/progress/models/unit_progress_local_model.dart';
import 'package:mobile/features/progress/services/unit_progress_local_storage.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';

class _FakeOfflineContentService extends CachedContentService {
  final List<LearningThemeModel> themes;
  final bool failThemesWithSocketException;

  _FakeOfflineContentService({
    required this.themes,
    this.failThemesWithSocketException = false,
  });

  @override
  Future<List<LearningThemeModel>> loadThemes({
    bool forceRefresh = false,
  }) async {
    if (failThemesWithSocketException) {
      throw const SocketException('API unreachable offline');
    }
    return themes;
  }

  @override
  Future<List<LearningUnitModel>> loadUnits({
    String? themeSlug,
    bool forceRefresh = false,
  }) async {
    return [
      LearningUnitModel.fromJson({
        'id': 102,
        'slug': 'unit-2-mots',
        'title_fr': 'Unité 2 : Premiers mots 𖺵',
        'title_en': 'Unit 2: First words 𖺵',
        'title_ar': 'الوحدة 2',
        'level': 'beginner',
        'enable_tracing': false,
        'weight_recognition': 50,
        'weight_tracing': 0,
        'weight_encoding': 50,
        'min_score_to_pass': 70,
        'estimated_minutes': 5,
        'order_index': 2,
        'status': 'published',
        'is_active': true,
        'available_offline': true,
        'core_flow': [
          {
            'index': 0,
            'step_type': 'discovery',
            'symbol': '𖺵',
            'unicode_code': 'U+16EB5',
            'character_type': 'consonant',
            'phoneme_ipa': 't',
            'label': 'Écoute et découvre la consonne /t/',
            'audio_url': null,
            'weight_category': 'recognition',
          },
        ],
      }),
    ];
  }
}

List<LearningThemeModel> _buildSampleThemes() {
  return [
    LearningThemeModel.fromJson({
      'id': 1,
      'slug': 'theme-salutations',
      'title_fr': 'Salutations Beřiya',
      'title_en': 'Beřiya Greetings',
      'title_ar': 'تحيات البيريا',
      'description_fr': 'Premiers échanges oraux et lettres Erfe',
      'description_en': 'First oral exchanges and Erfe letters',
      'description_ar': 'التبادلات الشفهية الأولى وحروف إرفي',
      'level': 'beginner',
      'order_index': 1,
      'status': 'published',
      'is_active': true,
      'available_offline': true,
      'units_count': 2,
      'units': [
        {
          'id': 101,
          'theme': 1,
          'slug': 'unit-1-lettres',
          'title_fr': 'Unité 1 : Lettres 𖺡 et 𖺣',
          'title_en': 'Unit 1: Letters 𖺡 and 𖺣',
          'title_ar': 'الوحدة 1',
          'description_fr': 'Sons de base et écriture Erfe',
          'description_en': 'Basic sounds and Erfe script',
          'description_ar': 'الأصوات الأساسية',
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
          'slug': 'unit-2-mots',
          'title_fr': 'Unité 2 : Premiers mots 𖺵',
          'title_en': 'Unit 2: First words 𖺵',
          'title_ar': 'الوحدة 2',
          'description_fr': 'Vocabulaire oral du quotidien',
          'description_en': 'Everyday oral vocabulary',
          'description_ar': 'المفردات اليومية',
          'level': 'beginner',
          'estimated_minutes': 6,
          'min_score_to_pass': 70,
          'order_index': 2,
          'status': 'published',
          'is_active': true,
          'available_offline': true,
          'characters_count': 2,
          'words_count': 2,
        },
      ],
    }),
  ];
}

Widget _wrapHome({
  required Widget child,
  ThemeData? theme,
  double textScale = 1.0,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.darkTheme(),
    locale: const Locale('fr'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    builder: (context, inner) {
      final mq = MediaQuery.of(context);
      return MediaQuery(
        data: mq.copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: inner!,
      );
    },
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lot 4B.5 — Modernisation de HomeScreen et continuité pédagogique', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'bk_audio_auto_play_v1': false,
      });
    });

    testWidgets(
      '1. Nouvelle hiérarchie de l\'accueil (Parcours actif, Continuer, SRS état vide, Hors ligne, Accès secondaires)',
      (tester) async {
        final contentService = _FakeOfflineContentService(
          themes: _buildSampleThemes(),
        );

        await tester.pumpWidget(
          _wrapHome(
            child: HomeScreen(
              contentService: contentService,
              initialThemes: _buildSampleThemes(),
              enablePreload: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Parcours actuel A ou B
        expect(
          find.byKey(const ValueKey('home-active-track-card')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('home-track-a-button')), findsOneWidget);
        expect(find.byKey(const ValueKey('home-track-b-button')), findsOneWidget);

        // 2. Action principale « Continuer à apprendre »
        expect(
          find.byKey(const ValueKey('home-continue-learning-card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-continue-learning-cta')),
          findsOneWidget,
        );
        expect(
          find.text('Unité 1 : Lettres 𖺡 et 𖺣'),
          findsOneWidget,
        );

        // 3. Révisions SRS disponibles avec état vide explicite (aucun compteur inventé)
        expect(find.byKey(const ValueKey('home-srs-review-card')), findsOneWidget);
        expect(find.byKey(const ValueKey('home-srs-empty-state')), findsOneWidget);
        expect(
          find.textContaining('Aucun élément étudié pour le moment'),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('home-srs-review-cta')), findsNothing);

        // 4. Accès aux contenus téléchargés
        expect(
          find.byKey(const ValueKey('home-offline-packs-card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-offline-packs-cta')),
          findsOneWidget,
        );

        // 5. Accès secondaires : dictionnaire, alphabet, leçons, profil
        expect(
          find.byKey(const ValueKey('home-secondary-access-section')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-secondary-dictionary')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-secondary-alphabet')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-secondary-lessons')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home-secondary-profile')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '2. Continuité pédagogique Parcours A : cible la prochaine unité réellement disponible après complétion',
      (tester) async {
        final storage = UnitProgressLocalStorage();
        // Unité 1 terminée -> l'accueil doit cibler l'Unité 2 disponible
        await storage.saveProgress(
          UnitProgressLocalModel.fromJson({
            'unit_slug': 'unit-1-lettres',
            'status': 'completed',
            'current_step': 5,
            'total_steps': 5,
            'completed': true,
            'best_score_percent': 100,
            'quizzes_answered': 2,
            'correct_answers': 2,
          }),
        );

        final contentService = _FakeOfflineContentService(
          themes: _buildSampleThemes(),
        );

        await tester.pumpWidget(
          _wrapHome(
            child: HomeScreen(
              contentService: contentService,
              progressStorage: storage,
              initialThemes: _buildSampleThemes(),
              enablePreload: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Vérifie que la carte "Continuer à apprendre" propose bien l'Unité 2
        expect(
          find.byKey(const ValueKey('home-continue-unit-title')),
          findsOneWidget,
        );
        expect(
          find.text('Unité 2 : Premiers mots 𖺵'),
          findsOneWidget,
        );

        // Clic sur "Continuer à apprendre" ouvre la séance audio-first de l'Unité 2
        await tester.tap(find.byKey(const ValueKey('home-continue-learning-cta')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('session-phase-badge')), findsOneWidget);
        expect(find.textContaining('ÉCOUTER'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Persistance locale du parcours A/B et modification à tout moment',
      (tester) async {
        await tester.pumpWidget(
          _wrapHome(
            child: HomeScreen(
              contentService: _FakeOfflineContentService(
                themes: _buildSampleThemes(),
              ),
              initialThemes: _buildSampleThemes(),
              enablePreload: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Par défaut Parcours A
        expect(
          await LearningPathScreen.loadSavedTrack(),
          BkLearningTrack.trackA,
        );

        // Passage au Parcours B depuis l'accueil
        await tester.tap(find.byKey(const ValueKey('home-track-b-button')));
        await tester.pumpAndSettle();

        expect(
          await LearningPathScreen.loadSavedTrack(),
          BkLearningTrack.trackB,
        );
        expect(find.text('Parcours B'), findsOneWidget);

        // Reconstruction d'un nouvel HomeScreen (simule redémarrage) : conserve Parcours B
        await tester.pumpWidget(
          _wrapHome(
            child: HomeScreen(
              key: const ValueKey('restarted-home'),
              contentService: _FakeOfflineContentService(
                themes: _buildSampleThemes(),
              ),
              initialThemes: _buildSampleThemes(),
              enablePreload: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Parcours B'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Révisions SRS disponibles : compteur exact et lancement facultatif de SrsReviewSessionScreen',
      (tester) async {
        final now = DateTime.utc(2026, 11, 10, 12, 0);
        final srsService = LocalSrsService(userScope: 'home_srs', clock: () => now);

        await srsService.recordOutcome(
          itemType: 'char',
          erfeText: '𖺡',
          unitSlug: 'unit-1-lettres',
          correct: false,
          label: 'Lettre Ba',
        );

        await tester.pumpWidget(
          _wrapHome(
            child: HomeScreen(
              contentService: _FakeOfflineContentService(
                themes: _buildSampleThemes(),
              ),
              srsService: srsService,
              initialThemes: _buildSampleThemes(),
              enablePreload: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1 élément(s) à réviser'), findsOneWidget);
        expect(find.byKey(const ValueKey('home-srs-empty-state')), findsNothing);
        expect(find.byKey(const ValueKey('home-srs-review-cta')), findsOneWidget);

        await tester.ensureVisible(find.byKey(const ValueKey('home-srs-review-cta')));
        await tester.tap(find.byKey(const ValueKey('home-srs-review-cta')));
        await tester.pumpAndSettle();

        expect(find.byType(SrsReviewSessionScreen), findsOneWidget);
      },
    );

    testWidgets(
      '5. Résilience hors ligne : HomeScreen reste accessible et non bloquant quand l\'API échoue',
      (tester) async {
        final storage = UnitProgressLocalStorage();
        await storage.saveProgress(
          UnitProgressLocalModel.fromJson({
            'unit_slug': 'unit-1-lettres',
            'status': 'in_progress',
            'current_step': 2,
            'total_steps': 5,
            'completed': false,
            'best_score_percent': 40,
            'quizzes_answered': 1,
            'correct_answers': 1,
          }),
        );

        final offlineFailingService = _FakeOfflineContentService(
          themes: const [],
          failThemesWithSocketException: true,
        );

        await tester.pumpWidget(
          _wrapHome(
            child: HomeScreen(
              contentService: offlineFailingService,
              progressStorage: storage,
              enablePreload: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // L'accueil s'affiche sans blocage ni erreur fatale, et conserve la progression locale
        expect(
          find.byKey(const ValueKey('home-continue-learning-card')),
          findsOneWidget,
        );
        expect(find.text('unit-1-lettres'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('home-offline-packs-card')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '6. Accessibilité : thèmes clair/sombre, petits écrans (320x568 & 360x800), TextScaler 1.3x, cibles >= 48dp et disableAnimations',
      (tester) async {
        for (final size in const [Size(320, 568), Size(360, 800)]) {
          for (final theme in [AppTheme.darkTheme(), AppTheme.lightTheme()]) {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;

            await tester.pumpWidget(
              _wrapHome(
                theme: theme,
                textScale: 1.3,
                disableAnimations: true,
                child: HomeScreen(
                  contentService: _FakeOfflineContentService(
                    themes: _buildSampleThemes(),
                  ),
                  initialThemes: _buildSampleThemes(),
                  enablePreload: false,
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);

            final ctaSize = tester.getSize(
              find.byKey(const ValueKey('home-continue-learning-cta')),
            );
            expect(ctaSize.height, greaterThanOrEqualTo(48.0));

            final offlineBtnSize = tester.getSize(
              find.byKey(const ValueKey('home-offline-packs-cta')),
            );
            expect(offlineBtnSize.height, greaterThanOrEqualTo(48.0));
          }
        }
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      },
    );
  });
}
