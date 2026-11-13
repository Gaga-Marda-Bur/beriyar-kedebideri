class OfflineMediaResolver {
  static String? resolve({
    required String? value,
    required String localPackPath,
  }) {
    if (value == null || value.isEmpty) return null;

    final trimmed = value.trim();

    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('assets/')) {
      return trimmed;
    }

    final normalizedPack = _normalizePath(localPackPath);
    if (normalizedPack.isEmpty) return null;
    final rawPack = localPackPath.trim().replaceFirst(RegExp(r'[/\\]+$'), '');

    final unixLike = trimmed.replaceAll('\\', '/');

    if (unixLike.startsWith('/media/')) {
      return _joinInsidePack(rawPack, unixLike.substring('/media/'.length));
    }

    if (unixLike.startsWith('/') || RegExp(r'^[A-Za-z]:/').hasMatch(unixLike)) {
      return _isInsidePack(normalizedPack, unixLike) ? trimmed : null;
    }

    var rel = unixLike;
    if (rel.startsWith('./')) {
      rel = rel.substring(2);
    }
    if (rel.startsWith('media/')) {
      rel = rel.substring('media/'.length);
    }

    return _joinInsidePack(rawPack, rel);
  }

  static String _normalizePath(String path) {
    final replaced = path.replaceAll('\\', '/').trim();
    return replaced.endsWith('/') && replaced.length > 1
        ? replaced.substring(0, replaced.length - 1)
        : replaced;
  }

  static bool _hasTraversal(String path) {
    return path.split('/').any((seg) => seg == '..');
  }

  static bool _isInsidePack(String normalizedPack, String candidate) {
    final normCandidate = _normalizePath(candidate);
    if (_hasTraversal(normCandidate)) return false;
    return normCandidate == normalizedPack ||
        normCandidate.startsWith('$normalizedPack/');
  }

  static String? _joinInsidePack(String normalizedPack, String relative) {
    final cleaned = relative.replaceFirst(RegExp(r'^/+'), '');
    if (cleaned.isEmpty || _hasTraversal(cleaned)) return null;
    return '$normalizedPack/$cleaned';
  }

  static Map<String, dynamic> resolveFields(
    Map<String, dynamic> raw, {
    required String localPackPath,
    required List<String> fields,
  }) {
    final map = Map<String, dynamic>.from(raw);

    for (final field in {...fields, ...raw.keys.where(_isMediaField)}) {
      map[field] = resolve(
        value: map[field]?.toString(),
        localPackPath: localPackPath,
      );
    }

    if (raw['core_flow'] is List) {
      map['core_flow'] = _resolveFlow(raw['core_flow'], localPackPath);
    }

    return map;
  }

  static bool _isMediaField(String key) =>
      key == 'audio_url' ||
      key.endsWith('_audio_url') ||
      key == 'image_url' ||
      key.endsWith('_image_url');

  static dynamic _resolveFlow(dynamic value, String packPath) {
    if (value is List) {
      return value.map((item) => _resolveFlow(item, packPath)).toList();
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(
          key.toString(),
          _isMediaField(key.toString()) && item is String
              ? resolve(value: item, localPackPath: packPath)
              : _resolveFlow(item, packPath),
        ),
      );
    }
    return value;
  }
}
