import '../../alphabet/models/character_model.dart';
import '../../vocabulary/models/word_model.dart';

class LearningUnitModel {
  final int id;
  final int theme;
  final String themeSlug;
  final String themeTitleFr;
  final String themeTitleEn;
  final String themeTitleAr;

  final String slug;
  final String titleFr;
  final String titleEn;
  final String titleAr;
  final String descriptionFr;
  final String descriptionEn;
  final String descriptionAr;

  final String level;
  final List<CharacterModel> characters;
  final List<CharacterModel> distractorCharacters;
  final List<WordModel> words;
  final WordModel? targetWord;
  final List<int> characterIds;
  final List<int> distractorCharacterIds;
  final List<int> wordIds;
  final int weightRecognition;
  final int weightTracing;
  final int weightEncoding;
  final bool enableTracing;
  final Map<String, dynamic> pedagogyConfig;
  final List<Map<String, dynamic>> coreFlow;

  final int estimatedMinutes;
  final int minScoreToPass;
  final int orderIndex;
  final String status;
  final bool isActive;
  final bool availableOffline;

  const LearningUnitModel({
    required this.id,
    required this.theme,
    required this.themeSlug,
    required this.themeTitleFr,
    required this.themeTitleEn,
    required this.themeTitleAr,
    required this.slug,
    required this.titleFr,
    required this.titleEn,
    required this.titleAr,
    required this.descriptionFr,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.level,
    required this.characters,
    this.distractorCharacters = const [],
    required this.words,
    this.targetWord,
    required this.characterIds,
    this.distractorCharacterIds = const [],
    required this.wordIds,
    this.weightRecognition = 35,
    this.weightTracing = 35,
    this.weightEncoding = 30,
    this.enableTracing = false,
    this.pedagogyConfig = const {},
    this.coreFlow = const [],
    required this.estimatedMinutes,
    required this.minScoreToPass,
    required this.orderIndex,
    required this.status,
    required this.isActive,
    required this.availableOffline,
  });

  List<Map<String, dynamic>> get effectiveCoreFlow =>
      coreFlow.isNotEmpty ? coreFlow : _generateLocalCoreFlow();

  List<Map<String, dynamic>> _generateLocalCoreFlow() {
    final steps = <Map<String, dynamic>>[];
    final chars = characters;
    final distractors = distractorCharacters;
    final targetW = targetWord ?? (words.isNotEmpty ? words.first : null);

    for (int i = 0; i < chars.length; i++) {
      final c = chars[i];
      final isVowel = c.characterType == 'vowel';
      final isConsonant = c.characterType == 'consonant';
      final typeLabel = isVowel ? 'la voyelle' : (isConsonant ? 'la consonne' : 'le caractère');
      final ipaStr = c.phonemeIpa.isNotEmpty && c.phonemeIpa != 'À_VALIDER' ? ' /${c.phonemeIpa}/' : '';

      steps.add({
        'index': steps.length,
        'step_type': 'discovery',
        'symbol': c.symbol,
        'unicode_code': c.unicodeCode,
        'character_type': c.characterType,
        'phoneme_ipa': c.phonemeIpa,
        'label': 'Écoute et découvre $typeLabel$ipaStr',
        'audio_url': c.phonemeAudioUrl ?? c.audioUrl,
        'letter_name_audio_url': c.letterNameAudioUrl,
        'weight_category': 'recognition',
      });

      CharacterModel? other;
      for (final cand in [...chars.sublist(i + 1), ...chars.sublist(0, i)]) {
        if (cand.symbol != c.symbol) {
          other = cand;
          break;
        }
      }
      other ??= (distractors.isNotEmpty ? distractors.first : null);

      if (other != null) {
        steps.add({
          'index': steps.length,
          'step_type': 'discrimination',
          'target_symbol': c.symbol,
          'other_symbol': other.symbol,
          'phoneme_ipa': c.phonemeIpa,
          'instruction': 'Touche $typeLabel$ipaStr',
          'audio_url': c.phonemeAudioUrl ?? c.audioUrl,
          'weight_category': 'recognition',
        });
      }

      if (enableTracing) {
        steps.add({
          'index': steps.length,
          'step_type': 'tracing',
          'symbol': c.symbol,
          'unicode_code': c.unicodeCode,
          'character_type': c.characterType,
          'stroke_path_data': c.strokePathData,
          'instruction': 'Trace le caractère ${c.symbol} du bout du doigt',
          'weight_category': 'tracing',
        });
      }
    }

    if (targetW != null) {
      if (chars.length >= 2) {
        steps.add({
          'index': steps.length,
          'step_type': 'fusion',
          'components': chars.take(2).map((e) => e.symbol).toList(),
          'result_syllable': targetW.beriyaText,
          'phonemes': chars.take(2).map((e) => '/${e.phonemeIpa}/').join(' + '),
          'instruction': 'Écoute comment les sons fusionnent pour former une syllabe',
          'audio_url': targetW.syllableAudioUrl ?? targetW.audioUrl,
          'weight_category': 'recognition',
        });
      }

      steps.add({
        'index': steps.length,
        'step_type': 'word_decoding',
        'word': targetW.beriyaText,
        'latin_transcription': targetW.latinTranscription,
        'french_translation': targetW.frenchTranslation,
        'orthographic_pattern': targetW.orthographicPattern,
        'syllabic_structure': targetW.syllabicStructure,
        'oral_prompt': targetW.oralPrompt.isNotEmpty ? targetW.oralPrompt : 'Écoute et observe le mot complet',
        'audio_url': targetW.audioUrl,
        'image_url': targetW.imageUrl,
        'weight_category': 'recognition',
      });

      final keyboardKeys = <String>{
        ...chars.map((e) => e.symbol),
        ...distractors.map((e) => e.symbol),
      }.toList();

      steps.add({
        'index': steps.length,
        'step_type': 'keyboard_encoding',
        'target_word': targetW.beriyaText,
        'latin_transcription': targetW.latinTranscription,
        'french_translation': targetW.frenchTranslation,
        'keyboard_keys': keyboardKeys,
        'audio_url': targetW.audioUrl,
        'instruction': 'Écris le mot "${targetW.latinTranscription.isNotEmpty ? targetW.latinTranscription : targetW.beriyaText}" au clavier :',
        'weight_category': 'encoding',
      });
    }

    steps.add({
      'index': steps.length,
      'step_type': 'celebration',
      'title': 'Félicitations !',
      'message': 'Tu as validé l\'apprentissage de $titleFr !',
      'target_word': targetW?.beriyaText ?? '',
      'french_translation': targetW?.frenchTranslation ?? '',
      'weights': {
        'recognition': enableTracing ? weightRecognition : 50,
        'tracing': enableTracing ? weightTracing : 0,
        'encoding': enableTracing ? weightEncoding : 50,
      },
    });

    return steps;
  }

  factory LearningUnitModel.fromJson(Map<String, dynamic> json) {
    return LearningUnitModel(
      id: _asInt(json['id']),
      theme: _asInt(json['theme']),
      themeSlug: _asString(json['theme_slug']),
      themeTitleFr: _asString(json['theme_title_fr']),
      themeTitleEn: _asString(json['theme_title_en']),
      themeTitleAr: _asString(json['theme_title_ar']),
      slug: _asString(json['slug']),
      titleFr: _asString(json['title_fr']),
      titleEn: _asString(json['title_en']),
      titleAr: _asString(json['title_ar']),
      descriptionFr: _asString(json['description_fr']),
      descriptionEn: _asString(json['description_en']),
      descriptionAr: _asString(json['description_ar']),
      level: _asString(json['level']),
      characters: _asMapList(json['characters'])
          .map((item) => CharacterModel.fromJson(item))
          .toList(),
      distractorCharacters: _asMapList(json['distractor_characters'])
          .map((item) => CharacterModel.fromJson(item))
          .toList(),
      words: _asMapList(json['words'])
          .map((item) => WordModel.fromJson(item))
          .toList(),
      targetWord: json['target_word'] is Map<String, dynamic>
          ? WordModel.fromJson(json['target_word'] as Map<String, dynamic>)
          : null,
      characterIds: _asIntList(
        json['character_ids'] ??
            (json['characters'] is List
                ? (json['characters'] as List).map((item) {
                    if (item is Map<String, dynamic>) return item['id'];
                    return item;
                  }).toList()
                : []),
      ),
      distractorCharacterIds: _asIntList(
        json['distractor_character_ids'] ??
            (json['distractor_characters'] is List
                ? (json['distractor_characters'] as List).map((item) {
                    if (item is Map<String, dynamic>) return item['id'];
                    return item;
                  }).toList()
                : []),
      ),
      wordIds: _asIntList(
        json['word_ids'] ??
            (json['words'] is List
                ? (json['words'] as List).map((item) {
                    if (item is Map<String, dynamic>) return item['id'];
                    return item;
                  }).toList()
                : []),
      ),
      weightRecognition: _asInt(json['weight_recognition'] ?? 35),
      weightTracing: _asInt(json['weight_tracing'] ?? 35),
      weightEncoding: _asInt(json['weight_encoding'] ?? 30),
      enableTracing: _asBool(json['enable_tracing']),
      pedagogyConfig: json['pedagogy_config'] is Map<String, dynamic>
          ? json['pedagogy_config'] as Map<String, dynamic>
          : {},
      coreFlow: _asMapList(json['core_flow']),
      estimatedMinutes: _asInt(json['estimated_minutes']),
      minScoreToPass: _asInt(json['min_score_to_pass']),
      orderIndex: _asInt(json['order_index']),
      status: _asString(json['status']),
      isActive: _asBool(json['is_active']),
      availableOffline: _asBool(json['available_offline']),
    );
  }

  static List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is List) return value.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  static List<int> _asIntList(dynamic value) {
    if (value is List) {
      return value.map((item) => _asInt(item)).toList();
    }
    return [];
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    return value?.toString() == 'true' || value?.toString() == '1';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'theme': theme,
      'theme_slug': themeSlug,
      'theme_title_fr': themeTitleFr,
      'theme_title_en': themeTitleEn,
      'theme_title_ar': themeTitleAr,
      'slug': slug,
      'title_fr': titleFr,
      'title_en': titleEn,
      'title_ar': titleAr,
      'description_fr': descriptionFr,
      'description_en': descriptionEn,
      'description_ar': descriptionAr,
      'level': level,
      'characters': characters.map((item) => item.toJson()).toList(),
      'distractor_characters': distractorCharacters.map((item) => item.toJson()).toList(),
      'words': words.map((item) => item.toJson()).toList(),
      'target_word': targetWord?.toJson(),
      'character_ids': characterIds,
      'distractor_character_ids': distractorCharacterIds,
      'word_ids': wordIds,
      'weight_recognition': weightRecognition,
      'weight_tracing': weightTracing,
      'weight_encoding': weightEncoding,
      'enable_tracing': enableTracing,
      'pedagogy_config': pedagogyConfig,
      'core_flow': coreFlow,
      'estimated_minutes': estimatedMinutes,
      'min_score_to_pass': minScoreToPass,
      'order_index': orderIndex,
      'status': status,
      'is_active': isActive,
      'available_offline': availableOffline,
    };
  }
}