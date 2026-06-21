import 'package:shared_preferences/shared_preferences.dart';

import 'beriya_keyboard_preferences.dart';

class BeriyaKeyboardPreferencesService {
  BeriyaKeyboardPreferencesService._();

  static const String _layoutKey = 'beriya_keyboard_layout';
  static const String _inputModeKey = 'beriya_keyboard_input_mode';
  static const String _handKey = 'beriya_keyboard_hand';

  static Future<BeriyaKeyboardPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();

    final layoutRaw = prefs.getString(_layoutKey);
    final inputModeRaw = prefs.getString(_inputModeKey);
    final handRaw = prefs.getString(_handKey);

    return BeriyaKeyboardPreferences(
      layout: _layoutFromString(layoutRaw),
      inputMode: _inputModeFromString(inputModeRaw),
      hand: _handFromString(handRaw),
    );
  }

  static Future<void> save(BeriyaKeyboardPreferences value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_layoutKey, value.layout.name);
    await prefs.setString(_inputModeKey, value.inputMode.name);
    await prefs.setString(_handKey, value.hand.name);
  }

  static BeriyaKeyboardLayoutPreference _layoutFromString(String? value) {
    switch (value) {
      case 'abc':
        return BeriyaKeyboardLayoutPreference.abc;
      case 'fast':
      default:
        return BeriyaKeyboardLayoutPreference.fast;
    }
  }

  static BeriyaInputModePreference _inputModeFromString(String? value) {
    switch (value) {
      case 'system':
        return BeriyaInputModePreference.system;
      case 'beriya':
      default:
        return BeriyaInputModePreference.beriya;
    }
  }

  static BeriyaHandPreference _handFromString(String? value) {
    switch (value) {
      case 'left':
        return BeriyaHandPreference.left;
      case 'right':
      default:
        return BeriyaHandPreference.right;
    }
  }
}