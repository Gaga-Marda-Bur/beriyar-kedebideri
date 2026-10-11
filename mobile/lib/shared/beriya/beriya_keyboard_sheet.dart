import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/generated/app_localizations.dart';
import 'beriya_keyboard.dart';
import 'beriya_keyboard_preferences.dart';
import 'beriya_keyboard_preferences_service.dart';
import 'utf16_safe.dart';

/// Shows the Beriya Erfe Keyboard as an architecturally managed Modal BottomSheet.
/// 
/// Lifecycle & Navigation guarantees:
/// 1. Back button (Android Back / system back) closes the sheet via [Navigator.pop].
/// 2. The close button [X] closes the sheet via [Navigator.pop].
/// 3. Swiping down or tapping outside dismisses the sheet cleanly.
/// 4. No floating ghost buttons or lingering OverlayEntries remain on screen.
Future<void> showBeriyaKeyboardSheet({
  required BuildContext context,
  required TextEditingController controller,
  ValueChanged<String>? onChanged,
  BeriyaKeyboardLayout? layout,
  BeriyaHandPreference? hand,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    enableDrag: true,
    useSafeArea: true,
    builder: (modalContext) {
      return BeriyaKeyboardSheet(
        controller: controller,
        onChanged: onChanged,
        layout: layout,
        hand: hand,
      );
    },
  );
}

class BeriyaKeyboardSheet extends StatefulWidget {
  const BeriyaKeyboardSheet({
    super.key,
    required this.controller,
    this.onChanged,
    this.layout,
    this.hand,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final BeriyaKeyboardLayout? layout;
  final BeriyaHandPreference? hand;

  @override
  State<BeriyaKeyboardSheet> createState() => _BeriyaKeyboardSheetState();
}

class _BeriyaKeyboardSheetState extends State<BeriyaKeyboardSheet> {
  BeriyaKeyboardLayout _layout = BeriyaKeyboardLayout.fast;
  BeriyaHandPreference _hand = BeriyaHandPreference.right;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await BeriyaKeyboardPreferencesService.load();
    if (!mounted) return;

    setState(() {
      _layout = widget.layout ??
          (prefs.layout == BeriyaKeyboardLayoutPreference.abc
              ? BeriyaKeyboardLayout.learning
              : BeriyaKeyboardLayout.fast);
      _hand = widget.hand ?? prefs.hand;
    });
  }

  void _insert(String value) {
    final text = Utf16Safe.sanitize(widget.controller.text);
    final selection = widget.controller.selection;

    final rawStart = selection.start < 0 ? text.length : selection.start;
    final rawEnd = selection.end < 0 ? text.length : selection.end;

    final start = rawStart.clamp(0, text.length);
    final end = rawEnd.clamp(0, text.length);

    final safeStart = start < end ? start : end;
    final safeEnd = start < end ? end : start;

    final next = text.replaceRange(safeStart, safeEnd, value);
    final sanitized = Utf16Safe.sanitize(next);

    widget.controller.value = TextEditingValue(
      text: sanitized,
      selection: TextSelection.collapsed(
        offset: (safeStart + value.length).clamp(0, sanitized.length),
      ),
    );

    widget.onChanged?.call(sanitized);
  }

  void _backspace() {
    final text = Utf16Safe.sanitize(widget.controller.text);
    final selection = widget.controller.selection;

    final rawStart = selection.start < 0 ? text.length : selection.start;
    final rawEnd = selection.end < 0 ? text.length : selection.end;

    final start = rawStart.clamp(0, text.length);
    final end = rawEnd.clamp(0, text.length);

    if (start != end) {
      final safeStart = start < end ? start : end;
      final safeEnd = start < end ? end : start;
      final next = Utf16Safe.sanitize(text.replaceRange(safeStart, safeEnd, ''));
      widget.controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: safeStart.clamp(0, next.length)),
      );
    } else if (start > 0) {
      final (next, newOffset) = Utf16Safe.deleteBefore(text, start);
      final sanitized = Utf16Safe.sanitize(next);
      widget.controller.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: newOffset.clamp(0, sanitized.length)),
      );
    }

    widget.onChanged?.call(widget.controller.text);
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF08261D).withAlpha(250),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(
          color: AppColors.gold.withAlpha(100),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 30,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Header with Title and explicit Close button [X]
          Row(
            children: [
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_rounded, color: AppColors.gold, size: 22),
              const SizedBox(width: 10),
              Text(
                loc.studioBeriyaKeyboard,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                tooltip: 'Fermer le clavier',
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Core Keyboard widget
          BeriyaKeyboard(
            layout: _layout,
            hand: _hand,
            onInsert: _insert,
            onBackspace: _backspace,
            onSpace: () => _insert(' '),
            onClear: _clear,
          ),
        ],
      ),
    );
  }
}
