class MemoryContentCache {
  static final MemoryContentCache instance = MemoryContentCache._internal();

  MemoryContentCache._internal();

  final Map<String, dynamic> _store = {};
  final Map<String, DateTime> _savedAt = {};

  T? get<T>(String key, {Duration? maxAge}) {
    if (!_store.containsKey(key)) return null;

    if (maxAge != null) {
      final savedAt = _savedAt[key];

      if (savedAt == null) {
        remove(key);
        return null;
      }

      final age = DateTime.now().difference(savedAt);

      if (age > maxAge) {
        remove(key);
        return null;
      }
    }

    final value = _store[key];

    if (value is T) {
      return value;
    }

    return null;
  }

  void set<T>(String key, T value) {
    _store[key] = value;
    _savedAt[key] = DateTime.now();
  }

  void remove(String key) {
    _store.remove(key);
    _savedAt.remove(key);
  }

  void clear() {
    _store.clear();
    _savedAt.clear();
  }
}