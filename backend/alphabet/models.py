from django.db import models

from audio_assets.models import AudioAsset


class Character(models.Model):
    VOWEL = 'vowel'
    CONSONANT = 'consonant'
    OTHER = 'other'
    UNKNOWN = 'unknown'

    CHARACTER_TYPE_CHOICES = [
        (VOWEL, 'Vowel'),
        (CONSONANT, 'Consonant'),
        (OTHER, 'Other'),
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

    symbol = models.CharField(
        max_length=10,
        unique=True,
        help_text='Caractère Beriya Erfe.',
    )

    unicode_code = models.CharField(
        max_length=20,
        unique=True,
        help_text='Exemple : U+16EA0.',
    )

    name = models.CharField(max_length=150, blank=True)
    name_fr = models.CharField(max_length=150, blank=True)
    name_en = models.CharField(max_length=150, blank=True)
    name_ar = models.CharField(max_length=150, blank=True)

    latin_transcription = models.CharField(max_length=120, blank=True)
    arabic_transcription = models.CharField(max_length=120, blank=True)

    character_type = models.CharField(
        max_length=30,
        choices=CHARACTER_TYPE_CHOICES,
        default=UNKNOWN,
    )

    order_index = models.PositiveIntegerField(default=0)

    description = models.TextField(blank=True)

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
        ordering = ['order_index', 'unicode_code']
        verbose_name = 'Character'
        verbose_name_plural = 'Characters'

    def __str__(self):
        return f'{self.symbol} ({self.unicode_code})'


class CharacterAudio(models.Model):
    NORMAL = 'normal'
    SLOW = 'slow'
    EXAMPLE = 'example'

    ROLE_CHOICES = [
        (NORMAL, 'Normal pronunciation'),
        (SLOW, 'Slow pronunciation'),
        (EXAMPLE, 'Example pronunciation'),
    ]

    character = models.ForeignKey(
        Character,
        on_delete=models.CASCADE,
        related_name='audio_links',
    )

    audio_asset = models.ForeignKey(
        AudioAsset,
        on_delete=models.CASCADE,
        related_name='character_links',
    )

    role = models.CharField(
        max_length=30,
        choices=ROLE_CHOICES,
        default=NORMAL,
    )

    is_primary = models.BooleanField(default=True)
    order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['character', 'role', '-is_primary', 'order']
        constraints = [
            models.UniqueConstraint(
                fields=['character', 'audio_asset', 'role'],
                name='unique_character_audio_role',
            ),
        ]

    def __str__(self):
        return f'{self.character} — {self.role}'