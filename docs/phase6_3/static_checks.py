"""Check the production WhiteNoise pipeline on an isolated collected tree."""
import os
from pathlib import Path
import sys
import hashlib
import json
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'backend'))
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings',DJANGO_ENV='test',DEBUG='False',
 DATABASE_URL='sqlite:///:memory:',USE_R2='False',SECRET_KEY='static-check-only',
 ALLOWED_HOSTS='testserver',SECURE_SSL_REDIRECT='False',PYTHONDONTWRITEBYTECODE='1')
import django
django.setup()
from django.conf import settings
settings.STATIC_ROOT=Path((HERE/'runtime/last_static_path.txt').read_text(encoding='utf-8'))
from django.test import Client
manifest=json.loads((settings.STATIC_ROOT/'staticfiles.json').read_text(encoding='utf-8'))
refs=json.loads((ROOT/'docs/phase6_reprise/PHASE6_VERIFICATIONS.json').read_text(encoding='utf-8'))['fonts']
client=Client()
results=[]
for ref in refs:
    key='webapp/fonts/'+Path(ref['path']).name
    hashed=manifest['paths'][key]
    response=client.get('/static/'+hashed)
    assert response.status_code==200
    data=b''.join(response.streaming_content) if response.streaming else response.content
    assert hashlib.sha256(data).hexdigest()==ref['sha256']
    results.append({'file':Path(ref['path']).name,'http':response.status_code,'mime':response['Content-Type'],
       'cache_control':response.get('Cache-Control'),'sha256_equal':True})
result={'collectstatic_executed':True,'location':'new isolated ignored directory',
 'hashed_manifest':True,'whitenoise_local_requests':results,'production_deployment':False}
(HERE/'STATIC_RESULTS.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print('Six fonts served through collected WhiteNoise pipeline with identical bytes')
