import secrets

from django.conf import settings
from django.db import models


def _generate_deletion_reference():
    return f"DEL-{secrets.token_hex(4).upper()}"


class AccountDeletionRequest(models.Model):
    SOURCE_MOBILE = 'mobile'
    SOURCE_WEB = 'web'
    SOURCE_CHOICES = [
        (SOURCE_MOBILE, 'Mobile'),
        (SOURCE_WEB, 'Web'),
    ]

    STATUS_PENDING = 'pending'
    STATUS_IN_REVIEW = 'in_review'
    STATUS_COMPLETED = 'completed'
    STATUS_REJECTED = 'rejected'
    STATUS_CHOICES = [
        (STATUS_PENDING, 'Pending'),
        (STATUS_IN_REVIEW, 'In review'),
        (STATUS_COMPLETED, 'Completed'),
        (STATUS_REJECTED, 'Rejected'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='deletion_requests',
    )
    requested_username = models.CharField(max_length=150)
    has_email = models.BooleanField(default=False)
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES, default=SOURCE_WEB)
    verification_method = models.CharField(max_length=32, default='session_and_password')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_PENDING)
    user_note = models.TextField(blank=True, default='', max_length=500)
    reference_code = models.CharField(
        max_length=24,
        unique=True,
        default=_generate_deletion_reference,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    processed_at = models.DateTimeField(null=True, blank=True)
    admin_notes = models.TextField(blank=True, default='')

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.reference_code} ({self.requested_username} - {self.status})"
