import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'beriya_keyboard.dart';
import 'beriya_keyboard_preferences.dart';
import 'beriya_keyboard_preferences_service.dart';

enum BeriyaInputMode {
  system,
  beriya,
}

class BeriyaTextField extends StatefulWidget {
  const BeriyaTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.textInputAction,
    this.keyboardType,
    this.showKeyboardInitially = false,
    this.initialMode,
    this.showModeSelector = true,
    this.prefixIcon,
    this.keyboardLayout,
    this.handPreference,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final int maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final bool showKeyboardInitially;
  final BeriyaInputMode? initialMode;
  final bool showModeSelector;
  final Widget? prefixIcon;
  final BeriyaKeyboardLayout? keyboardLayout;
  final BeriyaHandPreference? handPreference;

  @override
  State<BeriyaTextField> createState() => _BeriyaTextFieldState();
}

class _BeriyaTextFieldState extends State<BeriyaTextField> {
  late bool _keyboardVisible;
  late BeriyaInputMode _mode;

  BeriyaKeyboardLayout _keyboardLayout = BeriyaKeyboardLayout.fast;
  BeriyaHandPreference _handPreference = BeriyaHandPreference.right;

  bool get _isBeriyaMode => _mode == BeriyaInputMode.beriya;

  @override
  void initState() {
    super.initState();

    _keyboardVisible = widget.showKeyboardInitially;
    _mode = widget.initialMode ?? BeriyaInputMode.beriya;

    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await BeriyaKeyboardPreferencesService.load();

    if (!mounted) return;

    setState(() {
      _keyboardLayout = widget.keyboardLayout ??
          (prefs.layout == BeriyaKeyboardLayoutPreference.abc
              ? BeriyaKeyboardLayout.learning
              : BeriyaKeyboardLayout.fast);

      _handPreference = widget.handPreference ?? prefs.hand;

      if (widget.initialMode == null) {
        _mode = prefs.inputMode == BeriyaInputModePreference.system
            ? BeriyaInputMode.system
            : BeriyaInputMode.beriya;

        _keyboardVisible = _mode == BeriyaInputMode.beriya;
      }
    });
  }

  void _insertText(String value) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;

    final next = text.replaceRange(start, end, value);

    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + value.length),
    );

    widget.onChanged?.call(widget.controller.text);
    setState(() {});
  }

  void _backspace() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;

    if (start != end) {
      widget.controller.value = TextEditingValue(
        text: text.replaceRange(start, end, ''),
        selection: TextSelection.collapsed(offset: start),
      );
    } else if (start > 0) {
      widget.controller.value = TextEditingValue(
        text: text.replaceRange(start - 1, start, ''),
        selection: TextSelection.collapsed(offset: start - 1),
      );
    }

    widget.onChanged?.call(widget.controller.text);
    setState(() {});
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
    setState(() {});
  }

  void _changeMode(BeriyaInputMode mode) {
    setState(() {
      _mode = mode;
      _keyboardVisible = mode == BeriyaInputMode.beriya;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
        ],

        if (widget.showModeSelector) ...[
          Row(
            children: [
              Expanded(
                child: _InputModeButton(
                  label: loc.keyboardSystem,
                  selected: _mode == BeriyaInputMode.system,
                  onTap: () => _changeMode(BeriyaInputMode.system),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InputModeButton(
                  label: loc.studioBeriyaKeyboard,
                  selected: _mode == BeriyaInputMode.beriya,
                  onTap: () => _changeMode(BeriyaInputMode.beriya),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],

        TextField(
          controller: widget.controller,
          readOnly: _isBeriyaMode,
          showCursor: true,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          textInputAction: widget.textInputAction,
          keyboardType: widget.keyboardType,
          onTap: () {
            if (_isBeriyaMode) {
              setState(() => _keyboardVisible = true);
            }
          },
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontFamily: 'Kedebideri',
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: widget.prefixIcon,
            filled: true,
            fillColor: Colors.black.withAlpha(45),
            suffixIcon: IconButton(
              icon: Icon(
                _isBeriyaMode
                    ? (_keyboardVisible
                        ? Icons.keyboard_hide_rounded
                        : Icons.keyboard_rounded)
                    : Icons.keyboard_alt_rounded,
                color: const Color(0xFFD4AF37),
              ),
              onPressed: () {
                if (_isBeriyaMode) {
                  setState(() => _keyboardVisible = !_keyboardVisible);
                }
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: Colors.white.withAlpha(35),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: Color(0xFFD4AF37),
              ),
            ),
          ),
          onChanged: widget.onChanged,
        ),

        if (_isBeriyaMode && _keyboardVisible) ...[
          const SizedBox(height: 12),
          BeriyaKeyboard(
            layout: _keyboardLayout,
            hand: _handPreference,
            onInsert: _insertText,
            onBackspace: _backspace,
            onSpace: () => _insertText(' '),
            onClear: _clear,
          ),
        ],
      ],
    );
  }
}

class _InputModeButton extends StatelessWidget {
  const _InputModeButton({
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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? const Color(0xFFD4AF37) : Colors.white24,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
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