"""Validation commune des feedbacks web et API (audit A15).

Les mêmes règles s'appliquent au formulaire web et à l'endpoint public
``/api/feedback/create/`` : choix limités, longueurs maximales, caractères de
contrôle refusés, cible restreinte à des contenus pédagogiques existants et
pièces jointes bornées. Les messages d'erreur sont localisés (fr/en/ar).
"""
import re
import uuid
import math
from datetime import timedelta

from django.contrib.contenttypes.models import ContentType
from django.core.exceptions import ValidationError
from django.utils import timezone

from .models import FeedbackReport

MAX_TITLE_LENGTH = FeedbackReport._meta.get_field('title').max_length  # 255
MAX_MESSAGE_LENGTH = 5000
MAX_SCREENSHOT_BYTES = 2 * 1024 * 1024
MAX_SCREENSHOT_SIDE = 4096
ALLOWED_SCREENSHOT_FORMATS = {'JPEG', 'PNG', 'WEBP'}

FEEDBACK_TYPES = {value for value, _ in FeedbackReport.FEEDBACK_TYPE_CHOICES}
PLATFORMS = {'android', 'ios', 'web', 'windows', 'macos', 'linux', 'other'}

# Contenus pouvant faire l'objet d'un signalement. Les modèles techniques
# (utilisateurs, sessions, progressions…) ne sont jamais ciblables.
ALLOWED_TARGETS = {
    ('alphabet', 'character'),
    ('vocabulary', 'word'),
    ('lessons', 'lesson'),
    ('quizzes', 'quizquestion'),
    ('no_ena', 'noenapublication'),
    ('learning', 'learningunit'),
    ('learning', 'learningtheme'),
}

LANGUAGE_RE = re.compile(r'^[a-z]{2,3}([-_][A-Za-z0-9]{2,6})?$')
DEVICE_ID_RE = re.compile(r'^[A-Za-z0-9._:\-]{1,120}$')
APP_VERSION_RE = re.compile(r'^[0-9A-Za-z.+_\-]{1,50}$')
# Caractères de contrôle interdits ; tabulation et retours à la ligne permis.
CONTROL_CHARS_RE = re.compile(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f\ud800-\udfff]')

MESSAGES = {
    'required': {
        'fr': "Merci d’écrire un message avant d’envoyer.",
        'en': 'Please write a message before sending.',
        'ar': 'يرجى كتابة رسالة قبل الإرسال.',
    },
    'too_long': {
        'fr': 'Texte trop long ({max} caractères maximum).',
        'en': 'Text is too long ({max} characters maximum).',
        'ar': 'النص طويل جدًا (الحد الأقصى {max} حرف).',
    },
    'control_chars': {
        'fr': 'Le texte contient des caractères non autorisés.',
        'en': 'The text contains characters that are not allowed.',
        'ar': 'يحتوي النص على أحرف غير مسموح بها.',
    },
    'invalid_choice': {
        'fr': 'Valeur non autorisée.',
        'en': 'Value not allowed.',
        'ar': 'قيمة غير مسموح بها.',
    },
    'invalid_format': {
        'fr': 'Format invalide.',
        'en': 'Invalid format.',
        'ar': 'صيغة غير صالحة.',
    },
    'invalid_target': {
        'fr': 'Le contenu signalé est introuvable ou ne peut pas être signalé.',
        'en': 'The reported content does not exist or cannot be reported.',
        'ar': 'المحتوى المُبلَّغ عنه غير موجود أو لا يمكن الإبلاغ عنه.',
    },
    'invalid_date': {
        'fr': 'Date du client hors limites.',
        'en': 'Client date out of range.',
        'ar': 'تاريخ الجهاز خارج النطاق.',
    },
    'invalid_image': {
        'fr': 'Capture refusée : JPEG, PNG ou WebP, 2 Mo et 4096 px maximum.',
        'en': 'Screenshot rejected: JPEG, PNG or WebP, 2 MB and 4096 px maximum.',
        'ar': 'تم رفض لقطة الشاشة: JPEG أو PNG أو WebP، بحد أقصى 2 ميغابايت و4096 بكسل.',
    },
    'throttled': {
        'fr': 'Trop d’envois rapprochés. Réessaie dans {wait}.',
        'en': 'Too many submissions in a short time. Try again in {wait}.',
        'ar': 'عدد كبير من الإرسالات في وقت قصير. أعد المحاولة بعد {wait}.',
    },
}


def message(code, lang='en', **kwargs):
    lang = lang if lang in ('fr', 'en', 'ar') else 'en'
    return MESSAGES[code][lang].format(**kwargs)


def _error(code, lang, **kwargs):
    return ValidationError(message(code, lang, **kwargs), code=code)


def clean_text(value, max_length, lang='en'):
    text = (value or '').strip()
    if CONTROL_CHARS_RE.search(text):
        raise _error('control_chars', lang)
    if len(text) > max_length:
        raise _error('too_long', lang, max=max_length)
    return text


def clean_feedback_type(value, lang='en'):
    value = (value or FeedbackReport.OTHER).strip()
    if value not in FEEDBACK_TYPES:
        raise _error('invalid_choice', lang)
    return value


def clean_language_code(value, lang='en'):
    value = (value or '').strip()
    if value and (len(value) > 10 or not LANGUAGE_RE.fullmatch(value)):
        raise _error('invalid_format', lang)
    return value


def clean_platform(value, lang='en'):
    value = (value or '').strip().lower()
    if value and value not in PLATFORMS:
        raise _error('invalid_choice', lang)
    return value


def clean_device_id(value, lang='en'):
    value = (value or '').strip()
    if value and not DEVICE_ID_RE.match(value):
        raise _error('invalid_format', lang)
    return value


def clean_app_version(value, lang='en'):
    value = (value or '').strip()
    if value and not APP_VERSION_RE.match(value):
        raise _error('invalid_format', lang)
    return value


def clean_client_created_at(value, lang='en'):
    if value is None:
        return None
    now = timezone.now()
    if value > now + timedelta(days=1) or value.year < 2020:
        raise _error('invalid_date', lang)
    return value


def require_title_or_message(title, message_text, lang='en'):
    if not title and not message_text:
        raise _error('required', lang)


def resolve_target(app_label, model, object_id, lang='en'):
    """Retourne le ContentType autorisé, ou None si aucune cible."""
    app_label = (app_label or '').strip()
    model = (model or '').strip().lower()
    if not app_label and not model:
        if object_id is not None:
            raise _error('invalid_target', lang)
        return None
    if (app_label, model) not in ALLOWED_TARGETS:
        raise _error('invalid_target', lang)
    if object_id is None:
        raise _error('invalid_target', lang)
    content_type = ContentType.objects.filter(app_label=app_label, model=model).first()
    if content_type is None:
        raise _error('invalid_target', lang)
    if object_id is not None:
        model_class = content_type.model_class()
        if model_class is None or not model_class.objects.filter(pk=object_id).exists():
            raise _error('invalid_target', lang)
    return content_type


def clean_screenshot(upload, lang='en'):
    if not upload:
        return upload
    if upload.size > MAX_SCREENSHOT_BYTES:
        raise _error('invalid_image', lang)
    try:
        from PIL import Image

        position = upload.tell() if hasattr(upload, 'tell') else None
        image = Image.open(upload)
        image_format = image.format
        width, height = image.size
        if image_format not in ALLOWED_SCREENSHOT_FORMATS or width > MAX_SCREENSHOT_SIDE or height > MAX_SCREENSHOT_SIDE:
            raise _error('invalid_image', lang)
        image.verify()
        if position is not None:
            upload.seek(position)
    except Exception as exc:  # image corrompue ou non reconnue
        raise _error('invalid_image', lang) from exc
    if image_format not in ALLOWED_SCREENSHOT_FORMATS:
        raise _error('invalid_image', lang)
    if width > MAX_SCREENSHOT_SIDE or height > MAX_SCREENSHOT_SIDE:
        raise _error('invalid_image', lang)
    extension, content_type = {
        'JPEG': ('jpg', 'image/jpeg'), 'PNG': ('png', 'image/png'), 'WEBP': ('webp', 'image/webp'),
    }[image_format]
    upload.name = f'{uuid.uuid4().hex}.{extension}'
    upload.content_type = content_type
    return upload


def humanize_wait(seconds, lang='fr'):
    seconds = max(1, math.ceil(seconds or 1))
    if seconds < 60:
        unit = {'fr': 's', 'en': 's', 'ar': 'ث'}
        return f'{seconds} {unit.get(lang, "s")}'
    minutes = (seconds + 59) // 60
    unit = {'fr': 'min', 'en': 'min', 'ar': 'د'}
    return f'{minutes} {unit.get(lang, "min")}'
