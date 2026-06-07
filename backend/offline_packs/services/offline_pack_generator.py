import json
import os
import shutil
import tempfile
import zipfile
from pathlib import Path

from django.core.files import File
from django.utils import timezone

from audio_assets.utils import get_linked_audio_file
from offline_packs.models import LessonPack


class OfflinePackGenerator:
    SCHEMA_VERSION = 2

    def __init__(self, pack: LessonPack):
        self.pack = pack
        self.media_files = []
        self.items_count = 0

    def generate(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            base_dir = Path(temp_dir)
            pack_dir = base_dir / self.pack.slug
            pack_dir.mkdir(parents=True, exist_ok=True)

            (pack_dir / 'audio').mkdir(exist_ok=True)
            (pack_dir / 'images').mkdir(exist_ok=True)

            themes = self._serialize_themes()
            units = self._serialize_units()
            characters = self._serialize_characters(pack_dir)
            words = self._serialize_words(pack_dir)
            lessons = self._serialize_lessons(pack_dir)
            quizzes = self._serialize_quizzes(pack_dir)

            self.items_count = (
                len(themes)
                + len(units)
                + len(characters)
                + len(words)
                + len(lessons)
                + len(quizzes)
            )

            manifest = {
                'schema_version': self.SCHEMA_VERSION,
                'slug': self.pack.slug,
                'version': self.pack.version,
                'title_fr': self.pack.title_fr,
                'title_en': self.pack.title_en,
                'title_ar': self.pack.title_ar,
                'description_fr': self.pack.description_fr,
                'description_en': self.pack.description_en,
                'description_ar': self.pack.description_ar,
                'level': self.pack.level,
                'pack_type': self.pack.pack_type,
                'generated_at': timezone.now().isoformat(),
                'items_count': self.items_count,
                'media_files': self.media_files,
                'files': {
                    'themes': 'themes.json',
                    'units': 'units.json',
                    'characters': 'characters.json',
                    'words': 'words.json',
                    'lessons': 'lessons.json',
                    'quizzes': 'quizzes.json',
                },
            }

            self._write_json(pack_dir / 'manifest.json', manifest)
            self._write_json(pack_dir / 'metadata.json', manifest)
            self._write_json(pack_dir / 'themes.json', themes)
            self._write_json(pack_dir / 'units.json', units)
            self._write_json(pack_dir / 'characters.json', characters)
            self._write_json(pack_dir / 'words.json', words)
            self._write_json(pack_dir / 'lessons.json', lessons)
            self._write_json(pack_dir / 'quizzes.json', quizzes)

            zip_path = base_dir / self.pack.filename
            self._zip_directory(pack_dir, zip_path)

            with open(zip_path, 'rb') as opened_file:
                self.pack.file.save(
                    self.pack.filename,
                    File(opened_file),
                    save=False,
                )

            self.pack.manifest = manifest
            self.pack.items_count = self.items_count
            self.pack.generated_at = timezone.now()
            self.pack.save()

            self.pack.update_file_metadata()
            self.pack.save()

            return self.pack

    def _serialize_themes(self):
        return [
            {
                'id': theme.id,
                'slug': theme.slug,
                'title_fr': theme.title_fr,
                'title_en': theme.title_en,
                'title_ar': theme.title_ar,
                'description_fr': theme.description_fr,
                'description_en': theme.description_en,
                'description_ar': theme.description_ar,
                'level': theme.level,
                'order_index': theme.order_index,
                'status': theme.status,
            }
            for theme in self.pack.themes.filter(is_active=True)
        ]

    def _serialize_units(self):
        return [
            {
                'id': unit.id,
                'theme': unit.theme_id,
                'theme_slug': unit.theme.slug,
                'slug': unit.slug,
                'title_fr': unit.title_fr,
                'title_en': unit.title_en,
                'title_ar': unit.title_ar,
                'description_fr': unit.description_fr,
                'description_en': unit.description_en,
                'description_ar': unit.description_ar,
                'level': unit.level,
                'character_ids': list(unit.characters.values_list('id', flat=True)),
                'word_ids': list(unit.words.values_list('id', flat=True)),
                'estimated_minutes': unit.estimated_minutes,
                'min_score_to_pass': unit.min_score_to_pass,
                'order_index': unit.order_index,
                'status': unit.status,
            }
            for unit in self.pack.units.filter(is_active=True).select_related('theme').prefetch_related('characters', 'words')
        ]

    def _serialize_characters(self, pack_dir):
        results = []

        for character in self.pack.characters.filter(is_active=True).prefetch_related('audio_links__audio_asset'):
            audio_path = self._copy_audio(
                pack_dir=pack_dir,
                file_field=get_linked_audio_file(character, role='normal'),
                prefix=f'character_{character.id}_normal',
            )

            slow_audio_path = self._copy_audio(
                pack_dir=pack_dir,
                file_field=get_linked_audio_file(character, role='slow'),
                prefix=f'character_{character.id}_slow',
            )

            results.append({
                'id': character.id,
                'symbol': character.symbol,
                'unicode_code': character.unicode_code,
                'name': character.name,
                'name_fr': character.name_fr,
                'name_en': character.name_en,
                'name_ar': character.name_ar,
                'latin_transcription': character.latin_transcription,
                'arabic_transcription': character.arabic_transcription,
                'character_type': character.character_type,
                'order_index': character.order_index,
                'description': character.description,
                'audio': audio_path,
                'audio_url': audio_path,
                'slow_audio': slow_audio_path,
                'slow_audio_url': slow_audio_path,
            })

        return results

    def _serialize_words(self, pack_dir):
        results = []

        for word in self.pack.words.filter(is_active=True).select_related('category').prefetch_related('audio_links__audio_asset'):
            audio_path = self._copy_audio(
                pack_dir=pack_dir,
                file_field=get_linked_audio_file(word, role='normal'),
                prefix=f'word_{word.id}_normal',
            )

            slow_audio_path = self._copy_audio(
                pack_dir=pack_dir,
                file_field=get_linked_audio_file(word, role='slow'),
                prefix=f'word_{word.id}_slow',
            )

            image_path = self._copy_image(
                pack_dir=pack_dir,
                file_field=word.image,
                prefix=f'word_{word.id}',
            )

            results.append({
                'id': word.id,
                'beriya_text': word.beriya_text,
                'latin_transcription': word.latin_transcription,
                'arabic_transcription': word.arabic_transcription,
                'french_translation': word.french_translation,
                'english_translation': word.english_translation,
                'arabic_translation': word.arabic_translation,
                'translation_fr': word.french_translation,
                'translation_en': word.english_translation,
                'translation_ar': word.arabic_translation,
                'category': word.category_id,
                'category_slug': word.category.slug if word.category else '',
                'difficulty': word.difficulty,
                'level': word.difficulty,
                'difficulty_order': word.difficulty_order,
                'image': image_path,
                'image_url': image_path,
                'audio': audio_path,
                'audio_url': audio_path,
                'slow_audio': slow_audio_path,
                'slow_audio_url': slow_audio_path,
                'oral_prompt': word.oral_prompt,
                'pronunciation_note': word.pronunciation_note,
                'dialect_note': word.dialect_note,
                'example_sentence': word.example_sentence,
            })

        return results

    def _serialize_lessons(self, pack_dir):
        results = []

        for lesson in self.pack.lessons.filter(is_active=True).select_related('unit').prefetch_related(
            'items',
            'items__character',
            'items__word',
            'items__audio_links__audio_asset',
        ):
            items = []

            for item in lesson.items.filter(is_active=True).order_by('order_index', 'id'):
                audio_path = self._copy_audio(
                    pack_dir=pack_dir,
                    file_field=get_linked_audio_file(item, role='normal'),
                    prefix=f'lesson_item_{item.id}_normal',
                )

                slow_audio_path = self._copy_audio(
                    pack_dir=pack_dir,
                    file_field=get_linked_audio_file(item, role='slow'),
                    prefix=f'lesson_item_{item.id}_slow',
                )

                prompt_audio_path = self._copy_audio(
                    pack_dir=pack_dir,
                    file_field=get_linked_audio_file(item, role='prompt'),
                    prefix=f'lesson_item_{item.id}_prompt',
                )

                image_path = self._copy_image(
                    pack_dir=pack_dir,
                    file_field=item.image,
                    prefix=f'lesson_item_{item.id}',
                )

                items.append({
                    'id': item.id,
                    'lesson': lesson.id,
                    'item_type': item.item_type,
                    'character': item.character_id,
                    'character_id': item.character_id,
                    'word': item.word_id,
                    'word_id': item.word_id,
                    'title_fr': item.title_fr,
                    'title_en': item.title_en,
                    'title_ar': item.title_ar,
                    'oral_prompt_fr': item.oral_prompt_fr,
                    'oral_prompt_en': item.oral_prompt_en,
                    'oral_prompt_ar': item.oral_prompt_ar,
                    'explanation_fr': item.explanation_fr,
                    'explanation_en': item.explanation_en,
                    'explanation_ar': item.explanation_ar,
                    'writing_hint_fr': item.writing_hint_fr,
                    'writing_hint_en': item.writing_hint_en,
                    'writing_hint_ar': item.writing_hint_ar,
                    'repeat_count': item.repeat_count,
                    'image': image_path,
                    'image_url': image_path,
                    'audio': audio_path,
                    'audio_url': audio_path,
                    'slow_audio': slow_audio_path,
                    'slow_audio_url': slow_audio_path,
                    'prompt_audio': prompt_audio_path,
                    'prompt_audio_url': prompt_audio_path,
                    'order_index': item.order_index,
                })

            results.append({
                'id': lesson.id,
                'unit': lesson.unit_id,
                'unit_slug': lesson.unit.slug,
                'slug': lesson.slug,
                'title_fr': lesson.title_fr,
                'title_en': lesson.title_en,
                'title_ar': lesson.title_ar,
                'description_fr': lesson.description_fr,
                'description_en': lesson.description_en,
                'description_ar': lesson.description_ar,
                'oral_intro_fr': lesson.oral_intro_fr,
                'oral_intro_en': lesson.oral_intro_en,
                'oral_intro_ar': lesson.oral_intro_ar,
                'level': lesson.level,
                'order_index': lesson.order_index,
                'estimated_minutes': lesson.estimated_minutes,
                'status': lesson.status,
                'items': items,
            })

        return results

    def _serialize_quizzes(self, pack_dir):
        results = []

        for question in self.pack.quiz_questions.filter(is_active=True).select_related(
            'unit',
            'lesson',
            'character',
            'word',
        ).prefetch_related(
            'options',
            'options__character',
            'options__word',
            'audio_links__audio_asset',
        ):
            question_audio_path = self._copy_audio(
                pack_dir=pack_dir,
                file_field=get_linked_audio_file(question, role='question'),
                prefix=f'quiz_{question.id}_question',
            )

            slow_audio_path = self._copy_audio(
                pack_dir=pack_dir,
                file_field=get_linked_audio_file(question, role='slow_question'),
                prefix=f'quiz_{question.id}_slow',
            )

            explanation_audio_path = self._copy_audio(
                pack_dir=pack_dir,
                file_field=get_linked_audio_file(question, role='explanation'),
                prefix=f'quiz_{question.id}_explanation',
            )

            image_path = self._copy_image(
                pack_dir=pack_dir,
                file_field=question.question_image,
                prefix=f'quiz_{question.id}',
            )

            options = list(question.options.all())
            correct_index = 0

            option_payload = []

            for index, option in enumerate(options):
                if option.is_correct:
                    correct_index = index

                option_image = self._copy_image(
                    pack_dir=pack_dir,
                    file_field=option.image,
                    prefix=f'quiz_option_{option.id}',
                )

                fallback = ''
                if option.text_fr:
                    fallback = option.text_fr
                elif option.character:
                    fallback = option.character.symbol
                elif option.word:
                    fallback = option.word.beriya_text

                option_payload.append({
                    'id': option.id,
                    'question': question.id,
                    'text': fallback,
                    'text_fr': option.text_fr,
                    'text_en': option.text_en,
                    'text_ar': option.text_ar,
                    'text_fr_out': option.text_fr or fallback,
                    'text_en_out': option.text_en or fallback,
                    'text_ar_out': option.text_ar or fallback,
                    'character': option.character_id,
                    'character_symbol': option.character.symbol if option.character else '',
                    'word': option.word_id,
                    'word_text': option.word.beriya_text if option.word else '',
                    'image': option_image,
                    'image_url': option_image,
                    'order_index': option.order_index,
                })

            results.append({
                'id': question.id,
                'unit': question.unit_id,
                'unit_slug': question.unit.slug if question.unit else '',
                'lesson': question.lesson_id,
                'lesson_slug': question.lesson.slug if question.lesson else '',
                'question_type': question.question_type,
                'difficulty': question.difficulty,
                'prompt_text': question.prompt_fr or question.prompt_en or question.prompt_ar,
                'prompt_text_fr': question.prompt_fr,
                'prompt_text_en': question.prompt_en,
                'prompt_text_ar': question.prompt_ar,
                'oral_prompt': question.oral_prompt_fr or question.oral_prompt_en or question.oral_prompt_ar,
                'oral_prompt_fr': question.oral_prompt_fr,
                'oral_prompt_en': question.oral_prompt_en,
                'oral_prompt_ar': question.oral_prompt_ar,
                'character': question.character_id,
                'character_symbol': question.character.symbol if question.character else '',
                'word': question.word_id,
                'word_text': question.word.beriya_text if question.word else '',
                'question_image': image_path,
                'question_image_url': image_path,
                'question_audio': question_audio_path,
                'question_audio_url': question_audio_path,
                'question_slow_audio': slow_audio_path,
                'question_slow_audio_url': slow_audio_path,
                'correct_text_answer': question.correct_text_answer,
                'correct_index': correct_index,
                'explanation': question.explanation_fr or question.explanation_en or question.explanation_ar,
                'explanation_fr_out': question.explanation_fr,
                'explanation_en_out': question.explanation_en,
                'explanation_ar_out': question.explanation_ar,
                'explanation_audio': explanation_audio_path,
                'explanation_audio_url': explanation_audio_path,
                'order_index': question.order_index,
                'points': question.points,
                'status': question.status,
                'options': option_payload,
                'options_text_fr': [
                    option['text_fr_out']
                    for option in option_payload
                ],
                'options_text_en': [
                    option['text_en_out']
                    for option in option_payload
                ],
                'options_text_ar': [
                    option['text_ar_out']
                    for option in option_payload
                ],
            })

        return results

    def _copy_audio(self, pack_dir, file_field, prefix):
        return self._copy_media(pack_dir, file_field, 'audio', prefix)

    def _copy_image(self, pack_dir, file_field, prefix):
        return self._copy_media(pack_dir, file_field, 'images', prefix)

    def _copy_media(self, pack_dir, file_field, folder_name, prefix):
        if not file_field:
            return None

        try:
            source_path = file_field.path
        except (ValueError, NotImplementedError):
            return None

        if not os.path.exists(source_path):
            return None

        extension = Path(source_path).suffix
        filename = f'{prefix}{extension}'
        relative_path = f'{folder_name}/{filename}'
        destination_path = pack_dir / relative_path

        shutil.copy2(source_path, destination_path)

        if relative_path not in self.media_files:
            self.media_files.append(relative_path)

        return relative_path

    def _write_json(self, path, data):
        with open(path, 'w', encoding='utf-8') as opened_file:
            json.dump(
                data,
                opened_file,
                ensure_ascii=False,
                indent=2,
            )

    def _zip_directory(self, source_dir, zip_path):
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zip_file:
            for root, _, files in os.walk(source_dir):
                for file_name in files:
                    file_path = Path(root) / file_name
                    archive_name = file_path.relative_to(source_dir)
                    zip_file.write(file_path, archive_name)