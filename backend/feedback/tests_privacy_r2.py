from datetime import timedelta
import logging

from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.models import Permission
from django.test import Client, TestCase, override_settings
from django.urls import reverse
from django.utils import timezone

from audio_assets.models import AudioAsset
from core.deletion import execute_account_deletion
from core.models import AccountDeletionRequest
from feedback.models import FeedbackReport
from feedback.privacy_service import (
    REDACTED_MESSAGE_PLACEHOLDER,
    REDACTED_TITLE_PLACEHOLDER,
    get_retention_diagnostics,
    purge_feedback_media,
    redact_feedback_pii,
    validate_feedback_media_path,
)


class _FakeStorage:
    """Stockage entièrement local en mémoire — garantit 0 appel réseau R2 réel."""

    def __init__(self, files=None, fail_on=None):
        self.files = set(files or [])
        self.fail_on = set(fail_on or [])
        self.deleted = []

    def exists(self, name):
        return name in self.files

    def delete(self, name):
        if name in self.fail_on:
            raise OSError('Simulated R2 outage')
        self.deleted.append(name)
        self.files.discard(name)


@override_settings(USE_R2=False)
class FeedbackPrivacyAndR2SafetyTests(TestCase):
    def setUp(self):
        self.assertFalse(settings.USE_R2, 'Les tests ne doivent jamais contacter le vrai bucket R2.')
        self.User = get_user_model()
        self.staff_full = self.User.objects.create_user(
            username='admin_r2_full',
            password='StrongAdminPass!2026',
            is_staff=True,
            is_superuser=True,
        )
        self.staff_readonly = self.User.objects.create_user(
            username='admin_r2_ro',
            password='StrongStaffPass!2026',
            is_staff=True,
            is_superuser=False,
        )
        view_perm = Permission.objects.get(codename='view_feedbackreport')
        self.staff_readonly.user_permissions.add(view_perm)

    def _make_feedback(self, *, screenshot='', audio_asset=None, user=None, device_id='', title='T', message='M', status=FeedbackReport.NEW):
        fb = FeedbackReport.objects.create(
            user=user,
            device_id=device_id,
            title=title,
            message=message,
            status=status,
            audio_feedback=audio_asset,
        )
        if screenshot:
            FeedbackReport.objects.filter(pk=fb.pk).update(screenshot=screenshot)
            fb.refresh_from_db()
        return fb

    def _make_audio(self, *, audio_type, file_path):
        asset = AudioAsset.objects.create(title='Test audio', audio_type=audio_type)
        AudioAsset.objects.filter(pk=asset.pk).update(file=file_path)
        asset.refresh_from_db()
        return asset

    # --- Tests médias (1 à 13) ---

    def test_01_and_02_delete_valid_screenshot_and_feedback_audio(self):
        audio = self._make_audio(audio_type=AudioAsset.FEEDBACK, file_path='feedback/audio/clip1.mp3')
        fb = self._make_feedback(screenshot='feedback/screenshots/shot1.png', audio_asset=audio)
        fake = _FakeStorage(files={'feedback/screenshots/shot1.png', 'feedback/audio/clip1.mp3'})

        rep = purge_feedback_media(fb, dry_run=False, storage_resolver=lambda kind, s: fake)
        self.assertEqual(rep.overall_status, 'completed')
        self.assertEqual([i.status for i in rep.items], ['deleted', 'deleted'])
        self.assertEqual(set(fake.deleted), {'feedback/screenshots/shot1.png', 'feedback/audio/clip1.mp3'})
        fb.refresh_from_db()
        self.assertEqual(fb.screenshot.name, '')
        self.assertIsNone(fb.audio_feedback)
        self.assertFalse(AudioAsset.objects.filter(pk=audio.pk).exists())

    def test_03_04_05_06_reject_outside_prefix_pedagogical_shared_and_wildcard(self):
        # Chemins hors préfixe / traversal / wildcard / suppression par préfixe
        for bad in (
            'audio_assets/files/lesson1.mp3',
            'private/offline_packs/pack.zip',
            'feedback/screenshots/',
            'feedback/screenshots/*',
            'feedback/screenshots/../audio/a.mp3',
            '/feedback/screenshots/a.png',
        ):
            ok, _ = validate_feedback_media_path(bad, kind='screenshot')
            self.assertFalse(ok, f'{bad} aurait dû être refusé')

        # Fichier pédagogique (audio_type='character') protégé même si lié accidentellement
        ped_audio = self._make_audio(audio_type=AudioAsset.CHARACTER, file_path='audio_assets/files/erfe_a.mp3')
        fb_ped = self._make_feedback(audio_asset=ped_audio)
        fake = _FakeStorage(files={'audio_assets/files/erfe_a.mp3'})
        rep = purge_feedback_media(fb_ped, dry_run=False, storage_resolver=lambda kind, s: fake)
        self.assertEqual(rep.overall_status, 'rejected')
        self.assertEqual(rep.items[0].status, 'rejected')
        self.assertEqual(fake.deleted, [])
        self.assertTrue(AudioAsset.objects.filter(pk=ped_audio.pk).exists())

        # Audio feedback partagé entre deux feedbacks -> refusé
        shared_audio = self._make_audio(audio_type=AudioAsset.FEEDBACK, file_path='feedback/audio/shared.mp3')
        fb1 = self._make_feedback(audio_asset=shared_audio)
        self._make_feedback(audio_asset=shared_audio)
        rep_shared = purge_feedback_media(fb1, dry_run=False, storage_resolver=lambda kind, s: fake)
        self.assertEqual(rep_shared.overall_status, 'rejected')
        self.assertTrue(AudioAsset.objects.filter(pk=shared_audio.pk).exists())

    def test_07_dry_run_does_not_delete_storage_or_db(self):
        fb = self._make_feedback(screenshot='feedback/screenshots/dry.png')
        fake = _FakeStorage(files={'feedback/screenshots/dry.png'})
        rep = purge_feedback_media(fb, dry_run=True, storage_resolver=lambda kind, s: fake)
        self.assertEqual(rep.overall_status, 'dry_run')
        self.assertEqual(rep.items[0].status, 'would_delete')
        self.assertEqual(fake.deleted, [])
        fb.refresh_from_db()
        self.assertEqual(fb.screenshot.name, 'feedback/screenshots/dry.png')

    def test_08_09_10_11_absent_error_partial_and_idempotent_retry(self):
        # Objet déjà absent -> already_absent + nettoyage DB idempotent
        fb_abs = self._make_feedback(screenshot='feedback/screenshots/missing.png')
        fake_empty = _FakeStorage(files=set())
        rep_abs = purge_feedback_media(fb_abs, dry_run=False, storage_resolver=lambda kind, s: fake_empty)
        self.assertEqual(rep_abs.overall_status, 'completed')
        self.assertEqual(rep_abs.items[0].status, 'already_absent')
        fb_abs.refresh_from_db()
        self.assertEqual(fb_abs.screenshot.name, '')

        # Répétition idempotente -> noop
        rep_repeat = purge_feedback_media(fb_abs, dry_run=False, storage_resolver=lambda kind, s: fake_empty)
        self.assertEqual(rep_repeat.overall_status, 'noop')

        # Suppression partielle : screenshot OK, audio en erreur R2 simulée -> overall_status='partial', référence audio conservée
        audio = self._make_audio(audio_type=AudioAsset.FEEDBACK, file_path='feedback/audio/fail.mp3')
        fb_part = self._make_feedback(screenshot='feedback/screenshots/ok.png', audio_asset=audio)
        fake_partial = _FakeStorage(
            files={'feedback/screenshots/ok.png', 'feedback/audio/fail.mp3'},
            fail_on={'feedback/audio/fail.mp3'},
        )
        rep_part = purge_feedback_media(fb_part, dry_run=False, storage_resolver=lambda kind, s: fake_partial)
        self.assertEqual(rep_part.overall_status, 'partial')
        fb_part.refresh_from_db()
        self.assertEqual(fb_part.screenshot.name, '')
        self.assertEqual(fb_part.audio_feedback_id, audio.pk)

        # Reprise manuelle après rétablissement R2 -> completed
        fake_partial.fail_on.clear()
        rep_retry = purge_feedback_media(fb_part, dry_run=False, storage_resolver=lambda kind, s: fake_partial)
        self.assertEqual(rep_retry.overall_status, 'completed')
        fb_part.refresh_from_db()
        self.assertIsNone(fb_part.audio_feedback)

    def test_12_and_13_admin_permissions_preview_confirm_and_direct_delete_orphan_guard(self):
        fb = self._make_feedback(screenshot='feedback/screenshots/admin_shot.png')
        changelist = reverse('admin:feedback_feedbackreport_changelist')

        # Permissions insuffisantes -> 403
        ro_client = Client()
        ro_client.force_login(self.staff_readonly)
        denied = ro_client.post(
            changelist,
            {'action': 'purge_feedback_media_action', '_selected_action': [str(fb.pk)]},
        )
        self.assertEqual(denied.status_code, 403)

        # Admin autorisé : prévisualisation (dry-run) sans suppression
        admin_client = Client()
        admin_client.force_login(self.staff_full)
        preview = admin_client.post(
            changelist,
            {'action': 'purge_feedback_media_action', '_selected_action': [str(fb.pk)]},
        )
        self.assertEqual(preview.status_code, 200)
        self.assertContains(preview, 'feedback/screenshots/admin_shot.png')
        self.assertContains(preview, 'would_delete')

        # Protection contre suppression directe d'un feedback avec média attaché
        del_url = reverse('admin:feedback_feedbackreport_delete', args=[fb.pk])
        del_resp = admin_client.post(del_url, {'post': 'yes'})
        self.assertEqual(del_resp.status_code, 302)
        self.assertTrue(FeedbackReport.objects.filter(pk=fb.pk).exists())

    # --- Tests confidentialité PII (1 à 7) + diagnostics ---

    def test_pii_clear_all_manual_redaction_no_pii_in_logs_and_09deff1_compatibility(self):
        learner = self.User.objects.create_user(username='fict_fb_user', password='StrongPass!2026')
        fb = self._make_feedback(
            user=learner,
            device_id='dev-123',
            title='Je suis Jean Dupont',
            message='Appelez-moi au +33 6 12 34 56 78 ou jean@example.test sur la leçon 1',
            status=FeedbackReport.FIXED,
        )

        # Caviardage manuel via Admin + vérification qu'aucun log ne contient le texte PII original
        admin_client = Client()
        admin_client.force_login(self.staff_full)
        changelist = reverse('admin:feedback_feedbackreport_changelist')
        preview = admin_client.post(
            changelist,
            {'action': 'redact_feedback_pii_action', '_selected_action': [str(fb.pk)]},
        )
        self.assertEqual(preview.status_code, 200)
        self.assertContains(preview, 'email_pattern_detected')

        with self.assertLogs('django', level='DEBUG') as captured:
            logging.getLogger('django').debug('audit-marker')
            confirm = admin_client.post(
                changelist,
                {
                    'action': 'redact_feedback_pii_action',
                    'confirm_redact': 'yes',
                    'redaction_mode': 'manual',
                    '_selected_action': [str(fb.pk)],
                    f'manual_title_{fb.pk}': 'Problème leçon 1',
                    f'manual_message_{fb.pk}': 'Bug audio sur la leçon 1 [coordonnées retirées]',
                },
                follow=True,
            )
        self.assertEqual(confirm.status_code, 200)
        for line in captured.output:
            self.assertNotIn('jean@example.test', line)
            self.assertNotIn('Jean Dupont', line)
        fb.refresh_from_db()
        self.assertEqual(fb.title, 'Problème leçon 1')
        self.assertEqual(fb.device_id, '')
        self.assertEqual(fb.feedback_type, FeedbackReport.OTHER)

        # Suppression complète clear_all
        redact_feedback_pii(fb, mode='clear_all', dry_run=False)
        fb.refresh_from_db()
        self.assertEqual(fb.title, REDACTED_TITLE_PLACEHOLDER)
        self.assertEqual(fb.message, REDACTED_MESSAGE_PLACEHOLDER)

        # Compatibilité 09deff1
        req = AccountDeletionRequest.objects.create(user=learner, requested_username=learner.username, source='web')
        execute_account_deletion(req)
        fb.refresh_from_db()
        self.assertIsNone(fb.user)
        self.assertEqual(fb.device_id, '')

    def test_retention_diagnostics_non_destructive(self):
        old_dt = timezone.now() - timedelta(days=400)
        fb_old = self._make_feedback(
            screenshot='feedback/screenshots/old.png',
            title='Ancien ticket',
            message='Texte libre',
            status=FeedbackReport.FIXED,
        )
        FeedbackReport.objects.filter(pk=fb_old.pk).update(resolved_at=old_dt)
        orphan_audio = self._make_audio(audio_type=AudioAsset.FEEDBACK, file_path='feedback/audio/orphan.mp3')

        diag = get_retention_diagnostics()
        self.assertIn(fb_old.pk, diag['closed_feedbacks_over_12m_ids'])
        self.assertIn(fb_old.pk, diag['closed_media_over_90d_ids'])
        self.assertIn(fb_old.pk, diag['ownerless_free_text_ids'])
        self.assertIn(orphan_audio.pk, diag['unlinked_feedback_audio_ids'])
        # Non destructif : tout existe encore
        self.assertTrue(FeedbackReport.objects.filter(pk=fb_old.pk).exists())
        self.assertTrue(AudioAsset.objects.filter(pk=orphan_audio.pk).exists())
