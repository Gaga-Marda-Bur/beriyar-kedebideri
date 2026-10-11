/// Utility to safely manipulate UTF-16 strings containing characters
/// outside the Basic Multilingual Plane (BMP, code points > 0xFFFF),
/// such as Beriya Erfe characters (U+16EA0 to U+16EB8).
///
/// Prevents orphaned surrogate halves that trigger
/// "ArgumentError: string is not well-formed UTF-16" in Flutter's TextSpan / TextPainter.
class Utf16Safe {
  const Utf16Safe._();

  /// Safely deletes the character immediately preceding [offset],
  /// taking into account 2-code-unit surrogate pairs.
  static (String text, int newOffset) deleteBefore(String text, int offset) {
    if (offset <= 0 || text.isEmpty) {
      return (text, 0);
    }

    final safeOffset = offset.clamp(0, text.length);
    int deleteCount = 1;

    if (safeOffset >= 2) {
      final lead = text.codeUnitAt(safeOffset - 2);
      final trail = text.codeUnitAt(safeOffset - 1);
      // High surrogate: 0xD800..0xDBFF, Low surrogate: 0xDC00..0xDFFF
      if (lead >= 0xD800 && lead <= 0xDBFF && trail >= 0xDC00 && trail <= 0xDFFF) {
        deleteCount = 2;
      }
    }

    final newOffset = safeOffset - deleteCount;
    final newText = text.replaceRange(newOffset, safeOffset, '');
    return (newText, newOffset);
  }

  /// Drops the last grapheme / code point from [text], respecting surrogate pairs.
  static String dropLast(String text) {
    if (text.isEmpty) return '';
    return deleteBefore(text, text.length).$1;
  }

  /// Removes any unpaired or isolated UTF-16 surrogates from [input],
  /// guaranteeing that the returned string is 100% valid UTF-16.
  static String sanitize(String input) {
    if (input.isEmpty) return '';

    final units = <int>[];
    for (int i = 0; i < input.length; i++) {
      final code = input.codeUnitAt(i);
      if (code >= 0xD800 && code <= 0xDBFF) {
        // High surrogate
        if (i + 1 < input.length) {
          final next = input.codeUnitAt(i + 1);
          if (next >= 0xDC00 && next <= 0xDFFF) {
            units.add(code);
            units.add(next);
            i++;
            continue;
          }
        }
        // Orphaned high surrogate: omit
        continue;
      } else if (code >= 0xDC00 && code <= 0xDFFF) {
        // Orphaned low surrogate: omit
        continue;
      } else {
        units.add(code);
      }
    }
    return String.fromCharCodes(units);
  }
}
