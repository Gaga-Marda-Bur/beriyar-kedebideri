"""Run backend tests with an in-memory database and disposable media storage."""
import os
import sys
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'backend'))
os.environ['DJANGO_SETTINGS_MODULE'] = 'config.settings'
os.environ['DJANGO_ENV'] = 'test'
os.environ['DEBUG'] = 'False'
os.environ['SECURE_SSL_REDIRECT'] = 'False'
os.environ['DATABASE_URL'] = 'sqlite:///:memory:'
os.environ['USE_R2'] = 'False'
os.environ['SECRET_KEY'] = 'isolated-tests-only-not-a-production-key'
os.environ['ALLOWED_HOSTS'] = 'testserver,localhost,127.0.0.1'
import django
django.setup()
from django.conf import settings
from django.test.utils import get_runner, override_settings

assert settings.DATABASES['default']['NAME'] == ':memory:'
with tempfile.TemporaryDirectory(prefix='beriya-tests-') as media:
    with override_settings(MEDIA_ROOT=media, STORAGES={
        'default': {'BACKEND': 'django.core.files.storage.FileSystemStorage'},
        'staticfiles': {'BACKEND': 'django.contrib.staticfiles.storage.StaticFilesStorage'},
    }):
        result = get_runner(settings)(verbosity=1, interactive=False).run_tests(
            sys.argv[1:] or [str(root / 'backend')])
sys.exit(bool(result))
