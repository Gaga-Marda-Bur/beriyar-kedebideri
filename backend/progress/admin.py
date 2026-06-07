from django.contrib import admin

from .models import UnitProgress


@admin.register(UnitProgress)
class UnitProgressAdmin(admin.ModelAdmin):
    list_display = [
        'device_id',
        'user',
        'unit',
        'status',
        'last_stage',
        'best_score_percent',
        'completed',
        'client_updated_at',
        'synced_at',
    ]

    list_filter = [
        'status',
        'completed',
        'unit',
    ]

    search_fields = [
        'device_id',
        'user__username',
        'unit__slug',
        'unit__title_fr',
    ]

    autocomplete_fields = [
        'user',
        'unit',
    ]

    readonly_fields = [
        'synced_at',
        'created_at',
    ]

    fieldsets = (
        ('Identité', {
            'fields': (
                'user',
                'device_id',
                'unit',
            ),
        }),
        ('Progression', {
            'fields': (
                'status',
                'last_stage',
                'lessons_seen',
                'characters_seen',
                'words_seen',
                'quizzes_answered',
                'correct_answers',
                'best_score_percent',
                'completed',
            ),
        }),
        ('Dates', {
            'fields': (
                'started_at',
                'completed_at',
                'client_updated_at',
                'synced_at',
                'created_at',
            ),
        }),
    )