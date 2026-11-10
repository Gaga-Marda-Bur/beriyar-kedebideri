from django.conf import settings
from django.db import models

from learning.models import LearningUnit


class ProgressDeviceCredential(models.Model):
    """One immutable installation credential; never serialized to clients."""
    device_id = models.CharField(max_length=120, primary_key=True)
    token_digest = models.CharField(max_length=64)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                             on_delete=models.SET_NULL, related_name='+')
    # Remains true after account deletion: an old guest token must not reopen it.
    account_bound = models.BooleanField(default=False)


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

    account_bound = models.BooleanField(default=False)

    device_id = models.CharField(
        max_length=120,
        db_index=True,
        help_text='Identifiant local stable pour utilisateur sans compte.',
    )

    device_token = models.CharField(
        max_length=128,
        blank=True,
        default='',
        db_index=True,
        help_text='Jeton d\'installation ou preuve de propriété de la progression locale.',
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
    scoring_version = models.PositiveSmallIntegerField(default=1)
    last_session_score = models.PositiveSmallIntegerField(blank=True, null=True)

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

    def save(self, *args, **kwargs):
        # SET_NULL on account deletion must never turn private history into guest data.
        if self.user_id:
            self.account_bound = True
            if kwargs.get('update_fields') is not None:
                kwargs['update_fields'] = set(kwargs['update_fields']) | {'account_bound'}
        return super().save(*args, **kwargs)
