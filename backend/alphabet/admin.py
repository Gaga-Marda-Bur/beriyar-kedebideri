from django.contrib import admin

from .models import Character, CharacterAudio


class CharacterAudioInline(admin.TabularInline):
    model = CharacterAudio
    extra = 1
    autocomplete_fields = ['audio_asset']


@admin.register(Character)
class CharacterAdmin(admin.ModelAdmin):
    list_display = [
        'symbol',
        'unicode_code',
        'name',
        'latin_transcription',
        'arabic_transcription',
        'character_type',
        'order_index',
        'validation_status',
        'is_active',
    ]

    list_filter = [
        'character_type',
        'validation_status',
        'is_active',
        'available_offline',
    ]

    search_fields = [
        'symbol',
        'unicode_code',
        'name',
        'name_fr',
        'name_en',
        'name_ar',
        'latin_transcription',
        'arabic_transcription',
    ]

    readonly_fields = [
        'created_at',
        'updated_at',
    ]

    inlines = [CharacterAudioInline]


@admin.register(CharacterAudio)
class CharacterAudioAdmin(admin.ModelAdmin):
    list_display = [
        'character',
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
        'character__symbol',
        'character__unicode_code',
        'audio_asset__title',
        'audio_asset__transcript',
    ]

    autocomplete_fields = [
        'character',
        'audio_asset',
    ]