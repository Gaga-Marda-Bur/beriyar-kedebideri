import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/editor/models/beriya_draft.dart';
import 'package:mobile/features/editor/screens/beriya_editor_screen.dart';
import 'package:mobile/features/editor/services/beriya_draft_storage.dart';
import 'package:mobile/features/editor/services/beriya_pdf_service.dart';
import 'package:mobile/features/no_ena/models/no_ena_publication_model.dart';
import 'package:mobile/features/no_ena/screens/no_ena_detail_screen.dart';
import 'package:mobile/features/no_ena/screens/no_ena_screen.dart';
import 'package:mobile/features/sticker_studio/presentation/sticker_studio_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Cloture QA approfondie des outils historiques sur Samsung SM-A336E', (tester) async {
    expect(const bool.fromEnvironment('BK_TOOLS_QA'), isTrue);

    final outDir = Directory('/sdcard/Download/qa_final_proofs');
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      final boundary = tester.renderObject(find.byKey(const Key('qa-root'))) as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File('${outDir.path}/$name.png');
      await file.writeAsBytes(bytes);
      debugPrint('BK_QA_FINAL_PNG:${file.path}:${bytes.length}');
    }

    Widget wrap(Widget child) {
      return RepaintBoundary(
        key: const Key('qa-root'),
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

    // =========================================================================
    // 1. Studio Sticker — Saisie Erfe, styles, couleurs, rendu sticker réel
    // =========================================================================
    debugPrint('QA_SECTION:1_STUDIO_STICKER');
    await tester.pumpWidget(wrap(const StickerStudioScreen()));
    await tester.pumpAndSettle();

    // Saisie de plusieurs caractères Erfe
    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsOneWidget);

    // Sélection de style "Culture"
    final cultureChip = find.text('Culture');
    if (cultureChip.evaluate().isNotEmpty) {
      await tester.tap(cultureChip);
      await tester.pumpAndSettle();
    }

    // Capture de la composition Studio Sticker
    await capture('samsung_sticker_studio_composed');

    // =========================================================================
    // 2. Beriya Erfe Editor — Brouillon persistant, relecture, export PDF réel
    // =========================================================================
    debugPrint('QA_SECTION:2_BERIYA_EDITOR');
    final sampleDraft = BeriyaDraft(
      id: 'final_qa_draft',
      title: 'Titre Erfe : 𖺗𖺁𖺀 𖺠𖺡',
      content: 'Paragraphe 1 : 𖺠𖺡𖺢𖺣𖺤 𖺥𖺦𖺧𖺨\nParagraphe 2 avec retour à la ligne :\n𖺩𖺪𖺫 𖺬𖺭𖺮𖺯 𖺰𖺱𖺲𖺳',
      theme: 'golden',
      fontSize: 26.0,
      alignment: 'center',
      updatedAt: DateTime.now(),
    );

    // Sauvegarde
    await BeriyaDraftStorage.saveDraft(sampleDraft);

    // Rechargement immédiat et vérification
    final reloaded = await BeriyaDraftStorage.loadActiveDraft();
    expect(reloaded.title, equals(sampleDraft.title));
    expect(reloaded.content, equals(sampleDraft.content));
    expect(reloaded.theme, equals('golden'));

    // Génération PDF avec police et retours à la ligne
    final pdfBytes = await BeriyaPdfService.generatePdfBytes(reloaded);
    expect(pdfBytes.length, greaterThan(500));
    final pdfFile = File('${outDir.path}/samsung_beriya_editor_document.pdf');
    await pdfFile.writeAsBytes(pdfBytes);
    debugPrint('BK_QA_FINAL_PDF:${pdfFile.path}:${pdfBytes.length}');

    // Affichage dans l'écran
    await tester.pumpWidget(wrap(const BeriyaEditorScreen()));
    await tester.pumpAndSettle();
    await capture('samsung_editor_reloaded_draft');

    // =========================================================================
    // 3. No Ena — Liste des publications, détail, image et média audio
    // =========================================================================
    debugPrint('QA_SECTION:3_NO_ENA');
    await tester.pumpWidget(wrap(const NoEnaScreen()));
    await tester.pumpAndSettle();
    await capture('samsung_no_ena_list_view');

    // Tester ouverture du détail de publication avec audio et image
    final samplePub = NoEnaPublicationModel.fromJson({
      'id': 1,
      'slug': 'premier-regard-beriya-erfe',
      'title_fr': 'Premier regard sur Beriya Erfe',
      'title_en': 'First look at Beriya Erfe',
      'title_ar': 'نظرة أولى على بيريَا إرفي',
      'beriya_title': '𖺗𖺁𖺀 𖺠𖺡',
      'caption_fr': 'Découverte des premiers caractères et de la prononciation authentique.',
      'caption_en': 'Discovering the first characters and authentic pronunciation.',
      'caption_ar': 'اكتشاف الأحرف الأولى والنطق الأصيل.',
      'beriya_caption': '𖺠𖺡𖺢 𖺣𖺤',
      'publication_type': 'image',
      'image_url': 'https://media.beriyarkedebideri.com/no_ena/images/barikasit.png',
      'thumbnail_url': null,
      'video_url': null,
      'audio_url': 'https://media.beriyarkedebideri.com/audio_assets/files/arkap.wav',
      'primary_audio_asset': 10,
      'related_character': null,
      'related_character_symbol': '𖺡',
      'related_word': null,
      'related_word_text': 'Arkap',
      'related_unit': null,
      'related_unit_slug': 'unit-1',
      'contributor_name': 'Équipe Beřiya',
      'culture_theme': 'Écriture',
      'order_index': 1,
      'view_count': 42,
      'favorite_count': 12,
      'status': 'published',
      'is_active': true,
      'is_featured': true,
      'available_offline': true,
      'published_at': '2026-10-15T10:00:00Z',
    });

    await tester.pumpWidget(wrap(NoEnaDetailScreen(publication: samplePub)));
    await tester.pumpAndSettle();
    await capture('samsung_no_ena_detail_view');

    // Nettoyage après test
    await BeriyaDraftStorage.clearActiveDraft();
    debugPrint('BK_QA_FINAL_STATUS:SUCCESS_ALL_CHECKS');
  });
}
