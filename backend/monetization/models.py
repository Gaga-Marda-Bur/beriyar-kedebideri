"""Additive simulation ledger. No provider, secret, price or pedagogical FK."""
import uuid

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator, MaxValueValidator
from django.db import models
from django.db.models import Q, F

FREE_FEATURES = ('alphabet', 'dictionary', 'initiation', 'audio', 'progress',
                 'offline_packs', 'srs', 'keyboard', 'transliteration', 'editor', 'exports')
SIM_FEATURES = ('simulation.badge', 'ads_free')
SENSITIVE_CONTEXTS = ('lesson', 'quiz', 'audio', 'keyboard', 'srs', 'input',
                      'editor', 'authentication', 'payment', 'profile')


class ValidatedModel(models.Model):
    class Meta:
        abstract = True

    def save(self, *args, **kwargs):
        self.full_clean()
        return super().save(*args, **kwargs)


class CommercialPolicy(ValidatedModel):
    id = models.PositiveSmallIntegerField(primary_key=True, default=1, editable=False)
    version = models.PositiveIntegerField(default=1)
    ads_enabled = models.BooleanField(default=False)
    premium_sales_enabled = models.BooleanField(default=False)
    emergency_stop = models.BooleanField(default=True)
    web_enabled = models.BooleanField(default=False)
    android_enabled = models.BooleanField(default=False)
    max_per_day = models.PositiveSmallIntegerField(default=0)
    minimum_interval_seconds = models.PositiveIntegerField(default=0)
    excluded_categories = models.JSONField(default=list, blank=True)
    offline_days = models.PositiveSmallIntegerField(default=7, validators=[MinValueValidator(1), MaxValueValidator(7)])

    class Meta:
        constraints = [models.CheckConstraint(condition=Q(id=1), name='commerce_policy_singleton'),
                       models.CheckConstraint(condition=Q(ads_enabled=False, premium_sales_enabled=False), name='commerce_live_disabled'),
                       models.CheckConstraint(condition=Q(offline_days__gte=1, offline_days__lte=7), name='commerce_offline_bound')]
        permissions = [('configure_commerce', 'Configure simulation policies'),
                       ('disable_ads_emergency', 'Stop advertising')]

    def clean(self):
        if self.ads_enabled or self.premium_sales_enabled:
            raise ValidationError('Live commerce is prohibited in lot 6.4B.')
        if not isinstance(self.excluded_categories, list) or any(
            not isinstance(x, str) or len(x) > 80 for x in self.excluded_categories):
            raise ValidationError('Categories must be short policy codes, not executable content.')


class PremiumFeature(ValidatedModel):
    code = models.CharField(max_length=80, unique=True)
    label = models.CharField(max_length=120)

    def clean(self):
        if self.code not in SIM_FEATURES:
            raise ValidationError('Only explicitly synthetic/new features are eligible; existing functions stay free.')


class PremiumPlan(ValidatedModel):
    code = models.SlugField(unique=True)
    label = models.CharField(max_length=120)
    revision = models.PositiveIntegerField(default=1)
    duration_days = models.PositiveSmallIntegerField(default=30, validators=[MinValueValidator(1), MaxValueValidator(366)])
    features = models.ManyToManyField(PremiumFeature, blank=True)
    simulation_available = models.BooleanField(default=False)


class CommerceAccountState(ValidatedModel):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    subject = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    entitlement_epoch = models.PositiveBigIntegerField(default=0)
    age_band = models.CharField(max_length=8, choices=[(s,s) for s in ('unknown','minor','adult')], default='unknown')
    # No date of birth, guardian identity or fictitious parental consent collected.


class PaymentMethod(ValidatedModel):
    code = models.SlugField(unique=True)
    kind = models.CharField(max_length=12, choices=[(s,s) for s in ('bank','mobile_money','cash','online')])
    country = models.CharField(max_length=2, default='ZZ')
    currency = models.CharField(max_length=3, default='XXX')
    beneficiary = models.CharField(max_length=80, default='SIMULATION ONLY')
    instructions = models.CharField(max_length=200, default='SIMULATION ONLY')
    enabled = models.BooleanField(default=False)

    def clean(self):
        # No arbitrary bank coordinates / HTML fields in this simulation tranche.
        if self.beneficiary != 'SIMULATION ONLY' or self.instructions != 'SIMULATION ONLY':
            raise ValidationError('Real payment instructions are not accepted in this lot.')
        if self.currency != 'XXX' or self.country != 'ZZ':
            raise ValidationError('Only ISO test currency XXX and undefined country ZZ are allowed.')


class CommercialRequest(ValidatedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name='+')
    subject = models.UUIDField(editable=False)
    plan = models.ForeignKey(PremiumPlan, null=True, blank=True, on_delete=models.PROTECT)
    method = models.ForeignKey(PaymentMethod, null=True, blank=True, on_delete=models.PROTECT)
    purpose = models.CharField(max_length=16, choices=[(s,s) for s in ('purchase','donation','complimentary','scholarship')], default='purchase')
    status = models.CharField(max_length=12, choices=[(s,s) for s in ('pending','verified','activated','rejected','cancelled','refunded','revoked')], default='pending')
    simulated = models.BooleanField(default=True, editable=False)
    amount_minor = models.PositiveBigIntegerField(default=100)
    currency = models.CharField(max_length=3, default='XXX', editable=False)
    feature_snapshot = models.JSONField(default=list, blank=True)
    duration_days = models.PositiveSmallIntegerField(default=30)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name='+')
    verified_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name='+')
    approved_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name='+')
    idempotency_key = models.CharField(max_length=120)
    fingerprint = models.CharField(max_length=64)
    reason = models.CharField(max_length=240)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=['created_by','idempotency_key'], name='commerce_request_idempotent'),
                       models.CheckConstraint(condition=Q(simulated=True, currency='XXX'), name='commerce_request_test_only')]
        permissions = [('verify_payment', 'Verify simulated payments'),
                       ('approve_payment', 'Approve simulated activation'),
                       ('review_protected_account', 'Review simulated minor or unknown-age operations'),
                       ('record_refund', 'Record simulated refunds')]


class PaymentTransaction(ValidatedModel):
    request = models.OneToOneField(CommercialRequest, on_delete=models.PROTECT)
    receipt = models.CharField(max_length=100, unique=True)
    amount_minor = models.PositiveBigIntegerField()
    currency = models.CharField(max_length=3, default='XXX')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.CheckConstraint(condition=Q(currency='XXX', amount_minor__gt=0), name='commerce_transaction_test_only')]


class EntitlementGrant(ValidatedModel):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name='+')
    subject = models.UUIDField(editable=False)
    request = models.OneToOneField(CommercialRequest, on_delete=models.PROTECT)
    features = models.JSONField(default=list)
    starts_at = models.DateTimeField()
    ends_at = models.DateTimeField()
    revoked_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [models.CheckConstraint(condition=Q(ends_at__gt=F('starts_at')), name='commerce_grant_interval')]
        permissions = [('grant_entitlement', 'Grant simulated entitlements'),
                       ('grant_complimentary', 'Grant simulated complimentary access'),
                       ('grant_scholarship', 'Grant simulated scholarship'),
                       ('revoke_entitlement', 'Revoke simulated rights')]


class AdPlacement(ValidatedModel):
    code = models.SlugField()
    platform = models.CharField(max_length=8, choices=[('web','web'),('android','android')])
    format = models.CharField(max_length=16, choices=[(s,s) for s in ('banner','native','rewarded','interstitial')])
    context = models.CharField(max_length=30, choices=[('home','home'),('culture_list','culture_list')])
    enabled = models.BooleanField(default=False)
    max_per_day = models.PositiveSmallIntegerField(default=0)
    minimum_interval_seconds = models.PositiveIntegerField(default=0)

    class Meta:
        constraints = [models.UniqueConstraint(fields=['code','platform'], name='commerce_placement_unique')]


class AuditEvent(models.Model):
    actor = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL)
    action = models.CharField(max_length=50)
    target = models.CharField(max_length=100)
    reason = models.CharField(max_length=240)
    created_at = models.DateTimeField(auto_now_add=True)


class OutboxEvent(models.Model):
    request = models.OneToOneField(CommercialRequest, on_delete=models.PROTECT)
    kind = models.CharField(max_length=30, default='simulation_activated')
    created_at = models.DateTimeField(auto_now_add=True)


class DeviceKey(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    # P-256 SubjectPublicKeyInfo DER (base64), verified during enrollment.
    public_key = models.CharField(max_length=200)
    thumbprint = models.CharField(max_length=64)
    revoked_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=['user','thumbprint'], name='commerce_device_owner_key')]


class DeviceChallenge(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    nonce = models.CharField(max_length=80)
    purpose = models.CharField(max_length=10, choices=[('enroll','enroll'),('lease','lease')])
    expires_at = models.DateTimeField()
    used = models.BooleanField(default=False)
