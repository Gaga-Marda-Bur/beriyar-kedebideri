from django import template

register = template.Library()


def _clean(value):
    if value is None:
        return ""
    return str(value).strip()


def _first_not_empty(*values):
    for value in values:
        cleaned = _clean(value)
        if cleaned:
            return cleaned
    return ""


def _get(obj, field_name):
    if obj is None:
        return ""
    return getattr(obj, field_name, "")


@register.filter
def i18n_title(obj, lang):
    if lang == "ar":
        return _first_not_empty(
            _get(obj, "title_ar"),
            _get(obj, "title_fr"),
            _get(obj, "title_en"),
            _get(obj, "title"),
            obj,
        )

    if lang == "en":
        return _first_not_empty(
            _get(obj, "title_en"),
            _get(obj, "title_fr"),
            _get(obj, "title_ar"),
            _get(obj, "title"),
            obj,
        )

    return _first_not_empty(
        _get(obj, "title_fr"),
        _get(obj, "title_en"),
        _get(obj, "title_ar"),
        _get(obj, "title"),
        obj,
    )


@register.filter
def i18n_description(obj, lang):
    if lang == "ar":
        return _first_not_empty(
            _get(obj, "description_ar"),
            _get(obj, "description_fr"),
            _get(obj, "description_en"),
            _get(obj, "description"),
        )

    if lang == "en":
        return _first_not_empty(
            _get(obj, "description_en"),
            _get(obj, "description_fr"),
            _get(obj, "description_ar"),
            _get(obj, "description"),
        )

    return _first_not_empty(
        _get(obj, "description_fr"),
        _get(obj, "description_en"),
        _get(obj, "description_ar"),
        _get(obj, "description"),
    )


@register.filter
def i18n_caption(obj, lang):
    if lang == "ar":
        return _first_not_empty(
            _get(obj, "caption_ar"),
            _get(obj, "caption_fr"),
            _get(obj, "caption_en"),
            _get(obj, "caption"),
        )

    if lang == "en":
        return _first_not_empty(
            _get(obj, "caption_en"),
            _get(obj, "caption_fr"),
            _get(obj, "caption_ar"),
            _get(obj, "caption"),
        )

    return _first_not_empty(
        _get(obj, "caption_fr"),
        _get(obj, "caption_en"),
        _get(obj, "caption_ar"),
        _get(obj, "caption"),
    )


@register.filter
def i18n_prompt(obj, lang):
    if lang == "ar":
        return _first_not_empty(
            _get(obj, "prompt_ar"),
            _get(obj, "oral_prompt_ar"),
            _get(obj, "prompt_fr"),
            _get(obj, "oral_prompt_fr"),
            _get(obj, "prompt_en"),
            _get(obj, "oral_prompt_en"),
            _get(obj, "prompt"),
        )

    if lang == "en":
        return _first_not_empty(
            _get(obj, "prompt_en"),
            _get(obj, "oral_prompt_en"),
            _get(obj, "prompt_fr"),
            _get(obj, "oral_prompt_fr"),
            _get(obj, "prompt_ar"),
            _get(obj, "oral_prompt_ar"),
            _get(obj, "prompt"),
        )

    return _first_not_empty(
        _get(obj, "prompt_fr"),
        _get(obj, "oral_prompt_fr"),
        _get(obj, "prompt_en"),
        _get(obj, "oral_prompt_en"),
        _get(obj, "prompt_ar"),
        _get(obj, "oral_prompt_ar"),
        _get(obj, "prompt"),
    )


@register.filter
def i18n_word_translation(word, lang):
    if lang == "ar":
        return _first_not_empty(
            _get(word, "arabic_translation"),
            _get(word, "french_translation"),
            _get(word, "english_translation"),
            _get(word, "meaning"),
        )

    if lang == "en":
        return _first_not_empty(
            _get(word, "english_translation"),
            _get(word, "french_translation"),
            _get(word, "arabic_translation"),
            _get(word, "meaning"),
        )

    return _first_not_empty(
        _get(word, "french_translation"),
        _get(word, "english_translation"),
        _get(word, "arabic_translation"),
        _get(word, "meaning"),
    )


@register.filter
def i18n_category_name(category, lang):
    if lang == "ar":
        return _first_not_empty(
            _get(category, "name_ar"),
            _get(category, "name_fr"),
            _get(category, "name_en"),
            _get(category, "name"),
        )

    if lang == "en":
        return _first_not_empty(
            _get(category, "name_en"),
            _get(category, "name_fr"),
            _get(category, "name_ar"),
            _get(category, "name"),
        )

    return _first_not_empty(
        _get(category, "name_fr"),
        _get(category, "name_en"),
        _get(category, "name_ar"),
        _get(category, "name"),
    )


@register.filter
def i18n_transcription(obj, lang):
    if lang == "ar":
        return _first_not_empty(
            _get(obj, "arabic_transcription"),
            _get(obj, "latin_transcription"),
        )

    return _first_not_empty(
        _get(obj, "latin_transcription"),
        _get(obj, "arabic_transcription"),
    )


@register.filter
def i18n_level(level, lang):
    value = _clean(level).lower()

    beginner_values = {"beginner", "débutant", "debutant", "başlangıç", "1"}
    intermediate_values = {"intermediate", "intermédiaire", "intermediaire", "orta", "2"}
    advanced_values = {"advanced", "avancé", "avance", "ileri", "3"}

    if value in beginner_values:
        if lang == "ar":
            return "مبتدئ"
        if lang == "en":
            return "Beginner"
        return "Débutant"

    if value in intermediate_values:
        if lang == "ar":
            return "متوسط"
        if lang == "en":
            return "Intermediate"
        return "Intermédiaire"

    if value in advanced_values:
        if lang == "ar":
            return "متقدم"
        if lang == "en":
            return "Advanced"
        return "Avancé"

    return level


@register.filter
def i18n_publication_type(value, lang):
    raw = _clean(value).lower()

    labels = {
        "image": {
            "fr": "Image",
            "en": "Image",
            "ar": "صورة",
        },
        "video": {
            "fr": "Vidéo",
            "en": "Video",
            "ar": "فيديو",
        },
        "story": {
            "fr": "Récit",
            "en": "Story",
            "ar": "حكاية",
        },
        "proverb": {
            "fr": "Proverbe",
            "en": "Proverb",
            "ar": "مثل",
        },
        "demo": {
            "fr": "Démonstration",
            "en": "Demonstration",
            "ar": "عرض",
        },
        "demonstration": {
            "fr": "Démonstration",
            "en": "Demonstration",
            "ar": "عرض",
        },
    }

    if raw in labels:
        return labels[raw].get(lang, labels[raw]["fr"])

    return value


@register.filter
def i18n_quiz_type(value, lang):
    raw = _clean(value).upper()

    labels = {
        "AUDIO_TO_CHARACTER": {
            "fr": "Audio vers caractère",
            "en": "Audio to character",
            "ar": "من الصوت إلى الحرف",
        },
        "CHARACTER_TO_AUDIO": {
            "fr": "Caractère vers audio",
            "en": "Character to audio",
            "ar": "من الحرف إلى الصوت",
        },
        "AUDIO_TO_IMAGE": {
            "fr": "Audio vers image",
            "en": "Audio to image",
            "ar": "من الصوت إلى الصورة",
        },
        "IMAGE_TO_AUDIO": {
            "fr": "Image vers audio",
            "en": "Image to audio",
            "ar": "من الصورة إلى الصوت",
        },
        "TEXT_TO_CHARACTER": {
            "fr": "Texte vers caractère",
            "en": "Text to character",
            "ar": "من النص إلى الحرف",
        },
        "GUIDED_KEYBOARD": {
            "fr": "Clavier guidé",
            "en": "Guided keyboard",
            "ar": "كتابة موجّهة",
        },
        "LISTEN_AND_REPEAT": {
            "fr": "Écouter et répéter",
            "en": "Listen and repeat",
            "ar": "استمع وكرّر",
        },
    }

    if raw in labels:
        return labels[raw].get(lang, labels[raw]["fr"])

    if lang == "ar":
        return "اختبار"
    if lang == "en":
        return "Quiz"
    return "Quiz"


@register.simple_tag
def ui_text(key, lang="fr"):
    texts = {
        "listen": {
            "fr": "Écouter",
            "en": "Listen",
            "ar": "استمع",
        },
        "no_audio": {
            "fr": "Aucun audio pour le moment",
            "en": "No audio yet",
            "ar": "لا يوجد صوت بعد",
        },
        "characters": {
            "fr": "caractère(s)",
            "en": "character(s)",
            "ar": "حرف",
        },
        "words": {
            "fr": "mot(s)",
            "en": "word(s)",
            "ar": "كلمة",
        },
        "minutes": {
            "fr": "min",
            "en": "min",
            "ar": "دقيقة",
        },
        "options": {
            "fr": "option(s)",
            "en": "option(s)",
            "ar": "خيارات",
        },
        "search": {
            "fr": "Rechercher",
            "en": "Search",
            "ar": "بحث",
        },
        "all_categories": {
            "fr": "Toutes les catégories",
            "en": "All categories",
            "ar": "كل الفئات",
        },
        "all": {
            "fr": "Tous",
            "en": "All",
            "ar": "الكل",
        },
        "empty_words": {
            "fr": "Aucun mot trouvé.",
            "en": "No word found.",
            "ar": "لم يتم العثور على أي كلمة.",
        },
        "empty_quizzes": {
            "fr": "Aucun quiz publié pour le moment.",
            "en": "No published quizzes yet.",
            "ar": "لا توجد اختبارات منشورة حاليًا.",
        },
        "keyboard_hint": {
            "fr": "Utilise le bouton 𖺠 Clavier pour écrire les caractères Beriya.",
            "en": "Use the 𖺠 keyboard button to type Beriya characters.",
            "ar": "استخدم زر 𖺠 Clavier لكتابة حروف بيريَا.",
        },
    }

    return texts.get(key, {}).get(lang, texts.get(key, {}).get("fr", key))

@register.filter
def i18n_option_text(option, lang):
    if lang == "ar":
        return _first_not_empty(
            _get(option, "text_ar"),
            _get(option, "text_fr"),
            _get(option, "text_en"),
            "خيار",
        )

    if lang == "en":
        return _first_not_empty(
            _get(option, "text_en"),
            _get(option, "text_fr"),
            _get(option, "text_ar"),
            "Option",
        )

    return _first_not_empty(
        _get(option, "text_fr"),
        _get(option, "text_en"),
        _get(option, "text_ar"),
        "Option",
    )

@register.filter
def i18n_feedback_type(value, lang):
    raw = _clean(value).lower()

    labels = {
        "bug": {
            "fr": "Bug",
            "en": "Bug",
            "ar": "خطأ تقني",
        },
        "audio": {
            "fr": "Problème audio",
            "en": "Audio issue",
            "ar": "مشكلة صوت",
        },
        "translation": {
            "fr": "Erreur de traduction",
            "en": "Translation error",
            "ar": "خطأ في الترجمة",
        },
        "content": {
            "fr": "Contenu",
            "en": "Content",
            "ar": "محتوى",
        },
        "suggestion": {
            "fr": "Suggestion",
            "en": "Suggestion",
            "ar": "اقتراح",
        },
        "other": {
            "fr": "Autre",
            "en": "Other",
            "ar": "أخرى",
        },
    }

    if raw in labels:
        return labels[raw].get(lang, labels[raw]["fr"])

    return value