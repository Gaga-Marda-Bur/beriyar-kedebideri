import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/beriya/beriya_keyboard.dart';
import '../../../shared/beriya/beriya_keyboard_preferences.dart';
import '../../../shared/beriya/beriya_keyboard_preferences_service.dart';
import '../../../shared/beriya/beriya_keyboard_sheet.dart';
import '../models/beriya_draft.dart';
import '../services/beriya_draft_storage.dart';
import '../services/beriya_pdf_service.dart';

enum _ActiveField { title, body }

class BeriyaEditorScreen extends StatefulWidget {
  const BeriyaEditorScreen({super.key});

  @override
  State<BeriyaEditorScreen> createState() => _BeriyaEditorScreenState();
}

class _BeriyaEditorScreenState extends State<BeriyaEditorScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final ScreenshotController _screenshotController = ScreenshotController();

  _ActiveField _activeField = _ActiveField.body;
  double _fontSize = 24.0;
  String _alignment = 'left';
  String _theme = 'dark_forest';

  bool _isSaving = false;
  Timer? _debounceTimer;

  BeriyaKeyboardLayout _keyboardLayout = BeriyaKeyboardLayout.fast;
  BeriyaHandPreference _handPreference = BeriyaHandPreference.right;

  @override
  void initState() {
    super.initState();
    _loadKeyboardPreferences();
    _loadDraft();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadKeyboardPreferences() async {
    final prefs = await BeriyaKeyboardPreferencesService.load();
    if (!mounted) return;
    setState(() {
      _keyboardLayout = prefs.layout == BeriyaKeyboardLayoutPreference.abc
          ? BeriyaKeyboardLayout.learning
          : BeriyaKeyboardLayout.fast;
      _handPreference = prefs.hand;
    });
  }

  Future<void> _loadDraft() async {
    final draft = await BeriyaDraftStorage.loadActiveDraft();
    if (!mounted) return;
    setState(() {
      _titleController.text = draft.title;
      _bodyController.text = draft.content;
      _fontSize = draft.fontSize;
      _alignment = draft.alignment;
      _theme = draft.theme;
    });
  }

  void _onContentChanged() {
    setState(() {
      _isSaving = true;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      final draft = BeriyaDraft(
        id: 'default_draft',
        title: _titleController.text,
        content: _bodyController.text,
        fontSize: _fontSize,
        alignment: _alignment,
        theme: _theme,
        updatedAt: DateTime.now(),
      );

      await BeriyaDraftStorage.saveDraft(draft);

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    });
  }

  BeriyaDraft _getCurrentDraft() {
    return BeriyaDraft(
      id: 'default_draft',
      title: _titleController.text,
      content: _bodyController.text,
      fontSize: _fontSize,
      alignment: _alignment,
      theme: _theme,
      updatedAt: DateTime.now(),
    );
  }

  void _openBeriyaKeyboard() {
    final targetController =
        _activeField == _ActiveField.title ? _titleController : _bodyController;

    showBeriyaKeyboardSheet(
      context: context,
      controller: targetController,
      onChanged: (_) => _onContentChanged(),
      layout: _keyboardLayout,
      hand: _handPreference,
    );
  }

  Future<void> _confirmNewDocument() async {
    final loc = AppLocalizations.of(context)!;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D382B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          loc.editorNewDoc,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          loc.editorNewDocConfirm,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.editorCancel, style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.editorClear),
          ),
        ],
      ),
    );

    if (proceed == true) {
      setState(() {
        _titleController.clear();
        _bodyController.clear();
      });
      await BeriyaDraftStorage.clearActiveDraft();
    }
  }

  void _copyText() {
    final loc = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    final fullText = title.isNotEmpty ? '$title\n\n$body' : body;
    if (fullText.isEmpty) return;

    Clipboard.setData(ClipboardData(text: fullText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(loc.editorTextCopied),
        backgroundColor: const Color(0xFF0F3227),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _exportAsPng() async {
    try {
      final bytes = await _screenshotController.capture(pixelRatio: 3.0);
      if (bytes == null || !mounted) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Beriya_Document_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'Document créé avec l\'Éditeur Beřiyar Kedebideři',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur export Image: $e')),
      );
    }
  }

  Future<void> _exportAsPdf() async {
    try {
      final draft = _getCurrentDraft();
      await BeriyaPdfService.sharePdf(draft);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur export PDF: $e')),
      );
    }
  }

  Future<void> _printOrPreviewPdf() async {
    try {
      final draft = _getCurrentDraft();
      await BeriyaPdfService.previewOrPrintPdf(draft);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur aperçu PDF: $e')),
      );
    }
  }

  void _showExportModal() {
    final loc = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: const BoxDecoration(
          color: Color(0xFF061A14),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0xFFD4AF37), width: 1.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.ios_share_rounded, color: Color(0xFFD4AF37)),
                const SizedBox(width: 10),
                Text(
                  loc.editorExport,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
              ),
              title: Text(
                loc.editorExportPdf,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Police Kedebideri incorporée (lisible partout)',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
              onTap: () {
                Navigator.pop(ctx);
                _exportAsPdf();
              },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.image_rounded, color: Colors.blueAccent),
              ),
              title: Text(
                loc.editorExportImage,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Capture haute résolution PNG',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
              onTap: () {
                Navigator.pop(ctx);
                _exportAsPng();
              },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.print_rounded, color: Color(0xFFD4AF37)),
              ),
              title: Text(
                loc.editorPrintPreview,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Mise en page A4 directe',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
              onTap: () {
                Navigator.pop(ctx);
                _printOrPreviewPdf();
              },
            ),
          ],
        ),
      ),
    );
  }

  TextAlign _getTextAlign() {
    switch (_alignment) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'left':
      default:
        return TextAlign.left;
    }
  }

  Color _getCanvasBg() {
    switch (_theme) {
      case 'cream':
        return const Color(0xFFFAF6EE);
      case 'golden':
        return const Color(0xFF141913);
      case 'paper':
        return const Color(0xFFFFFFFF);
      case 'dark_forest':
      default:
        return const Color(0xFF0A221A);
    }
  }

  Color _getCanvasTextColor() {
    switch (_theme) {
      case 'cream':
        return const Color(0xFF2B2118);
      case 'golden':
        return const Color(0xFFFFF7DC);
      case 'paper':
        return const Color(0xFF0F172A);
      case 'dark_forest':
      default:
        return Colors.white;
    }
  }

  Color _getCanvasBorderColor() {
    switch (_theme) {
      case 'cream':
        return const Color(0xFFCBB689);
      case 'golden':
        return const Color(0xFFFFD700);
      case 'paper':
        return const Color(0xFFE2E8F0);
      case 'dark_forest':
      default:
        return const Color(0xFFD4AF37).withAlpha(120);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final canvasBg = _getCanvasBg();
    final canvasTextColor = _getCanvasTextColor();
    final canvasBorderColor = _getCanvasBorderColor();
    final textAlign = _getTextAlign();

    return Scaffold(
      backgroundColor: const Color(0xFF061A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF061A14),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.editorTitle,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
            ),
            Row(
              children: [
                Icon(
                  _isSaving ? Icons.sync_rounded : Icons.check_circle_rounded,
                  size: 12,
                  color: _isSaving ? const Color(0xFFD4AF37) : Colors.greenAccent,
                ),
                const SizedBox(width: 4),
                Text(
                  _isSaving ? loc.editorSaving : loc.editorDraftSaved,
                  style: TextStyle(
                    fontSize: 11,
                    color: _isSaving ? const Color(0xFFD4AF37) : Colors.greenAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: loc.editorCopyText,
            icon: const Icon(Icons.copy_rounded, color: Colors.white70),
            onPressed: _copyText,
          ),
          IconButton(
            tooltip: loc.editorNewDoc,
            icon: const Icon(Icons.note_add_outlined, color: Colors.white70),
            onPressed: _confirmNewDocument,
          ),
          IconButton(
            tooltip: loc.editorExport,
            icon: const Icon(Icons.ios_share_rounded, color: Color(0xFFD4AF37)),
            onPressed: _showExportModal,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0A221A),
            border: Border(top: BorderSide(color: Colors.white.withAlpha(25))),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: const Color(0xFF061A14),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _openBeriyaKeyboard,
                  icon: const Icon(Icons.keyboard_rounded, size: 24),
                  label: Text(
                    _activeField == _ActiveField.title
                        ? '𖺠 Clavier Beriya (Titre)'
                        : '𖺠 Clavier Beriya (Texte)',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Formatting ToolBar
            _buildFormatBar(loc),

            // Scrollable Document Canvas
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Screenshot(
                  controller: _screenshotController,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: canvasBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: canvasBorderColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(90),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header watermark
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Beřiyar Kedebideři',
                              style: TextStyle(
                                color: canvasTextColor.withAlpha(160),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              '✦',
                              style: TextStyle(
                                color: const Color(0xFFD4AF37),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Document Title
                        TextField(
                          controller: _titleController,
                          textAlign: textAlign,
                          readOnly: true,
                          showCursor: true,
                          style: TextStyle(
                            fontFamily: 'Kedebideri',
                            fontSize: _fontSize * 1.25,
                            fontWeight: FontWeight.w900,
                            color: canvasTextColor,
                          ),
                          decoration: InputDecoration(
                            hintText: loc.editorDocTitleHint,
                            hintStyle: TextStyle(
                              color: canvasTextColor.withAlpha(80),
                              fontFamily: 'Kedebideri',
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onTap: () {
                            setState(() {
                              _activeField = _ActiveField.title;
                            });
                            _openBeriyaKeyboard();
                          },
                          onChanged: (_) => _onContentChanged(),
                        ),

                        // Divider
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 14),
                          height: 1.5,
                          color: canvasBorderColor.withAlpha(100),
                        ),

                        // Document Body
                        TextField(
                          controller: _bodyController,
                          textAlign: textAlign,
                          readOnly: true,
                          showCursor: true,
                          maxLines: null,
                          style: TextStyle(
                            fontFamily: 'Kedebideri',
                            fontSize: _fontSize,
                            color: canvasTextColor,
                            height: 1.45,
                          ),
                          decoration: InputDecoration(
                            hintText: loc.editorBodyHint,
                            hintStyle: TextStyle(
                              color: canvasTextColor.withAlpha(80),
                              fontFamily: 'Kedebideri',
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onTap: () {
                            setState(() {
                              _activeField = _ActiveField.body;
                            });
                            _openBeriyaKeyboard();
                          },
                          onChanged: (_) => _onContentChanged(),
                        ),

                        const SizedBox(height: 48),

                        // Footer note in canvas
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'beriyarkedebideri.com',
                            style: TextStyle(
                              fontSize: 10,
                              color: canvasTextColor.withAlpha(100),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatBar(AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D382B).withAlpha(160),
        border: Border(
          bottom: BorderSide(color: Colors.white.withAlpha(20)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Alignment buttons
            IconButton(
              tooltip: 'Aligner à gauche',
              icon: Icon(
                Icons.format_align_left_rounded,
                color: _alignment == 'left' ? const Color(0xFFD4AF37) : Colors.white60,
                size: 20,
              ),
              onPressed: () {
                setState(() => _alignment = 'left');
                _onContentChanged();
              },
            ),
            IconButton(
              tooltip: 'Centrer',
              icon: Icon(
                Icons.format_align_center_rounded,
                color: _alignment == 'center' ? const Color(0xFFD4AF37) : Colors.white60,
                size: 20,
              ),
              onPressed: () {
                setState(() => _alignment = 'center');
                _onContentChanged();
              },
            ),
            IconButton(
              tooltip: 'Aligner à droite',
              icon: Icon(
                Icons.format_align_right_rounded,
                color: _alignment == 'right' ? const Color(0xFFD4AF37) : Colors.white60,
                size: 20,
              ),
              onPressed: () {
                setState(() => _alignment = 'right');
                _onContentChanged();
              },
            ),
            const VerticalDivider(color: Colors.white24, width: 20),

            // Font size selector
            _fontSizeChip('A-', 18.0),
            const SizedBox(width: 4),
            _fontSizeChip('A', 24.0),
            const SizedBox(width: 4),
            _fontSizeChip('A+', 30.0),
            const SizedBox(width: 4),
            _fontSizeChip('A++', 38.0),

            const VerticalDivider(color: Colors.white24, width: 20),

            // Theme selector chips
            _themeDot('dark_forest', const Color(0xFF0D382B), 'Forêt'),
            const SizedBox(width: 6),
            _themeDot('cream', const Color(0xFFFAF6EE), 'Parchemin'),
            const SizedBox(width: 6),
            _themeDot('golden', const Color(0xFF141913), 'Royal'),
            const SizedBox(width: 6),
            _themeDot('paper', const Color(0xFFFFFFFF), 'Papier'),
          ],
        ),
      ),
    );
  }

  Widget _fontSizeChip(String label, double size) {
    final selected = (_fontSize - size).abs() < 1.0;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() => _fontSize = size);
        _onContentChanged();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD4AF37) : Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF061A14) : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _themeDot(String key, Color color, String name) {
    final selected = _theme == key;
    return Tooltip(
      message: name,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () {
          setState(() => _theme = key);
          _onContentChanged();
        },
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? const Color(0xFFD4AF37) : Colors.white30,
              width: selected ? 2.5 : 1,
            ),
            boxShadow: selected
                ? [
                    const BoxShadow(
                      color: Color(0xFFD4AF37),
                      blurRadius: 6,
                    )
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
