from django.test import TestCase, Client
from django.urls import reverse

class WebappViewsTestCase(TestCase):
    def setUp(self):
        self.client = Client()

    def test_editor_page_loads(self):
        response = self.client.get(reverse("web-editor"))
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, "webapp/editor.html")
        self.assertContains(response, "editorCanvas")
        self.assertContains(response, "editorTitle")
        self.assertContains(response, "editorBody")
        self.assertContains(response, "pdf-lib.min")
        self.assertContains(response, "fontkit.umd.min")
        self.assertContains(response, "beriya_editor")

    def test_editor_page_multilingual(self):
        # Arabic
        resp_ar = self.client.get(reverse("web-editor") + "?lang=ar")
        self.assertEqual(resp_ar.status_code, 200)
        self.assertContains(resp_ar, 'dir="rtl"')

        # English
        resp_en = self.client.get(reverse("web-editor") + "?lang=en")
        self.assertEqual(resp_en.status_code, 200)
        self.assertContains(resp_en, "Beriya Erfe Text Editor")

        # French
        resp_fr = self.client.get(reverse("web-editor") + "?lang=fr")
        self.assertEqual(resp_fr.status_code, 200)
        self.assertContains(resp_fr, "Éditeur Beriya Erfe")

    def test_sticker_studio_page(self):
        response = self.client.get(reverse("web-sticker-studio"))
        self.assertEqual(response.status_code, 200)
        self.assertTemplateUsed(response, "webapp/sticker_studio.html")


class PublishedAudioParityTests(TestCase):
    def setUp(self):
        from alphabet.models import Character, CharacterAudio
        from audio_assets.models import AudioAsset
        self.character = Character.objects.create(
            symbol='𖺡', unicode_code='U+16EA1', validation_status='published')
        self.draft = AudioAsset.objects.create(
            title='Draft', file='audio/secret.mp3', validation_status='draft')
        self.slow = AudioAsset.objects.create(
            title='Slow', file='audio/slow.mp3', validation_status='published')
        self.selected = AudioAsset.objects.create(
            title='Normal', file='audio/chosen.mp3', validation_status='published')
        self.other = AudioAsset.objects.create(
            title='Other', file='audio/other.mp3', validation_status='published')
        CharacterAudio.objects.create(character=self.character, audio_asset=self.draft,
                                      role='normal', is_primary=True, order=0)
        CharacterAudio.objects.create(character=self.character, audio_asset=self.slow,
                                      role='slow', is_primary=True)
        CharacterAudio.objects.create(character=self.character, audio_asset=self.other,
                                      role='normal', is_primary=False, order=0)
        CharacterAudio.objects.create(character=self.character, audio_asset=self.selected,
                                      role='normal', is_primary=True, order=3)

    def test_web_api_and_pack_choose_same_published_role_and_priority(self):
        from alphabet.serializers import CharacterSerializer
        from audio_assets.utils import get_linked_audio_file
        from webapp.templatetags.web_i18n import published_audio
        expected = self.selected.file.url
        self.assertEqual(CharacterSerializer(self.character).data['audio_url'], expected)
        self.assertEqual(published_audio(self.character, 'normal'), expected)
        self.assertEqual(get_linked_audio_file(self.character, 'normal').name, self.selected.file.name)
        response = self.client.get('/alphabet/')
        self.assertContains(response, f'data-audio="{expected}"')
        self.assertNotContains(response, self.draft.file.url)
        self.assertNotContains(response, self.slow.file.url)
        self.assertContains(response, 'webapp/js/audio_player.js')
        self.assertNotContains(response, 'new Audio(')

    def test_no_published_normal_track_never_falls_back_to_draft_or_slow(self):
        from alphabet.serializers import CharacterSerializer
        from webapp.templatetags.web_i18n import published_audio
        self.character.audio_links.filter(role='normal', audio_asset__validation_status='published').delete()
        self.assertIsNone(published_audio(self.character))
        self.assertIsNone(CharacterSerializer(self.character).data['audio_url'])
        self.assertNotContains(self.client.get('/alphabet/'), 'data-audio=')

    def test_quiz_uses_published_non_primary_track_when_no_primary_exists(self):
        from quizzes.models import QuizQuestion, QuizQuestionAudio
        from quizzes.serializers import QuizQuestionSerializer
        from webapp.templatetags.web_i18n import published_audio
        question = QuizQuestion.objects.create(status='published', prompt_fr='Question')
        QuizQuestionAudio.objects.create(question=question, audio_asset=self.selected,
                                 role='question', is_primary=False)
        expected = published_audio(question, 'question')
        self.assertEqual(QuizQuestionSerializer(question).data['question_audio_url'], expected)
        response = self.client.get('/quiz/')
        self.assertContains(response, expected)
        self.assertNotContains(response, self.draft.file.url)

    def test_no_ena_does_not_expose_unpublished_primary_audio(self):
        from no_ena.models import NoEnaPublication
        from no_ena.serializers import NoEnaPublicationSerializer
        publication = NoEnaPublication.objects.create(slug='audio-test', title_fr='Audio',
            status='published', primary_audio_asset=self.draft)
        self.assertIsNone(NoEnaPublicationSerializer(publication).data['audio_url'])
        response = self.client.get('/no-ena/audio-test/')
        self.assertNotContains(response, self.draft.file.url)


class Lot3AccessibilityAndCopyTests(TestCase):
    def setUp(self):
        self.client = Client()

    def test_home_public_copy_no_admin_or_raw_api_leak(self):
        response = self.client.get(reverse('web-home'))
        self.assertEqual(response.status_code, 200)
        # Should not expose admin tasks or raw dev API endpoints
        self.assertNotContains(response, 'Crée et publie le Starter Pack depuis')
        self.assertNotContains(response, '/api/offline-packs/')
        # Should encourage learning
        self.assertContains(response, 'Parcours')

    def test_mobile_navigation_accessibility_attributes(self):
        response = self.client.get(reverse('web-home'))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, 'id="mobileMenuButton"')
        self.assertContains(response, 'aria-expanded="false"')
        self.assertContains(response, 'aria-controls="mobileMenu"')
        self.assertContains(response, 'aria-label="Ouvrir ou fermer le menu de navigation"')

        # RTL / Arabic accessibility label check
        resp_ar = self.client.get(reverse('web-home') + '?lang=ar')
        self.assertEqual(resp_ar.status_code, 200)
        self.assertContains(resp_ar, 'aria-label="فتح أو إغلاق القائمة"')

    def test_unit_detail_accessible_and_glyph_prominence(self):
        from learning.models import LearningTheme, LearningUnit
        from alphabet.models import Character, CharacterAudio
        from audio_assets.models import AudioAsset
        theme = LearningTheme.objects.create(
            slug='theme-a11y',
            title_fr='Thème A11y',
            status=LearningTheme.PUBLISHED
        )
        unit = LearningUnit.objects.create(
            theme=theme,
            slug='unit-a11y',
            title_fr='Unité Découverte',
            status=LearningUnit.PUBLISHED,
            order_index=1
        )
        ch = Character.objects.create(
            symbol='𖺡',
            unicode_code='U+16EA1',
            latin_transcription='a',
            arabic_transcription='ا',
            validation_status='published'
        )
        unit.characters.add(ch)
        audio = AudioAsset.objects.create(
            title='A', file='audio/a.mp3', validation_status='published')
        CharacterAudio.objects.create(
            character=ch, audio_asset=audio, role='normal', is_primary=True)

        response = self.client.get(reverse('web-unit-detail', kwargs={'slug': unit.slug}))
        self.assertEqual(response.status_code, 200)
        # Glyph and transcriptions present
        self.assertContains(response, '𖺡')
        self.assertContains(response, 'U+16EA1')
        self.assertContains(response, 'audio-button')
        self.assertContains(response, 'btn-primary')
