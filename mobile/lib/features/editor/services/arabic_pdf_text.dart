import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'arabic_pdf_layout_data.dart';
import 'erfe_pdf_text.dart';
import 'pdf_unicode_cmap.dart';

/// Diagnostics collected during experimental Arabic PDF shaping (never crashes).
class ArabicPdfDiagnostics {
  final List<int> unsupportedCharacters = <int>[];
  final List<int> unsupportedCombiningMarks = <int>[];

  bool get hasWarnings =>
      unsupportedCharacters.isNotEmpty || unsupportedCombiningMarks.isNotEmpty;
}

bool isArabicCodePoint(int cp) =>
    (cp >= 0x0600 && cp <= 0x06FF) || (cp >= 0x0750 && cp <= 0x077F);

bool isSupportedArabicCombiningMark(int cp) =>
    cp == 0x0300 || cp == 0x0301 || cp == 0x0304 || cp == 0x0307;

bool isGeneralCombiningMark(int cp) =>
    (cp >= 0x0300 && cp <= 0x036F) || (cp >= 0x064B && cp <= 0x065F);

bool containsArabicScript(String text) => text.runes.any(isArabicCodePoint);

/// Renders an Arabic RTL paragraph/segment visually right-to-left while emitting
/// every glyph in 100% logical Unicode order with nominal /ToUnicode mapping.
class LogicalRtlArabicBlock extends pw.Widget {
  LogicalRtlArabicBlock(
    this.text, {
    required this.arabicFont,
    required this.fontSize,
    required this.color,
    this.fallbackFont,
    this.alignRight = true,
    this.lineHeightFactor = 1.65,
    this.diagnostics,
  });

  final String text;
  final pw.Font arabicFont;
  final pw.Font? fallbackFont;
  final double fontSize;
  final PdfColor color;
  final bool alignRight;
  final double lineHeightFactor;
  final ArabicPdfDiagnostics? diagnostics;

  late List<List<_WordDraw>> _lines;
  late double _spaceWidth;
  double _maxLineWidth = 0;

  double get _scale => fontSize / arabicPdfUnitsPerEm;
  double get _lineHeight => fontSize * lineHeightFactor;

  static bool _connectsLeft(int cp) {
    final forms = arabicContextualForms[cp];
    return forms != null && forms[2] != null; // has initial/medial form
  }

  _WordDraw _shapeWord(String word, PdfFont pdfFont, PdfFont? fbFont) {
    final runes = word.runes.toList();
    final clusters = <List<int>>[];
    for (final r in runes) {
      if (isGeneralCombiningMark(r) && clusters.isNotEmpty) {
        clusters.last.add(r);
      } else {
        clusters.add([r]);
      }
    }

    final draws = <_ClusterDraw>[];
    var totalW = 0.0;

    for (var i = 0; i < clusters.length; i++) {
      final cl = clusters[i];
      final base = cl[0];
      final forms = arabicContextualForms[base];

      if (forms != null) {
        final prevConn = i > 0 && _connectsLeft(clusters[i - 1][0]);
        final nextAr =
            i + 1 < clusters.length && arabicContextualForms.containsKey(clusters[i + 1][0]);
        // formIdx: 0=isol, 1=fina, 2=init, 3=medi
        final formIdx = (!prevConn && !nextAr)
            ? 0
            : (prevConn && !nextAr)
                ? 1
                : (!prevConn && nextAr)
                    ? (_connectsLeft(base) ? 2 : 0)
                    : (_connectsLeft(base) ? 3 : 1);

        final drawBaseCp = forms[formIdx] ?? forms[0] ?? base;

        if (cl.length > 1) {
          final markCp = cl[1];
          if (!isSupportedArabicCombiningMark(markCp)) {
            diagnostics?.unsupportedCombiningMarks.add(markCp);
          }
          final key =
              '${base.toRadixString(16).toUpperCase().padLeft(4, '0')}:$formIdx:${markCp.toRadixString(16).toUpperCase().padLeft(4, '0')}';
          final anchor = arabicGposAnchors[key];
          if (anchor != null) {
            final w = anchor[1] * _scale;
            draws.add(
              _ClusterDraw(
                baseCp: anchor[0],
                markCp: markCp,
                dx: anchor[2].toDouble(),
                dy: anchor[3].toDouble(),
                width: w,
                useFallback: false,
              ),
            );
            totalW += w;
            continue;
          }
        }

        final adv = pdfFont.glyphMetrics(drawBaseCp).advanceWidth;
        final useFb = adv <= 0 && fbFont != null;
        final w = (useFb ? fbFont.glyphMetrics(base).advanceWidth : adv) * fontSize;
        final safeW = w > 0 ? w : fontSize * 0.5;
        draws.add(
          _ClusterDraw(
            baseCp: useFb ? base : drawBaseCp,
            markCp: cl.length > 1 ? cl[1] : null,
            dx: 0,
            dy: 0,
            width: safeW,
            useFallback: useFb,
          ),
        );
        totalW += safeW;
      } else {
        if (isArabicCodePoint(base)) {
          diagnostics?.unsupportedCharacters.add(base);
        }
        final adv = pdfFont.glyphMetrics(base).advanceWidth;
        final useFb = adv <= 0 && fbFont != null;
        final w = (useFb ? fbFont.glyphMetrics(base).advanceWidth : adv) * fontSize;
        final safeW = w > 0 ? w : fontSize * 0.5;
        draws.add(
          _ClusterDraw(
            baseCp: base,
            markCp: cl.length > 1 ? cl[1] : null,
            dx: 0,
            dy: 0,
            width: safeW,
            useFallback: useFb,
          ),
        );
        totalW += safeW;
      }
    }

    return _WordDraw(draws, totalW);
  }

  @override
  void layout(
    pw.Context context,
    pw.BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    final pdfFont = arabicFont.getFont(context);
    final fbFont = fallbackFont?.getFont(context);
    ensureNominalArabicPdfUnicode(pdfFont);

    _spaceWidth = pdfFont.glyphMetrics(0x0020).advanceWidth * fontSize;
    if (_spaceWidth <= 0) _spaceWidth = fontSize * 0.28;
    final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 500.0;

    _lines = [];
    _maxLineWidth = 0;

    for (final rawPara in text.split('\n')) {
      final words = rawPara.split(' ').where((w) => w.isNotEmpty).toList();
      if (words.isEmpty) {
        _lines.add([]);
        continue;
      }
      var curLine = <_WordDraw>[];
      var curW = 0.0;
      for (final wStr in words) {
        final wd = _shapeWord(wStr, pdfFont, fbFont);
        final addW = curLine.isEmpty ? wd.width : (_spaceWidth + wd.width);
        if (curLine.isNotEmpty && curW + addW > maxW) {
          _lines.add(curLine);
          if (curW > _maxLineWidth) _maxLineWidth = curW;
          curLine = [wd];
          curW = wd.width;
        } else {
          curLine.add(wd);
          curW += addW;
        }
      }
      if (curLine.isNotEmpty) {
        _lines.add(curLine);
        if (curW > _maxLineWidth) _maxLineWidth = curW;
      }
    }

    final boxW =
        alignRight && constraints.maxWidth.isFinite ? constraints.maxWidth : _maxLineWidth;
    final boxH = (_lines.isEmpty ? 1 : _lines.length) * _lineHeight;
    box = PdfRect(0, 0, boxW, boxH);
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);
    final pdfFont = arabicFont.getFont(context);
    final fbFont = fallbackFont?.getFont(context);
    ensureNominalArabicPdfUnicode(pdfFont);

    context.canvas
      ..saveContext()
      ..setFillColor(color);

    for (var lineIdx = 0; lineIdx < _lines.length; lineIdx++) {
      final line = _lines[lineIdx];
      final lineBottom = box!.top - (lineIdx + 1) * _lineHeight;
      final baseY = lineBottom - arabicPdfDescent * _scale + fontSize * 0.2;
      var cursorX = box!.right;

      for (var wIdx = 0; wIdx < line.length; wIdx++) {
        final wd = line[wIdx];
        for (final cl in wd.clusters) {
          cursorX -= cl.width;
          final f = (cl.useFallback && fbFont != null) ? fbFont : pdfFont;
          context.canvas.drawString(
            f,
            fontSize,
            String.fromCharCode(cl.baseCp),
            cursorX,
            baseY,
          );
          if (cl.markCp != null) {
            context.canvas.drawString(
              f,
              fontSize,
              String.fromCharCode(cl.markCp!),
              cursorX + cl.dx * _scale,
              baseY + cl.dy * _scale,
            );
          }
        }
        if (wIdx + 1 < line.length) {
          cursorX -= _spaceWidth;
          context.canvas.drawString(pdfFont, fontSize, ' ', cursorX, baseY);
        }
      }
    }

    context.canvas.restoreContext();
  }
}

class _ClusterDraw {
  _ClusterDraw({
    required this.baseCp,
    required this.markCp,
    required this.dx,
    required this.dy,
    required this.width,
    required this.useFallback,
  });
  final int baseCp;
  final int? markCp;
  final double dx;
  final double dy;
  final double width;
  final bool useFallback;
}

class _WordDraw {
  _WordDraw(this.clusters, this.width);
  final List<_ClusterDraw> clusters;
  final double width;
}

/// Experimental Arabic-aware PDF text widget.
/// Routes pure Arabic lines to LogicalRtlArabicBlock and keeps Erfe/Latin runs
/// on erfePdfText so existing Erfe exports remain untouched.
pw.Widget arabicPdfText(
  pw.Context context,
  String text, {
  required pw.Font arabicFont,
  required pw.Font erfeFont,
  pw.Font? latinFont,
  required double fontSize,
  required PdfColor color,
  required pw.TextAlign textAlign,
  bool bold = false,
  double lineSpacing = 1.4,
  ArabicPdfDiagnostics? diagnostics,
}) {
  if (!containsArabicScript(text)) {
    return erfePdfText(
      context,
      text,
      font: erfeFont,
      fontSize: fontSize,
      color: color,
      textAlign: textAlign,
      bold: bold,
      lineSpacing: lineSpacing,
    );
  }

  // Split into contiguous Arabic (with combining marks & internal spaces) vs non-Arabic runs
  final runes = text.runes.toList();
  final runs = <({String text, bool isArabic})>[];
  var i = 0;
  final buf = StringBuffer();
  bool? curArabic;

  while (i < runes.length) {
    final cp = runes[i];
    final isArChar = isArabicCodePoint(cp);
    final isMark = isGeneralCombiningMark(cp);
    final isSpace = cp == 0x0020;

    bool nextArabic;
    if (isArChar) {
      nextArabic = true;
    } else if (isMark && curArabic == true) {
      nextArabic = true;
    } else if (isSpace && curArabic == true) {
      // Keep space inside Arabic run only if followed by Arabic
      var j = i + 1;
      while (j < runes.length && runes[j] == 0x0020) {
        j++;
      }
      nextArabic = j < runes.length && isArabicCodePoint(runes[j]);
    } else {
      nextArabic = false;
    }

    if (curArabic != null && curArabic != nextArabic) {
      runs.add((text: buf.toString(), isArabic: curArabic));
      buf.clear();
    }
    curArabic = nextArabic;
    buf.writeCharCode(cp);
    i++;
  }
  if (buf.isNotEmpty && curArabic != null) {
    runs.add((text: buf.toString(), isArabic: curArabic));
  }

  if (runs.length == 1 && runs.first.isArabic) {
    return LogicalRtlArabicBlock(
      runs.first.text,
      arabicFont: arabicFont,
      fallbackFont: latinFont ?? erfeFont,
      fontSize: fontSize,
      color: color,
      alignRight: textAlign == pw.TextAlign.right,
      diagnostics: diagnostics,
    );
  }

  return pw.Wrap(
    crossAxisAlignment: pw.WrapCrossAlignment.center,
    children: [
      for (final run in runs)
        if (run.isArabic)
          LogicalRtlArabicBlock(
            run.text,
            arabicFont: arabicFont,
            fallbackFont: latinFont ?? erfeFont,
            fontSize: fontSize,
            color: color,
            alignRight: false,
            diagnostics: diagnostics,
          )
        else
          erfePdfText(
            context,
            run.text,
            font: erfeFont,
            fontSize: fontSize,
            color: color,
            textAlign: pw.TextAlign.left,
            bold: bold,
            lineSpacing: lineSpacing,
          ),
    ],
  );
}
