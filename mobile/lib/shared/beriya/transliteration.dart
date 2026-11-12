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
    .map((r) => List<String?>.from(r as List))
    .toList();
final _aliases = {
  for (final r in _rows)
    if (r[1]!.runes.length == 1) r[1]!: r[0]!,
};
final _sources = {
  WritingScript.erfe: {for (final r in _rows) r[0]!: r[0]!},
  WritingScript.latin: {
    for (final r in _rows) ...{r[2]!: r[0]!, r[3]!: r[0]!},
  },
  WritingScript.arabic: {
    for (final r in _rows)
      if (r[4] != null) r[4]!: r[0]!,
  },
};

String normalizeErfe(String text) => unorm.nfc(
  text.runes
      .map((r) => _aliases[String.fromCharCode(r)] ?? String.fromCharCode(r))
      .join(),
);

bool _inRanges(int cp, String key) => (transliterationData[key] as List).any(
  (r) => (r[0] as int) <= cp && cp <= (r[1] as int),
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
  final output = {for (final r in _rows) r[0]!: r[column]};
  final unmapped = <Map<String, Object>>[];
  final result = StringBuffer();
  var index = 0;
  final chars = normalizeErfe(text).runes.toList();
  while (index < chars.length) {
    var end = index + 1;
    while (end < chars.length && _inRanges(chars[end], 'combining_ranges')) {
      end++;
    }
    final unit = String.fromCharCodes(chars.sublist(index, end));
    final canonical = _sources[source]![unit];
    final mapped = output[canonical];
    if (mapped != null) {
      result.write(mapped);
    } else {
      result.write(unit);
      final pass =
          end - index == 1 && _inRanges(chars[index], 'passthrough_ranges');
      if (!pass) {
        unmapped.add({
          'character': unit,
          'codepoint': chars
              .sublist(index, end)
              .map(
                (cp) =>
                    'U+${cp.toRadixString(16).toUpperCase().padLeft(4, '0')}',
              )
              .join(' '),
          'index': index,
          if (canonical != null && target == WritingScript.arabic)
            'reason': 'missing_arabic_mapping',
        });
      }
    }
    index = end;
  }
  return TransliterationResult(unorm.nfc(result.toString()), unmapped);
}
