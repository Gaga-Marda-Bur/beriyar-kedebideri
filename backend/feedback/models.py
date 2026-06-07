from django.conf import settings
from django.contrib.contenttypes.fields import GenericForeignKey
from django.contrib.contenttypes.models import ContentType
from django.db import models

from audio_assets.models import AudioAsset


class FeedbackReport(models.Model):
    PRONUNCIATION = 'pronunciation'
    TRANSLATION = 'translation'
    AUDIO_QUALITY = 'audio_quality'
    WRONG_CHARACTER = 'wrong_character'
    WRONG_WORD = 'wrong_word'
    WRONG_IMAGE = 'wrong_image'
    TECHNICAL = 'technical'
    CONTENT_SUGGESTION = 'content_suggestion'
    OTHER = 'other'

    FEEDBACK_TYPE_CHOICES = [
        (PRONUNCIATION, 'Pronunciation problem'),
        (TRANSLATION, 'Translation problem'),
        (AUDIO_QUALITY, 'Audio quality problem'),
        (WRONG_CHARACTER, 'Wrong character'),
        (WRONG_WORD, 'Wrong word'),
        (WRONG_IMAGE, 'Wrong image'),
        (TECHNICAL, 'Technical problem'),
        (CONTENT_SUGGESTION, 'Content suggestion'),
        (OTHER, 'Other'),
    ]

    LOW = 'low'
    MEDIUM = 'medium'
    HIGH = 'high'
    CRITICAL = 'critical'

    PRIORITY_CHOICES = [
        (LOW, 'Low'),
        (MEDIUM, 'Medium'),
        (HIGH, 'High'),
        (CRITICAL, 'Critical'),
    ]

    NEW = 'new'
    REVIEWING = 'reviewing'
    ACCEPTED = 'accepted'
    REJECTED = 'rejected'
    FIXED = 'fixed'
    ARCHIVED = 'archived'

    STATUS_CHOICES = [
        (NEW, 'New'),
        (REVIEWING, 'Reviewing'),
        (ACCEPTED, 'Accepted'),
        (REJECTED, 'Rejected'),
        (FIXED, 'Fixed'),
        (ARCHIVED, 'Archived'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='feedback_reports',
    )

    device_id = models.CharField(
        max_length=120,
        blank=True,
        db_index=True,
        help_text='Identifiant local stable pour feedback sans compte.',
    )

    feedback_type = models.CharField(
        max_length=40,
        choices=FEEDBACK_TYPE_CHOICES,
        default=OTHER,
    )

    title = models.CharField(
        max_length=255,
        blank=True,
    )

    message = models.TextField(
        blank=True,
        help_text='Description du problème ou de la suggestion.',
    )

    # Lien flexible vers Character, Word, Lesson, QuizQuestion, NoEnaPublication plus tard.
    content_type = models.ForeignKey(
        ContentType,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
    )

    object_id = models.PositiveIntegerField(
        blank=True,
        null=True,
    )

    content_object = GenericForeignKey(
        'content_type',
        'object_id',
    )

    audio_feedback = models.ForeignKey(
        AudioAsset,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='feedback_reports',
        help_text='Feedback vocal envoyé ou ajouté par un utilisateur.',
    )

    screenshot = models.ImageField(
        upload_to='feedback/screenshots/',
        blank=True,
        null=True,
    )

    app_version = models.CharField(max_length=50, blank=True)
    platform = models.CharField(
        max_length=50,
        blank=True,
        help_text='android, ios, web, etc.',
    )

    language_code = models.CharField(
        max_length=10,
        blank=True,
        help_text='fr, en, ar, etc.',
    )

    priority = models.CharField(
        max_length=20,
        choices=PRIORITY_CHOICES,
        default=MEDIUM,
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=NEW,
    )

    admin_note = models.TextField(blank=True)
    resolved_at = models.DateTimeField(blank=True, null=True)

    client_created_at = models.DateTimeField(blank=True, null=True)
    synced_at = models.DateTimeField(auto_now=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = 'Feedback Report'
        verbose_name_plural = 'Feedback Reports'
        indexes = [
            models.Index(fields=['device_id']),
            models.Index(fields=['feedback_type']),
            models.Index(fields=['status']),
            models.Index(fields=['priority']),
        ]

    def __str__(self):
        label = self.title or self.message[:50] or self.feedback_type
        return f'{label} — {self.status}'