import django, os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from alphabet.models import Character, CharacterAudio
from vocabulary.models import Word, WordAudio
from learning.models import LearningTheme, LearningUnit
from lessons.models import Lesson, LessonItem
from quizzes.models import QuizQuestion, QuizOption
from offline_packs.models import LessonPack
from audio_assets.models import AudioAsset

print("=== AUDIT RAPPORT AUTOMATIQUE DES DONNEES ===\n")

# 1. Characters
total_chars = Character.objects.count()
active_chars = Character.objects.filter(is_active=True).count()
chars_with_audio = Character.objects.filter(audio_links__isnull=False).distinct().count()
chars_a_valider = Character.objects.filter(phoneme_ipa='À_VALIDER').count()
print(f"[CHARACTERS] Total: {total_chars} | Actifs: {active_chars} | Avec Audio: {chars_with_audio} | IPA A_VALIDER: {chars_a_valider}")
if chars_with_audio < total_chars:
    print(f"  -> WARNING: {total_chars - chars_with_audio} caracteres sans aucun lien audio!")

# 2. Words
total_words = Word.objects.count()
words_with_audio = Word.objects.filter(audio_links__isnull=False).distinct().count()
words_missing_fr = Word.objects.filter(french_translation='').count()
words_missing_ar = Word.objects.filter(arabic_translation='').count()
words_missing_en = Word.objects.filter(english_translation='').count()
print(f"\n[WORDS] Total: {total_words} | Avec Audio: {words_with_audio}")
print(f"  Traductions manquantes -> FR: {words_missing_fr}, AR: {words_missing_ar}, EN: {words_missing_en}")
for w in Word.objects.all():
    print(f"   * Word #{w.id}: {w.beriya_text} (latin: {w.latin_transcription}, ar_transcription: {w.arabic_transcription}) -> FR: \"{w.french_translation}\", AR: \"{w.arabic_translation}\", EN: \"{w.english_translation}\"")

# 3. Learning Units & core_flow
total_units = LearningUnit.objects.count()
print(f"\n[UNITS] Total: {total_units}")
for u in LearningUnit.objects.all():
    flow = u.core_flow
    print(f"   * Unit #{u.id} [{u.slug}]: \"{u.title_fr}\" | Chars: {u.characters.count()} | Words: {u.words.count()} | Flow steps: {len(flow)}")
    if len(flow) == 0:
        print(f"     -> WARNING: Unit #{u.id} a un core_flow vide!")

# 4. Quizzes
total_questions = QuizQuestion.objects.count()
print(f"\n[QUIZZES] Total Questions: {total_questions}")
for q in QuizQuestion.objects.all():
    print(f"   * Q#{q.id} type={q.question_type} prompt=\"{q.prompt_fr}\" options={q.options.count()}")

# 5. Offline Packs
print(f"\n[PACKS] Total Packs: {LessonPack.objects.count()}")
for p in LessonPack.objects.all():
    file_exists = os.path.exists(p.file.path) if p.file else False
    print(f"   * Pack #{p.id} [{p.slug}] v{p.version} | Fichier sur disque: {file_exists} ({p.size_mb} MB)")

print("\n=== FIN DU RAPPORT ===")
