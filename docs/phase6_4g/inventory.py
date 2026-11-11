"""Read-only source inventory. No linguistic content generated or repaired."""
import hashlib,json,sqlite3,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[2]
source=root/'backend/db.sqlite3'
before=hashlib.sha256(source.read_bytes()).hexdigest()
db=sqlite3.connect(source.as_uri()+'?mode=ro',uri=True);db.row_factory=sqlite3.Row
tables={r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
summary={}
for table in sorted(tables):
    if not table.startswith(('alphabet_','vocabulary_','learning_','lessons_','quizzes_','audio_assets_','offline_packs_')):continue
    columns={r[1] for r in db.execute(f'PRAGMA table_info("{table}")')}
    item={'count':db.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]}
    for column in ['validation_status','status','is_active','lesson_type','question_type','unit_type','track']:
        if column in columns:
            item[column]={str(r[0]):r[1] for r in db.execute(f'SELECT "{column}",COUNT(*) FROM "{table}" GROUP BY "{column}"')}
    if 'file' in columns:
        files=[]
        for row in db.execute(f'SELECT id,file FROM "{table}"'):
            name=row['file'] or '';path=(root/'backend/media'/name).resolve()
            safe=path.is_relative_to((root/'backend/media').resolve())
            entry={'id':row['id'],'path':name,'local_present':bool(name and safe and path.is_file())}
            if entry['local_present']:
                entry.update(bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest())
                if zipfile.is_zipfile(path):
                    with zipfile.ZipFile(path) as z:entry.update(zip_entries=len(z.infolist()),zip_crc_error=z.testzip())
            files.append(entry)
        item['files']=files
    summary[table]=item
unit_columns={r[1] for r in db.execute('PRAGMA table_info(learning_learningunit)')}
selected=[c for c in ['id','slug','title_fr','title','is_active'] if c in unit_columns]
units=[dict(r) for r in db.execute('SELECT '+','.join(selected)+' FROM learning_learningunit')]
placeholder=db.execute("SELECT COUNT(*) FROM vocabulary_word WHERE validation_status='published' AND lower(french_translation) LIKE '%exemple test%'").fetchone()[0]
db.close();assert hashlib.sha256(source.read_bytes()).hexdigest()==before
result={'source_sha256':before,'opened_read_only':True,'tables':summary,'units':units,'published_word_placeholder_warning_count':placeholder,
 'not_proven':['human linguistic validation','speaker recording consent','audio perceptual quality','remote object existence','tracks pedagogically complete']}
(Path(__file__).parent/'INVENTORY.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v['count'] for k,v in summary.items()}))
