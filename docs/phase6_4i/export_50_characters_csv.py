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
    'Nom Descriptif FR',
    'Transcription Latine (Grapheme)',
    'Phoneme IPA Existant',
    'Type Linguistique',
    'Enregistrement Audio',
    'Statut Editorial Actuel',
    'Provenance Technique Initiale',
    'Diagnostic & Anomalies',
    'Validation Transcription Latine (Humaine)',
    'Validation Phoneme IPA (Humaine)',
    'Validation Nom FR (Humaine)',
    'Statut Editorial Propose',
    'Commentaires & Observations'
]

rows = []
for c in characters:
    cid, ucode, sym, order, latin, ipa, ctype, name_fr, status, active, offline = c
    audio_info = char_audio_map.get(cid)
    audio_str = f"{audio_info['title']} ({audio_info['file']}) [{audio_info['status']}]" if audio_info else 'Aucun'
    
    # Provenance
    if cid in (1, 2, 3, 4, 22):
        prov = "seed_learning_core.py (Enrichissement methodologique Lot 4B)"
    else:
        prov = "seed_beriya_erfe_characters.py (Injection brute Unicode 2026-06)"
        
    # Diagnostics
    issues = []
    if status == 'published' and not audio_info:
        issues.append("Publié sans audio associé")
    if ipa == 'À_VALIDER':
        issues.append("Placeholder IPA 'À_VALIDER' non resolu (1 sur 45)")
    if not latin:
        issues.append("Transcription latine absente")
    if not audio_info:
        issues.append("Aucun audio rattaché")
    if not name_fr:
        issues.append("Nom descriptif français manquant")
        
    issue_str = '; '.join(issues) if issues else 'Données existantes complètes'
    
    rows.append([
        cid,
        ucode,
        sym,
        order,
        name_fr if name_fr else '(Non renseigne)',
        latin if latin else '(Non renseigne)',
        ipa if ipa else '(Non renseigne)',
        ctype,
        audio_str,
        status,
        prov,
        issue_str,
        '', # Val latine
        '', # Val IPA
        '', # Val Nom FR
        '', # Statut propose
        ''  # Commentaire
    ])

csv_path = root / 'docs' / 'phase6_4i' / 'validation_50_caracteres_erfe.csv'
with open(csv_path, 'w', newline='', encoding='utf-8-sig') as f:
    writer = csv.writer(f)
    writer.writerow(headers)
    writer.writerows(rows)

print(f'CSV exported: {len(rows)} characters written to {csv_path}')
