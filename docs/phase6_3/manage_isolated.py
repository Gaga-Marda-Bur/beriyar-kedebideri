"""Only disposable settings; never use a real DATABASE_URL for local checks."""
import os
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'backend'))
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings',DJANGO_ENV='test',
 DATABASE_URL='sqlite:///:memory:',USE_R2='False',DEBUG='False',
 SECRET_KEY='phase63-isolated-only',ALLOWED_HOSTS='testserver,localhost,127.0.0.1',
 SECURE_SSL_REDIRECT='False',PYTHONDONTWRITEBYTECODE='1')
import django
django.setup()
from django.conf import settings
settings.MEDIA_ROOT=ROOT/'docs/phase6_3/runtime/media'
settings.PRIVATE_MEDIA_ROOT=ROOT/'docs/phase6_3/runtime/private'
if len(sys.argv)>1 and sys.argv[1]=='collectstatic':
    import tempfile
    settings.STATIC_ROOT=Path(tempfile.mkdtemp(prefix='static-',dir=ROOT/'docs/phase6_3/runtime'))
    (ROOT/'docs/phase6_3/runtime/last_static_path.txt').write_text(str(settings.STATIC_ROOT),encoding='utf-8')
from django.core.management import execute_from_command_line
execute_from_command_line([sys.argv[0],*sys.argv[1:]])
