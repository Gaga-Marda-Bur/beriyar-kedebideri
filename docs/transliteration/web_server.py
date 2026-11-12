"""Local browser receipt; only an anonymized SQLite copy is writable."""
import os
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = Path(__file__).resolve().parent / 'runtime'
RUNTIME.mkdir(exist_ok=True)
db = RUNTIME / 'browser.sqlite3'
if not db.exists():
    source = sqlite3.connect((ROOT / 'backend/db.sqlite3').as_uri() + '?mode=ro', uri=True)
    target = sqlite3.connect(db)
    source.backup(target)
    source.close()
    target.execute("UPDATE auth_user SET username='qa-'||id,password='!',email='',first_name='',last_name='',is_active=0,is_staff=0,is_superuser=0")
    private = [r[0] for r in target.execute("SELECT name FROM sqlite_master WHERE type='table'")
               if r[0].startswith(('progress_', 'feedback_', 'monetization_')) or r[0] in ('django_session', 'django_admin_log')]
    for table in private:
        target.execute(f'DELETE FROM "{table}"')
    target.commit()
    target.close()
sys.path.insert(0, str(ROOT / 'backend'))
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings', DJANGO_ENV='test', DEBUG='True',
    DATABASE_URL='sqlite:///' + db.as_posix(), USE_R2='False',
    SECRET_KEY='isolated-transliteration-receipt-not-production', ALLOWED_HOSTS='127.0.0.1,localhost',
    SECURE_SSL_REDIRECT='False', PYTHONDONTWRITEBYTECODE='1')
import django
django.setup()
from django.conf import settings
from django.core.management import call_command
settings.SESSION_COOKIE_SECURE = False
settings.CSRF_COOKIE_SECURE = False
settings.MEDIA_ROOT = RUNTIME / 'media'
settings.PRIVATE_MEDIA_ROOT = RUNTIME / 'private'
call_command('runserver', '127.0.0.1:18789', use_reloader=False, verbosity=0)
