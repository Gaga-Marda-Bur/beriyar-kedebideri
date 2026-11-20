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
        from django.contrib.staticfiles import finders
        from django.contrib.staticfiles.storage import staticfiles_storage
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
        self.assertIsNotNone(finders.find('webapp/js/audio_player.js'))
        self.assertContains(response, staticfiles_storage.url('webapp/js/audio_player.js'))
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


class Release02PrivacyAndMobilePagesTests(TestCase):
    def setUp(self):
        self.client = Client()

    def test_privacy_page_multilingual_and_draft_notice(self):
        resp_fr = self.client.get(reverse('web-privacy') + '?lang=fr')
        self.assertEqual(resp_fr.status_code, 200)
        self.assertTemplateUsed(resp_fr, 'webapp/privacy.html')
        self.assertContains(resp_fr, 'Politique de confidentialité')
        self.assertContains(resp_fr, '[À CONFIRMER PAR LE RESPONSABLE]')
        self.assertContains(resp_fr, 'non prêt pour publication publique')

        resp_en = self.client.get(reverse('web-privacy') + '?lang=en')
        self.assertEqual(resp_en.status_code, 200)
        self.assertContains(resp_en, 'Privacy Policy')
        self.assertContains(resp_en, '[TO BE CONFIRMED BY OWNER]')

        resp_ar = self.client.get(reverse('web-privacy') + '?lang=ar')
        self.assertEqual(resp_ar.status_code, 200)
        self.assertContains(resp_ar, 'dir="rtl"')
        self.assertContains(resp_ar, 'سياسة الخصوصية')
        self.assertContains(resp_ar, '[يُؤكَّد من قِبل المسؤول]')

        for resp in (resp_fr, resp_en, resp_ar):
            self.assertContains(resp, 'privacy@beriyarkedebideri.com')
            self.assertContains(resp, 'support@beriyarkedebideri.com')
            self.assertContains(resp, 'Oregon')
            self.assertContains(resp, 'Eastern Europe (EEUR)')
            self.assertNotContains(resp, 'gmail.com')

        for path in (reverse('web-home'), reverse('web-mobile'), reverse('web-account-deletion')):
            for lang in ('fr', 'en', 'ar'):
                r = self.client.get(f'{path}?lang={lang}')
                self.assertEqual(r.status_code, 200)
                self.assertNotContains(r, 'gmail.com')

    def test_mobile_page_multilingual_metadata_and_no_premature_download(self):
        from django.contrib.staticfiles.storage import staticfiles_storage

        resp_fr = self.client.get(reverse('web-mobile') + '?lang=fr')
        self.assertEqual(resp_fr.status_code, 200)
        self.assertTemplateUsed(resp_fr, 'webapp/mobile.html')
        self.assertContains(resp_fr, staticfiles_storage.url('webapp/img/logo.png'))
        self.assertContains(resp_fr, '1.1.2+6')
        self.assertContains(resp_fr, '70 694 649')
        self.assertContains(
            resp_fr,
            'F96AB0D35C764244B055E773E2869AAF6C131D70593B94A2279705D7DE4F128F',
        )
        self.assertContains(resp_fr, 'Ne désinstallez pas')
        self.assertContains(resp_fr, reverse('web-privacy'))
        self.assertContains(resp_fr, 'aria-disabled="true"')
        self.assertNotContains(resp_fr, 'beriyar-kedebideri-v1.apk')
        self.assertNotContains(resp_fr, '.apk"')

        resp_en = self.client.get(reverse('web-mobile') + '?lang=en')
        self.assertEqual(resp_en.status_code, 200)
        self.assertContains(resp_en, 'Public download not active yet')

        resp_ar = self.client.get(reverse('web-mobile') + '?lang=ar')
        self.assertEqual(resp_ar.status_code, 200)
        self.assertContains(resp_ar, 'dir="rtl"')
        self.assertContains(resp_ar, 'التحميل العام غير مفعّل بعد')

    def test_mobile_page_refuses_legacy_v1_apk_url(self):
        from django.test import override_settings

        with override_settings(
            ANDROID_APK_RELEASE_URL='https://media.beriyarkedebideri.com/apk/beriyar-kedebideri-v1.apk'
        ):
            resp = self.client.get(reverse('web-mobile'))
            self.assertEqual(resp.status_code, 200)
            self.assertContains(resp, 'aria-disabled="true"')
            self.assertNotContains(resp, 'beriyar-kedebideri-v1.apk')

    def test_mobile_page_refuses_legacy_env_and_dangerous_or_untrusted_urls(self):
        from django.test import override_settings

        # Legacy ANDROID_APK_URL must not activate ANDROID_APK_RELEASE_URL
        with override_settings(
            ANDROID_APK_URL='https://media.beriyarkedebideri.com/apk/beriyar-kedebideri-v1.1.0+4-release.apk',
            ANDROID_APK_RELEASE_URL='',
        ):
            resp = self.client.get(reverse('web-mobile'))
            self.assertContains(resp, 'aria-disabled="true"')

        invalid_urls = [
            'javascript:alert(1)',
            'data:text/html,<script>alert(1)</script>',
            'file:///tmp/app.apk',
            'http://media.beriyarkedebideri.com/apk/beriyar-kedebideri-v1.1.0+4-release.apk',
            'https://evil.example.com/apk/beriyar-kedebideri-v1.1.0+4-release.apk',
            'https://user:pass@media.beriyarkedebideri.com/apk/beriyar-kedebideri-v1.1.0+4-release.apk',
            'https://media.beriyarkedebideri.com/apk/not-an-apk.txt',
        ]
        for bad_url in invalid_urls:
            with override_settings(ANDROID_APK_RELEASE_URL=bad_url):
                resp = self.client.get(reverse('web-mobile'))
                self.assertEqual(resp.status_code, 200)
                self.assertContains(resp, 'aria-disabled="true"')
                self.assertNotContains(resp, bad_url)

    def test_mobile_page_accepts_authorized_https_domain_apk_url(self):
        from django.test import override_settings

        valid_url = 'https://media.beriyarkedebideri.com/apk/beriyar-kedebideri-v1.1.0+4-release.apk'
        with override_settings(ANDROID_APK_RELEASE_URL=valid_url):
            resp = self.client.get(reverse('web-mobile'))
            self.assertEqual(resp.status_code, 200)
            self.assertContains(resp, f'href="{valid_url}"')
            self.assertNotContains(resp, 'aria-disabled="true"')

    def test_navigation_links_to_mobile_and_privacy_without_legacy_apk_link(self):
        resp_home = self.client.get(reverse('web-home'))
        self.assertEqual(resp_home.status_code, 200)
        self.assertContains(resp_home, reverse('web-mobile'))
        self.assertContains(resp_home, reverse('web-privacy'))
        self.assertNotContains(resp_home, 'beriyar-kedebideri-v1.apk')


class AccountDeletionFlowTests(TestCase):
    def setUp(self):
        from django.contrib.auth import get_user_model
        from django.core.cache import caches

        caches['feedback'].clear()
        self.User = get_user_model()
        self.user_no_email = self.User.objects.create_user(
            username='learner_no_email',
            email='',
            password='StrongPassword!2026',
        )
        self.csrf_client = Client(enforce_csrf_checks=True)

    def _csrf_token(self, client):
        resp = client.get('/api/core/auth/csrf/')
        return resp.json()['csrf_token']

    def test_api_deletion_request_requires_auth_and_password_confirmation(self):
        import json

        token = self._csrf_token(self.csrf_client)
        unauth = self.csrf_client.post(
            '/api/core/auth/deletion-request/',
            data=json.dumps({'password': 'StrongPassword!2026'}),
            content_type='application/json',
            HTTP_X_CSRFTOKEN=token,
        )
        self.assertEqual(unauth.status_code, 401)

        login_resp = self.csrf_client.post(
            '/api/core/auth/login/',
            data=json.dumps({'username': 'learner_no_email', 'password': 'StrongPassword!2026'}),
            content_type='application/json',
            HTTP_X_CSRFTOKEN=token,
        )
        self.assertEqual(login_resp.status_code, 200)
        token = login_resp.json()['csrf_token']

        wrong_pw = self.csrf_client.post(
            '/api/core/auth/deletion-request/',
            data=json.dumps({'password': 'WrongPassword!'}),
            content_type='application/json',
            HTTP_X_CSRFTOKEN=token,
        )
        self.assertEqual(wrong_pw.status_code, 403)

        ok_resp = self.csrf_client.post(
            '/api/core/auth/deletion-request/',
            data=json.dumps({'password': 'StrongPassword!2026', 'source': 'mobile', 'note': 'Test request'}),
            content_type='application/json',
            HTTP_X_CSRFTOKEN=token,
        )
        self.assertEqual(ok_resp.status_code, 201)
        payload = ok_resp.json()
        self.assertTrue(payload['requested'])
        self.assertFalse(payload['deleted_immediately'])
        self.assertEqual(payload['status'], 'pending')
        self.assertTrue(payload['reference_code'].startswith('DEL-'))

        self.user_no_email.refresh_from_db()
        self.assertTrue(self.user_no_email.is_active)

        from core.models import AccountDeletionRequest
        req = AccountDeletionRequest.objects.get(reference_code=payload['reference_code'])
        self.assertFalse(req.has_email)
        self.assertEqual(req.source, 'mobile')

        dup_resp = self.csrf_client.post(
            '/api/core/auth/deletion-request/',
            data=json.dumps({'password': 'StrongPassword!2026', 'source': 'mobile'}),
            content_type='application/json',
            HTTP_X_CSRFTOKEN=token,
        )
        self.assertEqual(dup_resp.status_code, 200)
        self.assertTrue(dup_resp.json()['already_pending'])

    def test_web_account_deletion_page_multilingual_and_authenticated_submission(self):
        client = Client()
        for lang, expected in [
            ('fr', 'Demande de suppression de compte'),
            ('en', 'Account Deletion Request'),
            ('ar', 'طلب حذف الحساب'),
        ]:
            resp = client.get(reverse('web-account-deletion') + f'?lang={lang}')
            self.assertEqual(resp.status_code, 200)
            self.assertContains(resp, expected)
            if lang == 'ar':
                self.assertContains(resp, 'dir="rtl"')

        client.force_login(self.user_no_email)
        bad_post = client.post(reverse('web-account-deletion') + '?lang=fr', {'password': 'bad'})
        self.assertEqual(bad_post.status_code, 200)
        self.assertContains(bad_post, 'Mot de passe incorrect')

        good_post = client.post(
            reverse('web-account-deletion') + '?lang=fr',
            {'password': 'StrongPassword!2026', 'note': 'Web test'},
        )
        self.assertEqual(good_post.status_code, 200)
        self.assertContains(good_post, 'DEL-')
        self.assertContains(good_post, 'pas encore supprimé')

    def test_deletion_security_csrf_rate_limit_third_party_and_admin_access(self):
        import json
        from django.core.cache import caches
        from django.utils import timezone
        from core.models import AccountDeletionRequest

        caches['feedback'].clear()

        # 1. CSRF enforcement on API deletion request
        no_csrf = self.csrf_client.post(
            '/api/core/auth/deletion-request/',
            data=json.dumps({'password': 'StrongPassword!2026'}),
            content_type='application/json',
        )
        self.assertEqual(no_csrf.status_code, 403)

        # 2. Third-party protection: payload targeting another user is ignored; only request.user is used
        other_user = self.User.objects.create_user(
            username='victim_user',
            email='victim@example.test',
            password='VictimPassword!2026',
        )
        token = self._csrf_token(self.csrf_client)
        login_resp = self.csrf_client.post(
            '/api/core/auth/login/',
            data=json.dumps({'username': 'learner_no_email', 'password': 'StrongPassword!2026'}),
            content_type='application/json',
            HTTP_X_CSRFTOKEN=token,
        )
        self.assertEqual(login_resp.status_code, 200)
        token = login_resp.json()['csrf_token']

        spoof_resp = self.csrf_client.post(
            '/api/core/auth/deletion-request/',
            data=json.dumps({
                'password': 'StrongPassword!2026',
                'username': 'victim_user',
                'user_id': other_user.pk,
                'source': 'mobile',
            }),
            content_type='application/json',
            HTTP_X_CSRFTOKEN=token,
        )
        self.assertEqual(spoof_resp.status_code, 201)
        self.assertFalse(AccountDeletionRequest.objects.filter(user=other_user).exists())
        created = AccountDeletionRequest.objects.get(user=self.user_no_email)
        self.assertEqual(created.requested_username, 'learner_no_email')

        # 3. Rate limiting (5/hour -> 6th request returns 429)
        for _ in range(4):
            r = self.csrf_client.post(
                '/api/core/auth/deletion-request/',
                data=json.dumps({'password': 'WrongPassword!'}),
                content_type='application/json',
                HTTP_X_CSRFTOKEN=token,
            )
            self.assertEqual(r.status_code, 403)
        throttled = self.csrf_client.post(
            '/api/core/auth/deletion-request/',
            data=json.dumps({'password': 'StrongPassword!2026'}),
            content_type='application/json',
            HTTP_X_CSRFTOKEN=token,
        )
        self.assertEqual(throttled.status_code, 429)

        # 4. Admin-only access & manual workflow
        learner_client = Client()
        learner_client.force_login(self.user_no_email)
        admin_url = reverse('admin:core_accountdeletionrequest_changelist')
        learner_admin = learner_client.get(admin_url)
        self.assertIn(learner_admin.status_code, (302, 403))

        staff_user = self.User.objects.create_user(
            username='admin_reviewer',
            email='',
            password='AdminPassword!2026',
            is_staff=True,
            is_superuser=True,
        )
        admin_client = Client()
        admin_client.force_login(staff_user)
        staff_admin = admin_client.get(admin_url)
        self.assertEqual(staff_admin.status_code, 200)
        self.assertContains(staff_admin, created.reference_code)

        created.status = AccountDeletionRequest.STATUS_COMPLETED
        created.processed_at = timezone.now()
        created.admin_notes = 'Manual test deletion verified'
        created.save()
        created.refresh_from_db()
        self.assertEqual(created.status, AccountDeletionRequest.STATUS_COMPLETED)

    def test_atomic_admin_account_deletion_erases_and_anonymizes_all_user_data(self):
        import json
        from unittest.mock import patch
        from django.contrib.sessions.models import Session
        from core.models import AccountDeletionRequest
        from feedback.models import FeedbackReport
        from learning.models import LearningTheme, LearningUnit
        from no_ena.models import NoEnaPublication
        from progress.models import ProgressDeviceCredential, UnitProgress

        fict = self.User.objects.create_user(
            username='fict_full_erase',
            email='fict_full@example.test',
            password='FictErasePass!2026',
        )
        staff = self.User.objects.create_user(
            username='admin_erase_op',
            email='',
            password='AdminErasePass!2026',
            is_staff=True,
            is_superuser=True,
        )

        theme = LearningTheme.objects.create(slug='t-erase', title_fr='T', status=LearningTheme.PUBLISHED)
        unit = LearningUnit.objects.create(theme=theme, slug='u-erase', title_fr='U', status=LearningUnit.PUBLISHED)
        ProgressDeviceCredential.objects.create(
            device_id=f'account:{fict.pk}',
            token_digest='a' * 64,
            user=fict,
            account_bound=True,
        )
        UnitProgress.objects.create(
            user=fict,
            device_id=f'account:{fict.pk}',
            unit=unit,
            status=UnitProgress.COMPLETED,
            completed=True,
        )
        fb = FeedbackReport.objects.create(
            user=fict,
            device_id='dev-fict-123',
            message='Fictitious bug report',
        )
        pub = NoEnaPublication.objects.create(
            slug='noena-fict-erase',
            title_fr='Test',
            contributor_user=fict,
        )

        # Create active session & deletion request via API
        user_client = Client()
        token = self._csrf_token(user_client)
        login_r = user_client.post(
            '/api/core/auth/login/',
            data=json.dumps({'username': 'fict_full_erase', 'password': 'FictErasePass!2026'}),
            content_type='application/json',
            HTTP_X_CSRFTOKEN=token,
        )
        self.assertEqual(login_r.status_code, 200)
        token = login_r.json()['csrf_token']
        del_r = user_client.post(
            '/api/core/auth/deletion-request/',
            data=json.dumps({'password': 'FictErasePass!2026', 'note': 'Mon nom est Fictif'}),
            content_type='application/json',
            HTTP_X_CSRFTOKEN=token,
        )
        self.assertEqual(del_r.status_code, 201)
        req = AccountDeletionRequest.objects.get(reference_code=del_r.json()['reference_code'])

        # Guard: cannot mark completed via Admin form while user still exists
        admin_client = Client()
        admin_client.force_login(staff)
        change_url = reverse('admin:core_accountdeletionrequest_change', args=[req.pk])
        guard_resp = admin_client.post(change_url, {'status': AccountDeletionRequest.STATUS_COMPLETED})
        self.assertEqual(guard_resp.status_code, 200)
        req.refresh_from_db()
        self.assertEqual(req.status, AccountDeletionRequest.STATUS_PENDING)

        # Rollback test: failure mid-deletion must not leave partial deletion or mark completed
        from core.deletion import execute_account_deletion
        with patch('django.db.models.query.QuerySet.delete', side_effect=RuntimeError('Simulated DB error')):
            with self.assertRaises(RuntimeError):
                execute_account_deletion(req)
        self.assertTrue(self.User.objects.filter(pk=fict.pk).exists())
        self.assertTrue(UnitProgress.objects.filter(user=fict).exists())
        req.refresh_from_db()
        self.assertEqual(req.status, AccountDeletionRequest.STATUS_PENDING)

        # Execute atomic deletion via Django Admin action
        changelist_url = reverse('admin:core_accountdeletionrequest_changelist')
        action_resp = admin_client.post(
            changelist_url,
            {
                'action': 'execute_selected_account_deletions',
                '_selected_action': [str(req.pk)],
            },
        )
        self.assertEqual(action_resp.status_code, 302)

        # Verify post-deletion state across all models
        self.assertFalse(self.User.objects.filter(pk=fict.pk).exists())
        self.assertFalse(UnitProgress.objects.filter(device_id=f'account:{fict.pk}').exists())
        self.assertFalse(ProgressDeviceCredential.objects.filter(device_id=f'account:{fict.pk}').exists())

        fb.refresh_from_db()
        self.assertIsNone(fb.user)
        self.assertEqual(fb.device_id, '')

        pub.refresh_from_db()
        self.assertIsNone(pub.contributor_user)

        req.refresh_from_db()
        self.assertIsNone(req.user)
        self.assertEqual(req.status, AccountDeletionRequest.STATUS_COMPLETED)
        self.assertEqual(req.requested_username, f'[deleted:{req.reference_code}]')
        self.assertEqual(req.user_note, '')
        self.assertIsNotNone(req.processed_at)

        active_user_sessions = [
            s for s in Session.objects.all()
            if str(s.get_decoded().get('_auth_user_id', '')) == str(fict.pk)
        ]
        self.assertEqual(active_user_sessions, [])


class ChildSafetyGuestAndRegistrationAuditTests(TestCase):
    def setUp(self):
        from django.core.cache import caches
        caches['feedback'].clear()

    def test_guest_learning_and_privacy_multilingual_without_account(self):
        for path in (reverse('web-home'), reverse('web-learning-path'), reverse('web-privacy')):
            for lang in ('fr', 'en', 'ar'):
                resp = self.client.get(f'{path}?lang={lang}')
                self.assertEqual(resp.status_code, 200)
                if lang == 'ar':
                    self.assertContains(resp, 'dir="rtl"')
        self.assertEqual(self.client.get('/api/learning/units/').status_code, 200)
        self.assertEqual(self.client.get('/api/offline-packs/').status_code, 200)

    def test_adult_registration_minimal_fields_and_no_unapproved_collection(self):
        import json
        from django.contrib.auth import get_user_model

        client = Client(enforce_csrf_checks=True)
        token = client.get('/api/core/auth/csrf/').json()['csrf_token']
        resp = client.post(
            '/api/core/auth/register/',
            data=json.dumps({
                'username': 'adult_audit_user',
                'email': '',
                'password': 'StrongAdultPass!2026',
                'password_confirm': 'StrongAdultPass!2026',
            }),
            content_type='application/json',
            HTTP_X_CSRFTOKEN=token,
        )
        self.assertEqual(resp.status_code, 201)
        payload = resp.json()
        self.assertTrue(payload['authenticated'])
        self.assertEqual(payload['username'], 'adult_audit_user')
        self.assertFalse(payload['is_staff'])

        User = get_user_model()
        user = User.objects.get(username='adult_audit_user')
        self.assertEqual(user.email, '')
        self.assertEqual(user.first_name, '')
        self.assertEqual(user.last_name, '')

    def test_guest_feedback_strips_persistent_device_id_server_side(self):
        import json
        from feedback.models import FeedbackReport

        resp = self.client.post(
            '/api/feedback/create/',
            data=json.dumps({
                'feedback_type': 'technical',
                'title': 'Guest test',
                'message': 'Guest report without storing device_id',
                'device_id': 'guest-device-xyz-123',
                'platform': 'android',
                'language_code': 'fr',
            }),
            content_type='application/json',
        )
        self.assertEqual(resp.status_code, 201)
        fb = FeedbackReport.objects.get(pk=resp.json()['id'])
        self.assertIsNone(fb.user)
        self.assertEqual(fb.device_id, '')

    def test_web_registration_modal_shows_parental_and_guest_notice_fr_en_ar(self):
        for lang, expected in [
            ('fr', 'privilégie le <strong>mode invité</strong>'),
            ('en', 'prefer <strong>guest mode</strong>'),
            ('ar', '<strong>وضع الضيف</strong>'),
        ]:
            resp = self.client.get(reverse('web-home') + f'?lang={lang}')
            self.assertEqual(resp.status_code, 200)
            self.assertContains(resp, expected)
            self.assertContains(resp, reverse('web-privacy'))
            if lang == 'ar':
                self.assertContains(resp, 'dir="rtl"')
