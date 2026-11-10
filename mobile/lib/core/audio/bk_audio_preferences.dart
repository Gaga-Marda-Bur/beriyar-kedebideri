import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférences utilisateur pour le comportement audio dans les séances (Lot 4B.1).
@immutable
class BkAudioPreferences {
  final bool autoPlayAudio;

  const BkAudioPreferences({
    required this.autoPlayAudio,
  });

  static const BkAudioPreferences defaults = BkAudioPreferences(
    autoPlayAudio: true,
  );

  BkAudioPreferences copyWith({
    bool? autoPlayAudio,
  }) {
    return BkAudioPreferences(
      autoPlayAudio: autoPlayAudio ?? this.autoPlayAudio,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BkAudioPreferences && other.autoPlayAudio == autoPlayAudio;
  }

  @override
  int get hashCode => autoPlayAudio.hashCode;
}

/// Service de persistance locale de la préférence de lecture automatique de l'audio.
class BkAudioPreferencesService {
  BkAudioPreferencesService._();

  static const String _autoPlayKey = 'bk_audio_auto_play';

  static Future<BkAudioPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final autoPlay = prefs.getBool(_autoPlayKey) ?? BkAudioPreferences.defaults.autoPlayAudio;
    return BkAudioPreferences(autoPlayAudio: autoPlay);
  }

  static Future<void> save(BkAudioPreferences value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPlayKey, value.autoPlayAudio);
  }

  static Future<bool> isAutoPlayEnabled() async {
    final prefs = await load();
    return prefs.autoPlayAudio;
  }

  static Future<void> setAutoPlayAudio(bool enabled) async {
    await save(BkAudioPreferences(autoPlayAudio: enabled));
  }
}
