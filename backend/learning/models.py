import unicodedata

from django.db import models
from core.media_validation import ValidatedMediaModel

from alphabet.models import Character
from vocabulary.models import Word


def _resolve_flow_lang(request=None, lang=None):
    """Resolve UI language ('fr', 'en', 'ar') from explicit arg, query, session, or header."""
    if lang in ('fr', 'en', 'ar'):
        return lang
    if request is not None:
        qp = getattr(request, 'query_params', None) or getattr(request, 'GET', None)
        if qp:
            req_lang = (qp.get('lang') or '').strip().lower()[:2]
            if req_lang in ('fr', 'en', 'ar'):
                return req_lang
        session = getattr(request, 'session', None)
        if session:
            sess_lang = (session.get('web_lang') or '').strip().lower()[:2]
            if sess_lang in ('fr', 'en', 'ar'):
                return sess_lang
        meta = getattr(request, 'META', None) or {}
        accept = (meta.get('HTTP_ACCEPT_LANGUAGE') or '').lower()
        for code in accept.replace(';', ',').split(','):
            short = code.strip()[:2]
            if short in ('fr', 'en', 'ar'):
                return short
    return 'fr'


def _extract_erfe_graphemes(text):
    """Split text into non-whitespace grapheme clusters (base + combining marks)."""
    graphemes = []
    for ch in (text or ''):
        if ch.isspace():
            continue
        if unicodedata.combining(ch) and graphemes:
            graphemes[-1] += ch
        else:
            graphemes.append(ch)
    return graphemes


def _localized_word_translation(word, lang):
    if lang == 'ar':
        return word.arabic_translation or word.french_translation or word.english_translation or ''
    if lang == 'en':
        return word.english_translation or word.french_translation or word.arabic_translation or ''
    return word.french_translation or word.english_translation or word.arabic_translation or ''


class LearningTheme(ValidatedMediaModel):
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

    def generate_core_flow(self, request=None, only_published=None, lang=None):
        """
        Génère dynamiquement la séquence complète des micro-étapes d'alphabétisation
        active (Learning Core) pour cette unité :
        1. Découverte auditive (phonème pur)
        2. Discrimination visuelle (sélection du glyphe cible)
        3. Geste d'écriture (tracé vectoriel guidé)
        ... pour chaque caractère introduit, puis :
        4. Fusion syllabique (consonne + voyelle)
        5. Décodage du/des mot(s) réel(s) (sens, oral, image)
        6. Encodage au clavier restreint (saisie autonome)
        7. Bilan & célébration (score calculé selon pondérations configurées)
        """
        from core.permissions import PILOT_ALLOWED_UNIT_SLUGS, is_pilot_user, is_staff_preview
        from audio_assets.utils import build_file_url, get_linked_audio_url

        resolved_lang = _resolve_flow_lang(request=request, lang=lang)

        if only_published is True:
            allowed_statuses = ('published',)
        elif only_published is False:
            allowed_statuses = None
        elif request is not None:
            if is_staff_preview(request):
                allowed_statuses = None
            elif is_pilot_user(request) and self.slug in PILOT_ALLOWED_UNIT_SLUGS:
                allowed_statuses = ('published', 'validated')
            else:
                allowed_statuses = ('published',)
        else:
            allowed_statuses = None

        steps = []
        if allowed_statuses is not None:
            chars = list(self.characters.filter(is_active=True, validation_status__in=allowed_statuses).order_by('order_index', 'id'))
            distractors = list(self.distractor_characters.filter(is_active=True, validation_status__in=allowed_statuses).order_by('order_index', 'id'))
            unit_words = list(self.words.filter(is_active=True, validation_status__in=allowed_statuses).order_by('difficulty_order', 'beriya_text', 'id'))
            target_w = self.target_word
            if target_w and (not target_w.is_active or target_w.validation_status not in allowed_statuses):
                target_w = None
        else:
            chars = list(self.characters.filter(is_active=True).order_by('order_index', 'id'))
            distractors = list(self.distractor_characters.filter(is_active=True).order_by('order_index', 'id'))
            unit_words = list(self.words.filter(is_active=True).order_by('difficulty_order', 'beriya_text', 'id'))
            target_w = self.target_word

        if target_w:
            words_to_teach = [target_w] + [w for w in unit_words if w.pk != target_w.pk]
        else:
            words_to_teach = unit_words

        # Phase par caractère introduit
        for idx, char in enumerate(chars):
            p_audio = get_linked_audio_url(char, 'phoneme', request=request) or get_linked_audio_url(char, 'normal', request=request)
            l_audio = get_linked_audio_url(char, 'letter_name', request=request)
            if resolved_lang == 'ar':
                type_label = 'الحرف الصائت' if char.character_type == Character.VOWEL else 'الحرف الساكن' if char.character_type == Character.CONSONANT else 'الحرف'
            elif resolved_lang == 'en':
                type_label = 'the vowel' if char.character_type == Character.VOWEL else 'the consonant' if char.character_type == Character.CONSONANT else 'the character'
            else:
                type_label = 'la voyelle' if char.character_type == Character.VOWEL else 'la consonne' if char.character_type == Character.CONSONANT else 'le caractère'

            ipa_str = f" /{char.phoneme_ipa}/" if char.phoneme_ipa and char.phoneme_ipa != 'À_VALIDER' else ""
            latin_hint = char.latin_transcription or char.latin_grapheme or ""

            if ipa_str or not latin_hint:
                if resolved_lang == 'ar':
                    discovery_label = f"استمع وتعرّف على {type_label}{ipa_str}"
                elif resolved_lang == 'en':
                    discovery_label = f"Listen and discover {type_label}{ipa_str}"
                else:
                    discovery_label = f"Écoute et découvre {type_label}{ipa_str}"
            else:
                if resolved_lang == 'ar':
                    discovery_label = f"تعرّف على الحرف « {latin_hint} » ({char.symbol})"
                elif resolved_lang == 'en':
                    discovery_label = f"Discover the letter “{latin_hint}” ({char.symbol})"
                else:
                    discovery_label = f"Découvre la lettre « {latin_hint} » ({char.symbol})"

            steps.append({
                'index': len(steps),
                'step_type': 'discovery',
                'symbol': char.symbol,
                'unicode_code': char.unicode_code,
                'character_type': char.character_type,
                'phoneme_ipa': char.phoneme_ipa,
                'latin_transcription': latin_hint,
                'label': discovery_label,
                'audio_url': p_audio,
                'letter_name_audio_url': l_audio,
                'weight_category': 'recognition',
            })

            # 2. Discrimination visuelle
            other_char = None
            for candidate in (chars[idx + 1:] + chars[:idx]):
                if candidate.symbol != char.symbol:
                    other_char = candidate
                    break
            if not other_char and distractors:
                other_char = distractors[0]

            if other_char:
                if ipa_str or not latin_hint:
                    if resolved_lang == 'ar':
                        disc_instruction = f"المس {type_label}{ipa_str}"
                    elif resolved_lang == 'en':
                        disc_instruction = f"Tap {type_label}{ipa_str}"
                    else:
                        disc_instruction = f"Touche {type_label}{ipa_str}"
                else:
                    if resolved_lang == 'ar':
                        disc_instruction = f"المس حرف إرفي المطابق لـ « {latin_hint} »"
                    elif resolved_lang == 'en':
                        disc_instruction = f"Tap the Erfe letter for “{latin_hint}”"
                    else:
                        disc_instruction = f"Touche la lettre Erfe correspondant à « {latin_hint} »"

                steps.append({
                    'index': len(steps),
                    'step_type': 'discrimination',
                    'target_symbol': char.symbol,
                    'other_symbol': other_char.symbol,
                    'phoneme_ipa': char.phoneme_ipa,
                    'latin_transcription': latin_hint,
                    'instruction': disc_instruction,
                    'audio_url': p_audio,
                    'weight_category': 'recognition',
                })

            # 3. Tracé Vectoriel
            if self.enable_tracing:
                if resolved_lang == 'ar':
                    trace_inst = f"تتبّع الحرف {char.symbol} بإصبعك"
                elif resolved_lang == 'en':
                    trace_inst = f"Trace the character {char.symbol} with your finger"
                else:
                    trace_inst = f"Trace le caractère {char.symbol} du bout du doigt"
                steps.append({
                    'index': len(steps),
                    'step_type': 'tracing',
                    'symbol': char.symbol,
                    'unicode_code': char.unicode_code,
                    'character_type': char.character_type,
                    'stroke_path_data': char.stroke_path_data or {},
                    'instruction': trace_inst,
                    'weight_category': 'tracing',
                })

        # Phase combinatoire / mots réels
        if words_to_teach:
            base_keyboard_symbols = list(dict.fromkeys([c.symbol for c in chars] + [d.symbol for d in distractors]))
            unit_word_graphemes = list(dict.fromkeys(
                g for w in words_to_teach for g in _extract_erfe_graphemes(w.beriya_text)
            ))

            for w_idx, current_w in enumerate(words_to_teach):
                w_normal_audio = get_linked_audio_url(current_w, 'normal', request=request)
                w_syllable_audio = (
                    get_linked_audio_url(current_w, 'syllable', request=request)
                    or get_linked_audio_url(current_w, 'syllable_breakdown', request=request)
                    or w_normal_audio
                )
                w_image = build_file_url(current_w.image, request=request)
                w_translation = _localized_word_translation(current_w, resolved_lang)

                # 4. Fusion syllabique (sur le mot principal si >= 2 caractères)
                if w_idx == 0 and len(chars) >= 2:
                    if resolved_lang == 'ar':
                        fusion_inst = "استمع إلى كيفية اندماج الأصوات لتكوين مقطع"
                    elif resolved_lang == 'en':
                        fusion_inst = "Listen to how the sounds blend to form a syllable"
                    else:
                        fusion_inst = "Écoute comment les sons fusionnent pour former une syllabe"
                    steps.append({
                        'index': len(steps),
                        'step_type': 'fusion',
                        'components': [c.symbol for c in chars[:2]],
                        'result_syllable': current_w.beriya_text,
                        'phonemes': " + ".join([f"/{c.phoneme_ipa}/" for c in chars[:2] if c.phoneme_ipa != 'À_VALIDER']),
                        'instruction': fusion_inst,
                        'audio_url': w_syllable_audio,
                        'weight_category': 'recognition',
                    })

                # 5. Décodage du mot réel
                if resolved_lang == 'ar':
                    default_oral = "استمع ولاحظ الكلمة كاملة"
                elif resolved_lang == 'en':
                    default_oral = "Listen and observe the full word"
                else:
                    default_oral = "Écoute et observe le mot complet"

                steps.append({
                    'index': len(steps),
                    'step_type': 'word_decoding',
                    'word': current_w.beriya_text,
                    'latin_transcription': current_w.latin_transcription,
                    'french_translation': current_w.french_translation,
                    'translation': w_translation,
                    'orthographic_pattern': current_w.orthographic_pattern,
                    'syllabic_structure': current_w.syllabic_structure,
                    'oral_prompt': current_w.oral_prompt or default_oral,
                    'audio_url': w_normal_audio,
                    'image_url': w_image,
                    'weight_category': 'recognition',
                })

                # 6. Encodage au Clavier Beriya (uniquement si saisissable sans espace, compatible APK 1.0.2)
                stripped_word = (current_w.beriya_text or '').strip()
                if stripped_word and ' ' not in stripped_word:
                    word_graphemes = _extract_erfe_graphemes(stripped_word)
                    keyboard_symbols = list(dict.fromkeys(base_keyboard_symbols + word_graphemes))
                    if len(keyboard_symbols) < 4:
                        for g in unit_word_graphemes:
                            if g not in keyboard_symbols:
                                keyboard_symbols.append(g)
                            if len(keyboard_symbols) >= 10:
                                break

                    word_label = current_w.latin_transcription or current_w.beriya_text
                    if resolved_lang == 'ar':
                        enc_inst = f"اكتب الكلمة « {word_label} » على لوحة المفاتيح:"
                    elif resolved_lang == 'en':
                        enc_inst = f'Type the word "{word_label}" on the keyboard:'
                    else:
                        enc_inst = f'Écris le mot "{word_label}" au clavier :'

                    steps.append({
                        'index': len(steps),
                        'step_type': 'keyboard_encoding',
                        'target_word': current_w.beriya_text,
                        'latin_transcription': current_w.latin_transcription,
                        'french_translation': current_w.french_translation,
                        'translation': w_translation,
                        'keyboard_keys': keyboard_symbols,
                        'audio_url': w_normal_audio,
                        'instruction': enc_inst,
                        'weight_category': 'encoding',
                    })
        elif chars:
            # Parcours alphabet sans mot cible : saisie guidée au clavier Erfe
            first_char = chars[0]
            first_audio = get_linked_audio_url(first_char, 'phoneme', request=request) or get_linked_audio_url(first_char, 'normal', request=request)
            first_latin = first_char.latin_transcription or first_char.latin_grapheme or first_char.symbol
            keyboard_symbols = list(dict.fromkeys([c.symbol for c in chars] + [d.symbol for d in distractors]))
            if resolved_lang == 'ar':
                letter_tr = f"الحرف {first_latin}"
                enc_inst = f"اكتب الحرف « {first_latin} » على لوحة مفاتيح إرفي:"
            elif resolved_lang == 'en':
                letter_tr = f"Letter {first_latin}"
                enc_inst = f"Type the letter “{first_latin}” on the Erfe keyboard:"
            else:
                letter_tr = f"Lettre {first_latin}"
                enc_inst = f"Écris la lettre « {first_latin} » au clavier Erfe :"

            steps.append({
                'index': len(steps),
                'step_type': 'keyboard_encoding',
                'target_word': first_char.symbol,
                'latin_transcription': first_latin,
                'french_translation': letter_tr,
                'translation': letter_tr,
                'keyboard_keys': keyboard_symbols,
                'audio_url': first_audio,
                'instruction': enc_inst,
                'weight_category': 'encoding',
            })

        # 7. Bilan & Célébration
        main_w = words_to_teach[0] if words_to_teach else None
        if resolved_lang == 'ar':
            unit_title = self.title_ar or self.title_fr
            cel_title = "أحسنت!"
            cel_msg = f"لقد أتممت تعلّم {unit_title}!"
        elif resolved_lang == 'en':
            unit_title = self.title_en or self.title_fr
            cel_title = "Congratulations!"
            cel_msg = f"You completed {unit_title}!"
        else:
            unit_title = self.title_fr
            cel_title = "Félicitations !"
            cel_msg = f"Tu as validé l'apprentissage de {unit_title} !"

        steps.append({
            'index': len(steps),
            'step_type': 'celebration',
            'title': cel_title,
            'message': cel_msg,
            'target_word': main_w.beriya_text if main_w else "",
            'french_translation': main_w.french_translation if main_w else "",
            'translation': _localized_word_translation(main_w, resolved_lang) if main_w else "",
            'weights': {
                'recognition': self.weight_recognition if self.enable_tracing else 50,
                'tracing': self.weight_tracing if self.enable_tracing else 0,
                'encoding': self.weight_encoding if self.enable_tracing else 50,
            },
        })

        return steps
