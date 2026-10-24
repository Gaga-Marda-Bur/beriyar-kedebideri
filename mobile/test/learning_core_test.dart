import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/cache/cached_content_service.dart';
import 'package:mobile/features/learning/models/learning_unit_model.dart';
import 'package:mobile/features/learning/screens/learning_core_unit_screen.dart';

class FakeContentService extends CachedContentService {
  final List<LearningUnitModel> mockUnits;
  FakeContentService(this.mockUnits);

  @override
  Future<List<LearningUnitModel>> loadUnits({bool forceRefresh = false}) async => mockUnits;
}

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

    test('deprived unit without characters has zero actionable exercises', () {
      final deprivedUnit = LearningUnitModel.fromJson({
        'id': 99,
        'title_fr': 'Unité Dépourvue de Dépendances',
        'slug': 'unite-depourvue',
        'characters': [],
        'words': [],
        'core_flow': [],
      });

      final flow = deprivedUnit.effectiveCoreFlow;
      final actionable = flow.where((s) => s['step_type'] != 'celebration').toList();
      expect(actionable.isEmpty, isTrue);
    });
  });

  group('LearningCoreUnitScreen A09 & Deprivation Protection', () {
    testWidgets('displays unavailable state when unit has no actionable exercises (no auto-completion)', (tester) async {
      final deprivedUnit = LearningUnitModel.fromJson({
        'id': 99,
        'title_fr': 'Unité Dépourvue',
        'slug': 'unite-depourvue',
        'characters': [],
        'words': [],
        'core_flow': [],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: LearningCoreUnitScreen(unit: deprivedUnit),
        ),
      );
      await tester.pump();

      // Doit afficher l'état d'indisponibilité et non pas un exercice vide ou la célébration
      expect(find.text('Unité Dépourvue'), findsNWidgets(2));
      expect(find.textContaining('validation pédagogique'), findsOneWidget);
      expect(find.text('Retour au parcours'), findsOneWidget);
      expect(find.text('Terminer la session'), findsNothing);
    });

    testWidgets('displays not available state for unknown slug without silent fallback to unit 1', (tester) async {
      final existingUnit1 = LearningUnitModel.fromJson({
        'id': 1,
        'title_fr': 'Unité 1 : La consonne Be (𖺡)',
        'slug': 'unite-1',
        'characters': [],
        'words': [],
        'core_flow': [],
      });

      final fakeContentService = FakeContentService([existingUnit1]);

      await tester.pumpWidget(
        MaterialApp(
          home: LearningCoreUnitScreen(
            unitSlug: 'slug-inexistant-xyz',
            contentService: fakeContentService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Doit afficher que l'unité n'est pas disponible et ne jamais basculer silencieusement sur unite-1
      expect(find.textContaining('pas disponible sur cet appareil'), findsOneWidget);
      expect(find.textContaining('slug-inexistant-xyz'), findsOneWidget);
      expect(find.text('Retour au parcours'), findsOneWidget);
      expect(find.text('Unité 1 : La consonne Be (𖺡)'), findsNothing);
    });
  });
}
