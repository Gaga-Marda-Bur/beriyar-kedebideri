"""Audit only: synthetic in-memory data and read-only local SQLite aggregates.

Run from repository root with PYTHONDONTWRITEBYTECODE=1.
Never imports production environment files or uses production storage.
"""
import json
import os
from pathlib import Path
import sqlite3
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backend'))
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings', DJANGO_ENV='test',
                  DATABASE_URL='sqlite:///:memory:', USE_R2='False', DEBUG='False',
                  SECURE_SSL_REDIRECT='False', ALLOWED_HOSTS='testserver,localhost',
                  SECRET_KEY='isolated-audit-only-not-a-production-key')
import django
django.setup()
from django.conf import settings
from django.core.management import call_command
from django.test import override_settings
from django.test.utils import CaptureQueriesContext
from django.db import connection
from rest_framework.test import APIClient
from learning.models import LearningTheme, LearningUnit
from progress.models import UnitProgress
from vocabulary.models import Word

assert settings.DATABASES['default']['NAME'] == ':memory:'
call_command('migrate', verbosity=0, interactive=False)
call_command('makemigrations', check=True, dry_run=True, verbosity=0)
result = {'scope': 'Synthetic in-memory SQLite; local inventory read-only',
          'model_migration_consistency': 'passed'}
theme = LearningTheme.objects.create(slug='audit-only', title_fr='Audit', status='published')
unit = LearningUnit.objects.create(theme=theme, slug='audit-only', title_fr='Audit', status='published')
legacy = UnitProgress.objects.create(device_id='audit-legacy', unit=unit, lessons_seen=8)
api = APIClient(raise_request_exception=False)
result['global_progress_status'] = api.get('/api/progress/unit-progress/').status_code
read = api.get('/api/progress/unit-progress/', {'device_id': 'audit-legacy'}, HTTP_X_DEVICE_TOKEN='arbitrary-new-token')
result['legacy_read_with_unregistered_token'] = {'status': read.status_code, 'count': read.data.get('count')}
sync = api.post('/api/progress/unit-progress/sync/', {'items': [{
    'unit_slug': unit.slug, 'device_id': 'audit-legacy', 'device_token': 'arbitrary-new-token',
    'lessons_seen': 9}]}, format='json')
legacy.refresh_from_db()
result['legacy_claim'] = {'status': sync.status_code, 'synced': sync.data['synced_count'],
                          'token_claimed': legacy.device_token == 'arbitrary-new-token'}
other_unit = LearningUnit.objects.create(theme=theme, slug='audit-other', title_fr='Audit', status='published')
new = api.post('/api/progress/unit-progress/sync/', {'items': [{
    'unit_slug': other_unit.slug, 'device_id': 'audit-legacy', 'device_token': 'different-token'}]}, format='json')
result['same_device_new_unit_other_token'] = {'synced': new.data['synced_count'], 'errors': new.data['error_count']}
cross_read = api.get('/api/progress/unit-progress/', {'device_id': 'audit-legacy'}, HTTP_X_DEVICE_TOKEN='different-token')
result['other_unit_token_reads_existing_history'] = {'status': cross_read.status_code, 'count': cross_read.data.get('count')}
malformed = api.post('/api/progress/unit-progress/sync/', {'items': [None, {'unit_slug': unit.slug, 'device_token': 42}]}, format='json')
result['malformed_token'] = {'status': malformed.status_code} if malformed.status_code != 200 else {'status': 200, 'errors': malformed.data['error_count']}

Word.objects.bulk_create([Word(beriya_text='audit-%04d' % i, validation_status='published') for i in range(101)])
with override_settings(STORAGES={
    'default': {'BACKEND': 'django.core.files.storage.FileSystemStorage'},
    'staticfiles': {'BACKEND': 'django.contrib.staticfiles.storage.StaticFilesStorage'}}):
    timings = []
    for count in (101, 1001):
        if count == 1001:
            Word.objects.bulk_create([Word(beriya_text='audit-%04d' % i, validation_status='published') for i in range(101, 1001)])
        with CaptureQueriesContext(connection) as queries:
            start = time.perf_counter()
            page = api.get('/vocabulaire/')
            elapsed = (time.perf_counter() - start) * 1000
        timings.append({'words': count, 'status': page.status_code, 'queries': len(queries),
                        'html_bytes': len(page.content), 'elapsed_ms_single_sample': round(elapsed, 1)})
    result['dictionary_synthetic_baseline'] = timings
    french = api.get('/vocabulaire/?q=audit-0001&lang=fr')
    english = api.get('/vocabulaire/?lang=en')
    result['language_switch_drops_search'] = b'value="audit-0001"' not in english.content

db = sqlite3.connect((ROOT / 'backend/db.sqlite3').as_uri() + '?mode=ro', uri=True)
result['local_data'] = {
    'duplicate_exact_word_groups': db.execute('SELECT COUNT(*) FROM (SELECT beriya_text FROM vocabulary_word GROUP BY beriya_text HAVING COUNT(*)>1)').fetchone()[0],
    'unit_tracing_enabled': db.execute('SELECT COUNT(*) FROM learning_learningunit WHERE enable_tracing=1').fetchone()[0],
    'word_statuses': dict(db.execute('SELECT validation_status, COUNT(*) FROM vocabulary_word GROUP BY validation_status')),
    'pack_statuses': dict(db.execute('SELECT status, COUNT(*) FROM offline_packs_lessonpack GROUP BY status')),
    'applied_migrations': db.execute('SELECT COUNT(*) FROM django_migrations').fetchone()[0],
}
db.close()
output = json.dumps(result, ensure_ascii=False, indent=2)
(ROOT / 'docs/audit_2026_11_09_results.json').write_text(output + '\n', encoding='utf-8')
print(output)
