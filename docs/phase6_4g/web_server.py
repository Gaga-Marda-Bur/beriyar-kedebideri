"""Browser QA against an anonymized COPY of the actual educational corpus."""
import os,sys,sqlite3
from pathlib import Path
root=Path(__file__).resolve().parents[2]
runtime=Path(__file__).resolve().parent/'runtime'
db=runtime/'web.sqlite3'
sys.path.insert(0,str(root/'backend'))
if not db.exists():
    source=sqlite3.connect((root/'backend/db.sqlite3').as_uri()+'?mode=ro',uri=True)
    target=sqlite3.connect(db);source.backup(target);source.close()
    target.execute("UPDATE auth_user SET username='anon-'||id,password='!',email='',first_name='',last_name='',is_active=0,is_staff=0,is_superuser=0")
    target.execute('DELETE FROM django_session')
    private=[r[0] for r in target.execute("SELECT name FROM sqlite_master WHERE type='table'")
             if r[0].startswith(('progress_','feedback_','monetization_')) or r[0] in ('django_admin_log','auth_user_groups','auth_user_user_permissions')]
    for table in private:target.execute(f'DELETE FROM "{table}"')
    target.commit();target.execute('VACUUM');target.close()
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings',DJANGO_ENV='test',DEBUG='True',
    DATABASE_URL='sqlite:///'+db.as_posix(),USE_R2='False',SECRET_KEY='isolated-browser-qa-not-staging',
    ALLOWED_HOSTS='127.0.0.1,localhost,testserver',SECURE_SSL_REDIRECT='False')
import django
django.setup()
from django.conf import settings
from django.core.management import call_command
from django.contrib.auth import get_user_model
settings.PRIVATE_MEDIA_ROOT=runtime/'private'
settings.STORAGES['private']={'BACKEND':'django.core.files.storage.FileSystemStorage','OPTIONS':{'location':settings.PRIVATE_MEDIA_ROOT}}
settings.SESSION_COOKIE_SECURE=False;settings.CSRF_COOKIE_SECURE=False
call_command('migrate',interactive=False,verbosity=0)
get_user_model().objects.get_or_create(username='qa64g',defaults={'is_active':True})
user=get_user_model().objects.get(username='qa64g');user.set_password('synthetic-browser-only');user.save()
call_command('runserver','127.0.0.1:18778',use_reloader=False,verbosity=0)
