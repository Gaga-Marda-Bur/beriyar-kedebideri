import 'package:unorm_dart/unorm_dart.dart' as unorm;
import 'transliteration_data.dart';

enum WritingScript { erfe, latin, arabic }

class TransliterationResult {
  const TransliterationResult(this.text, this.unmapped);
  final String text;
  final List<Map<String, Object>> unmapped;
  Map<String, Object> toJson() => {'text': text, 'unmapped': unmapped};
}

final _rows = (transliterationData['rows'] as List)
    .map((r) => List<String>.from(r as List))
    .toList();
final _aliases = {for (final r in _rows) r[1]: r[0]};
final _sources = {
  WritingScript.erfe: {for (final r in _rows) r[0]: r[0]},
  WritingScript.latin: {
    for (final r in _rows) ...{r[2]: r[0], r[3]: r[0]},
  },
  WritingScript.arabic: {for (final r in _rows) r[4]: r[0]},
};

String normalizeErfe(String text) => unorm.nfc(
  text.runes
      .map((r) => _aliases[String.fromCharCode(r)] ?? String.fromCharCode(r))
      .join(),
);

TransliterationResult transliterate(
  String text,
  WritingScript source,
  WritingScript target, {
  bool latinLowercase = false,
}) {
  final column = switch (target) {
    WritingScript.erfe => 0,
    WritingScript.latin => latinLowercase ? 3 : 2,
    WritingScript.arabic => 4,
  };
  final output = {for (final r in _rows) r[0]: r[column]};
  final unmapped = <Map<String, Object>>[];
  final result = StringBuffer();
  var index = 0;
  for (final cp in normalizeErfe(text).runes) {
    final c = String.fromCharCode(cp);
    final canonical = _sources[source]![c];
    if (canonical != null) {
      result.write(output[canonical]);
    } else {
      result.write(c);
      final pass = (transliterationData['passthrough_ranges'] as List).any(
        (r) => (r[0] as int) <= cp && cp <= (r[1] as int),
      );
      if (!pass) {
        unmapped.add({
          'character': c,
          'codepoint':
              'U+${cp.toRadixString(16).toUpperCase().padLeft(4, '0')}',
          'index': index,
        });
      }
    }
    index++;
  }
  return TransliterationResult(unorm.nfc(result.toString()), unmapped);
}
