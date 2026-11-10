import io
import os
import tempfile
import wave
import zipfile
from pathlib import Path
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.exceptions import ImproperlyConfigured, ValidationError, SuspiciousFileOperation
from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.files.storage import FileSystemStorage
from django.test import SimpleTestCase, TestCase, override_settings
from PIL import Image
from rest_framework.test import APIClient

from config.security import build_security_settings
from audio_assets.models import AudioAsset
from feedback.models import FeedbackReport
from vocabulary.models import Word
from no_ena.models import NoEnaPublication
from offline_packs.models import LessonPack
from django.core.management import call_command, CommandError

FIXTURE_SECRET = 'phase63-test-only-0123456789-ABCDEFGHIJKLMNOPQRSTUVWXYZ-not-real'


def png(name='test.png'):
    data=io.BytesIO(); Image.new('RGB',(8,8)).save(data,format='PNG')
    return SimpleUploadedFile(name,data.getvalue(),'image/png')


class StagingSecurityTests(SimpleTestCase):
    def build(self, **values):
        env={'DJANGO_ENV':'staging','SECRET_KEY':FIXTURE_SECRET,
             'ALLOWED_HOSTS':'staging-api.example.org',
             'CSRF_TRUSTED_ORIGINS':'https://staging.example.org',**values}
        return build_security_settings(env.get)

    def test_staging_uses_production_guards_and_its_own_hosts(self):
        config=self.build()
        for name in ('SECURE_SSL_REDIRECT','SESSION_COOKIE_SECURE','CSRF_COOKIE_SECURE'):
            self.assertTrue(config[name])
        self.assertFalse(config['DEBUG'])
        self.assertEqual(config['ALLOWED_HOSTS'],['staging-api.example.org'])
        self.assertGreater(config['SECURE_HSTS_SECONDS'],0)

    def test_staging_rejects_unsafe_settings(self):
        for values in ({'DEBUG':'True'},{'SECRET_KEY':'short'},
                       {'ALLOWED_HOSTS':'*'},{'ALLOWED_HOSTS':'https://wrong.example.org'},
                       {'CSRF_TRUSTED_ORIGINS':'http://staging.example.org'},
                       {'SECURE_SSL_REDIRECT':'False'},
                       {'CORS_ALLOWED_ORIGINS':'http://staging.example.org'},
                       {'CORS_ALLOW_ALL_ORIGINS':'True'}):
            with self.subTest(keys=list(values)),self.assertRaises(ImproperlyConfigured):
                self.build(**values)

    def test_production_rejects_wildcard_cors(self):
        with self.assertRaises(ImproperlyConfigured):
            self.build(DJANGO_ENV='production',CORS_ALLOW_ALL_ORIGINS='True')


class MediaSecurityTests(TestCase):
    def setUp(self):
        self.private=tempfile.TemporaryDirectory(prefix='bk-private-test-')
        self.addCleanup(self.private.cleanup)
        self.override=override_settings(PRIVATE_MEDIA_ROOT=self.private.name)
        self.override.enable(); self.addCleanup(self.override.disable)
        self.a=get_user_model().objects.create_user('qa63-a')
        self.b=get_user_model().objects.create_user('qa63-b')
        self.staff=get_user_model().objects.create_user('qa63-staff',is_staff=True)
        self.api=APIClient()

    def test_published_feedback_audio_never_becomes_public(self):
        audio=AudioAsset.objects.create(audio_type='feedback',validation_status='published',
                                       file='audio_assets/files/legacy-private.wav')
        for user in (None,self.a,self.b):
            self.api.force_authenticate(user=user)
            self.assertEqual(self.api.get(f'/api/audio/{audio.pk}/').status_code,404)
        self.api.force_authenticate(user=self.staff)
        self.assertEqual(self.api.get(f'/api/audio/{audio.pk}/').status_code,200)

    def test_public_teaching_audio_stays_public(self):
        audio=AudioAsset.objects.create(audio_type='character',validation_status='published',
                                       file='audio_assets/files/public.wav')
        self.assertEqual(self.api.get(f'/api/audio/{audio.pk}/').status_code,200)

    def test_new_feedback_screenshot_is_private_and_staff_only(self):
        report=FeedbackReport.objects.create(user=self.a,message='Synthetic QA',screenshot=png())
        self.assertTrue(report.screenshot.url.startswith('/api/feedback/attachments/'))
        self.assertTrue(Path(self.private.name,report.screenshot.name).is_file())
        for user in (None,self.a,self.b):
            self.api.force_authenticate(user=user)
            self.assertIn(self.api.get(report.screenshot.url).status_code,(403,404))
        self.api.force_authenticate(user=self.staff)
        response=self.api.get(report.screenshot.url)
        self.assertEqual(response.status_code,200)
        self.assertEqual(b''.join(response.streaming_content)[:8],b'\x89PNG\r\n\x1a\n')
        self.assertIn('no-store',response['Cache-Control'])

    def test_invalid_image_is_rejected_before_storage_even_on_direct_save(self):
        with self.assertRaises(ValidationError):
            Word.objects.create(beriya_text='𖺠',image=SimpleUploadedFile('fake.png',b'<script>x</script>','image/png'))

    def test_invalid_video_is_rejected(self):
        with self.assertRaises(ValidationError):
            NoEnaPublication.objects.create(title_fr='Synthetic QA',slug='synthetic-qa',
              video_file=SimpleUploadedFile('fake.mp4',b'not a video','video/mp4'))

    def test_legacy_file_reference_is_not_revalidated_or_rewritten(self):
        word=Word.objects.create(beriya_text='𖺠',image='legacy/not-available.gif')
        word.save()
        self.assertEqual(word.image.name,'legacy/not-available.gif')

    def test_public_storage_rejects_traversal(self):
        with tempfile.TemporaryDirectory() as directory:
            storage=FileSystemStorage(directory)
            with self.assertRaises(SuspiciousFileOperation):
                storage.save('../outside.png',png())

    def test_valid_new_images_and_feedback_audio_remain_accessible_to_staff(self):
        word=Word.objects.create(beriya_text='𖺠',image=png())
        self.assertIn('/media/',word.image.url)
        content=io.BytesIO()
        with wave.open(content,'wb') as wav:
            wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(8000);wav.writeframes(b'\0\0'*80)
        audio=AudioAsset.objects.create(audio_type='feedback',
            file=SimpleUploadedFile('feedback.wav',content.getvalue(),'audio/wav'))
        self.assertTrue(audio.file.name.startswith('feedback/audio/'))
        self.assertTrue(Path(self.private.name,audio.file.name).is_file())
        self.api.force_authenticate(user=self.a)
        self.assertEqual(self.api.get(audio.file.url,HTTP_X_DEVICE_TOKEN='forged').status_code,403)
        self.api.force_authenticate(user=self.staff)
        response=self.api.get(audio.file.url)
        self.assertEqual(response.status_code,200)
        response.close()

    def test_legacy_screenshot_staff_compatibility_and_direct_path_denial(self):
        from django.core.files.storage import default_storage
        from core.media_access import PublicMediaGuard
        from django.test import RequestFactory
        from django.http import HttpResponse
        name=default_storage.save('feedback/screenshots/legacy.png',png())
        report=FeedbackReport.objects.create(message='Synthetic QA',screenshot=name)
        self.api.force_authenticate(user=self.staff)
        response=self.api.get(report.screenshot.url)
        self.assertEqual(response.status_code,200);response.close()
        guard=PublicMediaGuard(lambda req:HttpResponse('public'))
        self.assertEqual(guard(RequestFactory().get('/media/'+name)).status_code,404)
        self.assertEqual(guard(RequestFactory().get('/media/folder/../'+name)).status_code,404)
        self.assertEqual(guard(RequestFactory().get('/media/'+name.replace('feedback/','FeedBack/'))).status_code,404)
        self.assertEqual(guard(RequestFactory().get('/media/words/images/public.png')).status_code,200)

    def test_public_packs_and_staff_drafts_keep_their_permissions(self):
        public=LessonPack.objects.create(slug='qa63-public',title_fr='Synthetic QA',status='published')
        draft=LessonPack.objects.create(slug='qa63-draft',title_fr='Synthetic QA',status='draft')
        for user in (None,self.a,self.b):
            self.api.force_authenticate(user=user)
            self.assertEqual(self.api.get(f'/api/offline-packs/{public.pk}/').status_code,200)
            self.assertEqual(self.api.get(f'/api/offline-packs/{draft.pk}/').status_code,404)
        self.api.force_authenticate(user=self.staff)
        self.assertEqual(self.api.get(f'/api/offline-packs/{draft.pk}/').status_code,200)

    def test_zip_traversal_corruption_and_symlink_rejected_but_valid_pack_saved(self):
        def archive(path,mode=None):
            data=io.BytesIO()
            with zipfile.ZipFile(data,'w') as z:
                entry=zipfile.ZipInfo(path)
                if mode is not None:entry.external_attr=mode<<16
                z.writestr(entry,'{}')
            payload=data.getvalue()
            if '\\' in path:
                payload=payload.replace(path.replace('\\','/').encode(),path.encode())
            return SimpleUploadedFile('pack.zip',payload)
        for path,mode in (('../outside.json',None),('/absolute.json',None),('C:/bad.json',None),
                          ('dir\\bad.json',None),('link',0o120777)):
            with self.subTest(path=path),self.assertRaises(ValidationError):
                LessonPack.objects.create(slug='bad',title_fr='Synthetic QA',file=archive(path,mode))
        pack=LessonPack.objects.create(slug='good',title_fr='Synthetic QA',file=archive('manifest.json'))
        self.assertEqual(len(pack.checksum),64)
        data=io.BytesIO()
        with zipfile.ZipFile(data,'w',compression=zipfile.ZIP_DEFLATED) as z:
            z.writestr('manifest.json','a'*1000)
        damaged=bytearray(data.getvalue())
        import struct
        name_length,extra_length=struct.unpack_from('<HH',damaged,26)
        damaged[30+name_length+extra_length]=7  # Invalid DEFLATE block type.
        with self.assertRaises(ValidationError):
            LessonPack.objects.create(slug='bad-deflate',title_fr='Synthetic QA',
                file=SimpleUploadedFile('bad.zip',bytes(damaged)))

    def test_size_caps_are_enforced_without_reading_large_bodies(self):
        upload=png();upload.size=6*1024*1024
        with self.assertRaises(ValidationError):
            Word.objects.create(beriya_text='𖺠',image=upload)

    def test_bootstrap_requires_opt_in_and_a_valid_password(self):
        with patch.dict(os.environ,{'BOOTSTRAP_SUPERUSER':'false',
                'DJANGO_SUPERUSER_USERNAME':'qa63-bootstrap','DJANGO_SUPERUSER_PASSWORD':'fixture-password'}):
            call_command('bootstrap_render',stdout=io.StringIO())
        self.assertFalse(get_user_model().objects.filter(username='qa63-bootstrap').exists())
        with patch.dict(os.environ,{'BOOTSTRAP_SUPERUSER':'true',
                'DJANGO_SUPERUSER_USERNAME':'qa63-bootstrap','DJANGO_SUPERUSER_PASSWORD':'123'}):
            with self.assertRaises(CommandError):
                call_command('bootstrap_render',stdout=io.StringIO())

    def test_container_signatures_alone_do_not_make_valid_audio_or_video(self):
        with self.assertRaises(ValidationError):
            AudioAsset.objects.create(audio_type='word',file=SimpleUploadedFile('fake.mp3',b'ID3'+b'\0'*40))
        with self.assertRaises(ValidationError):
            NoEnaPublication.objects.create(slug='bad-container',title_fr='Synthetic QA',
              video_file=SimpleUploadedFile('bad.mp4',b'\0\0\0\x10ftypisom'+b'\0'*32))

    def test_private_download_with_real_basic_auth_and_inactive_account(self):
        import base64
        password='qa63-only-synthetic-password-927461'
        self.staff.set_password(password);self.staff.save()
        report=FeedbackReport.objects.create(message='Synthetic QA',screenshot=png())
        auth=base64.b64encode(f'{self.staff.username}:{password}'.encode()).decode()
        self.api.credentials(HTTP_AUTHORIZATION='Basic '+auth)
        response=self.api.get(report.screenshot.url,secure=True)
        self.assertEqual(response.status_code,200);response.close()
        self.staff.is_active=False;self.staff.save()
        self.assertIn(self.api.get(report.screenshot.url,secure=True).status_code,(401,403))
