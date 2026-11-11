import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/editor/models/beriya_draft.dart';
import 'package:mobile/features/editor/screens/beriya_editor_screen.dart';
import 'package:mobile/features/editor/services/beriya_draft_storage.dart';
import 'package:mobile/features/editor/services/beriya_pdf_service.dart';
import 'package:mobile/features/no_ena/screens/no_ena_screen.dart';
import 'package:mobile/features/sticker_studio/presentation/sticker_studio_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Test physique isole des outils historiques Samsung', (tester) async {
    expect(const bool.fromEnvironment('BK_TOOLS_QA'), isTrue);

    final extDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final outDir = Directory('${extDir.path}/qa_tools_captures');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      final boundary = tester.renderObject(find.byKey(const Key('qa-tools-root'))) as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File('${outDir.path}/$name.png');
      await file.writeAsBytes(bytes);
      debugPrint('BK_QA_CAPTURE:${file.path}');
    }

    Widget wrap(Widget child) {
      return RepaintBoundary(
        key: const Key('qa-tools-root'),
        child: MaterialApp(
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr'), Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.darkTheme(),
          home: child,
        ),
      );
    }

    // 1. Tester No Ena
    debugPrint('BK_QA_STEP:NoEna');
    await tester.pumpWidget(wrap(const NoEnaScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(NoEnaScreen), findsOneWidget);
    await capture('samsung_no_ena_dark');

    // 2. Tester Studio Sticker
    debugPrint('BK_QA_STEP:StudioSticker');
    await tester.pumpWidget(wrap(const StickerStudioScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(StickerStudioScreen), findsOneWidget);
    await capture('samsung_sticker_studio_dark');

    // 3. Tester Beriya Editor & Brouillons & PDF
    debugPrint('BK_QA_STEP:BeriyaEditor');
    await tester.pumpWidget(wrap(const BeriyaEditorScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(BeriyaEditorScreen), findsOneWidget);
    await capture('samsung_editor_dark');

    // Vérifier persistance brouillon et génération PDF sur l'appareil
    final testDraft = BeriyaDraft(
      id: 'qa_samsung_1',
      title: 'Titre Test Samsung 𖺡𖺵',
      content: 'Texte en Erfe 𖺠𖺡𖺢𖺣𖺤 pour validation physique',
      updatedAt: DateTime.now(),
    );
    await BeriyaDraftStorage.saveDraft(testDraft);
    final loaded = await BeriyaDraftStorage.loadActiveDraft();
    expect(loaded.title, 'Titre Test Samsung 𖺡𖺵');
    expect(loaded.content, contains('𖺠𖺡𖺢'));

    // Génération PDF sur Samsung
    final pdfBytes = await BeriyaPdfService.generatePdfBytes(testDraft);
    expect(pdfBytes.length, greaterThan(100));
    final pdfFile = File('${outDir.path}/samsung_test_draft.pdf');
    await pdfFile.writeAsBytes(pdfBytes);
    debugPrint('BK_QA_PDF:${pdfFile.path}:${pdfBytes.length}');

    // Nettoyage brouillon de test
    await BeriyaDraftStorage.clearActiveDraft();
    debugPrint('BK_QA_STATUS:SUCCESS_ALL_HISTORICAL_TOOLS');
  });
}
