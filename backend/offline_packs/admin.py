from django.contrib import admin
from django.utils.html import format_html

from .models import LessonPack


@admin.register(LessonPack)
class LessonPackAdmin(admin.ModelAdmin):
    list_display = [
        'title_fr',
        'slug',
        'level',
        'pack_type',
        'version',
        'status',
        'is_active',
        'is_featured',
        'size_mb',
        'items_count',
        'generated_at',
        'download_link',
    ]

    list_filter = [
        'level',
        'pack_type',
        'status',
        'is_active',
        'is_featured',
    ]

    search_fields = [
        'title_fr',
        'title_en',
        'title_ar',
        'slug',
    ]

    prepopulated_fields = {
        'slug': ('title_fr',),
    }

    filter_horizontal = [
        'themes',
        'units',
        'characters',
        'words',
        'lessons',
        'quiz_questions',
    ]

    readonly_fields = [
        'manifest',
        'checksum',
        'size_mb',
        'items_count',
        'generated_at',
        'created_at',
        'updated_at',
        'download_link',
    ]

    fieldsets = (
        ('Identité', {
            'fields': (
                'slug',
                'title_fr',
                'title_en',
                'title_ar',
            ),
        }),
        ('Descriptions', {
            'fields': (
                'description_fr',
                'description_en',
                'description_ar',
            ),
        }),
        ('Configuration', {
            'fields': (
                'level',
                'pack_type',
                'version',
            ),
        }),
        ('Contenu', {
            'fields': (
                'themes',
                'units',
                'characters',
                'words',
                'lessons',
                'quiz_questions',
            ),
        }),
        ('Fichier généré', {
            'fields': (
                'file',
                'download_link',
                'manifest',
                'checksum',
                'size_mb',
                'items_count',
                'generated_at',
            ),
        }),
        ('Publication', {
            'fields': (
                'status',
                'is_active',
                'is_featured',
            ),
        }),
        ('Historique', {
            'fields': (
                'created_at',
                'updated_at',
            ),
        }),
    )

    def download_link(self, obj):
        if obj.file:
            return format_html(
                '<a href="{}" target="_blank">Download ZIP</a>',
                obj.file.url,
            )

        return '-'

    download_link.short_description = 'Download'