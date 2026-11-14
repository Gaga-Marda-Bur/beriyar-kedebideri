import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/learning/engine/learning_session.dart';
import 'package:mobile/features/learning/models/learning_unit_model.dart';

void main() {
  group('BK-LEARN Parcours Alphabet Erfe V1 sans audio', () {
    LearningUnitModel buildErf01({String? audioUrl}) {
      final letters = [
        ('𖺠', 'U+16EA0', 'A'),
        ('𖺡', 'U+16EA1', 'B'),
        ('𖺢', 'U+16EA2', 'D'),
        ('𖺣', 'U+16EA3', 'E'),
        ('𖺤', 'U+16EA4', 'F'),
      ];
      return LearningUnitModel.fromJson({
        'id': 101,
        'theme': 10,
        'theme_slug': 'bk-preprod-alphabet-erfe',
        'theme_title_fr': 'Alphabet Erfe (Préproduction)',
        'slug': 'bk-preprod-erf-01',
        'title_fr': 'Alphabet Erfe — groupe 1',
        'description_fr': 'Identifier les caractères Erfe et leurs équivalents latins.',
        'level': 'beginner',
        'characters': [
          for (int i = 0; i < letters.length; i++)
            {
              'id': i + 1,
              'symbol': letters[i].$1,
              'unicode_code': letters[i].$2,
              'name_fr': 'Lettre latine ${letters[i].$3}',
              'latin_transcription': letters[i].$3,
              'character_type': 'unknown',
              'order_index': i + 1,
              'validation_status': 'validated',
              'is_active': true,
              'available_offline': true,
              'audio_url': audioUrl ?? '',
            },
        ],
        'words': const [],
        'character_ids': [1, 2, 3, 4, 5],
        'word_ids': const [],
        'weight_recognition': 50,
        'weight_tracing': 0,
        'weight_encoding': 50,
        'enable_tracing': false,
        'estimated_minutes': 5,
        'min_score_to_pass': 70,
        'order_index': 1,
        'status': 'validated',
        'is_active': true,
        'available_offline': true,
      });
    }

    test('génère découverte, discrimination sans audio, clavier Erfe et bilan cohérent', () {
      final unit = buildErf01();
      final flow = unit.effectiveCoreFlow;

      final types = flow.map((s) => s['step_type']).toList();
      expect(types.where((t) => t == 'discovery').length, 5);
      expect(types.where((t) => t == 'discrimination').length, 5);
      expect(types.where((t) => t == 'keyboard_encoding').length, 1);
      expect(types.last, 'celebration');

      final firstDisc = flow.firstWhere((s) => s['step_type'] == 'discrimination');
      expect(firstDisc['instruction'], contains('« A »'));

      final enc = flow.firstWhere((s) => s['step_type'] == 'keyboard_encoding');
      expect(enc['target_word'], '𖺠');
      expect((enc['keyboard_keys'] as List).length, 5);

      // Parcours complet sans audio -> score 100%, réussite, sauvegarde/reprise JSON
      final session = LearningSession(flow, {'recognition': 50, 'tracing': 0, 'encoding': 50}, 70);
      for (int i = 0; i < flow.length - 1; i++) {
        session.currentStep = i;
        session.viewed.add(i);
        if (LearningSession.category(flow[i]) != null) {
          session.answer(true);
        }
        expect(session.canAdvance, isTrue);
      }
      expect(session.canFinish, isTrue);
      expect(session.score, 100);
      expect(session.passed, isTrue);

      // Reprise depuis sauvegarde JSON
      final saved = session.toJson();
      final restored = LearningSession(flow, {'recognition': 50, 'tracing': 0, 'encoding': 50}, 70)
        ..restore(saved);
      expect(restored.score, 100);
      expect(restored.passed, isTrue);
    });

    test('ajout ultérieur des URLs audio préserve la révision de progression', () {
      final withoutAudio = buildErf01();
      final withAudio = buildErf01(audioUrl: '/media/audio/a.mp3');

      final s1 = LearningSession(withoutAudio.effectiveCoreFlow, {'recognition': 50, 'tracing': 0, 'encoding': 50}, 70);
      final s2 = LearningSession(withAudio.effectiveCoreFlow, {'recognition': 50, 'tracing': 0, 'encoding': 50}, 70);

      expect(s1.revision, equals(s2.revision));
    });
  });
}
