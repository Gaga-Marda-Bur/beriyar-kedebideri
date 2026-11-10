"""Audio export contracts, using synthetic silence (no linguistic content)."""
import hashlib
import io
import json
import os
from pathlib import Path
import wave
import zipfile

from django.core.files.base import ContentFile
from django.test import TestCase

from audio_assets.models import AudioAsset
from learning.models import LearningTheme, LearningUnit
from lessons.models import Lesson, LessonItem, LessonItemAudio
from lessons.serializers import LessonSerializer
from quizzes.models import QuizQuestion, QuizOption, QuizQuestionAudio
from quizzes.serializers import QuizQuestionSerializer
from offline_packs.models import LessonPack
from offline_packs.services.offline_pack_generator import OfflinePackGenerator


class AudioExportContractTests(TestCase):
    def setUp(self):
        self.theme = LearningTheme.objects.create(slug='audio-contract', title_fr='Test', status='published')
        self.unit = LearningUnit.objects.create(theme=self.theme, slug='audio-contract', title_fr='Test', status='published')
        self.pack = LessonPack.objects.create(slug='audio-contract', title_fr='Test', status='published')
        self.pack.units.add(self.unit)

    def audio(self, role, status='published', missing=False):
        frames = 80 + sum(role.encode('utf-8'))
        content = io.BytesIO()
        with wave.open(content, 'wb') as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(8000)
            wav.writeframes(b'\x00\x00' * frames)
        return AudioAsset.objects.create(
            file=f'not-present/{role}.wav' if missing else ContentFile(content.getvalue(), name=f'{role}.wav'),
            title=f'Synthetic silence {role}', audio_type='lesson_prompt', mime_type='audio/wav',
            duration_ms=frames * 1000 // 8000, dialect_region='test-only', validation_status=status)

    def export(self):
        pack = OfflinePackGenerator(self.pack).generate()
        with pack.file.open('rb') as stream:
            data = stream.read()
        self.assertEqual(pack.checksum, hashlib.sha256(data).hexdigest())
        self.assertEqual(pack.size_mb, round(len(data) / (1024 * 1024), 2))
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            self.assertIsNone(archive.testzip())
            manifest = json.loads(archive.read('metadata.json'))
            for name in manifest['media_files']:
                self.assertIn(name, archive.namelist())
                self.assertGreater(len(archive.read(name)), 0)
            return data, {name: json.loads(archive.read(f'{name}.json')) for name in ('lessons', 'quizzes')}, archive.namelist()

    def lesson(self):
        lesson = Lesson.objects.create(unit=self.unit, slug='audio-lesson', title_fr='Test',
            oral_intro_fr='Instruction test', estimated_minutes=4, status='published')
        item = LessonItem.objects.create(lesson=lesson, item_type='audio_only',
            title_fr='Item test', writing_hint_fr='Indice test', repeat_count=3)
        self.pack.lessons.add(lesson)
        return lesson, item

    def test_complete_lesson_export_keeps_real_fields_and_all_item_audio_roles(self):
        lesson, item = self.lesson()
        audio_by_role = {}
        for role, _ in LessonItemAudio.ROLE_CHOICES:
            audio_by_role[role] = self.audio(role)
            LessonItemAudio.objects.create(lesson_item=item, audio_asset=audio_by_role[role], role=role)
        original_metadata = list(AudioAsset.objects.order_by('id').values())
        data, payload, names = self.export()
        self.assertEqual(list(AudioAsset.objects.order_by('id').values()), original_metadata)
        exported = payload['lessons'][0]
        online = LessonSerializer(lesson).data
        for key in ('id', 'slug', 'title_fr', 'oral_intro_fr', 'estimated_minutes', 'items_count'):
            self.assertEqual(exported[key], online[key])
        self.assertIsNone(exported['intro_audio_url'])
        self.assertIsNone(exported['cover_image_url'])
        out = exported['items'][0]
        for key in ('lesson', 'title_fr', 'writing_hint_fr', 'repeat_count', 'is_active', 'available_offline'):
            self.assertEqual(out[key], online['items'][0][key])
        for role, key in [('normal', 'audio_url'), ('slow', 'slow_audio_url'),
                          ('prompt', 'prompt_audio_url'), ('explanation', 'explanation_audio_url')]:
            self.assertIn(out[key], names)
            with zipfile.ZipFile(io.BytesIO(data)) as archive, audio_by_role[role].file.open('rb') as source:
                self.assertEqual(archive.read(out[key]), source.read())
        self.assertEqual(out['audio'], out['audio_url'])
        self.assertEqual(out['writing_hint'], out['writing_hint_fr'])

    def test_all_quiz_types_export_the_question_role_and_canonical_flutter_keys(self):
        for index, (kind, _) in enumerate(QuizQuestion.QUESTION_TYPE_CHOICES):
            with self.subTest(kind=kind):
                question = QuizQuestion.objects.create(unit=self.unit, question_type=kind,
                    prompt_fr=f'Question test {index}', correct_text_answer='test', status='published')
                QuizOption.objects.create(question=question, text_fr='test 1', is_correct=False, order_index=0)
                QuizOption.objects.create(question=question, text_fr='test 2', is_correct=True, order_index=1)
                for role, _ in QuizQuestionAudio.ROLE_CHOICES:
                    QuizQuestionAudio.objects.create(question=question, role=role, audio_asset=self.audio(role))
                self.pack.quiz_questions.add(question)
        data, payload, names = self.export()
        for exported, question in zip(payload['quizzes'], self.pack.quiz_questions.order_by('difficulty', 'order_index', 'id')):
            self.assertIsNotNone(exported['audio_url'])
            online = QuizQuestionSerializer(question).data
            for key in ('question_type', 'prompt_text_fr', 'correct_text_answer', 'correct_index', 'is_active'):
                self.assertEqual(exported[key], online[key])
            for key in ('question_audio_url', 'question_slow_audio_url', 'explanation_audio_url', 'correction_audio_url'):
                self.assertIn(exported[key], names)
            for role, key in [('question', 'question_audio_url'), ('slow_question', 'question_slow_audio_url'),
                              ('explanation', 'explanation_audio_url'), ('correction', 'correction_audio_url')]:
                source = question.audio_links.get(role=role).audio_asset
                with zipfile.ZipFile(io.BytesIO(data)) as archive, source.file.open('rb') as audio:
                    self.assertEqual(archive.read(exported[key]), audio.read())
            self.assertEqual(exported['audio'], exported['question_audio_url'])
            self.assertEqual(exported['audio_url'], exported['question_audio_url'])

    def test_missing_unlinked_and_draft_audio_are_explicitly_unavailable(self):
        _, item = self.lesson()
        LessonItemAudio.objects.create(lesson_item=item, role='normal', audio_asset=self.audio('missing', missing=True))
        LessonItemAudio.objects.create(lesson_item=item, role='slow', audio_asset=self.audio('draft', status='draft'))
        question = QuizQuestion.objects.create(unit=self.unit, question_type='audio_to_character', status='published')
        QuizQuestionAudio.objects.create(question=question, role='question', audio_asset=self.audio('missing-q', missing=True))
        self.pack.quiz_questions.add(question)
        _, payload, _ = self.export()
        for key in ('audio_url', 'slow_audio_url', 'prompt_audio_url', 'explanation_audio_url'):
            self.assertIsNone(payload['lessons'][0]['items'][0][key])
        self.assertIsNone(payload['quizzes'][0]['question_audio_url'])

    def test_lessons_without_audio_and_empty_legacy_lessons_still_export(self):
        lesson, _ = self.lesson()
        Lesson.objects.create(unit=self.unit, slug='not-selected', title_fr='Unselected', status='published')
        empty = Lesson.objects.create(unit=self.unit, slug='legacy-empty', title_fr='Legacy', status='published')
        self.pack.lessons.add(empty)
        _, payload, _ = self.export()
        self.assertEqual({x['id'] for x in payload['lessons']}, {lesson.id, empty.id})
        self.assertEqual(next(x for x in payload['lessons'] if x['id'] == empty.id)['items'], [])

    def test_published_selection_uses_valid_fallback_and_excludes_unpublished_lessons(self):
        lesson, item = self.lesson()
        draft = Lesson.objects.create(unit=self.unit, slug='draft', title_fr='Draft', status='draft')
        self.pack.lessons.add(draft)
        LessonItem.objects.create(lesson=lesson, is_active=False)
        valid = self.audio('fallback')
        LessonItemAudio.objects.create(lesson_item=item, role='normal', audio_asset=valid, is_primary=False)
        LessonItemAudio.objects.create(lesson_item=item, role='normal', audio_asset=self.audio('draft-primary', status='draft'), is_primary=True)
        data, payload, _ = self.export()
        self.assertEqual(len(payload['lessons']), 1)
        self.assertEqual(len(payload['lessons'][0]['items']), 1)
        with zipfile.ZipFile(io.BytesIO(data)) as archive, valid.file.open('rb') as source:
            self.assertEqual(archive.read(payload['lessons'][0]['items'][0]['audio_url']), source.read())

    def test_generated_archive_for_flutter_reader(self):
        _, item = self.lesson()
        for role, _ in LessonItemAudio.ROLE_CHOICES:
            LessonItemAudio.objects.create(lesson_item=item, role=role, audio_asset=self.audio(role))
        q = QuizQuestion.objects.create(unit=self.unit, question_type='audio_to_character', prompt_fr='Test audio', status='published')
        for role, _ in QuizQuestionAudio.ROLE_CHOICES:
            QuizQuestionAudio.objects.create(question=q, role=role, audio_asset=self.audio(role))
        self.pack.quiz_questions.add(q)
        data, _, _ = self.export()
        # Opt-in regeneration of the synthetic cross-runtime fixture, never corpus data.
        if os.environ.get('BK_AUDIO_FIXTURE_DIR'):
            target = Path(os.environ['BK_AUDIO_FIXTURE_DIR'])
            target.mkdir(parents=True, exist_ok=True)
            (target / 'audio_export.zip').write_bytes(data)
