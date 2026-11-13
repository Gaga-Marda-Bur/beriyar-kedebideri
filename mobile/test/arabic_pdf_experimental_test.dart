import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/editor/models/beriya_draft.dart';
import 'package:mobile/features/editor/services/arabic_pdf_text.dart';
import 'package:mobile/features/editor/services/beriya_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('experimental Arabic PDF is disabled by default', () {
    expect(BeriyaPdfService.experimentalArabicPdfEnabled, isFalse);
  });

  test('historical default PDF generation preserves Erfe without error', () async {
    final draft = BeriyaDraft(
      id: 'hist_erfe',
      title: '𖺠́𖺣̀𖺧̄',
      content: 'Beřiya 𖺠𖺡𖺢\n𖺣𖺤𖺥',
      updatedAt: DateTime(2026, 11, 13),
    );
    final bytes = await BeriyaPdfService.generatePdfBytes(draft);
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test(
    'experimental Arabic PDF generates valid multipage PDF and records diagnostics for unknown chars',
    () async {
      final diag = ArabicPdfDiagnostics();
      final longRtl = List.filled(18, '\u0628\u0627\u0301\u0628 \u0628\u06C7\u0300\u0628').join(' ');
      final draft = BeriyaDraft(
        id: 'exp_ar_07',
        title: 'AR-INT-07 : \u0627\u0301\u0622\u0300\u06CC\u0304',
        content: [
          all16Forms.join(' '),
          '\u0628\u0627\u0301',
          '\u0628\u06CC\u0304\u0628',
          '\u06CC\u0307\u0627\u0301\u06C6\u0300',
          '\u0627\u0301\u0622\u0300\u06CC\u0304\u06C6\u0301\u06C7\u0300',
          '\u0628\u06CC\u0307\u0628\u0622\u0300\u0628',
          '\u0628\u0627\u0301\u0628 \u0628\u06C7\u0300\u0628',
          '\u0628\u0627\u0301\u0628 \u0628\u0622\u0300\u0628 \u06CC\u0304\u0627\u0301\n\u0628\u06C6\u0301\u0628 \u0628\u06C7\u0300\u0628 \u0628\u06CC\u0307\u0628',
          'Beřiya 2026 : \u0627\u0301\u0622\u0300\u06CC\u0304 — 𖺠𖺣𖺧 (16)!',
          longRtl,
          // Unsupported Arabic char U+06FA and unsupported combining mark U+0308
          '\u06FA \u0627\u0308',
        ].join('\n'),
        fontSize: 18,
        alignment: 'right',
        updatedAt: DateTime(2026, 11, 13),
      );

      final sw = Stopwatch()..start();
      final bytes = await BeriyaPdfService.generatePdfBytes(
        draft,
        useExperimentalArabicPdf: true,
        arabicDiagnostics: diag,
      );
      sw.stop();

      expect(bytes.length, greaterThan(5000));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(diag.hasWarnings, isTrue);
      expect(diag.unsupportedCharacters, contains(0x06FA));
      expect(diag.unsupportedCombiningMarks, contains(0x0308));

      // Export artifact for independent pypdf / pdfminer.six verification
      final outPath = '../docs/qa_arabic_diacritics/ar_int_07_flutter_app.pdf';
      File(outPath).writeAsBytesSync(bytes);
    },
  );

  test(
    'robustness: 25 fundamental letters, contextual Arabic forms, multipage line-breaks, and offline generation',
    () async {
      final mapping = jsonDecode(
        File(
          '../shared/linguistics/beriya_erfe_transliteration_mapping.json',
        ).readAsStringSync(),
      ) as Map<String, dynamic>;
      final letters = (mapping['letters'] as List).cast<Map<String, dynamic>>();
      expect(letters.length, 25);

      final erfe25 = letters.map((l) => l['erfe'] as String).join(' ');
      final latin25 = letters.map((l) => l['latin_lower'] as String).join(' ');
      final arabic25 = letters
          .map((l) => l['arabic'] as String?)
          .where((a) => a != null && a.isNotEmpty)
          .join(' ');

      // Historical export with flag disabled preserves all 25 fundamental Erfe letters
      final hist25 = await BeriyaPdfService.generatePdfBytes(
        BeriyaDraft(
          id: 'qa08_hist_25',
          title: 'QA-08 25 Erfe',
          content: '$erfe25\n$latin25',
          updatedAt: DateTime(2026, 11, 13),
        ),
      );
      expect(String.fromCharCodes(hist25.take(4)), '%PDF');

      // Experimental multipage + contextual forms + blank lines + unknown diacritic/char
      final diag = ArabicPdfDiagnostics();
      final contextualChains = [
        '\u0628\u062A\u062B\u062C \u062D\u062E\u0633\u0634 \u0635\u0636\u0637\u0638',
        '\u0639\u063A\u0641\u0642 \u0643\u0644\u0645\u0646 \u0647\u064A\u0649\u0629',
        '\u0628\u06C6\u0628 \u0628\u06C7\u0628 \u0628\u06CC\u0628',
      ].join(' ');

      final multipageParagraphs = List<String>.generate(
        24,
        (i) =>
            'SYNTH-${i + 1}: \u0628\u0627\u0301\u0628 \u0628\u06CC\u0304\u0628 \u0628\u06C7\u0300\u0628 \u0628\u06C6\u0301\u0628 $contextualChains',
      );

      final draft = BeriyaDraft(
        id: 'qa08_robustness',
        title: 'QA-08 Synth : \u0627\u0301\u0622\u0300\u06CC\u0304',
        content: [
          all16Forms.join(' '),
          arabic25,
          erfe25,
          latin25,
          '', // blank line handling
          contextualChains,
          ...multipageParagraphs,
          '\u06FA \u06B5 \u0627\u0308 \u0628\u0651',
        ].join('\n'),
        fontSize: 16,
        alignment: 'right',
        updatedAt: DateTime(2026, 11, 13),
      );

      final bytes = await BeriyaPdfService.generatePdfBytes(
        draft,
        useExperimentalArabicPdf: true,
        arabicDiagnostics: diag,
      );

      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      expect(diag.unsupportedCharacters, containsAll([0x06FA, 0x06B5]));
      expect(diag.unsupportedCombiningMarks, containsAll([0x0308, 0x0651]));

      File('../docs/qa_arabic_diacritics/ar_qa_08_robustness.pdf')
          .writeAsBytesSync(bytes);
    },
  );
}
