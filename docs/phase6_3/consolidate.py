"""Consolidate executed results and preservation checks; no secrets exported."""
from pathlib import Path
import ast
import hashlib
import json
import re
import subprocess
import django

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda name:json.loads((HERE/name).read_text(encoding='utf-8'))
logs={name:(HERE/'runtime'/name).read_text(encoding='utf-8',errors='replace') for name in (
 'baseline_django.log','baseline_flutter.log','baseline_js.log','final_django.log',
 'final_flutter.log','final_js.log','final_analyze.log','reproduction.log')}
def counts(prefix):
    dj=logs[prefix+'_django.log'];fl=logs[prefix+'_flutter.log'];js=logs[prefix+'_js.log']
    assert '\nOK\n' in dj and 'All tests passed!' in fl and '# fail 0' in js
    return {'django':int(re.search(r'Ran (\d+) tests',dj).group(1)),
       'flutter':int(re.search(r'\+(\d+): All tests passed!',fl).group(1)),
       'javascript':int(re.search(r'# pass (\d+)',js).group(1))}
assert 'No issues found!' in logs['final_analyze.log']
for item in json.loads((ROOT/'docs/phase6_reprise/MANIFEST.json').read_text(encoding='utf-8')):
    assert sha(Path(item['path']))==item['sha256']
phase62=json.loads((ROOT/'docs/phase6_2/RESULTS.json').read_text(encoding='utf-8'))
for item in phase62['artifacts']:
    assert sha(ROOT/'docs/phase6_2'/item['file'])==item['sha256']
fonts=json.loads((ROOT/'docs/phase6_reprise/PHASE6_VERIFICATIONS.json').read_text(encoding='utf-8'))['fonts']
for item in fonts:assert sha(ROOT/item['path'])==item['sha256']
restore=read('RESTORE_RESULTS.json')
assert sha(ROOT/'backend/db.sqlite3')==restore['source_db_sha256_after']
for directory in (ROOT/'backend/core',ROOT/'docs/phase6_3'):
    for path in directory.glob('*.py'):ast.parse(path.read_text(encoding='utf-8'))
for name in ('audio_migration_sql.log','feedback_migration_sql.log'):
    sql=(HERE/'runtime'/name).read_text(encoding='utf-8')
    assert '(no-op)' in sql and not re.search(r'\b(DROP|ALTER|CREATE)\s+TABLE\b',sql)
result={'date':'2026-11-10','branch':'codex/phase6-3-security-staging','base_commit':'7998177',
 'baseline':counts('baseline'),'final':counts('final'),'django_version_final':django.get_version(),
 'flutter_analyze':'No issues found','reproduction':'10 methods, 5 failures and 1 error before fixes',
 'phase62_evidence_and_six_fonts_unchanged':True,
 'source_db_sha256_at_restore_and_final':sha(ROOT/'backend/db.sqlite3'),
 'source_db_differs_from_phase62_archive':sha(ROOT/'backend/db.sqlite3')!=phase62['source_db_sha256'],
 'source_db_change_origin_since_phase62':'not established; no initial phase63 hash before first restore',
 'restore_summary':restore,'configuration_summary':read('CONFIG_RESULTS.json')['synthetic_config_checks'],
 'static_summary':read('STATIC_RESULTS.json'),'typography_http':read('TYPOGRAPHY_HTTP_RESULTS.json'),
 'media_migrations_schema_sql':'no-op, state only; applied only in isolated tests/restore',
 'physical_android_executed':False,'physical_android_reason':'No ADB device detected in this phase',
 'production_deployment':False,'ads_or_payments_activated':False,
 'decision':'GO local corrections review; NO-GO production pending external prerequisites'}
(HERE/'RESULTS.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
paths=set(subprocess.check_output(['git','diff','HEAD','--name-only'],cwd=ROOT,text=True).splitlines())
paths.update(subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=ROOT,text=True).splitlines())
assert not any(path.endswith('.pyc') for path in paths),'Restore generated tracked bytecode before recording deliverables'
(HERE/'FILES_CHANGED.txt').write_text('\n'.join(sorted(paths))+'\n',encoding='utf-8')
print(json.dumps({'baseline':result['baseline'],'final':result['final'],
 'audit_preserved':True,'current_source_stable_since_restore':True,'production_deployment':False}))
