import json
import tempfile
from io import StringIO
from pathlib import Path

from django.core.management import call_command
from django.test import TestCase

from alphabet.models import Character
from learning.models import LearningTheme, LearningUnit
from lessons.models import Lesson, LessonItem
from quizzes.models import QuizOption, QuizQuestion
from vocabulary.models import Word


class ImportPreprodCoursesTests(TestCase):
    def test_dry_run_does_not_persist_changes(self):
        out = StringIO()
        call_command('import_preprod_courses', '--dry-run', stdout=out)
        output = out.getvalue()

        self.assertIn('DRY-RUN', output)
        self.assertIn('rejected=0', output)
        self.assertEqual(LearningTheme.objects.count(), 0)
        self.assertEqual(LearningUnit.objects.count(), 0)
        self.assertEqual(Lesson.objects.count(), 0)
        self.assertEqual(LessonItem.objects.count(), 0)
        self.assertEqual(QuizQuestion.objects.count(), 0)

    def test_import_all_preprod_courses_as_draft_and_idempotent(self):
        out1 = StringIO()
        call_command('import_preprod_courses', stdout=out1)
        output1 = out1.getvalue()

        self.assertIn('IMPORT RÉEL', output1)
        self.assertIn('rejected=0', output1)

        self.assertEqual(LearningTheme.objects.count(), 3)
        self.assertEqual(LearningUnit.objects.count(), 14)
        self.assertEqual(Lesson.objects.count(), 14)
        self.assertEqual(Character.objects.count(), 25)
        self.assertEqual(Word.objects.count(), 48)  # 30 phrases + 18 lexemes
        self.assertEqual(LessonItem.objects.count(), 73)
        self.assertEqual(QuizQuestion.objects.count(), 219)
        self.assertEqual(QuizOption.objects.count(), 584)  # 73*4 MCQ + 73*4 listen_select

        # Aucune publication automatique
        self.assertEqual(LearningTheme.objects.filter(status=LearningTheme.PUBLISHED).count(), 0)
        self.assertEqual(LearningUnit.objects.filter(status=LearningUnit.PUBLISHED).count(), 0)
        self.assertEqual(Lesson.objects.filter(status=Lesson.PUBLISHED).count(), 0)
        self.assertEqual(QuizQuestion.objects.filter(status=QuizQuestion.PUBLISHED).count(), 0)
        self.assertEqual(QuizQuestion.objects.filter(is_active=True).count(), 0)

        # Idempotence : second import sans doublons
        out2 = StringIO()
        call_command('import_preprod_courses', stdout=out2)
        output2 = out2.getvalue()

        self.assertIn('created=0', output2)
        self.assertIn('rejected=0', output2)
        self.assertEqual(LearningUnit.objects.count(), 14)
        self.assertEqual(LessonItem.objects.count(), 73)
        self.assertEqual(QuizQuestion.objects.count(), 219)

    def test_human_edits_are_protected_on_reimport(self):
        call_command('import_preprod_courses', '--tracks', 'ALPHABET_ERFE', stdout=StringIO())
        unit = LearningUnit.objects.get(slug='bk-preprod-erf-01')
        unit.title_fr = 'Titre validé par linguiste'
        unit.status = LearningUnit.VALIDATED
        unit.pedagogy_config = {**(unit.pedagogy_config or {}), 'human_edited': True}
        unit.save()

        out = StringIO()
        call_command('import_preprod_courses', '--tracks', 'ALPHABET_ERFE', stdout=out)
        unit.refresh_from_db()

        self.assertEqual(unit.title_fr, 'Titre validé par linguiste')
        self.assertEqual(unit.status, LearningUnit.VALIDATED)
        self.assertIn('skipped_protected=', out.getvalue())

    def test_rejects_public_enabled_without_audio(self):
        invalid_pack = {
            'package_id': 'INVALID_TEST',
            'lessons': [
                {
                    'id': 'BAD-01',
                    'track': 'ALPHABET_ERFE',
                    'title': 'Leçon invalide',
                    'level': 'A0',
                    'public_enabled': True,
                    'items': [],
                }
            ],
            'exercises': [],
        }
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / 'invalid.json'
            p.write_text(json.dumps(invalid_pack), encoding='utf-8')
            out = StringIO()
            call_command('import_preprod_courses', '--file', str(p), stdout=out)
            self.assertIn('rejected=1', out.getvalue())
            self.assertEqual(LearningUnit.objects.count(), 0)
