from django import forms
from django.contrib import admin, messages
from django.core.exceptions import PermissionDenied, ValidationError
from django.shortcuts import redirect
from django.template.response import TemplateResponse
from django.urls import path

from . import models, services


class ReadOnlyAdmin(admin.ModelAdmin):
    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


class ConfigurationAdmin(admin.ModelAdmin):
    def has_add_permission(self, request):
        return request.user.has_perm('monetization.configure_commerce')

    def has_change_permission(self, request, obj=None):
        return request.user.has_perm('monetization.configure_commerce')

    def has_delete_permission(self, request, obj=None):
        return False

    def save_model(self, request, obj, form, change):
        services.require(request.user, 'configure_commerce')
        if isinstance(obj, models.CommercialPolicy):
            previous = models.CommercialPolicy.objects.filter(pk=1).first()
            obj.version = previous.version + 1 if previous else 1
        super().save_model(request, obj, form, change)
        services.audit(request.user, 'configure', f'{obj._meta.label}:{obj.pk}',
                       'Simulation configuration via Django Admin')


@admin.register(models.PremiumPlan)
class PlanAdmin(ConfigurationAdmin):
    def get_readonly_fields(self, request, obj=None):
        if obj and models.CommercialRequest.objects.filter(plan=obj).exists():
            return tuple(f.name for f in obj._meta.get_fields()
                         if (f.concrete or f.many_to_many) and f.name != 'simulation_available')
        return ()


@admin.register(models.CommercialPolicy)
class PolicyAdmin(ConfigurationAdmin):
    readonly_fields = ('version',)
    actions = ('emergency_stop',)

    def has_add_permission(self, request):
        return super().has_add_permission(request) and not models.CommercialPolicy.objects.exists()

    @admin.action(description='Emergency stop (simulation)', permissions=['stop_ads'])
    def emergency_stop(self, request, queryset):
        from django.db import transaction
        from django.db.models import F
        services.require(request.user, 'disable_ads_emergency')
        with transaction.atomic():
            queryset.update(emergency_stop=True, ads_enabled=False, version=F('version')+1)
            services.audit(request.user, 'stop_ads', 'policy:1', 'Explicit emergency stop')

    def has_stop_ads_permission(self, request):
        return request.user.has_perm('monetization.disable_ads_emergency')


@admin.register(models.CommerceAccountState)
class AccountAdmin(ConfigurationAdmin):
    readonly_fields = ('user', 'subject', 'entitlement_epoch')

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return (super().has_change_permission(request, obj) and
                request.user.has_perm('monetization.review_protected_account'))


class SimulationForm(forms.Form):
    from django.contrib.auth import get_user_model
    user = forms.ModelChoiceField(queryset=get_user_model().objects.filter(is_active=True))
    plan = forms.ModelChoiceField(queryset=models.PremiumPlan.objects.filter(simulation_available=True), required=False)
    method = forms.ModelChoiceField(queryset=models.PaymentMethod.objects.filter(enabled=True), required=False)
    purpose = forms.ChoiceField(choices=models.CommercialRequest._meta.get_field('purpose').choices)
    key = forms.CharField(max_length=120)
    reason = forms.CharField(min_length=3, max_length=240)


@admin.register(models.CommercialRequest)
class RequestAdmin(ReadOnlyAdmin):
    list_display = ('id', 'purpose', 'status', 'simulated', 'created_at')
    change_list_template = 'admin/monetization/request_list.html'
    actions = ('verify', 'activate', 'reject', 'cancel', 'refund', 'revoke')

    def get_urls(self):
        return [path('simulate/', self.admin_site.admin_view(self.simulate), name='monetization_simulate')] + super().get_urls()

    def simulate(self, request):
        if not any(request.user.has_perm('monetization.'+p) for p in
                   ('verify_payment','grant_complimentary','grant_scholarship')):
            raise PermissionDenied
        form = SimulationForm(request.POST or None)
        if request.method == 'POST' and form.is_valid():
            try:
                services.create_request(actor=request.user, **form.cleaned_data)
            except (ValidationError, PermissionDenied) as exc:
                form.add_error(None, str(exc))
            else:
                return redirect('admin:monetization_commercialrequest_changelist')
        return TemplateResponse(request, 'admin/monetization/simulate.html',
            {**self.admin_site.each_context(request), 'form':form, 'title':'Simulation uniquement — aucun paiement'})

    def apply_transition(self, request, queryset, action):
        if queryset.count() != 1:
            self.message_user(request, 'Select exactly one simulation.', messages.ERROR)
            return
        obj = queryset.get()
        try:
            services.transition(actor=request.user, request_id=obj.pk, action=action,
                reason=f'SIMULATION: explicit Admin {action}', receipt='SIM-'+obj.pk.hex)
        except (ValidationError, PermissionDenied) as exc:
            self.message_user(request, str(exc), messages.ERROR)
        else:
            self.message_user(request, 'Simulation recorded. No real payment or email.')

    @admin.action(description='SIMULATION: verify payment')
    def verify(self, request, queryset):
        self.apply_transition(request, queryset, 'verify')

    @admin.action(description='SIMULATION: activate grant (independent reviewer)')
    def activate(self, request, queryset):
        self.apply_transition(request, queryset, 'activate')

    @admin.action(description='SIMULATION: reject')
    def reject(self, request, queryset):
        self.apply_transition(request, queryset, 'reject')

    @admin.action(description='SIMULATION: cancel')
    def cancel(self, request, queryset):
        self.apply_transition(request, queryset, 'cancel')

    @admin.action(description='SIMULATION: refund')
    def refund(self, request, queryset):
        self.apply_transition(request, queryset, 'refund')

    @admin.action(description='SIMULATION: revoke')
    def revoke(self, request, queryset):
        self.apply_transition(request, queryset, 'revoke')


@admin.register(models.DeviceKey)
class DeviceAdmin(ReadOnlyAdmin):
    actions = ('revoke_device',)

    @admin.action(description='Revoke simulation device')
    def revoke_device(self, request, queryset):
        from django.db import transaction
        from django.utils import timezone
        services.require(request.user, 'revoke_entitlement')
        with transaction.atomic():
            for obj in queryset.select_for_update():
                if obj.revoked_at is None:
                    obj.revoked_at = timezone.now()
                    obj.save(update_fields=['revoked_at'])
                    services.audit(request.user, 'revoke_device', obj.pk, 'SIMULATION: Admin revocation')


@admin.register(models.PremiumFeature)
class FeatureAdmin(ConfigurationAdmin):
    def has_change_permission(self, request, obj=None):
        return super().has_change_permission(request, obj) and not (
            obj and models.PremiumPlan.objects.filter(features=obj, commercialrequest__isnull=False).exists())


@admin.register(models.PaymentMethod)
class MethodAdmin(ConfigurationAdmin):
    def get_readonly_fields(self, request, obj=None):
        if obj and models.CommercialRequest.objects.filter(method=obj).exists():
            return tuple(f.name for f in obj._meta.fields if f.name != 'enabled')
        return ()


admin.site.register(models.AdPlacement, ConfigurationAdmin)
for model in (models.PaymentTransaction, models.EntitlementGrant, models.AuditEvent, models.OutboxEvent):
    admin.site.register(model, ReadOnlyAdmin)
