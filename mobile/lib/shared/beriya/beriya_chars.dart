class BeriyaChars {
  const BeriyaChars._();

  static const List<String> official = [
    '\u{16EA0}',
    '\u{16EA1}',
    '\u{16EA2}',
    '\u{16EA3}',
    '\u{16EA4}',
    '\u{16EA5}',
    '\u{16EA6}',
    '\u{16EA7}',
    '\u{16EA8}',
    '\u{16EA9}',
    '\u{16EAA}',
    '\u{16EAB}',
    '\u{16EAC}',
    '\u{16EAD}',
    '\u{16EAE}',
    '\u{16EAF}',
    '\u{16EB0}',
    '\u{16EB1}',
    '\u{16EB2}',
    '\u{16EB3}',
    '\u{16EB4}',
    '\u{16EB5}',
    '\u{16EB6}',
    '\u{16EB7}',
    '\u{16EB8}',
  ];

  /// Mode apprentissage : ordre officiel Unicode.
  static const List<List<String>> learningRows = [
    [
      '\u{16EA0}',
      '\u{16EA1}',
      '\u{16EA2}',
      '\u{16EA3}',
      '\u{16EA4}',
      '\u{16EA5}',
      '\u{16EA6}',
      '\u{16EA7}',
      '\u{16EA8}',
      '\u{16EA9}',
    ],
    [
      '\u{16EAA}',
      '\u{16EAB}',
      '\u{16EAC}',
      '\u{16EAD}',
      '\u{16EAE}',
      '\u{16EAF}',
      '\u{16EB0}',
      '\u{16EB1}',
      '\u{16EB2}',
    ],
    [
      '\u{16EB3}',
      '\u{16EB4}',
      '\u{16EB5}',
      '\u{16EB6}',
      '\u{16EB7}',
      '\u{16EB8}',
    ],
  ];

  /// Mode rapide : ordre optimisé par fréquence du corpus.
  static const List<List<String>> fastRows = [
    [
      '\u{16EA9}',
      '\u{16EA2}',
      '\u{16EA0}',
      '\u{16EA3}',
      '\u{16EA7}',
      '\u{16EAF}',
      '\u{16EB6}',
      '\u{16EB1}',
      '\u{16EAC}',
      '\u{16EB8}',
    ],
    [
      '\u{16EB5}',
      '\u{16EA5}',
      '\u{16EB2}',
      '\u{16EB3}',
      '\u{16EA1}',
      '\u{16EBB}',
      '\u{16EB7}',
      '\u{16EA8}',
      '\u{16EAE}',
    ],
    [
      '\u{16EA6}',
      '\u{16EA4}',
      '\u{16EAA}',
      '\u{16EB4}',
      '\u{16EB0}',
      '\u{16EAD}',
    ],
  ];

  /// Corrigé : pas de caractère hors des 25 officiels.
  /// Donc on remplace le mauvais U+16EBB par U+16EAB.
  static const List<List<String>> fastRowsOfficialOnly = [
    [
      '\u{16EA9}',
      '\u{16EA2}',
      '\u{16EA0}',
      '\u{16EA3}',
      '\u{16EA7}',
      '\u{16EAF}',
      '\u{16EB6}',
      '\u{16EB1}',
      '\u{16EAC}',
      '\u{16EB8}',
    ],
    [
      '\u{16EB5}',
      '\u{16EA5}',
      '\u{16EB2}',
      '\u{16EB3}',
      '\u{16EA1}',
      '\u{16EAB}',
      '\u{16EB7}',
      '\u{16EA8}',
      '\u{16EAE}',
    ],
    [
      '\u{16EA6}',
      '\u{16EA4}',
      '\u{16EAA}',
      '\u{16EB4}',
      '\u{16EB0}',
      '\u{16EAD}',
    ],
  ];

  static const List<List<String>> symbolRows = [
    ['.', ',', '?', '!', ':', ';'],
    ['-', '—', '(', ')', '«', '»'],
    ["'", '"', '/', '@', '&', '+'],
  ];

  static const Map<String, List<String>> longPressOptions = {
    '\u{16EA0}': ['\u{16EA0}\u{0304}'],
    '\u{16EA3}': ['\u{16EA3}\u{0304}'],
    '\u{16EA7}': ['\u{16EA7}\u{0304}'],
    '\u{16EAF}': ['\u{16EAF}\u{0304}'],
    '\u{16EB6}': ['\u{16EB6}\u{0304}'],
    '.': ['.', ',', '?', '!', ':', ';', '…'],
    '-': ['-', '—', '_'],
    "'": ["'", '"', '«', '»'],
  };
}