from django.contrib.auth import get_user_model
from django.contrib.sessions.models import Session
from django.db import transaction
from django.db.models import Q
from django.utils import timezone

from .models import AccountDeletionRequest


class AccountDeletionError(Exception):
    """Raised when an account deletion cannot be completed safely."""


def _delete_user_sessions(user_id: int) -> int:
    target_uid = str(user_id)
    deleted_count = 0
    for session in Session.objects.all().iterator():
        try:
            decoded = session.get_decoded()
        except Exception:
            continue
        if str(decoded.get('_auth_user_id', '')) == target_uid:
            session.delete()
            deleted_count += 1
    return deleted_count


def execute_account_deletion(
    deletion_request: AccountDeletionRequest,
    *,
    admin_note: str = '',
) -> dict:
    """
    Atomically delete a user account and associated personal data for a pending/in-review
    AccountDeletionRequest, anonymize technical feedback, purge sessions, and scrub PII
    from the request record itself.
    """
    from feedback.models import FeedbackReport
    from no_ena.models import NoEnaPublication
    from progress.models import ProgressDeviceCredential, UnitProgress

    if deletion_request.status not in (
        AccountDeletionRequest.STATUS_PENDING,
        AccountDeletionRequest.STATUS_IN_REVIEW,
    ):
        raise AccountDeletionError(
            f"La demande {deletion_request.reference_code} a déjà le statut '{deletion_request.status}'."
        )

    User = get_user_model()
    with transaction.atomic():
        locked_req = (
            AccountDeletionRequest.objects.select_for_update()
            .select_related('user')
            .get(pk=deletion_request.pk)
        )
        if locked_req.status not in (
            AccountDeletionRequest.STATUS_PENDING,
            AccountDeletionRequest.STATUS_IN_REVIEW,
        ):
            raise AccountDeletionError(
                f"La demande {locked_req.reference_code} a déjà le statut '{locked_req.status}'."
            )

        target_user = locked_req.user
        if target_user is None:
            raise AccountDeletionError(
                f"Aucun utilisateur actif lié à la demande {locked_req.reference_code}."
            )

        user_id = target_user.pk
        account_device_id = f"account:{user_id}"

        progress_deleted, _ = UnitProgress.objects.filter(
            Q(user=target_user) | Q(device_id=account_device_id)
        ).delete()

        creds_deleted, _ = ProgressDeviceCredential.objects.filter(
            Q(user=target_user) | Q(device_id=account_device_id)
        ).delete()

        feedback_anonymized = FeedbackReport.objects.filter(user=target_user).update(
            user=None,
            device_id='',
        )

        no_ena_dissociated = NoEnaPublication.objects.filter(
            contributor_user=target_user
        ).update(contributor_user=None)

        sessions_deleted = _delete_user_sessions(user_id)

        User.objects.filter(pk=user_id).delete()

        locked_req.user = None
        locked_req.requested_username = f"[deleted:{locked_req.reference_code}]"
        locked_req.user_note = ''
        locked_req.status = AccountDeletionRequest.STATUS_COMPLETED
        locked_req.processed_at = timezone.now()
        if admin_note:
            locked_req.admin_notes = admin_note
        elif not locked_req.admin_notes:
            locked_req.admin_notes = (
                f"Compte supprimé de manière atomique ({locked_req.reference_code})."
            )
        locked_req.save(
            update_fields=[
                'user',
                'requested_username',
                'user_note',
                'status',
                'processed_at',
                'admin_notes',
            ]
        )

    return {
        'reference_code': locked_req.reference_code,
        'progress_deleted': progress_deleted,
        'credentials_deleted': creds_deleted,
        'feedback_anonymized': feedback_anonymized,
        'no_ena_dissociated': no_ena_dissociated,
        'sessions_deleted': sessions_deleted,
    }
