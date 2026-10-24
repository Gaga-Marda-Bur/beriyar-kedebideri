"""Statistiques agrégées de la copie SQLite locale, ouverte en lecture seule."""
import json
import sqlite3
from pathlib import Path

path = Path(__file__).resolve().parents[1] / "backend" / "db.sqlite3"
db = sqlite3.connect(path.as_uri() + "?mode=ro", uri=True)
tables = [
    "alphabet_character", "vocabulary_word", "learning_learningtheme",
    "learning_learningunit", "lessons_lesson", "quizzes_quizquestion",
    "offline_packs_lessonpack", "no_ena_noenapublication", "audio_assets_audioasset",
]
result = {
    "scope": "Copie SQLite locale uniquement, pas la production",
    "counts": {table: db.execute("SELECT COUNT(*) FROM " + table).fetchone()[0]
               for table in tables},
    "integrity": db.execute("PRAGMA integrity_check").fetchone()[0],
    "foreign_key_violations": len(db.execute("PRAGMA foreign_key_check").fetchall()),
    "words_missing_translation": dict(zip(["fr", "en", "ar"], db.execute(
        "SELECT SUM(french_translation=''),SUM(english_translation=''),"
        "SUM(arabic_translation='') FROM vocabulary_word"
    ).fetchone())),
    "characters_missing_audio_link": db.execute(
        "SELECT COUNT(*) FROM alphabet_character c WHERE NOT EXISTS "
        "(SELECT 1 FROM alphabet_characteraudio a WHERE a.character_id=c.id)"
    ).fetchone()[0],
    "characters_ipa_to_validate": db.execute(
        "SELECT COUNT(*) FROM alphabet_character WHERE phoneme_ipa='À_VALIDER'"
    ).fetchone()[0],
}
db.close()
print(json.dumps(result, ensure_ascii=False, indent=2))
