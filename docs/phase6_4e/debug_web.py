import os, sys
from pathlib import Path
root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / 'backend'))
qa_db = root / 'docs' / 'phase6_4c' / 'runtime' / 'qa.sqlite3'
os.environ.update(
    DJANGO_SETTINGS_MODULE='config.settings',
    DJANGO_ENV='test',
    DEBUG='True',
    DATABASE_URL='sqlite:///' + qa_db.as_posix(),
    USE_R2='False',
    SECRET_KEY='synthetic-qa-key',
    SECURE_SSL_REDIRECT='False',
    ALLOWED_HOSTS='127.0.0.1,localhost,testserver'
)
import django
django.setup()
from django.test import Client
c = Client()
try:
    r = c.get('/alphabet/')
    print('GET /alphabet/ Status:', r.status_code)
    if r.status_code != 200:
        print('Content snippet:', r.content[:500].decode('utf-8', errors='ignore'))
except Exception as e:
    import traceback
    traceback.print_exc()
