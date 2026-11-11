"""Synthetic loopback-only QA. Never imports or migrates an existing DB."""
import argparse,base64,json,os,sys
from pathlib import Path
from datetime import timedelta

root=Path(__file__).resolve().parents[2]
runtime=Path(__file__).resolve().parent/'runtime'
runtime.mkdir(exist_ok=True)
db=runtime/'qa.sqlite3'
sys.path.insert(0,str(root/'backend'))
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings',DJANGO_ENV='test',DEBUG='False',
 DATABASE_URL='sqlite:///'+db.as_posix(),USE_R2='False',SECRET_KEY='synthetic-64c-server-only',
 SECURE_SSL_REDIRECT='False',ALLOWED_HOSTS='127.0.0.1,localhost,testserver',
 MONETIZATION_SIGNING_KEY_FILE=str(runtime/'signer.pem'),MONETIZATION_SIGNING_KID='sim-64c-qa')
import django
django.setup()
from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.utils import timezone
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from monetization.models import PremiumFeature,PremiumPlan,PaymentMethod,EntitlementGrant
from monetization import services

assert Path(settings.DATABASES['default']['NAME']).resolve()==db.resolve()
parser=argparse.ArgumentParser()
parser.add_argument('action',choices=['prepare','serve','reset','expire','revoke','disable','delete'])
args=parser.parse_args()
if args.action=='prepare':
    assert not db.exists(),'Refuse to overwrite an existing QA database; choose a fresh runtime.'
    call_command('migrate',interactive=False,verbosity=0)
    key=Ed25519PrivateKey.generate()
    (runtime/'signer.pem').write_bytes(key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption()))
    (runtime/'public_keys.json').write_text(json.dumps({'sim-64c-qa':base64.b64encode(key.public_key().public_bytes(serialization.Encoding.Raw,serialization.PublicFormat.Raw)).decode()}))
    User=get_user_model()
    a=User.objects.create_user('qa64c-a',password='synthetic-session-password')
    User.objects.create_user('qa64c-b',password='synthetic-session-password')
    maker=User.objects.create_superuser('qa64c-maker',password='synthetic-admin-only')
    checker=User.objects.create_superuser('qa64c-checker',password='synthetic-admin-only')
    feature=PremiumFeature.objects.create(code='simulation.badge',label='Badge de démonstration')
    plan=PremiumPlan.objects.create(code='qa64c',label='BK · Démonstration',simulation_available=True)
    plan.features.add(feature)
    method=PaymentMethod.objects.create(code='qa64c',kind='cash',enabled=True)
    req=services.create_request(actor=maker,user=a,plan=plan,method=method,key='qa64c',reason='Synthetic phone QA')
    services.transition(actor=maker,request_id=req.pk,action='verify',receipt='SIM-QA64C',reason='Synthetic phone QA')
    services.transition(actor=checker,request_id=req.pk,action='activate',reason='Synthetic phone QA')
    print('Synthetic accounts A/B and test public key prepared; no real data.')
elif args.action=='serve':
    assert db.exists()
    # HTTP is confined to USB adb reverse -> loopback; CSRF remains enabled.
    settings.SESSION_COOKIE_SECURE=False
    settings.CSRF_COOKIE_SECURE=False
    call_command('runserver','127.0.0.1:18765',use_reloader=False,verbosity=0)
else:
    a=get_user_model().objects.get(username='qa64c-a')
    if args.action=='reset':
        a.is_active=True; a.save()
        EntitlementGrant.objects.filter(user=a).update(revoked_at=None,ends_at=timezone.now()+timedelta(days=30))
    elif args.action=='expire':
        EntitlementGrant.objects.filter(user=a).update(ends_at=timezone.now()-timedelta(seconds=1))
    elif args.action=='revoke':
        EntitlementGrant.objects.filter(user=a).update(revoked_at=timezone.now())
        state=services.state_for(a);state.entitlement_epoch+=1;state.save()
    elif args.action=='disable':
        a.is_active=False;a.save()
    elif args.action=='delete':
        a.delete()
    print('Synthetic QA mutation completed:',args.action)
