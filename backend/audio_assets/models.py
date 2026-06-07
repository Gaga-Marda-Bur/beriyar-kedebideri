import uuid

from django.core.validators import FileExtensionValidator
from django.db import models


class AudioAsset(models.Model):
    CHARACTER = 'character'
    PHONEME = 'phoneme'
    SYLLABLE = 'syllable'
    WORD = 'word'
    SENTENCE = 'sentence'
    PROVERB = 'proverb'
    STORY = 'story'
    LESSON_PROMPT = 'lesson_prompt'
    QUIZ_PROMPT = 'quiz_prompt'
    QUIZ_EXPLANATION = 'quiz_explanation'
    FEEDBACK = 'feedback'
    NO_ENA = 'no_ena'

    AUDIO_TYPE_CHOICES = [
        (CHARACTER, 'Character'),
        (PHONEME, 'Phoneme'),
        (SYLLABLE, 'Syllable'),
        (WORD, 'Word'),
        (SENTENCE, 'Sentence'),
        (PROVERB, 'Proverb'),
        (STORY, 'Story'),
        (LESSON_PROMPT, 'Lesson prompt'),
        (QUIZ_PROMPT, 'Quiz prompt'),
        (QUIZ_EXPLANATION, 'Quiz explanation'),
        (FEEDBACK, 'Feedback'),
        (NO_ENA, 'No Ena'),
    ]

    SLOW = 'slow'
    NORMAL = 'normal'

    SPEED_CHOICES = [
        (SLOW, 'Slow'),
        (NORMAL, 'Normal'),
    ]

    FEMALE = 'female'
    MALE = 'male'
    UNKNOWN = 'unknown'

    SPEAKER_GENDER_CHOICES = [
        (FEMALE, 'Female'),
        (MALE, 'Male'),
        (UNKNOWN, 'Unknown'),
    ]

    DRAFT = 'draft'
    REVIEW = 'review'
    VALIDATED = 'validated'
    PUBLISHED = 'published'
    REJECTED = 'rejected'

    VALIDATION_STATUS_CHOICES = [
        (DRAFT, 'Draft'),
        (REVIEW, 'Review'),
        (VALIDATED, 'Validated'),
        (PUBLISHED, 'Published'),
        (REJECTED, 'Rejected'),
    ]

    id = models.UUIDField(
        primary_key=True,
        default=uuid.uuid4,
        editable=False,
    )

    title = models.CharField(
        max_length=255,
        blank=True,
        help_text="Nom interne de l’audio.",
    )

    file = models.FileField(
        upload_to='audio_assets/files/',
        validators=[
            FileExtensionValidator(
                allowed_extensions=['mp3', 'm4a', 'wav'],
            )
        ],
        help_text='Formats acceptés : MP3, M4A, WAV.',
    )

    audio_type = models.CharField(
        max_length=40,
        choices=AUDIO_TYPE_CHOICES,
    )

    speed = models.CharField(
        max_length=20,
        choices=SPEED_CHOICES,
        default=NORMAL,
    )

    speaker_name = models.CharField(
        max_length=150,
        blank=True,
    )

    speaker_gender = models.CharField(
        max_length=20,
        choices=SPEAKER_GENDER_CHOICES,
        default=UNKNOWN,
    )

    dialect_region = models.CharField(
        max_length=150,
        blank=True,
        help_text='Exemple : Borkou, Ennedi, Darfour, diaspora, etc.',
    )

    mime_type = models.CharField(
        max_length=100,
        blank=True,
        help_text='Exemple : audio/mpeg, audio/mp4, audio/wav.',
    )

    duration_ms = models.PositiveIntegerField(
        blank=True,
        null=True,
    )

    transcript = models.TextField(
        blank=True,
        help_text='Texte ou transcription correspondant à l’audio.',
    )

    recording_quality = models.CharField(
        max_length=50,
        blank=True,
        help_text='Exemple : draft, acceptable, studio, verified.',
    )

    validation_status = models.CharField(
        max_length=20,
        choices=VALIDATION_STATUS_CHOICES,
        default=DRAFT,
    )

    available_offline = models.BooleanField(
        default=True,
        help_text='Peut être inclus dans les packs offline.',
    )

    notes = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['audio_type', 'title', '-created_at']
        verbose_name = 'Audio Asset'
        verbose_name_plural = 'Audio Assets'

    def __str__(self):
        label = self.title or self.file.name
        return f'{label} — {self.audio_type} / {self.speed}'