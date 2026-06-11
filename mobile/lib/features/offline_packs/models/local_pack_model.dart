class LocalPackModel {
  final Map<String, dynamic> metadata;
  final List<dynamic> themes;
  final List<dynamic> units;
  final List<dynamic> characters;
  final List<dynamic> words;
  final List<dynamic> lessons;
  final List<dynamic> quizzes;
  final String localPath;
  final int sizeBytes;
  final DateTime? downloadedAt;

  const LocalPackModel({
    required this.metadata,
    required this.themes,
    required this.units,
    required this.characters,
    required this.words,
    required this.lessons,
    required this.quizzes,
    required this.localPath,
    required this.sizeBytes,
    required this.downloadedAt,
  });

  String get slug => metadata['slug']?.toString() ?? '';
  int get version => int.tryParse(metadata['version']?.toString() ?? '') ?? 0;

  String titleForLang(String lang) {
    if (lang == 'ar') {
      return metadata['title_ar']?.toString() ??
          metadata['title_fr']?.toString() ??
          slug;
    }

    if (lang == 'en') {
      return metadata['title_en']?.toString() ??
          metadata['title_fr']?.toString() ??
          slug;
    }

    return metadata['title_fr']?.toString() ?? slug;
  }

  int get itemsCount {
    return int.tryParse(metadata['items_count']?.toString() ?? '') ??
        themes.length +
            units.length +
            characters.length +
            words.length +
            lessons.length +
            quizzes.length;
  }

  String get formattedSize {
    if (sizeBytes <= 0) return '—';

    final kb = sizeBytes / 1024;
    final mb = kb / 1024;

    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }

    return '${kb.toStringAsFixed(1)} KB';
  }

  String get formattedDownloadedAt {
    final value = downloadedAt;

    if (value == null) return '—';

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();

    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }
}