from django.core.exceptions import ValidationError
from django.db import models

from alphabet.models import Character
from audio_assets.models import AudioAsset
from learning.models import LearningUnit
from lessons.models import Lesson
from vocabulary.models import Word


class QuizQuestion(models.Model):
    AUDIO_TO_CHARACTER = 'audio_to_character'
    CHARACTER_TO_AUDIO = 'character_to_audio'
    AUDIO_TO_IMAGE = 'audio_to_image'
    IMAGE_TO_AUDIO = 'image_to_audio'
    LISTEN_AND_REPEAT = 'listen_and_repeat'
    GUIDED_KEYBOARD = 'guided_keyboard'
    TEXT_TO_CHARACTER = 'text_to_character'

    QUESTION_TYPE_CHOICES = [
        (AUDIO_TO_CHARACTER, 'Audio to character'),
        (CHARACTER_TO_AUDIO, 'Character to audio'),
        (AUDIO_TO_IMAGE, 'Audio to image'),
        (IMAGE_TO_AUDIO, 'Image to audio'),
        (LISTEN_AND_REPEAT, 'Listen and repeat'),
        (GUIDED_KEYBOARD, 'Guided keyboard'),
        (TEXT_TO_CHARACTER, 'Text to character'),
    ]

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
        blank=True,
        null=True,
        related_name='quiz_questions',
    )

    lesson = models.ForeignKey(
        Lesson,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='quiz_questions',
    )

    question_type = models.CharField(
        max_length=50,
        choices=QUESTION_TYPE_CHOICES,
        default=AUDIO_TO_CHARACTER,
    )

    difficulty = models.CharField(
        max_length=30,
        choices=DIFFICULTY_CHOICES,
        default=BEGINNER,
    )

    prompt_fr = models.CharField(
        max_length=255,
        blank=True,
        help_text='Instruction visible. Ex: Écoute et choisis le bon caractère.',
    )
    prompt_en = models.CharField(max_length=255, blank=True)
    prompt_ar = models.CharField(max_length=255, blank=True)

    oral_prompt_fr = models.CharField(
        max_length=255,
        blank=True,
        help_text='Instruction destinée à être lue ou jouée en audio.',
    )
    oral_prompt_en = models.CharField(max_length=255, blank=True)
    oral_prompt_ar = models.CharField(max_length=255, blank=True)

    character = models.ForeignKey(
        Character,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='quiz_questions',
    )

    word = models.ForeignKey(
        Word,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='quiz_questions',
    )

    question_image = models.ImageField(
        upload_to='quizzes/questions/images/',
        blank=True,
        null=True,
    )

    correct_text_answer = models.CharField(
        max_length=255,
        blank=True,
        help_text='Pour guided_keyboard ou réponse textuelle.',
    )

    explanation_fr = models.TextField(blank=True)
    explanation_en = models.TextField(blank=True)
    explanation_ar = models.TextField(blank=True)

    order_index = models.PositiveIntegerField(default=0)
    points = models.PositiveIntegerField(default=1)

    min_options_required = models.PositiveIntegerField(default=2)

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
        ordering = ['difficulty', 'order_index', 'id']
        verbose_name = 'Quiz Question'
        verbose_name_plural = 'Quiz Questions'
        indexes = [
            models.Index(fields=['question_type']),
            models.Index(fields=['difficulty']),
            models.Index(fields=['status']),
        ]

    def __str__(self):
        return f'{self.question_type} — {self.prompt_fr[:50] or self.id}'

    def clean(self):
        if self.status == self.PUBLISHED:
            if self.question_type in [
                self.AUDIO_TO_CHARACTER,
                self.AUDIO_TO_IMAGE,
                self.CHARACTER_TO_AUDIO,
                self.IMAGE_TO_AUDIO,
                self.LISTEN_AND_REPEAT,
            ]:
                if not self.pk:
                    return

                has_question_audio = self.audio_links.filter(
                    role=QuizQuestionAudio.QUESTION,
                    audio_asset__validation_status=AudioAsset.PUBLISHED,
                ).exists()

                if not has_question_audio:
                    raise ValidationError(
                        'Un quiz audio publié doit avoir un AudioAsset publié avec role=question.'
                    )


class QuizOption(models.Model):
    question = models.ForeignKey(
        QuizQuestion,
        on_delete=models.CASCADE,
        related_name='options',
    )

    text_fr = models.CharField(max_length=255, blank=True)
    text_en = models.CharField(max_length=255, blank=True)
    text_ar = models.CharField(max_length=255, blank=True)

    character = models.ForeignKey(
        Character,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='quiz_options',
    )

    word = models.ForeignKey(
        Word,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='quiz_options',
    )

    image = models.ImageField(
        upload_to='quizzes/options/images/',
        blank=True,
        null=True,
    )

    is_correct = models.BooleanField(default=False)
    order_index = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['question', 'order_index', 'id']
        verbose_name = 'Quiz Option'
        verbose_name_plural = 'Quiz Options'

    def __str__(self):
        if self.text_fr:
            return self.text_fr
        if self.character:
            return str(self.character)
        if self.word:
            return str(self.word)
        return f'Option {self.id}'


class QuizQuestionAudio(models.Model):
    QUESTION = 'question'
    SLOW_QUESTION = 'slow_question'
    EXPLANATION = 'explanation'
    CORRECTION = 'correction'

    ROLE_CHOICES = [
        (QUESTION, 'Question audio'),
        (SLOW_QUESTION, 'Slow question audio'),
        (EXPLANATION, 'Explanation audio'),
        (CORRECTION, 'Correction audio'),
    ]

    question = models.ForeignKey(
        QuizQuestion,
        on_delete=models.CASCADE,
        related_name='audio_links',
    )

    audio_asset = models.ForeignKey(
        AudioAsset,
        on_delete=models.CASCADE,
        related_name='quiz_question_links',
    )

    role = models.CharField(
        max_length=40,
        choices=ROLE_CHOICES,
        default=QUESTION,
    )

    is_primary = models.BooleanField(default=True)
    order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['question', 'role', '-is_primary', 'order']
        constraints = [
            models.UniqueConstraint(
                fields=['question', 'audio_asset', 'role'],
                name='unique_quiz_question_audio_role',
            ),
        ]

    def __str__(self):
        return f'Quiz {self.question_id} — {self.role}'