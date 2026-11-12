import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../shared/beriya/transliteration_data.dart';
import 'erfe_pdf_layout_data.dart';
import 'pdf_unicode_cmap.dart';

/// Keep searchable Unicode text, positioning marks with the font's GPOS anchors.
/// No replacement font, outlines, approximate centering or inferred accent.
pw.Widget erfePdfText(
  pw.Context context,
  String text, {
  required pw.Font font,
  required double fontSize,
  required PdfColor color,
  required pw.TextAlign textAlign,
  bool bold = false,
  double lineSpacing = 1.4,
}) {
  ensurePdfSupplementaryUnicode(font.getFont(context));
  final metrics =
      erfePdfLayoutData[bold ? 'bold' : 'regular'] as Map<String, dynamic>;
  final layouts = metrics['units'] as Map<String, dynamic>;
  final chars = text.runes.toList(), spans = <pw.InlineSpan>[];
  bool isMark(int cp) => (transliterationData['combining_ranges'] as List).any(
    (r) => r[0] <= cp && cp <= r[1],
  );
  var index = 0;
  final plain = StringBuffer();
  void flush() {
    if (plain.isNotEmpty) {
      spans.add(pw.TextSpan(text: plain.toString()));
      plain.clear();
    }
  }

  while (index < chars.length) {
    var end = index + 1;
    while (end < chars.length && isMark(chars[end])) {
      end++;
    }
    final unit = String.fromCharCodes(chars.sublist(index, end));
    final layout = layouts[unit] as List?;
    if (layout == null) {
      plain.write(unit);
    } else {
      flush();
      final baseline =
          (metrics['descent'] as num).toDouble() *
          fontSize /
          (metrics['unitsPerEm'] as num);
      spans.add(
        pw.WidgetSpan(
          baseline: baseline,
          child: _AnchoredErfeUnit(
            font: font,
            size: fontSize,
            color: color,
            metrics: metrics,
            glyphs: layout,
          ),
        ),
      );
    }
    index = end;
  }
  flush();
  return pw.RichText(
    textAlign: textAlign,
    text: pw.TextSpan(
      style: pw.TextStyle(
        font: font,
        fontSize: fontSize,
        color: color,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        lineSpacing: lineSpacing,
      ),
      children: spans,
    ),
  );
}

class _AnchoredErfeUnit extends pw.Widget {
  _AnchoredErfeUnit({
    required this.font,
    required this.size,
    required this.color,
    required this.metrics,
    required this.glyphs,
  });
  final pw.Font font;
  final double size;
  final PdfColor color;
  final Map<String, dynamic> metrics;
  final List<dynamic> glyphs;
  double get scale => size / (metrics['unitsPerEm'] as num);
  @override
  void layout(
    pw.Context context,
    pw.BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    final width =
        glyphs.fold<double>(
          0,
          (advance, g) => advance + (g['xAdvance'] as num).toDouble(),
        ) *
        scale;
    box = PdfRect(
      0,
      0,
      width,
      ((metrics['ascent'] as num) - (metrics['descent'] as num)) * scale,
    );
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);
    final pdfFont = font.getFont(context);
    context.canvas.setFillColor(color);
    // The generator checks this exact two-glyph horizontal mark layout.
    // One text operation keeps the base and mark together for text extraction.
    context.canvas.saveContext();
    context.canvas.drawString(
      pdfFont,
      size,
      glyphs.map((g) => g['text'] as String).join(),
      box!.left,
      box!.bottom - (metrics['descent'] as num) * scale,
      charSpace: (glyphs[1]['xOffset'] as num) * scale,
    );
    context.canvas.restoreContext();
  }
}
