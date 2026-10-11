from django.core.management.base import BaseCommand
from alphabet.models import Character
from vocabulary.models import Word, WordCategory
from learning.models import LearningTheme, LearningUnit


class Command(BaseCommand):
    help = "Initialise ou met à jour les données de référence pour l'Unité 1 (Learning Core)."

    def handle(self, *args, **options):
        self.stdout.write("Initialisation des données d'alphabétisation active...")

        # 1. Mise à jour des caractères avec tracés vectoriels et phonèmes IPA
        char_b, _ = Character.objects.get_or_create(
            symbol='𖺡',
            defaults={'unicode_code': 'U+16EA1'},
        )
        char_b.latin_grapheme = 'b'
        char_b.phoneme_ipa = 'b'
        char_b.character_type = Character.CONSONANT
        char_b.name_fr = 'Consonne B'
        char_b.stroke_path_data = {
            'strokes': [
                [{'x': 0.22, 'y': 0.28}, {'x': 0.50, 'y': 0.88}],
                [{'x': 0.78, 'y': 0.28}, {'x': 0.50, 'y': 0.88}],
                [{'x': 0.50, 'y': 0.28}, {'x': 0.50, 'y': 0.88}],
                [{'x': 0.32, 'y': 0.58}, {'x': 0.68, 'y': 0.58}],
            ]
        }
        char_b.save()
        self.stdout.write(f"Caractère configuré : {char_b.symbol} (/b/)")

        char_e, _ = Character.objects.get_or_create(
            symbol='𖺣',
            defaults={'unicode_code': 'U+16EA3'},
        )
        char_e.latin_grapheme = 'e'
        char_e.phoneme_ipa = 'e'
        char_e.character_type = Character.VOWEL
        char_e.name_fr = 'Voyelle E'
        char_e.stroke_path_data = {
            'strokes': [
                [{'x': 0.60, 'y': 0.25}, {'x': 0.36, 'y': 0.25}],
                [{'x': 0.36, 'y': 0.25}, {'x': 0.36, 'y': 0.50}],
                [{'x': 0.36, 'y': 0.50}, {'x': 0.64, 'y': 0.50}],
                [{'x': 0.64, 'y': 0.50}, {'x': 0.64, 'y': 0.76}],
                [{'x': 0.64, 'y': 0.76}, {'x': 0.36, 'y': 0.76}],
            ]
        }
        char_e.save()
        self.stdout.write(f"Caractère configuré : {char_e.symbol} (/e/)")

        char_t, _ = Character.objects.get_or_create(
            symbol='𖺵',
            defaults={'unicode_code': 'U+16EB5'},
        )
        char_t.latin_grapheme = 't'
        char_t.phoneme_ipa = 't'
        char_t.character_type = Character.CONSONANT
        char_t.name_fr = 'Consonne T'
        char_t.stroke_path_data = {
            'strokes': [
                [{'x': 0.72, 'y': 0.26}, {'x': 0.48, 'y': 0.56}],
                [{'x': 0.48, 'y': 0.56}, {'x': 0.48, 'y': 0.88}],
                [{'x': 0.28, 'y': 0.56}, {'x': 0.68, 'y': 0.56}],
            ]
        }
        char_t.save()
        self.stdout.write(f"Caractère configuré : {char_t.symbol} (/t/)")

        # 2. Mot cible : "be" (𖺡𖺣 - pays)
        cat, _ = WordCategory.objects.get_or_create(
            slug='societe-et-territoire',
            defaults={'name_fr': 'Société et Territoire'},
        )

        word_be, _ = Word.objects.get_or_create(
            beriya_text='𖺡𖺣',
            defaults={
                'latin_transcription': 'be',
                'french_translation': 'pays',
                'orthographic_pattern': 'CV',
                'syllabic_structure': 'CV',
                'category': cat,
                'difficulty': Word.BEGINNER,
                'oral_prompt': 'Écoute le mot "be" qui signifie le pays.',
            },
        )
        word_be.french_translation = 'pays'
        word_be.latin_transcription = 'be'
        word_be.orthographic_pattern = 'CV'
        word_be.syllabic_structure = 'CV'
        word_be.category = cat
        word_be.save()
        self.stdout.write(f"Mot configuré : {word_be.beriya_text} ({word_be.latin_transcription} - {word_be.french_translation})")

        # 3. Thème et Unité 1
        theme, _ = LearningTheme.objects.get_or_create(
            slug='alphabetisation-active',
            defaults={
                'title_fr': 'Méthode Active Beriya Erfe',
                'description_fr': 'Transformation de la langue orale en code écrit.',
                'level': LearningTheme.BEGINNER,
                'order_index': 1,
            },
        )

        unit, created = LearningUnit.objects.get_or_create(
            slug='unite-1-be',
            defaults={
                'theme': theme,
                'title_fr': 'Unité 1 : Les premières lettres et le mot "be"',
                'description_fr': 'Découverte des sons /b/ et /e/, tracé gestuel, fusion et encodage au clavier.',
                'level': LearningUnit.BEGINNER,
                'order_index': 1,
                'estimated_minutes': 4,
                'status': LearningUnit.PUBLISHED,
                'is_active': True,
                'available_offline': True,
                'target_word': word_be,
                'weight_recognition': 35,
                'weight_tracing': 35,
                'weight_encoding': 30,
            },
        )

        unit.theme = theme
        unit.title_fr = 'Unité 1 : Les premières lettres et le mot "be"'
        unit.target_word = word_be
        unit.enable_tracing = False
        unit.weight_recognition = 50
        unit.weight_tracing = 0
        unit.weight_encoding = 50
        unit.status = LearningUnit.PUBLISHED
        unit.is_active = True
        unit.save()

        unit.characters.set([char_b, char_e])
        unit.distractor_characters.set([char_t])
        unit.words.set([word_be])

        self.stdout.write(self.style.SUCCESS(
            f"Unité 1 configurée avec succès ! (ID: {unit.id}, slug: {unit.slug})"
        ))
        steps = unit.generate_core_flow()
        self.stdout.write(f"Nombre d'étapes Unité 1 générées dynamiquement : {len(steps)}")

        # 4. Caractères supplémentaires : A (𖺠) et D (𖺢)
        char_a, _ = Character.objects.get_or_create(
            symbol='𖺠',
            defaults={'unicode_code': 'U+16EA0'},
        )
        char_a.latin_grapheme = 'a'
        char_a.phoneme_ipa = 'a'
        char_a.character_type = Character.VOWEL
        char_a.name_fr = 'Voyelle A'
        char_a.order_index = 1
        char_a.save()
        self.stdout.write(f"Caractère configuré : {char_a.symbol} (/a/)")

        char_d, _ = Character.objects.get_or_create(
            symbol='𖺢',
            defaults={'unicode_code': 'U+16EA2'},
        )
        char_d.latin_grapheme = 'd'
        char_d.phoneme_ipa = 'd'
        char_d.character_type = Character.CONSONANT
        char_d.name_fr = 'Consonne D'
        char_d.order_index = 3
        char_d.save()
        self.stdout.write(f"Caractère configuré : {char_d.symbol} (/d/)")

        # 5. Mots cibles supplémentaires : "ta" (𖺵𖺠) et "de" (𖺢𖺣)
        word_ta, _ = Word.objects.get_or_create(
            beriya_text='𖺵𖺠',
            defaults={
                'latin_transcription': 'ta',
                'french_translation': 'maison',
                'orthographic_pattern': 'CV',
                'syllabic_structure': 'CV',
                'category': cat,
                'difficulty': Word.BEGINNER,
                'oral_prompt': 'Écoute le mot "ta" qui signifie la maison.',
            },
        )
        word_ta.latin_transcription = 'ta'
        word_ta.french_translation = 'maison'
        word_ta.save()
        self.stdout.write(f"Mot configuré : {word_ta.beriya_text} ({word_ta.latin_transcription} - {word_ta.french_translation})")

        word_de, _ = Word.objects.get_or_create(
            beriya_text='𖺢𖺣',
            defaults={
                'latin_transcription': 'de',
                'french_translation': 'terre',
                'orthographic_pattern': 'CV',
                'syllabic_structure': 'CV',
                'category': cat,
                'difficulty': Word.BEGINNER,
                'oral_prompt': 'Écoute le mot "de" qui signifie la terre.',
            },
        )
        word_de.latin_transcription = 'de'
        word_de.french_translation = 'terre'
        word_de.save()
        self.stdout.write(f"Mot configuré : {word_de.beriya_text} ({word_de.latin_transcription} - {word_de.french_translation})")

        # 6. Unité 2 : Consonne Te (𖺵) et Voyelle A (𖺠) -> Mot "ta"
        unit_2, _ = LearningUnit.objects.get_or_create(
            slug='unite-2-ta',
            defaults={
                'theme': theme,
                'title_fr': 'Unité 2 : La consonne Te (𖺵) et le mot "ta"',
                'description_fr': 'Découverte des sons /t/ et /a/, fusion syllabique et encodage du mot "ta" (maison).',
                'level': LearningUnit.BEGINNER,
                'order_index': 2,
                'estimated_minutes': 4,
                'status': LearningUnit.PUBLISHED,
                'is_active': True,
                'available_offline': True,
                'target_word': word_ta,
                'enable_tracing': False,
                'weight_recognition': 50,
                'weight_tracing': 0,
                'weight_encoding': 50,
            },
        )
        unit_2.theme = theme
        unit_2.title_fr = 'Unité 2 : La consonne Te (𖺵) et le mot "ta"'
        unit_2.target_word = word_ta
        unit_2.enable_tracing = False
        unit_2.weight_recognition = 50
        unit_2.weight_tracing = 0
        unit_2.weight_encoding = 50
        unit_2.order_index = 2
        unit_2.status = LearningUnit.PUBLISHED
        unit_2.is_active = True
        unit_2.save()

        unit_2.characters.set([char_t, char_a])
        unit_2.distractor_characters.set([char_b, char_e])
        unit_2.words.set([word_ta])

        self.stdout.write(self.style.SUCCESS(
            f"Unité 2 configurée avec succès ! (ID: {unit_2.id}, slug: {unit_2.slug})"
        ))
        steps_2 = unit_2.generate_core_flow()
        self.stdout.write(f"Nombre d'étapes Unité 2 générées dynamiquement : {len(steps_2)}")

        # 7. Unité 3 : Consonne De (𖺢) et Voyelle E (𖺣) -> Mot "de"
        unit_3, _ = LearningUnit.objects.get_or_create(
            slug='unite-3-de',
            defaults={
                'theme': theme,
                'title_fr': 'Unité 3 : La consonne De (𖺢) et le mot "de"',
                'description_fr': 'Découverte des sons /d/ et /e/, fusion syllabique et encodage du mot "de" (terre).',
                'level': LearningUnit.BEGINNER,
                'order_index': 3,
                'estimated_minutes': 4,
                'status': LearningUnit.PUBLISHED,
                'is_active': True,
                'available_offline': True,
                'target_word': word_de,
                'enable_tracing': False,
                'weight_recognition': 50,
                'weight_tracing': 0,
                'weight_encoding': 50,
            },
        )
        unit_3.theme = theme
        unit_3.title_fr = 'Unité 3 : La consonne De (𖺢) et le mot "de"'
        unit_3.target_word = word_de
        unit_3.enable_tracing = False
        unit_3.weight_recognition = 50
        unit_3.weight_tracing = 0
        unit_3.weight_encoding = 50
        unit_3.order_index = 3
        unit_3.status = LearningUnit.PUBLISHED
        unit_3.is_active = True
        unit_3.save()

        unit_3.characters.set([char_d, char_e])
        unit_3.distractor_characters.set([char_t, char_a])
        unit_3.words.set([word_de])

        self.stdout.write(self.style.SUCCESS(
            f"Unité 3 configurée avec succès ! (ID: {unit_3.id}, slug: {unit_3.slug})"
        ))
        steps_3 = unit_3.generate_core_flow()
        self.stdout.write(f"Nombre d'étapes Unité 3 générées dynamiquement : {len(steps_3)}")
