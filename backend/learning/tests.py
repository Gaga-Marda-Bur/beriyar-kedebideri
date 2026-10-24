from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient
from alphabet.models import Character, CharacterAudio
from audio_assets.models import AudioAsset
from vocabulary.models import Word, WordAudio, WordCategory
from learning.models import LearningTheme, LearningUnit
from learning.serializers import LearningUnitSerializer


User = get_user_model()


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
            validation_status=Character.PUBLISHED,
        )
        self.char_e = Character.objects.create(
            symbol='𖺣',
            unicode_code='U+16EA3',
            latin_grapheme='e',
            phoneme_ipa='e',
            character_type=Character.VOWEL,
            validation_status=Character.PUBLISHED,
        )
        self.char_t = Character.objects.create(
            symbol='𖺵',
            unicode_code='U+16EB5',
            latin_grapheme='t',
            phoneme_ipa='t',
            character_type=Character.CONSONANT,
            validation_status=Character.PUBLISHED,
        )

        self.word_be = Word.objects.create(
            beriya_text='𖺡𖺣',
            latin_transcription='be',
            french_translation='pays',
            orthographic_pattern='CV',
            validation_status=Word.PUBLISHED,
        )

        self.theme = LearningTheme.objects.create(
            slug='active-theme',
            title_fr='Thème Actif',
            level=LearningTheme.BEGINNER,
            status=LearningTheme.PUBLISHED,
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


class EditorialDraftProtectionTests(TestCase):
    """
    Tests A07: Exclure les brouillons des API publiques, relations imbriquées
    et packs publics, tout en les conservant pour l'administration et prévisualisation staff.
    """
    def setUp(self):
        self.client = APIClient()

        self.staff_user = User.objects.create_user(
            username='staff_tester',
            password='Password123!',
            is_staff=True,
        )

        # Thème publié et thème brouillon
        self.pub_theme = LearningTheme.objects.create(
            slug='theme-publie',
            title_fr='Thème Publié',
            status='published',
        )
        self.draft_theme = LearningTheme.objects.create(
            slug='theme-brouillon',
            title_fr='Thème Brouillon',
            status='draft',
        )

        # Mots : 1 publié, 1 brouillon
        self.pub_word = Word.objects.create(
            beriya_text='𖺡𖺠',
            latin_transcription='ba',
            french_translation='père',
            validation_status='published',
        )
        self.draft_word = Word.objects.create(
            beriya_text='𖺡𖺣',
            latin_transcription='be',
            french_translation='pays',
            validation_status='draft',
        )

        # Caractères : 1 publié, 1 en review
        self.pub_char = Character.objects.create(
            symbol='𖺡',
            unicode_code='U+16EA1',
            validation_status='published',
        )
        self.review_char = Character.objects.create(
            symbol='𖺣',
            unicode_code='U+16EA3',
            validation_status='review',
        )

        # Unité publiée avec dépendances mixtes
        self.unit_with_draft_deps = LearningUnit.objects.create(
            theme=self.pub_theme,
            slug='unite-mixte',
            title_fr='Unité Mixte',
            status='published',
            target_word=self.draft_word,  # Dépendance brouillon
        )
        self.unit_with_draft_deps.characters.add(self.pub_char, self.review_char)
        self.unit_with_draft_deps.words.add(self.pub_word, self.draft_word)

        # Unité brouillon
        self.draft_unit = LearningUnit.objects.create(
            theme=self.draft_theme,
            slug='unite-brouillon',
            title_fr='Unité Brouillon',
            status='draft',
        )

        # Audio avec métadonnées internes
        self.audio = AudioAsset.objects.create(
            title="Audio Test Secret",
            validation_status="published",
            notes="Note confidentielle de production",
            speaker_name="Locuteur Secret",
            recording_quality=5,
        )

    def test_anonymous_cannot_see_draft_units_or_themes(self):
        # Themes
        res = self.client.get('/api/learning/themes/')
        self.assertEqual(res.status_code, 200)
        slugs = [t['slug'] for t in res.data['results'] if isinstance(res.data, dict) and 'results' in res.data] if 'results' in res.data else [t['slug'] for t in res.data]
        self.assertIn('theme-publie', slugs)
        self.assertNotIn('theme-brouillon', slugs)

        # Detail draft theme -> 404
        res_detail = self.client.get(f'/api/learning/themes/{self.draft_theme.id}/')
        self.assertEqual(res_detail.status_code, 404)

        # Units
        res_u = self.client.get('/api/learning/units/')
        self.assertEqual(res_u.status_code, 200)
        u_slugs = [u['slug'] for u in res_u.data['results']] if 'results' in res_u.data else [u['slug'] for u in res_u.data]
        self.assertIn('unite-mixte', u_slugs)
        self.assertNotIn('unite-brouillon', u_slugs)

        # Detail draft unit -> 404
        res_u_detail = self.client.get(f'/api/learning/units/{self.draft_unit.id}/')
        self.assertEqual(res_u_detail.status_code, 404)

    def test_staff_can_preview_drafts(self):
        self.client.force_authenticate(user=self.staff_user)

        # Themes staff preview
        res = self.client.get('/api/learning/themes/?status=draft')
        self.assertEqual(res.status_code, 200)
        slugs = [t['slug'] for t in res.data['results']] if 'results' in res.data else [t['slug'] for t in res.data]
        self.assertIn('theme-brouillon', slugs)

        # Units staff preview
        res_u = self.client.get(f'/api/learning/units/{self.draft_unit.id}/')
        self.assertEqual(res_u.status_code, 200)
        self.assertEqual(res_u.data['slug'], 'unite-brouillon')

    def test_anonymous_unit_detail_masks_unpublished_nested_relations(self):
        res = self.client.get(f'/api/learning/units/{self.unit_with_draft_deps.id}/')
        self.assertEqual(res.status_code, 200)

        # Le mot cible est en brouillon -> doit être masqué (None) pour le public
        self.assertIsNone(res.data['target_word'])

        # Caractères : seul le caractère publié (𖺡) doit être renvoyé, pas le review (𖺣)
        char_symbols = [c['symbol'] for c in res.data['characters']]
        self.assertIn('𖺡', char_symbols)
        self.assertNotIn('𖺣', char_symbols)
        self.assertEqual(res.data['character_ids'], [self.pub_char.id])

        # Mots d'accompagnement : seul le mot publié (𖺡𖺠) doit être renvoyé
        word_texts = [w['beriya_text'] for w in res.data['words']]
        self.assertIn('𖺡𖺠', word_texts)
        self.assertNotIn('𖺡𖺣', word_texts)
        self.assertEqual(res.data['word_ids'], [self.pub_word.id])

    def test_audio_internal_fields_stripped_for_anonymous(self):
        # Anonymous
        res = self.client.get(f'/api/audio/{self.audio.id}/')
        self.assertEqual(res.status_code, 200)
        self.assertNotIn('notes', res.data)
        self.assertNotIn('speaker_name', res.data)
        self.assertNotIn('recording_quality', res.data)

        # Staff
        self.client.force_authenticate(user=self.staff_user)
        res_staff = self.client.get(f'/api/audio/{self.audio.id}/')
        self.assertEqual(res_staff.status_code, 200)
        self.assertEqual(res_staff.data['notes'], "Note confidentielle de production")
        self.assertEqual(res_staff.data['speaker_name'], "Locuteur Secret")
        self.assertEqual(str(res_staff.data['recording_quality']), '5')
