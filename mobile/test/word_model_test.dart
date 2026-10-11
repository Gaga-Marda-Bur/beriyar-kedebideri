import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/vocabulary/models/word_model.dart';

void main() {
  group('WordModel deserialization tests', () {
    test('arabicTranslation uses arabic_translation and not arabic_transcription', () {
      final json = {
        'id': 1,
        'beriya_text': '𖺡𖺣',
        'latin_transcription': 'be',
        'arabic_transcription': 'بِي',
        'french_translation': 'pays',
        'english_translation': 'country',
        'arabic_translation': 'بلد',
        'category_slug': 'general',
        'category_fr': 'Général',
        'difficulty': 'beginner',
        'orthographic_pattern': 'CV',
        'syllabic_structure': 'CV',
      };

      final word = WordModel.fromJson(json);

      expect(word.beriyaText, equals('𖺡𖺣'));
      expect(word.latinTranscription, equals('be'));
      expect(word.arabicTranscription, equals('بِي'));
      expect(word.frenchTranslation, equals('pays'));
      expect(word.englishTranslation, equals('country'));
      // Regression check: must be the actual translation ("بلد"), NOT the transcription ("بِي")
      expect(word.arabicTranslation, equals('بلد'));
      expect(word.translationAr, equals('بلد'));
      expect(word.arabicTranslation, isNot(equals(word.arabicTranscription)));
    });

    test('arabicTranslation falls back to translation_ar if arabic_translation is omitted', () {
      final json = {
        'id': 2,
        'beriya_text': '𖺵𖺠',
        'latin_transcription': 'ta',
        'arabic_transcription': 'تا',
        'translation_ar': 'بيت',
        'translation_fr': 'maison',
      };

      final word = WordModel.fromJson(json);

      expect(word.arabicTranslation, equals('بيت'));
      expect(word.translationAr, equals('بيت'));
    });
  });
}
