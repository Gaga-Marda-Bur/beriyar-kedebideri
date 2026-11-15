import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/editor/screens/beriya_editor_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildEditorTestApp({double textScale = 1.0}) {
  return MaterialApp(
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
    builder: (context, child) {
      final mediaQuery = MediaQuery.of(context);
      return MediaQuery(
        data: mediaQuery.copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      );
    },
    home: const BeriyaEditorScreen(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpAndVerifyNoOverflow(
    WidgetTester tester, {
    required Size screenSize,
    required double textScale,
  }) async {
    final errors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = 1.0;

    FlutterError.onError = (details) {
      errors.add(details);
    };
    try {
      await tester.pumpWidget(_buildEditorTestApp(textScale: textScale));
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previousOnError;
    }

    expect(
      errors,
      isEmpty,
      reason:
          'Expected no layout/overflow errors at $screenSize with textScale=$textScale, got: ${errors.map((e) => e.exceptionAsString()).join('\n')}',
    );
    expect(find.text('Éditeur Beriya'), findsOneWidget);
    expect(find.text('Brouillon enregistré'), findsOneWidget);
  }

  testWidgets('AppBar does not overflow on small Android screen (320x640)',
      (tester) async {
    await pumpAndVerifyNoOverflow(
      tester,
      screenSize: const Size(320, 640),
      textScale: 1.0,
    );
  });

  testWidgets(
      'AppBar does not overflow on 360x720 with increased font size (1.6x and 2.0x)',
      (tester) async {
    await pumpAndVerifyNoOverflow(
      tester,
      screenSize: const Size(360, 720),
      textScale: 1.6,
    );
    await pumpAndVerifyNoOverflow(
      tester,
      screenSize: const Size(360, 720),
      textScale: 2.0,
    );
  });

  testWidgets('Secondary editor actions remain accessible via PopupMenuButton',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_buildEditorTestApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.ios_share_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('editor-more-actions')));
    await tester.pumpAndSettle();

    expect(find.text('Erfe | Latin | Arabe'), findsOneWidget);
    expect(find.text('Copier le texte'), findsOneWidget);
    expect(find.text('Nouveau document'), findsOneWidget);
  });
}
