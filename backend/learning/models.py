from django.db import models

from alphabet.models import Character
from vocabulary.models import Word


class LearningTheme(models.Model):
    BEGINNER = 'beginner'
    INTERMEDIATE = 'intermediate'
    ADVANCED = 'advanced'

    LEVEL_CHOICES = [
        (BEGINNER, 'Beginner'),
        (INTERMEDIATE, 'Intermediate'),
        (ADVANCED, 'Advanced'),
    ]

    DRAFT = 'draft'
    REVIEW = 'review'
    VALIDATED = 'validated'
    PUBLISHED = 'published'
    ARCHIVED = 'archived'

    STATUS_CHOICES = [
        (DRAFT, 'Draft'),
        (REVIEW, 'Review'),
        (VALIDATED, 'Validated'),
        (PUBLISHED, 'Published'),
        (ARCHIVED, 'Archived'),
    ]

    slug = models.SlugField(unique=True)

    title_fr = models.CharField(max_length=255)
    title_en = models.CharField(max_length=255, blank=True)
    title_ar = models.CharField(max_length=255, blank=True)

    description_fr = models.TextField(blank=True)
    description_en = models.TextField(blank=True)
    description_ar = models.TextField(blank=True)

    level = models.CharField(
        max_length=30,
        choices=LEVEL_CHOICES,
        default=BEGINNER,
    )

    cover_image = models.ImageField(
        upload_to='learning/themes/covers/',
        blank=True,
        null=True,
    )

    order_index = models.PositiveIntegerField(default=0)

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=DRAFT,
    )

    is_active = models.BooleanField(default=True)
    available_offline = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['level', 'order_index', 'title_fr']
        verbose_name = 'Learning Theme'
        verbose_name_plural = 'Learning Themes'

    def __str__(self):
        return self.title_fr


class LearningUnit(models.Model):
    BEGINNER = 'beginner'
    INTERMEDIATE = 'intermediate'
    ADVANCED = 'advanced'

    LEVEL_CHOICES = [
        (BEGINNER, 'Beginner'),
        (INTERMEDIATE, 'Intermediate'),
        (ADVANCED, 'Advanced'),
    ]

    DRAFT = 'draft'
    REVIEW = 'review'
    VALIDATED = 'validated'
    PUBLISHED = 'published'
    ARCHIVED = 'archived'

    STATUS_CHOICES = [
        (DRAFT, 'Draft'),
        (REVIEW, 'Review'),
        (VALIDATED, 'Validated'),
        (PUBLISHED, 'Published'),
        (ARCHIVED, 'Archived'),
    ]

    theme = models.ForeignKey(
        LearningTheme,
        on_delete=models.CASCADE,
        related_name='units',
    )

    slug = models.SlugField(unique=True)

    title_fr = models.CharField(max_length=255)
    title_en = models.CharField(max_length=255, blank=True)
    title_ar = models.CharField(max_length=255, blank=True)

    description_fr = models.TextField(blank=True)
    description_en = models.TextField(blank=True)
    description_ar = models.TextField(blank=True)

    level = models.CharField(
        max_length=30,
        choices=LEVEL_CHOICES,
        default=BEGINNER,
    )

    characters = models.ManyToManyField(
        Character,
        blank=True,
        related_name='learning_units',
    )

    words = models.ManyToManyField(
        Word,
        blank=True,
        related_name='learning_units',
    )

    target_word = models.ForeignKey(
        Word,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='target_in_units',
        help_text="Mot cible principal de l'unité pour la fusion et l'encodage au clavier.",
    )

    distractor_characters = models.ManyToManyField(
        Character,
        blank=True,
        related_name='distractor_in_units',
        help_text="Caractères distracteurs pour les exercices de discrimination et le clavier restreint.",
    )

    weight_recognition = models.PositiveIntegerField(
        default=35,
        help_text="Pondération pour la reconnaissance visuelle/auditive (%).",
    )

    weight_tracing = models.PositiveIntegerField(
        default=35,
        help_text="Pondération pour le geste d'écriture / tracé vectoriel (%).",
    )

    weight_encoding = models.PositiveIntegerField(
        default=30,
        help_text="Pondération pour l'encodage au clavier (%).",
    )

    pedagogy_config = models.JSONField(
        default=dict,
        blank=True,
        help_text="Configuration pédagogique avancée (règles de fusion, sons personnalisés).",
    )

    enable_tracing = models.BooleanField(
        default=False,
        help_text="Activer l'exercice de tracé au doigt (désactivé par défaut au profit de la lecture et du clavier).",
    )

    estimated_minutes = models.PositiveIntegerField(default=5)

    min_score_to_pass = models.PositiveIntegerField(
        default=70,
        help_text='Score minimum en pourcentage pour valider l’unité.',
    )

    order_index = models.PositiveIntegerField(default=0)

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=DRAFT,
    )

    is_active = models.BooleanField(default=True)
    available_offline = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['theme', 'order_index', 'title_fr']
        verbose_name = 'Learning Unit'
        verbose_name_plural = 'Learning Units'

    def __str__(self):
        return f'{self.theme.title_fr} — {self.title_fr}'

    @property
    def core_flow(self):
        return self.generate_core_flow()

    def generate_core_flow(self, request=None, only_published=None):
        """
        Génère dynamiquement la séquence complète des micro-étapes d'alphabétisation
        active (Learning Core) pour cette unité :
        1. Découverte auditive (phonème pur)
        2. Discrimination visuelle (sélection du glyphe cible)
        3. Geste d'écriture (tracé vectoriel guidé)
        ... pour chaque caractère introduit, puis :
        4. Fusion syllabique (consonne + voyelle)
        5. Décodage du mot réel (sens, oral, image)
        6. Encodage au clavier restreint (saisie autonome)
        7. Bilan & célébration (score calculé selon pondérations configurées)
        """
        from core.permissions import is_staff_preview
        from audio_assets.utils import build_file_url, get_linked_audio_url

        if only_published is None:
            if request is not None:
                only_published = not is_staff_preview(request)
            else:
                only_published = False

        steps = []
        if only_published:
            chars = list(self.characters.filter(is_active=True, validation_status='published').order_by('order_index', 'id'))
            distractors = list(self.distractor_characters.filter(is_active=True, validation_status='published').order_by('order_index', 'id'))
            target_w = self.target_word
            if target_w and (not target_w.is_active or target_w.validation_status != 'published'):
                target_w = None
            if not target_w:
                target_w = self.words.filter(is_active=True, validation_status='published').first()
        else:
            chars = list(self.characters.filter(is_active=True).order_by('order_index', 'id'))
            distractors = list(self.distractor_characters.filter(is_active=True).order_by('order_index', 'id'))
            target_w = self.target_word or self.words.filter(is_active=True).first()

        # Phase par caractère introduit
        for idx, char in enumerate(chars):
            # 1. Découverte Phonème
            p_audio = get_linked_audio_url(char, 'phoneme', request=request) or get_linked_audio_url(char, 'normal', request=request)
            l_audio = get_linked_audio_url(char, 'letter_name', request=request)
            type_label = 'la voyelle' if char.character_type == Character.VOWEL else 'la consonne' if char.character_type == Character.CONSONANT else 'le caractère'
            ipa_str = f" /{char.phoneme_ipa}/" if char.phoneme_ipa and char.phoneme_ipa != 'À_VALIDER' else ""

            steps.append({
                'index': len(steps),
                'step_type': 'discovery',
                'symbol': char.symbol,
                'unicode_code': char.unicode_code,
                'character_type': char.character_type,
                'phoneme_ipa': char.phoneme_ipa,
                'label': f"Écoute et découvre {type_label}{ipa_str}",
                'audio_url': p_audio,
                'letter_name_audio_url': l_audio,
                'weight_category': 'recognition',
            })

            # 2. Discrimination visuelle
            # Choix d'un distracteur pour l'exercice
            other_char = None
            for candidate in (chars[idx + 1:] + chars[:idx]):
                if candidate.symbol != char.symbol:
                    other_char = candidate
                    break
            if not other_char and distractors:
                other_char = distractors[0]

            if other_char:
                steps.append({
                    'index': len(steps),
                    'step_type': 'discrimination',
                    'target_symbol': char.symbol,
                    'other_symbol': other_char.symbol,
                    'phoneme_ipa': char.phoneme_ipa,
                    'instruction': f"Touche {type_label}{ipa_str}",
                    'audio_url': p_audio,
                    'weight_category': 'recognition',
                })

            # 3. Tracé Vectoriel (optionnel, activé si enable_tracing est True)
            if self.enable_tracing:
                steps.append({
                    'index': len(steps),
                    'step_type': 'tracing',
                    'symbol': char.symbol,
                    'unicode_code': char.unicode_code,
                    'character_type': char.character_type,
                    'stroke_path_data': char.stroke_path_data or {},
                    'instruction': f"Trace le caractère {char.symbol} du bout du doigt",
                    'weight_category': 'tracing',
                })

        # Phase combinatoire / mot réel si disponible
        if target_w:
            w_normal_audio = get_linked_audio_url(target_w, 'normal', request=request)
            w_syllable_audio = get_linked_audio_url(target_w, 'syllable', request=request) or get_linked_audio_url(target_w, 'syllable_breakdown', request=request) or w_normal_audio
            w_image = build_file_url(target_w.image, request=request)

            # 4. Fusion syllabique
            if len(chars) >= 2:
                steps.append({
                    'index': len(steps),
                    'step_type': 'fusion',
                    'components': [c.symbol for c in chars[:2]],
                    'result_syllable': target_w.beriya_text,
                    'phonemes': " + ".join([f"/{c.phoneme_ipa}/" for c in chars[:2] if c.phoneme_ipa != 'À_VALIDER']),
                    'instruction': "Écoute comment les sons fusionnent pour former une syllabe",
                    'audio_url': w_syllable_audio,
                    'weight_category': 'recognition',
                })

            # 5. Décodage du mot réel
            steps.append({
                'index': len(steps),
                'step_type': 'word_decoding',
                'word': target_w.beriya_text,
                'latin_transcription': target_w.latin_transcription,
                'french_translation': target_w.french_translation,
                'orthographic_pattern': target_w.orthographic_pattern,
                'syllabic_structure': target_w.syllabic_structure,
                'oral_prompt': target_w.oral_prompt or "Écoute et observe le mot complet",
                'audio_url': w_normal_audio,
                'image_url': w_image,
                'weight_category': 'recognition',
            })

            # 6. Encodage au Clavier Beriya
            keyboard_symbols = list(dict.fromkeys([c.symbol for c in chars] + [d.symbol for d in distractors]))
            steps.append({
                'index': len(steps),
                'step_type': 'keyboard_encoding',
                'target_word': target_w.beriya_text,
                'latin_transcription': target_w.latin_transcription,
                'french_translation': target_w.french_translation,
                'keyboard_keys': keyboard_symbols,
                'audio_url': w_normal_audio,
                'instruction': f"Écris le mot \"{target_w.latin_transcription or target_w.beriya_text}\" au clavier :",
                'weight_category': 'encoding',
            })

        # 7. Bilan & Célébration
        steps.append({
            'index': len(steps),
            'step_type': 'celebration',
            'title': "Félicitations !",
            'message': f"Tu as validé l'apprentissage de {self.title_fr} !",
            'target_word': target_w.beriya_text if target_w else "",
            'french_translation': target_w.french_translation if target_w else "",
            'weights': {
                'recognition': self.weight_recognition if self.enable_tracing else 50,
                'tracing': self.weight_tracing if self.enable_tracing else 0,
                'encoding': self.weight_encoding if self.enable_tracing else 50,
            },
        })

        return steps