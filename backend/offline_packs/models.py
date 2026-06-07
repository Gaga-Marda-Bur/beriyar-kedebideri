import hashlib
import os

from django.core.validators import FileExtensionValidator
from django.db import models
from django.utils import timezone

from alphabet.models import Character
from learning.models import LearningTheme, LearningUnit
from lessons.models import Lesson
from quizzes.models import QuizQuestion
from vocabulary.models import Word


class LessonPack(models.Model):
    BEGINNER = 'beginner'
    INTERMEDIATE = 'intermediate'
    ADVANCED = 'advanced'

    LEVEL_CHOICES = [
        (BEGINNER, 'Beginner'),
        (INTERMEDIATE, 'Intermediate'),
        (ADVANCED, 'Advanced'),
    ]

    LIGHT = 'light'
    NORMAL = 'normal'
    COMPLETE = 'complete'

    PACK_TYPE_CHOICES = [
        (LIGHT, 'Light - text + essential audio'),
        (NORMAL, 'Normal - audio + images'),
        (COMPLETE, 'Complete - all available media'),
    ]

    DRAFT = 'draft'
    REVIEW = 'review'
    PUBLISHED = 'published'
    ARCHIVED = 'archived'

    STATUS_CHOICES = [
        (DRAFT, 'Draft'),
        (REVIEW, 'Review'),
        (PUBLISHED, 'Published'),
        (ARCHIVED, 'Archived'),
    ]

    title_fr = models.CharField(max_length=255)
    title_en = models.CharField(max_length=255, blank=True)
    title_ar = models.CharField(max_length=255, blank=True)

    slug = models.SlugField(unique=True)

    description_fr = models.TextField(blank=True)
    description_en = models.TextField(blank=True)
    description_ar = models.TextField(blank=True)

    level = models.CharField(
        max_length=30,
        choices=LEVEL_CHOICES,
        default=BEGINNER,
    )

    pack_type = models.CharField(
        max_length=30,
        choices=PACK_TYPE_CHOICES,
        default=NORMAL,
    )

    version = models.PositiveIntegerField(default=1)

    themes = models.ManyToManyField(
        LearningTheme,
        blank=True,
        related_name='offline_packs',
    )

    units = models.ManyToManyField(
        LearningUnit,
        blank=True,
        related_name='offline_packs',
    )

    characters = models.ManyToManyField(
        Character,
        blank=True,
        related_name='offline_packs',
    )

    words = models.ManyToManyField(
        Word,
        blank=True,
        related_name='offline_packs',
    )

    lessons = models.ManyToManyField(
        Lesson,
        blank=True,
        related_name='offline_packs',
    )

    quiz_questions = models.ManyToManyField(
        QuizQuestion,
        blank=True,
        related_name='offline_packs',
    )

    file = models.FileField(
        upload_to='offline_packs/files/',
        validators=[
            FileExtensionValidator(allowed_extensions=['zip']),
        ],
        blank=True,
        null=True,
    )

    manifest = models.JSONField(
        default=dict,
        blank=True,
    )

    checksum = models.CharField(max_length=128, blank=True)
    size_mb = models.FloatField(default=0)
    items_count = models.PositiveIntegerField(default=0)

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=DRAFT,
    )

    is_active = models.BooleanField(default=True)
    is_featured = models.BooleanField(default=False)

    generated_at = models.DateTimeField(blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['level', 'title_fr', 'version']
        verbose_name = 'Lesson Pack'
        verbose_name_plural = 'Lesson Packs'

    def __str__(self):
        return f'{self.title_fr} v{self.version}'

    @property
    def filename(self):
        return f'{self.slug}_v{self.version}.zip'

    def update_file_metadata(self):
        if not self.file:
            return

        file_path = self.file.path

        if not os.path.exists(file_path):
            return

        size_bytes = os.path.getsize(file_path)
        self.size_mb = round(size_bytes / (1024 * 1024), 2)

        sha256 = hashlib.sha256()

        with open(file_path, 'rb') as opened_file:
            for chunk in iter(lambda: opened_file.read(8192), b''):
                sha256.update(chunk)

        self.checksum = sha256.hexdigest()
        self.generated_at = timezone.now()