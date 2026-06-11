import '../utils/app_logger.dart';

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
    AppLogger.debug('SOURCE SET [$key] = ${source.name}');
  }

  ContentSourceType getSource(String key) {
    final source = _sources[key] ?? ContentSourceType.empty;
    AppLogger.debug('SOURCE GET [$key] = ${source.name}');
    return source;
  }

  void clear() {
    _sources.clear();
    AppLogger.debug('SOURCE CLEAR');
  }
}