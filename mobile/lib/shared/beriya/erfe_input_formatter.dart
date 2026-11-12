import 'package:flutter/services.dart';
import 'transliteration.dart';

/// Does not transliterate Latin/Arabic. Preserve IME composition and UTF-16 caret.
class ErfeInputFormatter extends TextInputFormatter {
  const ErfeInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    final normalized = normalizeErfe(newValue.text);
    if (normalized == newValue.text) return newValue;
    int position(int offset) {
      if (offset < 0) return offset;
      var safe = offset.clamp(0, newValue.text.length);
      if (safe > 0 &&
          safe < newValue.text.length &&
          newValue.text.codeUnitAt(safe) >= 0xDC00 &&
          newValue.text.codeUnitAt(safe) <= 0xDFFF &&
          newValue.text.codeUnitAt(safe - 1) >= 0xD800 &&
          newValue.text.codeUnitAt(safe - 1) <= 0xDBFF) {
        safe--;
      }
      return normalizeErfe(
        newValue.text.substring(0, safe),
      ).length.clamp(0, normalized.length);
    }

    return newValue.copyWith(
      text: normalized,
      composing: TextRange.empty,
      selection: TextSelection(
        baseOffset: position(newValue.selection.baseOffset),
        extentOffset: position(newValue.selection.extentOffset),
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
    );
  }
}
