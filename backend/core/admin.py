from django import forms
from django.contrib import admin, messages

from .deletion import AccountDeletionError, execute_account_deletion
from .models import AccountDeletionRequest


class AccountDeletionRequestAdminForm(forms.ModelForm):
    class Meta:
        model = AccountDeletionRequest
        fields = '__all__'

    def clean(self):
        cleaned = super().clean()
        status = cleaned.get('status')
        if (
            status == AccountDeletionRequest.STATUS_COMPLETED
            and self.instance.pk
            and self.instance.user_id is not None
        ):
            raise forms.ValidationError(
                "Impossible de marquer la demande 'completed' tant que le compte utilisateur existe encore. "
                "Utilisez l'action d'administration « Exécuter la suppression atomique du compte »."
            )
        return cleaned


@admin.register(AccountDeletionRequest)
class AccountDeletionRequestAdmin(admin.ModelAdmin):
    form = AccountDeletionRequestAdminForm
    actions = ['execute_selected_account_deletions']
    list_display = (
        'reference_code',
        'requested_username',
        'source',
        'has_email',
        'status',
        'created_at',
        'processed_at',
    )
    list_filter = ('status', 'source', 'has_email')
    search_fields = ('reference_code', 'requested_username')
    readonly_fields = (
        'reference_code',
        'user',
        'requested_username',
        'has_email',
        'source',
        'verification_method',
        'user_note',
        'created_at',
    )

    @admin.action(description="Exécuter la suppression atomique du compte et anonymiser les données")
    def execute_selected_account_deletions(self, request, queryset):
        completed = 0
        for deletion_request in queryset:
            try:
                summary = execute_account_deletion(deletion_request)
                completed += 1
                self.message_user(
                    request,
                    f"Demande {summary['reference_code']} clôturée : "
                    f"{summary['progress_deleted']} progression(s), "
                    f"{summary['sessions_deleted']} session(s), "
                    f"{summary['feedback_anonymized']} signalement(s) anonymisé(s).",
                    level=messages.SUCCESS,
                )
            except AccountDeletionError as exc:
                self.message_user(request, str(exc), level=messages.ERROR)
            except Exception as exc:
                self.message_user(
                    request,
                    f"Erreur lors de la suppression pour {deletion_request.reference_code} : {exc}",
                    level=messages.ERROR,
                )
        if completed == 0 and not queryset.exists():
            self.message_user(request, "Aucune demande sélectionnée.", level=messages.WARNING)
