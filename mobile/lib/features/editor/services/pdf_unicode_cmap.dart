// Work around pdf 3.12.0's scalar (rather than UTF-16BE) ToUnicode encoding,
// and optionally map Presentation Forms-B back to nominal U+06xx.
// No SDK/cache edit. Recheck this adapter when updating the pdf dependency.
// ignore: implementation_imports
import 'package:pdf/src/pdf/obj/unicode_cmap.dart';
import 'package:pdf/pdf.dart';
import 'arabic_pdf_layout_data.dart';

void ensurePdfSupplementaryUnicode(PdfFont font) {
  if (font is! PdfTtfFont || font.unicodeCMap is _Utf16Cmap) return;
  final previous = font.unicodeCMap;
  final replacement = _Utf16Cmap(previous.pdfDocument, previous.protect);
  replacement.cmap
    ..clear()
    ..addAll(previous.cmap);
  previous.inUse = false;
  font.unicodeCMap = replacement;
}

void ensureNominalArabicPdfUnicode(PdfFont font) {
  if (font is! PdfTtfFont || font.unicodeCMap is _NominalArabicAndUtf16Cmap) {
    return;
  }
  final previous = font.unicodeCMap;
  final replacement = _NominalArabicAndUtf16Cmap(
    previous.pdfDocument,
    previous.protect,
  );
  replacement.cmap
    ..clear()
    ..addAll(previous.cmap);
  previous.inUse = false;
  font.unicodeCMap = replacement;
}

class _Utf16Cmap extends PdfUnicodeCmap {
  _Utf16Cmap(super.pdfDocument, super.protect);
  @override
  void prepare() {
    final original = List<int>.from(cmap);
    try {
      for (var i = 0; i < cmap.length; i++) {
        final cp = cmap[i];
        if (cp > 0xffff && cp <= 0x10ffff) {
          final value = cp - 0x10000;
          cmap[i] =
              ((0xd800 + (value >> 10)) << 16) | (0xdc00 + (value & 0x3ff));
        }
      }
      super.prepare();
    } finally {
      cmap
        ..clear()
        ..addAll(original);
    }
  }
}

class _NominalArabicAndUtf16Cmap extends PdfUnicodeCmap {
  _NominalArabicAndUtf16Cmap(super.pdfDocument, super.protect);
  @override
  void prepare() {
    final original = List<int>.from(cmap);
    try {
      for (var i = 0; i < cmap.length; i++) {
        var cp = arabicPresentationToNominal[cmap[i]] ?? cmap[i];
        if (cp > 0xffff && cp <= 0x10ffff) {
          final value = cp - 0x10000;
          cp = ((0xd800 + (value >> 10)) << 16) | (0xdc00 + (value & 0x3ff));
        }
        cmap[i] = cp;
      }
      super.prepare();
    } finally {
      cmap
        ..clear()
        ..addAll(original);
    }
  }
}
