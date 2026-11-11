from django.contrib.auth import get_user_model
from django.core.exceptions import PermissionDenied
from django.test import TestCase,override_settings
from . import licensing,services

class EducationalStagingGateTests(TestCase):
    def setUp(self):
        self.staff=get_user_model().objects.create_superuser('synthetic-staging-staff',password='synthetic-only')

    @override_settings(DJANGO_ENV='staging')
    def test_staging_cannot_mutate_simulated_ledger(self):
        with self.assertRaises(PermissionDenied): services.require(self.staff,'verify_payment')

    @override_settings(DJANGO_ENV='staging')
    def test_staging_cannot_issue_device_challenges(self):
        with self.assertRaises(PermissionDenied): licensing.challenge(self.staff,'lease')

    @override_settings(DJANGO_ENV='test')
    def test_isolated_test_keeps_simulation_available(self):
        services.require(self.staff,'verify_payment')
        self.assertEqual(licensing.challenge(self.staff,'lease').purpose,'lease')
