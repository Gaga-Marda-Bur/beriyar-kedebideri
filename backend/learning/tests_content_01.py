from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group
from django.test import Client, TestCase
from rest_framework.test import APIClient

from alphabet.models import Character
from audio_assets.models import AudioAsset
from core.permissions import PILOT_ALLOWED_UNIT_SLUGS, PILOT_GROUP_NAME
from learning.models import LearningTheme, LearningUnit
from lessons.models import Lesson
from quizzes.models import QuizQuestion
from vocabulary.models import Word, WordAudio


class BkContent01BackendTests(TestCase):
    def setUp(self):
        self.client = Client()
        self.api_client = APIClient()
        User = get_user_model()
        self.staff = User.objects.create_user(username="staff_c01", password="pwd", is_staff=True)
        self.pilot = User.objects.create_user(username="pilot_c01", password="pwd")
        grp, _ = Group.objects.get_or_create(name=PILOT_GROUP_NAME)
        self.pilot.groups.add(grp)

        self.theme_pub = LearningTheme.objects.create(
            slug="mots-quotidiens",
            title_fr="Mots du quotidien",
            title_en="Daily words",
            title_ar="كلمات يومية",
            level="beginner",
            order_index=2,
            status="published",
        )
        self.theme_draft = LearningTheme.objects.create(
            slug="theme-brouillon",
            title_fr="Thème brouillon",
            level="beginner",
            order_index=9,
            status="draft",
        )

        self.unit_pub = LearningUnit.objects.create(
            theme=self.theme_pub,
            slug="maison-personnes",
            title_fr="Maison et personnes",
            title_en="Home and people",
            title_ar="البيت والأشخاص",
            level="beginner",
            order_index=3,
            status="published",
        )
        self.unit_draft = LearningUnit.objects.create(
            theme=self.theme_pub,
            slug="unite-brouillon",
            title_fr="Unité brouillon",
            level="beginner",
            order_index=4,
            status="draft",
        )
        self.unit_old = LearningUnit.objects.create(
            theme=self.theme_draft,
            slug="premiers-signes",
            title_fr="Premiers signes",
            level="beginner",
            order_index=1,
            status="draft",
        )
        self.unit_pilot = LearningUnit.objects.create(
            theme=self.theme_pub,
            slug=PILOT_ALLOWED_UNIT_SLUGS[0],
            title_fr="Pilote Erfe 01",
            level="beginner",
            order_index=5,
            status="validated",
        )

        self.audio = AudioAsset.objects.create(
            title="Word Audio",
            file="audio/word.mp3",
            validation_status="published",
        )

        # 9 single-token words + 1 multi-word phrase with space = 10 words
        self.words = []
        for i in range(9):
            w = Word.objects.create(
                beriya_text=f"𖺠{chr(0x16EA1 + i)}",
                latin_transcription=f"mot{i}",
                french_translation=f"Mot FR {i}",
                english_translation=f"Word EN {i}",
                arabic_translation=f"كلمة {i}",
                difficulty_order=i + 1,
                validation_status="published",
            )
            WordAudio.objects.create(word=w, audio_asset=self.audio, role="normal", is_primary=True)
            self.unit_pub.words.add(w)
            self.words.append(w)

        self.phrase_word = Word.objects.create(
            beriya_text="𖺬𖺯 𖺵𖺠̄",
            latin_transcription="kor fa",
            french_translation="Chez nous",
            english_translation="At home",
            arabic_translation="عندنا",
            difficulty_order=10,
            validation_status="published",
        )
        self.unit_pub.words.add(self.phrase_word)

        self.draft_word = Word.objects.create(
            beriya_text="𖺢𖺣",
            latin_transcription="secret",
            french_translation="Mot brouillon",
            difficulty_order=11,
            validation_status="draft",
        )
        self.unit_pub.words.add(self.draft_word)

        self.draft_char = Character.objects.create(
            symbol="𖺱",
            unicode_code="U+16EB1",
            validation_status="draft",
        )
        self.unit_pub.characters.add(self.draft_char)

        self.draft_lesson = Lesson.objects.create(
            unit=self.unit_pub,
            slug="lecon-brouillon",
            title_fr="Leçon brouillon",
            status="draft",
        )

        self.orphan_quiz = QuizQuestion.objects.create(
            unit=self.unit_old,
            status="published",
            prompt_fr="Quiz premiers-signes",
        )
        self.standalone_quiz = QuizQuestion.objects.create(
            unit=None,
            status="published",
            prompt_fr="Quiz autonome",
        )

    def test_lot3a_anonymous_visibility_and_quiz_filtering(self):
        # Web /parcours/ ne doit pas exposer unite-brouillon ni le pilote
        resp = self.client.get("/parcours/")
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, "Maison et personnes")
        self.assertNotContains(resp, "Unité brouillon")
        self.assertNotContains(resp, "Pilote Erfe 01")

        # Web /parcours/<slug>/ ne doit pas exposer mots/caractères/leçons brouillon
        resp_unit = self.client.get("/parcours/maison-personnes/")
        self.assertEqual(resp_unit.status_code, 200)
        self.assertNotContains(resp_unit, "Mot brouillon")
        self.assertNotContains(resp_unit, "Leçon brouillon")
        self.assertNotContains(resp_unit, "U+16EB1")

        # Web /parcours/unite-brouillon/ -> 404
        self.assertEqual(self.client.get("/parcours/unite-brouillon/").status_code, 404)

        # /api/quizzes/ et /quiz/ ne doivent pas exposer le quiz de premiers-signes
        api_quizzes = self.api_client.get("/api/quizzes/")
        self.assertEqual(api_quizzes.status_code, 200)
        results = api_quizzes.json()["results"]
        ids = [q["id"] for q in results]
        self.assertNotIn(self.orphan_quiz.id, ids)
        self.assertIn(self.standalone_quiz.id, ids)

        web_quiz = self.client.get("/quiz/")
        self.assertNotContains(web_quiz, "Quiz premiers-signes")
        self.assertContains(web_quiz, "Quiz autonome")

        # Le quiz premiers-signes n'est ni supprimé ni déplacé en base
        self.assertTrue(QuizQuestion.objects.filter(pk=self.orphan_quiz.id, unit=self.unit_old).exists())

    def test_lot3a_staff_and_pilot_keep_access(self):
        self.client.force_login(self.staff)
        resp_staff = self.client.get("/parcours/unite-brouillon/")
        self.assertEqual(resp_staff.status_code, 200)
        self.assertContains(self.client.get("/quiz/"), "Quiz premiers-signes")

        self.client.force_login(self.pilot)
        resp_pilot = self.client.get(f"/parcours/{PILOT_ALLOWED_UNIT_SLUGS[0]}/")
        self.assertEqual(resp_pilot.status_code, 200)

    def test_lot3b_maison_personnes_all_10_words_and_non_empty_keyboard(self):
        flow = self.unit_pub.generate_core_flow(only_published=True, lang="fr")
        decoding_words = [s["word"] for s in flow if s["step_type"] == "word_decoding"]
        self.assertEqual(len(decoding_words), 10)
        self.assertIn("𖺬𖺯 𖺵𖺠̄", decoding_words)

        encoding_steps = [s for s in flow if s["step_type"] == "keyboard_encoding"]
        self.assertEqual(len(encoding_steps), 9)  # phrase avec espace exclue du clavier 1.0.2
        for step in encoding_steps:
            self.assertTrue(len(step["keyboard_keys"]) >= 2)
            self.assertIn("french_translation", step)
            self.assertIn("translation", step)

    def test_lot3c_web_unit_detail_audio_and_core_flow(self):
        resp = self.client.get("/parcours/maison-personnes/")
        self.assertEqual(resp.status_code, 200)
        self.assertContains(resp, f'data-audio="{self.audio.file.url}"')
        self.assertContains(resp, 'id="bk-core-flow-data"')
        self.assertNotContains(resp, "Aucune leçon pour cette unité.")

        resp_ar = self.client.get("/parcours/maison-personnes/?lang=ar")
        self.assertEqual(resp_ar.status_code, 200)
        self.assertContains(resp_ar, 'dir="rtl"')
        self.assertContains(resp_ar, "كلمة 0")

    def test_lot3d_api_languages_preserve_apk_102_contract(self):
        resp_en = self.api_client.get("/api/learning/units/?lang=en")
        self.assertEqual(resp_en.status_code, 200)
        unit_data = [u for u in resp_en.json()["results"] if u["slug"] == "maison-personnes"][0]
        flow = unit_data["core_flow"]
        self.assertEqual(flow[0]["translation"], "Word EN 0")
        self.assertEqual(flow[0]["french_translation"], "Mot FR 0")
        self.assertEqual(flow[-1]["title"], "Congratulations!")
