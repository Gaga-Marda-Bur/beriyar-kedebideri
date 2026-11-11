import sqlite3
import csv
from pathlib import Path

root = Path(__file__).resolve().parents[2]
db_path = root / 'backend' / 'db.sqlite3'

conn = sqlite3.connect(f'file:{db_path.as_posix()}?mode=ro', uri=True)
cur = conn.cursor()

# Fetch audio asset map
cur.execute('''
    SELECT wa.word_id, aa.title, aa.file, aa.validation_status
    FROM vocabulary_wordaudio wa
    JOIN audio_assets_audioasset aa ON wa.audio_asset_id = aa.id
''')
word_audio_map = {r[0]: {'file': r[2], 'title': r[1], 'status': r[3]} for r in cur.fetchall()}

cur.execute('''
    SELECT id, beriya_text, latin_transcription, french_translation, english_translation, 
           arabic_translation, oral_prompt, validation_status, is_active
    FROM vocabulary_word
    ORDER BY id
''')
words = cur.fetchall()

headers = [
    'Identifiant (ID)',
    'Texte Erfe',
    'Transcription Latine',
    'Traduction Francaise Actuelle',
    'Traduction Anglaise Actuelle',
    'Traduction Arabe Actuelle',
    'Prompt Oral Existant',
    'Audio Associe',
    'Statut Actuel',
    'Anomalie / Diagnostic',
    'Validation Traduction FR (Humaine)',
    'Validation Traduction EN (Humaine)',
    'Validation Traduction AR (Humaine)',
    'Statut Propose',
    'Commentaire'
]

rows = []
for w in words:
    wid, erfe, latin, fr, en, ar, prompt, status, active = w
    audio = word_audio_map.get(wid)
    audio_str = f"{audio['title']} ({audio['file']}) [{audio['status']}]" if audio else 'Aucun'
    
    issues = []
    if 'test' in fr.lower() or 'exemple' in fr.lower():
        issues.append('Libellé de test provisoire détecté')
    if len(erfe) == 1 and wid == 1:
        issues.append('Texte Erfe identique à la lettre U+16EA0 unique')
    if not audio:
        issues.append('Aucun enregistrement vocal disponible')
    if status == 'draft':
        issues.append('En attente de validation éditoriale pour publication')
        
    issue_str = '; '.join(issues)
    
    rows.append([
        wid,
        erfe,
        latin,
        fr,
        en,
        ar,
        prompt,
        audio_str,
        status,
        issue_str,
        '', # FR valide
        '', # EN valide
        '', # AR valide
        '', # Statut propose
        ''  # Commentaire
    ])

csv_path = root / 'docs' / 'phase6_4i' / 'validation_lexicale_mots.csv'
with open(csv_path, 'w', newline='', encoding='utf-8-sig') as f:
    writer = csv.writer(f)
    writer.writerow(headers)
    writer.writerows(rows)

print(f'CSV exported: {len(rows)} words written to {csv_path}')
