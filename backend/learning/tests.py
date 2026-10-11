from django.test import TestCase
from rest_framework.test import APIClient
from alphabet.models import Character, CharacterAudio
from vocabulary.models import Word, WordAudio, WordCategory
from learning.models import LearningTheme, LearningUnit
from learning.serializers import LearningUnitSerializer


class LearningCoreTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        self.char_b = Character.objects.create(
            symbol='𖺡',
            unicode_code='U+16EA1',
            latin_grapheme='b',
            phoneme_ipa='b',
            character_type=Character.CONSONANT,
            stroke_path_data={'strokes': [[{'x': 0.2, 'y': 0.3}, {'x': 0.5, 'y': 0.8}]]},
        )
        self.char_e = Character.objects.create(
            symbol='𖺣',
            unicode_code='U+16EA3',
            latin_grapheme='e',
            phoneme_ipa='e',
            character_type=Character.VOWEL,
        )
        self.char_t = Character.objects.create(
            symbol='𖺵',
            unicode_code='U+16EB5',
            latin_grapheme='t',
            phoneme_ipa='t',
            character_type=Character.CONSONANT,
        )

        self.word_be = Word.objects.create(
            beriya_text='𖺡𖺣',
            latin_transcription='be',
            french_translation='pays',
            orthographic_pattern='CV',
        )

        self.theme = LearningTheme.objects.create(
            slug='active-theme',
            title_fr='Thème Actif',
            level=LearningTheme.BEGINNER,
        )

        self.unit = LearningUnit.objects.create(
            theme=self.theme,
            slug='test-unit-1',
            title_fr='Unité Test 1',
            level=LearningUnit.BEGINNER,
            target_word=self.word_be,
            weight_recognition=35,
            weight_tracing=35,
            weight_encoding=30,
            status=LearningUnit.PUBLISHED,
            is_active=True,
        )
        self.unit.characters.set([self.char_b, self.char_e])
        self.unit.distractor_characters.set([self.char_t])

    def test_audio_role_choices(self):
        self.assertIn(('phoneme', 'Phoneme (pure sound)'), CharacterAudio.ROLE_CHOICES)
        self.assertIn(('letter_name', 'Letter name (traditional name)'), CharacterAudio.ROLE_CHOICES)
        self.assertIn(('syllable', 'Syllable pronunciation'), WordAudio.ROLE_CHOICES)

    def test_generate_core_flow_structure(self):
        # 1. Test avec enable_tracing = False (flux par défaut sans tracé)
        flow_no_tracing = self.unit.generate_core_flow()
        self.assertIsInstance(flow_no_tracing, list)
        self.assertEqual(len(flow_no_tracing), 8)
        step_types_no_tr = [step['step_type'] for step in flow_no_tracing]
        self.assertNotIn('tracing', step_types_no_tr)
        self.assertIn('discovery', step_types_no_tr)
        self.assertIn('discrimination', step_types_no_tr)
        self.assertIn('fusion', step_types_no_tr)
        self.assertIn('word_decoding', step_types_no_tr)
        self.assertIn('keyboard_encoding', step_types_no_tr)
        self.assertIn('celebration', step_types_no_tr)

        cel_step_no_tr = next(s for s in flow_no_tracing if s['step_type'] == 'celebration')
        self.assertEqual(cel_step_no_tr['weights']['recognition'], 50)
        self.assertEqual(cel_step_no_tr['weights']['tracing'], 0)
        self.assertEqual(cel_step_no_tr['weights']['encoding'], 50)

        # 2. Test avec enable_tracing = True
        self.unit.enable_tracing = True
        self.unit.save()
        flow = self.unit.generate_core_flow()
        step_types = [step['step_type'] for step in flow]
        self.assertIn('tracing', step_types)

        # Vérifier l'étape clavier
        kb_step = next(s for s in flow if s['step_type'] == 'keyboard_encoding')
        self.assertEqual(kb_step['target_word'], '𖺡𖺣')
        self.assertIn('𖺡', kb_step['keyboard_keys'])
        self.assertIn('𖺣', kb_step['keyboard_keys'])
        self.assertIn('𖺵', kb_step['keyboard_keys'])

        # Vérifier l'étape célébration avec pondérations
        cel_step = next(s for s in flow if s['step_type'] == 'celebration')
        self.assertEqual(cel_step['weights']['recognition'], 35)
        self.assertEqual(cel_step['weights']['tracing'], 35)
        self.assertEqual(cel_step['weights']['encoding'], 30)

    def test_serializer_includes_learning_core_fields(self):
        serializer = LearningUnitSerializer(self.unit)
        data = serializer.data

        self.assertIn('target_word', data)
        self.assertIn('distractor_characters', data)
        self.assertIn('weight_recognition', data)
        self.assertIn('weight_tracing', data)
        self.assertIn('weight_encoding', data)
        self.assertIn('core_flow', data)
        self.assertEqual(data['target_word']['beriya_text'], '𖺡𖺣')
        self.assertEqual(len(data['distractor_characters']), 1)
        self.assertEqual(data['distractor_characters'][0]['symbol'], '𖺵')

    def test_api_endpoints(self):
        # Liste des unités
        res_list = self.client.get('/api/learning/units/')
        self.assertEqual(res_list.status_code, 200)

        # Détail d'une unité
        res_detail = self.client.get(f'/api/learning/units/{self.unit.id}/')
        self.assertEqual(res_detail.status_code, 200)
        self.assertEqual(res_detail.data['slug'], 'test-unit-1')
        self.assertIn('core_flow', res_detail.data)

        # Endpoint direct core-flow
        res_flow = self.client.get(f'/api/learning/units/{self.unit.id}/core-flow/')
        self.assertEqual(res_flow.status_code, 200)
        self.assertEqual(res_flow.data['unit_id'], self.unit.id)
        self.assertGreaterEqual(res_flow.data['total_steps'], 6)
        self.assertEqual(res_flow.data['weights']['encoding'], 30)
