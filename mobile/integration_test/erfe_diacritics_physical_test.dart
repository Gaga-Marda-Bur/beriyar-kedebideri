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
import 'package:mobile/features/no_ena/screens/no_ena_screen.dart';
import 'package:mobile/features/sticker_studio/presentation/sticker_studio_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mobile/shared/beriya/beriya_chars.dart';
import 'package:mobile/shared/beriya/erfe_input_formatter.dart';
import 'package:mobile/shared/beriya/transliteration.dart';
import 'package:mobile/shared/beriya/transliteration_dialog.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QA physique des 16 diacritiques Erfe sur Samsung SM-A336E', (tester) async {
    // -------------------------------------------------------------------------
    // 0. Garde-fou environnement QA isolé
    // -------------------------------------------------------------------------
    expect(const bool.fromEnvironment('BK_TOOLS_QA'), isTrue);

    final outDir = Directory('/sdcard/Download/qa_diacritics_proofs');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      final boundary = tester.renderObject(find.byKey(const Key('qa-root'))) as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File('${outDir.path}/$name.png');
      await file.writeAsBytes(bytes);
      debugPrint('BK_QA_PROOF_PNG:${file.path}:${bytes.length}');
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
    // 1. Clavier et translittération des 16 formes diacritiques
    // =========================================================================
    debugPrint('QA_SECTION:1_TRANSLITERATION_16_FORMS');

    // Les 16 correspondances officielles validées
    final validatedForms = [
      {'latin_upper': 'Ị', 'latin_lower': 'ị', 'erfe': '𖺧̇', 'erfe_lower': '𖻂̇', 'name': 'I_dot_above'},
      {'latin_upper': 'Î', 'latin_lower': 'î', 'erfe': '𖺧̄', 'erfe_lower': '𖻂̄', 'name': 'I_macron'},
      {'latin_upper': 'Û', 'latin_lower': 'û', 'erfe': '𖺶̄', 'erfe_lower': '𖻑̄', 'name': 'U_macron'},
      {'latin_upper': 'Ô', 'latin_lower': 'ô', 'erfe': '𖺯̄', 'erfe_lower': '𖻊̄', 'name': 'O_macron'},
      {'latin_upper': 'Â', 'latin_lower': 'â', 'erfe': '𖺠̄', 'erfe_lower': '𖺻̄', 'name': 'A_macron'},
      {'latin_upper': 'Ê', 'latin_lower': 'ê', 'erfe': '𖺣̄', 'erfe_lower': '𖺾̄', 'name': 'E_macron'},
      {'latin_upper': 'À', 'latin_lower': 'à', 'erfe': '𖺠̀', 'erfe_lower': '𖺻̀', 'name': 'A_grave'},
      {'latin_upper': 'Á', 'latin_lower': 'á', 'erfe': '𖺠́', 'erfe_lower': '𖺻́', 'name': 'A_acute'},
      {'latin_upper': 'È', 'latin_lower': 'è', 'erfe': '𖺣̀', 'erfe_lower': '𖺾̀', 'name': 'E_grave'},
      {'latin_upper': 'É', 'latin_lower': 'é', 'erfe': '𖺣́', 'erfe_lower': '𖺾́', 'name': 'E_acute'},
      {'latin_upper': 'Ì', 'latin_lower': 'ì', 'erfe': '𖺧̀', 'erfe_lower': '𖻂̀', 'name': 'I_grave'},
      {'latin_upper': 'Í', 'latin_lower': 'í', 'erfe': '𖺧́', 'erfe_lower': '𖻂́', 'name': 'I_acute'},
      {'latin_upper': 'Ù', 'latin_lower': 'ù', 'erfe': '𖺶̀', 'erfe_lower': '𖻑̀', 'name': 'U_grave'},
      {'latin_upper': 'Ú', 'latin_lower': 'ú', 'erfe': '𖺶́', 'erfe_lower': '𖻑́', 'name': 'U_acute'},
      {'latin_upper': 'Ò', 'latin_lower': 'ò', 'erfe': '𖺯̀', 'erfe_lower': '𖻊̀', 'name': 'O_grave'},
      {'latin_upper': 'Ó', 'latin_lower': 'ó', 'erfe': '𖺯́', 'erfe_lower': '𖻊́', 'name': 'O_acute'},
    ];

    expect(validatedForms.length, 16);

    // Test A : Aller-retour Latin <-> Erfe pour chaque forme
    for (final row in validatedForms) {
      final latinUpper = row['latin_upper']!;
      final latinLower = row['latin_lower']!;
      final erfeUpper = row['erfe']!;
      final erfeLower = row['erfe_lower']!;

      // Latin majuscule -> Erfe
      final toErfeFromUpper = transliterate(latinUpper, WritingScript.latin, WritingScript.erfe);
      expect(toErfeFromUpper.text, erfeUpper, reason: 'Failed Latin Upper -> Erfe for $latinUpper');

      // Latin minuscule -> Erfe
      final toErfeFromLower = transliterate(latinLower, WritingScript.latin, WritingScript.erfe);
      expect(toErfeFromLower.text, erfeUpper, reason: 'Failed Latin Lower -> Erfe for $latinLower');

      // Erfe majuscule -> Latin majuscule
      final toLatinFromUpper = transliterate(erfeUpper, WritingScript.erfe, WritingScript.latin);
      expect(toLatinFromUpper.text, latinUpper, reason: 'Failed Erfe Upper -> Latin for $erfeUpper');

      // Erfe minuscule -> Latin majuscule (normalisation canonique)
      final toLatinFromLower = transliterate(erfeLower, WritingScript.erfe, WritingScript.latin);
      expect(toLatinFromLower.text, latinUpper, reason: 'Failed Erfe Lower -> Latin for $erfeLower');

      // Erfe minuscule avec diacritique -> Erfe majuscule avec diacritique
      final normalizedErfe = normalizeErfe(erfeLower);
      expect(normalizedErfe, erfeUpper, reason: 'Failed normalizeErfe for $erfeLower');
    }

    // Test B : Cas spécifiques demandés par le protocole
    // ÁÈÎ <-> 𖺠́𖺣̀𖺧̄
    final sampleAeiLatin = 'ÁÈÎ';
    final sampleAeiErfe = '𖺠́𖺣̀𖺧̄';
    expect(transliterate(sampleAeiLatin, WritingScript.latin, WritingScript.erfe).text, sampleAeiErfe);
    expect(transliterate(sampleAeiErfe, WritingScript.erfe, WritingScript.latin).text, sampleAeiLatin);

    // Ó <-> 𖺯́
    expect(transliterate('Ó', WritingScript.latin, WritingScript.erfe).text, '𖺯́');
    expect(transliterate('𖺯́', WritingScript.erfe, WritingScript.latin).text, 'Ó');
    // Normalisation depuis minuscule 𖻊́ -> 𖺯́
    expect(normalizeErfe('𖻊́'), '𖺯́');

    // Ị <-> 𖺧̇ (correspondance provisoire avec U+0307 point dessus)
    expect(transliterate('Ị', WritingScript.latin, WritingScript.erfe).text, '𖺧̇');
    expect(transliterate('𖺧̇', WritingScript.erfe, WritingScript.latin).text, 'Ị');
    expect(transliterate('ị', WritingScript.latin, WritingScript.erfe).text, '𖺧̇');

    // Test C : Gestion NFC et NFD
    // 'Á' en NFD (A + U+0301) -> 𖺠́
    final nfdA = 'A\u0301';
    expect(transliterate(nfdA, WritingScript.latin, WritingScript.erfe).text, '𖺠́');

    // 'Ị' en NFD (I + U+0323 dot below) -> 𖺧̇
    final nfdI = 'I\u0323';
    expect(transliterate(nfdI, WritingScript.latin, WritingScript.erfe).text, '𖺧̇');

    // 'Â' en NFD (A + U+0302 circumflex) -> 𖺠̄
    final nfdCircumflex = 'A\u0302';
    expect(transliterate(nfdCircumflex, WritingScript.latin, WritingScript.erfe).text, '𖺠̄');

    // Test D : ErfeInputFormatter (collage externe et préservation des retours à la ligne)
    const formatter = ErfeInputFormatter();
    const pasteInput = TextEditingValue(
      text: '𖺻́𖺾̀𖻂̄\nTexte 123',
      selection: TextSelection(baseOffset: 3, extentOffset: 9),
    );
    final pasteResult = formatter.formatEditUpdate(TextEditingValue.empty, pasteInput);
    expect(pasteResult.text, '𖺠́𖺣̀𖺧̄\nTexte 123');
    expect(pasteResult.selection, pasteInput.selection);

    // Test E : Préservation des accents lors de l'édition
    // Insertion avant et après sans corrompre le signe combinant
    final baseAccented = '𖺠́';
    final editedText = 'Avant $baseAccented Après';
    expect(editedText.contains('𖺠́'), isTrue);
    final editedTranslit = transliterate(editedText, WritingScript.erfe, WritingScript.latin);
    expect(editedTranslit.text, 'Avant Á Après');

    // Test F : Options du clavier pour chaque voyelle de base
    final allKeyboardDiacritics = BeriyaChars.longPressOptions.entries
        .where((e) => e.key.runes.first >= 0x16EA0 && e.key.runes.first <= 0x16EB8)
        .expand((e) => e.value)
        .toSet();
    for (final row in validatedForms) {
      expect(allKeyboardDiacritics.contains(row['erfe']), isTrue,
          reason: 'Keyboard missing diacritic ${row['erfe']} for ${row['latin_upper']}');
    }

    // =========================================================================
    // 2. Gestion de l'Arabe (préservation des accents, absence de suppression)
    // =========================================================================
    debugPrint('QA_SECTION:2_ARABIC_FALLBACK');

    // Vérifier que chaque forme accentuée vers l'arabe :
    // - Conserve son texte sans suppression d'accents
    // - Signale 'missing_arabic_mapping'
    for (final row in validatedForms) {
      final erfeForm = row['erfe']!;
      final latinForm = row['latin_upper']!;
      final arabicForm = row['arabic']!;

      final erfeToArabic = transliterate(erfeForm, WritingScript.erfe, WritingScript.arabic);
      expect(erfeToArabic.text, arabicForm);
      expect(erfeToArabic.unmapped, isEmpty);

      final latinToArabic = transliterate(latinForm, WritingScript.latin, WritingScript.arabic);
      expect(latinToArabic.text, arabicForm);
      expect(latinToArabic.unmapped, isEmpty);
    }

    // Test mixte Arabe avec lettres simples et lettres accentuées
    final mixedTranslit = transliterate('BÁ D', WritingScript.latin, WritingScript.arabic);
    expect(mixedTranslit.text, 'ب\u0627\u0301 د');

    // Test interactif : boîte de dialogue de translittération
    final dialogController = TextEditingController(text: 'ÁÈÎ 𖺯́ 𖺧̇');
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: Center(
            child: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open-translit-btn'),
                onPressed: () => showTransliterationDialog(ctx, dialogController),
                child: const Text('Ouvrir dialogue'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Ouvrir le dialogue
    await tester.tap(find.byKey(const Key('open-translit-btn')));
    await tester.pumpAndSettle();

    // Sélectionner Latin -> Arabe
    final dropdowns = find.byType(DropdownButton<WritingScript>);
    expect(dropdowns, findsNWidgets(2));

    await tester.tap(dropdowns.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Latin').last);
    await tester.pumpAndSettle();

    await tester.tap(dropdowns.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arabe').last);
    await tester.pumpAndSettle();

    // Taper sur Convertir
    await tester.tap(find.text('Convertir'));
    await tester.pumpAndSettle();

    // Vérifier l'avertissement de conversion incomplète dans l'interface
    expect(find.textContaining('correspondances arabes non définies'), findsOneWidget);

    // Capture de l'avertissement arabe sur le Samsung physique
    await capture('samsung_transliteration_arabic_warning');

    // Fermer le dialogue
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();

    // =========================================================================
    // 3. Studio Sticker — Saisie avec diacritiques, styles, capture PNG
    // =========================================================================
    debugPrint('QA_SECTION:3_STUDIO_STICKER_DIACRITICS');

    await tester.pumpWidget(wrap(const StickerStudioScreen()));
    await tester.pumpAndSettle();

    // Saisie de caractères Erfe accentués
    final stickerTextField = find.byType(TextField);
    expect(stickerTextField, findsOneWidget);
    await tester.enterText(stickerTextField, '𖺠́𖺣̀𖺧̄ 𖺯́ 𖺧̇');
    await tester.pumpAndSettle();

    // Sélectionner un style (Culture ou Calligraphie)
    final styleChip = find.text('Culture');
    if (styleChip.evaluate().isNotEmpty) {
      await tester.tap(styleChip);
      await tester.pumpAndSettle();
    }

    // Capture de la composition Studio Sticker
    await capture('samsung_sticker_diacritics_composed');

    // Génération et sauvegarde d'un sticker PNG isolé
    final stickerRenderKey = GlobalKey();
    await tester.pumpWidget(
      wrap(
        Scaffold(
          backgroundColor: const Color(0xFF1E1E1E),
          body: Center(
            child: RepaintBoundary(
              key: stickerRenderKey,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2416),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD4AF37), width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'BERIYAR STICKER',
                      style: TextStyle(
                        fontFamily: 'Noto Sans',
                        color: Color(0xFFD4AF37),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '𖺠́𖺣̀𖺧̄ 𖺯́ 𖺧̇',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Kedebideri',
                        fontFamilyFallback: ['Noto Sans'],
                        color: Colors.white,
                        fontSize: 42,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Á È Î  Ó  Ị',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Noto Sans',
                        color: Color(0xFFD4AF37),
                        fontSize: 18,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Rendu en image PNG
    final stickerBoundary = stickerRenderKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final stickerImage = await stickerBoundary.toImage(pixelRatio: 3.0);
    final stickerByteData = await stickerImage.toByteData(format: ui.ImageByteFormat.png);
    final stickerPngBytes = stickerByteData!.buffer.asUint8List();

    // Vérifier en-tête PNG
    expect(stickerPngBytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(stickerPngBytes.length, greaterThan(1500));

    final stickerFile = File('${outDir.path}/samsung_sticker_diacritics.png');
    await stickerFile.writeAsBytes(stickerPngBytes);
    debugPrint('BK_QA_PROOF_STICKER_PNG:${stickerFile.path}:${stickerPngBytes.length}');

    // =========================================================================
    // 4. Beriya Erfe Editor — Brouillon persistant & Export PDF réel avec 16 diacritiques
    // =========================================================================
    debugPrint('QA_SECTION:4_BERIYA_EDITOR_DIACRITICS');

    final editorContent = validatedForms
        .map((f) => '${f['erfe']} / ${f['latin_upper']} ${f['latin_lower']} (${f['name']})')
        .join('\n');

    final sampleDraft = BeriyaDraft(
      id: 'qa_diacritics_samsung_draft',
      title: 'QA Diacritiques 𖺠́𖺣̀𖺧̄ 𖺯́ 𖺧̇',
      content: '16 FORMES DIACRITIQUES ERFE :\n$editorContent\nPhrase test : 𖺠́𖺣̀𖺧̄ 𖺯́ 𖺧̇',
      theme: 'golden',
      fontSize: 24.0,
      alignment: 'left',
      updatedAt: DateTime.now(),
    );

    // Sauvegarde persistante
    final saveResult = await BeriyaDraftStorage.saveDraft(sampleDraft);
    expect(saveResult, isTrue);

    // Rechargement immédiat
    final reloadedDraft = await BeriyaDraftStorage.loadActiveDraft();
    expect(reloadedDraft.title, sampleDraft.title);
    expect(reloadedDraft.content, sampleDraft.content);
    expect(reloadedDraft.theme, 'golden');

    // Affichage dans l'écran de l'éditeur
    await tester.pumpWidget(wrap(const BeriyaEditorScreen()));
    await tester.pumpAndSettle();
    await capture('samsung_editor_diacritics');

    // Export PDF réel avec la police Kedebideri
    final pdfBytes = await BeriyaPdfService.generatePdfBytes(reloadedDraft);
    expect(pdfBytes.length, greaterThan(2000));
    expect(String.fromCharCodes(pdfBytes.take(5)), '%PDF-');

    final pdfFile = File('${outDir.path}/samsung_erfe_diacritics.pdf');
    await pdfFile.writeAsBytes(pdfBytes);
    debugPrint('BK_QA_PROOF_PDF:${pdfFile.path}:${pdfBytes.length}');

    // =========================================================================
    // 5. Rendu haute résolution des 16 glyphes avec Kedebideri
    // =========================================================================
    debugPrint('QA_SECTION:5_FONT_16_FORMS_RENDER');

    final fontRenderKey = GlobalKey();
    await tester.pumpWidget(
      wrap(
        Scaffold(
          backgroundColor: const Color(0xFFF9F7F1),
          body: SingleChildScrollView(
            child: RepaintBoundary(
              key: fontRenderKey,
              child: Container(
                padding: const EdgeInsets.all(24),
                color: const Color(0xFFF9F7F1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BERIYAR ERFE — 16 DIACRITIQUES VALIDÉS',
                      style: TextStyle(
                        fontFamily: 'Noto Sans',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final f in validatedForms)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text(
                                f['erfe']!,
                                style: const TextStyle(
                                  fontFamily: 'Kedebideri',
                                  fontFamilyFallback: ['Noto Sans'],
                                  fontSize: 32,
                                  color: Color(0xFF8B2500),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: Text(
                                '${f['latin_upper']} / ${f['latin_lower']}',
                                style: const TextStyle(
                                  fontFamily: 'Noto Sans',
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E1E1E),
                                ),
                              ),
                            ),
                            Text(
                              f['name']!,
                              style: const TextStyle(
                                fontFamily: 'Noto Sans',
                                fontSize: 16,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fontBoundary = fontRenderKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final fontImage = await fontBoundary.toImage(pixelRatio: 2.0);
    final fontByteData = await fontImage.toByteData(format: ui.ImageByteFormat.png);
    final fontPngBytes = fontByteData!.buffer.asUint8List();

    final fontFile = File('${outDir.path}/samsung_font_16_forms.png');
    await fontFile.writeAsBytes(fontPngBytes);
    debugPrint('BK_QA_PROOF_FONT_PNG:${fontFile.path}:${fontPngBytes.length}');

    // =========================================================================
    // 6. Non-régression : 25 lettres fondamentales & No Ena
    // =========================================================================
    debugPrint('QA_SECTION:6_NON_REGRESSION');

    // Les 25 lettres officielles existent et sont intactes
    expect(BeriyaChars.official.length, 25);
    expect(BeriyaChars.fastRowsOfficialOnly.expand((r) => r).length, 25);

    // Écran No Ena sans crash
    await tester.pumpWidget(wrap(const NoEnaScreen()));
    await tester.pumpAndSettle();
    await capture('samsung_no_ena_check');

    debugPrint('QA_PHYSICAL_DIACRITICS_COMPLETED_SUCCESSFULLY');
  });
}
