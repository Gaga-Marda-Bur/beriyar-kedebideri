from django.contrib import admin

from .models import LearningTheme, LearningUnit


class LearningUnitInline(admin.TabularInline):
    model = LearningUnit
    extra = 0
    fields = [
        'title_fr',
        'level',
        'order_index',
        'status',
        'is_active',
        'available_offline',
    ]
    show_change_link = True


@admin.register(LearningTheme)
class LearningThemeAdmin(admin.ModelAdmin):
    list_display = [
        'title_fr',
        'slug',
        'level',
        'order_index',
        'status',
        'is_active',
        'available_offline',
    ]

    list_filter = [
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
    ]

    prepopulated_fields = {
        'slug': ('title_fr',),
    }

    readonly_fields = [
        'created_at',
        'updated_at',
    ]

    inlines = [LearningUnitInline]

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
        ('Classement', {
            'fields': (
                'level',
                'order_index',
                'cover_image',
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


@admin.register(LearningUnit)
class LearningUnitAdmin(admin.ModelAdmin):
    list_display = [
        'title_fr',
        'theme',
        'slug',
        'level',
        'estimated_minutes',
        'min_score_to_pass',
        'order_index',
        'status',
        'is_active',
        'available_offline',
    ]

    list_filter = [
        'theme',
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
        'theme__title_fr',
    ]

    prepopulated_fields = {
        'slug': ('title_fr',),
    }

    autocomplete_fields = [
        'theme',
        'characters',
        'words',
    ]

    filter_horizontal = [
        'characters',
        'words',
    ]

    readonly_fields = [
        'created_at',
        'updated_at',
    ]

    fieldsets = (
        ('Identité', {
            'fields': (
                'theme',
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
        ('Contenu pédagogique', {
            'fields': (
                'characters',
                'words',
            ),
        }),
        ('Progression', {
            'fields': (
                'level',
                'estimated_minutes',
                'min_score_to_pass',
                'order_index',
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