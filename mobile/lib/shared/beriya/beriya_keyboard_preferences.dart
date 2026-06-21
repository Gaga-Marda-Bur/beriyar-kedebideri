enum BeriyaKeyboardLayoutPreference {
  fast,
  abc,
}

enum BeriyaInputModePreference {
  beriya,
  system,
}

enum BeriyaHandPreference {
  right,
  left,
}

class BeriyaKeyboardPreferences {
  const BeriyaKeyboardPreferences({
    required this.layout,
    required this.inputMode,
    required this.hand,
  });

  final BeriyaKeyboardLayoutPreference layout;
  final BeriyaInputModePreference inputMode;
  final BeriyaHandPreference hand;

  static const defaults = BeriyaKeyboardPreferences(
    layout: BeriyaKeyboardLayoutPreference.fast,
    inputMode: BeriyaInputModePreference.beriya,
    hand: BeriyaHandPreference.right,
  );

  BeriyaKeyboardPreferences copyWith({
    BeriyaKeyboardLayoutPreference? layout,
    BeriyaInputModePreference? inputMode,
    BeriyaHandPreference? hand,
  }) {
    return BeriyaKeyboardPreferences(
      layout: layout ?? this.layout,
      inputMode: inputMode ?? this.inputMode,
      hand: hand ?? this.hand,
    );
  }
}