from django.contrib import admin

from .models import Lesson, LessonItem, LessonItemAudio


class LessonItemInline(admin.TabularInline):
    model = LessonItem
    extra = 0
    fields = [
        'item_type',
        'character',
        'word',
        'title_fr',
        'order_index',
        'is_active',
        'available_offline',
    ]
    autocomplete_fields = [
        'character',
        'word',
    ]
    show_change_link = True


@admin.register(Lesson)
class LessonAdmin(admin.ModelAdmin):
    list_display = [
        'title_fr',
        'unit',
        'slug',
        'level',
        'order_index',
        'estimated_minutes',
        'status',
        'is_active',
        'available_offline',
    ]

    list_filter = [
        'unit',
        'level',
        'status',
        'is_active',
        'available_offline',
    ]

    search_fields = [
        'title_fr',
        'title_en',
        'title_ar',
        'slug',
        'unit__title_fr',
    ]

    prepopulated_fields = {
        'slug': ('title_fr',),
    }

    autocomplete_fields = [
        'unit',
    ]

    readonly_fields = [
        'created_at',
        'updated_at',
    ]

    inlines = [LessonItemInline]

    fieldsets = (
        ('Identité', {
            'fields': (
                'unit',
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
        ('Oral-first', {
            'fields': (
                'oral_intro_fr',
                'oral_intro_en',
                'oral_intro_ar',
            ),
        }),
        ('Classement', {
            'fields': (
                'level',
                'order_index',
                'estimated_minutes',
            ),
        }),
        ('Publication', {
            'fields': (
                'status',
                'is_active',
                'available_offline',
            ),
        }),
        ('Historique', {
            'fields': (
                'created_at',
                'updated_at',
            ),
        }),
    )


class LessonItemAudioInline(admin.TabularInline):
    model = LessonItemAudio
    extra = 1
    autocomplete_fields = ['audio_asset']


@admin.register(LessonItem)
class LessonItemAdmin(admin.ModelAdmin):
    list_display = [
        'lesson',
        'item_type',
        'character',
        'word',
        'title_fr',
        'repeat_count',
        'order_index',
        'is_active',
        'available_offline',
    ]

    list_filter = [
        'item_type',
        'is_active',
        'available_offline',
    ]

    search_fields = [
        'title_fr',
        'title_en',
        'title_ar',
        'lesson__title_fr',
        'character__symbol',
        'word__beriya_text',
    ]

    autocomplete_fields = [
        'lesson',
        'character',
        'word',
    ]

    readonly_fields = [
        'created_at',
        'updated_at',
    ]

    inlines = [LessonItemAudioInline]

    fieldsets = (
        ('Lien pédagogique', {
            'fields': (
                'lesson',
                'item_type',
                'character',
                'word',
            ),
        }),
        ('Titres', {
            'fields': (
                'title_fr',
                'title_en',
                'title_ar',
            ),
        }),
        ('Instructions orales', {
            'fields': (
                'oral_prompt_fr',
                'oral_prompt_en',
                'oral_prompt_ar',
                'repeat_count',
            ),
        }),
        ('Explications', {
            'fields': (
                'explanation_fr',
                'explanation_en',
                'explanation_ar',
            ),
        }),
        ('Aide à l’écriture', {
            'fields': (
                'writing_hint_fr',
                'writing_hint_en',
                'writing_hint_ar',
            ),
        }),
        ('Média', {
            'fields': (
                'image',
            ),
        }),
        ('Publication', {
            'fields': (
                'order_index',
                'is_active',
                'available_offline',
            ),
        }),
        ('Historique', {
            'fields': (
                'created_at',
                'updated_at',
            ),
        }),
    )


@admin.register(LessonItemAudio)
class LessonItemAudioAdmin(admin.ModelAdmin):
    list_display = [
        'lesson_item',
        'audio_asset',
        'role',
        'is_primary',
        'order',
    ]

    list_filter = [
        'role',
        'is_primary',
    ]

    search_fields = [
        'lesson_item__title_fr',
        'lesson_item__lesson__title_fr',
        'audio_asset__title',
        'audio_asset__transcript',
    ]

    autocomplete_fields = [
        'lesson_item',
        'audio_asset',
    ]