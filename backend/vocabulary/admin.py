from django.contrib import admin

from .models import Word, WordAudio, WordCategory


@admin.register(WordCategory)
class WordCategoryAdmin(admin.ModelAdmin):
    list_display = [
        'name_fr',
        'name_en',
        'name_ar',
        'slug',
        'order_index',
        'is_active',
    ]

    list_filter = [
        'is_active',
    ]

    search_fields = [
        'name_fr',
        'name_en',
        'name_ar',
        'slug',
    ]

    prepopulated_fields = {
        'slug': ('name_fr',),
    }


class WordAudioInline(admin.TabularInline):
    model = WordAudio
    extra = 1
    autocomplete_fields = ['audio_asset']


@admin.register(Word)
class WordAdmin(admin.ModelAdmin):
    list_display = [
        'beriya_text',
        'french_translation',
        'english_translation',
        'arabic_translation',
        'category',
        'difficulty',
        'validation_status',
        'is_active',
        'available_offline',
    ]

    list_filter = [
        'category',
        'difficulty',
        'validation_status',
        'is_active',
        'available_offline',
    ]

    search_fields = [
        'beriya_text',
        'latin_transcription',
        'arabic_transcription',
        'french_translation',
        'english_translation',
        'arabic_translation',
    ]

    autocomplete_fields = [
        'category',
    ]

    readonly_fields = [
        'created_at',
        'updated_at',
    ]

    inlines = [WordAudioInline]

    fieldsets = (
        ('Mot', {
            'fields': (
                'beriya_text',
                'latin_transcription',
                'arabic_transcription',
            ),
        }),
        ('Traductions', {
            'fields': (
                'french_translation',
                'english_translation',
                'arabic_translation',
            ),
        }),
        ('Classement', {
            'fields': (
                'category',
                'difficulty',
                'difficulty_order',
            ),
        }),
        ('Média et pédagogie', {
            'fields': (
                'image',
                'oral_prompt',
                'pronunciation_note',
                'dialect_note',
                'example_sentence',
            ),
        }),
        ('Validation', {
            'fields': (
                'validation_status',
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


@admin.register(WordAudio)
class WordAudioAdmin(admin.ModelAdmin):
    list_display = [
        'word',
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
        'word__beriya_text',
        'word__french_translation',
        'word__english_translation',
        'audio_asset__title',
        'audio_asset__transcript',
    ]

    autocomplete_fields = [
        'word',
        'audio_asset',
    ]