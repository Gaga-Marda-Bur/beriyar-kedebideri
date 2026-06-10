class QuizQuestionModel {
  final int id;
  final int? unit;
  final String unitSlug;
  final int? lesson;
  final String lessonSlug;

  final String questionType;
  final String difficulty;

  final String promptText;
  final String promptTextFr;
  final String promptTextEn;
  final String promptTextAr;

  final String oralPrompt;
  final String oralPromptFr;
  final String oralPromptEn;
  final String oralPromptAr;

  final int? character;
  final String characterSymbol;
  final String characterName;

  final int? word;
  final String wordText;
  final String wordLatin;

  final String? questionImageUrl;
  final String? questionAudioUrl;
  final String? questionSlowAudioUrl;

  final String correctTextAnswer;
  final int correctIndex;

  final String explanation;
  final String explanationFr;
  final String explanationEn;
  final String explanationAr;
  final String? explanationAudioUrl;

  final int orderIndex;
  final int points;
  final int minOptionsRequired;

  final String status;
  final bool isActive;
  final bool availableOffline;

  final List<QuizOptionModel> options;
  final List<String> optionsTextFr;
  final List<String> optionsTextEn;
  final List<String> optionsTextAr;

  const QuizQuestionModel({
    required this.id,
    required this.unit,
    required this.unitSlug,
    required this.lesson,
    required this.lessonSlug,
    required this.questionType,
    required this.difficulty,
    required this.promptText,
    required this.promptTextFr,
    required this.promptTextEn,
    required this.promptTextAr,
    required this.oralPrompt,
    required this.oralPromptFr,
    required this.oralPromptEn,
    required this.oralPromptAr,
    required this.character,
    required this.characterSymbol,
    required this.characterName,
    required this.word,
    required this.wordText,
    required this.wordLatin,
    required this.questionImageUrl,
    required this.questionAudioUrl,
    required this.questionSlowAudioUrl,
    required this.correctTextAnswer,
    required this.correctIndex,
    required this.explanation,
    required this.explanationFr,
    required this.explanationEn,
    required this.explanationAr,
    required this.explanationAudioUrl,
    required this.orderIndex,
    required this.points,
    required this.minOptionsRequired,
    required this.status,
    required this.isActive,
    required this.availableOffline,
    required this.options,
    required this.optionsTextFr,
    required this.optionsTextEn,
    required this.optionsTextAr,
  });

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return QuizQuestionModel(
      id: _asInt(json['id']),
      unit: json['unit'] == null ? null : _asInt(json['unit']),
      unitSlug: _asString(json['unit_slug']),
      lesson: json['lesson'] == null ? null : _asInt(json['lesson']),
      lessonSlug: _asString(json['lesson_slug']),
      questionType: _asString(json['question_type']),
      difficulty: _asString(json['difficulty']),
      promptText: _asString(json['prompt_text']),
      promptTextFr: _asString(json['prompt_text_fr']),
      promptTextEn: _asString(json['prompt_text_en']),
      promptTextAr: _asString(json['prompt_text_ar']),
      oralPrompt: _asString(json['oral_prompt']),
      oralPromptFr: _asString(json['oral_prompt_fr']),
      oralPromptEn: _asString(json['oral_prompt_en']),
      oralPromptAr: _asString(json['oral_prompt_ar']),
      character: json['character'] == null ? null : _asInt(json['character']),
      characterSymbol: _asString(json['character_symbol']),
      characterName: _asString(json['character_name']),
      word: json['word'] == null ? null : _asInt(json['word']),
      wordText: _asString(json['word_text']),
      wordLatin: _asString(json['word_latin']),
      questionImageUrl: _asNullableString(json['question_image_url']),
      questionAudioUrl: _asNullableString(json['question_audio_url']),
      questionSlowAudioUrl: _asNullableString(json['question_slow_audio_url']),
      correctTextAnswer: _asString(json['correct_text_answer']),
      correctIndex: _asInt(json['correct_index']),
      explanation: _asString(json['explanation']),
      explanationFr: _asString(json['explanation_fr_out']),
      explanationEn: _asString(json['explanation_en_out']),
      explanationAr: _asString(json['explanation_ar_out']),
      explanationAudioUrl: _asNullableString(json['explanation_audio_url']),
      orderIndex: _asInt(json['order_index']),
      points: _asInt(json['points']),
      minOptionsRequired: _asInt(json['min_options_required']),
      status: _asString(json['status']),
      isActive: _asBool(json['is_active']),
      availableOffline: _asBool(json['available_offline']),
      options: _asMapList(json['options'])
          .map((item) => QuizOptionModel.fromJson(item))
          .toList(),
      optionsTextFr: _asStringList(json['options_text_fr']),
      optionsTextEn: _asStringList(json['options_text_en']),
      optionsTextAr: _asStringList(json['options_text_ar']),
    );
  }

  bool get hasAudio => questionAudioUrl != null && questionAudioUrl!.isNotEmpty;

  bool get isAudioQuestion {
    return questionType == 'audio_to_character' ||
        questionType == 'audio_to_image' ||
        questionType == 'listen_and_repeat';
  }

  static List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is List) return value.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    return [];
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static String? _asNullableString(dynamic value) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? null : text;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    return value?.toString() == 'true' || value?.toString() == '1';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'unit': unit,
      'unit_slug': unitSlug,
      'lesson': lesson,
      'lesson_slug': lessonSlug,
      'question_type': questionType,
      'difficulty': difficulty,
      'prompt_text': promptText,
      'prompt_text_fr': promptTextFr,
      'prompt_text_en': promptTextEn,
      'prompt_text_ar': promptTextAr,
      'oral_prompt': oralPrompt,
      'oral_prompt_fr': oralPromptFr,
      'oral_prompt_en': oralPromptEn,
      'oral_prompt_ar': oralPromptAr,
      'character': character,
      'character_symbol': characterSymbol,
      'character_name': characterName,
      'word': word,
      'word_text': wordText,
      'word_latin': wordLatin,
      'question_image_url': questionImageUrl,
      'question_audio_url': questionAudioUrl,
      'question_slow_audio_url': questionSlowAudioUrl,
      'correct_text_answer': correctTextAnswer,
      'correct_index': correctIndex,
      'explanation': explanation,
      'explanation_fr_out': explanationFr,
      'explanation_en_out': explanationEn,
      'explanation_ar_out': explanationAr,
      'explanation_audio_url': explanationAudioUrl,
      'order_index': orderIndex,
      'points': points,
      'min_options_required': minOptionsRequired,
      'status': status,
      'is_active': isActive,
      'available_offline': availableOffline,
      'options': options.map((item) => item.toJson()).toList(),
      'options_text_fr': optionsTextFr,
      'options_text_en': optionsTextEn,
      'options_text_ar': optionsTextAr,
    };
  }
}

class QuizOptionModel {
  final int id;
  final int question;

  final String text;
  final String textFr;
  final String textEn;
  final String textAr;
  final String textFrOut;
  final String textEnOut;
  final String textArOut;

  final int? character;
  final String characterSymbol;
  final String characterName;
  final String characterLatin;

  final int? word;
  final String wordText;
  final String wordLatin;

  final String? imageUrl;
  final int orderIndex;

  const QuizOptionModel({
    required this.id,
    required this.question,
    required this.text,
    required this.textFr,
    required this.textEn,
    required this.textAr,
    required this.textFrOut,
    required this.textEnOut,
    required this.textArOut,
    required this.character,
    required this.characterSymbol,
    required this.characterName,
    required this.characterLatin,
    required this.word,
    required this.wordText,
    required this.wordLatin,
    required this.imageUrl,
    required this.orderIndex,
  });

  factory QuizOptionModel.fromJson(Map<String, dynamic> json) {
    return QuizOptionModel(
      id: _asInt(json['id']),
      question: _asInt(json['question']),
      text: _asString(json['text']),
      textFr: _asString(json['text_fr']),
      textEn: _asString(json['text_en']),
      textAr: _asString(json['text_ar']),
      textFrOut: _asString(json['text_fr_out'] ?? json['text']),
      textEnOut: _asString(json['text_en_out'] ?? json['text']),
      textArOut: _asString(json['text_ar_out'] ?? json['text']),
      character: json['character'] == null ? null : _asInt(json['character']),
      characterSymbol: _asString(json['character_symbol']),
      characterName: _asString(json['character_name']),
      characterLatin: _asString(json['character_latin']),
      word: json['word'] == null ? null : _asInt(json['word']),
      wordText: _asString(json['word_text']),
      wordLatin: _asString(json['word_latin']),
      imageUrl: _asNullableString(json['image_url']),
      orderIndex: _asInt(json['order_index']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static String? _asNullableString(dynamic value) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? null : text;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'text': text,
      'text_fr': textFr,
      'text_en': textEn,
      'text_ar': textAr,
      'text_fr_out': textFrOut,
      'text_en_out': textEnOut,
      'text_ar_out': textArOut,
      'character': character,
      'character_symbol': characterSymbol,
      'character_name': characterName,
      'character_latin': characterLatin,
      'word': word,
      'word_text': wordText,
      'word_latin': wordLatin,
      'image_url': imageUrl,
      'order_index': orderIndex,
    };
  }
}