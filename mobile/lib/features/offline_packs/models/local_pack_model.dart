class LocalPackModel {
  final Map<String, dynamic> metadata;
  final List<dynamic> themes;
  final List<dynamic> units;
  final List<dynamic> characters;
  final List<dynamic> words;
  final List<dynamic> lessons;
  final List<dynamic> quizzes;
  final String localPath;

  const LocalPackModel({
    required this.metadata,
    required this.themes,
    required this.units,
    required this.characters,
    required this.words,
    required this.lessons,
    required this.quizzes,
    required this.localPath,
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
}