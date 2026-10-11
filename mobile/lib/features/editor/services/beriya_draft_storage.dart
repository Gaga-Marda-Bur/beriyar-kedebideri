import 'package:shared_preferences/shared_preferences.dart';

import '../models/beriya_draft.dart';

class BeriyaDraftStorage {
  static const String _activeDraftKey = 'beriya_editor_active_draft';

  static Future<BeriyaDraft> loadActiveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_activeDraftKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return BeriyaDraft.fromJson(jsonStr);
      }
    } catch (_) {
      // Fallback on read error
    }
    return BeriyaDraft.initial();
  }

  static Future<bool> saveDraft(BeriyaDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_activeDraftKey, draft.toJson());
    } catch (_) {
      return false;
    }
  }

  static Future<bool> clearActiveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_activeDraftKey);
    } catch (_) {
      return false;
    }
  }
}
