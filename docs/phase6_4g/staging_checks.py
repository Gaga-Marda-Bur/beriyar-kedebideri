"""Local synthetic configuration probes; no actual staging secret or database used."""
import json,os,secrets,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'backend'))
from config.security import build_security_settings
from django.core.exceptions import ImproperlyConfigured
profile={'DJANGO_ENV':'staging','DEBUG':'False','SECRET_KEY':secrets.token_urlsafe(64),
 'ALLOWED_HOSTS':'staging.example.invalid','CSRF_TRUSTED_ORIGINS':'https://staging.example.invalid',
 'SECURE_HSTS_SECONDS':'300','SECURE_HSTS_PRELOAD':'False','SECURE_HSTS_INCLUDE_SUBDOMAINS':'False'}
settings=build_security_settings(profile.get)
probes={}
for name,patch in {
 'debug':{'DEBUG':'True'},'wildcard_host':{'ALLOWED_HOSTS':'*'},
 'http_csrf':{'CSRF_TRUSTED_ORIGINS':'http://staging.example.invalid'},
 'cors_all':{'CORS_ALLOW_ALL_ORIGINS':'True'},'weak_secret':{'SECRET_KEY':'development'},
 'proxy_without_count':{'TRUST_X_FORWARDED_PROTO':'True','NUM_PROXIES':'0'},
}.items():
    try:build_security_settings({**profile,**patch}.get);probes[name]='NOT_REJECTED'
    except ImproperlyConfigured:probes[name]='rejected'
os.environ.update(profile,DJANGO_SETTINGS_MODULE='config.settings',
 DATABASE_URL='postgresql://synthetic:unused@127.0.0.1:55464/bk64g_config_only',
 DATABASE_REQUIRE_SSL='True',MEDIA_STORAGE_PERSISTENT='True',USE_R2='False',
 FEEDBACK_CACHE_BACKEND='django.core.cache.backends.db.DatabaseCache',FEEDBACK_CACHE_LOCATION='synthetic_cache')
import django
django.setup()
from django.core.management import call_command
call_command('check',deploy=True)
from django.core.checks import run_checks
messages=run_checks(include_deployment_checks=True)
public={k:v for k,v in settings.items() if k in ['DJANGO_ENV','DEBUG','ALLOWED_HOSTS','CSRF_TRUSTED_ORIGINS','CORS_ALLOWED_ORIGINS','CORS_ALLOW_ALL_ORIGINS','SESSION_COOKIE_SECURE','CSRF_COOKIE_SECURE','SESSION_COOKIE_HTTPONLY','SESSION_COOKIE_SAMESITE','SECURE_SSL_REDIRECT','SECURE_HSTS_SECONDS','SECURE_HSTS_PRELOAD','SECURE_HSTS_INCLUDE_SUBDOMAINS','SECURE_PROXY_SSL_HEADER']}
result={'synthetic_only':True,'effective':public,'rejection_probes':probes,
 'django_deploy_check':'completed','deploy_messages':[{'id':m.id,'message':m.msg} for m in messages],
 'no_actual_database_connection':True,
 'unverified_remote':['TLS termination','real domains and DNS','proxy overwrite','secret provenance','database role and TLS','media persistence/ACL','file permissions','log redaction/retention','backup restore target']}
(Path(__file__).parent/'STAGING_CHECKS.json').write_text(json.dumps(result,indent=2)+'\n')
assert all(x=='rejected' for x in probes.values()),probes
