enum ContentSourceType {
  online,
  memory,
  localCache,
  offlinePack,
  empty,
}

class ContentSourceState {
  static final ContentSourceState instance = ContentSourceState._internal();

  ContentSourceState._internal();

  final Map<String, ContentSourceType> _sources = {};

  void setSource(String key, ContentSourceType source) {
    _sources[key] = source;
  }

  ContentSourceType getSource(String key) {
    return _sources[key] ?? ContentSourceType.empty;
  }

  void clear() {
    _sources.clear();
  }
}