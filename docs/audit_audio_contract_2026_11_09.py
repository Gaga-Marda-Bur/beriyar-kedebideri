"""Synthetic audio export probes; memory DB, no media creation or production access."""
import json
import os
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'backend'))
os.environ.update(DJANGO_SETTINGS_MODULE='config.settings', DJANGO_ENV='test',
    DATABASE_URL='sqlite:///:memory:', USE_R2='False', DEBUG='False',
    SECRET_KEY='isolated-audio-audit-not-a-production-key')
import django
django.setup()
from django.conf import settings
from django.core.management import call_command
from learning.models import LearningTheme, LearningUnit
from lessons.models import Lesson
from quizzes.models import QuizQuestion, QuizQuestionAudio
from audio_assets.models import AudioAsset
from audio_assets.utils import get_linked_audio_file
from offline_packs.models import LessonPack
from offline_packs.services.offline_pack_generator import OfflinePackGenerator
assert settings.DATABASES['default']['NAME'] == ':memory:'
call_command('migrate', verbosity=0, interactive=False)
t = LearningTheme.objects.create(slug='audio-audit', title_fr='Audit', status='published')
u = LearningUnit.objects.create(theme=t, slug='audio-audit', title_fr='Audit', status='published')
l = Lesson.objects.create(unit=u, slug='audio-audit', title_fr='Audit', status='published')
p = LessonPack.objects.create(slug='audio-audit', title_fr='Audit', status='published')
p.lessons.add(l)
g = OfflinePackGenerator(p)
output = {}
try:
    g._serialize_lessons(ROOT / 'docs')
    output['lesson_export'] = 'no error'
except Exception as error:
    output['lesson_export'] = {'error': type(error).__name__, 'detail': str(error)}
q = QuizQuestion.objects.create(unit=u, question_type='multiple_choice', prompt_fr='Audit', status='published')
a = AudioAsset.objects.create(file='audio/audit.mp3', audio_type='quiz_prompt', validation_status='published')
QuizQuestionAudio.objects.create(question=q, audio_asset=a, role='question')
output['quiz_question_role_resolves'] = bool(get_linked_audio_file(q, role='question'))
output['quiz_export_normal_role_resolves'] = bool(get_linked_audio_file(q, role='normal'))
out = json.dumps(output, ensure_ascii=False, indent=2)
(ROOT / 'docs/audit_audio_contract_2026_11_09_results.json').write_text(out + '\n', encoding='utf-8')
print(out)
