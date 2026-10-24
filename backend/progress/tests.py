from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from learning.models import LearningTheme, LearningUnit
from .models import UnitProgress

User = get_user_model()


class UnitProgressSecurityAndSyncTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.theme = LearningTheme.objects.create(slug='test-theme', title_fr='Theme Test')
        self.unit = LearningUnit.objects.create(theme=self.theme, slug='test-unit', title_fr='Unit Test')

        self.device_id_a = 'device-aaa'
        self.token_a = 'token-secret-aaa'
        self.device_id_b = 'device-bbb'
        self.token_b = 'token-secret-bbb'

        self.progress_a = UnitProgress.objects.create(
            device_id=self.device_id_a,
            device_token=self.token_a,
            unit=self.unit,
            lessons_seen=5,
            best_score_percent=80,
            client_updated_at=timezone.datetime(2026, 10, 20, 12, 0, 0, tzinfo=timezone.datetime.now(timezone.UTC).tzinfo),
        )

        self.staff_user = User.objects.create_superuser(
            username='admin_test',
            email='admin@test.com',
            password='password123',
        )
        self.normal_user = User.objects.create_user(
            username='user_test',
            email='user@test.com',
            password='password123',
        )

    def test_anonymous_global_listing_is_forbidden(self):
        """A01: Une requête anonyme sans device_id ne doit pas révéler la liste des progressions."""
        response = self.client.get('/api/progress/unit-progress/')
        self.assertEqual(response.status_code, 403)

    def test_scoring_metadata_preserves_legacy_success_and_records_new_session(self):
        self.progress_a.best_score_percent = 100
        self.progress_a.completed = True
        self.progress_a.save()
        response = self.client.post('/api/progress/unit-progress/sync/', {'items': [{
            'unit_slug': self.unit.slug, 'device_id': self.device_id_a,
            'device_token': self.token_a, 'score_percent': 100,
            'scoring_version': 2, 'last_session_score': 46, 'completed': True,
        }]}, format='json')
        self.assertEqual(response.data['error_count'], 0)
        self.progress_a.refresh_from_db()
        self.assertTrue(self.progress_a.completed)
        self.assertEqual(self.progress_a.best_score_percent, 100)
        self.assertEqual(self.progress_a.scoring_version, 1)
        self.assertEqual(self.progress_a.last_session_score, 46)

    def test_new_best_retains_its_scoring_version(self):
        response = self.client.post('/api/progress/unit-progress/sync/', {'items': [{
            'unit_slug': self.unit.slug, 'device_id': self.device_id_a,
            'device_token': self.token_a, 'score_percent': 90,
            'scoring_version': 2, 'last_session_score': 90,
        }]}, format='json')
        self.assertEqual(response.data['error_count'], 0)
        self.progress_a.refresh_from_db()
        self.assertEqual(self.progress_a.best_score_percent, 90)
        self.assertEqual(self.progress_a.scoring_version, 2)

    def test_new_mastery_below_threshold_is_rejected_without_changing_history(self):
        response = self.client.post('/api/progress/unit-progress/sync/', {'items': [{
            'unit_slug': self.unit.slug, 'device_id': self.device_id_a,
            'device_token': self.token_a, 'score_percent': 50, 'completed': True,
        }]}, format='json')
        self.assertEqual(response.data['error_count'], 1)
        self.progress_a.refresh_from_db()
        self.assertFalse(self.progress_a.completed)
        self.assertEqual(self.progress_a.best_score_percent, 80)

    def test_anonymous_listing_without_valid_token_is_forbidden(self):
        """A01: Fournir un device_id sans le token correspondant est interdit."""
        # Sans token
        response = self.client.get(f'/api/progress/unit-progress/?device_id={self.device_id_a}')
        self.assertEqual(response.status_code, 403)

        # Avec mauvais token
        response = self.client.get(
            f'/api/progress/unit-progress/?device_id={self.device_id_a}',
            HTTP_X_DEVICE_TOKEN='mauvais-token',
        )
        self.assertEqual(response.status_code, 403)

    def test_anonymous_listing_with_valid_token_succeeds(self):
        """A01: Fournir le bon token autorise la lecture de ses propres données."""
        response = self.client.get(
            f'/api/progress/unit-progress/?device_id={self.device_id_a}',
            HTTP_X_DEVICE_TOKEN=self.token_a,
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['count'], 1)
        self.assertEqual(response.data['results'][0]['device_id'], self.device_id_a)

    def test_staff_can_view_all_progress(self):
        """A01: Les administrateurs peuvent consulter la liste globale."""
        self.client.force_authenticate(user=self.staff_user)
        response = self.client.get('/api/progress/unit-progress/')
        self.assertEqual(response.status_code, 200)
        self.assertGreaterEqual(response.data['count'], 1)

    def test_sync_cannot_overwrite_another_device_with_wrong_token(self):
        """A01: Un terminal B ne peut pas modifier la progression d'un terminal A protégé."""
        payload = {
            'items': [{
                'unit_slug': self.unit.slug,
                'device_id': self.device_id_a,
                'device_token': 'wrong-token',
                'lessons_seen': 10,
                'score_percent': 90,
            }]
        }
        response = self.client.post('/api/progress/unit-progress/sync/', payload, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['synced_count'], 0)
        self.assertEqual(response.data['error_count'], 1)

        # Vérification en base : les compteurs du device A n'ont pas changé
        self.progress_a.refresh_from_db()
        self.assertEqual(self.progress_a.lessons_seen, 5)

    def test_sync_malformed_items_never_cause_500(self):
        """A03: Un lot contenant un élément nul ou mal formé renvoie des erreurs structurées sans 500."""
        payload = {
            'items': [
                None,
                'chaine-invalide',
                {'score_percent': 999},  # Sans slug ni unit_id, score hors limites
            ]
        }
        response = self.client.post('/api/progress/unit-progress/sync/', payload, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['synced_count'], 0)
        self.assertEqual(response.data['error_count'], 3)

    def test_sync_anti_regression_does_not_decrease_counters(self):
        """A03: Une mise à jour ancienne ne fait pas reculer les compteurs."""
        stale_date = '2020-01-01T00:00:00Z'
        payload = {
            'items': [{
                'unit_slug': self.unit.slug,
                'device_id': self.device_id_a,
                'device_token': self.token_a,
                'lessons_seen': 1,  # Inférieur aux 5 actuels
                'score_percent': 95,
                'client_updated_at': stale_date,
            }]
        }
        response = self.client.post('/api/progress/unit-progress/sync/', payload, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['synced_count'], 1)

        self.progress_a.refresh_from_db()
        # lessons_seen ne doit PAS avoir diminué
        self.assertEqual(self.progress_a.lessons_seen, 5)
        # Mais le meilleur score (95 > 80) a bien été pris en compte
        self.assertEqual(self.progress_a.best_score_percent, 95)
