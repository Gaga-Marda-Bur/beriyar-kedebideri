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
        self.media_map = {}  # {source_identifier: relative_pack_path}

    def generate(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            base_dir = Path(temp_dir)
            pack_dir = base_dir / self.pack.slug
            pack_dir.mkdir(parents=True, exist_ok=True)

            (pack_dir / 'audio').mkdir(exist_ok=True)
            (pack_dir / 'images').mkdir(exist_ok=True)

            # Sérialisation des entités et copie des médias associés
            themes = self._serialize_themes()
            characters = self._serialize_characters(pack_dir)
            words = self._serialize_words(pack_dir)
            lessons = self._serialize_lessons(pack_dir)
            quizzes = self._serialize_quizzes(pack_dir)
            # Les unités sont sérialisées après afin de pouvoir réécrire les URLs de core_flow
            units = self._serialize_units(pack_dir)

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
        qs = self.pack.themes.filter(is_active=True)
        if self.pack.status == 'published':
            qs = qs.filter(status='published')
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
            for theme in qs
        ]

    def _serialize_units(self, pack_dir):
        units_data = []
        is_published = (self.pack.status == 'published')

        units_qs = self.pack.units.filter(is_active=True).select_related('theme', 'target_word').prefetch_related(
            'characters', 'distractor_characters', 'words'
        )
        if is_published:
            units_qs = units_qs.filter(status='published')

        for unit in units_qs:
            # Embarquer et réécrire le core_flow (A06 & A07)
            raw_flow = unit.generate_core_flow(only_published=is_published) or []
            rewritten_flow = self._rewrite_and_embed_core_flow(pack_dir, unit, raw_flow)

            chars = unit.characters.filter(is_active=True)
            distractors = unit.distractor_characters.filter(is_active=True)
            words = unit.words.filter(is_active=True)
            target_word_id = unit.target_word_id

            if is_published:
                chars = chars.filter(validation_status='published')
                distractors = distractors.filter(validation_status='published')
                words = words.filter(validation_status='published')
                if unit.target_word and unit.target_word.validation_status != 'published':
                    target_word_id = None

            units_data.append({
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
                'character_ids': list(chars.values_list('id', flat=True)),
                'distractor_character_ids': list(distractors.values_list('id', flat=True)),
                'word_ids': list(words.values_list('id', flat=True)),
                'target_word_id': target_word_id,
                'weight_recognition': unit.weight_recognition,
                'weight_tracing': unit.weight_tracing,
                'weight_encoding': unit.weight_encoding,
                'enable_tracing': unit.enable_tracing,
                'pedagogy_config': unit.pedagogy_config or {},
                'core_flow': rewritten_flow,
                'estimated_minutes': unit.estimated_minutes,
                'min_score_to_pass': unit.min_score_to_pass,
                'order_index': unit.order_index,
                'status': unit.status,
            })

        return units_data

    def _rewrite_and_embed_core_flow(self, pack_dir, unit, flow):
        """
        Parcourt récursivement chaque étape du core_flow, copie les médias
        référencés et remplace leurs URL/chemins par les chemins relatifs locaux (A06).
        """
        rewritten = []

        for step in flow:
            step_copy = dict(step)

            # Vérification et réécriture des champs audio potentiels
            for audio_key in ['audio_url', 'letter_name_audio_url', 'audio']:
                val = step_copy.get(audio_key)
                if val:
                    local_val = self._resolve_or_copy_flow_media(pack_dir, val, 'audio')
                    if local_val:
                        step_copy[audio_key] = local_val

            # Vérification et réécriture des champs images
            for img_key in ['image_url', 'image']:
                val = step_copy.get(img_key)
                if val:
                    local_val = self._resolve_or_copy_flow_media(pack_dir, val, 'images')
                    if local_val:
                        step_copy[img_key] = local_val

            rewritten.append(step_copy)

        return rewritten

    def _resolve_or_copy_flow_media(self, pack_dir, source_ref, folder_name):
        """
        Trouve le média correspondant dans les fichiers existants ou dans media_map.
        Si non trouvé, le copie et retourne le chemin relatif dans le pack.
        """
        if not source_ref or not isinstance(source_ref, str):
            return source_ref

        # Nettoyage de la référence source
        ref = source_ref.strip()

        # Si c'est déjà un chemin relatif local du pack (ex: audio/character_1_normal.mp3)
        if ref.startswith(f'{folder_name}/') and ref in self.media_files:
            return ref

        # Correspondance dans notre cache de médias déjà copiés
        for src_key, rel_path in self.media_map.items():
            if src_key in ref or ref.endswith(src_key):
                return rel_path

        # Si le chemin commence par /media/ ou media/
        clean_name = ref
        for prefix in ['http://', 'https://']:
            if clean_name.startswith(prefix):
                parts = clean_name.split('/media/', 1)
                if len(parts) > 1:
                    clean_name = parts[1]
                break

        if clean_name.startswith('/media/'):
            clean_name = clean_name[len('/media/'):]
        elif clean_name.startswith('media/'):
            clean_name = clean_name[len('media/'):]

        # Chercher dans MEDIA_ROOT si accessible localement
        from django.conf import settings
        from django.core.files.storage import default_storage

        if default_storage.exists(clean_name):
            try:
                field_file = default_storage.open(clean_name)
                stem = Path(clean_name).stem
                prefix = f'flow_{stem}'
                return self._copy_storage_file(pack_dir, default_storage, clean_name, folder_name, prefix)
            except Exception:
                pass

        return source_ref

    def _serialize_characters(self, pack_dir):
        results = []

        chars_qs = self.pack.characters.filter(is_active=True).prefetch_related('audio_links__audio_asset')
        if self.pack.status == 'published':
            chars_qs = chars_qs.filter(validation_status='published')
        for character in chars_qs:
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
                'phoneme_ipa': getattr(character, 'phoneme_ipa', ''),
                'stroke_path_data': getattr(character, 'stroke_path_data', {}),
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

        words_qs = self.pack.words.filter(is_active=True).select_related('category').prefetch_related('audio_links__audio_asset')
        if self.pack.status == 'published':
            words_qs = words_qs.filter(validation_status='published')
        for word in words_qs:
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

        lessons_qs = self.pack.lessons.filter(is_active=True)
        if self.pack.status == 'published':
            lessons_qs = lessons_qs.filter(status='published')
        for lesson in lessons_qs.select_related('unit').prefetch_related(
            'items',
            'items__character',
            'items__word',
            'items__audio_links__audio_asset',
        ):
            intro_audio_path = self._copy_audio(
                pack_dir=pack_dir,
                file_field=get_linked_audio_file(lesson, role='normal'),
                prefix=f'lesson_{lesson.id}_intro',
            )

            cover_image_path = self._copy_image(
                pack_dir=pack_dir,
                file_field=lesson.cover_image,
                prefix=f'lesson_{lesson.id}_cover',
            )

            items_payload = []

            for item in lesson.items.filter(is_active=True).select_related('character', 'word').prefetch_related('audio_links__audio_asset'):
                item_audio_path = self._copy_audio(
                    pack_dir=pack_dir,
                    file_field=get_linked_audio_file(item, role='normal'),
                    prefix=f'lesson_item_{item.id}',
                )

                items_payload.append({
                    'id': item.id,
                    'item_type': item.item_type,
                    'order_index': item.order_index,
                    'character': item.character_id,
                    'character_symbol': item.character.symbol if item.character else '',
                    'word': item.word_id,
                    'word_beriya_text': item.word.beriya_text if item.word else '',
                    'oral_prompt_fr': item.oral_prompt_fr,
                    'oral_prompt_en': item.oral_prompt_en,
                    'oral_prompt_ar': item.oral_prompt_ar,
                    'explanation_fr': item.explanation_fr,
                    'explanation_en': item.explanation_en,
                    'explanation_ar': item.explanation_ar,
                    'writing_hint': item.writing_hint,
                    'audio': item_audio_path,
                    'audio_url': item_audio_path,
                })

            results.append({
                'id': lesson.id,
                'unit': lesson.unit_id,
                'unit_slug': lesson.unit.slug,
                'slug': lesson.slug,
                'title_fr': lesson.title_fr,
                'title_en': lesson.title_en,
                'title_ar': lesson.title_ar,
                'short_description_fr': lesson.short_description_fr,
                'short_description_en': lesson.short_description_en,
                'short_description_ar': lesson.short_description_ar,
                'description_fr': lesson.description_fr,
                'description_en': lesson.description_en,
                'description_ar': lesson.description_ar,
                'level': lesson.level,
                'order_index': lesson.order_index,
                'status': lesson.status,
                'cover_image': cover_image_path,
                'cover_image_url': cover_image_path,
                'intro_audio': intro_audio_path,
                'intro_audio_url': intro_audio_path,
                'items': items_payload,
            })

        return results

    def _serialize_quizzes(self, pack_dir):
        results = []

        quizzes_qs = self.pack.quiz_questions.filter(is_active=True)
        if self.pack.status == 'published':
            quizzes_qs = quizzes_qs.filter(status='published')
        for question in quizzes_qs.select_related('unit', 'character', 'word').prefetch_related('options'):
            prompt_audio_path = self._copy_audio(
                pack_dir=pack_dir,
                file_field=get_linked_audio_file(question, role='normal'),
                prefix=f'quiz_question_{question.id}',
            )

            option_payload = []

            for option in question.options.all().select_related('character', 'word'):
                option_payload.append({
                    'id': option.id,
                    'character': option.character_id,
                    'character_symbol': option.character.symbol if option.character else '',
                    'word': option.word_id,
                    'word_beriya_text': option.word.beriya_text if option.word else '',
                    'text_fr': option.text_fr,
                    'text_en': option.text_en,
                    'text_ar': option.text_ar,
                    'is_correct': option.is_correct,
                    'order_index': option.order_index,
                    'text_fr_out': option.text_fr or (option.character.symbol if option.character else '') or (option.word.beriya_text if option.word else ''),
                    'text_en_out': option.text_en or (option.character.symbol if option.character else '') or (option.word.beriya_text if option.word else ''),
                    'text_ar_out': option.text_ar or (option.character.symbol if option.character else '') or (option.word.beriya_text if option.word else ''),
                })

            results.append({
                'id': question.id,
                'unit': question.unit_id,
                'unit_slug': question.unit.slug if question.unit else '',
                'lesson': question.lesson_id,
                'question_type': question.question_type,
                'difficulty': question.difficulty,
                'points': question.points,
                'prompt_fr': question.prompt_fr,
                'prompt_en': question.prompt_en,
                'prompt_ar': question.prompt_ar,
                'oral_prompt_fr': question.oral_prompt_fr,
                'oral_prompt_en': question.oral_prompt_en,
                'oral_prompt_ar': question.oral_prompt_ar,
                'audio': prompt_audio_path,
                'audio_url': prompt_audio_path,
                'character': question.character_id,
                'character_symbol': question.character.symbol if question.character else '',
                'word': question.word_id,
                'word_beriya_text': question.word.beriya_text if question.word else '',
                'min_options_required': question.min_options_required,
                'order_index': question.order_index,
                'status': question.status,
                'options': option_payload,
                'options_text_fr': [option['text_fr_out'] for option in option_payload],
                'options_text_en': [option['text_en_out'] for option in option_payload],
                'options_text_ar': [option['text_ar_out'] for option in option_payload],
            })

        return results

    def _copy_audio(self, pack_dir, file_field, prefix):
        return self._copy_media(pack_dir, file_field, 'audio', prefix)

    def _copy_image(self, pack_dir, file_field, prefix):
        return self._copy_media(pack_dir, file_field, 'images', prefix)

    def _copy_media(self, pack_dir, file_field, folder_name, prefix):
        """
        Copie sécurisée d'un média local ou distant (A04).
        Utilise file_field.open() par blocs pour fonctionner sous FileSystemStorage et S3/R2.
        """
        if not file_field or not getattr(file_field, 'name', None):
            return None

        name = file_field.name
        extension = Path(name).suffix or ('.mp3' if folder_name == 'audio' else '.jpg')
        filename = f'{prefix}{extension}'
        relative_path = f'{folder_name}/{filename}'
        destination_path = pack_dir / relative_path

        try:
            # Ouverture en flux via le storage du FieldFile
            with file_field.open('rb') as src_file:
                with open(destination_path, 'wb') as dst_file:
                    for chunk in iter(lambda: src_file.read(65536), b''):
                        dst_file.write(chunk)
        except Exception:
            return None

        if relative_path not in self.media_files:
            self.media_files.append(relative_path)

        self.media_map[name] = relative_path
        if hasattr(file_field, 'url'):
            try:
                self.media_map[file_field.url] = relative_path
            except Exception:
                pass

        return relative_path

    def _copy_storage_file(self, pack_dir, storage, storage_name, folder_name, prefix):
        extension = Path(storage_name).suffix or ('.mp3' if folder_name == 'audio' else '.jpg')
        filename = f'{prefix}{extension}'
        relative_path = f'{folder_name}/{filename}'
        destination_path = pack_dir / relative_path

        try:
            with storage.open(storage_name, 'rb') as src_file:
                with open(destination_path, 'wb') as dst_file:
                    for chunk in iter(lambda: src_file.read(65536), b''):
                        dst_file.write(chunk)
        except Exception:
            return None

        if relative_path not in self.media_files:
            self.media_files.append(relative_path)

        self.media_map[storage_name] = relative_path
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
