"""Tests d'isolation des buckets et identifiants Cloudflare R2 (sans appel réseau)."""
import os
import subprocess
import sys
from pathlib import Path

from django.test import SimpleTestCase

from core.media_storage import PrivatePackStorage


BASE_PROD_ENV = {
    'DJANGO_SETTINGS_MODULE': 'config.settings',
    'DJANGO_ENV': 'production',
    'DEBUG': 'False',
    'SECURE_SSL_REDIRECT': 'True',
    'SECRET_KEY': 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6A7B8C9D0E1F2',
    'ALLOWED_HOSTS': 'beriyarkedebideri.com',
    'DATABASE_URL': 'postgres://u:p@10.0.0.1:5432/db?sslmode=require',
    'USE_R2': 'True',
    'R2_BUCKET_NAME': 'beriyar-kedebideri-media',
    'R2_ACCESS_KEY_ID': 'dummy_pub_key_1',
    'R2_SECRET_ACCESS_KEY': 'dummy_pub_secret_1',
    'R2_PRIVATE_BUCKET_NAME': 'beriyar-private-media',
    'R2_PRIVATE_ACCESS_KEY_ID': 'dummy_priv_key_2',
    'R2_PRIVATE_SECRET_ACCESS_KEY': 'dummy_priv_secret_2',
    'R2_ENDPOINT_URL': 'https://00000000000000000000000000000000.r2.cloudflarestorage.com',
    'R2_PUBLIC_BASE_URL': 'https://media.beriyarkedebideri.com',
    'FEEDBACK_CACHE_BACKEND': 'django.core.cache.backends.db.DatabaseCache',
    'FEEDBACK_CACHE_LOCATION': 'beriya_feedback_cache',
    'TRUST_X_FORWARDED_PROTO': 'True',
    'NUM_PROXIES': '2',
}


def _run_settings_probe(overrides, code='import django; django.setup(); print("OK")'):
    env = os.environ.copy()
    env.update(BASE_PROD_ENV)
    for k, v in overrides.items():
        if v is None:
            env.pop(k, None)
        else:
            env[k] = v
    backend_dir = str(Path(__file__).resolve().parent.parent)
    return subprocess.run(
        [sys.executable, '-c', code],
        cwd=backend_dir,
        env=env,
        capture_output=True,
        text=True,
        timeout=20,
    )


class R2DualCredentialsIsolationTests(SimpleTestCase):
    def test_valid_dual_buckets_and_dual_credentials(self):
        probe = (
            'import django; django.setup(); '
            'from django.core.files.storage import storages; '
            'd, p = storages["default"], storages["private"]; '
            'assert d.bucket_name == "beriyar-kedebideri-media"; '
            'assert p.bucket_name == "beriyar-private-media"; '
            'assert d.access_key == "dummy_pub_key_1"; '
            'assert p.access_key == "dummy_priv_key_2"; '
            'assert d.secret_key == "dummy_pub_secret_1"; '
            'assert p.secret_key == "dummy_priv_secret_2"; '
            'assert p.custom_domain is None; '
            'assert p.querystring_auth is True; '
            'assert p.endpoint_url == d.endpoint_url; '
            'print("ISOLATED_OK")'
        )
        res = _run_settings_probe({}, code=probe)
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertIn('ISOLATED_OK', res.stdout)

    def test_rejects_missing_private_bucket_in_production(self):
        res = _run_settings_probe({'R2_PRIVATE_BUCKET_NAME': ''})
        self.assertNotEqual(res.returncode, 0)
        self.assertIn('Un bucket privé distinct est requis', res.stderr)

    def test_rejects_same_bucket_for_public_and_private(self):
        res = _run_settings_probe({'R2_PRIVATE_BUCKET_NAME': 'beriyar-kedebideri-media'})
        self.assertNotEqual(res.returncode, 0)
        self.assertIn('Un bucket privé distinct est requis', res.stderr)

    def test_rejects_missing_private_credentials_without_fallback(self):
        for key in ('R2_PRIVATE_ACCESS_KEY_ID', 'R2_PRIVATE_SECRET_ACCESS_KEY'):
            with self.subTest(missing=key):
                res = _run_settings_probe({key: ''})
                self.assertNotEqual(res.returncode, 0)
                self.assertIn('identifiants S3 privés distincts', res.stderr)

    def test_rejects_reused_public_credentials_for_private_storage(self):
        for overrides in (
            {'R2_PRIVATE_ACCESS_KEY_ID': 'dummy_pub_key_1'},
            {'R2_PRIVATE_SECRET_ACCESS_KEY': 'dummy_pub_secret_1'},
        ):
            with self.subTest(overrides=overrides):
                res = _run_settings_probe(overrides)
                self.assertNotEqual(res.returncode, 0)
                self.assertIn('doivent être distincts des identifiants publics', res.stderr)

    def test_private_pack_storage_never_exposes_url(self):
        self.assertEqual(PrivatePackStorage().url('offline_packs/files/secret.zip'), '')
