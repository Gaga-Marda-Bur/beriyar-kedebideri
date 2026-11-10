"""Local-only read-only Django typography QA, no migrations or production config."""
import os
from pathlib import Path
import sys
from wsgiref.simple_server import make_server

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'backend'))
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings', DJANGO_ENV='test',
    DATABASE_URL='sqlite:///:memory:', USE_R2='False', DEBUG='True',
    SECRET_KEY='typography-local-only', ALLOWED_HOSTS='127.0.0.1,localhost',
    SECURE_SSL_REDIRECT='False', PYTHONDONTWRITEBYTECODE='1')
import django
django.setup()
from django.conf import settings
settings.DATABASES['default'].update(NAME=(ROOT / 'backend/db.sqlite3').as_uri() + '?mode=ro',
    OPTIONS={'uri': True})
settings.SESSION_ENGINE = 'django.contrib.sessions.backends.signed_cookies'
if 'before' in sys.argv:
    baseline = Path(__file__).parent / 'runtime/baseline/backend'
    settings.TEMPLATES[0]['DIRS'] = [baseline / 'templates']
    settings.STATICFILES_DIRS = [baseline / 'static', ROOT / 'backend/static']
from django.contrib.staticfiles.handlers import StaticFilesHandler
from django.core.wsgi import get_wsgi_application

print('QA read-only http://127.0.0.1:8766', flush=True)
make_server('127.0.0.1', 8766, StaticFilesHandler(get_wsgi_application())).serve_forever()
