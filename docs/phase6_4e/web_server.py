"""Isolated web test server with WhiteNoise for static files and pre-populated educational database."""
import os, sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / 'backend'))
runtime = root / 'docs' / 'phase6_4e' / 'web_runtime'
runtime.mkdir(exist_ok=True, parents=True)
db = runtime / 'web_test.sqlite3'

os.environ.update(
    DJANGO_SETTINGS_MODULE='config.settings',
    DJANGO_ENV='test',
    DEBUG='False',
    DATABASE_URL='sqlite:///' + db.as_posix(),
    USE_R2='False',
    SECRET_KEY='web-browser-receipt-64e-isolated',
    SECURE_SSL_REDIRECT='False',
    ALLOWED_HOSTS='127.0.0.1,localhost,testserver',
    MONETIZATION_SIGNING_KEY_FILE=str(root / 'docs' / 'phase6_4c' / 'runtime' / 'signer.pem'),
    MONETIZATION_SIGNING_KID='sim-64c-qa'
)

import django
django.setup()

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.management import call_command
from monetization.models import PremiumFeature, PremiumPlan, PaymentMethod, CommercialPolicy
from alphabet.models import Character
from vocabulary.models import WordCategory, Word

if not db.exists():
    call_command('migrate', interactive=False, verbosity=0)
    # Collect static into isolated staticfiles directory for WhiteNoise
    call_command('collectstatic', interactive=False, verbosity=0)
    
    User = get_user_model()
    superadmin = User.objects.create_superuser('web-superadmin', password='WebPassword2026!')
    customer_a = User.objects.create_user('web-customer-a', password='CustomerPassA2026!')
    customer_b = User.objects.create_user('web-customer-b', password='CustomerPassB2026!')
    
    CommercialPolicy.objects.create(pk=1, version=1, ads_enabled=False, emergency_stop=False)
    feat = PremiumFeature.objects.create(code='simulation.badge', label='Badge de démonstration')
    plan = PremiumPlan.objects.create(code='web_sim', label='BK · Démonstration Web', simulation_available=True)
    plan.features.add(feat)
    PaymentMethod.objects.create(code='web_cash', kind='cash', enabled=True)
    
    # Educational test fixtures
    c = Character.objects.create(
        symbol='𖺠', unicode_code='U+16EA0', name='A', name_fr='A',
        latin_transcription='a', arabic_transcription='أ',
        character_type='vowel', order_index=1, validation_status='approved'
    )
    cat = WordCategory.objects.create(slug='famille', name_fr='Famille', name_en='Family', name_ar='العائلة', order_index=1)
    Word.objects.create(
        beriya_text='𖺠𖺮', latin_transcription='Ber', arabic_transcription='بر',
        french_translation='Fils / Homme', english_translation='Son / Man', arabic_translation='ابن / رجل',
        category=cat, validation_status='approved'
    )
    print('Web test fixtures populated successfully.')

if __name__ == '__main__':
    settings.SESSION_COOKIE_SECURE = False
    settings.CSRF_COOKIE_SECURE = False
    call_command('runserver', '127.0.0.1:18770', use_reloader=False, verbosity=1)
