# backend/core/management/commands/seed_initial_content.py

from django.core.management.base import BaseCommand
from django.db.models import Q

def existing_fields(model):
    return {field.name for field in model._meta.fields}


def clean_defaults(model, data):
    fields = existing_fields(model)
    return {key: value for key, value in data.items() if key in fields}


def set_existing_attrs(obj, data):
    fields = existing_fields(obj.__class__)
    changed = False

    for key, value in data.items():
        if key in fields and getattr(obj, key, None) != value:
            setattr(obj, key, value)
            changed = True

    if changed:
        obj.save()

    return obj


class Command(BaseCommand):
    help = "Seed initial Beriyar Kedebideri content for Render."

    def handle(self, *args, **options):
        from alphabet.models import Character
        from learning.models import LearningTheme, LearningUnit
        from lessons.models import Lesson, LessonItem
        from quizzes.models import QuizQuestion, QuizOption

        self.stdout.write("Seeding initial content...")

        # 1. Alphabet Beriya Erfe
        # Unicode range: U+16EA0..U+16EB8 and U+16EBB..U+16ED3
        # Nettoyage : retirer les 25 formes non officielles créées par erreur.
        Character.objects.filter(
            Q(symbol__gte=chr(0x16EBB), symbol__lte=chr(0x16ED3))
            | Q(unicode_code__gte="U+16EBB", unicode_code__lte="U+16ED3")
        ).delete()

        # Alphabet officiel : 25 caractères seulement.
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
                set_existing_attrs(character, data)
            else:
                character = Character.objects.create(**data)

            characters.append(character)

        # 2. Theme
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

        theme, created = LearningTheme.objects.get_or_create(
            slug="alphabet-beriya-erfe",
            defaults=theme_defaults,
        )

        if not created:
            set_existing_attrs(theme, theme_defaults)

        self.stdout.write(self.style.SUCCESS("Theme OK."))

        # 3. Unit
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

        unit, created = LearningUnit.objects.get_or_create(
            slug="premiers-signes",
            defaults=unit_defaults,
        )

        if not created:
            set_existing_attrs(unit, unit_defaults)

        # Add characters to unit if ManyToMany exists
        if hasattr(unit, "characters"):
            unit.characters.set(characters[:10])

        self.stdout.write(self.style.SUCCESS("Unit OK."))

        # 4. Lesson
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

        lesson, created = Lesson.objects.get_or_create(
            slug="ecouter-et-reconnaitre",
            defaults=lesson_defaults,
        )

        if not created:
            set_existing_attrs(lesson, lesson_defaults)

        self.stdout.write(self.style.SUCCESS("Lesson OK."))

        # 5. Lesson items
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

            item, created = LessonItem.objects.get_or_create(
                lesson=lesson,
                character=character,
                defaults=item_defaults,
            )

            if not created:
                set_existing_attrs(item, item_defaults)

        self.stdout.write(self.style.SUCCESS("Lesson items OK."))

        # 6. Quiz questions + options
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

            question, created = QuizQuestion.objects.get_or_create(
                unit=unit,
                lesson=lesson,
                character=character,
                question_type="audio_to_character",
                defaults=question_defaults,
            )

            if not created:
                set_existing_attrs(question, question_defaults)

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
                    "is_correct": option_character.id == character.id,
                    "order": option_index,
                    "order_index": option_index,
                })

                option, created = QuizOption.objects.get_or_create(
                    question=question,
                    character=option_character,
                    defaults=option_defaults,
                )

                if not created:
                    set_existing_attrs(option, option_defaults)

        self.stdout.write(self.style.SUCCESS("Quiz OK."))
        self.stdout.write(self.style.SUCCESS("Initial content seed completed."))