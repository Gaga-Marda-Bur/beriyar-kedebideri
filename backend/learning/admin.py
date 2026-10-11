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
        'target_word',
        'slug',
        'level',
        'estimated_minutes',
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
        'target_word',
    ]

    filter_horizontal = [
        'characters',
        'distractor_characters',
        'words',
    ]

    readonly_fields = [
        'created_at',
        'updated_at',
        'core_flow_preview',
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
        ('Méthode Active (Learning Core)', {
            'description': "Configuration du parcours d'alphabétisation active (Oral -> Visuel -> Geste -> Fusion -> Clavier)",
            'fields': (
                'target_word',
                'characters',
                'distractor_characters',
                'enable_tracing',
                'weight_recognition',
                'weight_tracing',
                'weight_encoding',
                'pedagogy_config',
                'core_flow_preview',
            ),
        }),
        ('Contenu d’accompagnement', {
            'classes': ('collapse',),
            'fields': (
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

    def core_flow_preview(self, obj):
        from django.utils.html import format_html
        if not obj.pk:
            return "Sauvegardez l'unité pour générer l'aperçu du flux."
        steps = obj.generate_core_flow()
        if not steps:
            return "Aucune étape générée. Veuillez sélectionner des caractères et un mot cible."

        rows = []
        for step in steps:
            idx = step.get('index', 0) + 1
            stype = step.get('step_type', '')
            details = []
            if 'symbol' in step:
                details.append(f"<b>Glyphe:</b> {step['symbol']}")
            if 'phoneme_ipa' in step and step['phoneme_ipa'] != 'À_VALIDER':
                details.append(f"<b>Son:</b> /{step['phoneme_ipa']}/")
            if 'target_symbol' in step:
                details.append(f"<b>Cible:</b> {step['target_symbol']} vs {step.get('other_symbol', '')}")
            if 'components' in step:
                details.append(f"<b>Fusion:</b> {' + '.join(step['components'])} &rarr; {step.get('result_syllable', '')}")
            if 'word' in step:
                details.append(f"<b>Mot:</b> {step['word']} ({step.get('french_translation', '')})")
            if 'keyboard_keys' in step:
                details.append(f"<b>Touches clavier:</b> {' '.join(step['keyboard_keys'])}")
            if 'weights' in step:
                w = step['weights']
                details.append(f"<b>Pondérations:</b> Reconnaissance {w.get('recognition')}% | Tracé {w.get('tracing')}% | Encodage {w.get('encoding')}%")

            detail_str = " &nbsp;|&nbsp; ".join(details) if details else step.get('instruction', '')
            rows.append(
                f"<tr>"
                f"<td style='padding:6px 12px; border:1px solid #ddd; text-align:center;'><b>{idx}</b></td>"
                f"<td style='padding:6px 12px; border:1px solid #ddd; font-weight:bold; color:#1b4332;'>{stype}</td>"
                f"<td style='padding:6px 12px; border:1px solid #ddd;'>{detail_str}</td>"
                f"</tr>"
            )

        html = (
            "<div style='max-width:800px; margin-top:8px;'>"
            "<table style='width:100%; border-collapse:collapse; background:#fff; font-size:13px;'>"
            "<thead><tr style='background:#f4f6f8;'>"
            "<th style='padding:6px; border:1px solid #ddd; width:40px;'>#</th>"
            "<th style='padding:6px; border:1px solid #ddd; width:150px;'>Type d'étape</th>"
            "<th style='padding:6px; border:1px solid #ddd;'>Détails & Contenu</th>"
            "</tr></thead>"
            f"<tbody>{''.join(rows)}</tbody>"
            "</table></div>"
        )
        return format_html(html)

    core_flow_preview.short_description = "Aperçu dynamique du flux (Learning Core)"