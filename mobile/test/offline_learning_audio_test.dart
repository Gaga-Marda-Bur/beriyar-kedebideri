import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/offline_packs/services/offline_media_resolver.dart';
import 'package:mobile/features/learning/engine/learning_session.dart';

void main() {
  test(
    'offline core flow resolves all nested audio roles without changing learning identity',
    () {
      final raw = {
        'phoneme_audio_url': 'audio/phoneme.mp3',
        'letter_name_audio_url': 'audio/name.mp3',
        'core_flow': [
          {
            'step_type': 'discovery',
            'symbol': '𖺡',
            'audio_url': 'audio/phoneme.mp3',
            'letter_name_audio_url': 'audio/name.mp3',
            'nested': {'explanation_audio_url': 'audio/explanation.mp3'},
          },
          {
            'step_type': 'word_decoding',
            'word': '𖺡𖺣',
            'image_url': 'images/word.png',
          },
        ],
      };
      final normalized = OfflineMediaResolver.resolveFields(
        raw,
        localPackPath: '/packs/unit-v1',
        fields: [],
      );
      expect(
        normalized['phoneme_audio_url'],
        '/packs/unit-v1/audio/phoneme.mp3',
      );
      final flow = normalized['core_flow'] as List;
      expect(flow[0]['audio_url'], '/packs/unit-v1/audio/phoneme.mp3');
      expect(flow[0]['letter_name_audio_url'], '/packs/unit-v1/audio/name.mp3');
      expect(
        flow[0]['nested']['explanation_audio_url'],
        '/packs/unit-v1/audio/explanation.mp3',
      );
      expect(flow[1]['image_url'], '/packs/unit-v1/images/word.png');
      expect((raw['core_flow'] as List)[0]['audio_url'], 'audio/phoneme.mp3');
      List<Map<String, dynamic>> steps(dynamic list) => (list as List)
          .map((step) => Map<String, dynamic>.from(step as Map))
          .toList();
      expect(
        LearningSession(steps(raw['core_flow']), {}, 70).revision,
        LearningSession(steps(flow), {}, 70).revision,
      );
    },
  );
}
