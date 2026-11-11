import sqlite3
import csv
from pathlib import Path

root = Path(__file__).resolve().parents[2]
db_path = root / 'backend' / 'db.sqlite3'

conn = sqlite3.connect(f'file:{db_path.as_posix()}?mode=ro', uri=True)
cur = conn.cursor()

# 1. Fetch character audio map
cur.execute('''
    SELECT ca.character_id, aa.file, aa.title, aa.validation_status
    FROM alphabet_characteraudio ca
    JOIN audio_assets_audioasset aa ON ca.audio_asset_id = aa.id
''')
char_audio_map = {r[0]: {'file': r[1], 'title': r[2], 'status': r[3]} for r in cur.fetchall()}

# 2. Fetch all characters
cur.execute('''
    SELECT id, unicode_code, symbol, order_index, latin_grapheme, phoneme_ipa, 
           character_type, name_fr, validation_status, is_active, available_offline
    FROM alphabet_character
    ORDER BY order_index
''')
characters = cur.fetchall()

headers = [
    'Identifiant (ID)',
    'Code Unicode',
    'Glyphe Erfe',
    'Ordre Canonique',
    'Transcription Latine Existante',
    'Phoneme IPA Existant',
    'Type (Voyelle/Consonne)',
    'Nom FR Existant',
    'Reference Audio Existante',
    'Statut Actuel',
    'Probleme Eventuel Identifie',
    'Decision Humaine Requise',
    'Commentaire Editorial',
    'Statut de Publication Propose'
]

rows = []
for c in characters:
    cid, ucode, sym, order, latin, ipa, ctype, name_fr, status, active, offline = c
    audio_info = char_audio_map.get(cid)
    audio_str = f"{audio_info['title']} ({audio_info['file']}) [{audio_info['status']}]" if audio_info else 'Aucun'
    
    # Identify issues
    issues = []
    if status == 'published' and not latin:
        issues.append('Publié mais sans transcription latine explicite')
    if status == 'review':
        if not latin:
            issues.append('Transcription latine non renseignee')
        if ipa == 'À_VALIDER' or not ipa:
            issues.append('Phoneme IPA placeholder ou manquant')
        if not audio_info:
            issues.append('Enregistrement audio manquant')
        if not name_fr:
            issues.append('Nom descriptif francais manquant')
            
    issue_str = '; '.join(issues) if issues else 'Aucun probleme technique apparent'
    
    rows.append([
        cid,
        ucode,
        sym,
        order,
        latin,
        ipa,
        ctype,
        name_fr,
        audio_str,
        status,
        issue_str,
        '', # Decision humaine (a remplir par le linguiste)
        '', # Commentaire (a remplir par le linguiste)
        ''  # Statut propose (a remplir par le linguiste)
    ])

csv_path = root / 'docs' / 'phase6_4h' / 'validation_linguistique_erfe.csv'
with open(csv_path, 'w', newline='', encoding='utf-8-sig') as f:
    writer = csv.writer(f)
    writer.writerow(headers)
    writer.writerows(rows)

print(f'CSV exported: {len(rows)} characters written to {csv_path}')
