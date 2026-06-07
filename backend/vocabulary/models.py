from django.db import models

from audio_assets.models import AudioAsset


class WordCategory(models.Model):
    slug = models.SlugField(unique=True)

    name_fr = models.CharField(max_length=120)
    name_en = models.CharField(max_length=120, blank=True)
    name_ar = models.CharField(max_length=120, blank=True)

    order_index = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['order_index', 'name_fr']
        verbose_name = 'Word Category'
        verbose_name_plural = 'Word Categories'

    def __str__(self):
        return self.name_fr


class Word(models.Model):
    BEGINNER = 'beginner'
    INTERMEDIATE = 'intermediate'
    ADVANCED = 'advanced'

    DIFFICULTY_CHOICES = [
        (BEGINNER, 'Beginner'),
        (INTERMEDIATE, 'Intermediate'),
        (ADVANCED, 'Advanced'),
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

    beriya_text = models.CharField(
        max_length=255,
        help_text='Mot en Beriya Erfe.',
    )

    latin_transcription = models.CharField(max_length=255, blank=True)
    arabic_transcription = models.CharField(max_length=255, blank=True)

    french_translation = models.CharField(max_length=255, blank=True)
    english_translation = models.CharField(max_length=255, blank=True)
    arabic_translation = models.CharField(max_length=255, blank=True)

    category = models.ForeignKey(
        WordCategory,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='words',
    )

    difficulty = models.CharField(
        max_length=30,
        choices=DIFFICULTY_CHOICES,
        default=BEGINNER,
    )

    difficulty_order = models.PositiveIntegerField(default=0)

    image = models.ImageField(
        upload_to='vocabulary/images/',
        blank=True,
        null=True,
    )

    oral_prompt = models.CharField(
        max_length=255,
        blank=True,
        help_text='Instruction courte audio-first.',
    )

    pronunciation_note = models.TextField(blank=True)
    dialect_note = models.TextField(blank=True)
    example_sentence = models.TextField(blank=True)

    validation_status = models.CharField(
        max_length=20,
        choices=VALIDATION_STATUS_CHOICES,
        default=DRAFT,
    )

    is_active = models.BooleanField(default=True)
    available_offline = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['difficulty_order', 'beriya_text']
        verbose_name = 'Word'
        verbose_name_plural = 'Words'
        indexes = [
            models.Index(fields=['beriya_text']),
            models.Index(fields=['difficulty']),
            models.Index(fields=['validation_status']),
        ]

    def __str__(self):
        return self.beriya_text


class WordAudio(models.Model):
    NORMAL = 'normal'
    SLOW = 'slow'
    EXAMPLE = 'example'
    SYLLABLE_BREAKDOWN = 'syllable_breakdown'

    ROLE_CHOICES = [
        (NORMAL, 'Normal pronunciation'),
        (SLOW, 'Slow pronunciation'),
        (EXAMPLE, 'Example sentence'),
        (SYLLABLE_BREAKDOWN, 'Syllable breakdown'),
    ]

    word = models.ForeignKey(
        Word,
        on_delete=models.CASCADE,
        related_name='audio_links',
    )

    audio_asset = models.ForeignKey(
        AudioAsset,
        on_delete=models.CASCADE,
        related_name='word_links',
    )

    role = models.CharField(
        max_length=40,
        choices=ROLE_CHOICES,
        default=NORMAL,
    )

    is_primary = models.BooleanField(default=True)
    order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['word', 'role', '-is_primary', 'order']
        constraints = [
            models.UniqueConstraint(
                fields=['word', 'audio_asset', 'role'],
                name='unique_word_audio_role',
            ),
        ]

    def __str__(self):
        return f'{self.word} — {self.role}'