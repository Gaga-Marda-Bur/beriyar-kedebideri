enum FeedbackCategory {
  pronunciation,
  translation,
  audioQuality,
  wrongCharacter,
  wrongWord,
  wrongImage,
  technical,
  contentSuggestion,
  other,
}

extension FeedbackCategoryX on FeedbackCategory {
  String get value {
    switch (this) {
      case FeedbackCategory.pronunciation:
        return 'pronunciation';
      case FeedbackCategory.translation:
        return 'translation';
      case FeedbackCategory.audioQuality:
        return 'audio_quality';
      case FeedbackCategory.wrongCharacter:
        return 'wrong_character';
      case FeedbackCategory.wrongWord:
        return 'wrong_word';
      case FeedbackCategory.wrongImage:
        return 'wrong_image';
      case FeedbackCategory.technical:
        return 'technical';
      case FeedbackCategory.contentSuggestion:
        return 'content_suggestion';
      case FeedbackCategory.other:
        return 'other';
    }
  }
}