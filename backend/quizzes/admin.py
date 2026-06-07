from django.contrib import admin

from .models import QuizOption, QuizQuestion, QuizQuestionAudio


class QuizOptionInline(admin.TabularInline):
    model = QuizOption
    extra = 4
    fields = [
        'text_fr',
        'text_en',
        'text_ar',
        'character',
        'word',
        'image',
        'is_correct',
        'order_index',
    ]
    autocomplete_fields = [
        'character',
        'word',
    ]


class QuizQuestionAudioInline(admin.TabularInline):
    model = QuizQuestionAudio
    extra = 1
    autocomplete_fields = ['audio_asset']


@admin.register(QuizQuestion)
class QuizQuestionAdmin(admin.ModelAdmin):
    list_display = [
        'id',
        'question_type',
        'unit',
        'lesson',
        'difficulty',
        'prompt_fr',
        'status',
        'is_active',
        'available_offline',
        'order_index',
    ]

    list_filter = [
        'question_type',
        'difficulty',
        'status',
        'is_active',
        'available_offline',
        'unit',
    ]

    search_fields = [
        'prompt_fr',
        'prompt_en',
        'prompt_ar',
        'oral_prompt_fr',
        'correct_text_answer',
        'character__symbol',
        'word__beriya_text',
    ]

    autocomplete_fields = [
        'unit',
        'lesson',
        'character',
        'word',
    ]

    readonly_fields = [
        'created_at',
        'updated_at',
    ]

    inlines = [
        QuizQuestionAudioInline,
        QuizOptionInline,
    ]

    fieldsets = (
        ('Lien pédagogique', {
            'fields': (
                'unit',
                'lesson',
                'question_type',
                'difficulty',
                'order_index',
                'points',
            ),
        }),
        ('Prompt visible', {
            'fields': (
                'prompt_fr',
                'prompt_en',
                'prompt_ar',
            ),
        }),
        ('Prompt oral', {
            'fields': (
                'oral_prompt_fr',
                'oral_prompt_en',
                'oral_prompt_ar',
            ),
        }),
        ('Contenu cible', {
            'fields': (
                'character',
                'word',
                'question_image',
                'correct_text_answer',
            ),
        }),
        ('Explication', {
            'fields': (
                'explanation_fr',
                'explanation_en',
                'explanation_ar',
            ),
        }),
        ('Validation', {
            'fields': (
                'min_options_required',
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


@admin.register(QuizOption)
class QuizOptionAdmin(admin.ModelAdmin):
    list_display = [
        'question',
        'display_label',
        'is_correct',
        'order_index',
    ]

    list_filter = [
        'is_correct',
        'question__question_type',
    ]

    search_fields = [
        'text_fr',
        'text_en',
        'text_ar',
        'character__symbol',
        'word__beriya_text',
    ]

    autocomplete_fields = [
        'question',
        'character',
        'word',
    ]

    def display_label(self, obj):
        return str(obj)


@admin.register(QuizQuestionAudio)
class QuizQuestionAudioAdmin(admin.ModelAdmin):
    list_display = [
        'question',
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
        'question__prompt_fr',
        'audio_asset__title',
        'audio_asset__transcript',
    ]

    autocomplete_fields = [
        'question',
        'audio_asset',
    ]