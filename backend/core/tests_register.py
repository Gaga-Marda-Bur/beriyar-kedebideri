"""Tests de l'inscription publique sécurisée (/api/core/auth/register/)."""
import json

from django.contrib.auth import get_user_model
from django.core.cache import caches
from django.test import Client, TestCase


User = get_user_model()


class LearnerRegistrationTests(TestCase):
    def setUp(self):
        caches['feedback'].clear()
        self.client = Client(enforce_csrf_checks=True)
        csrf_resp = self.client.get('/api/core/auth/csrf/')
        self.csrf_token = csrf_resp.json()['csrf_token']

    def _post_register(self, payload, headers=None):
        extra = {'HTTP_X_CSRFTOKEN': self.csrf_token}
        if headers is not None:
            extra = headers
        return self.client.post(
            '/api/core/auth/register/',
            data=json.dumps(payload),
            content_type='application/json',
            **extra,
        )

    def test_register_creates_non_staff_user_with_hashed_password_and_session(self):
        resp = self._post_register({
            'username': 'nouvel_apprenant',
            'email': 'apprenant@example.com',
            'password': 'StrongPassword!2026',
            'password_confirm': 'StrongPassword!2026',
        })
        self.assertEqual(resp.status_code, 201)
        data = resp.json()
        self.assertTrue(data['authenticated'])
        self.assertEqual(data['username'], 'nouvel_apprenant')
        self.assertFalse(data['is_staff'])

        user = User.objects.get(username='nouvel_apprenant')
        self.assertFalse(user.is_staff)
        self.assertFalse(user.is_superuser)
        self.assertNotEqual(user.password, 'StrongPassword!2026')
        self.assertTrue(user.check_password('StrongPassword!2026'))

        me_resp = self.client.get('/api/core/auth/me/')
        self.assertEqual(me_resp.status_code, 200)
        self.assertEqual(me_resp.json()['username'], 'nouvel_apprenant')

    def test_register_rejects_duplicate_username_case_insensitive(self):
        User.objects.create_user(username='ExistingUser', password='StrongPassword!2026')
        resp = self._post_register({
            'username': 'existinguser',
            'password': 'StrongPassword!2026',
            'password_confirm': 'StrongPassword!2026',
        })
        self.assertEqual(resp.status_code, 409)

    def test_register_rejects_weak_or_mismatched_password_and_bad_username(self):
        self.assertEqual(
            self._post_register({
                'username': 'ab',
                'password': 'StrongPassword!2026',
                'password_confirm': 'StrongPassword!2026',
            }).status_code,
            400,
        )
        self.assertEqual(
            self._post_register({
                'username': 'valid_user_1',
                'password': 'StrongPassword!2026',
                'password_confirm': 'DifferentPassword!2026',
            }).status_code,
            400,
        )
        self.assertEqual(
            self._post_register({
                'username': 'valid_user_2',
                'password': '123',
                'password_confirm': '123',
            }).status_code,
            400,
        )

    def test_register_requires_csrf_and_throttles_burst(self):
        no_csrf = self._post_register(
            {'username': 'no_csrf_user', 'password': 'StrongPassword!2026', 'password_confirm': 'StrongPassword!2026'},
            headers={},
        )
        self.assertEqual(no_csrf.status_code, 403)

        for i in range(5):
            r = self._post_register({
                'username': f'rate_user_{i}',
                'password': 'StrongPassword!2026',
                'password_confirm': 'StrongPassword!2026',
            })
            if 'csrf_token' in r.json():
                self.csrf_token = r.json()['csrf_token']
        throttled = self._post_register({
            'username': 'rate_user_6',
            'password': 'StrongPassword!2026',
            'password_confirm': 'StrongPassword!2026',
        })
        self.assertEqual(throttled.status_code, 429)
