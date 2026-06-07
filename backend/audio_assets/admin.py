from django.contrib import admin

from .models import AudioAsset


@admin.register(AudioAsset)
class AudioAssetAdmin(admin.ModelAdmin):
    list_display = [
        'title',
        'audio_type',
        'speed',
        'speaker_name',
        'dialect_region',
        'validation_status',
        'available_offline',
        'created_at',
    ]

    list_filter = [
        'audio_type',
        'speed',
        'speaker_gender',
        'validation_status',
        'available_offline',
    ]

    search_fields = [
        'title',
        'speaker_name',
        'dialect_region',
        'transcript',
        'file',
        'notes',
    ]

    readonly_fields = [
        'id',
        'created_at',
        'updated_at',
    ]

    fieldsets = (
        ('Fichier audio', {
            'fields': (
                'id',
                'title',
                'file',
                'mime_type',
                'duration_ms',
            ),
        }),
        ('Classification', {
            'fields': (
                'audio_type',
                'speed',
                'transcript',
            ),
        }),
        ('Locuteur', {
            'fields': (
                'speaker_name',
                'speaker_gender',
                'dialect_region',
            ),
        }),
        ('Validation', {
            'fields': (
                'recording_quality',
                'validation_status',
                'available_offline',
                'notes',
            ),
        }),
        ('Historique', {
            'fields': (
                'created_at',
                'updated_at',
            ),
        }),
    )