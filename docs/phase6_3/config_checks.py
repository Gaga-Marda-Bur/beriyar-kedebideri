"""Redacted inventory and deployed-settings probes with synthetic values only."""
from pathlib import Path
import hashlib
import json
import os
import re
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
inventory=[]
for path in (ROOT/'backend').glob('.env*'):
    if not path.is_file():continue
    text=path.read_text(encoding='utf-8-sig')
    keys=sorted(set(re.findall(r'^\s*(?:export\s+)?([A-Z][A-Z0-9_]*)\s*=',text,re.M)))
    inventory.append({'file':path.relative_to(ROOT).as_posix(),'keys_only':keys,
      'secret_keys_present':[key for key in keys if re.search(r'KEY|SECRET|PASSWORD|TOKEN|DATABASE_URL',key)]})
base=os.environ.copy()
base.update(DJANGO_SETTINGS_MODULE='config.settings',DJANGO_ENV='staging',DEBUG='False',
 SECRET_KEY='phase63-synthetic-only-not-used-for-production-0123456789-ABCDEFGHIJKLMNOPQRSTUVWXYZ',
 ALLOWED_HOSTS='staging-api.example.org',CSRF_TRUSTED_ORIGINS='https://staging.example.org',
 CORS_ALLOWED_ORIGINS='https://staging.example.org',CORS_ALLOW_ALL_ORIGINS='False',
 DATABASE_URL='postgresql://synthetic:synthetic@127.0.0.1:1/never_connected',
 DATABASE_REQUIRE_SSL='True',USE_R2='False',MEDIA_STORAGE_PERSISTENT='True',
 PRIVATE_MEDIA_ROOT=str(HERE/'runtime/private'),
 FEEDBACK_CACHE_BACKEND='django.core.cache.backends.db.DatabaseCache',
 FEEDBACK_CACHE_LOCATION='feedback_rate_limits',TRUST_X_FORWARDED_PROTO='False',
 SECURE_SSL_REDIRECT='True',SECURE_HSTS_PRELOAD='False',SECURE_HSTS_INCLUDE_SUBDOMAINS='False',
 SECURE_HSTS_SECONDS='300',PYTHONDONTWRITEBYTECODE='1')
script="""
import json,django
django.setup()
from django.conf import settings
from django.core.checks import run_checks
result={'environment':settings.DJANGO_ENV,'debug':settings.DEBUG,
 'https_redirect':settings.SECURE_SSL_REDIRECT,'cookie_secure':settings.SESSION_COOKIE_SECURE,
 'database_engine':settings.DATABASES['default']['ENGINE'],
 'database_tls':settings.DATABASES['default']['OPTIONS'].get('sslmode'),
 'cache_backend':settings.CACHES['feedback']['BACKEND'],
 'private_storage_backend':settings.STORAGES['private']['BACKEND'],
 'private_has_no_custom_domain':settings.STORAGES['private']['OPTIONS'].get('custom_domain') is None,
 'r2_buckets_distinct':settings.STORAGES['private']['OPTIONS'].get('bucket_name')!=getattr(settings,'AWS_STORAGE_BUCKET_NAME',None) if settings.USE_R2 else None,
 'deploy_checks':[{'id':issue.id,'level':issue.level} for issue in run_checks(include_deployment_checks=True)]}
print(json.dumps(result))
"""
def run(changes,ok):
    env={**base,**changes}
    result=subprocess.run([sys.executable,'-c',script],cwd=ROOT/'backend',env=env,
       capture_output=True,text=True)
    assert (result.returncode==0)==ok, 'Configuration probe failed (details deliberately redacted)'
    return json.loads(result.stdout) if ok else {'rejected':True}

scenarios={'staging':run({},True),'production':run({'DJANGO_ENV':'production'},True)}
for name,changes in {
 'no_database':{'DATABASE_URL':''},'sqlite_deployed':{'DATABASE_URL':'sqlite:///:memory:'},
 'local_cache':{'FEEDBACK_CACHE_BACKEND':'django.core.cache.backends.locmem.LocMemCache'},
 'ephemeral_media':{'MEDIA_STORAGE_PERSISTENT':'False'},
 'public_private_overlap':{'PRIVATE_MEDIA_ROOT':str(ROOT/'backend/media/private')},
 'insecure_database':{'DATABASE_REQUIRE_SSL':'False','DATABASE_NETWORK':'public'},
}.items():scenarios[name]=run(changes,False)
r2={'USE_R2':'True','R2_ACCESS_KEY_ID':'synthetic-only','R2_SECRET_ACCESS_KEY':'synthetic-only',
 'R2_BUCKET_NAME':'qa-public','R2_PRIVATE_BUCKET_NAME':'qa-private',
 'R2_ENDPOINT_URL':'https://synthetic.r2.cloudflarestorage.com',
 'R2_PUBLIC_BASE_URL':'https://media.example.org'}
scenarios['r2_distinct_private']=run(r2,True)
assert scenarios['r2_distinct_private']['r2_buckets_distinct']
assert scenarios['r2_distinct_private']['private_has_no_custom_domain']
scenarios['r2_missing_private']=run({**r2,'R2_PRIVATE_BUCKET_NAME':''},False)
scenarios['r2_same_bucket']=run({**r2,'R2_PRIVATE_BUCKET_NAME':'qa-public'},False)
scenarios['r2_public_http']=run({**r2,'R2_PUBLIC_BASE_URL':'http://media.example.org'},False)
result={'date':'2026-11-10','inventory':inventory,'synthetic_config_checks':scenarios,
 'values_from_real_env_files_exported':False,'network_or_database_connections':False}
result['sensitive_file_presence']=[]
for relative in ('backend/.env.production','backend/.env','mobile/android/key.properties',
                 'mobile/android/app/beriyar-release-key.jks'):
    tracked=bool(subprocess.check_output(['git','ls-files','--',relative],cwd=ROOT,text=True).strip())
    ignored=subprocess.run(['git','check-ignore','-q','--',relative],cwd=ROOT).returncode==0
    result['sensitive_file_presence'].append({'file':relative,'exists':(ROOT/relative).is_file(),
        'tracked':tracked,'ignored':ignored})
(HERE/'CONFIG_RESULTS.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'inventory_files':len(inventory),'config_probes':len(scenarios),
                  'deploy_check_ids':scenarios['staging']['deploy_checks']}))
