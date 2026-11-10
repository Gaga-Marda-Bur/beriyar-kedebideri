"""Read-only audio inventory; no Django settings, network or media writes."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import sqlite3
import wave

ROOT = Path(__file__).resolve().parents[1]
MEDIA = (ROOT / 'backend/media').resolve()
DB = ROOT / 'backend/db.sqlite3'

def digest(path):
    sha = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            sha.update(chunk)
    return sha.hexdigest()

before = digest(DB)
db = sqlite3.connect(DB.as_uri() + '?mode=ro', uri=True)
db.row_factory = sqlite3.Row
assets = [dict(row) for row in db.execute('SELECT * FROM audio_assets_audioasset')]
asset_by_id = {a['id']: a for a in assets}
result = {'scope': 'Local SQLite read-only; no production access or perceptual audio assessment'}
result['metadata_filled'] = {field: sum(a[field] is not None and str(a[field]).strip() != '' for a in assets)
    for field in ('speaker_name', 'dialect_region', 'mime_type', 'duration_ms', 'transcript', 'recording_quality')}
result['asset_counts'] = {field: dict(Counter(str(a[field]) for a in assets))
    for field in ('audio_type', 'speed', 'validation_status', 'available_offline')}
result['dedicated_rights_fields'] = [col[1] for col in db.execute('PRAGMA table_info(audio_assets_audioasset)')
    if any(term in col[1].lower() for term in ('licen', 'consent', 'right', 'copyright'))]
result['assets'] = []
for a in assets:
    path = (MEDIA / a['file']).resolve()
    safe = path.is_relative_to(MEDIA)
    exists = safe and path.is_file()
    head = path.open('rb').read(16) if exists else b''
    result['assets'].append({'id': a['id'], 'file': a['file'], 'exists_locally': exists,
        'bytes': path.stat().st_size if exists else None, 'sha256': digest(path) if exists else None,
        'header_hex': head.hex(), 'metadata_duration_ms': a['duration_ms'],
        'notes_present': bool(a['notes'].strip())})
    if exists and path.suffix.lower() == '.wav':
        try:
            with wave.open(str(path), 'rb') as wav:
                result['assets'][-1]['wav_technical'] = {
                    'channels': wav.getnchannels(), 'sample_rate_hz': wav.getframerate(),
                    'sample_width_bytes': wav.getsampwidth(),
                    'duration_seconds': round(wav.getnframes() / wav.getframerate(), 3)}
        except (wave.Error, EOFError) as error:
            result['assets'][-1]['wav_error'] = type(error).__name__

links = {}
for name, table, fk in [('characters', 'alphabet_characteraudio', 'character_id'),
                         ('words', 'vocabulary_wordaudio', 'word_id'),
                         ('lesson_items', 'lessons_lessonitemaudio', 'lesson_item_id'),
                         ('quiz_questions', 'quizzes_quizquestionaudio', 'question_id')]:
    rows = [dict(r) for r in db.execute('SELECT * FROM ' + table)]
    links[name] = rows
    result.setdefault('links', {})[name] = {'total': len(rows),
        'roles': dict(Counter(r['role'] for r in rows)),
        'published_file_reference': sum(asset_by_id[r['audio_asset_id']]['validation_status'] == 'published'
            and bool(asset_by_id[r['audio_asset_id']]['file']) for r in rows)}

def covered(kind, entity_id):
    key = {'characters': 'character_id', 'words': 'word_id', 'lesson_items': 'lesson_item_id'}[kind]
    return any(r[key] == entity_id and asset_by_id[r['audio_asset_id']]['validation_status'] == 'published'
        and asset_by_id[r['audio_asset_id']]['file'] for r in links[kind])

result['units'] = []
for u in db.execute('SELECT id,status,target_word_id FROM learning_learningunit'):
    chars = [r[0] for r in db.execute('SELECT character_id FROM learning_learningunit_characters WHERE learningunit_id=?', (u['id'],))]
    words = set(r[0] for r in db.execute('SELECT word_id FROM learning_learningunit_words WHERE learningunit_id=?', (u['id'],)))
    if u['target_word_id']:
        words.add(u['target_word_id'])
    result['units'].append({'id': u['id'], 'status': u['status'], 'characters_selected': len(chars),
        'characters_with_any_published_audio_reference': sum(covered('characters', c) for c in chars),
        'words_selected_or_targeted': len(words),
        'words_with_any_published_audio_reference': sum(covered('words', w) for w in words)})
result['lessons'] = []
for lesson in db.execute('SELECT id,status FROM lessons_lesson'):
    items = list(db.execute('SELECT id,character_id,word_id FROM lessons_lessonitem WHERE lesson_id=?', (lesson['id'],)))
    count = sum(covered('lesson_items', i['id']) or covered('characters', i['character_id'])
        or covered('words', i['word_id']) for i in items)
    result['lessons'].append({'id': lesson['id'], 'status': lesson['status'], 'items': len(items),
        'items_with_any_direct_or_related_published_audio_reference': count})
result['no_ena'] = {'publications': db.execute('SELECT COUNT(*) FROM no_ena_noenapublication').fetchone()[0],
    'with_video_reference': db.execute("SELECT COUNT(*) FROM no_ena_noenapublication WHERE video_file<>''").fetchone()[0],
    'with_audio_reference': db.execute('SELECT COUNT(*) FROM no_ena_noenapublication WHERE primary_audio_asset_id IS NOT NULL').fetchone()[0]}
known = {a['file'] for a in assets}
files = []
for base in (MEDIA, ROOT / 'media_samples'):
    for path in base.rglob('*') if base.exists() else []:
        if path.is_file() and path.suffix.lower() in ('.mp3', '.m4a', '.wav', '.ogg', '.aac', '.flac', '.mp4', '.webm'):
            files.append({'path': path.relative_to(ROOT).as_posix(), 'bytes': path.stat().st_size,
                'referenced_by_audioasset': path.is_relative_to(MEDIA) and path.relative_to(MEDIA).as_posix() in known})
result['media_files'] = files
result['note'] = 'Unreferenced by AudioAsset is not proof of orphan status: ZIP exports, No Ena and external uses may exist.'
db.close()
result['db_sha256_before'] = before
result['db_sha256_after'] = digest(DB)
assert result['db_sha256_before'] == result['db_sha256_after']
out = json.dumps(result, ensure_ascii=False, indent=2)
(ROOT / 'docs/audit_audio_2026_11_09_results.json').write_text(out + '\n', encoding='utf-8')
print(out)
