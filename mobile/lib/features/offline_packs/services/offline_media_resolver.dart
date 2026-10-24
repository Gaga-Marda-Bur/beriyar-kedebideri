class OfflineMediaResolver {
  static String? resolve({
    required String? value,
    required String localPackPath,
  }) {
    if (value == null || value.isEmpty) return null;

    final trimmed = value.trim();

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    if (trimmed.startsWith('/')) {
      return trimmed;
    }

    if (trimmed.contains(':\\')) {
      return trimmed;
    }

    final normalized = trimmed
        .replaceAll('\\', '/')
        .replaceFirst('./', '')
        .replaceFirst('media/', '');

    return '$localPackPath/$normalized';
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
