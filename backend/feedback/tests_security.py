import io
from datetime import timedelta
from unittest.mock import patch

from django.conf import settings
from django.core.cache import caches
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from django.utils import timezone
from PIL import Image
from rest_framework.test import APIClient

from alphabet.models import Character
from .models import FeedbackReport


@override_settings(REST_FRAMEWORK={**settings.REST_FRAMEWORK, 'NUM_PROXIES': 0,
    'DEFAULT_THROTTLE_RATES': {'feedback_burst': '100/min', 'feedback_sustained': '100/hour', 'feedback_device': '100/hour'}})
class FeedbackValidationTests(TestCase):
    def setUp(self):
        caches['feedback'].clear()
        self.api = APIClient()

    def post(self, **values):
        return self.api.post('/api/feedback/create/', {'message': '𖺡𖺣 العربية', 'feedback_type': 'technical', **values}, format='json')

    def test_valid_feedback_preserves_unicode_and_server_owned_fields(self):
        self.assertEqual(self.post().status_code, 201)
        report = FeedbackReport.objects.get()
        self.assertEqual(report.message, '𖺡𖺣 العربية')
        self.assertEqual(report.status, FeedbackReport.NEW)
        self.assertEqual(report.admin_note, '')

    def test_invalid_fields_and_privileged_writes_are_rejected(self):
        for payload in ({'feedback_type': 'invented'}, {'message': 'x' * 5001},
                        {'message': 123}, {'title': ['invalid']},
                        {'message': ' ', 'title': ''}, {'title': 'x' * 256},
                        {'message': 'bad\x00text'}, {'platform': 'invented'},
                        {'device_id': 'bad id'}, {'language_code': 'fr/../../'},
                        {'admin_note': 'forged'}, {'status': 'fixed'}, {'user': 1},
                        {'audio_feedback': '00000000-0000-0000-0000-000000000001'}):
            with self.subTest(fields=list(payload)):
                self.assertEqual(self.post(**payload).status_code, 400)
        self.assertEqual(FeedbackReport.objects.count(), 0)

    def test_malformed_payloads_return_400(self):
        for payload in (None, [], 'text', {'message': []}):
            self.assertEqual(self.api.post('/api/feedback/create/', payload, format='json').status_code, 400)

    def test_orphan_unicode_surrogates_are_rejected_without_500(self):
        escaped = bytes([92]) + b'ud800'
        for body in (b'{"message":"' + escaped + b'"}',
                     b'{"message":"Valid","device_id":"' + escaped + b'"}',
                     b'{"message":"Valid","' + escaped + b'":"extra"}'):
            self.assertEqual(self.api.generic('POST', '/api/feedback/create/', body,
                content_type='application/json').status_code, 400)

    def test_target_allowlist_and_existence(self):
        character = Character.objects.create(symbol='𖺡', unicode_code='U+16EA1')
        self.assertEqual(self.post(target_app_label='alphabet', target_model='character', object_id=character.pk).status_code, 201)
        for payload in ({'target_app_label': 'auth', 'target_model': 'user', 'object_id': 1},
                        {'object_id': character.pk}, {'target_app_label': 'alphabet', 'target_model': 'character'},
                        {'target_app_label': 'alphabet', 'target_model': 'character', 'object_id': 999999}):
            self.assertEqual(self.post(**payload).status_code, 400)

    def test_future_client_date_is_rejected(self):
        self.assertEqual(self.post(client_created_at=(timezone.now() + timedelta(days=3)).isoformat()).status_code, 400)

    def test_screenshot_content_dimensions_and_size_are_validated(self):
        content = io.BytesIO()
        Image.new('RGB', (2, 2)).save(content, 'PNG')
        response = self.api.post('/api/feedback/create/', {'message': 'Image',
            'screenshot': SimpleUploadedFile('screen.png', content.getvalue(), 'image/png')}, format='multipart')
        self.assertEqual(response.status_code, 201)
        self.assertTrue(FeedbackReport.objects.get().screenshot.name.endswith('.png'))
        response = self.api.post('/api/feedback/create/', {'message': 'Image',
            'screenshot': SimpleUploadedFile('screen.html', content.getvalue(), 'image/png')}, format='multipart')
        self.assertEqual(response.status_code, 400)
        for data in (b'not-an-image', b'x' * (2 * 1024 * 1024 + 1)):
            response = self.api.post('/api/feedback/create/', {'message': 'Image',
                'screenshot': SimpleUploadedFile('screen.png', data, 'image/png')}, format='multipart')
            self.assertEqual(response.status_code, 400)
        wide = io.BytesIO()
        Image.new('RGB', (4097, 1)).save(wide, 'PNG')
        response = self.api.post('/api/feedback/create/', {'message': 'Image',
            'screenshot': SimpleUploadedFile('wide.png', wide.getvalue(), 'image/png')}, format='multipart')
        self.assertEqual(response.status_code, 400)

    def test_request_body_limit_and_web_csrf_remain_enforced(self):
        response = self.api.generic('POST', '/api/feedback/create/', b'x' * (3 * 1024 * 1024 + 1),
                                    content_type='application/octet-stream')
        self.assertEqual(response.status_code, 413)
        from django.test import Client
        response = Client(enforce_csrf_checks=True).post('/feedback/', {'message': 'Valid'})
        self.assertEqual(response.status_code, 403)

    def test_web_validation_preserves_submission_and_valid_web_form_still_works(self):
        response = self.client.post('/feedback/?lang=fr', {'message': 'Message à conserver', 'feedback_type': 'invalid'})
        self.assertEqual(response.status_code, 400)
        self.assertContains(response, 'Message à conserver', status_code=400)
        self.assertEqual(FeedbackReport.objects.count(), 0)
        response = self.client.post('/feedback/', {'message': 'Message valide', 'feedback_type': 'technical'})
        self.assertEqual(response.status_code, 302)
        self.assertEqual(FeedbackReport.objects.get().platform, 'web')

    @override_settings(REST_FRAMEWORK={**settings.REST_FRAMEWORK, 'NUM_PROXIES': 0,
        'DEFAULT_THROTTLE_RATES': {'feedback_burst': '1/min', 'feedback_sustained': '100/hour', 'feedback_device': '100/hour'}})
    def test_api_and_web_share_client_quota_and_keep_web_input(self):
        self.assertEqual(self.post().status_code, 201)
        response = self.client.post('/feedback/?lang=fr', {'message': 'Pas perdu', 'feedback_type': 'technical'})
        self.assertEqual(response.status_code, 429)
        self.assertIn('Retry-After', response)
        self.assertContains(response, 'Pas perdu', status_code=429)
        self.assertEqual(FeedbackReport.objects.count(), 1)
        response = self.api.post('/api/feedback/create/', {'message': 'Again'}, format='json',
                                 HTTP_X_FORWARDED_FOR='203.0.113.25', HTTP_ACCEPT_LANGUAGE='fr')
        self.assertEqual(response.status_code, 429)
        self.assertIn('Retry-After', response)
        self.assertIn('Trop', str(response.data['detail']))

    @override_settings(REST_FRAMEWORK={**settings.REST_FRAMEWORK,
        'DEFAULT_THROTTLE_RATES': {'feedback_burst': '100/min', 'feedback_sustained': '100/hour', 'feedback_device': '1/hour'}})
    def test_device_quota_is_an_additional_limit(self):
        self.assertEqual(self.post(device_id='device-a').status_code, 201)
        self.assertEqual(self.api.post('/api/feedback/create/', {'message': 'Again', 'device_id': 'device-a'},
            format='json', REMOTE_ADDR='203.0.113.2').status_code, 429)
        self.assertEqual(self.post(device_id='device-b').status_code, 201)

    @override_settings(REST_FRAMEWORK={**settings.REST_FRAMEWORK, 'NUM_PROXIES': 0,
        'DEFAULT_THROTTLE_RATES': {'feedback_burst': '1/min', 'feedback_sustained': '100/hour', 'feedback_device': '100/hour'}})
    def test_client_can_submit_again_after_the_retry_window(self):
        clock = [1000.0]
        with patch('feedback.throttles._FeedbackThrottle.timer', staticmethod(lambda: clock[0])):
            self.assertEqual(self.post().status_code, 201)
            self.assertEqual(self.post().status_code, 429)
            clock[0] += 61
            self.assertEqual(self.post().status_code, 201)

    @override_settings(REST_FRAMEWORK={**settings.REST_FRAMEWORK,
        'DEFAULT_THROTTLE_RATES': {'feedback_burst': '100/min', 'feedback_sustained': '1/hour', 'feedback_device': '100/hour'}})
    def test_sustained_quota_blocks_after_burst_quota_would_allow(self):
        self.assertEqual(self.post().status_code, 201)
        self.assertEqual(self.post().status_code, 429)

    @override_settings(REST_FRAMEWORK={**settings.REST_FRAMEWORK,
        'DEFAULT_THROTTLE_RATES': {'feedback_burst': '1/min', 'feedback_sustained': '1/hour', 'feedback_device': '1/hour'}})
    def test_authenticated_staff_can_submit_legitimate_reports_without_throttling(self):
        from django.contrib.auth import get_user_model
        staff = get_user_model().objects.create_user(username='feedback-editor', is_staff=True)
        self.api.force_authenticate(user=staff)
        self.assertEqual(self.post(device_id='editor').status_code, 201)
        self.assertEqual(self.post(device_id='editor').status_code, 201)
