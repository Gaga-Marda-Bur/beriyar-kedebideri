from io import StringIO

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase
from rest_framework.test import APIClient

from learning.models import LearningTheme, LearningUnit
from offline_packs.models import LessonPack
from offline_packs.services.offline_pack_generator import OfflinePackGenerator


User = get_user_model()


class PreprodNonExposureSecurityTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        call_command('import_preprod_courses', stdout=StringIO())
        cls.public_user = User.objects.create_user(
            username='public_learner',
            password='Password123!',
            is_staff=False,
        )
        cls.staff_user = User.objects.create_user(
            username='linguist_reviewer',
            password='Password123!',
            is_staff=True,
        )

    def _extract_results(self, response):
        data = response.json()
        if isinstance(data, dict) and 'results' in data:
            return data['results']
        return data

    def test_anonymous_and_ordinary_users_cannot_see_preprod_drafts(self):
        endpoints = [
            '/api/learning/themes/',
            '/api/learning/units/',
            '/api/lessons/',
            '/api/lessons/items/',
            '/api/alphabet/characters/',
            '/api/vocabulary/words/',
            '/api/quizzes/',
            '/api/offline-packs/',
        ]

        for user in (None, self.public_user):
            client = APIClient()
            if user is not None:
                client.force_authenticate(user=user)

            for url in endpoints:
                resp = client.get(url)
                self.assertEqual(resp.status_code, 200, msg=f'{url} failed')
                results = self._extract_results(resp)
                self.assertEqual(
                    len(results),
                    0,
                    msg=f'Fuite détectée sur {url} pour user={user}: {len(results)} éléments',
                )

    def test_public_user_cannot_access_draft_detail_or_core_flow(self):
        unit = LearningUnit.objects.get(slug='bk-preprod-erf-01')
        client = APIClient()
        client.force_authenticate(user=self.public_user)

        self.assertEqual(client.get(f'/api/learning/units/{unit.id}/').status_code, 404)
        self.assertEqual(client.get(f'/api/learning/units/{unit.id}/core-flow/').status_code, 404)

    def test_staff_preview_can_inspect_drafts_for_validation(self):
        client = APIClient()
        client.force_authenticate(user=self.staff_user)

        themes = self._extract_results(client.get('/api/learning/themes/?status=draft'))
        units = self._extract_results(client.get('/api/learning/units/?status=draft'))
        lessons = self._extract_results(client.get('/api/lessons/?status=draft'))
        chars = self._extract_results(client.get('/api/alphabet/characters/?status=draft'))

        self.assertEqual(len(themes), 3)
        self.assertEqual(len(units), 14)
        self.assertEqual(len(lessons), 14)
        self.assertEqual(len(chars), 25)

    def test_published_offline_pack_never_includes_draft_themes_or_units(self):
        pack = LessonPack.objects.create(
            title_fr='Pack Test Sécurité',
            slug='pack-test-securite',
            status=LessonPack.PUBLISHED,
            is_active=True,
        )
        pack.themes.add(LearningTheme.objects.get(slug='bk-preprod-alphabet-erfe'))
        pack.units.add(LearningUnit.objects.get(slug='bk-preprod-erf-01'))

        generator = OfflinePackGenerator(pack)
        themes = generator._serialize_themes()
        self.assertEqual(len(themes), 0)
