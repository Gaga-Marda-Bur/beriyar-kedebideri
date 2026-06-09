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

    for (final field in fields) {
      map[field] = resolve(
        value: map[field]?.toString(),
        localPackPath: localPackPath,
      );
    }

    return map;
  }
}