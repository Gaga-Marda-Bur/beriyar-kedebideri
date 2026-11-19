from django.contrib import admin

from .models import AccountDeletionRequest


@admin.register(AccountDeletionRequest)
class AccountDeletionRequestAdmin(admin.ModelAdmin):
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
