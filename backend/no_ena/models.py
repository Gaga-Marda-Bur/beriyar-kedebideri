from django.conf import settings
from django.db import models

from alphabet.models import Character
from audio_assets.models import AudioAsset
from learning.models import LearningUnit
from vocabulary.models import Word


class NoEnaPublication(models.Model):
    SHORT_VIDEO = 'short_video'
    IMAGE = 'image'
    AUDIO_STORY = 'audio_story'
    PROVERB = 'proverb'
    WRITING_DEMO = 'writing_demo'
    CULTURE_NOTE = 'culture_note'

    PUBLICATION_TYPE_CHOICES = [
        (SHORT_VIDEO, 'Short video'),
        (IMAGE, 'Image'),
        (AUDIO_STORY, 'Audio story'),
        (PROVERB, 'Proverb'),
        (WRITING_DEMO, 'Writing demonstration'),
        (CULTURE_NOTE, 'Culture note'),
    ]

    DRAFT = 'draft'
    REVIEW = 'review'
    VALIDATED = 'validated'
    PUBLISHED = 'published'
    ARCHIVED = 'archived'
    REJECTED = 'rejected'

    STATUS_CHOICES = [
        (DRAFT, 'Draft'),
        (REVIEW, 'Review'),
        (VALIDATED, 'Validated'),
        (PUBLISHED, 'Published'),
        (ARCHIVED, 'Archived'),
        (REJECTED, 'Rejected'),
    ]

    title_fr = models.CharField(max_length=255)
    title_en = models.CharField(max_length=255, blank=True)
    title_ar = models.CharField(max_length=255, blank=True)

    beriya_title = models.CharField(
        max_length=255,
        blank=True,
        help_text='Titre éventuel en Beriya Erfe.',
    )

    slug = models.SlugField(unique=True)

    caption_fr = models.TextField(blank=True)
    caption_en = models.TextField(blank=True)
    caption_ar = models.TextField(blank=True)

    beriya_caption = models.TextField(
        blank=True,
        help_text='Description éventuelle en Beriya Erfe.',
    )

    publication_type = models.CharField(
        max_length=40,
        choices=PUBLICATION_TYPE_CHOICES,
        default=IMAGE,
    )

    image_file = models.ImageField(
        upload_to='no_ena/images/',
        blank=True,
        null=True,
    )

    thumbnail = models.ImageField(
        upload_to='no_ena/thumbnails/',
        blank=True,
        null=True,
    )

    video_file = models.FileField(
        upload_to='no_ena/videos/',
        blank=True,
        null=True,
        help_text='Vidéo courte MP4 optimisée mobile.',
    )

    primary_audio_asset = models.ForeignKey(
        AudioAsset,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='no_ena_publications',
        help_text='Audio principal : narration, proverbe, explication, etc.',
    )

    related_character = models.ForeignKey(
        Character,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='no_ena_publications',
    )

    related_word = models.ForeignKey(
        Word,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='no_ena_publications',
    )

    related_unit = models.ForeignKey(
        LearningUnit,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='no_ena_publications',
    )

    contributor_name = models.CharField(
        max_length=150,
        blank=True,
    )

    contributor_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='no_ena_contributions',
    )

    culture_theme = models.CharField(
        max_length=150,
        blank=True,
        help_text='Exemple : proverbes, écriture, famille, tradition, histoire.',
    )

    order_index = models.PositiveIntegerField(default=0)

    view_count = models.PositiveIntegerField(default=0)
    favorite_count = models.PositiveIntegerField(default=0)

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=DRAFT,
    )

    is_active = models.BooleanField(default=True)
    is_featured = models.BooleanField(default=False)
    available_offline = models.BooleanField(default=False)

    published_at = models.DateTimeField(blank=True, null=True)

    admin_note = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-is_featured', 'order_index', '-published_at', '-created_at']
        verbose_name = 'No Ena Publication'
        verbose_name_plural = 'No Ena Publications'
        indexes = [
            models.Index(fields=['publication_type']),
            models.Index(fields=['status']),
            models.Index(fields=['is_featured']),
            models.Index(fields=['available_offline']),
        ]

    def __str__(self):
        return self.title_fr