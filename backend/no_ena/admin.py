from django.contrib import admin
from django.utils import timezone
from django.utils.html import format_html

from .models import NoEnaPublication


@admin.register(NoEnaPublication)
class NoEnaPublicationAdmin(admin.ModelAdmin):
    list_display = [
        'title_fr',
        'publication_type',
        'culture_theme',
        'status',
        'is_active',
        'is_featured',
        'available_offline',
        'view_count',
        'published_at',
        'preview_media',
    ]

    list_filter = [
        'publication_type',
        'culture_theme',
        'status',
        'is_active',
        'is_featured',
        'available_offline',
        'created_at',
    ]

    search_fields = [
        'title_fr',
        'title_en',
        'title_ar',
        'beriya_title',
        'caption_fr',
        'caption_en',
        'caption_ar',
        'beriya_caption',
        'contributor_name',
        'culture_theme',
    ]

    prepopulated_fields = {
        'slug': ('title_fr',),
    }

    autocomplete_fields = [
        'primary_audio_asset',
        'related_character',
        'related_word',
        'related_unit',
        'contributor_user',
    ]

    readonly_fields = [
        'view_count',
        'favorite_count',
        'created_at',
        'updated_at',
        'preview_media',
    ]

    actions = [
        'mark_as_published',
        'mark_as_review',
        'mark_as_archived',
    ]

    fieldsets = (
        ('Identité', {
            'fields': (
                'slug',
                'title_fr',
                'title_en',
                'title_ar',
                'beriya_title',
            ),
        }),
        ('Descriptions', {
            'fields': (
                'caption_fr',
                'caption_en',
                'caption_ar',
                'beriya_caption',
            ),
        }),
        ('Média', {
            'fields': (
                'publication_type',
                'image_file',
                'thumbnail',
                'video_file',
                'primary_audio_asset',
                'preview_media',
            ),
        }),
        ('Liens pédagogiques', {
            'fields': (
                'related_character',
                'related_word',
                'related_unit',
            ),
        }),
        ('Contribution et culture', {
            'fields': (
                'contributor_name',
                'contributor_user',
                'culture_theme',
            ),
        }),
        ('Publication', {
            'fields': (
                'status',
                'is_active',
                'is_featured',
                'available_offline',
                'order_index',
                'published_at',
                'admin_note',
            ),
        }),
        ('Statistiques', {
            'fields': (
                'view_count',
                'favorite_count',
            ),
        }),
        ('Historique', {
            'fields': (
                'created_at',
                'updated_at',
            ),
        }),
    )

    def preview_media(self, obj):
        if obj.thumbnail:
            return format_html(
                '<img src="{}" style="height:80px;border-radius:8px;" />',
                obj.thumbnail.url,
            )

        if obj.image_file:
            return format_html(
                '<img src="{}" style="height:80px;border-radius:8px;" />',
                obj.image_file.url,
            )

        if obj.video_file:
            return format_html(
                '<a href="{}" target="_blank">Open video</a>',
                obj.video_file.url,
            )

        return '-'

    preview_media.short_description = 'Preview'

    def mark_as_published(self, request, queryset):
        queryset.update(
            status=NoEnaPublication.PUBLISHED,
            is_active=True,
            published_at=timezone.now(),
        )

    mark_as_published.short_description = 'Mark selected as published'

    def mark_as_review(self, request, queryset):
        queryset.update(status=NoEnaPublication.REVIEW)

    mark_as_review.short_description = 'Mark selected as review'

    def mark_as_archived(self, request, queryset):
        queryset.update(status=NoEnaPublication.ARCHIVED)

    mark_as_archived.short_description = 'Mark selected as archived'