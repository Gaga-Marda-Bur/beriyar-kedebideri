import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:mobile/features/editor/models/beriya_draft.dart';
import 'package:mobile/features/editor/services/arabic_pdf_text.dart';
import 'package:mobile/features/editor/services/beriya_pdf_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const all16Forms = [
    '\u06CC\u0307',
    '\u06CC\u0304',
    '\u06C7\u0304',
    '\u06C6\u0304',
    '\u0627\u0304',
    '\u0622\u0304',
    '\u0627\u0300',
    '\u0627\u0301',
    '\u0622\u0300',
    '\u0622\u0301',
    '\u06CC\u0300',
    '\u06CC\u0301',
    '\u06C7\u0300',
    '\u06C7\u0301',
    '\u06C6\u0300',
    '\u06C6\u0301',
  ];

  const arabic25 =
      '\u0627 \u0628 \u062F \u0622 \u0641 \u0642 \u0647 \u06CC \u062C \u0643 \u0644 \u0645 \u0646 \u06BD \u06A0 \u06C6 \u067E \u0631 \u0695 \u0633 \u0634 \u062A \u06C7 \u0648 \u064A';
  const erfe25 =
      '𖺠 𖺡 𖺢 𖺣 𖺤 𖺥 𖺦 𖺧 𖺨 𖺩 𖺪 𖺫 𖺬 𖺭 𖺮 𖺯 𖺰 𖺱 𖺲 𖺳 𖺴 𖺵 𖺶 𖺷 𖺸';
  const latin25 =
      'a b c d e f g h i j k l m n o p q r s t u v w x y';

  testWidgets('AR-DEVICE-09 QA physique Samsung SM-A336E', (tester) async {
    // Garde-fou environnement QA isolé (applicationId .qa_tools)
    expect(const bool.fromEnvironment('BK_TOOLS_QA'), isTrue);
    expect(BeriyaPdfService.experimentalArabicPdfEnabled, isFalse);

    // Charge la police expérimentale uniquement dans ce harnais QA
    final fontLoader = FontLoader('BeriyaArabicProtoQA')
      ..addFont(
        rootBundle.load(
          'assets/fonts/experimental/BeriyaArabicProto-Regular.ttf',
        ),
      );
    await fontLoader.load();

    final outDir = Directory('/sdcard/Download/qa_ar_device_09_close10');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      final boundary =
          tester.renderObject(find.byKey(const Key('qa-root')))
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final file = File('${outDir.path}/$name.png');
      await file.writeAsBytes(bytes);
      debugPrint('BK_DEVICE09_PNG:${file.path}:${bytes.length}');
    }

    final controller = TextEditingController();

    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('qa-root'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: Scaffold(
            appBar: AppBar(title: const Text('AR-DEVICE-09 QA Isolée')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '16 formes accentuées (BeriyaArabicProtoQA)',
                    style: TextStyle(fontSize: 13, color: Colors.amber),
                  ),
                  const SizedBox(height: 8),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: SelectableText(
                      all16Forms.join('  '),
                      style: const TextStyle(
                        fontFamily: 'BeriyaArabicProtoQA',
                        fontSize: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'RTL multi-clusters & mixte Erfe/Latin/Arabe',
                    style: TextStyle(fontSize: 13, color: Colors.amber),
                  ),
                  const SizedBox(height: 8),
                  const Directionality(
                    textDirection: TextDirection.rtl,
                    child: SelectableText(
                      '\u0628\u0627\u0301\u0628 \u0628\u06CC\u0304\u0628 \u0628\u06C7\u0300\u0628 \u0628\u06C6\u0301\u0628\n'
                      'Beřiya 2026 : \u0627\u0301\u0622\u0300\u06CC\u0304 — 𖺠𖺣𖺧',
                      style: TextStyle(
                        fontFamily: 'BeriyaArabicProtoQA',
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: TextField(
                      key: const Key('qa-rtl-input'),
                      controller: controller,
                      style: const TextStyle(
                        fontFamily: 'BeriyaArabicProtoQA',
                        fontSize: 18,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Test saisie RTL & copier-coller',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Test saisie RTL et copier-coller Unicode
    final sampleClipboard = '${all16Forms.join(' ')} \u0628\u0627\u0301\u0628';
    await Clipboard.setData(ClipboardData(text: sampleClipboard));
    final pasted = await Clipboard.getData(Clipboard.kTextPlain);
    expect(pasted?.text, sampleClipboard);
    await tester.enterText(find.byKey(const Key('qa-rtl-input')), sampleClipboard);
    expect(controller.text, sampleClipboard);

    await capture('screen_16forms_rtl');

    // Génération PDF hors ligne sur Samsung (mode expérimental activé uniquement ici)
    final diag = ArabicPdfDiagnostics();
    final multipageParagraphs = List<String>.generate(
      20,
      (i) =>
          'SYNTH-${i + 1}: \u0628\u0627\u0301\u0628 \u0628\u06CC\u0304\u0628 \u0628\u06C7\u0300\u0628 \u0628\u06C6\u0301\u0628 \u0628\u062A\u062B\u062C \u0639\u063A\u0641\u0642',
    );
    final expDraft = BeriyaDraft(
      id: 'device_09_exp',
      title: 'AR-DEVICE-09 : \u0627\u0301\u0622\u0300\u06CC\u0304',
      content: [
        all16Forms.join(' '),
        arabic25,
        erfe25,
        latin25,
        '',
        'Beřiya 2026 : \u0627\u0301\u0622\u0300\u06CC\u0304 — 𖺠𖺣𖺧 (16)!',
        ...multipageParagraphs,
        '\u06FA \u06B5 \u0627\u0308 \u0628\u0651',
      ].join('\n'),
      fontSize: 16,
      alignment: 'right',
      updatedAt: DateTime(2026, 11, 13),
    );

    final sw = Stopwatch()..start();
    final expPdfBytes = await BeriyaPdfService.generatePdfBytes(
      expDraft,
      useExperimentalArabicPdf: true,
      arabicDiagnostics: diag,
    );
    sw.stop();
    expect(String.fromCharCodes(expPdfBytes.take(4)), '%PDF');
    expect(diag.unsupportedCharacters, containsAll([0x06FA, 0x06B5]));
    expect(diag.unsupportedCombiningMarks, containsAll([0x0308, 0x0651]));

    final expPdfFile = File('${outDir.path}/ar_device_09_samsung.pdf');
    await expPdfFile.writeAsBytes(expPdfBytes);
    debugPrint(
      'BK_DEVICE09_EXP_PDF:${expPdfFile.path}:${expPdfBytes.length}:${sw.elapsedMilliseconds}ms',
    );

    // Export Erfe historique (drapeau désactivé par défaut)
    final histDraft = BeriyaDraft(
      id: 'device_09_hist',
      title: '𖺠́𖺣̀𖺧̄',
      content: '$erfe25\n$latin25',
      updatedAt: DateTime(2026, 11, 13),
    );
    final histPdfBytes = await BeriyaPdfService.generatePdfBytes(histDraft);
    expect(String.fromCharCodes(histPdfBytes.take(4)), '%PDF');
    final histPdfFile = File('${outDir.path}/ar_device_09_historical_erfe.pdf');
    await histPdfFile.writeAsBytes(histPdfBytes);
    debugPrint(
      'BK_DEVICE09_HIST_PDF:${histPdfFile.path}:${histPdfBytes.length}',
    );
  });
}
