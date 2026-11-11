import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/sticker_studio/presentation/sticker_studio_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';

Widget _buildStickerStudioApp() {
  return MaterialApp(
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
    home: const StickerStudioScreen(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Studio Sticker Tests', () {
    testWidgets('StickerStudioScreen se monte avec son apercu et ses contrôles', (tester) async {
      await tester.pumpWidget(_buildStickerStudioApp());
      await tester.pumpAndSettle();

      expect(find.byType(StickerStudioScreen), findsOneWidget);
      expect(find.text('Studio Sticker'), findsOneWidget);

      // Vérifier le champ texte initial
      expect(find.byType(TextField), findsOneWidget);

      // Vérifier les styles de stickers
      expect(find.text('Classique'), findsOneWidget);

      // Faire défiler pour afficher les actions d'exportation
      final downloadFinder = find.byIcon(Icons.download_rounded);
      await tester.scrollUntilVisible(
        downloadFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(downloadFinder, findsOneWidget);
    });
  });
}
