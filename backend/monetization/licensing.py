"""Fixed-algorithm simulation leases; private key is provisioned externally only."""
import base64
import hashlib
import json
import secrets
import re
import uuid
from datetime import timedelta
from pathlib import Path

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, ed25519
from django.conf import settings
from django.core.exceptions import PermissionDenied, ValidationError
from django.db import transaction
from django.utils import timezone

from .models import DeviceChallenge, DeviceKey, CommerceAccountState
from .services import entitlements, public_config, state_for


def require_account(user):
    from django.contrib.auth import get_user_model
    if not user.pk or not get_user_model().objects.filter(pk=user.pk, is_active=True).exists():
        raise PermissionDenied('Active account required.')


def signing_key():
    if settings.DJANGO_ENV not in ('development', 'test'):
        raise PermissionDenied('Simulation leases are disabled in production.')
    filename = getattr(settings, 'MONETIZATION_SIGNING_KEY_FILE', '')
    kid = getattr(settings, 'MONETIZATION_SIGNING_KID', '')
    if not filename or not re.fullmatch(r'sim-[A-Za-z0-9_-]{1,64}',kid):
        raise ValidationError('Simulation signer is not provisioned.')
    key = serialization.load_pem_private_key(Path(filename).read_bytes(), password=None)
    if not isinstance(key, ed25519.Ed25519PrivateKey):
        raise ValidationError('Ed25519 required.')
    return key, kid


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode('ascii')


def sign_claims(claims, key, kid):
    payload = b64(json.dumps(claims, sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode('ascii'))
    signed = f'BK-OFFLINE-GRANT/v1\n{kid}\n{payload}'.encode('ascii')
    return {'version':1, 'kid':kid, 'payload_b64url':payload, 'signature_b64url':b64(key.sign(signed))}


def challenge(user, purpose):
    require_account(user)
    if settings.DJANGO_ENV not in ('development', 'test') or purpose not in ('enroll','lease'):
        raise PermissionDenied('Simulation only.')
    now = timezone.now()
    if DeviceChallenge.objects.filter(user=user, used=False, expires_at__gt=now).count() >= 20:
        raise ValidationError('Too many pending challenges; retry after expiry.')
    return DeviceChallenge.objects.create(user=user, purpose=purpose,
        nonce=secrets.token_urlsafe(32), expires_at=now+timedelta(minutes=2))


def consume_challenge(user, challenge_id, purpose):
    try:
        row = DeviceChallenge.objects.select_for_update().get(pk=challenge_id, user=user,
            purpose=purpose, used=False, expires_at__gt=timezone.now())
    except (DeviceChallenge.DoesNotExist, ValueError, ValidationError) as exc:
        raise PermissionDenied('Invalid or expired challenge.') from exc
    return row


def proof_message(row):
    return f'BK-DEVICE/v1\n{row.purpose}\n{row.pk}\n{row.nonce}'.encode('ascii')


def verify_proof(row, public_key, signature):
    try:
        der = base64.b64decode(public_key, validate=True)
        key = serialization.load_der_public_key(der)
        if not isinstance(key, ec.EllipticCurvePublicKey) or not isinstance(key.curve, ec.SECP256R1):
            raise ValueError('P-256 required')
        key.verify(base64.b64decode(signature, validate=True), proof_message(row), ec.ECDSA(hashes.SHA256()))
        return hashlib.sha256(der).hexdigest()
    except (ValueError, TypeError, InvalidSignature) as exc:
        raise PermissionDenied('Invalid device possession proof.') from exc


@transaction.atomic
def enroll(user, challenge_id, public_key, signature):
    require_account(user)
    if settings.DJANGO_ENV not in ('development', 'test'):
        raise PermissionDenied('Simulation only.')
    row = consume_challenge(user, challenge_id, 'enroll')
    thumbprint = verify_proof(row, public_key, signature)
    device, _ = DeviceKey.objects.get_or_create(user=user, thumbprint=thumbprint,
        defaults={'public_key':public_key})
    if device.revoked_at:
        raise PermissionDenied('Key revoked; create a new device key.')
    row.used = True
    row.save(update_fields=['used'])
    return device


@transaction.atomic
def issue_lease(user, challenge_id, device_id, signature):
    require_account(user)
    key, kid = signing_key()
    row = consume_challenge(user, challenge_id, 'lease')
    try:
        device = DeviceKey.objects.get(pk=device_id, user=user, revoked_at=None)
    except (DeviceKey.DoesNotExist, ValueError, ValidationError) as exc:
        raise PermissionDenied('Device not owned or revoked.') from exc
    verify_proof(row, device.public_key, signature)
    state_for(user)
    CommerceAccountState.objects.select_for_update().get(user=user)
    rights = entitlements(user)
    now = int(timezone.now().timestamp())
    policy = public_config()
    end = min(now+policy['offline_max_seconds'], rights['expires_at'] or now)
    claims = {'version':1, 'issuer':'bk', 'audience':'bk-android-simulation',
        'environment':settings.DJANGO_ENV, 'subject':rights['subject'],
        'lease_id':str(uuid.uuid4()), 'entitlement_epoch':rights['epoch'],
        'device_id':str(device.pk), 'device_key_thumbprint':device.thumbprint,
        'features':rights['features'], 'grant_ids':[g['id'] for g in rights['grants']],
        'issued_at':now,'starts_at':now,'expires_at':end,'offline_valid_until':end,
        'server_now':now,'nonce':row.nonce,'policy_version':policy['version']}
    # JCS-compatible subset: ASCII keys/values, integers, arrays; no floats/UTF-16 sorting ambiguity.
    row.used = True
    row.save(update_fields=['used'])
    return sign_claims(claims, key, kid)
