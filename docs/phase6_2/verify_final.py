"""Evidence integrity and existing combining sequences; never writes source DB."""
from pathlib import Path
import hashlib
import json
import re
import sqlite3
import subprocess

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old=json.loads((ROOT/'docs/phase6_reprise/PHASE6_VERIFICATIONS.json').read_text(encoding='utf-8'))
db=ROOT/'backend/db.sqlite3'
assert sha(db)==old['database_after']
for info in json.loads((ROOT/'docs/phase6_reprise/MANIFEST.json').read_text(encoding='utf-8')):
    assert sha(Path(info['path']))==info['sha256']
for info in old['fonts']:
    assert sha(ROOT/info['path'])==info['sha256']
combinations=set()
with sqlite3.connect(db.as_uri()+'?mode=ro',uri=True) as connection:
    connection.execute('PRAGMA query_only=ON')
    for table in ('alphabet_character','vocabulary_word','learning_learningunit',
                  'lessons_lessonitem','quizzes_quizquestion','quizzes_quizoption'):
        columns=[r[1] for r in connection.execute(f'PRAGMA table_info("{table}")')
                 if r[1] in ('symbol','beriya_text','core_flow','prompt_fr','title_fr','text')]
        if not columns:continue
        for row in connection.execute('SELECT '+','.join('"'+c+'"' for c in columns)+f' FROM "{table}"'):
            for value in row:
                if not isinstance(value,str):continue
                try:value=json.dumps(json.loads(value),ensure_ascii=False)
                except (ValueError,TypeError):pass
                combinations.update(re.findall(r'[\U00016EA0-\U00016ED3][\u0300-\u036f]+',value))
result={'date':'2026-11-10','checkpoint':'4cb8708',
 'source_db_unchanged':sha(db)==old['database_after'],'source_db_sha256':sha(db),
 'audit_manifest_unchanged':True,'six_kedebideri_binaries_unchanged':True,
 'existing_erfe_combining_sequences':sorted(combinations),
 'keyboard_macron_sequences':sorted({chr(int(cp,16))+'\u0304' for cp in re.findall(
    r'\\u\{([0-9A-Fa-f]+)\}\\u\{0304\}',
    (ROOT/'backend/static/webapp/js/beriya_keyboard_data.js').read_text(encoding='utf-8'))}),
 'new_pdf_fonts':[{ 'file':p.name,'bytes':p.stat().st_size,'sha256':sha(p),
    'same_in_mobile':sha(p)==sha(ROOT/'mobile/assets/fonts'/p.name)}
    for p in (ROOT/'backend/static/webapp/fonts').glob('Noto*.ttf')],
 'artifacts':[{ 'file':p.relative_to(HERE).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)}
    for p in sorted((HERE/'captures').iterdir()) if p.is_file()]}
logs={name:(HERE/'runtime'/name).read_text(encoding='utf-8') for name in
      ('django_tests.log','flutter_tests.log','flutter_analyze.log','js_before.log','js_after.log')}
assert '\nOK\n' in logs['django_tests.log']
assert 'All tests passed!' in logs['flutter_tests.log']
assert 'No issues found!' in logs['flutter_analyze.log']
assert '# fail 0' in logs['js_after.log']
result['test_results']={
 'django_passed':int(re.search(r'Ran (\d+) tests',logs['django_tests.log']).group(1)),
 'flutter_passed':int(re.search(r'\+(\d+): All tests passed!',logs['flutter_tests.log']).group(1)),
 'javascript_passed':int(re.search(r'# pass (\d+)',logs['js_after.log']).group(1)),
 'javascript_baseline_failed':int(re.search(r'# fail (\d+)',logs['js_before.log']).group(1)),
 'flutter_analyze':'No issues found'}
assert all(item['same_in_mobile'] for item in result['new_pdf_fonts'])
(HERE/'RESULTS.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
changed=subprocess.check_output(['git','diff','HEAD','--name-only'],cwd=ROOT,text=True).splitlines()
untracked=subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=ROOT,text=True).splitlines()
(HERE/'FILES_CHANGED.txt').write_text('\n'.join(sorted(set(changed+untracked)))+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k not in ('artifacts','new_pdf_fonts')},ensure_ascii=False))
