from django.contrib.auth import get_user_model
from django.contrib.auth.models import Group
from django.test import Client, TestCase

from alphabet.models import Character
from core.permissions import PILOT_ALLOWED_UNIT_SLUGS, PILOT_GROUP_NAME
from learning.models import LearningTheme, LearningUnit
from lessons.models import Lesson
from offline_packs.models import LessonPack
from quizzes.models import QuizQuestion

User = get_user_model()


class LearnerAuthAndPilotPermissionsTest(TestCase):
    def setUp(self):
        self.pilot_group, _ = Group.objects.get_or_create(name=PILOT_GROUP_NAME)

        self.pilot_user = User.objects.create_user(
            username='pilot_learner',
            password='PilotPassword123!',
        )
        self.pilot_user.groups.add(self.pilot_group)

        self.ordinary_user = User.objects.create_user(
            username='ordinary_learner',
            password='OrdinaryPassword123!',
        )

        self.staff_user = User.objects.create_user(
            username='staff_reviewer',
            password='StaffPassword123!',
            is_staff=True,
        )

        self.theme_pilot = LearningTheme.objects.create(
            slug='theme-pilot-auth',
            title_fr='Thème Pilote',
            title_en='Pilot Theme',
            status='validated',
        )
        self.theme_draft = LearningTheme.objects.create(
            slug='theme-draft-auth',
            title_fr='Thème Brouillon',
            title_en='Draft Theme',
            status='draft',
        )

        self.pilot_unit = LearningUnit.objects.create(
            theme=self.theme_pilot,
            slug=PILOT_ALLOWED_UNIT_SLUGS[0],
            title_fr='ERF-01 Test',
            title_en='ERF-01 Test',
            status='validated',
        )
        self.sixth_validated_unit = LearningUnit.objects.create(
            theme=self.theme_pilot,
            slug='bk-hors-pilote-06',
            title_fr='Unité 6 Hors Pilote',
            title_en='Unit 6 Out Of Pilot',
            status='validated',
        )
        self.draft_unit = LearningUnit.objects.create(
            theme=self.theme_draft,
            slug='bk-preprod-p01',
            title_fr='P01 Brouillon',
            title_en='P01 Draft',
            status='draft',
        )

        self.pilot_char = Character.objects.create(
            symbol='𖺠',
            unicode_code='U+16EA0',
            latin_grapheme='a',
            name_fr='A Erfe',
            name_en='Erfe A',
            validation_status=Character.VALIDATED,
        )
        self.out_char = Character.objects.create(
            symbol='𖺡',
            unicode_code='U+16EA1',
            latin_grapheme='b',
            name_fr='B Erfe',
            name_en='Erfe B',
            validation_status=Character.VALIDATED,
        )
        self.pilot_unit.characters.add(self.pilot_char)
        self.sixth_validated_unit.characters.add(self.out_char)

        self.pilot_lesson = Lesson.objects.create(
            unit=self.pilot_unit,
            slug='lesson-erf-01-auth',
            title_fr='Leçon ERF-01',
            title_en='ERF-01 Lesson',
            status='validated',
        )
        self.out_lesson = Lesson.objects.create(
            unit=self.sixth_validated_unit,
            slug='lesson-hors-pilote-06',
            title_fr='Leçon Hors Pilote',
            title_en='Out Of Pilot Lesson',
            status='validated',
        )
        self.draft_lesson = Lesson.objects.create(
            unit=self.draft_unit,
            slug='lesson-p01-draft',
            title_fr='Leçon P01',
            title_en='P01 Lesson',
            status='draft',
        )

        self.pilot_quiz = QuizQuestion.objects.create(
            unit=self.pilot_unit,
            question_type='TEXT_TO_CHARACTER',
            prompt_fr='Quelle lettre pour a ?',
            character=self.pilot_char,
            status='validated',
        )
        self.out_quiz = QuizQuestion.objects.create(
            unit=self.sixth_validated_unit,
            question_type='TEXT_TO_CHARACTER',
            prompt_fr='Question hors pilote',
            character=self.out_char,
            status='validated',
        )
        self.draft_quiz = QuizQuestion.objects.create(
            unit=self.draft_unit,
            question_type='TEXT_TO_CHARACTER',
            prompt_fr='Question brouillon',
            character=self.pilot_char,
            status='draft',
        )

        self.pilot_pack = LessonPack.objects.create(
            slug='pack-pilot-erf-01',
            title_fr='Pack ERF-01',
            title_en='Pack ERF-01',
            status='validated',
        )
        self.pilot_pack.units.add(self.pilot_unit)

        self.out_pack = LessonPack.objects.create(
            slug='pack-hors-pilote-06',
            title_fr='Pack Hors Pilote',
            title_en='Out Of Pilot Pack',
            status='validated',
        )
        self.out_pack.units.add(self.sixth_validated_unit)

    def _session_login(self, client, username, password):
        csrf_res = client.get('/api/core/auth/csrf/')
        self.assertEqual(csrf_res.status_code, 200)
        csrf_token = csrf_res.json()['csrf_token']
        return client.post(
            '/api/core/auth/login/',
            data={'username': username, 'password': password},
            content_type='application/json',
            HTTP_X_CSRFTOKEN=csrf_token,
        )

    def test_auth_lifecycle_and_fail_closed_responses(self):
        client = Client(enforce_csrf_checks=True)

        me_anon = client.get('/api/core/auth/me/')
        self.assertEqual(me_anon.status_code, 401)

        bad_login = self._session_login(client, 'pilot_learner', 'WrongPass!')
        self.assertEqual(bad_login.status_code, 401)

        good_login = self._session_login(client, 'pilot_learner', 'PilotPassword123!')
        self.assertEqual(good_login.status_code, 200)
        payload = good_login.json()
        self.assertTrue(payload['authenticated'])
        self.assertEqual(payload['username'], 'pilot_learner')
        self.assertTrue(payload['is_pilot'])
        self.assertFalse(payload['is_staff'])

        me_auth = client.get('/api/core/auth/me/')
        self.assertEqual(me_auth.status_code, 200)
        self.assertEqual(me_auth.json()['username'], 'pilot_learner')

        logout_res = client.post(
            '/api/core/auth/logout/',
            data={},
            content_type='application/json',
            HTTP_X_CSRFTOKEN=me_auth.json()['csrf_token'],
        )
        self.assertEqual(logout_res.status_code, 200)
        self.assertEqual(client.get('/api/core/auth/me/').status_code, 401)

    def test_anonymous_and_ordinary_user_cannot_access_pilot_even_with_client_hints(self):
        anon_client = Client()
        self.assertEqual(anon_client.get('/api/learning/units/').json()['results'], [])
        self.assertEqual(
            anon_client.get(f'/api/learning/units/{self.pilot_unit.pk}/').status_code,
            404,
        )

        ord_client = Client(enforce_csrf_checks=True)
        self.assertEqual(
            self._session_login(ord_client, 'ordinary_learner', 'OrdinaryPassword123!').status_code,
            200,
        )
        # Client-side hints must never grant pilot access.
        units_res = ord_client.get(
            '/api/learning/units/?pilot=true&is_pilot=1',
            HTTP_X_PILOT_USER='true',
        )
        self.assertEqual(units_res.status_code, 200)
        self.assertEqual(units_res.json()['results'], [])
        self.assertEqual(
            ord_client.get(f'/api/learning/units/{self.pilot_unit.pk}/').status_code,
            404,
        )
        self.assertEqual(
            ord_client.get(f'/api/lessons/{self.pilot_lesson.pk}/').status_code,
            404,
        )
        self.assertEqual(ord_client.get('/api/quizzes/').json()['results'], [])
        self.assertEqual(ord_client.get('/api/alphabet/characters/').json()['results'], [])
        self.assertEqual(ord_client.get('/api/offline-packs/').json()['results'], [])

    def test_pilot_user_access_scope_and_revocation(self):
        client = Client(enforce_csrf_checks=True)
        self.assertEqual(
            self._session_login(client, 'pilot_learner', 'PilotPassword123!').status_code,
            200,
        )

        # Allowed: ERF-01..ERF-05
        unit_slugs = [u['slug'] for u in client.get('/api/learning/units/').json()['results']]
        self.assertEqual(unit_slugs, [self.pilot_unit.slug])
        self.assertEqual(
            client.get(f'/api/learning/units/{self.pilot_unit.pk}/').status_code,
            200,
        )
        self.assertEqual(
            client.get(f'/api/learning/units/{self.pilot_unit.pk}/core-flow/').status_code,
            200,
        )

        # Blocked: 6th validated unit & draft units (list + direct ID)
        self.assertEqual(
            client.get(f'/api/learning/units/{self.sixth_validated_unit.pk}/').status_code,
            404,
        )
        self.assertEqual(
            client.get(f'/api/learning/units/{self.sixth_validated_unit.pk}/core-flow/').status_code,
            404,
        )
        self.assertEqual(
            client.get(f'/api/learning/units/{self.draft_unit.pk}/').status_code,
            404,
        )

        # Lessons, quizzes, alphabet, offline packs scoped to pilot only
        lesson_slugs = [l['slug'] for l in client.get('/api/lessons/').json()['results']]
        self.assertEqual(lesson_slugs, [self.pilot_lesson.slug])
        self.assertEqual(
            client.get(f'/api/lessons/{self.out_lesson.pk}/').status_code,
            404,
        )
        self.assertEqual(
            client.get(f'/api/lessons/{self.draft_lesson.pk}/').status_code,
            404,
        )

        quiz_ids = [q['id'] for q in client.get('/api/quizzes/').json()['results']]
        self.assertEqual(quiz_ids, [self.pilot_quiz.id])

        char_symbols = [c['symbol'] for c in client.get('/api/alphabet/characters/').json()['results']]
        self.assertEqual(char_symbols, [self.pilot_char.symbol])

        pack_slugs = [p['slug'] for p in client.get('/api/offline-packs/').json()['results']]
        self.assertEqual(pack_slugs, [self.pilot_pack.slug])
        self.assertEqual(
            client.get(f'/api/offline-packs/{self.out_pack.pk}/').status_code,
            404,
        )

        # Revoke group membership on server -> immediate refusal
        self.pilot_user.groups.remove(self.pilot_group)
        self.assertEqual(client.get('/api/learning/units/').json()['results'], [])
        self.assertEqual(
            client.get(f'/api/learning/units/{self.pilot_unit.pk}/').status_code,
            404,
        )
        self.assertEqual(client.get('/api/quizzes/').json()['results'], [])
        self.assertEqual(client.get('/api/alphabet/characters/').json()['results'], [])
        self.assertEqual(client.get('/api/offline-packs/').json()['results'], [])

    def test_staff_retains_preview_access(self):
        client = Client(enforce_csrf_checks=True)
        self.assertEqual(
            self._session_login(client, 'staff_reviewer', 'StaffPassword123!').status_code,
            200,
        )
        unit_slugs = {u['slug'] for u in client.get('/api/learning/units/').json()['results']}
        self.assertIn(self.pilot_unit.slug, unit_slugs)
        self.assertIn(self.sixth_validated_unit.slug, unit_slugs)
        self.assertIn(self.draft_unit.slug, unit_slugs)

    def test_login_throttle_uses_shared_feedback_cache_and_blocks_excess_attempts(self):
        from django.core.cache import caches
        from core.auth_views import LearnerLoginThrottle

        throttle = LearnerLoginThrottle()
        self.assertIs(throttle.cache, caches['feedback'])

        caches['feedback'].clear()
        try:
            client = Client(enforce_csrf_checks=True)
            for _ in range(15):
                resp = self._session_login(client, 'pilot_tester', 'WrongPass123!')
                self.assertEqual(resp.status_code, 401)
            blocked = self._session_login(client, 'pilot_tester', 'WrongPass123!')
            self.assertEqual(blocked.status_code, 429)
        finally:
            caches['feedback'].clear()

    def test_private_pilot_pack_storage_and_authenticated_download(self):
        import tempfile
        from pathlib import Path
        from django.test import override_settings
        from offline_packs.services.offline_pack_generator import OfflinePackGenerator

        with tempfile.TemporaryDirectory() as tmpdir:
            private_root = Path(tmpdir) / 'private_media'
            public_root = Path(tmpdir) / 'public_media'
            private_root.mkdir()
            public_root.mkdir()

            with override_settings(
                PRIVATE_MEDIA_ROOT=private_root,
                MEDIA_ROOT=public_root,
                USE_R2=False,
            ):
                OfflinePackGenerator(self.pilot_pack).generate()
                self.pilot_pack.refresh_from_db()

                # Stored strictly in private_file, never in public default_storage/MEDIA_ROOT
                self.assertFalse(bool(self.pilot_pack.file))
                self.assertTrue(bool(self.pilot_pack.private_file))
                self.assertEqual(self.pilot_pack.private_file.storage.url(self.pilot_pack.private_file.name), '')
                self.assertEqual(list(public_root.rglob('*.zip')), [])
                self.assertTrue(len(list(private_root.rglob('*.zip'))) == 1)

                # Generate archive for out-of-pilot validated pack and draft pack
                OfflinePackGenerator(self.out_pack).generate()
                draft_pack = LessonPack.objects.create(
                    slug='draft-pack-secret',
                    title_fr='Pack Brouillon',
                    status=LessonPack.DRAFT,
                    is_active=True,
                )
                draft_pack.units.add(self.draft_unit)
                OfflinePackGenerator(draft_pack).generate()

                # Anonymous & ordinary user denied download (404)
                anon_client = Client()
                self.assertEqual(
                    anon_client.get(f'/api/offline-packs/{self.pilot_pack.pk}/download/').status_code,
                    404,
                )

                ordinary_client = Client(enforce_csrf_checks=True)
                ord_login = self._session_login(ordinary_client, 'ordinary_learner', 'OrdinaryPassword123!')
                self.assertEqual(ord_login.status_code, 200, ord_login.content)
                self.assertEqual(
                    ordinary_client.get(f'/api/offline-packs/{self.pilot_pack.pk}/download/').status_code,
                    404,
                )

                # Pilot user sees authenticated download URL (never raw storage URL)
                pilot_client = Client(enforce_csrf_checks=True)
                login_resp = self._session_login(pilot_client, 'pilot_learner', 'PilotPassword123!')
                self.assertEqual(login_resp.status_code, 200, login_resp.content)
                pack_resp = pilot_client.get(f'/api/offline-packs/{self.pilot_pack.pk}/')
                self.assertEqual(pack_resp.status_code, 200, pack_resp.content)
                pack_detail = pack_resp.json()
                self.assertTrue(pack_detail['is_downloadable'])
                self.assertTrue(
                    pack_detail['file_url'].endswith(f'/api/offline-packs/{self.pilot_pack.pk}/download/')
                )

                dl_resp = pilot_client.get(f'/api/offline-packs/{self.pilot_pack.pk}/download/')
                self.assertEqual(dl_resp.status_code, 200)
                self.assertEqual(dl_resp['Cache-Control'], 'private, no-store')
                self.assertIn('Cookie', dl_resp['Vary'])
                self.assertEqual(dl_resp['X-Content-Type-Options'], 'nosniff')
                payload = b''.join(dl_resp.streaming_content)
                self.assertTrue(payload.startswith(b'PK'))

                # Non-pilot validated pack & draft pack remain 404
                self.assertEqual(
                    pilot_client.get(f'/api/offline-packs/{self.out_pack.pk}/download/').status_code,
                    404,
                )
                self.assertEqual(
                    pilot_client.get(f'/api/offline-packs/{draft_pack.pk}/download/').status_code,
                    404,
                )

                # Revocation immediately blocks download
                self.pilot_user.groups.remove(self.pilot_group)
                self.assertEqual(
                    pilot_client.get(f'/api/offline-packs/{self.pilot_pack.pk}/download/').status_code,
                    404,
                )

    def test_pack_status_transitions_and_pilot_content_scope(self):
        import io
        import json
        import tempfile
        import zipfile
        from django.test import override_settings
        from core.permissions import PILOT_ALLOWED_UNIT_SLUGS
        from offline_packs.services.offline_pack_generator import OfflinePackGenerator

        with tempfile.TemporaryDirectory() as media_root, tempfile.TemporaryDirectory() as private_root:
            with override_settings(
                MEDIA_ROOT=media_root,
                PRIVATE_MEDIA_ROOT=private_root,
                STORAGES={
                    'default': {'BACKEND': 'django.core.files.storage.FileSystemStorage'},
                    'private': {
                        'BACKEND': 'django.core.files.storage.FileSystemStorage',
                        'OPTIONS': {'location': private_root},
                    },
                    'staticfiles': {'BACKEND': 'django.contrib.staticfiles.storage.StaticFilesStorage'},
                },
                USE_R2=False,
            ):
                # 1) Pilot pack ZIP content strictly contains only authorized pilot units
                OfflinePackGenerator(self.pilot_pack).generate()
                with self.pilot_pack.private_file.open('rb') as zf_stream:
                    with zipfile.ZipFile(io.BytesIO(zf_stream.read()), 'r') as zf:
                        units_json = json.loads(zf.read('units.json').decode('utf-8'))
                        unit_slugs = {u['slug'] for u in units_json}
                        self.assertTrue(unit_slugs)
                        self.assertTrue(unit_slugs.issubset(set(PILOT_ALLOWED_UNIT_SLUGS)))

                # 2) Draft -> Validated -> Published -> Draft + Regeneration
                trans_pack = LessonPack.objects.create(
                    slug='transition-erf-pack',
                    title_fr='Transition Pack',
                    level='beginner',
                    version=1,
                    status=LessonPack.DRAFT,
                    is_active=True,
                )
                trans_pack.units.add(self.pilot_unit)
                OfflinePackGenerator(trans_pack).generate()
                self.assertTrue(bool(trans_pack.private_file))
                self.assertFalse(bool(trans_pack.file))

                # Draft -> Validated
                trans_pack.status = LessonPack.VALIDATED
                trans_pack.save()
                self.assertTrue(bool(trans_pack.private_file))
                self.assertFalse(bool(trans_pack.file))

                pilot_client = Client(enforce_csrf_checks=True)
                self._session_login(pilot_client, 'pilot_learner', 'PilotPassword123!')
                dl_resp = pilot_client.get(f'/api/offline-packs/{trans_pack.pk}/download/')
                self.assertEqual(dl_resp.status_code, 200)
                dl_resp.close()

                # Validated -> Published (migrates archive to public file, clears private_file on commit)
                priv_name = trans_pack.private_file.name
                priv_storage = trans_pack.private_file.storage
                with self.captureOnCommitCallbacks(execute=True):
                    trans_pack.status = LessonPack.PUBLISHED
                    trans_pack.save()
                self.assertTrue(bool(trans_pack.file))
                self.assertFalse(bool(trans_pack.private_file))
                self.assertFalse(priv_storage.exists(priv_name))

                pub_detail = Client().get(f'/api/offline-packs/{trans_pack.pk}/').json()
                self.assertTrue(pub_detail['is_downloadable'])
                self.assertNotIn('/download/', pub_detail['file_url'])

                # Simulated DB rollback during Published -> Draft must preserve existing public file
                pub_name = trans_pack.file.name
                pub_storage = trans_pack.file.storage
                from django.db import transaction
                with self.captureOnCommitCallbacks(execute=True):
                    with self.assertRaises(RuntimeError):
                        with transaction.atomic():
                            trans_pack.status = LessonPack.DRAFT
                            trans_pack.save()
                            raise RuntimeError('Simulated DB failure')
                self.assertTrue(pub_storage.exists(pub_name))
                trans_pack.refresh_from_db()
                self.assertEqual(trans_pack.status, LessonPack.PUBLISHED)

                # Published -> Draft (moves archive back to private_file, deletes public file on commit)
                with self.captureOnCommitCallbacks(execute=True):
                    trans_pack.status = LessonPack.DRAFT
                    trans_pack.save()
                self.assertFalse(bool(trans_pack.file))
                self.assertTrue(bool(trans_pack.private_file))
                self.assertFalse(pub_storage.exists(pub_name))
                self.assertEqual(
                    pilot_client.get(f'/api/offline-packs/{trans_pack.pk}/download/').status_code,
                    404,
                )

                # Regeneration in Validated
                trans_pack.status = LessonPack.VALIDATED
                trans_pack.save()
                OfflinePackGenerator(trans_pack).generate()
                self.assertTrue(bool(trans_pack.private_file))
                self.assertFalse(bool(trans_pack.file))

                # Idempotent orphan inventory / reconciliation command (dry-run then --apply)
                from django.core.files.base import ContentFile
                from django.core.files.storage import default_storage
                from django.core.management import call_command
                from core.media_storage import private_backend

                orphan_pub = default_storage.save('offline_packs/files/orphan_pub.zip', ContentFile(b'PKorphan'))
                orphan_priv = private_backend().save('offline_packs/files/orphan_priv.zip', ContentFile(b'PKorphan'))
                call_command('reconcile_pack_storage', '--dry-run')
                self.assertTrue(default_storage.exists(orphan_pub))
                self.assertTrue(private_backend().exists(orphan_priv))

                # Default min-age-seconds=300 protects recently created objects
                call_command('reconcile_pack_storage', '--apply')
                self.assertTrue(default_storage.exists(orphan_pub))
                self.assertTrue(private_backend().exists(orphan_priv))

                call_command('reconcile_pack_storage', '--apply', '--min-age-seconds=0')
                self.assertFalse(default_storage.exists(orphan_pub))
                self.assertFalse(private_backend().exists(orphan_priv))
                self.assertTrue(private_backend().exists(trans_pack.private_file.name))

                # Repeated --apply is idempotent
                call_command('reconcile_pack_storage', '--apply', '--min-age-seconds=0')
                self.assertTrue(private_backend().exists(trans_pack.private_file.name))
