from django.contrib import admin

from .models import FeedbackReport


@admin.register(FeedbackReport)
class FeedbackReportAdmin(admin.ModelAdmin):
    list_display = [
        'id',
        'feedback_type',
        'title',
        'device_id',
        'content_type',
        'object_id',
        'priority',
        'status',
        'platform',
        'language_code',
        'created_at',
    ]

    list_filter = [
        'feedback_type',
        'priority',
        'status',
        'platform',
        'language_code',
        'created_at',
    ]

    search_fields = [
        'title',
        'message',
        'device_id',
        'admin_note',
        'app_version',
    ]

    raw_id_fields = [
        'user',
        'content_type',
        'audio_feedback',
    ]

    readonly_fields = [
        'device_id',
        'platform',
        'app_version',
        'language_code',
        'client_created_at',
        'synced_at',
        'created_at',
        'updated_at',
    ]

    date_hierarchy = 'created_at'
    list_per_page = 25

    fieldsets = (
        ('Utilisateur / appareil', {
            'fields': (
                'user',
                'device_id',
                'platform',
                'app_version',
                'language_code',
            ),
        }),
        ('Feedback', {
            'fields': (
                'feedback_type',
                'title',
                'message',
                'priority',
                'status',
            ),
        }),
        ('Contenu concerné', {
            'fields': (
                'content_type',
                'object_id',
            ),
        }),
        ('Média', {
            'fields': (
                'audio_feedback',
                'screenshot',
            ),
        }),
        ('Traitement admin', {
            'fields': (
                'admin_note',
                'resolved_at',
            ),
        }),
        ('Dates', {
            'fields': (
                'client_created_at',
                'synced_at',
                'created_at',
                'updated_at',
            ),
        }),
    )