"""All commercial writes go through permissioned, atomic simulation services."""
import hashlib
import json
import re
from datetime import timedelta

from django.conf import settings
from django.core.exceptions import PermissionDenied, ValidationError
from django.db import transaction, IntegrityError
from django.db.models import F
from django.utils import timezone

from .models import (CommercialPolicy, CommerceAccountState, CommercialRequest,
                     PaymentTransaction, EntitlementGrant, AuditEvent, OutboxEvent,
                     FREE_FEATURES, SIM_FEATURES)


def require(actor, *permissions):
    if not actor or not actor.is_authenticated or not actor.is_active or any(
            not actor.has_perm('monetization.' + p) for p in permissions):
        raise PermissionDenied('Explicit commerce permissions required.')
    if settings.DJANGO_ENV == 'production':
        raise PermissionDenied('Simulation writes are disabled in production.')


def audit(actor, action, target, reason):
    if not isinstance(reason, str) or not 3 <= len(reason.strip()) <= 240:
        raise ValidationError('A short explicit reason is required (3–240 characters).')
    return AuditEvent.objects.create(actor=actor, action=action, target=str(target), reason=reason.strip())


def state_for(user):
    return CommerceAccountState.objects.get_or_create(user=user)[0]


def public_config():
    policy = CommercialPolicy.objects.first()
    return {'version': policy.version if policy else 1, 'mode': 'simulation',
            'ads_enabled': False, 'premium_sales_enabled': False, 'tracking_enabled': False,
            'personalized_ads_enabled': False, 'advertising_id_collection': False,
            'audience': 'mixed', 'unknown_age_policy': 'most_protective',
            'parental_consent': 'not_implemented_no_consent_assumed',
            'offline_max_seconds': min(policy.offline_days if policy else 7, 7) * 86400,
            'free_features': list(FREE_FEATURES), 'placements': []}


def entitlements(user):
    now = timezone.now()
    state = state_for(user)
    grants = list(EntitlementGrant.objects.filter(user=user, revoked_at=None,
                  starts_at__lte=now, ends_at__gt=now).order_by('ends_at', 'pk'))
    return {'subject': str(state.subject), 'epoch': state.entitlement_epoch,
            'mode': 'simulation', 'status': 'active' if grants else 'free',
            'verification': 'server_verified', 'server_now': int(now.timestamp()),
            'features': sorted({f for g in grants for f in g.features if f in SIM_FEATURES}),
            'free_features': list(FREE_FEATURES),
            'expires_at': min((int(g.ends_at.timestamp()) for g in grants), default=None),
            'grants': [{'id':str(g.pk), 'features':g.features,
                        'starts_at':int(g.starts_at.timestamp()),
                        'expires_at':int(g.ends_at.timestamp())} for g in grants]}


@transaction.atomic
def create_request(*, actor, user, plan, method, key, reason, purpose='purchase'):
    required = {'purchase':'verify_payment', 'donation':'verify_payment',
                'complimentary':'grant_complimentary', 'scholarship':'grant_scholarship'}
    if purpose not in required:
        raise ValidationError('Unknown purpose.')
    require(actor, required[purpose])
    if not user.is_active or not isinstance(key, str) or not 1 <= len(key) <= 120:
        raise ValidationError('Active beneficiary and bounded idempotency key required.')
    if purpose == 'donation' and plan is not None:
        raise ValidationError('Donation must not acquire a digital advantage.')
    if purpose != 'donation' and (not plan or not plan.simulation_available):
        raise ValidationError('A simulation plan is required.')
    if purpose in ('purchase','donation') and not method:
        raise ValidationError('Simulation payment method required.')
    if purpose in ('complimentary','scholarship') and method is not None:
        raise ValidationError('Free grants have no payment method.')
    if method:
        method.full_clean()
        if not method.enabled:
            raise ValidationError('Simulation payment method is disabled.')
    snapshot = sorted(plan.features.values_list('code', flat=True)) if plan else []
    if any(f not in SIM_FEATURES for f in snapshot) or (purpose != 'donation' and not snapshot):
        raise ValidationError('Existing free features cannot be sold.')
    fingerprint = hashlib.sha256(json.dumps([user.pk, plan.pk if plan else None,
        method.pk if method else None, purpose, snapshot, plan.duration_days if plan else None, reason],
        separators=(',', ':')).encode()).hexdigest()
    # Serialize per maker, including creation of the first idempotency record.
    from django.contrib.auth import get_user_model
    get_user_model().objects.select_for_update().get(pk=actor.pk)
    previous = CommercialRequest.objects.filter(created_by=actor, idempotency_key=key).first()
    if previous:
        if previous.fingerprint != fingerprint:
            raise ValidationError('Idempotency conflict.')
        return previous
    state = state_for(user)
    req = CommercialRequest.objects.create(user=user, subject=state.subject, plan=plan,
        method=method, purpose=purpose, created_by=actor, idempotency_key=key,
        fingerprint=fingerprint, reason=reason, feature_snapshot=snapshot,
        duration_days=plan.duration_days if plan else 1,
        amount_minor=100 if purpose in ('purchase','donation') else 0)
    audit(actor, 'create_request', req.pk, reason)
    return req


@transaction.atomic
def transition(*, actor, request_id, action, reason, receipt=None):
    permissions = {'verify':('verify_payment',), 'activate':('approve_payment','grant_entitlement'),
        'reject':('approve_payment',), 'cancel':('approve_payment',),
        'refund':('record_refund',), 'revoke':('revoke_entitlement',)}
    if action not in permissions:
        raise ValidationError('Unknown transition.')
    require(actor, *permissions[action])
    req = CommercialRequest.objects.select_for_update().get(pk=request_id)
    audit_reason = reason  # Validation precedes idempotent returns too.
    if not isinstance(reason, str) or not 3 <= len(reason.strip()) <= 240:
        raise ValidationError('Reason required.')
    if req.user_id is None or not req.user.is_active:
        raise ValidationError('Account deleted or inactive.')
    if actor.pk == req.user_id:
        raise PermissionDenied('Self benefit cannot be approved.')
    state = CommerceAccountState.objects.select_for_update().get(user=req.user)
    if action == 'activate':
        if state.age_band != 'adult':
            require(actor, 'review_protected_account')
        if actor.pk in (req.verified_by_id, req.created_by_id):
            raise PermissionDenied('Independent approver required.')
        if req.purpose == 'complimentary':
            require(actor, 'grant_complimentary')
        if req.purpose == 'scholarship':
            require(actor, 'grant_scholarship')
    target = {'verify':'verified','activate':'activated','reject':'rejected',
              'cancel':'cancelled','refund':'refunded','revoke':'revoked'}[action]
    if req.status == target:
        if action == 'verify' and req.paymenttransaction.receipt != receipt:
            raise ValidationError('Receipt conflict.')
        return req
    if action == 'verify':
        if req.status != 'pending' or req.purpose not in ('purchase','donation'):
            raise ValidationError('Only pending simulated payments can be verified.')
        if not isinstance(receipt, str) or not re.fullmatch(r'SIM-[A-Za-z0-9_-]{1,96}', receipt):
            raise ValidationError('Synthetic SIM- reference required.')
        try:
            with transaction.atomic():
                PaymentTransaction.objects.create(request=req, receipt=receipt,
                    amount_minor=req.amount_minor, currency='XXX')
        except (IntegrityError, ValidationError) as exc:
            raise ValidationError('Receipt already used or invalid.') from exc
        req.verified_by = actor
    elif action == 'activate':
        expected = 'pending' if req.purpose in ('complimentary','scholarship') else 'verified'
        if req.status != expected or req.purpose == 'donation':
            raise ValidationError('Verified purchase or controlled free grant required.')
        now = timezone.now()
        EntitlementGrant.objects.create(user=req.user, subject=req.subject, request=req,
            features=req.feature_snapshot, starts_at=now,
            ends_at=now + timedelta(days=req.duration_days))
        CommerceAccountState.objects.filter(pk=state.pk).update(entitlement_epoch=F('entitlement_epoch')+1)
        req.approved_by = actor
        OutboxEvent.objects.create(request=req)
    elif action in ('refund','revoke'):
        if action == 'refund' and (req.purpose not in ('purchase','donation') or req.status not in ('verified','activated','revoked')):
            raise ValidationError('No simulated payment to refund.')
        if action == 'revoke' and req.status != 'activated':
            raise ValidationError('Only active grants can be revoked.')
        EntitlementGrant.objects.filter(request=req, revoked_at=None).update(revoked_at=timezone.now())
        CommerceAccountState.objects.filter(pk=state.pk).update(entitlement_epoch=F('entitlement_epoch')+1)
    elif req.status != 'pending':
        raise ValidationError('Only pending requests can be cancelled or rejected.')
    req.status = target
    req.save()
    audit(actor, action, req.pk, audit_reason)
    return req
