from io import StringIO

from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.management import call_command
from django.test import TestCase
from rest_framework.test import APIClient

from alphabet.models import Character, CharacterAudio
from audio_assets.models import AudioAsset
from learning.models import LearningTheme, LearningUnit
from lessons.models import Lesson
from quizzes.models import QuizQuestion


User = get_user_model()


class ErfeAlphabetV1ValidationTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        call_command('import_preprod_courses', stdout=StringIO())
        call_command(
            'validate_erfe_alphabet_v1',
            '--validated-by=responsable_linguistique_test',
            '--validated-on=2026-11-14',
            stdout=StringIO(),
        )
        cls.public_user = User.objects.create_user(
            username='learner_v1',
            password='Password123!',
            is_staff=False,
        )
        cls.staff_user = User.objects.create_user(
            username='staff_v1',
            password='Password123!',
            is_staff=True,
        )

    def test_validation_state_and_non_publication(self):
        erf_units = LearningUnit.objects.filter(slug__startswith='bk-preprod-erf-')
        self.assertEqual(erf_units.count(), 5)
        self.assertEqual(erf_units.filter(status=LearningUnit.VALIDATED).count(), 5)
        self.assertEqual(erf_units.filter(status=LearningUnit.PUBLISHED).count(), 0)

        for unit in erf_units:
            trace = unit.pedagogy_config.get('linguistic_validation', {})
            self.assertEqual(trace.get('status'), 'validated')
            self.assertEqual(trace.get('validated_by'), 'responsable_linguistique_test')
            self.assertEqual(trace.get('audio_mode'), 'audio_optional_pending')

        self.assertEqual(
            Lesson.objects.filter(slug__startswith='bk-preprod-erf-', status=Lesson.VALIDATED).count(),
            5,
        )
        self.assertEqual(Character.objects.filter(validation_status=Character.VALIDATED).count(), 25)

        # Phrases (P01..P06) et Vocabulaire (V01..V03) restent en draft
        self.assertEqual(
            LearningUnit.objects.filter(slug__startswith='bk-preprod-p', status=LearningUnit.DRAFT).count(),
            6,
        )
        self.assertEqual(
            LearningUnit.objects.filter(slug__startswith='bk-preprod-v', status=LearningUnit.DRAFT).count(),
            3,
        )

        # Seuls les QCM sans audio sont activés sur ERF-01..ERF-05
        erf_quizzes = QuizQuestion.objects.filter(unit__slug__startswith='bk-preprod-erf-')
        self.assertEqual(erf_quizzes.filter(is_active=True, status=QuizQuestion.VALIDATED).count(), 25)
        self.assertEqual(erf_quizzes.filter(is_active=False, status=QuizQuestion.DRAFT).count(), 50)

    def test_core_flow_works_without_audio_and_preserves_ids_when_audio_added_later(self):
        unit = LearningUnit.objects.get(slug='bk-preprod-erf-01')
        unit_id_before = unit.id
        unit_slug_before = unit.slug

        flow = unit.generate_core_flow(only_published=False)
        step_types = [s['step_type'] for s in flow]
        self.assertIn('discovery', step_types)
        self.assertIn('discrimination', step_types)
        self.assertIn('keyboard_encoding', step_types)
        self.assertEqual(step_types[-1], 'celebration')

        first_disc = next(s for s in flow if s['step_type'] == 'discrimination')
        self.assertIn('A', first_disc['instruction'])
        self.assertIsNone(first_disc['audio_url'])

        first_enc = next(s for s in flow if s['step_type'] == 'keyboard_encoding')
        self.assertEqual(first_enc['target_word'], '𖺠')

        # Ajout ultérieur d'un audio sans recréer l'unité ni changer son ID
        char_a = unit.characters.get(symbol='𖺠')
        import io
        import wave
        wav_buf = io.BytesIO()
        with wave.open(wav_buf, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(16000)
            wf.writeframes(b'\x00\x00')
        wav_bytes = wav_buf.getvalue()
        audio = AudioAsset.objects.create(
            title='Son A test',
            file=SimpleUploadedFile('a_test.wav', wav_bytes, content_type='audio/wav'),
            audio_type=AudioAsset.PHONEME,
            validation_status=AudioAsset.PUBLISHED,
        )
        CharacterAudio.objects.create(
            character=char_a,
            audio_asset=audio,
            role=CharacterAudio.PHONEME,
            is_primary=True,
        )

        unit.refresh_from_db()
        self.assertEqual(unit.id, unit_id_before)
        self.assertEqual(unit.slug, unit_slug_before)
        flow_with_audio = unit.generate_core_flow(only_published=False)
        first_disc_audio = next(s for s in flow_with_audio if s['step_type'] == 'discrimination')
        self.assertIsNotNone(first_disc_audio['audio_url'])

    def test_candidate_is_visible_in_staff_preview_only_and_not_public(self):
        pub_client = APIClient()
        pub_client.force_authenticate(user=self.public_user)
        self.assertEqual(len(pub_client.get('/api/learning/units/').json().get('results', pub_client.get('/api/learning/units/').json())), 0)

        staff_client = APIClient()
        staff_client.force_authenticate(user=self.staff_user)
        resp = staff_client.get('/api/learning/units/?status=validated')
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        results = data['results'] if isinstance(data, dict) and 'results' in data else data
        self.assertEqual(len(results), 5)

    def test_pilot_group_access_sees_only_erf_01_to_05_never_draft(self):
        from django.contrib.auth import get_user_model
        from django.contrib.auth.models import Group
        from core.permissions import PILOT_GROUP_NAME

        User = get_user_model()
        pilot_user = User.objects.create_user(username='pilot_learner_1', password='pw', is_staff=False)
        pilot_group, _ = Group.objects.get_or_create(name=PILOT_GROUP_NAME)
        pilot_user.groups.add(pilot_group)

        pilot_client = APIClient()
        pilot_client.force_authenticate(user=pilot_user)

        themes_resp = pilot_client.get('/api/learning/themes/').json()
        themes = themes_resp['results'] if isinstance(themes_resp, dict) and 'results' in themes_resp else themes_resp
        self.assertEqual([t['slug'] for t in themes], ['bk-preprod-alphabet-erfe'])
        self.assertEqual(themes[0]['units_count'], 5)

        units_resp = pilot_client.get('/api/learning/units/').json()
        units = units_resp['results'] if isinstance(units_resp, dict) and 'results' in units_resp else units_resp
        self.assertEqual(len(units), 5)
        self.assertTrue(all(u['slug'].startswith('bk-preprod-erf-') for u in units))
        self.assertEqual(len(units[0]['characters']), 5)
        self.assertGreater(len(units[0]['core_flow']), 0)

        # Même avec ?status=draft, un apprenant pilote ne voit jamais les brouillons P01..P06 / V01..V03
        draft_resp = pilot_client.get('/api/learning/units/?status=draft').json()
        draft_units = draft_resp['results'] if isinstance(draft_resp, dict) and 'results' in draft_resp else draft_resp
        self.assertEqual(len(draft_units), 0)

        quizzes_resp = pilot_client.get('/api/quizzes/').json()
        quizzes = quizzes_resp['results'] if isinstance(quizzes_resp, dict) and 'results' in quizzes_resp else quizzes_resp
        self.assertEqual(len(quizzes), 25)
        self.assertTrue(all(q['question_type'] == 'text_to_character' for q in quizzes))

    def test_pilot_allowlist_blocks_sixth_validated_unit_even_by_direct_id_and_preserves_published(self):
        from django.contrib.auth import get_user_model
        from django.contrib.auth.models import Group
        from core.permissions import PILOT_GROUP_NAME
        from learning.models import LearningTheme
        from lessons.models import Lesson
        from alphabet.models import Character

        # 6e unité VALIDATED hors pilote + thème/leçon/quiz/caractère associés
        ext_theme = LearningTheme.objects.create(
            slug='bk-theme-hors-pilote',
            title_fr='Thème hors pilote',
            status=LearningTheme.VALIDATED,
            is_active=True,
        )
        ext_char = Character.objects.create(
            symbol='𖺹',
            unicode_code='U+16EB9',
            name_fr='Hors pilote',
            validation_status=Character.VALIDATED,
            is_active=True,
        )
        ext_unit = LearningUnit.objects.create(
            theme=ext_theme,
            slug='bk-hors-pilote-06',
            title_fr='Unité hors pilote',
            status=LearningUnit.VALIDATED,
            is_active=True,
        )
        ext_unit.characters.add(ext_char)
        ext_lesson = Lesson.objects.create(
            unit=ext_unit,
            slug='bk-lesson-hors-pilote-06',
            title_fr='Leçon hors pilote',
            status=Lesson.VALIDATED,
            is_active=True,
        )
        ext_quiz = QuizQuestion.objects.create(
            unit=ext_unit,
            lesson=ext_lesson,
            question_type=QuizQuestion.TEXT_TO_CHARACTER,
            prompt_fr='Quiz hors pilote',
            status=QuizQuestion.VALIDATED,
            is_active=True,
        )

        # Unité déjà PUBLISHED : les règles d'accès normales restent inchangées
        pub_theme = LearningTheme.objects.create(
            slug='bk-theme-pub',
            title_fr='Thème publié',
            status=LearningTheme.PUBLISHED,
            is_active=True,
        )
        pub_unit = LearningUnit.objects.create(
            theme=pub_theme,
            slug='bk-pub-01',
            title_fr='Unité publiée',
            status=LearningUnit.PUBLISHED,
            is_active=True,
        )

        User = get_user_model()
        pilot_user = User.objects.create_user(username='pilot_allowlist', password='pw', is_staff=False)
        pilot_group, _ = Group.objects.get_or_create(name=PILOT_GROUP_NAME)
        pilot_user.groups.add(pilot_group)

        pilot_client = APIClient()
        pilot_client.force_authenticate(user=pilot_user)

        # Accès direct par ID à la 6e unité VALIDATED hors pilote -> 404 partout
        self.assertEqual(pilot_client.get(f'/api/learning/units/{ext_unit.id}/').status_code, 404)
        self.assertEqual(pilot_client.get(f'/api/learning/units/{ext_unit.id}/core-flow/').status_code, 404)
        self.assertEqual(pilot_client.get(f'/api/lessons/{ext_lesson.id}/').status_code, 404)
        self.assertEqual(pilot_client.get(f'/api/quizzes/{ext_quiz.id}/').status_code, 404)
        self.assertEqual(pilot_client.get(f'/api/alphabet/characters/{ext_char.id}/').status_code, 404)

        # Liste des unités pour le pilote : uniquement les 5 ERF + l'unité PUBLISHED (jamais la 6e validated ni les drafts)
        units_resp = pilot_client.get('/api/learning/units/').json()
        units = units_resp['results'] if isinstance(units_resp, dict) and 'results' in units_resp else units_resp
        unit_slugs = {u['slug'] for u in units}
        self.assertNotIn('bk-hors-pilote-06', unit_slugs)
        self.assertIn('bk-pub-01', unit_slugs)
        self.assertEqual(len(unit_slugs), 6)

        # Accès normal au contenu déjà PUBLISHED préservé
        self.assertEqual(pilot_client.get(f'/api/learning/units/{pub_unit.id}/').status_code, 200)
