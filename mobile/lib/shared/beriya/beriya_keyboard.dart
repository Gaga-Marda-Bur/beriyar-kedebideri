import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'beriya_chars.dart';
import 'beriya_keyboard_preferences.dart';

enum BeriyaKeyboardLayout {
  learning,
  fast,
}

class BeriyaKeyboard extends StatefulWidget {
  const BeriyaKeyboard({
    super.key,
    required this.onInsert,
    required this.onBackspace,
    required this.onSpace,
    required this.onClear,
    this.layout = BeriyaKeyboardLayout.fast,
    this.hand = BeriyaHandPreference.right,
  });

  final ValueChanged<String> onInsert;
  final VoidCallback onBackspace;
  final VoidCallback onSpace;
  final VoidCallback onClear;
  final BeriyaKeyboardLayout layout;
  final BeriyaHandPreference hand;

  @override
  State<BeriyaKeyboard> createState() => _BeriyaKeyboardState();
}

class _BeriyaKeyboardState extends State<BeriyaKeyboard> {
  bool _showSymbols = false;
  late BeriyaKeyboardLayout _layout;

  @override
  void initState() {
    super.initState();
    _layout = widget.layout;
  }

  List<List<String>> get _currentRows {
    if (_showSymbols) {
      return BeriyaChars.symbolRows;
    }

    return _layout == BeriyaKeyboardLayout.fast
      ? BeriyaChars.fastRowsOfficialOnly
      : BeriyaChars.learningRows;
  }

  bool get _isBeriyaMode => !_showSymbols;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3227).withAlpha(235),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFD4AF37).withAlpha(90),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _topTools(),
          const SizedBox(height: 12),
          for (int i = 0; i < _currentRows.length; i++) ...[
            _keyboardRow(_currentRows[i], rowIndex: i),
            if (i != _currentRows.length - 1) const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          _actionRow(loc),
        ],
      ),
    );
  }

  Widget _topTools() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ModeButton(
                label: 'Rapide',
                selected: _layout == BeriyaKeyboardLayout.fast,
                onTap: () {
                  setState(() {
                    _layout = BeriyaKeyboardLayout.fast;
                    _showSymbols = false;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ModeButton(
                label: 'ABC',
                selected: _layout == BeriyaKeyboardLayout.learning,
                onTap: () {
                  setState(() {
                    _layout = BeriyaKeyboardLayout.learning;
                    _showSymbols = false;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ModeButton(
                label: '.?123',
                selected: _showSymbols,
                onTap: () {
                  setState(() => _showSymbols = true);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _keyboardRow(List<String> chars, {required int rowIndex}) {
    final horizontalPadding = switch (rowIndex) {
      0 => 0.0,
      1 => 14.0,
      _ => 42.0,
    };

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        textDirection: widget.hand == BeriyaHandPreference.left
            ? TextDirection.rtl
            : TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final char in chars) ...[
            Expanded(
              child: _KeyButton(
                label: char,
                isBeriya: _isBeriyaMode,
                longPressOptions: BeriyaChars.longPressOptions[char],
                onTap: () => widget.onInsert(char),
                onInsert: widget.onInsert,
              ),
            ),
            if (char != chars.last) const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }

  Widget _actionRow(AppLocalizations loc) {
    return Row(
      textDirection: widget.hand == BeriyaHandPreference.left
          ? TextDirection.rtl
          : TextDirection.ltr,
      children: [
        Expanded(
          child: _KeyButton(
            label: '.',
            longPressOptions: BeriyaChars.longPressOptions['.'],
            onTap: () => widget.onInsert('.'),
            onInsert: widget.onInsert,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: _KeyButton(
            label: loc.keyboardSpace,
            onTap: widget.onSpace,
            onInsert: widget.onInsert,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KeyButton(
            label: '⌫',
            onTap: widget.onBackspace,
            onInsert: widget.onInsert,
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? const Color(0xFFD4AF37).withAlpha(45)
          : Colors.white.withAlpha(18),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? const Color(0xFFD4AF37) : Colors.white24,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFFD4AF37) : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.onTap,
    required this.onInsert,
    this.isBeriya = false,
    this.longPressOptions,
  });

  final String label;
  final VoidCallback onTap;
  final ValueChanged<String> onInsert;
  final bool isBeriya;
  final List<String>? longPressOptions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(20),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        onLongPress: longPressOptions == null
            ? null
            : () => _showLongPressMenu(context),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: isBeriya ? 25 : 14,
              fontFamily: isBeriya ? 'Kedebideri' : null,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }

  void _showLongPressMenu(BuildContext context) {
    final options = longPressOptions;
    if (options == null || options.isEmpty) return;

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: entry.remove,
                child: Container(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: position.dx,
              top: position.dy - 58,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F3227),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFD4AF37),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: options.map((option) {
                      final isBeriyaOption =
                          option.runes.any((r) => r >= 0x16EA0 && r <= 0x16EB8);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            onInsert(option);
                            entry.remove();
                          },
                          child: Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(24),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              option,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isBeriyaOption ? 24 : 18,
                                fontWeight: FontWeight.w900,
                                fontFamily:
                                    isBeriyaOption ? 'Kedebideri' : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(entry);
  }
}