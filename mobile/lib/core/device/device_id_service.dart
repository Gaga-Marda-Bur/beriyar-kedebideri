import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  static const String _key = 'bk_device_id';
  static const String _tokenKey = 'bk_device_token';

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    final existing = prefs.getString(_key);

    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated = const Uuid().v4();
    await prefs.setString(_key, generated);

    return generated;
  }

  /// Retourne ou génère le jeton secret d'installation lié au terminal (A01).
  Future<String> getOrCreateDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();

    final existing = prefs.getString(_tokenKey);

    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated = const Uuid().v4();
    await prefs.setString(_tokenKey, generated);

    return generated;
  }
}
