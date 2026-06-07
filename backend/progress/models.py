from django.conf import settings
from django.db import models

from learning.models import LearningUnit


class UnitProgress(models.Model):
    STARTED = 'started'
    REVIEW = 'review'
    COMPLETED = 'completed'

    STATUS_CHOICES = [
        (STARTED, 'Started'),
        (REVIEW, 'Review'),
        (COMPLETED, 'Completed'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='unit_progress_records',
    )

    device_id = models.CharField(
        max_length=120,
        db_index=True,
        help_text='Identifiant local stable pour utilisateur sans compte.',
    )

    unit = models.ForeignKey(
        LearningUnit,
        on_delete=models.CASCADE,
        related_name='progress_records',
    )

    status = models.CharField(
        max_length=30,
        choices=STATUS_CHOICES,
        default=STARTED,
    )

    last_stage = models.CharField(
        max_length=50,
        default='intro',
        help_text='intro, lessons, characters, words, quiz, result',
    )

    lessons_seen = models.PositiveIntegerField(default=0)
    characters_seen = models.PositiveIntegerField(default=0)
    words_seen = models.PositiveIntegerField(default=0)
    quizzes_answered = models.PositiveIntegerField(default=0)
    correct_answers = models.PositiveIntegerField(default=0)

    best_score_percent = models.PositiveIntegerField(default=0)

    completed = models.BooleanField(default=False)

    started_at = models.DateTimeField(blank=True, null=True)
    completed_at = models.DateTimeField(blank=True, null=True)

    client_updated_at = models.DateTimeField(blank=True, null=True)
    synced_at = models.DateTimeField(auto_now=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-client_updated_at', '-synced_at']
        constraints = [
            models.UniqueConstraint(
                fields=['device_id', 'unit'],
                name='unique_device_unit_progress',
            ),
        ]
        indexes = [
            models.Index(fields=['device_id']),
            models.Index(fields=['status']),
            models.Index(fields=['completed']),
        ]

    def __str__(self):
        return f'{self.device_id} — {self.unit.slug} — {self.status}'