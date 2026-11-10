"""Real SQLite + media backup/restore; unique destination, source strictly RO.

Never executes the old destructive scratch cleanup or touches cloud resources.
Private DBs/media and detailed paths stay in ignored runtime, results are counts.
"""
from collections import Counter
from pathlib import Path
import hashlib
import json
import os
import shutil
import sqlite3
import sys
import tempfile
import zipfile

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
LAB=Path(tempfile.mkdtemp(prefix='restore-',dir=HERE/'runtime'))
SOURCE=ROOT/'backend/db.sqlite3'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
before=sha(SOURCE)

def snapshot(path):
    with sqlite3.connect(path.as_uri()+'?mode=ro',uri=True) as db:
        tables=db.execute("SELECT name,sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name").fetchall()
        return {name:{'ddl':sql,'columns':[r[1] for r in db.execute(f'PRAGMA table_info("{name}")')],
                      'rows':sorted(db.execute(f'SELECT * FROM "{name}"').fetchall(),key=repr)} for name,sql in tables}

backup=LAB/'backup.sqlite3';restored=LAB/'restored.sqlite3'
with sqlite3.connect(SOURCE.as_uri()+'?mode=ro',uri=True) as source,sqlite3.connect(backup) as target:
    source.backup(target)
with sqlite3.connect(backup.as_uri()+'?mode=ro',uri=True) as source,sqlite3.connect(restored) as target:
    source.backup(target)
initial=snapshot(backup)
assert snapshot(restored)==initial
with sqlite3.connect(restored) as db:
    assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
    assert not db.execute('PRAGMA foreign_key_check').fetchall()

def media_snapshot(directory):
    result={}
    if directory.is_dir():
        for path in directory.rglob('*'):
            assert not path.is_symlink(),'Symlink not allowed in backup'
            if path.is_file():
                assert path.resolve().is_relative_to(directory.resolve())
                result[path.relative_to(directory).as_posix()]=sha(path)
    return result

media={}
for label,directory in (('public',ROOT/'backend/media'),('private',ROOT/'backend/private_media')):
    hashes=media_snapshot(directory)
    out=LAB/f'restored_{label}'
    out.mkdir()
    for name in hashes:
        destination=out/name;destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(directory/name,destination)
    assert media_snapshot(out)==hashes
    assert media_snapshot(directory)==hashes
    media[label]={'files':len(hashes),'bytes':sum((directory/name).stat().st_size for name in hashes),
      'audio_files':sum(Path(name).suffix.lower() in ('.wav','.mp3','.m4a') for name in hashes),
      'all_sha256_equal':True}

sys.path.insert(0,str(ROOT/'backend'))
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings',DJANGO_ENV='test',DEBUG='False',
 DATABASE_URL='sqlite:///'+restored.as_posix(),USE_R2='False',SECRET_KEY='restore-local-only',
 SECURE_SSL_REDIRECT='False',ALLOWED_HOSTS='testserver,127.0.0.1',PYTHONDONTWRITEBYTECODE='1')
import django
django.setup()
from django.conf import settings
settings.MEDIA_ROOT=LAB/'restored_public'
settings.PRIVATE_MEDIA_ROOT=LAB/'restored_private'
from django.core.management import call_command
from django.db import connection
from django.db.migrations.executor import MigrationExecutor
executor=MigrationExecutor(connection)
targets=executor.loader.graph.leaf_nodes()
plan=executor.migration_plan(targets)
planned=[f'{migration.app_label}.{migration.name}' for migration,backward in plan]
assert not any(backward for migration,backward in plan)
executor.migrate(targets)
call_command('makemigrations',check=True,dry_run=True,verbosity=0)
after=snapshot(restored)
# Every pre-existing value, including accounts/history/linguistic data, survives.
for table,content in initial.items():
    assert table in after
    indices=[after[table]['columns'].index(column) for column in content['columns']]
    projected=sorted([tuple(row[i] for i in indices) for row in after[table]['rows']],key=repr)
    if table=='django_migrations':
        assert set(content['rows']).issubset(set(projected))
    else:
        assert projected==content['rows'],f'Existing values changed in {table}'
with sqlite3.connect(restored) as db:
    assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
    assert not db.execute('PRAGMA foreign_key_check').fetchall()

from django.apps import apps
from django.db.models import FileField
missing=Counter();references=0;restored_audio=0
for model in apps.get_models():
    fields=[field for field in model._meta.fields if isinstance(field,FileField)]
    if not fields:continue
    for obj in model.objects.all():
        for field in fields:
            file=getattr(obj,field.name)
            if not file:continue
            references+=1
            if file.storage.exists(file.name):
                if Path(file.name).suffix.lower() in ('.wav','.mp3','.m4a'):
                    with file.open('rb') as stream:
                        assert stream.read(1)
                    restored_audio+=1
            else:missing[f'{model._meta.label}.{field.name}']+=1

from offline_packs.models import LessonPack
packs=[]
for pack in LessonPack.objects.exclude(file='').exclude(file__isnull=True):
    if not pack.file.storage.exists(pack.file.name):
        packs.append({'present':False});continue
    with pack.file.open('rb') as stream:
        digest=hashlib.file_digest(stream,'sha256').hexdigest()
    with pack.file.open('rb') as stream,zipfile.ZipFile(stream) as archive:
        crc_ok=archive.testzip() is None
    packs.append({'present':True,'stored_checksum_present':bool(pack.checksum),
       'checksum_equal':digest==pack.checksum if pack.checksum else None,'zip_crc_ok':crc_ok})
assert all(not p.get('stored_checksum_present') or p['checksum_equal'] for p in packs)
# Sequential independent workers demonstrate shared cache visibility, not atomic
# rate limiting under concurrent load. Only the restored SQLite gets this table.
import subprocess
worker_env={**os.environ,'FEEDBACK_CACHE_BACKEND':'django.core.cache.backends.db.DatabaseCache',
            'FEEDBACK_CACHE_LOCATION':'qa63_rate_limits'}
create="import django;django.setup();from django.core.management import call_command;call_command('createcachetable',verbosity=0)"
subprocess.run([sys.executable,'-c',create],cwd=ROOT/'backend',env=worker_env,check=True,capture_output=True)
counter="import django;django.setup();from django.core.cache import caches;c=caches['feedback'];v=c.get('qa63',0)+1;c.set('qa63',v,60);print(v)"
workers=[int(subprocess.check_output([sys.executable,'-c',counter],cwd=ROOT/'backend',env=worker_env,text=True)) for _ in range(2)]
assert workers==[1,2]
assert sha(SOURCE)==before
result={'date':'2026-11-10','source_db_sha256_before':before,'source_db_sha256_after':sha(SOURCE),
 'destination':'unique ignored runtime/restore-* directory','source_opened_readonly':True,
 'tables_compared_before_migrations':len(initial),'rows_compared_before_migrations':sum(len(t['rows']) for t in initial.values()),
 'all_schema_and_rows_equal_before_migrations':True,'all_preexisting_values_preserved_after_migrations':True,
 'migration_plan_applied_to_restore_only':planned,'integrity_check':'ok','foreign_key_violations':0,
 'media':media,'file_references':references,'missing_references_by_field':dict(missing),
 'restored_audio_references_opened':restored_audio,'packs':packs,
 'database_cache_independent_workers':workers,'atomic_concurrent_throttling_proven':False,
 'postgresql_or_cloud_restore_executed':False}
(HERE/'RESTORE_RESULTS.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
# Keep private absolute runtime path only in runtime for later diagnostics.
(HERE/'runtime/last_restore_path.txt').write_text(str(LAB),encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
