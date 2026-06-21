import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/beriya/beriya_keyboard.dart';
import '../../../l10n/generated/app_localizations.dart';

enum StickerStyleType {
  classic,
  premium,
  culture,
  child,
  calligraphy,
}

enum StickerOutputMode {
  photo,
  sticker,
}

class StickerStudioScreen extends StatefulWidget {
  const StickerStudioScreen({super.key});

  @override
  State<StickerStudioScreen> createState() => _StickerStudioScreenState();
}

class _StickerStudioScreenState extends State<StickerStudioScreen> {
  final TextEditingController _controller = TextEditingController(
    text: 'La connaissance éclaire le chemin.',
  );

  final ScreenshotController _screenshotController = ScreenshotController();

  StickerStyleType _style = StickerStyleType.classic;
  StickerOutputMode _mode = StickerOutputMode.photo;
  Color _mainColor = const Color(0xFFD4AF37);
  bool _keyboardVisible = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _insertText(String value) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;

    final next = text.replaceRange(start, end, value);

    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + value.length),
    );

    setState(() {});
  }

  void _backspace() {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;

    if (start != end) {
      _controller.value = TextEditingValue(
        text: text.replaceRange(start, end, ''),
        selection: TextSelection.collapsed(offset: start),
      );
    } else if (start > 0) {
      _controller.value = TextEditingValue(
        text: text.replaceRange(start - 1, start, ''),
        selection: TextSelection.collapsed(offset: start - 1),
      );
    }

    setState(() {});
  }

  Future<void> _shareImage() async {
    final loc = AppLocalizations.of(context)!;
    final shareText = loc.studioCreatedWith;

    final bytes = await _screenshotController.capture(
      pixelRatio: 3,
    );

    if (!mounted || bytes == null) return;

    final dir = await getTemporaryDirectory();

    if (!mounted) return;

    final file = File('${dir.path}/beriyar-sticker.png');
    await file.writeAsBytes(bytes);

    if (!mounted) return;

    await Share.shareXFiles(
      [XFile(file.path)],
      text: shareText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF061A14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF061A14),
        elevation: 0,
        title: Text(loc.studioSticker),
        actions: [
          IconButton(
            onPressed: _shareImage,
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _hero(),
            const SizedBox(height: 18),
            _textInput(),
            const SizedBox(height: 14),
            _styleSelector(),
            const SizedBox(height: 14),
            _colorSelector(),
            const SizedBox(height: 14),
            _modeSelector(),
            const SizedBox(height: 18),
            _preview(),
            const SizedBox(height: 18),
            _actions(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    final loc = AppLocalizations.of(context)!;

    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✨ ${loc.studioStickerTitle}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            loc.studioStickerSubtitle,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _textInput() {
    final loc = AppLocalizations.of(context)!;
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('1. ${loc.studioWriteText}'),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            maxLines: 4,
            minLines: 3,
            readOnly: true,
            showCursor: true,
            onTap: () {
              setState(() => _keyboardVisible = true);
            },
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'Kedebideri',
            ),
            decoration: InputDecoration(
              hintText: loc.studioTextHint,
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.black.withAlpha(51),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(
                  color: _mainColor.withAlpha(90),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(
                  color: _mainColor.withAlpha(90),
                ),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _mainColor,
              foregroundColor: const Color(0xFF061A14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: () {
              setState(() => _keyboardVisible = !_keyboardVisible);
            },
            icon: const Icon(Icons.keyboard_rounded),
            label: Text(loc.studioBeriyaKeyboard),
          ),
          if (_keyboardVisible) ...[
            const SizedBox(height: 12),
            BeriyaKeyboard(
              onInsert: _insertText,
              onBackspace: _backspace,
              onSpace: () => _insertText(' '),
              onClear: () {
                _controller.clear();
                setState(() {});
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _styleSelector() {
    final loc = AppLocalizations.of(context)!;
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('2. ${loc.studioStyle}'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _styleChip(loc.studioClassic, StickerStyleType.classic),
              _styleChip(loc.studioPremium, StickerStyleType.premium),
              _styleChip(loc.studioCulture, StickerStyleType.culture),
              _styleChip(loc.studioChild, StickerStyleType.child),
              _styleChip(loc.studioCalligraphy, StickerStyleType.calligraphy),
            ],
          ),
        ],
      ),
    );
  }

  Widget _colorSelector() {
    final loc = AppLocalizations.of(context)!;
    final colors = [
      const Color(0xFFD4AF37),
      const Color(0xFF1B4D3E),
      const Color(0xFF2DD4BF),
      const Color(0xFF3B82F6),
      const Color(0xFFA855F7),
      const Color(0xFFEF4444),
    ];

    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('3. ${loc.studioColor}'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            children: colors.map((color) {
              final selected = color.toARGB32() == _mainColor.toARGB32();

              return GestureDetector(
                onTap: () => setState(() => _mainColor = color),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.white : Colors.white54,
                      width: selected ? 4 : 2,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: color.withAlpha(153),
                              blurRadius: 18,
                            ),
                          ]
                        : [],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _modeSelector() {
    final loc = AppLocalizations.of(context)!;
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('4. ${loc.studioOutputMode}'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _modeButton(loc.studioPhoto, StickerOutputMode.photo),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _modeButton(loc.studioSticker, StickerOutputMode.sticker),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    final loc = AppLocalizations.of(context)!;
    return _glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(loc.studioPreview),
          const SizedBox(height: 14),
          Screenshot(
            controller: _screenshotController,
            child: AspectRatio(
              aspectRatio: 1,
              child: _StickerPreview(
                text: _controller.text.trim().isEmpty
                    ? loc.studioEmptyText
                    : _controller.text.trim(),
                color: _mainColor,
                style: _style,
                mode: _mode,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    final loc = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _mainColor,
              foregroundColor: const Color(0xFF061A14),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: _shareImage,
            icon: const Icon(Icons.download_rounded),
            label: Text(
              loc.studioDownloadShare,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Widget _styleChip(String label, StickerStyleType type) {
    final selected = _style == type;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _style = type),
      selectedColor: _mainColor.withAlpha(56),
      backgroundColor: Colors.white.withAlpha(20),
      labelStyle: TextStyle(
        color: selected ? _mainColor : Colors.white,
        fontWeight: FontWeight.w800,
      ),
      side: BorderSide(
        color: selected ? _mainColor : Colors.white24,
      ),
    );
  }

  Widget _modeButton(String label, StickerOutputMode mode) {
    final selected = _mode == mode;

    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? _mainColor : Colors.white,
        side: BorderSide(
          color: selected ? _mainColor : Colors.white24,
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      onPressed: () => setState(() => _mode = mode),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _mainColor,
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _glass({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withAlpha(30),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StickerPreview extends StatelessWidget {
  const _StickerPreview({
    required this.text,
    required this.color,
    required this.style,
    required this.mode,
  });

  final String text;
  final Color color;
  final StickerStyleType style;
  final StickerOutputMode mode;

  @override
  Widget build(BuildContext context) {
    final transparent = mode == StickerOutputMode.sticker;

    return Container(
      decoration: BoxDecoration(
        color: transparent ? Colors.transparent : null,
        gradient: transparent ? null : _gradient(),
        borderRadius: BorderRadius.circular(36),
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(28),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: transparent
                ? const Color(0xFFFFF7E1)
                : Colors.white.withAlpha(20),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(
              color: color,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(64),
                blurRadius: 26,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 6,
                right: 10,
                child: Text(
                  '✦',
                  style: TextStyle(
                    color: color,
                    fontSize: 32,
                  ),
                ),
              ),
              Center(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: transparent ? const Color(0xFF123428) : Colors.white,
                    fontSize: _fontSize(),
                    height: style == StickerStyleType.calligraphy ? 1.28 : 1.18,
                    fontWeight: style == StickerStyleType.calligraphy
                        ? FontWeight.w700
                        : FontWeight.w900,
                    fontFamily: _fontFamily(),
                    letterSpacing: style == StickerStyleType.calligraphy ? 1.2 : 0,
                    shadows: style == StickerStyleType.calligraphy
                        ? [
                            Shadow(
                              color: color.withAlpha(120),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Text(
                  'Beřiyar Kedebideři',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LinearGradient _gradient() {
    switch (style) {
      case StickerStyleType.child:
        return const LinearGradient(
          colors: [Color(0xFF60A5FA), Color(0xFFFDE68A)],
        );
      case StickerStyleType.premium:
        return const LinearGradient(
          colors: [Color(0xFF020617), Color(0xFF1B4D3E)],
        );
      case StickerStyleType.culture:
        return const LinearGradient(
          colors: [Color(0xFF0F3227), Color(0xFFD4AF37)],
        );
      case StickerStyleType.calligraphy:
        return const LinearGradient(
          colors: [Color(0xFF10291F), Color(0xFF071B15)],
        );
      case StickerStyleType.classic:
        return const LinearGradient(
          colors: [Color(0xFF0F3227), Color(0xFF061A14)],
        );
    }
  }

  String? _fontFamily() {
    return 'Kedebideri';
  }

  double _fontSize() {
    if (text.length > 90) return 24;
    if (text.length > 50) return 30;
    return 36;
  }
}