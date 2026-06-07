from django.db import models

from alphabet.models import Character
from audio_assets.models import AudioAsset
from learning.models import LearningUnit
from vocabulary.models import Word


class Lesson(models.Model):
    BEGINNER = 'beginner'
    INTERMEDIATE = 'intermediate'
    ADVANCED = 'advanced'

    LEVEL_CHOICES = [
        (BEGINNER, 'Beginner'),
        (INTERMEDIATE, 'Intermediate'),
        (ADVANCED, 'Advanced'),
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

    unit = models.ForeignKey(
        LearningUnit,
        on_delete=models.CASCADE,
        related_name='lessons',
    )

    slug = models.SlugField(unique=True)

    title_fr = models.CharField(max_length=255)
    title_en = models.CharField(max_length=255, blank=True)
    title_ar = models.CharField(max_length=255, blank=True)

    description_fr = models.TextField(blank=True)
    description_en = models.TextField(blank=True)
    description_ar = models.TextField(blank=True)

    oral_intro_fr = models.CharField(
        max_length=255,
        blank=True,
        help_text='Ex: Écoute ce son, puis répète.',
    )
    oral_intro_en = models.CharField(max_length=255, blank=True)
    oral_intro_ar = models.CharField(max_length=255, blank=True)

    level = models.CharField(
        max_length=30,
        choices=LEVEL_CHOICES,
        default=BEGINNER,
    )

    order_index = models.PositiveIntegerField(default=0)
    estimated_minutes = models.PositiveIntegerField(default=3)

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=DRAFT,
    )

    is_active = models.BooleanField(default=True)
    available_offline = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['unit', 'order_index', 'title_fr']
        verbose_name = 'Lesson'
        verbose_name_plural = 'Lessons'

    def __str__(self):
        return f'{self.unit.title_fr} — {self.title_fr}'


class LessonItem(models.Model):
    CHARACTER = 'character'
    WORD = 'word'
    AUDIO_ONLY = 'audio_only'
    IMAGE_ONLY = 'image_only'
    PRACTICE = 'practice'
    EXPLANATION = 'explanation'

    ITEM_TYPE_CHOICES = [
        (CHARACTER, 'Character'),
        (WORD, 'Word'),
        (AUDIO_ONLY, 'Audio only'),
        (IMAGE_ONLY, 'Image only'),
        (PRACTICE, 'Practice'),
        (EXPLANATION, 'Explanation'),
    ]

    lesson = models.ForeignKey(
        Lesson,
        on_delete=models.CASCADE,
        related_name='items',
    )

    item_type = models.CharField(
        max_length=30,
        choices=ITEM_TYPE_CHOICES,
        default=CHARACTER,
    )

    character = models.ForeignKey(
        Character,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='lesson_items',
    )

    word = models.ForeignKey(
        Word,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='lesson_items',
    )

    title_fr = models.CharField(max_length=255, blank=True)
    title_en = models.CharField(max_length=255, blank=True)
    title_ar = models.CharField(max_length=255, blank=True)

    oral_prompt_fr = models.CharField(
        max_length=255,
        blank=True,
        help_text='Ex: Écoute et répète deux fois.',
    )
    oral_prompt_en = models.CharField(max_length=255, blank=True)
    oral_prompt_ar = models.CharField(max_length=255, blank=True)

    explanation_fr = models.TextField(blank=True)
    explanation_en = models.TextField(blank=True)
    explanation_ar = models.TextField(blank=True)

    writing_hint_fr = models.TextField(blank=True)
    writing_hint_en = models.TextField(blank=True)
    writing_hint_ar = models.TextField(blank=True)

    image = models.ImageField(
        upload_to='lessons/items/images/',
        blank=True,
        null=True,
    )

    repeat_count = models.PositiveIntegerField(
        default=2,
        help_text='Nombre de répétitions conseillé pour l’approche oral-first.',
    )

    order_index = models.PositiveIntegerField(default=0)

    is_active = models.BooleanField(default=True)
    available_offline = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['lesson', 'order_index', 'id']
        verbose_name = 'Lesson Item'
        verbose_name_plural = 'Lesson Items'

    def __str__(self):
        title = self.title_fr or self.item_type
        return f'{self.lesson.title_fr} — {title}'


class LessonItemAudio(models.Model):
    NORMAL = 'normal'
    SLOW = 'slow'
    PROMPT = 'prompt'
    EXPLANATION = 'explanation'

    ROLE_CHOICES = [
        (NORMAL, 'Normal content audio'),
        (SLOW, 'Slow content audio'),
        (PROMPT, 'Oral instruction'),
        (EXPLANATION, 'Explanation'),
    ]

    lesson_item = models.ForeignKey(
        LessonItem,
        on_delete=models.CASCADE,
        related_name='audio_links',
    )

    audio_asset = models.ForeignKey(
        AudioAsset,
        on_delete=models.CASCADE,
        related_name='lesson_item_links',
    )

    role = models.CharField(
        max_length=40,
        choices=ROLE_CHOICES,
        default=NORMAL,
    )

    is_primary = models.BooleanField(default=True)
    order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['lesson_item', 'role', '-is_primary', 'order']
        constraints = [
            models.UniqueConstraint(
                fields=['lesson_item', 'audio_asset', 'role'],
                name='unique_lesson_item_audio_role',
            ),
        ]

    def __str__(self):
        return f'{self.lesson_item} — {self.role}'