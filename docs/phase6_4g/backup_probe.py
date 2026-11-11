"""Local dump/restore smoke probe; NOT a production or full BK recovery claim."""
import hashlib,json,shutil,subprocess
from pathlib import Path
import psycopg2
folder=Path(__file__).resolve().parent;root=folder.parents[1]
pg=Path('C:/Program Files/PostgreSQL/17/bin')
params=dict(host='127.0.0.1',port=55464,user='bk_simulation')
admin=psycopg2.connect(dbname='bk64b_recette',**params);admin.autocommit=True
names=['bk64g_backup_source','bk64g_backup_restored']
with admin.cursor() as c:
    for name in names:
        c.execute('SELECT 1 FROM pg_database WHERE datname=%s',[name]);assert c.fetchone() is None,'Refuse overwrite'
        c.execute('CREATE DATABASE '+name)
source=psycopg2.connect(dbname=names[0],**params)
with source,source.cursor() as c:
    c.execute('CREATE TABLE qa_progress (owner_code text PRIMARY KEY, score integer)')
    c.execute("INSERT INTO qa_progress VALUES ('SYNTHETIC-A',7),('SYNTHETIC-B',0)")
source.close()
dump=folder/'runtime/backup.dump'
subprocess.run([str(pg/'pg_dump.exe'),'-h','127.0.0.1','-p','55464','-U','bk_simulation','-Fc','-f',str(dump),names[0]],check=True)
subprocess.run([str(pg/'pg_restore.exe'),'-h','127.0.0.1','-p','55464','-U','bk_simulation','--exit-on-error','-d',names[1],str(dump)],check=True)
restored=psycopg2.connect(dbname=names[1],**params)
with restored.cursor() as c:c.execute('SELECT * FROM qa_progress ORDER BY owner_code');rows=c.fetchall()
restored.close();assert rows==[('SYNTHETIC-A',7),('SYNTHETIC-B',0)]
audio=root/'backend/media/audio_assets/files/arkap.wav'
target=folder/'runtime/restored_audio.wav';shutil.copyfile(audio,target)
hashfile=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert hashfile(audio)==hashfile(target)
with admin.cursor() as c:
    for name in names:c.execute('DROP DATABASE '+name)
admin.close()
result={'scope':'synthetic PostgreSQL utility smoke test, not full BK restoration',
 'postgres_local_port':55464,'dump_sha256':hashfile(dump),'synthetic_rows_restored':len(rows),
 'audio_byte_copy_sha256':hashfile(target),'audio_copy_equal':True,'own_test_databases_removed':True,
 'not_verified':['real staging role','remote backup encryption/retention','full BK database plus object storage atomicity','actual staging restoration']}
(folder/'BACKUP_PROBE.json').write_text(json.dumps(result,indent=2)+'\n')
print('Local synthetic dump/restore and audio byte-copy verified; no source overwritten.')
