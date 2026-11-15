import hashlib
import logging
import os

from django.core.files.base import ContentFile
from django.core.validators import FileExtensionValidator
from django.db import models
from core.media_storage import PrivatePackStorage
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
        new_public_file = bool(
            self.file
            and not self.file._committed
            and (update_fields is None or 'file' in update_fields)
        )
        new_private_file = bool(
            self.private_file
            and not self.private_file._committed
            and (update_fields is None or 'private_file' in update_fields)
        )
        from django.db import transaction
        with transaction.atomic():
            if not new_public_file and not new_private_file:
                result = super().save(*args, **kwargs)
            else:
                result = super().save(*args, **kwargs)
                # Metadata for this fresh upload only. Existing archives stay intact.
                target = self.private_file if new_private_file else self.file
                with target.open('rb') as stream:
                    self.checksum = hashlib.file_digest(stream, 'sha256').hexdigest()
                self.size_mb = round(target.size / (1024 * 1024), 2)
                self.generated_at = timezone.now()
                super().save(update_fields=['checksum', 'size_mb', 'generated_at'])
            self._sync_storage_for_status()
        return result

    @staticmethod
    def _safe_delete_storage_object(storage, name):
        if not name:
            return
        try:
            if storage.exists(name):
                storage.delete(name)
        except Exception:
            logging.getLogger(__name__).warning(
                'Failed to delete stale LessonPack storage object %r; safe to clean up via reconcile_pack_storage.',
                name,
                exc_info=True,
            )

    def _sync_storage_for_status(self):
        """
        Keep physical archive placement aligned with LessonPack.status:
        - Non-published packs must never leave a copy in public `file` storage.
        - Published packs must expose a copy in `file` if only `private_file` exists.
        Old physical objects are deleted only via transaction.on_commit so a DB
        rollback never causes data loss.
        """
        from django.db import transaction

        if self.status != self.PUBLISHED and self.file:
            old_name = self.file.name
            old_storage = self.file.storage
            copied_name = None
            if not self.private_file and old_name and old_storage.exists(old_name):
                with old_storage.open(old_name, 'rb') as stream:
                    self.private_file.save(self.filename, ContentFile(stream.read()), save=False)
                copied_name = self.private_file.name
            self.file.close()
            self.file = None
            try:
                super().save(update_fields=['file', 'private_file'])
            except Exception:
                if copied_name:
                    self._safe_delete_storage_object(self.private_file.storage, copied_name)
                raise
            if old_name:
                transaction.on_commit(lambda s=old_storage, n=old_name: self._safe_delete_storage_object(s, n))
        elif self.status == self.PUBLISHED and self.private_file and not self.file:
            priv_name = self.private_file.name
            priv_storage = self.private_file.storage
            copied_name = None
            if priv_name and priv_storage.exists(priv_name):
                with priv_storage.open(priv_name, 'rb') as stream:
                    self.file.save(self.filename, ContentFile(stream.read()), save=False)
                copied_name = self.file.name
            self.private_file.close()
            self.private_file = None
            try:
                super().save(update_fields=['file', 'private_file'])
            except Exception:
                if copied_name:
                    self._safe_delete_storage_object(self.file.storage, copied_name)
                raise
            if priv_name:
                transaction.on_commit(lambda s=priv_storage, n=priv_name: self._safe_delete_storage_object(s, n))

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

    private_file = models.FileField(
        upload_to='offline_packs/files/',
        storage=PrivatePackStorage(),
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

    @property
    def active_file(self):
        if self.status == self.PUBLISHED:
            return self.file or self.private_file
        return self.private_file or self.file

    def update_file_metadata(self):
        """
        Calcule la taille et le SHA-256 en flux via l'API Storage (A04).
        Fonctionne avec stockage local (FileSystemStorage) et distant (S3 / R2).
        """
        target = self.active_file
        if not target or not getattr(target, 'name', None):
            return

        storage = target.storage
        sha256 = hashlib.sha256()
        total_size = 0

        try:
            total_size = storage.size(target.name)
        except Exception:
            total_size = 0

        try:
            with storage.open(target.name, 'rb') as opened_file:
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
