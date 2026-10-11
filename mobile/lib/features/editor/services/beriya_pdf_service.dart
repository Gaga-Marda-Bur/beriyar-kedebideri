import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/beriya_draft.dart';

class BeriyaPdfService {
  static pw.Font? _cachedRegularFont;
  static pw.Font? _cachedBoldFont;

  static Future<void> _initFonts() async {
    if (_cachedRegularFont != null && _cachedBoldFont != null) return;

    try {
      final regData = await rootBundle.load('assets/fonts/Kedebideri-Regular.ttf');
      _cachedRegularFont = pw.Font.ttf(regData);
    } catch (_) {
      _cachedRegularFont = null;
    }

    try {
      final boldData = await rootBundle.load('assets/fonts/Kedebideri-Bold.ttf');
      _cachedBoldFont = pw.Font.ttf(boldData);
    } catch (_) {
      _cachedBoldFont = _cachedRegularFont;
    }
  }

  static pw.TextAlign _convertAlignment(String alignment) {
    switch (alignment) {
      case 'center':
        return pw.TextAlign.center;
      case 'right':
        return pw.TextAlign.right;
      case 'left':
      default:
        return pw.TextAlign.left;
    }
  }

  static Future<Uint8List> generatePdfBytes(BeriyaDraft draft) async {
    await _initFonts();

    final doc = pw.Document(
      title: draft.title.isNotEmpty ? draft.title : 'Document Beriya',
      author: 'Beřiyar Kedebideři',
      creator: 'Beřiyar Kedebideři Mobile App',
    );

    final fontRegular = _cachedRegularFont ?? pw.Font.helvetica();
    final fontBold = _cachedBoldFont ?? pw.Font.helveticaBold();
    final textAlign = _convertAlignment(draft.alignment);

    // Theme palette
    PdfColor primaryColor;
    PdfColor accentColor;
    PdfColor textColor;

    switch (draft.theme) {
      case 'cream':
        primaryColor = const PdfColor.fromInt(0xFF704214);
        accentColor = const PdfColor.fromInt(0xFFB8860B);
        textColor = const PdfColor.fromInt(0xFF2C221E);
        break;
      case 'golden':
        primaryColor = const PdfColor.fromInt(0xFF0F3227);
        accentColor = const PdfColor.fromInt(0xFFD4AF37);
        textColor = const PdfColor.fromInt(0xFF1A1A1A);
        break;
      case 'paper':
        primaryColor = const PdfColor.fromInt(0xFF1E293B);
        accentColor = const PdfColor.fromInt(0xFF0D9488);
        textColor = const PdfColor.fromInt(0xFF0F172A);
        break;
      case 'dark_forest':
      default:
        primaryColor = const PdfColor.fromInt(0xFF0D382B);
        accentColor = const PdfColor.fromInt(0xFFD4AF37);
        textColor = const PdfColor.fromInt(0xFF12231E);
        break;
    }

    final rawContent = draft.content.trim().isEmpty ? '...' : draft.content;
    final paragraphs = rawContent.split('\n');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 42),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        header: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 24),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: accentColor, width: 2),
              ),
            ),
            padding: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Beriya Kedebideri',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 16,
                        color: primaryColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'Edition Beriya • beriyarkedebideri.com',
                      style: const pw.TextStyle(
                        fontSize: 8.5,
                        color: PdfColor.fromInt(0xFF666666),
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  '${draft.updatedAt.day.toString().padLeft(2, '0')}/${draft.updatedAt.month.toString().padLeft(2, '0')}/${draft.updatedAt.year}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromInt(0xFF777777),
                  ),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 20),
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColor.fromInt(0xFFE0E0E0), width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Beriya Kedebideri - Police Kedebideri incorporee',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColor.fromInt(0xFF888888),
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} / ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColor.fromInt(0xFF888888),
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) {
          final widgets = <pw.Widget>[];

          if (draft.title.trim().isNotEmpty) {
            widgets.add(
              pw.Container(
                width: double.infinity,
                margin: const pw.EdgeInsets.only(bottom: 18),
                child: pw.Text(
                  draft.title.trim(),
                  textAlign: textAlign,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: draft.fontSize * 1.25,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                    lineSpacing: 1.2,
                  ),
                ),
              ),
            );
          }

          for (final p in paragraphs) {
            if (p.trim().isEmpty) {
              widgets.add(pw.SizedBox(height: 12));
            } else {
              widgets.add(
                pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Text(
                    p,
                    textAlign: textAlign,
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: draft.fontSize,
                      color: textColor,
                      lineSpacing: 1.4,
                    ),
                  ),
                ),
              );
            }
          }

          return widgets;
        },
      ),
    );

    return doc.save();
  }

  static Future<File> savePdfToFile(BeriyaDraft draft) async {
    final bytes = await generatePdfBytes(draft);
    final dir = await getTemporaryDirectory();
    final cleanTitle = draft.title.trim().replaceAll(RegExp(r'[^\w\s\-]'), '_');
    final filename = cleanTitle.isNotEmpty
        ? 'Beriya_${cleanTitle.replaceAll(' ', '_')}.pdf'
        : 'Beriya_Document_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<void> sharePdf(BeriyaDraft draft) async {
    final file = await savePdfToFile(draft);
    final subject = draft.title.trim().isNotEmpty
        ? draft.title.trim()
        : 'Document Beřiyar Kedebideři';
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: subject,
      text: 'Document rédigé en alphabet Beriya (Beřiyar Kedebideři)',
    );
  }

  static Future<void> previewOrPrintPdf(BeriyaDraft draft) async {
    final bytes = await generatePdfBytes(draft);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: draft.title.trim().isNotEmpty ? draft.title.trim() : 'Document_Beriya',
    );
  }
}
