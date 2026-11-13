import json
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from alphabet.models import Character
from learning.models import LearningTheme, LearningUnit
from lessons.models import Lesson, LessonItem
from quizzes.models import QuizOption, QuizQuestion
from vocabulary.models import Word, WordCategory


TRACK_TO_THEME = {
    'ALPHABET_ERFE': {
        'slug': 'bk-preprod-alphabet-erfe',
        'title_fr': 'Alphabet Erfe (Préproduction)',
        'description_fr': 'Parcours pilote alphabet Erfe (25 lettres, préproduction non publiée).',
        'level': LearningTheme.BEGINNER,
        'order_index': 101,
    },
    'LECTURE_PHRASES': {
        'slug': 'bk-preprod-lecture-phrases',
        'title_fr': 'Lecture de phrases (Préproduction)',
        'description_fr': 'Phrases issues du corpus Beřiya–Français (préproduction non publiée).',
        'level': LearningTheme.INTERMEDIATE,
        'order_index': 102,
    },
    'LEXIQUE_LATIN_SOURCE': {
        'slug': 'bk-preprod-lexique-latin-source',
        'title_fr': 'Lexique DF/ADES 2007 (Préproduction)',
        'description_fr': 'Lexique source DF/ADES 2007 sans conversion Erfe automatique (préproduction).',
        'level': LearningTheme.BEGINNER,
        'order_index': 103,
    },
}

EX_TYPE_TO_QUESTION_TYPE = {
    'mcq': QuizQuestion.TEXT_TO_CHARACTER,
    'listen_select': QuizQuestion.AUDIO_TO_CHARACTER,
    'listen_type': QuizQuestion.GUIDED_KEYBOARD,
}


def _map_cefr_to_level(cefr: str) -> str:
    upper = (cefr or '').upper()
    if upper in {'A2-B1', 'B1', 'B1-B2', 'B2'}:
        return LearningUnit.INTERMEDIATE
    if upper in {'C1', 'C2'}:
        return LearningUnit.ADVANCED
    return LearningUnit.BEGINNER


def _map_cefr_to_difficulty(cefr: str) -> str:
    upper = (cefr or '').upper()
    if upper in {'A2-B1', 'B1', 'B1-B2', 'B2'}:
        return Word.INTERMEDIATE
    if upper in {'C1', 'C2'}:
        return Word.ADVANCED
    return Word.BEGINNER


class Command(BaseCommand):
    help = 'Importe de manière idempotente et atomique un pack de cours de préproduction (non publié).'

    def add_arguments(self, parser):
        default_fixture = (
            Path(settings.BASE_DIR) / 'learning' / 'fixtures' / 'bk_preprod_pack_fr_beriya.json'
        )
        parser.add_argument(
            '--file',
            type=str,
            default=str(default_fixture),
            help='Chemin vers le fichier JSON de préproduction.',
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Simule l’import dans une transaction annulée sans modifier la base.',
        )
        parser.add_argument(
            '--tracks',
            nargs='*',
            default=None,
            help='Filtrer les parcours à importer (ex: ALPHABET_ERFE LECTURE_PHRASES).',
        )

    def handle(self, *args, **options):
        file_path = Path(options['file'])
        if not file_path.exists():
            raise CommandError(f'Fichier introuvable : {file_path}')

        try:
            with open(file_path, encoding='utf-8') as f:
                pack = json.load(f)
        except Exception as exc:
            raise CommandError(f'JSON invalide ({file_path}): {exc}') from exc

        lessons_data = pack.get('lessons')
        exercises_data = pack.get('exercises', [])
        if not isinstance(lessons_data, list):
            raise CommandError('Le pack JSON doit contenir une liste "lessons".')

        selected_tracks = set(options['tracks']) if options['tracks'] else None
        dry_run = bool(options['dry_run'])

        stats = {
            'dry_run': dry_run,
            'package_id': pack.get('package_id', ''),
            'created': 0,
            'skipped_existing': 0,
            'skipped_protected': 0,
            'rejected': 0,
            'rejection_reasons': [],
        }

        with transaction.atomic():
            themes_by_track = {}
            lessons_by_preprod_id = {}
            units_by_preprod_id = {}
            items_by_preprod_id = {}

            cat_phrases, _ = WordCategory.objects.get_or_create(
                slug='bk-preprod-phrases',
                defaults={'name_fr': 'Phrases Préproduction', 'order_index': 101},
            )
            cat_lexique, _ = WordCategory.objects.get_or_create(
                slug='bk-preprod-lexique-df-ades',
                defaults={'name_fr': 'Lexique DF/ADES 2007 (Préproduction)', 'order_index': 102},
            )

            track_order_counter = {}

            for lesson_obj in lessons_data:
                lesson_id = (lesson_obj.get('id') or '').strip()
                track = (lesson_obj.get('track') or '').strip()
                title = (lesson_obj.get('title') or '').strip()

                if not lesson_id or not track or not title:
                    stats['rejected'] += 1
                    stats['rejection_reasons'].append(
                        f'Leçon invalide (id/track/title manquant): {lesson_id or "?"}'
                    )
                    continue

                if selected_tracks and track not in selected_tracks:
                    continue

                if track not in TRACK_TO_THEME:
                    stats['rejected'] += 1
                    stats['rejection_reasons'].append(
                        f'Parcours inconnu pour {lesson_id}: {track}'
                    )
                    continue

                if lesson_obj.get('public_enabled') is True:
                    stats['rejected'] += 1
                    stats['rejection_reasons'].append(
                        f'Leçon {lesson_id} rejetée : public_enabled=true interdit en préproduction.'
                    )
                    continue

                if track not in themes_by_track:
                    theme_meta = TRACK_TO_THEME[track]
                    theme, theme_created = LearningTheme.objects.get_or_create(
                        slug=theme_meta['slug'],
                        defaults={
                            'title_fr': theme_meta['title_fr'],
                            'description_fr': theme_meta['description_fr'],
                            'level': theme_meta['level'],
                            'order_index': theme_meta['order_index'],
                            'status': LearningTheme.DRAFT,
                            'is_active': True,
                            'available_offline': True,
                        },
                    )
                    themes_by_track[track] = theme
                    if theme_created:
                        stats['created'] += 1
                    elif theme.status != LearningTheme.DRAFT:
                        stats['skipped_protected'] += 1
                    else:
                        stats['skipped_existing'] += 1

                theme = themes_by_track[track]
                track_order_counter[track] = track_order_counter.get(track, 0) + 1
                order_idx = track_order_counter[track]

                unit_slug = f'bk-preprod-{lesson_id.lower()}'
                level = _map_cefr_to_level(lesson_obj.get('level', ''))
                objective = (lesson_obj.get('objective') or '').strip()

                unit, unit_created = LearningUnit.objects.get_or_create(
                    slug=unit_slug,
                    defaults={
                        'theme': theme,
                        'title_fr': title,
                        'description_fr': objective,
                        'level': level,
                        'order_index': order_idx,
                        'status': LearningUnit.DRAFT,
                        'is_active': True,
                        'available_offline': True,
                        'enable_tracing': False,
                        'pedagogy_config': {
                            'preprod_id': lesson_id,
                            'track': track,
                            'cefr_level': lesson_obj.get('level', ''),
                            'source_package_id': pack.get('package_id', ''),
                            'audio_status': 'A_ENREGISTRER',
                            'publication_blocked': True,
                            'human_edited': False,
                        },
                    },
                )
                if unit_created:
                    stats['created'] += 1
                elif unit.status != LearningUnit.DRAFT or (
                    isinstance(unit.pedagogy_config, dict)
                    and unit.pedagogy_config.get('human_edited') is True
                ):
                    stats['skipped_protected'] += 1
                else:
                    stats['skipped_existing'] += 1

                lesson, lesson_created = Lesson.objects.get_or_create(
                    slug=unit_slug,
                    defaults={
                        'unit': unit,
                        'title_fr': title,
                        'description_fr': objective,
                        'oral_intro_fr': 'Contenu de préproduction en attente de validation native et audio.',
                        'level': level,
                        'order_index': order_idx,
                        'status': Lesson.DRAFT,
                        'is_active': True,
                        'available_offline': True,
                    },
                )
                if lesson_created:
                    stats['created'] += 1
                elif lesson.status != Lesson.DRAFT:
                    stats['skipped_protected'] += 1
                else:
                    stats['skipped_existing'] += 1

                units_by_preprod_id[lesson_id] = unit
                lessons_by_preprod_id[lesson_id] = lesson

                for item_idx, item in enumerate(lesson_obj.get('items', []), start=1):
                    item_id = (item.get('id') or '').strip()
                    kind = (item.get('kind') or '').strip()
                    french = (item.get('french') or '').strip()

                    if not item_id or not kind or not french:
                        stats['rejected'] += 1
                        stats['rejection_reasons'].append(
                            f'Contenu invalide dans {lesson_id}: {item_id or "?"}'
                        )
                        continue

                    if item.get('publication_status') == 'PUBLISHED' and not item.get('audio_path'):
                        stats['rejected'] += 1
                        stats['rejection_reasons'].append(
                            f'Contenu {item_id} rejeté : publication sans audio interdite.'
                        )
                        continue

                    bk_marker = f'[bk_id:{item_id}]'
                    source_ref = item.get('source_ref') or ''
                    source_row = item.get('source_row')
                    notes = item.get('notes') or ''
                    explanation_text = (
                        f'{bk_marker} {notes} '
                        f'(Source: {source_ref}'
                        f'{f", ligne {source_row}" if source_row is not None else ""})'
                    ).strip()

                    char_obj = None
                    word_obj = None
                    item_type = LessonItem.EXPLANATION

                    if kind == 'alphabet':
                        symbol = (item.get('beriya_erfe') or '').strip()
                        if not symbol:
                            stats['rejected'] += 1
                            stats['rejection_reasons'].append(
                                f'Alphabet {item_id} rejeté : beriya_erfe manquant.'
                            )
                            continue
                        unicode_code = f'U+{ord(symbol[0]):04X}'
                        latin = (item.get('beriya_latin') or '').strip()
                        arabic_ref = (item.get('arabic_reference') or '').strip()
                        char_obj, char_created = Character.objects.get_or_create(
                            symbol=symbol,
                            defaults={
                                'unicode_code': unicode_code,
                                'name_fr': french,
                                'latin_transcription': latin,
                                'latin_grapheme': latin.lower(),
                                'arabic_transcription': arabic_ref,
                                'order_index': item_idx,
                                'validation_status': Character.DRAFT,
                                'is_active': True,
                                'available_offline': True,
                            },
                        )
                        if char_created:
                            stats['created'] += 1
                        elif char_obj.validation_status != Character.DRAFT:
                            stats['skipped_protected'] += 1
                        else:
                            stats['skipped_existing'] += 1
                        unit.characters.add(char_obj)
                        item_type = LessonItem.CHARACTER

                    elif kind == 'phrase':
                        beriya_erfe = (item.get('beriya_erfe') or '').strip()
                        if not beriya_erfe:
                            stats['rejected'] += 1
                            stats['rejection_reasons'].append(
                                f'Phrase {item_id} rejetée : beriya_erfe manquant.'
                            )
                            continue
                        existing_word = Word.objects.filter(
                            dialect_note__contains=bk_marker
                        ).first()
                        if existing_word:
                            word_obj = existing_word
                            if word_obj.validation_status != Word.DRAFT:
                                stats['skipped_protected'] += 1
                            else:
                                stats['skipped_existing'] += 1
                        else:
                            word_obj = Word.objects.create(
                                beriya_text=beriya_erfe,
                                latin_transcription=(item.get('beriya_latin') or '').strip(),
                                french_translation=french,
                                category=cat_phrases,
                                difficulty=_map_cefr_to_difficulty(lesson_obj.get('level', '')),
                                difficulty_order=item_idx,
                                dialect_note=explanation_text,
                                validation_status=Word.DRAFT,
                                is_active=True,
                                available_offline=True,
                            )
                            stats['created'] += 1
                        unit.words.add(word_obj)
                        item_type = LessonItem.WORD

                    elif kind == 'lexique':
                        latin = (item.get('beriya_latin') or '').strip()
                        if not latin:
                            stats['rejected'] += 1
                            stats['rejection_reasons'].append(
                                f'Lexème {item_id} rejeté : beriya_latin manquant.'
                            )
                            continue
                        existing_word = Word.objects.filter(
                            dialect_note__contains=bk_marker
                        ).first()
                        if existing_word:
                            word_obj = existing_word
                            if word_obj.validation_status != Word.DRAFT:
                                stats['skipped_protected'] += 1
                            else:
                                stats['skipped_existing'] += 1
                        else:
                            word_obj = Word.objects.create(
                                beriya_text=latin,
                                latin_transcription=latin,
                                french_translation=french,
                                category=cat_lexique,
                                difficulty=_map_cefr_to_difficulty(lesson_obj.get('level', '')),
                                difficulty_order=item_idx,
                                dialect_note=f'{explanation_text} [DF/ADES 2007 — Erfe non généré]',
                                validation_status=Word.DRAFT,
                                is_active=True,
                                available_offline=True,
                            )
                            stats['created'] += 1
                        unit.words.add(word_obj)
                        item_type = LessonItem.WORD
                    else:
                        stats['rejected'] += 1
                        stats['rejection_reasons'].append(
                            f'Type de contenu inconnu pour {item_id}: {kind}'
                        )
                        continue

                    existing_item = LessonItem.objects.filter(
                        lesson=lesson,
                        explanation_fr__contains=bk_marker,
                    ).first()
                    if existing_item:
                        if lesson.status != Lesson.DRAFT:
                            stats['skipped_protected'] += 1
                        else:
                            stats['skipped_existing'] += 1
                        items_by_preprod_id[item_id] = existing_item
                    else:
                        li = LessonItem.objects.create(
                            lesson=lesson,
                            item_type=item_type,
                            character=char_obj,
                            word=word_obj,
                            title_fr=french[:255],
                            explanation_fr=explanation_text,
                            order_index=item_idx,
                            is_active=True,
                            available_offline=True,
                        )
                        items_by_preprod_id[item_id] = li
                        stats['created'] += 1

            for ex_idx, ex in enumerate(exercises_data, start=1):
                ex_id = (ex.get('id') or '').strip()
                lesson_id = (ex.get('lesson_id') or '').strip()
                ex_type = (ex.get('type') or '').strip()

                if lesson_id not in lessons_by_preprod_id:
                    continue

                if not ex_id or ex_type not in EX_TYPE_TO_QUESTION_TYPE:
                    stats['rejected'] += 1
                    stats['rejection_reasons'].append(
                        f'Exercice invalide ({ex_id or "?"}): type={ex_type}'
                    )
                    continue

                if ex.get('enabled') is True and not ex.get('audio_path') and ex_type in {'listen_select', 'listen_type'}:
                    stats['rejected'] += 1
                    stats['rejection_reasons'].append(
                        f'Exercice {ex_id} rejeté : exercice audio actif sans audio.'
                    )
                    continue

                options_list = ex.get('options') or []
                correct_index = ex.get('correct_index')
                if ex_type in {'mcq', 'listen_select'}:
                    if len(options_list) < 2 or correct_index is None or not (0 <= correct_index < len(options_list)):
                        stats['rejected'] += 1
                        stats['rejection_reasons'].append(
                            f'Exercice {ex_id} rejeté : options/correct_index invalides.'
                        )
                        continue

                lesson = lessons_by_preprod_id[lesson_id]
                unit = units_by_preprod_id[lesson_id]
                item_obj = items_by_preprod_id.get(ex.get('item_id'))
                bk_ex_marker = f'[bk_id:{ex_id}]'

                existing_q = QuizQuestion.objects.filter(
                    lesson=lesson,
                    explanation_fr__contains=bk_ex_marker,
                ).first()
                if existing_q:
                    if existing_q.status != QuizQuestion.DRAFT:
                        stats['skipped_protected'] += 1
                    else:
                        stats['skipped_existing'] += 1
                    continue

                q = QuizQuestion.objects.create(
                    unit=unit,
                    lesson=lesson,
                    question_type=EX_TYPE_TO_QUESTION_TYPE[ex_type],
                    difficulty=_map_cefr_to_difficulty(
                        unit.pedagogy_config.get('cefr_level', '')
                        if isinstance(unit.pedagogy_config, dict)
                        else ''
                    ),
                    prompt_fr=(ex.get('prompt') or '')[:255],
                    character=item_obj.character if item_obj else None,
                    word=item_obj.word if item_obj else None,
                    correct_text_answer=(ex.get('expected_text') or '')[:255],
                    explanation_fr=f"{bk_ex_marker} {ex.get('disabled_reason') or ''} (Source: {ex.get('source_ref') or ''})".strip(),
                    order_index=ex_idx,
                    min_options_required=2 if options_list else 0,
                    status=QuizQuestion.DRAFT,
                    is_active=False,
                    available_offline=True,
                )
                stats['created'] += 1

                for opt_idx, opt_text in enumerate(options_list, start=1):
                    QuizOption.objects.create(
                        question=q,
                        text_fr=str(opt_text)[:255],
                        is_correct=(opt_idx - 1 == correct_index),
                        order_index=opt_idx,
                    )
                    stats['created'] += 1

            if dry_run:
                transaction.set_rollback(True)

        mode_label = 'DRY-RUN (annulé)' if dry_run else 'IMPORT RÉEL'
        self.stdout.write(
            self.style.SUCCESS(
                f'[{mode_label}] package={stats["package_id"]} | '
                f'created={stats["created"]} | '
                f'skipped_existing={stats["skipped_existing"]} | '
                f'skipped_protected={stats["skipped_protected"]} | '
                f'rejected={stats["rejected"]}'
            )
        )
        for reason in stats['rejection_reasons']:
            self.stdout.write(self.style.WARNING(f'  REJET: {reason}'))
