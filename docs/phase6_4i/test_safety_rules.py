import sqlite3
from pathlib import Path
from django.core.exceptions import ValidationError

root = Path(__file__).resolve().parents[2]
db_path = root / 'backend' / 'db.sqlite3'

def run_pedagogical_safety_checks():
    conn = sqlite3.connect(f'file:{db_path.as_posix()}?mode=ro', uri=True)
    cur = conn.cursor()
    
    findings = []
    
    # 1. Check for placeholders in published characters
    cur.execute("SELECT id, unicode_code, phoneme_ipa, validation_status FROM alphabet_character WHERE validation_status = 'published'")
    pub_chars = cur.fetchall()
    for c in pub_chars:
        if c[2] == 'À_VALIDER':
            findings.append(f"[SAFETY_VIOLATION] Published character {c[1]} has placeholder IPA 'À_VALIDER'")
            
    # 2. Check for placeholders in published words
    cur.execute("SELECT id, beriya_text, french_translation, validation_status FROM vocabulary_word WHERE validation_status = 'published'")
    pub_words = cur.fetchall()
    for w in pub_words:
        if 'test' in w[2].lower() or 'exemple' in w[2].lower():
            findings.append(f"[SAFETY_VIOLATION] Published word #{w[0]} '{w[1]}' contains test/placeholder translation: '{w[2]}'")
            
    # 3. Check for published units depending on unvalidated characters
    cur.execute('''
        SELECT lu.id, lu.slug, c.unicode_code, c.validation_status
        FROM learning_learningunit lu
        JOIN learning_learningunit_characters luc ON lu.id = luc.learningunit_id
        JOIN alphabet_character c ON luc.character_id = c.id
        WHERE lu.status = 'published' AND c.validation_status != 'published'
    ''')
    dep_violations = cur.fetchall()
    for dv in dep_violations:
        findings.append(f"[DEPENDENCY_VIOLATION] Published Unit #{dv[0]} ({dv[1]}) references unvalidated character {dv[2]} (status={dv[3]})")
        
    # 4. Check for published units depending on draft words
    cur.execute('''
        SELECT lu.id, lu.slug, w.latin_transcription, w.validation_status
        FROM learning_learningunit lu
        JOIN learning_learningunit_words luw ON lu.id = luw.learningunit_id
        JOIN vocabulary_word w ON luw.word_id = w.id
        WHERE lu.status = 'published' AND w.validation_status != 'published'
    ''')
    word_dep_violations = cur.fetchall()
    for wdv in word_dep_violations:
        findings.append(f"[DEPENDENCY_VIOLATION] Published Unit #{wdv[0]} ({wdv[1]}) references unvalidated word '{wdv[2]}' (status={wdv[3]})")
        
    # 5. Check for duplicate audios inside offline pack
    import zipfile, hashlib
    pack_path = root / 'backend' / 'media' / 'offline_packs' / 'files' / 'starter-beriya-erfe_v1_iMr8Evw.zip'
    if pack_path.exists():
        with zipfile.ZipFile(pack_path) as z:
            audio_hashes = {}
            for n in z.namelist():
                if n.startswith('audio/') and n.endswith('.wav'):
                    data = z.read(n)
                    h = hashlib.sha256(data).hexdigest()
                    audio_hashes.setdefault(h, []).append(n)
            for h, entries in audio_hashes.items():
                if len(entries) > 1:
                    findings.append(f"[PACK_DUPLICATE_AUDIO] Pack contains {len(entries)} audio files with identical content (sha256={h[:12]}): {entries}")

    conn.close()
    return findings

if __name__ == '__main__':
    results = run_pedagogical_safety_checks()
    print(f"Safety checks executed. Total findings: {len(results)}")
    for r in results:
        print(f" - {r}")
