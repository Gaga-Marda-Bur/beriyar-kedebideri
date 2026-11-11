"""Run real PostgreSQL concurrency and isolation tests for Lot 6.4E."""
import os
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / 'backend'))

os.environ.update(
    DJANGO_SETTINGS_MODULE='config.settings',
    DJANGO_ENV='test',
    DEBUG='False',
    DATABASE_URL='postgresql://postgres@127.0.0.1:15432/bk_audit_test',
    USE_R2='False',
    SECRET_KEY='postgres-audit-test-key-64e',
    SECURE_SSL_REDIRECT='False',
    ALLOWED_HOSTS='127.0.0.1,localhost,testserver'
)

import django
django.setup()

from django.conf import settings
from django.db import connection
from django.test.utils import get_runner, override_settings

assert connection.vendor == 'postgresql', f'Expected postgresql, got {connection.vendor}'
print(f'Connected to PostgreSQL: {connection.settings_dict["NAME"]} on {connection.settings_dict["HOST"]}:{connection.settings_dict["PORT"]}')

with override_settings(
    STORAGES={
        'default': {'BACKEND': 'django.core.files.storage.FileSystemStorage'},
        'staticfiles': {'BACKEND': 'django.contrib.staticfiles.storage.StaticFilesStorage'},
    }
):
    runner = get_runner(settings)(verbosity=2, interactive=False)
    failures = runner.run_tests(['monetization.tests_concurrency'])
    sys.exit(bool(failures))
