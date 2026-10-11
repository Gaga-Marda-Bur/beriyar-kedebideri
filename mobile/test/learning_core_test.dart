import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/learning/models/learning_unit_model.dart';

void main() {
  group('LearningUnitModel & CoreFlow tests', () {
    test('effectiveCoreFlow generates 5-step active flow when core_flow is empty', () {
      final unit = LearningUnitModel.fromJson({
        'id': 1,
        'title_fr': 'Unité 1 : Be (𖺡)',
        'slug': 'unite-1',
        'level': 'beginner',
        'enable_tracing': false,
        'weight_recognition': 50,
        'weight_tracing': 0,
        'weight_encoding': 50,
        'characters': [
          {
            'id': 1,
            'name_fr': 'Be',
            'phoneme_ipa': 'b',
            'symbol': '𖺡',
            'character': '𖺡',
            'latin_transcription': 'b',
            'character_type': 'consonant',
            'order_index': 1,
          },
          {
            'id': 2,
            'name_fr': 'E',
            'phoneme_ipa': 'e',
            'symbol': '𖺣',
            'character': '𖺣',
            'latin_transcription': 'e',
            'character_type': 'vowel',
            'order_index': 2,
          },
        ],
        'distractor_characters': [
          {
            'id': 3,
            'name_fr': 'A',
            'phoneme_ipa': 'a',
            'symbol': '𖺠',
            'character': '𖺠',
            'latin_transcription': 'a',
            'character_type': 'vowel',
            'order_index': 3,
          },
        ],
        'words': [
          {
            'id': 1,
            'beriya_text': '𖺡𖺣',
            'latin_transcription': 'be',
            'french_translation': 'pays',
            'english_translation': 'country',
            'arabic_translation': 'بلد',
          }
        ],
      });

      final flow = unit.effectiveCoreFlow;
      expect(flow.isNotEmpty, isTrue);

      final stepTypes = flow.map((s) => s['step_type']).toList();
      expect(stepTypes.contains('discovery'), isTrue);
      expect(stepTypes.contains('discrimination'), isTrue);
      expect(stepTypes.contains('fusion'), isTrue);
      expect(stepTypes.contains('word_decoding'), isTrue);
      expect(stepTypes.contains('keyboard_encoding'), isTrue);
      expect(stepTypes.contains('celebration'), isTrue);
    });

    test('effectiveCoreFlow uses backend core_flow when provided', () {
      final unit = LearningUnitModel.fromJson({
        'id': 1,
        'title_fr': 'Unité 1',
        'slug': 'unite-1',
        'characters': [],
        'words': [],
        'core_flow': [
          {'step_type': 'discovery', 'symbol': '𖺡'},
          {'step_type': 'celebration', 'title': 'Bravo'},
        ],
      });

      final flow = unit.effectiveCoreFlow;
      expect(flow.length, 2);
      expect(flow[0]['step_type'], 'discovery');
      expect(flow[1]['step_type'], 'celebration');
    });
  });
}
