import hashlib
import os

from django.core.validators import FileExtensionValidator
from django.db import models
from core.media_validation import ValidatedMediaModel
from django.utils import timezone

from alphabet.models import Character
from learning.models import LearningTheme, LearningUnit
from lessons.models import Lesson
from quizzes.models import QuizQuestion
from vocabulary.models import Word


class LessonPack(ValidatedMediaModel):
    def save(self, *args, **kwargs):
        update_fields = kwargs.get('update_fields')
        new_file = bool(self.file and not self.file._committed and
                        (update_fields is None or 'file' in update_fields))
        if not new_file:
            return super().save(*args, **kwargs)
        from django.db import transaction
        with transaction.atomic():
            result = super().save(*args, **kwargs)
            # Metadata for this fresh upload only. Existing archives stay intact.
            with self.file.open('rb') as stream:
                self.checksum = hashlib.file_digest(stream, 'sha256').hexdigest()
            self.size_mb = round(self.file.size / (1024 * 1024), 2)
            self.generated_at = timezone.now()
            super().save(update_fields=['checksum', 'size_mb', 'generated_at'])
        return result

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

    manifest = models.JSONField(default=dict, blank=True)
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
        """
        Calcule la taille et le SHA-256 en flux via l'API Storage (A04).
        Fonctionne avec stockage local (FileSystemStorage) et distant (S3 / R2).
        """
        if not self.file or not getattr(self.file, 'name', None):
            return

        storage = self.file.storage
        sha256 = hashlib.sha256()
        total_size = 0

        try:
            total_size = storage.size(self.file.name)
        except Exception:
            total_size = 0

        try:
            with storage.open(self.file.name, 'rb') as opened_file:
                bytes_read = 0
                for chunk in iter(lambda: opened_file.read(65536), b''):
                    sha256.update(chunk)
                    bytes_read += len(chunk)

                if total_size <= 0:
                    total_size = bytes_read
        except Exception:
            return

        self.size_mb = round(total_size / (1024 * 1024), 2)
        self.checksum = sha256.hexdigest()
        self.generated_at = timezone.now()
