import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/editor/models/beriya_draft.dart';
import 'package:mobile/features/editor/services/beriya_pdf_service.dart';
import 'package:mobile/shared/beriya/beriya_chars.dart';
import 'package:mobile/shared/beriya/erfe_input_formatter.dart';
import 'package:mobile/shared/beriya/transliteration.dart';
import 'package:mobile/shared/beriya/transliteration_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final reference =
      jsonDecode(
            File(
              '../shared/linguistics/beriya_erfe_transliteration_mapping.json',
            ).readAsStringSync(),
          )
          as Map;
  final forms = reference['diacritic_letters'] as List;
  const capture = bool.fromEnvironment('BK_CAPTURE_DIACRITICS');
  final output = Directory('../docs/transliteration_diacritics');

  test('16 diacritic forms round-trip and generated keyboard options', () {
    expect(forms.length, 16);
    final options = BeriyaChars.longPressOptions.entries
        .where((e) => e.key.runes.first >= 0x16EA0)
        .expand((e) => e.value)
        .toSet();
    expect(options, forms.map((r) => r['erfe']).toSet());
    for (final r in forms) {
      final latin = transliterate(
        r['erfe_lower_alias'] as String,
        WritingScript.erfe,
        WritingScript.latin,
      );
      expect(latin.text, r['latin_upper']);
      expect(
        transliterate(latin.text, WritingScript.latin, WritingScript.erfe).text,
        r['erfe'],
      );
      for (final script in [WritingScript.erfe, WritingScript.latin]) {
        final original =
            r[script == WritingScript.erfe ? 'erfe' : 'latin_upper'] as String;
        final result = transliterate(original, script, WritingScript.arabic);
        expect(result.text, original);
        expect(result.unmapped.single['reason'], 'missing_arabic_mapping');
      }
    }
  });
  test(
    'paste accents retains UTF16 selection and newlines; Latin NFD becomes NFC',
    () {
      const formatter = ErfeInputFormatter();
      const input = TextEditingValue(
        text: '𖺻́𖺾̀𖻂̄\n',
        selection: TextSelection(baseOffset: 3, extentOffset: 9),
      );
      final result = formatter.formatEditUpdate(TextEditingValue.empty, input);
      expect(result.text, '𖺠́𖺣̀𖺧̄\n');
      expect(result.selection, input.selection);
      final nfd = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: 'A\u0302I\u0323',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );
      expect(nfd.text, 'ÂỊ');
      expect(nfd.selection.extentOffset, 2);
    },
  );
  test('PDF export with all 16 lower Erfe forms and Latin accents', () async {
    final content = forms
        .map(
          (r) =>
              '${r['erfe_lower_alias']} / ${r['latin_upper']} ${r['latin_lower']}',
        )
        .join('\n');
    final bytes = await BeriyaPdfService.generatePdfBytes(
      BeriyaDraft.initial().copyWith(
        title: 'Diacritiques - QA 𖺧̇ 𖺠́',
        content: content,
      ),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    if (capture) {
      await File('${output.path}/flutter_diacritics.pdf').writeAsBytes(bytes);
    }
  });
  testWidgets(
    'conversion warns about missing Arabic, retains accents and original input',
    (tester) async {
      final controller = TextEditingController(text: 'ÁÈÎ');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTransliterationDialog(context, controller),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<WritingScript>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Latin').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<WritingScript>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arabe').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Convertir'));
      await tester.pumpAndSettle();
      expect(
        (tester.widget(find.byKey(const Key('conversion-output'))) as TextField)
            .controller!
            .text,
        'ÁÈÎ',
      );
      expect(
        find.textContaining('correspondances arabes non définies'),
        findsOneWidget,
      );
      expect(controller.text, 'ÁÈÎ');
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      controller.dispose();
    },
  );
  testWidgets('actual font rendering of 16 forms and PNG encoding', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await (FontLoader('Kedebideri')
            ..addFont(rootBundle.load('assets/fonts/Kedebideri-Regular.ttf')))
          .load();
      await (FontLoader(
        'Noto Sans',
      )..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
    });
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xfff6f3e8),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Erfe / Latin - 16 formes',
                    style: TextStyle(fontFamily: 'Noto Sans', fontSize: 24),
                  ),
                  for (final r in forms)
                    Text(
                      '${r['erfe']}     ${r['latin_upper']} ${r['latin_lower']}',
                      style: const TextStyle(
                        fontFamily: 'Kedebideri',
                        fontFamilyFallback: ['Noto Sans'],
                        fontSize: 24,
                        height: 1.25,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final png = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      expect(png.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
      if (capture) {
        await File('${output.path}/flutter_diacritics.png').writeAsBytes(png);
      }
      image.dispose();
    });
  });
}
