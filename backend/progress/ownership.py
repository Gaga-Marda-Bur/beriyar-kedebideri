"""Server-side account/guest boundaries shared by progress reads and writes."""
import hashlib

from django.utils.crypto import constant_time_compare
from rest_framework.exceptions import PermissionDenied

from .models import ProgressDeviceCredential, UnitProgress

DENIED = 'Preuve de propriété absente ou invalide. Historique conservé.'
ACCOUNT_PREFIX = 'account:'


def digest_token(token):
    # Installation tokens are random bearer secrets, not human passwords.
    return hashlib.sha256(token.encode('utf-8')).hexdigest()


def guest_progress_queryset(device_id, token):
    if not device_id or len(device_id) > 120 or device_id.startswith(ACCOUNT_PREFIX) or not token or len(token) > 128:
        raise PermissionDenied(DENIED)
    credential = ProgressDeviceCredential.objects.filter(device_id=device_id).first()
    if credential and (credential.account_bound or not constant_time_compare(credential.token_digest, digest_token(token))):
        raise PermissionDenied(DENIED)
    records = UnitProgress.objects.filter(device_id=device_id)
    if records.filter(user__isnull=False).exists() or records.filter(account_bound=True).exists():
        raise PermissionDenied(DENIED)
    # A token on one historical unit never grants access to another token or
    # a legacy tokenless row. GET does not register, claim or repair anything.
    owned = records.filter(user__isnull=True, account_bound=False, device_token=token)
    if not credential and not owned.exists():
        raise PermissionDenied(DENIED)
    return owned


def _lock_credential(device_id, token, user):
    """Called inside atomic(); unique PK serializes first-registration races."""
    if not token or device_id.startswith(ACCOUNT_PREFIX):
        raise PermissionDenied(DENIED)
    credential = ProgressDeviceCredential.objects.select_for_update().filter(device_id=device_id).first()
    records = UnitProgress.objects.filter(device_id=device_id)
    if records.filter(account_bound=True, user__isnull=True).exists():
        raise PermissionDenied(DENIED)
    if records.filter(user__isnull=False).exclude(user=user if user.is_authenticated else None).exists():
        raise PermissionDenied(DENIED)
    if credential is None:
        tokens = set(records.values_list('device_token', flat=True))
        # No first-claim recovery for legacy/ambiguous histories. Nothing is erased.
        if tokens and (len(tokens) != 1 or '' in tokens or not constant_time_compare(next(iter(tokens)), token)):
            raise PermissionDenied(DENIED)
        credential, _ = ProgressDeviceCredential.objects.get_or_create(
            device_id=device_id, defaults={'token_digest': digest_token(token)})
        # get_or_create can return the concurrent winner; always recheck under lock.
        credential = ProgressDeviceCredential.objects.select_for_update().get(pk=credential.pk)
    if not constant_time_compare(credential.token_digest, digest_token(token)):
        raise PermissionDenied(DENIED)
    if credential.account_bound and (not user.is_authenticated or credential.user_id != user.pk):
        raise PermissionDenied(DENIED)
    return credential


def progress_for_sync(user, unit, device_id, token):
    """Return only an owned record, or a new record attributed by the server."""
    if user.is_authenticated:
        owned = UnitProgress.objects.select_for_update().filter(user=user, unit=unit).first()
        if owned:
            return owned  # Account identity is stronger than an installation token.
        if not device_id or not token:
            # Stable server namespace prevents the old shared empty-device collision.
            device_id = f'{ACCOUNT_PREFIX}{user.pk}'
            existing = UnitProgress.objects.select_for_update().filter(device_id=device_id, unit=unit).first()
            if existing and existing.user_id != user.pk:
                raise PermissionDenied(DENIED)
            return existing or UnitProgress(user=user, unit=unit, device_id=device_id)
    if not device_id:
        raise PermissionDenied(DENIED)
    credential = _lock_credential(device_id, token, user)
    progress = UnitProgress.objects.select_for_update().filter(device_id=device_id, unit=unit).first()
    if progress:
        if progress.user_id:
            if not user.is_authenticated or progress.user_id != user.pk:
                raise PermissionDenied(DENIED)
        elif progress.account_bound or not progress.device_token or not constant_time_compare(progress.device_token, token):
            raise PermissionDenied(DENIED)
    else:
        progress = UnitProgress(device_id=device_id, device_token=token, unit=unit)
    if user.is_authenticated:
        progress.user = user
        credential.user = user
        credential.account_bound = True
        credential.save(update_fields=['user', 'account_bound'])
    return progress
