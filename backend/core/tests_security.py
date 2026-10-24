from types import SimpleNamespace

from django.core.exceptions import ImproperlyConfigured
from django.test import SimpleTestCase, override_settings
from rest_framework.test import APIRequestFactory, force_authenticate

from config.security import build_security_settings, build_feedback_rates, resolve_environment
from core.views import HttpsProxyDiagnosticAPIView


TEST_SECRET = 'test-fixture-only-not-used-in-production-0123456789-abcdefghijk'


class ProductionSecurityTests(SimpleTestCase):
    def build(self, **values):
        environment = {'DJANGO_ENV': 'production', 'SECRET_KEY': TEST_SECRET, **values}
        return build_security_settings(environment.get)

    def test_production_requires_secret_and_disables_debug(self):
        for values in ({'SECRET_KEY': ''}, {'SECRET_KEY': 'short'}, {'SECRET_KEY': 'django-insecure-public'}, {'DEBUG': 'True'}):
            with self.subTest(values=list(values)), self.assertRaises(ImproperlyConfigured):
                self.build(**values)

    def test_existing_secret_is_never_trimmed_or_rotated(self):
        secret = ' ' + TEST_SECRET + ' '
        self.assertEqual(self.build(SECRET_KEY=secret)['SECRET_KEY'], secret)

    def test_production_https_cookies_and_gradual_hsts(self):
        values = self.build()
        self.assertFalse(values['DEBUG'])
        self.assertTrue(values['SECURE_SSL_REDIRECT'])
        self.assertTrue(values['SESSION_COOKIE_SECURE'])
        self.assertTrue(values['CSRF_COOKIE_SECURE'])
        self.assertEqual(values['SECURE_HSTS_SECONDS'], 300)
        self.assertFalse(values['SECURE_HSTS_INCLUDE_SUBDOMAINS'])
        self.assertFalse(values['SECURE_HSTS_PRELOAD'])
        self.assertIsNone(values['SECURE_PROXY_SSL_HEADER'])
        self.assertEqual(values['NUM_PROXIES'], 0)

    def test_proxy_trust_is_explicit_and_render_is_detected(self):
        self.assertEqual(resolve_environment({'RENDER': 'true'}.get), 'production')
        self.assertEqual(resolve_environment({'DEBUG': 'False'}.get), 'production')
        self.assertEqual(resolve_environment({'RENDER': 'false'}.get), 'development')
        with self.assertRaises(ImproperlyConfigured):
            self.build(RENDER='true')
        with self.assertRaises(ImproperlyConfigured):
            self.build(TRUST_X_FORWARDED_PROTO='True')
        values = self.build(RENDER='true', TRUST_X_FORWARDED_PROTO='True', NUM_PROXIES='1')
        self.assertEqual(values['SECURE_PROXY_SSL_HEADER'], ('HTTP_X_FORWARDED_PROTO', 'https'))
        self.assertEqual(values['NUM_PROXIES'], 1)

    def test_invalid_hosts_origins_and_hsts_are_rejected(self):
        for values in (
            {'ALLOWED_HOSTS': '*'}, {'ALLOWED_HOSTS': ''}, {'ALLOWED_HOSTS': 'localhost'},
            {'CSRF_TRUSTED_ORIGINS': 'http://example.org'},
            {'CSRF_TRUSTED_ORIGINS': 'https://name:password@example.org'},
            {'CSRF_TRUSTED_ORIGINS': 'https://[invalid'},
            {'CSRF_TRUSTED_ORIGINS': 'https://example.org:invalid'},
            {'SECURE_HSTS_PRELOAD': 'True'}, {'SECURE_SSL_REDIRECT': 'False'},
        ):
            with self.subTest(fields=list(values)), self.assertRaises(ImproperlyConfigured):
                self.build(**values)

    def test_feedback_rates_fail_at_startup_instead_of_on_a_request(self):
        self.assertEqual(build_feedback_rates({}.get)['feedback_burst'], '5/min')
        for value in ['0/min', '', 'none', '5/invalid', '-1/hour']:
            with self.subTest(value=value), self.assertRaises(ImproperlyConfigured):
                build_feedback_rates({'FEEDBACK_RATE_BURST': value}.get)

    def test_diagnostic_is_staff_only_and_reports_effective_proxy_configuration(self):
        factory = APIRequestFactory()
        request = factory.get('/api/core/diagnostics/https/', HTTP_X_FORWARDED_PROTO='https')
        self.assertEqual(HttpsProxyDiagnosticAPIView.as_view()(request).status_code, 403)
        force_authenticate(request, user=SimpleNamespace(is_authenticated=True, is_staff=True))
        with override_settings(SECURE_PROXY_SSL_HEADER=None):
            self.assertFalse(HttpsProxyDiagnosticAPIView.as_view()(request).data['is_secure'])
        with override_settings(SECURE_PROXY_SSL_HEADER=('HTTP_X_FORWARDED_PROTO', 'https')):
            self.assertTrue(HttpsProxyDiagnosticAPIView.as_view()(request).data['is_secure'])

    @override_settings(SECURE_SSL_REDIRECT=True, SECURE_PROXY_SSL_HEADER=None,
                       SECURE_HSTS_SECONDS=300, SECURE_HSTS_INCLUDE_SUBDOMAINS=False,
                       SECURE_HSTS_PRELOAD=False)
    def test_http_redirect_and_https_headers_with_untrusted_spoofed_proxy_header(self):
        response = self.client.get('/api/core/diagnostics/https/', HTTP_X_FORWARDED_PROTO='https')
        self.assertEqual(response.status_code, 301)
        response = self.client.get('/api/core/diagnostics/https/', secure=True)
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response['Strict-Transport-Security'], 'max-age=300')
        self.assertEqual(response['X-Content-Type-Options'], 'nosniff')
