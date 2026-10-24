# backend/core/management/commands/seed_initial_content.py

from django.core.management.base import BaseCommand
from django.db import transaction
from django.db.models import Q


def existing_fields(model):
    return {field.name for field in model._meta.fields}


def clean_defaults(model, data):
    fields = existing_fields(model)
    return {key: value for key, value in data.items() if key in fields}


def set_existing_attrs(obj, data, dry_run=False):
    fields = existing_fields(obj.__class__)
    changed = False

    for key, value in data.items():
        if key in fields and getattr(obj, key, None) != value:
            setattr(obj, key, value)
            changed = True

    if changed and not dry_run:
        obj.save()

    return obj, changed


class Command(BaseCommand):
    help = "Seed initial Beriyar Kedebideri content for Render (non-destructive by default)."

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            dest='dry_run',
            default=False,
            help="Simule l'exécution sans modifier la base de données et affiche un rapport détaillé.",
        )
        parser.add_argument(
            '--clean-unofficial-characters',
            action='store_true',
            dest='clean_unofficial_characters',
            default=False,
            help="Archive (is_active=False) ou nettoie explicitement les caractères U+16EBB..U+16ED3 (désactivé par défaut pour préserver le corpus).",
        )

    def handle(self, *args, **options):
        from alphabet.models import Character
        from learning.models import LearningTheme, LearningUnit
        from lessons.models import Lesson, LessonItem
        from quizzes.models import QuizQuestion, QuizOption

        dry_run = options.get('dry_run', False)
        clean_unofficial = options.get('clean_unofficial_characters', False)

        if dry_run:
            self.stdout.write(self.style.WARNING("=== MODE SIMULATION (--dry-run) : AUCUNE ÉCRITURE ==="))

        self.stdout.write("Vérification et initialisation du contenu de base...")

        stats = {
            'characters_created': 0,
            'characters_updated': 0,
            'unofficial_found': 0,
            'unofficial_archived': 0,
            'themes_created': 0,
            'themes_updated': 0,
            'units_created': 0,
            'units_updated': 0,
            'lessons_created': 0,
            'lessons_updated': 0,
            'lesson_items_created': 0,
            'lesson_items_updated': 0,
            'quiz_questions_created': 0,
            'quiz_questions_updated': 0,
            'quiz_options_created': 0,
            'quiz_options_updated': 0,
        }

        # 1. Préservation du corpus : PAS de suppression automatique (A08)
        unofficial_qs = Character.objects.filter(
            Q(symbol__gte=chr(0x16EBB), symbol__lte=chr(0x16ED3))
            | Q(unicode_code__gte="U+16EBB", unicode_code__lte="U+16ED3")
        )
        stats['unofficial_found'] = unofficial_qs.count()

        if stats['unofficial_found'] > 0:
            if clean_unofficial:
                if not dry_run:
                    # Règle A08 : désactivation / archivage plutôt que suppression brute
                    updated_cnt = unofficial_qs.update(is_active=False)
                    stats['unofficial_archived'] = updated_cnt
                    self.stdout.write(self.style.WARNING(
                        f"Archivage de {updated_cnt} caractères non officiels (is_active=False)."
                    ))
                else:
                    stats['unofficial_archived'] = stats['unofficial_found']
                    self.stdout.write(self.style.NOTICE(
                        f"[dry-run] {stats['unofficial_found']} caractères non officiels seraient archivés."
                    ))
            else:
                self.stdout.write(self.style.NOTICE(
                    f"{stats['unofficial_found']} caractères hors plage officielle détectés. "
                    "Conservés intacts pour protéger l'historique (utiliser --clean-unofficial-characters si souhaité)."
                ))

        # 2. Caractères officiels (U+16EA0..U+16EB8)
        codepoints = list(range(0x16EA0, 0x16EB9))
        characters = []

        for index, codepoint in enumerate(codepoints, start=1):
            symbol = chr(codepoint)
            unicode_code = f"U+{codepoint:04X}"
            name = f"Beriya Erfe {index}"

            data = clean_defaults(Character, {
                "symbol": symbol,
                "unicode_code": unicode_code,
                "name": name,
                "latin_transcription": f"char-{index}",
                "arabic_transcription": "",
                "ipa": "",
                "description": f"Caractère officiel Beriya Erfe numéro {index}.",
                "order": index,
                "order_index": index,
                "is_active": True,
                "available_offline": True,
            })

            query = Q(symbol=symbol)
            if "unicode_code" in existing_fields(Character):
                query = query | Q(unicode_code=unicode_code)

            character = Character.objects.filter(query).first()

            if character:
                character, changed = set_existing_attrs(character, data, dry_run=dry_run)
                if changed:
                    stats['characters_updated'] += 1
            else:
                if not dry_run:
                    character = Character.objects.create(**data)
                else:
                    character = Character(**data)
                stats['characters_created'] += 1

            characters.append(character)

        # 3. Thème
        theme_defaults = clean_defaults(LearningTheme, {
            "title_fr": "Alphabet Beriya Erfe",
            "title_en": "Beriya Erfe Alphabet",
            "title_ar": "أبجدية بيريَا إرفي",
            "description_fr": "Apprendre progressivement les premiers caractères Beriya Erfe.",
            "description_en": "Learn the first Beriya Erfe characters step by step.",
            "description_ar": "تعلّم حروف بيريَا إرفي تدريجياً.",
            "level": "beginner",
            "order": 1,
            "order_index": 1,
            "is_active": True,
            "available_offline": True,
        })

        theme = LearningTheme.objects.filter(slug="alphabet-beriya-erfe").first()
        if not theme:
            if not dry_run:
                theme = LearningTheme.objects.create(slug="alphabet-beriya-erfe", **theme_defaults)
            else:
                theme = LearningTheme(slug="alphabet-beriya-erfe", **theme_defaults)
            stats['themes_created'] += 1
        else:
            theme, changed = set_existing_attrs(theme, theme_defaults, dry_run=dry_run)
            if changed:
                stats['themes_updated'] += 1

        # 4. Unité
        unit_defaults = clean_defaults(LearningUnit, {
            "theme": theme,
            "title_fr": "Premiers signes",
            "title_en": "First signs",
            "title_ar": "العلامات الأولى",
            "description_fr": "Découvrir les premiers caractères de l’écriture Beriya Erfe.",
            "description_en": "Discover the first characters of the Beriya Erfe script.",
            "description_ar": "اكتشاف الحروف الأولى من كتابة بيريَا إرفي.",
            "level": "beginner",
            "order": 1,
            "order_index": 1,
            "is_active": True,
            "available_offline": True,
        })

        unit = LearningUnit.objects.filter(slug="premiers-signes").first()
        if not unit:
            if not dry_run:
                unit = LearningUnit.objects.create(slug="premiers-signes", **unit_defaults)
            else:
                unit = LearningUnit(slug="premiers-signes", **unit_defaults)
            stats['units_created'] += 1
        else:
            unit, changed = set_existing_attrs(unit, unit_defaults, dry_run=dry_run)
            if changed:
                stats['units_updated'] += 1

        if not dry_run and hasattr(unit, "characters") and unit.pk:
            # Association des caractères sans casser les liaisons existantes
            current_ids = set(unit.characters.values_list('id', flat=True))
            new_ids = {c.id for c in characters[:10] if c.id}
            if not new_ids.issubset(current_ids):
                unit.characters.add(*[c for c in characters[:10] if c.id])

        # 5. Leçon
        lesson_defaults = clean_defaults(Lesson, {
            "unit": unit,
            "title_fr": "Écouter et reconnaître",
            "title_en": "Listen and recognize",
            "title_ar": "استمع وتعرّف",
            "short_description_fr": "Première leçon orale pour reconnaître les signes.",
            "short_description_en": "First oral lesson to recognize signs.",
            "short_description_ar": "الدرس الشفهي الأول للتعرّف على العلامات.",
            "description_fr": "Cette leçon introduit les premiers signes Beriya Erfe.",
            "description_en": "This lesson introduces the first Beriya Erfe signs.",
            "description_ar": "يقدّم هذا الدرس أول علامات بيريَا إرفي.",
            "level": "beginner",
            "order": 1,
            "order_index": 1,
            "is_active": True,
            "available_offline": True,
        })

        lesson = Lesson.objects.filter(slug="ecouter-et-reconnaitre").first()
        if not lesson:
            if not dry_run:
                lesson = Lesson.objects.create(slug="ecouter-et-reconnaitre", **lesson_defaults)
            else:
                lesson = Lesson(slug="ecouter-et-reconnaitre", **lesson_defaults)
            stats['lessons_created'] += 1
        else:
            lesson, changed = set_existing_attrs(lesson, lesson_defaults, dry_run=dry_run)
            if changed:
                stats['lessons_updated'] += 1

        # 6. Éléments de leçon
        for index, character in enumerate(characters[:10], start=1):
            item_defaults = clean_defaults(LessonItem, {
                "lesson": lesson,
                "character": character,
                "item_type": "character",
                "oral_prompt_fr": f"Écoute et observe le signe {index}.",
                "oral_prompt_en": f"Listen and look at sign {index}.",
                "oral_prompt_ar": f"استمع وانظر إلى العلامة {index}.",
                "explanation_fr": f"Ce signe est le caractère Beriya Erfe numéro {index}.",
                "explanation_en": f"This sign is Beriya Erfe character number {index}.",
                "explanation_ar": f"هذه العلامة هي حرف بيريَا إرفي رقم {index}.",
                "writing_hint": "Observe la forme puis répète.",
                "order": index,
                "order_index": index,
                "is_active": True,
                "available_offline": True,
            })

            item = None
            if lesson.pk and character.pk:
                item = LessonItem.objects.filter(lesson=lesson, character=character).first()

            if not item:
                if not dry_run and lesson.pk and character.pk:
                    LessonItem.objects.create(**item_defaults)
                stats['lesson_items_created'] += 1
            else:
                item, changed = set_existing_attrs(item, item_defaults, dry_run=dry_run)
                if changed:
                    stats['lesson_items_updated'] += 1

        # 7. Questions et options de quiz
        for index, character in enumerate(characters[:5], start=1):
            question_defaults = clean_defaults(QuizQuestion, {
                "unit": unit,
                "lesson": lesson,
                "question_type": "audio_to_character",
                "difficulty": 1,
                "prompt_fr": "Choisis le bon caractère.",
                "prompt_en": "Choose the correct character.",
                "prompt_ar": "اختر الحرف الصحيح.",
                "oral_prompt_fr": "Écoute puis choisis le signe correspondant.",
                "oral_prompt_en": "Listen and choose the matching sign.",
                "oral_prompt_ar": "استمع ثم اختر العلامة المناسبة.",
                "character": character,
                "order": index,
                "order_index": index,
                "points": 1,
                "min_options_required": 4,
                "status": "published",
                "is_active": True,
                "available_offline": True,
            })

            question = None
            if unit.pk and lesson.pk and character.pk:
                question = QuizQuestion.objects.filter(
                    unit=unit,
                    lesson=lesson,
                    character=character,
                    question_type="audio_to_character",
                ).first()

            if not question:
                if not dry_run and unit.pk and lesson.pk and character.pk:
                    question = QuizQuestion.objects.create(**question_defaults)
                else:
                    question = QuizQuestion(**question_defaults)
                stats['quiz_questions_created'] += 1
            else:
                question, changed = set_existing_attrs(question, question_defaults, dry_run=dry_run)
                if changed:
                    stats['quiz_questions_updated'] += 1

            option_chars = characters[index - 1:index + 3]
            while len(option_chars) < 4:
                option_chars.append(characters[len(option_chars)])

            for option_index, option_character in enumerate(option_chars, start=1):
                option_defaults = clean_defaults(QuizOption, {
                    "question": question,
                    "character": option_character,
                    "text_fr": option_character.symbol,
                    "text_en": option_character.symbol,
                    "text_ar": option_character.symbol,
                    "is_correct": option_character.id == character.id if (option_character.id and character.id) else False,
                    "order": option_index,
                    "order_index": option_index,
                })

                option = None
                if question.pk and option_character.pk:
                    option = QuizOption.objects.filter(
                        question=question,
                        character=option_character,
                    ).first()

                if not option:
                    if not dry_run and question.pk and option_character.pk:
                        QuizOption.objects.create(**option_defaults)
                    stats['quiz_options_created'] += 1
                else:
                    option, changed = set_existing_attrs(option, option_defaults, dry_run=dry_run)
                    if changed:
                        stats['quiz_options_updated'] += 1

        # Rapport d'exécution
        self.stdout.write("----------------------------------------")
        self.stdout.write(f"Caractères créés : {stats['characters_created']} | mis à jour : {stats['characters_updated']}")
        self.stdout.write(f"Thèmes créés : {stats['themes_created']} | mis à jour : {stats['themes_updated']}")
        self.stdout.write(f"Unités créées : {stats['units_created']} | mis à jour : {stats['units_updated']}")
        self.stdout.write(f"Leçons créées : {stats['lessons_created']} | mis à jour : {stats['lessons_updated']}")
        self.stdout.write(f"Éléments créés : {stats['lesson_items_created']} | mis à jour : {stats['lesson_items_updated']}")
        self.stdout.write(f"Questions quiz créées : {stats['quiz_questions_created']} | mises à jour : {stats['quiz_questions_updated']}")
        self.stdout.write(f"Options quiz créées : {stats['quiz_options_created']} | mises à jour : {stats['quiz_options_updated']}")
        self.stdout.write("----------------------------------------")

        if dry_run:
            self.stdout.write(self.style.SUCCESS("Simulation seed_initial_content terminée avec succès (aucune écriture en base)."))
        else:
            self.stdout.write(self.style.SUCCESS("Initialisation du contenu terminée avec succès sans suppression destructive."))
