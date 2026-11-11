import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/app/app_state.dart';
import 'package:mobile/core/cache/cached_content_service.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/content_hub/screens/content_hub_screen.dart';
import 'package:mobile/features/editor/screens/beriya_editor_screen.dart';
import 'package:mobile/features/home/screens/home_screen.dart';
import 'package:mobile/features/learning/models/learning_theme_model.dart';
import 'package:mobile/features/learning/models/learning_unit_model.dart';
import 'package:mobile/features/no_ena/screens/no_ena_screen.dart';
import 'package:mobile/features/settings/screens/settings_screen.dart';
import 'package:mobile/features/sticker_studio/presentation/sticker_studio_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';

class _FakeContentService extends CachedContentService {
  @override
  Future<List<LearningThemeModel>> loadThemes({bool forceRefresh = false}) async {
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
        'units_count': 1,
        'units': [],
      }),
    ];
  }

  @override
  Future<List<LearningUnitModel>> loadUnits({
    String? themeSlug,
    bool forceRefresh = false,
  }) async {
    return [];
  }
}

Widget _buildTestApp({Widget? home, String? initialRoute}) {
  return ChangeNotifierProvider<AppState>(
    create: (_) => AppState(),
    child: MaterialApp(
      theme: AppTheme.darkTheme(),
      locale: const Locale('fr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('ar'),
      ],
      initialRoute: initialRoute,
      routes: {
        '/': (_) => home ?? HomeScreen(
              contentService: _FakeContentService(),
              enablePreload: false,
            ),
        '/content': (_) => const ContentHubScreen(),
        '/no-ena': (_) => const NoEnaScreen(),
        '/sticker-studio': (_) => const StickerStudioScreen(),
        '/editor': (_) => const BeriyaEditorScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Restauration des outils historiques - Tests Flutter', () {
    testWidgets('1. Section Outils & Création visible avec les 3 accès directs', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      // Vérifier la présence de la section Outils & Création
      expect(find.byKey(const ValueKey('home-tools-creation-section')), findsOneWidget);

      // Vérifier les 3 cartes d'accès direct
      expect(find.byKey(const ValueKey('home-tool-no-ena')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-tool-sticker-studio')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-tool-editor')), findsOneWidget);

      // Vérifier le bouton "Tout voir" vers le hub
      expect(find.byKey(const ValueKey('home-tools-view-all-button')), findsOneWidget);
    });

    testWidgets('2. Simple tap sur No Ena ouvre NoEnaScreen', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final noEnaTile = find.byKey(const ValueKey('home-tool-no-ena'));
      await tester.ensureVisible(noEnaTile);
      await tester.tap(noEnaTile);
      await tester.pumpAndSettle();

      expect(find.byType(NoEnaScreen), findsOneWidget);
    });

    testWidgets('3. Simple tap sur Studio Sticker ouvre StickerStudioScreen', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final stickerTile = find.byKey(const ValueKey('home-tool-sticker-studio'));
      await tester.ensureVisible(stickerTile);
      await tester.tap(stickerTile);
      await tester.pumpAndSettle();

      expect(find.byType(StickerStudioScreen), findsOneWidget);
    });

    testWidgets('4. Simple tap sur Éditeur Beriya ouvre BeriyaEditorScreen', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final editorTile = find.byKey(const ValueKey('home-tool-editor'));
      await tester.ensureVisible(editorTile);
      await tester.tap(editorTile);
      await tester.pumpAndSettle();

      expect(find.byType(BeriyaEditorScreen), findsOneWidget);
    });

    testWidgets('5. Bouton Tout voir ouvre ContentHubScreen', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final hubBtn = find.byKey(const ValueKey('home-tools-view-all-button'));
      await tester.ensureVisible(hubBtn);
      await tester.tap(hubBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ContentHubScreen), findsOneWidget);
    });

    testWidgets('6. Pas de navigation cachée sur appui long du bouton Profil & réglages', (tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final profileFinder = find.byKey(const ValueKey('home-secondary-profile'));
      await tester.scrollUntilVisible(
        profileFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(profileFinder, findsOneWidget);

      await tester.longPress(profileFinder);
      await tester.pumpAndSettle();

      // Ne doit PAS ouvrir ContentHubScreen
      expect(find.byType(ContentHubScreen), findsNothing);
    });

    testWidgets('7. Route /sticker-studio ouvre StickerStudioScreen', (tester) async {
      await tester.pumpWidget(_buildTestApp(initialRoute: '/sticker-studio'));
      await tester.pumpAndSettle();
      expect(find.byType(StickerStudioScreen), findsOneWidget);
    });

    testWidgets('8. Route /editor ouvre BeriyaEditorScreen', (tester) async {
      await tester.pumpWidget(_buildTestApp(initialRoute: '/editor'));
      await tester.pumpAndSettle();
      expect(find.byType(BeriyaEditorScreen), findsOneWidget);
    });
  });
}
