"""Only our explicitly isolated local cluster, never DATABASE_URL from .env."""
import os
import sys
import tempfile
from pathlib import Path

root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'backend'))
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings',DJANGO_ENV='test',DEBUG='False',
    DATABASE_URL='postgresql://bk_simulation@127.0.0.1:55464/bk64b_recette',
    DATABASE_REQUIRE_SSL='False',USE_R2='False',SECRET_KEY='isolated-synthetic-postgres-tests',
    SECURE_SSL_REDIRECT='False',ALLOWED_HOSTS='testserver,localhost,127.0.0.1')
import django
django.setup()
from django.conf import settings
from django.test.utils import get_runner,override_settings

assert settings.DATABASES['default']['NAME']=='bk64b_recette'
assert settings.DATABASES['default']['PORT']==55464 or settings.DATABASES['default']['PORT']=='55464'
with tempfile.TemporaryDirectory(dir=Path(__file__).parent/'runtime',prefix='pg-tests-') as temp:
    with override_settings(MEDIA_ROOT=Path(temp)/'public',PRIVATE_MEDIA_ROOT=Path(temp)/'private',
        STORAGES={'default':{'BACKEND':'django.core.files.storage.FileSystemStorage'},
                  'staticfiles':{'BACKEND':'django.contrib.staticfiles.storage.StaticFilesStorage'}}):
        result=get_runner(settings)(verbosity=2,interactive=False).run_tests(sys.argv[1:] or ['monetization'])
sys.exit(bool(result))
